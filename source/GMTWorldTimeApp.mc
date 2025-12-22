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
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Background;
import Toybox.Time;

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
        System.println("****************************************");
        System.println("APP: onSettingsChanged() called");
        System.println("****************************************");
        
        if (_view != null) {
            System.println("APP: Reloading view settings...");
            _view.loadSettings();
        } else {
            System.println("APP: WARNING - View is null!");
        }

        // Trigger background update to fetch new timezone data
        System.println("APP: Registering background temporal event (5 minutes)...");
        Background.registerForTemporalEvent(new Time.Duration(300)); // 5 minutes minimum

        System.println("APP: Requesting UI update...");
        WatchUi.requestUpdate();
        System.println("APP: onSettingsChanged() completed");
        System.println("****************************************");
    }

    /**
     * Called when background data is available
     * @param data Background data
     */
    function onBackgroundData(data as Application.PersistableType) as Void {
        System.println("****************************************");
        System.println("APP: onBackgroundData() called");
        System.println("APP: Data received: " + data);
        System.println("****************************************");
        
        // Background service has updated timezone data
        // Reload settings to get fresh data
        if (_view != null) {
            System.println("APP: Reloading view with new background data...");
            _view.loadSettings();
        } else {
            System.println("APP: WARNING - View is null!");
        }
        
        System.println("APP: Requesting UI update...");
        WatchUi.requestUpdate();
        System.println("APP: onBackgroundData() completed");
        System.println("****************************************");
    }

    /**
     * Get the background service delegate
     * @return Service delegate instance
     */
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new WorldTimeBackgroundService()];
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
