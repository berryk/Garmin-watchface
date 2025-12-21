/**
 * World Time Background Service
 *
 * Fetches timezone data from WorldTimeAPI in the background.
 * Implements daisy-chain fetching to handle multiple timezones sequentially.
 */

import Toybox.Lang;
import Toybox.Background;
import Toybox.System;
import Toybox.Communications;
import Toybox.Application.Properties;
import Toybox.Time;

/**
 * Service delegate for background data fetching
 */
(:background)
class WorldTimeBackgroundService extends System.ServiceDelegate {

    // Current city being fetched (for callback tracking)
    private var currentCityNum as Number = 1;

    /**
     * Constructor
     */
    function initialize() {
        ServiceDelegate.initialize();
    }

    /**
     * Temporal event callback - called periodically by the system
     * @param info Temporal event information
     */
    function onTemporalEvent() as Void {
        // Start fetching from City 1
        fetchTimezoneData(1);
    }

    /**
     * Fetch timezone data for a specific city
     * @param cityNum City number (1-4)
     */
    function fetchTimezoneData(cityNum as Number) as Void {
        if (cityNum > 4) {
            // All cities processed, exit
            Background.exit(null);
            return;
        }

        // Get timezone ID from properties
        var zoneKey = "City" + cityNum.toString() + "Zone";
        var labelKey = "City" + cityNum.toString() + "Label";

        var zoneId = Properties.getValue(zoneKey);
        var label = Properties.getValue(labelKey);

        if (zoneId == null || !(zoneId instanceof String) || zoneId.equals("")) {
            // No timezone configured, skip to next
            fetchTimezoneData(cityNum + 1);
            return;
        }

        if (label == null || !(label instanceof String)) {
            label = "";
        }

        // Load existing data to check if refresh needed
        var info = TimezoneDataManager.loadTimezoneInfo(cityNum, zoneId as String, label as String);

        if (!info.isStale()) {
            // Data is still fresh, skip to next
            fetchTimezoneData(cityNum + 1);
            return;
        }

        // Build API URL
        var url = "http://worldtimeapi.org/api/timezone/" + zoneId;

        // Store current city number for callback
        currentCityNum = cityNum;

        // Make HTTP request
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            url,
            null,
            options,
            method(:onReceiveTimezoneData)
        );
    }

    /**
     * Callback for timezone data response
     * @param responseCode HTTP response code
     * @param data Response data
     */
    function onReceiveTimezoneData(responseCode as Number, data as Dictionary?) as Void {
        var cityNum = currentCityNum;

        if (responseCode == 200 && data != null) {
            // Parse response
            parseAndSaveTimezoneData(cityNum, data);
        }

        // Continue to next city regardless of success/failure
        // (keeping old data if fetch failed)
        fetchTimezoneData(cityNum + 1);
    }

    /**
     * Parse API response and save timezone data
     * @param cityNum City number (1-4)
     * @param data API response data
     */
    function parseAndSaveTimezoneData(cityNum as Number, data as Dictionary) as Void {
        try {
            // Get timezone ID and label from properties
            var zoneKey = "City" + cityNum.toString() + "Zone";
            var labelKey = "City" + cityNum.toString() + "Label";

            var zoneId = Properties.getValue(zoneKey);
            var label = Properties.getValue(labelKey);

            if (zoneId == null || !(zoneId instanceof String)) {
                return;
            }

            if (label == null || !(label instanceof String)) {
                label = "";
            }

            // Create timezone info object
            var info = new TimezoneInfo(zoneId as String, label as String);

            // Parse offset data
            // WorldTimeAPI returns: raw_offset (base timezone) + dst_offset (if in DST)
            var rawOffset = data.get("raw_offset");
            var dstOffset = data.get("dst_offset");

            if (rawOffset != null && rawOffset instanceof Number) {
                info.offset = rawOffset;
            } else {
                info.offset = 0;
            }

            if (dstOffset != null && dstOffset instanceof Number) {
                info.offset += dstOffset;
                info.dst = (dstOffset != 0);
            } else {
                info.dst = false;
            }

            // Try to parse next DST transition time
            // WorldTimeAPI may include dst_until or dst_from
            var dstUntil = data.get("dst_until");
            var dstFrom = data.get("dst_from");

            if (dstUntil != null && dstUntil instanceof String) {
                info.nextChange = parseIso8601ToUnix(dstUntil as String);
            } else if (dstFrom != null && dstFrom instanceof String) {
                info.nextChange = parseIso8601ToUnix(dstFrom as String);
            } else {
                // No transition data available, assume refresh needed in 24h
                info.nextChange = Time.now().value() + 86400L;
            }

            // Mark update time
            info.lastUpdate = Time.now().value().toLong();

            // Save to storage
            TimezoneDataManager.saveTimezoneInfo(cityNum, info);

        } catch (e) {
            // Parsing failed, keep old data
        }
    }

    /**
     * Parse ISO 8601 datetime string to Unix timestamp
     * Simplified parser for WorldTimeAPI format
     * @param dateStr ISO 8601 string (e.g., "2024-03-31T01:00:00+00:00")
     * @return Unix timestamp, or 0 if parsing fails
     */
    function parseIso8601ToUnix(dateStr as String) as Long {
        try {
            // WorldTimeAPI format: "2024-03-31T01:00:00+00:00"
            // Extract: year, month, day, hour, min, sec

            // Find T separator
            var tIndex = dateStr.find("T");
            if (tIndex == null) {
                return 0L;
            }

            var datePart = dateStr.substring(0, tIndex);
            var timePart = dateStr.substring(tIndex + 1, dateStr.length());

            // Parse date: "2024-03-31"
            var dateParts = split(datePart, "-");
            if (dateParts.size() < 3) {
                return 0L;
            }

            var year = dateParts[0].toNumber();
            var month = dateParts[1].toNumber();
            var day = dateParts[2].toNumber();

            // Parse time: "01:00:00+00:00" or "01:00:00Z"
            var plusIndex = timePart.find("+");
            var zIndex = timePart.find("Z");
            var endIndex = timePart.length();

            if (plusIndex != null) {
                endIndex = plusIndex;
            } else if (zIndex != null) {
                endIndex = zIndex;
            }

            var timeOnly = timePart.substring(0, endIndex);
            var timeParts = split(timeOnly, ":");

            if (timeParts.size() < 3) {
                return 0L;
            }

            var hour = timeParts[0].toNumber();
            var min = timeParts[1].toNumber();
            var sec = timeParts[2].toNumber();

            // Create moment and convert to Unix timestamp
            var moment = Time.Gregorian.moment({
                :year => year,
                :month => month,
                :day => day,
                :hour => hour,
                :minute => min,
                :second => sec
            });

            return moment.value().toLong();

        } catch (e) {
            return 0L;
        }
    }

    /**
     * Simple string split function
     * @param str String to split
     * @param delimiter Delimiter character
     * @return Array of substrings
     */
    function split(str as String, delimiter as String) as Array<String> {
        var result = [] as Array<String>;
        var startIndex = 0;

        while (true) {
            var delimIndex = str.find(delimiter);

            if (delimIndex == null) {
                // No more delimiters, add rest of string
                result.add(str.substring(startIndex, str.length()));
                break;
            }

            // Add substring before delimiter
            result.add(str.substring(startIndex, delimIndex));

            // Move past delimiter
            str = str.substring(delimIndex + delimiter.length(), str.length());
        }

        return result;
    }
}
