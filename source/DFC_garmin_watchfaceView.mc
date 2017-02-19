using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Communications as Comm;
using Toybox.Timer as Timer;
using Toybox.Sensor as Sensor;
using Toybox.SensorHistory as SensorHistory;
using Toybox.Time as Time;
using Toybox.UserProfile as UserProfile;
using Toybox.Application as App;

var phoneMethod;
var commListener = new CommListener();
var sendCommBusy = false;
var timer1 = new Timer.Timer();
var HR_value = 0;
var HRSensorEnable = false;
var sport_mode = false;
const SPORT_MODE_MIN_TIME = 60; // in seconds
var onSensorHRCounter = SPORT_MODE_MIN_TIME;
var last_minute = -1;
const DISPLAY_HEIGHT_OFFSET = 57;
var screenWidth;
var screenHeight;

// Heart Rate Zones
var zone_HR_min;
var zone_HR_max;
var zone_HR_m_calc;
const INDICATOR_WIDTH = 15;
const INDICATOR_WIDTH_HALF = 7;
const INDICATOR_HEIGHT = 12;
var customFont = null;

var secondsCounter = 0;

const COLOR_GRAY_1 = 0xAAAAAA;
const COLOR_GRAY_2 = 0x555555;
const COLOR_BLUE_1 = 0x00AAFF;
const COLOR_BLUE_2 = 0x0055FF;
const COLOR_GREEN_1 = 0x00FF00;
const COLOR_GREEN_2 = 0x00AA00;
const COLOR_ORANGE_1 = 0xFFAA00;
const COLOR_ORANGE_2 = 0xFF5500;
const COLOR_RED_1 = 0xFF0000;
const COLOR_RED_2 = 0xAA0000;
const COLOR_YELLOW_1 = 0xFFFFAA;
const COLOR_YELLOW_2 = 0xFFFF00;

var clockTime = Sys.getClockTime();

const HISTORIC_HR_COMMAND = 104030201;
const ALIVE_COMMAND = 154030201;
const USER_DATA_COMMAND = 204030201;
const CALORIES_BALANCE_COMMAND = 304030201;

var caloriesBalance = 0;
var caloriesBalanceScale = 1;

// Seems a Garmin bug, because UTC time is UTC 00:00 Dec 31 1989
//Unix UTC time: 1 January 1970
//Garmin UTC time: 31 December 1989
const GARMIN_UTC_OFFSET = ((1990 - 1970) * Time.Gregorian.SECONDS_PER_YEAR) - Time.Gregorian.SECONDS_PER_DAY;

const CUSTOM_FONT = false; // true to use the customFont but code needs to be built on Windows only :-(

function CalcHRZones() {
  zone_HR_max = 220 - UserAge; // HRMax = 220 - UserAge
  zone_HR_min = zone_HR_max / 2;

  zone_HR_m_calc = (148.0 - INDICATOR_WIDTH) / (zone_HR_max - zone_HR_min); // screenWidth = 148 on VivoActive HR
}

function onSensorHR(sensor_info)
{
  if (onSensorHRCounter > 0) { onSensorHRCounter--; }

  var HR = sensor_info.heartRate;
  if(HR == null) {
    HR_value = 0;
  } else {
    HR_value = HR;
  }

  if (onSensorHRCounter > 0) {
    sport_mode = true;
  } else if (HR_value < 90){
    sport_mode = false;
    disableHRSensor();
  } else {
    sport_mode = true;
  }

  if (HR_value >= 90) {
    sport_mode = true;
    onSensorHRCounter = SPORT_MODE_MIN_TIME;
  }

  Ui.requestUpdate();
}

function enableHRSensor() {
  if (HRSensorEnable == false) {
    Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
    Sensor.enableSensorEvents(method(:onSensorHR));
    HRSensorEnable = true;
  }
}

function disableHRSensor() {
  Sensor.setEnabledSensors([]);
  Sensor.enableSensorEvents();
  HRSensorEnable = false;
}

/*******************************************************
 * Receive here the data sent from the Android app
 */
function onPhone(msg) {
  if (sendCommBusy == false) { // we just can send data if Comm is not busy, so ignore received command while Comm is busy
    var dataArray = [];

    // Execute the command
    if (msg.data[0] == HISTORIC_HR_COMMAND) {
      var startDate = msg.data[1];
      var date;

      var HRSensorHistoryIterator = SensorHistory.getHeartRateHistory(
	  {
	  //Garmin Connect IQ bug?? https://forums.garmin.com/showthread.php?354356-Toybox-SensorHistory-question&highlight=sensorhistory+period
	      //:period => new Toybox.Time.Duration.initiavar lize(5*60)
	      :order => SensorHistory.ORDER_NEWEST_FIRST
	  });

      var HRSample = HRSensorHistoryIterator.next();
      // Starting building the command response
      dataArray.add(HISTORIC_HR_COMMAND);
      while (HRSample != null) {
	date = HRSample.when.value() + GARMIN_UTC_OFFSET;
	if (date > startDate) {
	  var tempHR = HRSample.data;
	  if (tempHR == null) {
	    HRSample = HRSensorHistoryIterator.next();
	    continue;
	  }
	  dataArray.add(date);
	  dataArray.add(HRSample.data);
	  HRSample = HRSensorHistoryIterator.next();
	} else {
	  break;
	}
      }
      // Transmit command response
      sendCommBusy = true;
      Comm.transmit(dataArray, null, commListener);
      
    } else if (msg.data[0] == USER_DATA_COMMAND) {
      // Get the parameters from the command
      // Starting building the command response
      dataArray.add(USER_DATA_COMMAND);
      dataArray.add(userProfile.birthYear);
      dataArray.add(userProfile.gender);
      dataArray.add(userProfile.height);
      dataArray.add(userProfile.weight);
      dataArray.add(userProfile.activityClass);
      // Transmit command response
      sendCommBusy = true;
      Comm.transmit(dataArray, null, commListener);
      
    } else if (msg.data[0] == CALORIES_BALANCE_COMMAND) {
      caloriesBalance = msg.data[1];
      caloriesBalanceScale = msg.data[2]; // 40% of total EER calories for the day
      Ui.requestUpdate();
    }
  }
}

function sendAliveCommand () {
  if (sendCommBusy == false) {
    // Prepare and send the command
    var dataArray = [];
    dataArray.add(ALIVE_COMMAND);
    sendCommBusy = true;
    Comm.transmit(dataArray, null, commListener);
  }
}

class DFC_garmin_watchappView extends Ui.View {
  function initialize() {
    View.initialize();

    // Enable communications
    phoneMethod = method(:onPhone);
    Comm.registerForPhoneAppMessages(phoneMethod);

    CalcHRZones();

    if (CUSTOM_FONT == true) {
      customFont = Ui.loadResource(Rez.Fonts.roboto_bold_36);
    } else {
      customFont = Graphics.FONT_LARGE;
    }

    timer1.start(method(:timer1Callback), 60*1000, true);
  }

  // Update UI at frequency of timer
  function timer1Callback() {
    Ui.requestUpdate();
  }

  function drawHoursHand(dc, angle) {
    // Map out the coordinates of the watch hand
    var coords = [
		  [   0,   0],
		  [  -6, -16],
		  [   0, -44],
		  [   6, -16]
		 ];
    var result = new [4];

    var centerX = dc.getWidth() / 2;
    var centerY = (dc.getHeight() - DISPLAY_HEIGHT_OFFSET) / 2;
    var cos = Math.cos(angle);
    var sin = Math.sin(angle);

    // Transform the coordinates
    for (var i = 0; i < 4; i += 1) {
      var x = (coords[i][0] * cos) - (coords[i][1] * sin);
      var y = (coords[i][0] * sin) + (coords[i][1] * cos);
      result[i] = [centerX + x, centerY + y];
    }

    // Draw the polygonHR
    dc.fillPolygon(result);
  }

  function drawMinutesHand(dc, angle) {
    // Map out the coordinates of the watch hand
    var coords = [
		  [   0,   0],
		  [  -5, -16],
		  [   0, -68],
		  [   5, -16]
		 ];
    var result = new [4];

    var centerX = dc.getWidth() / 2;
    var centerY = (dc.getHeight() - DISPLAY_HEIGHT_OFFSET) / 2;
    var cos = Math.cos(angle);
    var sin = Math.sin(angle);

    // Transform the coordinates
    for (var i = 0; i < 4; i += 1) {
      var x = (coords[i][0] * cos) - (coords[i][1] * sin);
      var y = (coords[i][0] * sin) + (coords[i][1] * cos);
      result[i] = [centerX + x, centerY + y];
    }

    // Draw the polygon
    dc.fillPolygon(result);
  }

  // Draw the hash mark symbols on the watch
  function drawHashMarks(dc) {
    var width = dc.getWidth();
    var height = dc.getHeight() - DISPLAY_HEIGHT_OFFSET;
    var coords = [0, width / 4, (3 * width) / 4, width];

    for (var i = 0; i < coords.size(); i += 1) {
      var dx = ((width / 2.0) - coords[i]) / (height / 2.0);
      var upperX = coords[i] + (dx * 10);
      // Draw the upper hash marks
      dc.fillPolygon([[coords[i] - 1, 2], [upperX - 1, 12], [upperX + 1, 12], [coords[i] + 1, 2]]);
      // Draw the lower hash marks
      dc.fillPolygon([[coords[i] - 1, height-2], [upperX - 1, height - 12], [upperX + 1, height - 12], [coords[i] + 1, height - 2]]);
    }
  }

  // Update the view
  function onUpdate(dc) {
    var font = Graphics.FONT_LARGE;
    var width;
    var height;
    screenWidth = dc.getWidth();
    screenHeight = dc.getHeight();
    var clockTime = Sys.getClockTime();
    var hourHandAngle;
    var minuteHandAngle;
    var secondHandAngle;

    width = dc.getWidth();
    height = dc.getHeight() - DISPLAY_HEIGHT_OFFSET;

    // Clear the screen
    if (sport_mode == false) {dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);}
    else {dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);}
    dc.fillRectangle(0, 0, screenWidth, screenHeight);

    // Draw lowest rectangle
    if (sport_mode == false) {
 	  dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
	  dc.fillRectangle(0, screenHeight - DISPLAY_HEIGHT_OFFSET, screenWidth, screenHeight);
	} else {
	  dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
	  dc.fillRectangle(0, screenHeight - DISPLAY_HEIGHT_OFFSET, screenWidth, screenHeight);
	}
    
    // Draw the numbers
    if (sport_mode == false) {dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);}
    else {dc.setColor(COLOR_GRAY_1, Gfx.COLOR_TRANSPARENT);}
    dc.drawText((width / 2), 0, font, "12", Gfx.TEXT_JUSTIFY_CENTER);
    dc.drawText(width - 2, (height / 2) - 15, font, "3", Gfx.TEXT_JUSTIFY_RIGHT);
    dc.drawText(width / 2, height - 28, font, "6", Gfx.TEXT_JUSTIFY_CENTER);
    dc.drawText(2, (height / 2) - 15, font, "9", Gfx.TEXT_JUSTIFY_LEFT);

    // Draw the hash marks
    drawHashMarks(dc);

    // Draw the hour. Convert it to minutes and compute the angle.
    hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
    hourHandAngle = hourHandAngle / (12 * 60.0);
    hourHandAngle = hourHandAngle * Math.PI * 2;
    drawHoursHand(dc, hourHandAngle);

    // Draw the minute
    minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;
    drawMinutesHand(dc, minuteHandAngle);

    // Draw the arbor
    if (sport_mode == false) {dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);}
    else {dc.setColor(COLOR_GRAY_1, Gfx.COLOR_TRANSPARENT);}
    dc.fillCircle(width / 2, height / 2, 5);
    dc.drawCircle(width / 2, height / 2, 5);

    if (sport_mode == true) {
      /********************************************/
      // Draw HR zones graphs
      //
      dc.setColor(COLOR_GRAY_1, Gfx.COLOR_TRANSPARENT); // gray
      var x_width = 25; // dc.getWidth() 148 / 5; // 5 HR zones
      var x = INDICATOR_WIDTH_HALF;
      var y = screenHeight - 10; // height of the bars
      var y_height = screenHeight;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(COLOR_BLUE_1, Gfx.COLOR_TRANSPARENT); // blue
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(COLOR_GREEN_1, Gfx.COLOR_TRANSPARENT); // green
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(COLOR_ORANGE_1, Gfx.COLOR_TRANSPARENT); // orange
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(COLOR_RED_1, Gfx.COLOR_TRANSPARENT); // red
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);
      /********************************************/

      /********************************************/
      // Draw HR zone indicator
      //
      // calc position of the indicator
      var HR = HR_value;
      if (HR < zone_HR_min) { HR = zone_HR_min; }
      else if (HR > zone_HR_max) { HR = zone_HR_max; }
      var pos_ind = ((HR - zone_HR_min) * zone_HR_m_calc) + INDICATOR_WIDTH_HALF;
      pos_ind = pos_ind.toNumber();

      dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
      var x1 = pos_ind - INDICATOR_WIDTH_HALF;
      var y1 = screenHeight - 12;
      var x2 = x1 + INDICATOR_WIDTH;
      var y2 = y1;
      var x3 = x1 + INDICATOR_WIDTH_HALF;
      var y3 = y1 + INDICATOR_HEIGHT;
      dc.fillPolygon([[x1, y1], [x2, y2], [x3, y3]]);
      /********************************************/

      // Display the HR value
      if (HR_value != 0) {
	if (CUSTOM_FONT == true) {
	  dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET)), customFont, HR_value, Gfx.TEXT_JUSTIFY_CENTER);
	} else {
	  dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET - 8)), customFont, HR_value, Gfx.TEXT_JUSTIFY_CENTER);
	}
      } else {
	if (CUSTOM_FONT == true) {
	  dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET)), customFont, "---", Gfx.TEXT_JUSTIFY_CENTER);
	} else {
	  dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET - 8)), customFont, "---", Gfx.TEXT_JUSTIFY_CENTER);
	}
      }

    } else if (clockTime.min != last_minute) {
      /********************************************/
      // Draw calories zones graphs
      //
      dc.setColor(COLOR_ORANGE_2, Gfx.COLOR_TRANSPARENT);
      var x_width = 32; // 4 zones
      var x = INDICATOR_WIDTH_HALF;
      var y = screenHeight - 10; // height of the bars
      var y_height = screenHeight;
      dc.fillRectangle(x, y, x_width, y_height);
     
      dc.setColor(COLOR_GREEN_1, Gfx.COLOR_TRANSPARENT);
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(COLOR_BLUE_1, Gfx.COLOR_TRANSPARENT);      
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(COLOR_GRAY_1, Gfx.COLOR_TRANSPARENT);
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);
      /********************************************/
      
      /********************************************/
      // Draw the zone indicator
      //
      // calc position of the indicator
      var bar_with = 148.0 - INDICATOR_WIDTH;
      var scale = bar_with / caloriesBalanceScale;
      var caloriesIndicator = caloriesBalance * scale;
      caloriesIndicator = caloriesIndicator.toNumber();

      dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
      var x1 = (bar_with/4) + caloriesIndicator;
      // impose limits
      if (x1 > bar_with) { x1 = bar_with; }
      else if (x1 < INDICATOR_WIDTH) { x1 = INDICATOR_WIDTH; }

      var y1 = screenHeight - 12;
      var x2 = x1 + INDICATOR_WIDTH;
      var y2 = y1;
      var x3 = x1 + INDICATOR_WIDTH_HALF;
      var y3 = y1 + INDICATOR_HEIGHT;
      dc.fillPolygon([[x1, y1], [x2, y2], [x3, y3]]);
      /********************************************/

      // Display the calories balance value
      if (caloriesBalance != 0) {
	if (caloriesBalance < 0) { dc.setColor(0xFF0055, Gfx.COLOR_TRANSPARENT); }
	if (CUSTOM_FONT == true) {
	  dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET)), customFont, caloriesBalance, Gfx.TEXT_JUSTIFY_CENTER);
	} else {
	  dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET - 8)), customFont, caloriesBalance, Gfx.TEXT_JUSTIFY_CENTER);
	}
      } else {
	if (CUSTOM_FONT == true) {
	  dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET)), customFont, "----", Gfx.TEXT_JUSTIFY_CENTER);
	} else {
	  dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET - 8)), customFont, "----", Gfx.TEXT_JUSTIFY_CENTER);
	}
      }
    
      secondsCounter++;
      if (secondsCounter >= 2) {
	secondsCounter = 0;
	sendAliveCommand();
      }
    }
  }
}

class CommListener extends Comm.ConnectionListener {
  function initialize() {
    Comm.ConnectionListener.initialize();
  }

  // Sucess to send data to Android app
  function onComplete() {
    sendCommBusy = false;
  }

  // Fail to send data to Android app
  function onError() {
    sendCommBusy = false;
  }
}

class ConfirmationDialogDelegate extends Ui.ConfirmationDelegate {
  function initialize() {
    ConfirmationDelegate.initialize();
  }

  function onResponse(value) {
    if (value == 0) {
    }
    else {
      Ui.popView(Ui.SLIDE_UP); // close the app
    }
  }
}


class BaseInputDelegate extends Ui.BehaviorDelegate {
  var dialog;

  function initialize() {
    BehaviorDelegate.initialize();
  }

  function onMenu() {
    sendAliveCommand();
    return 0;
  }

  function onBack() {
    if (sport_mode == true) { // exit the sport mode
      sport_mode = false;
      disableHRSensor();
      Ui.requestUpdate();
      return true;
    } else {
      return pushDialog();
    }
  }

  function onKey(evt) {
    var key = evt.getKey();
    if (key == KEY_ENTER) {
      // Start the sport mode
      onSensorHRCounter = SPORT_MODE_MIN_TIME;
      enableHRSensor();
    }

    return true;
  }

  function pushDialog() {
    dialog = new Ui.Confirmation("Do you want to exit?");
    Ui.pushView(dialog, new ConfirmationDialogDelegate(), Ui.SLIDE_IMMEDIATE);
    return true;
  }

  function onNextPage() {
  }
}

/* ****************************************************************************
 * ****************************************************************************
 * ****************************************************************************
 *
 * Storage
 *
 */

const CALS_ARRAY_SIZE = 1550; // each element is 4 bytes: 1550*4 = ~6kbytes <-- higher value will not work
const PROPERTY_CALS_ARRAY_KEY = 1;
const PROPERTY_CALS_ARRAY_END_POS_KEY = 2;
const PROPERTY_CALS_ARRAY_END_TIME_KEY = 3;

var calsArray = null;
var calsArrayEndPos = 0;
var calsArrayEndTime = 0;

function initStorage () {
  var calsPerMinute = 0;

  // Initialize var from the values on store object
  var app = App.getApp();
  calsArray = app.getProperty(PROPERTY_CALS_ARRAY_KEY);
//app.clearProperties();
//calsArray = null;
  if (calsArray == null) { // should happen only on the very first time the app runs
    calsArray = new [CALS_ARRAY_SIZE];

    /* ************************************************
     * Fill the array with default value of calories
     */
    calsPerMinute = getCalsPerMinute (0); // default HR of 0

    // start at current time and go backwards
    calsArrayEndPos = CALS_ARRAY_SIZE - 1;
    calsArrayEndTime = Time.now().value() / 60;

    for (var i = 0; i < CALS_ARRAY_SIZE; i++) {
      calsArray[i] = calsPerMinute;
    }

    return; // array and all variables should be correct initialized
  }

  calsArrayEndPos = app.getProperty(PROPERTY_CALS_ARRAY_END_POS_KEY);
  calsArrayEndTime = app.getProperty(PROPERTY_CALS_ARRAY_END_TIME_KEY);

  var nowMinutes = Time.now().value() / 60;
  var minutesLeftInArray = nowMinutes - calsArrayEndTime;
  if (minutesLeftInArray) { // need to update the array
    if (minutesLeftInArray > CALS_ARRAY_SIZE) { minutesLeftInArray = CALS_ARRAY_SIZE; } // limit to max array size

    // **********************************************************
    // Prepare HR Sensor history
    var targetMinute = nowMinutes - minutesLeftInArray;
    var HRSensorHistoryIterator = SensorHistory.getHeartRateHistory(
   	  {
   	  //Garmin Connect IQ bug?? https://forums.garmin.com/showthread.php?354356-Toybox-SensorHistory-question&highlight=sensorhistory+period
   	      //:period => new Toybox.Time.Duration.initiavar lize(5*60)
   	      :order => SensorHistory.ORDER_OLDEST_FIRST
   	  });

    // move forward SensorHistoryIterator until the date we are looking for
    var HRSample = 0;
    var date = 0;
    do {
      HRSample = HRSensorHistoryIterator.next();
      if (HRSample != null) {
	date = (HRSample.when.value() + GARMIN_UTC_OFFSET) / 60;
      } else { // no more samples
	brake;
      }
    } while (date < targetMinute);
    // **********************************************************

    var HR = 0;
    while (minutesLeftInArray) {
      minutesLeftInArray--;

      // Manage the array pointer bondaries
      if (calsArrayEndPos >= (CALS_ARRAY_SIZE - 1)) { calsArrayEndPos = 0; }
      else { calsArrayEndPos++; }

      // **********************************************************
      // get the new values of calories and put on the array
      if (HRSample != null) {
	date = (HRSample.when.value() + GARMIN_UTC_OFFSET) / 60;
	if ((date >= targetMinute) && (date < (targetMinute+1))) { // get HR values that are only on this minute
	  if (HRSample.data != null) {
	    HR = HRSample.data;
	  }
	}

	HRSample = HRSensorHistoryIterator.next();
      } else { // no more data from SensorHistory
	HR = 0;
      }

      calsArray[calsArrayEndPos] = getCalsPerMinute (HR);
      calsArrayEndTime++;

      targetMinute++;
    }

    return; // array and all variables should be correct initialized
  }
}

function saveStorage () {
   // Save now the values on store object
  var app = App.getApp();
System.println("calsArray " + calsArray);
  app.setProperty(PROPERTY_CALS_ARRAY_KEY, calsArray);
  app.setProperty(PROPERTY_CALS_ARRAY_END_POS_KEY, calsArrayEndPos);
  app.setProperty(PROPERTY_CALS_ARRAY_END_TIME_KEY, calsArrayEndTime);
}

/* ****************************************************************************
 * ****************************************************************************
 * ****************************************************************************/

/* ****************************************************************************
 * ****************************************************************************
 * ****************************************************************************
 *
 * Calories
 *
 */

/*
  EER:
  Your EER (Estimated Energy Requirements) are the number of estimated  calories that you burn
  based on your BMR plus calories from a typical  non-exercise day, such as getting ready for
  work, working at a desk job  for 8 hours, and stopping by the store on the way home. EER is
  based on a  formula published by the FDA and used by other government agencies to  estimate the
  calories required by an individual based on their age,  height, weight, and gender. Your EER is
  greater than your BMR since your  BMR only takes into account the calories burned by your body
  just for  it to exist.
  MALE: EER = 864 - 9.72 x age(years) + 1.0 x (14.2 x weight(kg) + 503 x height(meters))
  FEMALE: EER = 387 - 7.31 x age(years) + 1.0 x (10.9 x weight(kg) + 660.7 x height(meters))

  Calories over and including 90 HR:
  This is the Formula when you don't know the VO2max (Maximal oxygen consumption):
  Male:((-55.0969 + (0.6309 x HR) + (0.1988 x W) + (0.2017 x A))/4.184) x 60 x T
  Female:((-20.4022 + (0.4472 x HR) - (0.1263 x W) + (0.074 x A))/4.184) x 60 x T
  HR = Heart rate (in beats/minute)
  W = Weight (in kilograms)
  A = Age (in years)
  T = Exercise duration time (in hours)
*/

var userProfile = UserProfile.getProfile();
var UserAge = 0;
var UserWeight = 0;
var UserHeight = 0;
var EERCalsPerMinute = 0;

function initEERCals () {
  var currentYear = (Time.now().value() / Time.Gregorian.SECONDS_PER_YEAR) + 1970;
  UserAge = currentYear - userProfile.birthYear; // years
  UserWeight = userProfile.weight / 1000.0; // kg
  UserHeight = userProfile.height / 100.0; // meters

  //EER
  if (userProfile.gender == UserProfile.GENDER_FEMALE) { // female
    EERCalsPerMinute = ((387 - (7.31*UserAge) + (1.0*(10.9*UserWeight)) + (660.7*UserHeight))); // daily value
  } else { // male
    EERCalsPerMinute = ((864 - (9.72*UserAge) + (1.0*(14.2*UserWeight)) + (503*UserHeight)));
  }

  EERCalsPerMinute /= 24.0 * 60.0; // per minute value of the day
  EERCalsPerMinute *= 1000;
  EERCalsPerMinute = EERCalsPerMinute.toNumber(); // int value and 1000x the real value
}

function getCalsPerMinute (HR) {
  var calories;
  if (HR >= 90 && HR < 255) { // HR >= 90 only, calculation based on formula without VO2max
    if (userProfile.gender == UserProfile.GENDER_FEMALE) { // female
      calories = (-20.4022 + (0.4472*HR) - (0.1263*UserWeight) + (0.074*UserAge));
      calories = calories / 4.184;
      calories *= 1000;
      calories = calories.toNumber(); // int value and 1000x the real value

    } else { // male
      calories = (-55.0969 + (0.6309*HR) + (0.1988*UserWeight) + (0.2017*UserAge));
      calories = calories / 4.184;
      calories *= 1000;
      calories = calories.toNumber(); // int value and 1000x the real value
    }
  } else { // here, calculation based on Estimated Energy Requirements
    calories = EERCalsPerMinute;
  }

  return calories;
}
