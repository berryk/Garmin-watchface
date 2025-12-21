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
import Toybox.Background;

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

    // Timezone data (loaded from storage and properties)
    private var city1Info as TimezoneInfo?;
    private var city2Info as TimezoneInfo?;
    private var city3Info as TimezoneInfo?;
    private var city4Info as TimezoneInfo?;

    /**
     * Constructor
     */
    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    /**
     * Load city settings from properties and storage
     */
    function loadSettings() as Void {
        try {
            // Load City 1
            var zone1 = Properties.getValue("City1Zone");
            var label1 = Properties.getValue("City1Label");
            if (zone1 != null && zone1 instanceof String) {
                var lbl = (label1 != null && label1 instanceof String) ? label1 as String : "LN";
                city1Info = TimezoneDataManager.loadTimezoneInfo(1, zone1 as String, lbl);
            }

            // Load City 2
            var zone2 = Properties.getValue("City2Zone");
            var label2 = Properties.getValue("City2Label");
            if (zone2 != null && zone2 instanceof String) {
                var lbl = (label2 != null && label2 instanceof String) ? label2 as String : "HK";
                city2Info = TimezoneDataManager.loadTimezoneInfo(2, zone2 as String, lbl);
            }

            // Load City 3
            var zone3 = Properties.getValue("City3Zone");
            var label3 = Properties.getValue("City3Label");
            if (zone3 != null && zone3 instanceof String) {
                var lbl = (label3 != null && label3 instanceof String) ? label3 as String : "NY";
                city3Info = TimezoneDataManager.loadTimezoneInfo(3, zone3 as String, lbl);
            }

            // Load City 4
            var zone4 = Properties.getValue("City4Zone");
            var label4 = Properties.getValue("City4Label");
            if (zone4 != null && zone4 instanceof String) {
                var lbl = (label4 != null && label4 instanceof String) ? label4 as String : "SF";
                city4Info = TimezoneDataManager.loadTimezoneInfo(4, zone4 as String, lbl);
            }

            // Request background update if any timezone needs refresh
            requestBackgroundUpdateIfNeeded();
        } catch (e) {
            // Use defaults if loading fails
        }
    }

    /**
     * Request background update if timezone data is stale
     */
    function requestBackgroundUpdateIfNeeded() as Void {
        var needsUpdate = false;

        if (city1Info != null && city1Info.isStale()) { needsUpdate = true; }
        if (city2Info != null && city2Info.isStale()) { needsUpdate = true; }
        if (city3Info != null && city3Info.isStale()) { needsUpdate = true; }
        if (city4Info != null && city4Info.isStale()) { needsUpdate = true; }

        if (needsUpdate) {
            // Trigger background service to fetch fresh data
            Background.registerForTemporalEvent(new Time.Duration(5));
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
     * Draw the top row of world times (City 1, City 2)
     * @param dc Device context
     * @param clockTime Current system clock time
     * @param y Vertical position
     */
    private function drawWorldTimesTop(dc as Dc, clockTime as System.ClockTime, y as Number) as Void {
        var spacing = screenWidth * 0.25;

        // Draw City 1
        if (city1Info != null) {
            checkAndApplyPrediction(city1Info, 1);
            var hour1 = city1Info.getHour(clockTime);
            drawWorldTimeItem(dc, centerX - spacing.toNumber(), y, city1Info.label, hour1);
        }

        // Draw City 2
        if (city2Info != null) {
            checkAndApplyPrediction(city2Info, 2);
            var hour2 = city2Info.getHour(clockTime);
            drawWorldTimeItem(dc, centerX + spacing.toNumber(), y, city2Info.label, hour2);
        }
    }

    /**
     * Draw the bottom row of world times (City 3, City 4)
     * @param dc Device context
     * @param clockTime Current system clock time
     * @param y Vertical position
     */
    private function drawWorldTimesBottom(dc as Dc, clockTime as System.ClockTime, y as Number) as Void {
        var spacing = screenWidth * 0.25;

        // Draw City 3
        if (city3Info != null) {
            checkAndApplyPrediction(city3Info, 3);
            var hour3 = city3Info.getHour(clockTime);
            drawWorldTimeItem(dc, centerX - spacing.toNumber(), y, city3Info.label, hour3);
        }

        // Draw City 4
        if (city4Info != null) {
            checkAndApplyPrediction(city4Info, 4);
            var hour4 = city4Info.getHour(clockTime);
            drawWorldTimeItem(dc, centerX + spacing.toNumber(), y, city4Info.label, hour4);
        }
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
     * Check if timezone data has passed its transition time and apply prediction
     * @param info Timezone info to check
     * @param cityNum City number (for saving updated data)
     */
    private function checkAndApplyPrediction(info as TimezoneInfo, cityNum as Number) as Void {
        var now = Time.now().value();

        // Check if we've passed the predicted transition time
        if (info.nextChange > 0 && now > info.nextChange) {
            // Apply heuristic prediction (flip DST, adjust offset by ±1 hour)
            info.applyPrediction();

            // Save updated data
            TimezoneDataManager.saveTimezoneInfo(cityNum, info);

            // Request background update to get exact data
            Background.registerForTemporalEvent(new Time.Duration(5));
        }
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
