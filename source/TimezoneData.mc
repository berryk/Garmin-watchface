/**
 * Timezone Data Model
 *
 * Manages timezone information with smart caching.
 * Stores offset data and validity timestamps to minimize API calls.
 */

import Toybox.Lang;
import Toybox.System;
import Toybox.Application.Storage;
import Toybox.Time;

/**
 * Helper function to map timezone ID to timezone string
 * @param zoneId Numeric timezone ID (0-20)
 * @return Timezone string for WorldTimeAPI
 */
function getTimezoneString(zoneId as Number) as String {
    switch (zoneId) {
        case 0: return "Europe/London";
        case 1: return "Europe/Paris";
        case 2: return "Europe/Berlin";
        case 3: return "Europe/Moscow";
        case 4: return "America/New_York";
        case 5: return "America/Chicago";
        case 6: return "America/Denver";
        case 7: return "America/Los_Angeles";
        case 8: return "America/Mexico_City";
        case 9: return "America/Sao_Paulo";
        case 10: return "Asia/Dubai";
        case 11: return "Asia/Kolkata";
        case 12: return "Asia/Singapore";
        case 13: return "Asia/Hong_Kong";
        case 14: return "Asia/Tokyo";
        case 15: return "Asia/Shanghai";
        case 16: return "Australia/Sydney";
        case 17: return "Pacific/Auckland";
        case 18: return "Pacific/Honolulu";
        case 19: return "Africa/Johannesburg";
        case 20: return "Europe/Vienna";
        default: return "Europe/London"; // Fallback to London
    }
}

/**
 * Data structure for a single timezone
 */
class TimezoneInfo {
    public var id as String;              // API timezone ID (e.g., "Europe/London")
    public var offset as Number;          // Total offset from UTC in seconds
    public var dst as Boolean;            // Currently in DST?
    public var nextChange as Long;        // UTC timestamp of next DST transition (0 if unknown)
    public var label as String;           // Display label (e.g., "LN")
    public var lastUpdate as Long;        // UTC timestamp of last successful API fetch

    /**
     * Constructor
     * @param zoneId Timezone identifier (e.g., "Europe/London")
     * @param displayLabel User-specified display label
     */
    function initialize(zoneId as String, displayLabel as String) {
        id = zoneId;
        label = displayLabel;
        offset = 0;
        dst = false;
        nextChange = 0L;
        lastUpdate = 0L;
    }

    /**
     * Check if cached data is stale and needs refresh
     * @return True if data should be refreshed
     */
    function isStale() as Boolean {
        var now = Time.now().value();

        // No data yet
        if (lastUpdate == 0) {
            return true;
        }

        // Past the predicted transition time
        if (nextChange > 0 && now > nextChange) {
            return true;
        }

        // Force refresh after 24 hours regardless
        var dayInSeconds = 86400;
        if (now - lastUpdate > dayInSeconds) {
            return true;
        }

        return false;
    }

    /**
     * Apply heuristic DST prediction when offline past transition time
     * Standard DST rule: flip DST flag and adjust offset by +/- 1 hour
     */
    function applyPrediction() as Void {
        // Flip DST status
        dst = !dst;

        // Adjust offset by 1 hour (3600 seconds)
        if (dst) {
            offset += 3600; // Entering DST
        } else {
            offset -= 3600; // Leaving DST
        }

        // Clear next change time to force refresh on next opportunity
        nextChange = 0L;
    }

    /**
     * Get current hour in this timezone
     * @param clockTime Current device clock time
     * @return Hour in this timezone (0-23)
     */
    function getHour(clockTime as System.ClockTime) as Number {
        // Calculate UTC from local time
        var localOffset = clockTime.timeZoneOffset;
        var localSeconds = clockTime.hour * 3600 + clockTime.min * 60 + clockTime.sec;
        var utcSeconds = localSeconds - localOffset;

        // Add this timezone's offset
        var targetSeconds = utcSeconds + offset;

        // Handle day wraparound
        if (targetSeconds < 0) {
            targetSeconds += 86400;
        } else if (targetSeconds >= 86400) {
            targetSeconds -= 86400;
        }

        // Extract hour
        var hour = (targetSeconds / 3600).toNumber();

        // Ensure valid range
        if (hour < 0) {
            hour += 24;
        } else if (hour >= 24) {
            hour -= 24;
        }

        return hour;
    }
}

/**
 * Manager class for all timezone data
 */
class TimezoneDataManager {
    /**
     * Save timezone info to persistent storage
     * @param cityNum City number (1-4)
     * @param info Timezone info to save
     */
    static function saveTimezoneInfo(cityNum as Number, info as TimezoneInfo) as Void {
        var key = "timezone_data_" + cityNum.toString();

        // Store as dictionary for persistence
        var data = {
            "id" => info.id,
            "offset" => info.offset,
            "dst" => info.dst,
            "nextChange" => info.nextChange,
            "label" => info.label,
            "lastUpdate" => info.lastUpdate
        };

        Storage.setValue(key, data);
    }

    /**
     * Load timezone info from persistent storage
     * @param cityNum City number (1-4)
     * @param zoneId Timezone ID (fallback if no stored data)
     * @param displayLabel Display label (fallback if no stored data)
     * @return Loaded or newly created TimezoneInfo
     */
    static function loadTimezoneInfo(cityNum as Number, zoneId as String, displayLabel as String) as TimezoneInfo {
        var key = "timezone_data_" + cityNum.toString();
        var data = Storage.getValue(key);

        var info = new TimezoneInfo(zoneId, displayLabel);

        if (data != null && data instanceof Dictionary) {
            // Restore from storage
            var id = data.get("id");
            if (id != null && id instanceof String) {
                info.id = id;
            }

            var offset = data.get("offset");
            if (offset != null && offset instanceof Number) {
                info.offset = offset;
            }

            var dst = data.get("dst");
            if (dst != null && dst instanceof Boolean) {
                info.dst = dst;
            }

            var nextChange = data.get("nextChange");
            if (nextChange != null && nextChange instanceof Long) {
                info.nextChange = nextChange;
            }

            var label = data.get("label");
            if (label != null && label instanceof String) {
                info.label = label;
            }

            var lastUpdate = data.get("lastUpdate");
            if (lastUpdate != null && lastUpdate instanceof Long) {
                info.lastUpdate = lastUpdate;
            }
        }

        return info;
    }

    /**
     * Clear all stored timezone data
     */
    static function clearAllData() as Void {
        for (var i = 1; i <= 4; i++) {
            var key = "timezone_data_" + i.toString();
            Storage.deleteValue(key);
        }
    }
}
