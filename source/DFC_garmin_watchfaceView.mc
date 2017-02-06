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
const SPORT_MODE_MIN_TIME = 30; // in seconds
var onSensorHRCounter = SPORT_MODE_MIN_TIME;
var last_minute = -1;
var screenWidth;
var screenHeight;

var secondsCounter = 0;

var clockTime = Sys.getClockTime();

const HISTORIC_HR_COMMAND = 104030201;
const ALIVE_COMMAND = 154030201;
const USER_DATA_COMMAND = 204030201;

const DISPLAY_HEIGHT_OFFSET = 57;

// Seems a Garmin bug, because UTC time is UTC 00:00 Dec 31 1989
//Unix UTC time: 1 January 1970
//Garmin UTC time: 31 December 1989
const GARMIN_UTC_OFFSET = ((1990 - 1970) * Time.Gregorian.SECONDS_PER_YEAR) - Time.Gregorian.SECONDS_PER_DAY;

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
//  if (HRSensorEnable == false) {
    Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
    Sensor.enableSensorEvents(method(:onSensorHR));
    HRSensorEnable = true;
//  }
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

//    Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);

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

    // Transform the coordina_tes
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
    dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
    dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

    // Draw lowest rectangle
    dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
    dc.fillRectangle(0, dc.getHeight() - DISPLAY_HEIGHT_OFFSET, dc.getWidth(), dc.getHeight());

    // Draw the numbers
    dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
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
    dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
    dc.fillCircle(width / 2, height / 2, 5);
    dc.setColor(Gfx.COLOR_BLACK,Gfx.COLOR_BLACK);
    dc.drawCircle(width / 2, height / 2, 5);

    if (sport_mode == true) {
      // Display the HR value
      dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
      if (HR_value != 0) {
	dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET - 20)), Graphics.FONT_LARGE, HR_value, Gfx.TEXT_JUSTIFY_CENTER);
      } else {
	dc.drawText((screenWidth / 2), (screenHeight - (DISPLAY_HEIGHT_OFFSET - 20)), Graphics.FONT_LARGE, "---", Gfx.TEXT_JUSTIFY_CENTER);
      }
    } else if (clockTime.min != last_minute) {
      last_minute = clockTime.min;

      // Enable HR sensor - processing of result on the event handler
//      enableHRSensor();

      secondsCounter++;
      if (secondsCounter >= 2) {
	secondsCounter = 0;
	sendAliveCommand();
      }
    }

//    System.println("onUpdate " + clockTime.min + ":" + clockTime.sec);
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
    return pushDialog();
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
