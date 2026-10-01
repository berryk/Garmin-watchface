/**
 * Complication snapshot for the fitness reporter
 *
 * System complications (body battery, training status, recovery time, race
 * predictors...) are read from the foreground view, at most every 10 minutes,
 * and saved to Storage as "cx" for the background reporter to send.
 */

import Toybox.Application.Storage;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Time;

module ComplicationCache {

    const INTERVAL = 600;

    var _lastRefresh as Number = 0;

    function refresh() as Void {
        if (!(Toybox has :Complications)) {
            return;
        }
        var now = Time.now().value();
        if (now - _lastRefresh < INTERVAL) {
            return;
        }
        _lastRefresh = now;

        var types = {
            "bb" => Complications.COMPLICATION_TYPE_BODY_BATTERY,
            "stress" => Complications.COMPLICATION_TYPE_STRESS,
            "hr" => Complications.COMPLICATION_TYPE_HEART_RATE,
            "spo2" => Complications.COMPLICATION_TYPE_PULSE_OX,
            "resp" => Complications.COMPLICATION_TYPE_RESPIRATION_RATE,
            "recovery" => Complications.COMPLICATION_TYPE_RECOVERY_TIME,
            "trainingStatus" => Complications.COMPLICATION_TYPE_TRAINING_STATUS,
            "vo2Run" => Complications.COMPLICATION_TYPE_VO2MAX_RUN,
            "vo2Bike" => Complications.COMPLICATION_TYPE_VO2MAX_BIKE,
            "intensityMin" => Complications.COMPLICATION_TYPE_INTENSITY_MINUTES,
            "race5k" => Complications.COMPLICATION_TYPE_RACE_PREDICTOR_5K,
            "race10k" => Complications.COMPLICATION_TYPE_RACE_PREDICTOR_10K,
            "raceHalf" => Complications.COMPLICATION_TYPE_RACE_PREDICTOR_HALF_MARATHON,
            "raceMarathon" => Complications.COMPLICATION_TYPE_RACE_PREDICTOR_MARATHON
        };
        var out = {"t" => now};
        var keys = types.keys();
        for (var i = 0; i < keys.size(); i++) {
            try {
                var c = Complications.getComplication(new Complications.Id(types[keys[i]]));
                var v = c.value;
                if (v != null) {
                    out[keys[i]] = (v instanceof Number || v instanceof Float || v instanceof String) ? v : v.toString();
                }
            } catch (e) {
                // Not available on this device
            }
        }
        Storage.setValue("cx", out);
    }
}
