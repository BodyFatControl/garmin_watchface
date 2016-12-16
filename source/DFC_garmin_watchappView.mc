using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Communications as Comm;
using Toybox.Timer as Timer;

var mailMethod;
var timer1;

class DFC_garmin_watchappView extends Ui.WatchFace {

    function initialize() {
        WatchFace.initialize();

        mailMethod = method(:onMail);
        Comm.setMailboxListener(mailMethod);
    }

    // Update UI at frequency of timer
    function timerCallback() {
        Ui.requestUpdate();
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));

        timer1 = new Timer.Timer();
        // every 5000ms = 5s
        timer1.start(method(:timerCallback), 5000, true);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
	Comm.setMailboxListener(mailMethod);
	var listener = new CommListener();

	var font = Graphics.FONT_LARGE;
	var clockTime = Sys.getClockTime();

	// Clear the screen
	dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
	dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

	// Write teh seconds on the screen
	dc.drawText(dc.getWidth()/2, dc.getHeight()/2, font, clockTime.sec, Gfx.TEXT_JUSTIFY_CENTER);

	// Send the seconds
	Comm.transmit(clockTime.sec, null, listener);
	System.println(clockTime.sec);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    function onEnterSleep() {
	Ui.requestUpdate();
    }

    function onExitSleep() {
	timer1.stop();
    }

    function onMail(mailIter) {
	Comm.emptyMailbox();
    }
}

class CommListener extends Comm.ConnectionListener {
    function initialize() {
        Comm.ConnectionListener.initialize();
    }

    function onComplete() {
//        Sys.println("Transmit Complete");
    }

    function onError() {
//        Sys.println("Transmit Failed");
    }
}
