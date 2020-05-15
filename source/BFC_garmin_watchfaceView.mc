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

var timer1 = new Timer.Timer();
var HR_value = 0;
var HRSensorEnable = false;
var sport_mode = false;
const SPORT_MODE_MIN_TIME = 60; // in 10 seconds
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

var caloriesBalance = 0;
var caloriesBalanceScale = 1;

var secondsCounter = 60;

// Seems a Garmin bug, because UTC time is UTC 00:00 Dec 31 1989
//Unix UTC time: 1 January 1970
//Garmin UTC time: 31 December 1989
const GARMIN_UTC_OFFSET = ((1990 - 1970) * Time.Gregorian.SECONDS_PER_YEAR) - Time.Gregorian.SECONDS_PER_DAY;

const CUSTOM_FONT = false; // true to use the customFont but code needs to be built on Windows only :-(

class BFC_garmin_watchappView extends Ui.View {

  function CalcHRZones() {
    var currentYear = (Time.now().value() / Time.Gregorian.SECONDS_PER_YEAR) + 1970;
    var userProfile = UserProfile.getProfile();
    zone_HR_max = 220 - (currentYear - userProfile.birthYear); // HRMax = 220 - UserAge
    zone_HR_min = zone_HR_max / 2;

    zone_HR_m_calc = (148.0 - INDICATOR_WIDTH) / (zone_HR_max - zone_HR_min); // screenWidth = 148 on VivoActive HR
  }

  function initialize() {
    View.initialize();

    CalcHRZones();

    if (CUSTOM_FONT == true) {
      customFont = Ui.loadResource(Rez.Fonts.roboto_bold_36);
    } else {
      customFont = Graphics.FONT_LARGE;
    }

//    timer1.start(method(:timer1Callback), 60*1000, true);
    timer1.start(method(:timer1Callback), 1*1000, true);
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

    secondsCounter++;
    if (secondsCounter >= 60) {
      secondsCounter = 0;

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
      if (sport_mode == false) {
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
      } else {
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
      }
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
      if (sport_mode == false) {
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
      } else {
        dc.setColor(COLOR_GRAY_1, Gfx.COLOR_TRANSPARENT);
      }
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
      if (sport_mode == false) {
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
      }
      else {
        dc.setColor(COLOR_GRAY_1, Gfx.COLOR_TRANSPARENT);
      }
      dc.fillCircle(width / 2, height / 2, 5);
      dc.drawCircle(width / 2, height / 2, 5);
    }

    if (sport_mode == true) {

      if (onSensorHRCounter > 0) {
        onSensorHRCounter--;
      }

      if (onSensorHRCounter > 0) {
        sport_mode = true;
        secondsCounter = 60;
      } else if (HR_value < 90) {
        sport_mode = false;
        secondsCounter = 60;
      } else {
        sport_mode = true;
        secondsCounter = 60;
      }

      HR_value = Sensor.getInfo().heartRate;
      if (HR_value == null) {
        HR_value = 0;
      }

      if (HR_value >= 90) {
        sport_mode = true;
        onSensorHRCounter = SPORT_MODE_MIN_TIME;
      }


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
    }
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

  function onBack() {
    if (sport_mode == true) { // exit the sport mode
      onSensorHRCounter = 0;
      sport_mode = false;
      secondsCounter = 60;
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
      sport_mode = true;
      secondsCounter = 60;
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
