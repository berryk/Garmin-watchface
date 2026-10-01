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
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

/**
 * Main application class. Loaded in the background process too, for FitnessReporter
 */
(:background)
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
        startReporting();
        return [_view];
    }

    /**
     * Background process entry point
     */
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new FitnessReporter()];
    }

    /**
     * Result of a background report: remember it and schedule the next one
     * at the time the endpoint asked for (or retry in 15 minutes on failure)
     */
    function onBackgroundData(data as Application.PersistableType) as Void {
        var now = Time.now().value();
        var next = now + 900;
        if (data instanceof Dictionary) {
            Storage.setValue("lastResult", data);
            if (data["code"] == 200) {
                Storage.setValue("lastReport", data["t"]);
            }
            if (data["next"] instanceof Number) {
                next = data["next"];
            }
            if (data["code"] == -1) {
                return; // Not configured
            }
        }
        scheduleReport(next);
    }

    /**
     * Wake-time and activity-completed reports, plus a first scheduled report
     * if nothing is registered (a new install, or the chain was broken)
     */
    private function startReporting() as Void {
        if (!(Toybox has :Background)) {
            return;
        }
        if (Background has :registerForWakeEvent) {
            Background.registerForWakeEvent();
        }
        if (Background has :registerForActivityCompletedEvent) {
            Background.registerForActivityCompletedEvent();
        }
        if (Background.getTemporalEventRegisteredTime() == null) {
            scheduleReport(Time.now().value() + 60);
        }
    }

    /**
     * Temporal events must be at least 5 minutes apart
     */
    private function scheduleReport(at as Number) as Void {
        var last = Background.getLastTemporalEventTime();
        if (last != null && at < last.value() + 300) {
            at = last.value() + 300;
        }
        Background.registerForTemporalEvent(new Time.Moment(at));
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
