using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Communications as Comm;
using Toybox.Timer as Timer;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;
using Toybox.Time as Time;
using Toybox.UserProfile as UserProfile;

var mailMethod;
var timer1 = new Timer.Timer();

var clockTime = Sys.getClockTime();

const HISTORIC_HR_COMMAND = 104030201;
const USER_DATA_COMMAND = 204030201;

const HISTORIC_HR_ARRAY_SIZE = 8*1000 // (8 kbytes - 192 bytes) size
const HISTORIC_HR_ARRAY_DATA_SIZE = 4 // each int stored equals to 4 bytes
var historicHRArray = [HISTORIC_HR_ARRAY_SIZE];
const STORE_PROPERTY_ARRAY_KEY = 1;
const STORE_PROPERTY_ARRAY_POINTER_KEY = 2;

// Seems a Garmin bug, because UTC time is UTC 00:00 Dec 31 1989
//Unix UTC time: 1 January 1970
//Garmin UTC time: 31 December 1989
const GARMIN_UTC_OFFSET = ((1990 - 1970) * Time.Gregorian.SECONDS_PER_YEAR) - Time.Gregorian.SECONDS_PER_DAY;

class DFC_garmin_watchappView extends Ui.View {
    const displayHeightOffset = 57;

    function initialize() {
	View.initialize();

        mailMethod = method(:onMail);
        Comm.setMailboxListener(mailMethod);

        timer1.start(method(:timerCallback), 1000 * 5, true);
    }

    // Update UI at frequency of timer
    function timerCallback() {
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
	var centerY = (dc.getHeight() - displayHeightOffset) / 2;
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
	var centerY = (dc.getHeight() - displayHeightOffset) / 2;
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
    // @param dc Device context
    function drawHashMarks(dc) {
	var width = dc.getWidth();
	var height = dc.getHeight() - displayHeightOffset;
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
	var screenWidth = dc.getWidth();
	var clockTime = Sys.getClockTime();
	var hourHandAngle;
	var minuteHandAngle;
	var secondHandAngle;

	width = dc.getWidth();
	height = dc.getHeight() - displayHeightOffset;
	// timer runs at every 1 minute
	timer1.stop();
	timer1.start(method(:timerCallback), 60*1000, true);

	// Clear the screen
	dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
	dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

	// Draw lowest rectangle
	dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
	dc.fillRectangle(0, dc.getHeight() - displayHeightOffset, dc.getWidth(), dc.getHeight());

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
    }

    /*******************************************************
     * Receive here the data sent from the Android app
     */
    function onMail(mailIter) {
	var listener = new CommListener();
	var mail;
	var dataArray = [];
	var command = 0;

	mail = mailIter.next();

	// Identify the command sent
	if (mail[0] == HISTORIC_HR_COMMAND) {
	    command = HISTORIC_HR_COMMAND;to know
	} else if (mail[0] == USER_DATA_COMMAND) {
	    command = USER_DATA_COMMAND;
	}

	// Execute the command
	if (command == HISTORIC_HR_COMMAND) {
	    var startDate = mail[2];
	    var date;

	    var HRSensorHistoryIterator = SensorHistory.getHeartRateHistory(
		{
		//Garmin Connect IQ bug?? https://forums.garmin.com/showthread.php?354356-Toybox-SensorHistory-question&highlight=sensorhistory+period
		    //:period => new Toybox.Time.Duration.initialize(5*60)
		    :order => SensorHistory.ORDER_NEWEST_FIRST
		});

	    var HRSample = HRSensorHistoryIterator.next();
	    // Starting building the command response
	    dataArray.add(HISTORIC_HR_COMMAND);
	    dataArray.add(mail[1]); // send back the random ID
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
	} else if (command == USER_DATA_COMMAND) {

	    // Get the parameters from the command
	    var userProfile = UserProfile.getProfile();
	    // Starting building the command response
	    dataArray.add(USER_DATA_COMMAND);
	    dataArray.add(mail[1]); // send back the random ID
	    dataArray.add(userProfile.birthYear);
	    dataArray.add(userProfile.gender);
	    dataArray.add(userProfile.height);
	    dataArray.add(userProfile.weight);
	    dataArray.add(userProfile.activityClass);
	}

	// Transmit command response
	Comm.transmit(dataArray, null, listener);
	Comm.emptyMailbox();
    }

    function storeHR () {
      // get the last date of HR historic stored
      var app = App.getApp();
      historicHRArray = app.getProperty(STORE_PROPERTY_ARRAY_KEY);
      historicHRArrayPointer = app.getProperty(STORE_PROPERTY_ARRAY_POINTER_KEY);

      // get the last date
      var lastDate = historicHRArray[historicHRArrayPointer];

      var HRSensorHistoryIterator = SensorHistory.getHeartRateHistory(
      {to know
      //Garmin Connect IQ bug?? https://forums.garmin.com/showthread.php?354356-Toybox-SensorHistory-question&highlight=sensorhistory+period
	  //:period => new Toybox.Time.Duration.initialize(5*60)
	  :order => SensorHistory.ORDER_OLDEST_FIRST
      });

      var HRSample = HRSensorHistoryIterator.next();
      while (HRSample != null) { // avoid null samples or end of HR historic data
	  date = HRSample.when.value();

	  if (date > lastDate) {

	    var tempHR = HRSample.data;
	    if (tempHR == null && tempHR < 90) { // HR value null or less of 90, keep iterating looking values we want
	      HRSample = HRSensorHistoryIterator.next();
	    } else {
	      // verify if historicHRArrayPointer is at the end
	      if (historicHRArrayPointer == (HISTORIC_HR_ARRAY_SIZE - (HISTORIC_HR_ARRAY_DATA_SIZE * 2)) {
		  historicHRArrayPointer = 0;
	      }

	      historicHRArray[historicHRArrayPointer] = date;
	      historicHRArray[historicHRArrayPointer + HISTORIC_HR_ARRAY_DATA_SIZE] = HRSample.data;
	      historicHRArrayPointer += HISTORIC_HR_ARRAY_DATA_SIZE * 2;

	      HRSample = HRSensorHistoryIterator.next();
	    }

	  } else { // we are at dates that are already stored, keep iterating looking for new dates
	      HRSample = HRSensorHistoryIterator.next();
	  }
      }

      // now save the values
      app.setProperty(STORE_PROPERTY_ARRAY_KEY, historicHRArray);
      app.setProperty(STORE_PROPERTY_ARRAY_POINTER_KEY, historicHRArrayPointer);
    }
}

class CommListener extends Comm.ConnectionListener {
    function initialize() {
        Comm.ConnectionListener.initialize();
    }

    // Sucess to send data to Android app
    function onComplete() {
//	System.println("send ok " + Time.now().value());
    }

    // Fail to send data to Android app
    function onError() {
//	System.println("send er " + Time.now().value());
    }
}


