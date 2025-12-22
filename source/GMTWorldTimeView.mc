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
        System.println("========================================");
        System.println("VIEW: loadSettings() called");
        System.println("========================================");
        
        try {
            // Load City 1
            System.println("VIEW: Loading City 1...");
            var zone1Id = Properties.getValue("City1Zone");
            var label1 = Properties.getValue("City1Label");
            System.println("VIEW: City1Zone = " + zone1Id);
            System.println("VIEW: City1Label = " + label1);
            
            if (zone1Id != null && zone1Id instanceof Number) {
                var zoneStr = getTimezoneString(zone1Id as Number);
                System.println("VIEW: City1 timezone string = " + zoneStr);
                var lbl = (label1 != null && label1 instanceof String) ? label1 as String : "LN";
                city1Info = TimezoneDataManager.loadTimezoneInfo(1, zoneStr, lbl);
                System.println("VIEW: City1 loaded successfully");
                if (city1Info != null) {
                    System.println("VIEW: City1Info - offset=" + city1Info.offset + ", dst=" + city1Info.dst + ", lastUpdate=" + city1Info.lastUpdate);
                }
            } else {
                System.println("VIEW: ERROR - City1Zone is null or wrong type!");
            }

            // Load City 2
            System.println("VIEW: Loading City 2...");
            var zone2Id = Properties.getValue("City2Zone");
            var label2 = Properties.getValue("City2Label");
            System.println("VIEW: City2Zone = " + zone2Id);
            System.println("VIEW: City2Label = " + label2);
            
            if (zone2Id != null && zone2Id instanceof Number) {
                var zoneStr = getTimezoneString(zone2Id as Number);
                System.println("VIEW: City2 timezone string = " + zoneStr);
                var lbl = (label2 != null && label2 instanceof String) ? label2 as String : "HK";
                city2Info = TimezoneDataManager.loadTimezoneInfo(2, zoneStr, lbl);
                System.println("VIEW: City2 loaded successfully");
                if (city2Info != null) {
                    System.println("VIEW: City2Info - offset=" + city2Info.offset + ", dst=" + city2Info.dst + ", lastUpdate=" + city2Info.lastUpdate);
                }
            } else {
                System.println("VIEW: ERROR - City2Zone is null or wrong type!");
            }

            // Load City 3
            System.println("VIEW: Loading City 3...");
            var zone3Id = Properties.getValue("City3Zone");
            var label3 = Properties.getValue("City3Label");
            System.println("VIEW: City3Zone = " + zone3Id);
            System.println("VIEW: City3Label = " + label3);
            
            if (zone3Id != null && zone3Id instanceof Number) {
                var zoneStr = getTimezoneString(zone3Id as Number);
                System.println("VIEW: City3 timezone string = " + zoneStr);
                var lbl = (label3 != null && label3 instanceof String) ? label3 as String : "NY";
                city3Info = TimezoneDataManager.loadTimezoneInfo(3, zoneStr, lbl);
                System.println("VIEW: City3 loaded successfully");
                if (city3Info != null) {
                    System.println("VIEW: City3Info - offset=" + city3Info.offset + ", dst=" + city3Info.dst + ", lastUpdate=" + city3Info.lastUpdate);
                }
            } else {
                System.println("VIEW: ERROR - City3Zone is null or wrong type!");
            }

            // Load City 4
            System.println("VIEW: Loading City 4...");
            var zone4Id = Properties.getValue("City4Zone");
            var label4 = Properties.getValue("City4Label");
            System.println("VIEW: City4Zone = " + zone4Id);
            System.println("VIEW: City4Label = " + label4);
            
            if (zone4Id != null && zone4Id instanceof Number) {
                var zoneStr = getTimezoneString(zone4Id as Number);
                System.println("VIEW: City4 timezone string = " + zoneStr);
                var lbl = (label4 != null && label4 instanceof String) ? label4 as String : "SF";
                city4Info = TimezoneDataManager.loadTimezoneInfo(4, zoneStr, lbl);
                System.println("VIEW: City4 loaded successfully");
                if (city4Info != null) {
                    System.println("VIEW: City4Info - offset=" + city4Info.offset + ", dst=" + city4Info.dst + ", lastUpdate=" + city4Info.lastUpdate);
                }
            } else {
                System.println("VIEW: ERROR - City4Zone is null or wrong type!");
            }

            // Request background update if any timezone needs refresh
            System.println("VIEW: Checking if background update needed...");
            requestBackgroundUpdateIfNeeded();
            System.println("VIEW: loadSettings() completed successfully");
            System.println("========================================");
        } catch (e) {
            System.println("VIEW: CRITICAL ERROR in loadSettings()!");
            System.println("VIEW: Error message: " + e.getErrorMessage());
            System.println("VIEW: Using default fallbacks");
            System.println("========================================");
        }
    }

    /**
     * Request background update if timezone data is stale
     */
    function requestBackgroundUpdateIfNeeded() as Void {
        // Check if any city data is stale and needs refresh
        var needsUpdate = false;
        
        if (city1Info != null && city1Info.isStale()) {
            System.println("VIEW: City1 data is stale, needs update");
            needsUpdate = true;
        }
        if (city2Info != null && city2Info.isStale()) {
            System.println("VIEW: City2 data is stale, needs update");
            needsUpdate = true;
        }
        if (city3Info != null && city3Info.isStale()) {
            System.println("VIEW: City3 data is stale, needs update");
            needsUpdate = true;
        }
        if (city4Info != null && city4Info.isStale()) {
            System.println("VIEW: City4 data is stale, needs update");
            needsUpdate = true;
        }
        
        if (needsUpdate) {
            System.println("VIEW: Registering background temporal event for API fetch...");
            Background.registerForTemporalEvent(new Time.Duration(300)); // 5 minutes minimum
        } else {
            System.println("VIEW: All timezone data is fresh, no update needed");
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
            Background.registerForTemporalEvent(new Time.Duration(300)); // 5 minutes minimum
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
