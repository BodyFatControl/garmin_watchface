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
using Toybox.Attention as Attention;

var bodyFatControl_garmin_watchappView;

class BodyFatControl extends App.AppBase {

  function initialize() {
      AppBase.initialize();
  }

  // onStart() is called on application start up
  function onStart(state) {
    initEERCals ();
    initPersistentData ();

    // Enable communications
    phoneMethod = method(:onPhone);
    Comm.registerForPhoneAppMessages(phoneMethod);
  }

  // onStop() is called when your application is exiting
  function onStop(state) {
    savePersistentData ();
  }

  // Return the initial view of your application here
  function getInitialView() {
    bodyFatControl_garmin_watchappView = new BodyFatControl_garmin_watchappView ();
    return [bodyFatControl_garmin_watchappView, new BaseInputDelegate()];
  }

  function onSensorHR(sensor_info)
  {
    if (onSensorHRCounter > 0) { onSensorHRCounter--; }

    var HR = sensor_info.heartRate; // get the current HR value
    if(HR == null) {
      HR_value = 0;
    } else {
      HR_value = HR;
    }

    if (onSensorHRCounter > 0) { // continue in sport mode, not timeout yet
      sport_mode = true;
    } else if (HR_value < 90) { // stop the sport mode, HR lower than 90
      bodyFatControl_garmin_watchappView.stopSportMode();
    } else {  // continue in sport mode, HR still higher or equal than 90
      sport_mode = true;
    }

    if (HR_value >= 90) { // continue in sport mode, HR still higher or equal than 90, reset the counter for timeout
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
}
