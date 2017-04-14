using Toybox.Application as App;
using Toybox.SensorHistory as SensorHistory;

class BodyFatControl extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
      initEERCals ();
      initPersistentData ();
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
      savePersistentData ();
    }

    // Return the initial view of your application here
    function getInitialView() {
        return [ new BodyFatControl_garmin_watchappView(), new BaseInputDelegate()];
    }
}
