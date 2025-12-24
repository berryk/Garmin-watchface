/**
 * GMT World Time Watchface View
 * 
 * Handles all rendering of the watchface display including:
 * - Main time display
 * - Date/day/month
 * - Bluetooth status
 * - Step count
 * - World time zones (configurable via Garmin Connect app)
 */

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Application.Properties;

/**
 * Main view class for rendering the watchface
 */
class GMTWorldTimeView extends WatchUi.WatchFace {

    // Day and month abbreviations
    private const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    private const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", 
                            "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    // Screen dimensions (calculated on load)
    private var screenWidth as Number = 0;
    private var screenHeight as Number = 0;
    private var centerX as Number = 0;
    private var centerY as Number = 0;

    // Zone settings (loaded from properties)
    // Each zone is a city ID (0-20) that maps to embedded timezone rules
    private var zone1 as Number = 0;   // Default: London
    private var zone2 as Number = 13;  // Default: Hong Kong
    private var zone3 as Number = 4;   // Default: New York
    private var zone4 as Number = 7;   // Default: Los Angeles

    // Custom zone labels (loaded from properties, max 3 chars)
    private var zone1Label as String = "LON";
    private var zone2Label as String = "HKG";
    private var zone3Label as String = "NYC";
    private var zone4Label as String = "LAX";

    /**
     * Constructor
     */
    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    /**
     * Load zone settings from properties
     */
    function loadSettings() as Void {
        try {
            // Load zone IDs (integers 0-20)
            var z1 = Properties.getValue("Zone1");
            if (z1 != null) { zone1 = z1 as Number; }

            var z2 = Properties.getValue("Zone2");
            if (z2 != null) { zone2 = z2 as Number; }

            var z3 = Properties.getValue("Zone3");
            if (z3 != null) { zone3 = z3 as Number; }

            var z4 = Properties.getValue("Zone4");
            if (z4 != null) { zone4 = z4 as Number; }

            // Load custom labels (fall back to TzHelper abbreviation if empty)
            var label1 = Properties.getValue("Zone1Label");
            if (label1 != null && label1 != "") {
                zone1Label = label1 as String;
            } else {
                zone1Label = TzHelper.getCityAbbr(zone1);
            }

            var label2 = Properties.getValue("Zone2Label");
            if (label2 != null && label2 != "") {
                zone2Label = label2 as String;
            } else {
                zone2Label = TzHelper.getCityAbbr(zone2);
            }

            var label3 = Properties.getValue("Zone3Label");
            if (label3 != null && label3 != "") {
                zone3Label = label3 as String;
            } else {
                zone3Label = TzHelper.getCityAbbr(zone3);
            }

            var label4 = Properties.getValue("Zone4Label");
            if (label4 != null && label4 != "") {
                zone4Label = label4 as String;
            } else {
                zone4Label = TzHelper.getCityAbbr(zone4);
            }
        } catch (e) {
            // Use defaults if properties fail to load
        }
    }

    /**
     * Called when the view is brought into the foreground
     * @param dc Device context for drawing
     */
    function onLayout(dc as Dc) as Void {
        // Cache screen dimensions
        screenWidth = dc.getWidth();
        screenHeight = dc.getHeight();
        centerX = screenWidth / 2;
        centerY = screenHeight / 2;
    }

    /**
     * Called when settings change
     */
    function onSettingsChanged() as Void {
        loadSettings();
        WatchUi.requestUpdate();
    }

    /**
     * Called when the view needs to be updated
     * @param dc Device context for drawing
     */
    function onUpdate(dc as Dc) as Void {
        // Clear the screen with black background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Get current time - use FORMAT_SHORT to get numeric values
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var clockTime = System.getClockTime();
        
        // Calculate vertical positions based on screen height
        var dateY = screenHeight * 0.15;
        var topWorldTimeY = screenHeight * 0.30;
        var mainTimeY = centerY;
        var bottomWorldTimeY = screenHeight * 0.70;
        var stepsY = screenHeight * 0.87;

        // Draw all elements
        drawDateAndBluetooth(dc, now, dateY.toNumber());
        drawWorldTimesTop(dc, clockTime, topWorldTimeY.toNumber());
        drawMainTime(dc, clockTime, mainTimeY);
        drawWorldTimesBottom(dc, clockTime, bottomWorldTimeY.toNumber());
        drawSteps(dc, stepsY.toNumber());
    }

    /**
     * Draw the date, day, month and Bluetooth status
     * @param dc Device context
     * @param now Current time info
     * @param y Vertical position
     */
    private function drawDateAndBluetooth(dc as Dc, now as Gregorian.Info, y as Number) as Void {
        var settings = System.getDeviceSettings();
        var isConnected = settings.phoneConnected;
        
        // Format: "THU 19 DEC"
        // Safely get day_of_week as number (1-7, where 1=Sunday)
        var dayOfWeekNum = now.day_of_week as Number;
        var dayStr = DAYS[dayOfWeekNum - 1];
        
        // Get day of month as number
        var dayNum = now.day as Number;
        var dateNum = dayNum.format("%02d");
        
        // Get month as number (1-12)
        var monthNum = now.month as Number;
        var monthStr = MONTHS[monthNum - 1];
        
        var dateString = dayStr + " " + dateNum + " " + monthStr;
        
        // Calculate positions
        var font = Graphics.FONT_SMALL;
        var dateWidth = dc.getTextWidthInPixels(dateString, font);
        var iconWidth = 20; // Approximate width for bluetooth indicator
        var spacing = 8;
        var totalWidth = dateWidth + spacing + iconWidth;
        var startX = centerX - (totalWidth / 2);
        
        // Draw date text
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + (dateWidth / 2), y, font, dateString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // Draw Bluetooth indicator
        var btX = startX + dateWidth + spacing + (iconWidth / 2);
        if (isConnected) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            // Draw filled circle for connected
            dc.fillCircle(btX, y, 6);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            // Draw empty circle for disconnected
            dc.drawCircle(btX, y, 6);
        }
    }

    /**
     * Draw the top row of world times (Zone 1, Zone 2)
     * @param dc Device context
     * @param clockTime Current system clock time
     * @param y Vertical position
     */
    private function drawWorldTimesTop(dc as Dc, clockTime as System.ClockTime, y as Number) as Void {
        // Get timezone offsets from TzHelper (includes automatic DST calculation)
        var offset1Seconds = TzHelper.getCurrentOffset(zone1);
        var offset2Seconds = TzHelper.getCurrentOffset(zone2);

        var hour1 = getWorldTimeHour(clockTime, offset1Seconds);
        var hour2 = getWorldTimeHour(clockTime, offset2Seconds);

        var spacing = screenWidth * 0.25;

        // Use custom labels loaded from settings
        drawWorldTimeItem(dc, centerX - spacing.toNumber(), y, zone1Label, hour1);
        drawWorldTimeItem(dc, centerX + spacing.toNumber(), y, zone2Label, hour2);
    }

    /**
     * Draw the bottom row of world times (Zone 3, Zone 4)
     * @param dc Device context
     * @param clockTime Current system clock time
     * @param y Vertical position
     */
    private function drawWorldTimesBottom(dc as Dc, clockTime as System.ClockTime, y as Number) as Void {
        // Get timezone offsets from TzHelper (includes automatic DST calculation)
        var offset3Seconds = TzHelper.getCurrentOffset(zone3);
        var offset4Seconds = TzHelper.getCurrentOffset(zone4);

        var hour3 = getWorldTimeHour(clockTime, offset3Seconds);
        var hour4 = getWorldTimeHour(clockTime, offset4Seconds);

        var spacing = screenWidth * 0.25;

        // Use custom labels loaded from settings
        drawWorldTimeItem(dc, centerX - spacing.toNumber(), y, zone3Label, hour3);
        drawWorldTimeItem(dc, centerX + spacing.toNumber(), y, zone4Label, hour4);
    }

    /**
     * Draw a single world time item (label + hour)
     * @param dc Device context
     * @param x Horizontal position
     * @param y Vertical position
     * @param label City label (e.g., "LN")
     * @param hour Hour in that timezone (0-23)
     */
    private function drawWorldTimeItem(dc as Dc, x as Number, y as Number, label as String, hour as Number) as Void {
        var hourStr = hour.format("%02d");
        var font = Graphics.FONT_MEDIUM;
        
        // Calculate combined width - use same font for both label and hour
        var labelWidth = dc.getTextWidthInPixels(label, font);
        var hourWidth = dc.getTextWidthInPixels(hourStr, font);
        var spacing = 6;
        var totalWidth = labelWidth + spacing + hourWidth;
        var startX = x - (totalWidth / 2);
        
        // Draw label in white (same style as hour)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + (labelWidth / 2), y, font, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // Draw hour in white
        dc.drawText(startX + labelWidth + spacing + (hourWidth / 2), y, font, hourStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    /**
     * Calculate the hour in a given timezone
     * @param clockTime Current device clock time
     * @param tzOffset Timezone offset from UTC in seconds
     * @return Hour in the target timezone (0-23)
     */
    private function getWorldTimeHour(clockTime as System.ClockTime, tzOffset as Number) as Number {
        // Get local time offset from UTC
        var localOffset = clockTime.timeZoneOffset;
        
        // Calculate UTC hour from local time
        var localSeconds = clockTime.hour * 3600 + clockTime.min * 60 + clockTime.sec;
        var utcSeconds = localSeconds - localOffset;
        
        // Add target timezone offset
        var targetSeconds = utcSeconds + tzOffset;
        
        // Handle day wraparound
        if (targetSeconds < 0) {
            targetSeconds += 86400; // Add 24 hours
        } else if (targetSeconds >= 86400) {
            targetSeconds -= 86400; // Subtract 24 hours
        }
        
        // Extract hour
        var hour = (targetSeconds / 3600).toNumber();
        
        // Ensure hour is in valid range
        if (hour < 0) {
            hour += 24;
        } else if (hour >= 24) {
            hour -= 24;
        }
        
        return hour;
    }

    /**
     * Draw the main time display
     * @param dc Device context
     * @param clockTime Current system clock time
     * @param y Vertical center position
     */
    private function drawMainTime(dc as Dc, clockTime as System.ClockTime, y as Number) as Void {
        var hour = clockTime.hour;
        var minute = clockTime.min;
        
        // Check 12/24 hour format preference
        var settings = System.getDeviceSettings();
        if (!settings.is24Hour) {
            if (hour == 0) {
                hour = 12;
            } else if (hour > 12) {
                hour = hour - 12;
            }
        }
        
        // Format time string
        var timeString = hour.format("%02d") + ":" + minute.format("%02d");
        
        // Use the largest available font for main time
        var font = Graphics.FONT_NUMBER_HOT;
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, font, timeString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    /**
     * Draw the step count (centered, no icon)
     * @param dc Device context
     * @param y Vertical position
     */
    private function drawSteps(dc as Dc, y as Number) as Void {
        var steps = 0;
        
        // Get step count from activity monitor
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            steps = info.steps;
        }
        
        // Format with thousands separator
        var stepsString = formatNumber(steps);
        
        // Draw steps count centered
        var font = Graphics.FONT_SMALL;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, font, stepsString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    /**
     * Format a number with thousands separators
     * @param num The number to format
     * @return Formatted string (e.g., "8,432")
     */
    private function formatNumber(num as Number) as String {
        if (num < 1000) {
            return num.toString();
        }
        
        var thousands = num / 1000;
        var remainder = num % 1000;
        
        return thousands.toString() + "," + remainder.format("%03d");
    }

    /**
     * Called when entering sleep mode
     */
    function onEnterSleep() as Void {
        // Could reduce update frequency or simplify display
        WatchUi.requestUpdate();
    }

    /**
     * Called when exiting sleep mode
     */
    function onExitSleep() as Void {
        WatchUi.requestUpdate();
    }

    /**
     * Called every second in high power mode, every minute in low power mode
     */
    function onPartialUpdate(dc as Dc) as Void {
        // For partial updates, we just update the time
        // This is called when in low power mode
    }
}
