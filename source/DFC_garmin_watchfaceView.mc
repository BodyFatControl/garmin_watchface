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

class DFC_garmin_watchappView extends Ui.View {
    var isAwake = false;
    const displayHeightOffset = 57;

    function initialize() {
	View.initialize();

        mailMethod = method(:onMail);
        Comm.setMailboxListener(mailMethod);
    }

    // Update UI at frequency of timer
    function timerCallback() {
        Ui.requestUpdate();

//        sendHR();
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));

        timer1.start(method(:timerCallback), 1000 * 5, true);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
	var font = Graphics.FONT_LARGE;
	var width;
	var height;
	var clockTime = Sys.getClockTime();

	width = dc.getWidth();
	height = dc.getHeight();

	// Clear the screen
	dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
	dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

	// Draw the numbers
	dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
	dc.drawText((width / 2), (height/2), font, clockTime.sec, Gfx.TEXT_JUSTIFY_CENTER);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // Receive here the data sent from the Android app
    function onMail(mailIter) {
	var listener = new CommListener();
	var mail;
	var dataArray = [];
	var command = 0;

	mail = mailIter.next();

	// Identify command
	if (mail[0] == HISTORIC_HR_COMMAND) {
	    command = HISTORIC_HR_COMMAND;
	} else if (mail[0] == USER_DATA_COMMAND) {
	    command = USER_DATA_COMMAND;
	}

	// Execute command
	if (command == HISTORIC_HR_COMMAND) {
//	    // Get the parameters from the command
//	    var random_id = mailIter.next();
//	    var interval = mailIter.next(); // interval in minutes
//	    var HRSensorHistoryIterator = SensorHistory.getHeaUSER_DATA_COMMANDrtRateHistory(
//		{
//		    :period => duration,
//		    :order => SensorHistory.ORDER_NEWEST_FIRST
//		});
//
//	    var when = HRSensorHistoryIterator.next().when();
//	    var hrValue = HRSensorHistoryIterator.next().data();
//
//
//	    // Starting building the command response
//	    dataArray.add(HISTORIC_HR_COMMAND);
//	    dataArray.add(random_id);
//
//	    while (hrValue != null) {
//		dataArray.add(when);
//		dataArray.add(hrValue);
//
//		var when = HRSensorHistoryIterator.next().when();
//		var hrValue = HRSensorHistoryIterator.next().data();
//	    }
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


