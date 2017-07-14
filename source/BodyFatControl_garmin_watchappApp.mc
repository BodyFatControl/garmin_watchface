using Toybox.Application as App;
using Toybox.SensorHistory as SensorHistory;
using Toybox.Communications as Comm;

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
        return [ new BodyFatControl_garmin_watchappView(), new BaseInputDelegate()];
    }

    /*******************************************************
     * Receive here the data sent from the Android app
     */
    function onPhone(msg) {
      if (sendCommBusy == false) { // we just can send data if Comm is not busy, so ignore received command while Comm is busy
        var dataArray = [];

        // Execute the command
        if (msg.data[0] == HISTORIC_CALS_COMMAND) {
          dataArray.add(HISTORIC_CALS_COMMAND);
          var date = calsArrayEndTime; // date from last minute stored in calsArray
          dataArray.add(date);
          dataArray.add(EERCalsPerMinute);
          var startDate = msg.data[1]; // date comes already in minutes
          if (startDate < (date - CALS_ARRAY_SIZE)) { startDate = date - CALS_ARRAY_SIZE; }
          var count = date - startDate;
          var index = calsArrayEndPos;
          if (count > CALS_ARRAY_SIZE) {count = CALS_ARRAY_SIZE;}
          if (count < 0) { count = 0;}

          // now prepare the array with the data
          while (count) {
    	count--;
    	dataArray.add(calsArray[index]);
            if (index == 0) { index = CALS_ARRAY_SIZE - 1; }
            else { index--; }
          }

          // Transmit command response
          sendCommBusy = true;
          Comm.transmit(dataArray, null, commListener);

        } else if (msg.data[0] == USER_DATA_COMMAND) {
          // Get the parameters from the command
          // Starting building the command response
          dataArray.add(USER_DATA_COMMAND);
          dataArray.add(userProfile.birthYear);
          dataArray.add(userProfile.gender);
          dataArray.add(userProfile.height);
          dataArray.add(userProfile.weight);
          dataArray.add(userProfile.activityClass);
          // Transmit command response
          sendCommBusy = true;
          Comm.transmit(dataArray, null, commListener);

        } else if (msg.data[0] == CALORIES_CONSUMED_COMMAND) {
          caloriesConsumed = msg.data[1];
          Ui.requestUpdate();
        }
      }
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
        stopSportMode();
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

    function disableHRSensor() {
      Sensor.setEnabledSensors([]);
      Sensor.enableSensorEvents();
      HRSensorEnable = false;
    }
}
