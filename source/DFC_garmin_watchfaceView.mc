using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Communications as Comm;
using Toybox.Timer as Timer;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.SensorHistory as SensorHistory;
using Toybox.Time as Time;

var mailMethod;
var timer1 = new Timer.Timer();

var clockTime = Sys.getClockTime();

const HISTORIC_HR_COMMAND = 0xFFFFA000;
const USER_DATA_COMMAND = 0xFFFF0B00;

class DFC_garmin_watchappView extends Ui.WatchFace {
    var isAwake = false;
    const displayHeightOffset = 57;

    function initialize() {
        WatchFace.initialize();

        mailMethod = method(:onMail);
        Comm.setMailboxListener(mailMethod);
    }

    // Update UI at frequency of timer
    function timerCallback() {
        Ui.requestUpdate();

        var duration = new Time.Duration(60*60);
        System.println("duration " + duration.value());


	var HRSensorHistoryIterator = SensorHistory.getHeartRateHistory(
	    {
//		:period => (Time.now().value() - 2), /* 1h */
//		:period => duration.value(),
		:period => 30*60,
		:order => SensorHistory.ORDER_NEWEST_FIRST
	    });

	var HRSample = HRSensorHistoryIterator.next();
	var dataArray = []; // array size will be increased as needed using .add()

	// Starting building the command response
	dataArray.add(HISTORIC_HR_COMMAND);
	dataArray.add(HISTORIC_HR_COMMAND);
	while (HRSample != null) {

	    dataArray.add(HRSample.when.value());
	    dataArray.add(HRSample.data);

	    HRSample = HRSensorHistoryIterator.next();
	}

	System.println("timeNow " + Time.now().value());
	System.println("dataArray " + dataArray);

//	// Transmit command response
//	Comm.transmit(dataArray, null, listener);
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

	Comm.setMailboxListener(mailMethod);
	var listener = new CommListener();

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

    function onEnterSleep() {
    }

    function onExitSleep() {
    }

    // Receive here the data sent from the Android app
    function onMail(mailIter) {
	Comm.emptyMailbox();
    }
}

class CommListener extends Comm.ConnectionListener {
    function initialize() {
        Comm.ConnectionListener.initialize();
    }

    // Sucess to send data to Android app
    function onComplete() {
	System.println("send ok " + Time.now());
    }

    // Fail to send data to Android app
    function onError() {
	System.println("send er " + Time.now());
    }
}
