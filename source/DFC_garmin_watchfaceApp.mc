using Toybox.Application as App;

class DFC extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
      initStorage();
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
      saveStorage();
    }

    // Return the initial view of your application here
    function getInitialView() {
        return [ new DFC_garmin_watchappView(), new BaseInputDelegate()];
    }
}
