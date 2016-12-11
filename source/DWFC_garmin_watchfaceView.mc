using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;

class DWFC_garmin_watchfaceView extends Ui.WatchFace {
    var isAwake = false;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Draw the watch hand
    // @param dc Device Context to Draw
    // @param angle Angle to draw the watch hand
    // @param length Length of the watch hand
    // @param width Width of the watch hand
    function drawHand(dc, angle, length, width) {
	// Map out the coordinates of the watch hand
	var coords = [[-(width / 2),0], [-(width / 2), -length], [width / 2, -length], [width / 2, 0]];
	var result = new [4];
	var centerX = dc.getWidth() / 2;
	var centerY = dc.getHeight() / 2;
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
	dc.fillPolygon(result);
    }

    // Draw the hash mark symbols on the watch
    // @param dc Device context
    function drawHashMarks(dc) {
	var width = dc.getWidth();
	var height = dc.getHeight();
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
	var hourHand;
	var minuteHand;
	var secondHand;
	var secondTail;

	width = dc.getWidth();
	height = dc.getHeight();

	var now = Time.now();

	// Clear the screen
	dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
	dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

	// Draw the numbers
	dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
	dc.drawText((width / 2), 2, font, "12", Gfx.TEXT_JUSTIFY_CENTER);
	dc.drawText(width - 2, (height / 2) - 15, font, "3", Gfx.TEXT_JUSTIFY_RIGHT);
	dc.drawText(width / 2, height - 30, font, "6", Gfx.TEXT_JUSTIFY_CENTER);
	dc.drawText(2, (height / 2) - 15, font, "9", Gfx.TEXT_JUSTIFY_LEFT);

	// Draw the hash marks
	drawHashMarks(dc);

	// Draw the hour. Convert it to minutes and compute the angle.
	hourHand = (((clockTime.hour % 12) * 60) + clockTime.min);
	hourHand = hourHand / (12 * 60.0);
	hourHand = hourHand * Math.PI * 2;
	drawHand(dc, hourHand, 40, 5);

	// Draw the minute
	minuteHand = (clockTime.min / 60.0) * Math.PI * 2;
	drawHand(dc, minuteHand, 70, 4);

	// Draw the second
	if (isAwake) {
	    dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
	    secondHand = (clockTime.sec / 60.0) * Math.PI * 2;
	    secondTail = secondHand - Math.PI;
	    drawHand(dc, secondHand, 60, 2);
	    drawHand(dc, secondTail, 20, 2);
	}

	// Draw the arbor
	dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_BLACK);
	dc.fillCircle(width / 2, height / 2, 5);
	dc.setColor(Gfx.COLOR_BLACK,Gfx.COLOR_BLACK);
	dc.drawCircle(width / 2, height / 2, 5);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    function onEnterSleep() {
	isAwake = false;
	Ui.requestUpdate();
    }

    function onExitSleep() {
	isAwake = true;
    }

}
