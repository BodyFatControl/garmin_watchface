using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

class TestApp extends Ui.View
{
    //! Constructor
    function initialize()
    {
        View.initialize();
        Ui.requestUpdate();
    }

    //! Handle the update event
    function onUpdate(dc)
    {
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT );

        dc.drawText(50, 50, Gfx.FONT_LARGE, "test battery", Gfx.TEXT_JUSTIFY_CENTER);
    }
}

//! main is the primary start point for a Monkeybrains application
class Test extends App.AppBase
{
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state)
    {
        return false;
    }

    function getInitialView()
    {
        return [new TestApp()];
    }

    function onStop(state)
    {
        return false;
    }
}
