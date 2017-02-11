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
const HR_INDICATOR_WIDTH = 15;
const HR_INDICATOR_WIDTH_HALF = 7;
const HR_INDICATOR_HEIGHT = 12;
var customFont = null;

var secondsCounter = 0;

var clockTime = Sys.getClockTime();

const HISTORIC_HR_COMMAND = 104030201;
const ALIVE_COMMAND = 154030201;
const USER_DATA_COMMAND = 204030201;

// Seems a Garmin bug, because UTC time is UTC 00:00 Dec 31 1989
//Unix UTC time: 1 January 1970
//Garmin UTC time: 31 December 1989
const GARMIN_UTC_OFFSET = ((1990 - 1970) * Time.Gregorian.SECONDS_PER_YEAR) - Time.Gregorian.SECONDS_PER_DAY;

function CalcHRZones() {
  var currentYear = (Time.now().value() / Time.Gregorian.SECONDS_PER_YEAR) + 1970;
  var userProfile = UserProfile.getProfile();
  zone_HR_max = 220 - (currentYear - userProfile.birthYear); // HRMax = 220 - UserAge
  zone_HR_min = zone_HR_max / 2;

  zone_HR_m_calc = (148.0 - HR_INDICATOR_WIDTH) / (zone_HR_max - zone_HR_min); // screenWidth = 148 on VivoActive HR
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
    } else if (msg.data[0] == USER_DATA_COMMAND) {
      // Get the parameters from the command
      var userProfile = UserProfile.getProfile();
      // Starting building the command response
      dataArray.add(USER_DATA_COMMAND);
      dataArray.add(userProfile.birthYear);
      dataArray.add(userProfile.gender);
      dataArray.add(userProfile.height);
      dataArray.add(userProfile.weight);
      dataArray.add(userProfile.activityClass);
    }

    // Transmit command response
    sendCommBusy = true;
    Comm.transmit(dataArray, null, commListener);
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

    customFont = Ui.loadResource(Rez.Fonts.roboto_bold_36);

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
      dc.fillRectangle(0, screenHeight - DISPLAY_HEIGHT_OFFSET, screenWidth, screenHeight - DISPLAY_HEIGHT_OFFSET + 4);
      dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
      dc.fillRectangle(0, screenHeight - DISPLAY_HEIGHT_OFFSET + 4, screenWidth, screenHeight);
	}
    else {
	  dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
	  dc.fillRectangle(0, screenHeight - DISPLAY_HEIGHT_OFFSET, screenWidth, screenHeight);
	}
    
    // Draw the numbers
    if (sport_mode == false) {dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);}
    else {dc.setColor(0xAAAAAA, Gfx.COLOR_TRANSPARENT);}
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
    else {dc.setColor(0xAAAAAA, Gfx.COLOR_TRANSPARENT);}
    dc.fillCircle(width / 2, height / 2, 5);
    dc.drawCircle(width / 2, height / 2, 5);

    if (sport_mode == true) {
      /********************************************/
      // Draw HR zones graphs
      //
      dc.setColor(0xAAAAAA, Gfx.COLOR_TRANSPARENT); // gray
      var x_width = 25; // dc.getWidth() 148 / 5; // 5 HR zones
      var x = 7;
      var y = screenHeight - 12; // height of the bars
      var y_height = screenHeight;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(0x00AAFF, Gfx.COLOR_TRANSPARENT); // blue
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(0x00FF00, Gfx.COLOR_TRANSPARENT); // green
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(0xFFAA00, Gfx.COLOR_TRANSPARENT); // orange
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(0xFF0000, Gfx.COLOR_TRANSPARENT); // red
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
      var pos_ind = ((HR - zone_HR_min) * zone_HR_m_calc) + HR_INDICATOR_WIDTH_HALF;
      pos_ind = pos_ind.toNumber();

      dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
      var x1 = pos_ind - HR_INDICATOR_WIDTH_HALF;
      var y1 = screenHeight - 14;
      var x2 = x1 + HR_INDICATOR_WIDTH;
      var y2 = y1;
      var x3 = x1 + HR_INDICATOR_WIDTH_HALF;
      var y3 = y1 + HR_INDICATOR_HEIGHT;
      dc.fillPolygon([[x1, y1], [x2, y2], [x3, y3]]);
      /********************************************/

      // Display the HR value
      if (HR_value != 0) {
	    dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET + 0)), customFont, HR_value, Gfx.TEXT_JUSTIFY_CENTER);
      } else {
	    dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET + 0)), customFont, "---", Gfx.TEXT_JUSTIFY_CENTER);
      }

    } else if (clockTime.min != last_minute) {
      /********************************************/
      // Draw calories zones graphs
      //
      dc.setColor(0xFF0000, Gfx.COLOR_TRANSPARENT); // red
      var x_width = 25; // dc.getWidth() 148 / 5; // 5 zones
      var x = 7;
      var y = screenHeight - 12; // height of the bars
      var y_height = screenHeight;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(0xFFAA00, Gfx.COLOR_TRANSPARENT); // orange
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(0xFFFF00, Gfx.COLOR_TRANSPARENT); // yellow
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(0x00FF00, Gfx.COLOR_TRANSPARENT); // green      
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);

      dc.setColor(0x00AAFF, Gfx.COLOR_TRANSPARENT); // blue      
      x += x_width + 2;
      dc.fillRectangle(x, y, x_width, y_height);
      /********************************************/
    
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
