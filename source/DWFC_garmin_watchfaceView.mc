using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;

class DWFC_garmin_watchfaceView extends Ui.WatchFace {
    var isAwake = false;
    const displayHeightOffset = 57;

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

    function drawSecondsHand(dc, angle) {
	// Map out the coordinates of the watch hand
	var coords = [
		      [  -1,  24],
		      [  -1, -64],
		      [   1, -64],
		      [   1,  24]
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

	var now = Time.now();

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

	// Draw the second
	if (isAwake) {
	    dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
	    secondHandAngle = (clockTime.sec / 60.0) * Math.PI * 2;
	    drawSecondsHand(dc, secondHandAngle);
	}

	// Draw the arbor
	dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
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
