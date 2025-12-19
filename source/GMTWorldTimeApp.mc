/**
 * GMT World Time Watchface Application
 * 
 * A simple, clear watchface that displays:
 * - Current time (hours and minutes)
 * - Day and date
 * - Bluetooth connection status
 * - Step count
 * - 4 configurable world time zones
 * 
 * Compatible with all Connect IQ devices.
 */

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

/**
 * Main application class
 */
class GMTWorldTimeApp extends Application.AppBase {

    private var _view as GMTWorldTimeView?;

    /**
     * Constructor
     */
    function initialize() {
        AppBase.initialize();
    }

    /**
     * Called when application starts
     * @return Initial view for the application
     */
    function getInitialView() as [Views] or [Views, InputDelegates] {
        _view = new GMTWorldTimeView();
        return [_view];
    }

    /**
     * Called when settings are changed in Garmin Connect
     */
    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.loadSettings();
        }
        WatchUi.requestUpdate();
    }

    /**
     * Called when watch enters sleep mode
     */
    function onEnterSleep() as Void {
    }

    /**
     * Called when watch exits sleep mode
     */
    function onExitSleep() as Void {
    }
}
