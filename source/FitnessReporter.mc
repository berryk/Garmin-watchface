/**
 * Background fitness reporter
 *
 * Runs in the watch face's background process and POSTs what Connect IQ exposes
 * (daily counters, 7-day history, heart rate / stress / body battery / SpO2 history,
 * profile, recent activities and the complication snapshot cached by the view)
 * to the report endpoint. The request goes through Garmin Connect on the phone,
 * so it works while the phone is locked.
 *
 * The endpoint replies with the Unix time of the next check-in, which the app
 * uses to schedule the next temporal event. Endpoint and token are the hidden
 * ReportUrl / ReportToken properties; reporting is off while either is empty.
 */

import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;

(:background)
class FitnessReporter extends System.ServiceDelegate {

    // Longest window of history sent in one report, and the sample spacing within it
    private const MAX_WINDOW = 6 * 3600;
    private const STEP = 300;

    private var _now as Number = 0;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        report("scheduled");
    }

    function onWakeTime() as Void {
        report("wake");
    }

    function onActivityCompleted(activity as {:sport as Activity.Sport, :subSport as Activity.SubSport}) as Void {
        report("activity");
    }

    /**
     * Collects everything and sends it; Background.exit() happens in onResponse
     */
    private function report(trigger as String) as Void {
        var url = Properties.getValue("ReportUrl");
        var token = Properties.getValue("ReportToken");
        if (!(url instanceof String) || !(token instanceof String) || url.length() == 0 || token.length() == 0) {
            Background.exit({"code" => -1, "trigger" => trigger});
            return;
        }

        _now = Time.now().value();
        var since = Storage.getValue("lastReport");
        if (!(since instanceof Number) || _now - since > MAX_WINDOW) {
            since = _now - MAX_WINDOW;
        }

        var body = {
            "v" => 1,
            "t" => _now,
            "trigger" => trigger,
            "since" => since,
            "day" => dayInfo(),
            "hist" => history(),
            "profile" => profile(),
            "acts" => activities(),
            "hr" => series(:hr, since),
            "stress" => series(:stress, since),
            "bb" => series(:bb, since),
            "spo2" => series(:spo2, since)
        };
        var cx = Storage.getValue("cx");
        if (cx != null) {
            body["cx"] = cx;
        }

        Communications.makeWebRequest(url, body, {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Authorization" => "Bearer " + token
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        var result = {"code" => code, "t" => _now};
        if (code == 200 && data instanceof Dictionary && data["next"] instanceof Number) {
            result["next"] = data["next"];
        }
        Background.exit(result);
    }

    /**
     * Today's counters. Fields missing on this device, or not yet known, are left out
     */
    private function dayInfo() as Dictionary {
        var d = {};
        var i = ActivityMonitor.getInfo();
        put(d, "steps", i.steps);
        put(d, "stepGoal", i.stepGoal);
        put(d, "cal", i.calories);
        put(d, "distCm", i.distance);
        if (i has :floorsClimbed) {
            put(d, "floorsUp", i.floorsClimbed);
            put(d, "floorsDown", i.floorsDescended);
        }
        if (i has :activeMinutesDay && i.activeMinutesDay != null) {
            d["actMinDay"] = [i.activeMinutesDay.total, i.activeMinutesDay.moderate, i.activeMinutesDay.vigorous];
        }
        if (i has :activeMinutesWeek && i.activeMinutesWeek != null) {
            put(d, "actMinWeek", i.activeMinutesWeek.total);
            put(d, "actMinWeekGoal", i.activeMinutesWeekGoal);
        }
        if (i has :stressScore) { put(d, "stress", i.stressScore); }
        if (i has :respirationRate) { put(d, "resp", i.respirationRate); }
        if (i has :timeToRecovery) { put(d, "recoveryH", i.timeToRecovery); }
        if (i has :moveBarLevel) { put(d, "moveBar", i.moveBarLevel); }
        return d;
    }

    /**
     * Last 7 days: [startOfDay, steps, calories, distanceCm, floorsUp, activeMinutes]
     */
    private function history() as Array {
        var out = [];
        var h = ActivityMonitor.getHistory();
        for (var n = 0; n < h.size(); n++) {
            var e = h[n];
            out.add([
                e.startOfDay != null ? e.startOfDay.value() : -1,
                num(e.steps), num(e.calories), num(e.distance),
                (e has :floorsClimbed) ? num(e.floorsClimbed) : -1,
                (e has :activeMinutes && e.activeMinutes != null) ? num(e.activeMinutes.total) : -1
            ]);
        }
        return out;
    }

    private function profile() as Dictionary {
        var d = {};
        var p = UserProfile.getProfile();
        put(d, "rhr", p.restingHeartRate);
        if (p has :averageRestingHeartRate) { put(d, "avgRhr", p.averageRestingHeartRate); }
        put(d, "vo2Run", p.vo2maxRunning);
        put(d, "vo2Bike", p.vo2maxCycling);
        put(d, "weightG", p.weight);
        return d;
    }

    /**
     * Activities from the last two days: [start, durationS, distanceM, type]
     */
    private function activities() as Array {
        var out = [];
        if (!(UserProfile has :getUserActivityHistory)) {
            return out;
        }
        var it = UserProfile.getUserActivityHistory();
        var a = it.next();
        while (a != null) {
            var start = a.startTime != null ? a.startTime.value() : -1;
            if (start >= _now - 2 * 86400) {
                out.add([start, a.duration != null ? a.duration.value() : -1, num(a.distance), num(a.type)]);
            }
            a = it.next();
        }
        return out;
    }

    /**
     * Flat [time, value, time, value, ...] from `since`, at most one sample per STEP seconds
     */
    private function series(kind as Symbol, since as Number) as Array {
        var out = [];
        var opts = {:period => new Time.Duration(_now - since), :order => SensorHistory.ORDER_OLDEST_FIRST};
        var it = null;
        if (kind == :hr && SensorHistory has :getHeartRateHistory) {
            it = SensorHistory.getHeartRateHistory(opts);
        } else if (kind == :stress && SensorHistory has :getStressHistory) {
            it = SensorHistory.getStressHistory(opts);
        } else if (kind == :bb && SensorHistory has :getBodyBatteryHistory) {
            it = SensorHistory.getBodyBatteryHistory(opts);
        } else if (kind == :spo2 && SensorHistory has :getOxygenSaturationHistory) {
            it = SensorHistory.getOxygenSaturationHistory(opts);
        }
        if (it == null) {
            return out;
        }
        var last = 0;
        var s = it.next();
        while (s != null) {
            if (s.data != null && s.when != null) {
                var t = s.when.value();
                if (t - last >= STEP) {
                    out.add(t);
                    out.add(s.data.toNumber());
                    last = t;
                }
            }
            s = it.next();
        }
        return out;
    }

    private function put(d as Dictionary, key as String, value) as Void {
        if (value != null) {
            d[key] = value;
        }
    }

    private function num(value) as Number or Float {
        return value == null ? -1 : value;
    }
}
