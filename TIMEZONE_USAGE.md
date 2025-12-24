# Embedded Timezone System - Usage Guide

## Overview

The watchface now uses an **Embedded Rule-Based Timezone System** that eliminates the need for API calls and enables full offline functionality. Timezones are calculated mathematically using DST rules.

## Architecture

The system uses a "Compact Atlas" approach:
- **City IDs**: Integer values (0-20) that map to specific cities
- **Standard Offsets**: Base UTC offset without DST
- **DST Rules**: Automatic calculation based on calendar rules

## Supported Cities (21 Total)

| ID | City | Standard Offset | DST Rule | Abbreviation |
|----|------|-----------------|----------|--------------|
| 0  | London | UTC+0 | EU Rule | LON |
| 1  | Paris | UTC+1 | EU Rule | PAR |
| 2  | Berlin | UTC+1 | EU Rule | BER |
| 3  | Moscow | UTC+3 | No DST | MOS |
| 4  | New York | UTC-5 | US Rule | NYC |
| 5  | Chicago | UTC-6 | US Rule | CHI |
| 6  | Denver | UTC-7 | US Rule | DEN |
| 7  | Los Angeles | UTC-8 | US Rule | LAX |
| 8  | Mexico City | UTC-6 | No DST | MEX |
| 9  | São Paulo | UTC-3 | No DST | SAO |
| 10 | Dubai | UTC+4 | No DST | DXB |
| 11 | Kolkata | UTC+5:30 | No DST | DEL |
| 12 | Singapore | UTC+8 | No DST | SIN |
| 13 | Hong Kong | UTC+8 | No DST | HKG |
| 14 | Tokyo | UTC+9 | No DST | TYO |
| 15 | Shanghai | UTC+8 | No DST | SHA |
| 16 | Sydney | UTC+10 | AUS Rule | SYD |
| 17 | Auckland | UTC+12 | NZ Rule | AKL |
| 18 | Honolulu | UTC-10 | No DST | HNL |
| 19 | Johannesburg | UTC+2 | No DST | JNB |
| 20 | Vienna | UTC+1 | EU Rule | VIE |

## DST Rules

### RULE_US (US Daylight Saving Time)
- **Start**: Second Sunday of March at 2:00 AM
- **End**: First Sunday of November at 2:00 AM
- **Offset**: +1 hour during DST

### RULE_EU (European Summer Time)
- **Start**: Last Sunday of March at 1:00 AM UTC
- **End**: Last Sunday of October at 1:00 AM UTC
- **Offset**: +1 hour during DST

### RULE_AUS (Australian Daylight Time - Southern Hemisphere)
- **Start**: First Sunday of October at 2:00 AM
- **End**: First Sunday of April at 3:00 AM
- **Offset**: +1 hour during DST

### RULE_NZ (New Zealand Daylight Time - Southern Hemisphere)
- **Start**: Last Sunday of September at 2:00 AM
- **End**: First Sunday of April at 3:00 AM
- **Offset**: +1 hour during DST

### NO_DST
- No daylight saving time adjustments

## Usage in Code

### Basic Usage - Get Current Offset

```monkeyc
import Toybox.Application.Properties;

// In your onUpdate() function:
function onUpdate(dc) {
    // Load zone setting (integer 0-20)
    var zoneId = Properties.getValue("Zone1");
    if (zoneId == null) { zoneId = 0; } // Default to London

    // Get current offset in seconds (includes DST if applicable)
    var offsetSeconds = TzHelper.getCurrentOffset(zoneId);

    // Get city abbreviation
    var cityAbbr = TzHelper.getCityAbbr(zoneId);

    // Calculate time in that zone
    var clockTime = System.getClockTime();
    var hour = getWorldTimeHour(clockTime, offsetSeconds);
    var minute = clockTime.min;

    // Format and display
    var timeStr = hour.format("%02d") + ":" + minute.format("%02d");
    dc.drawText(x, y, font, cityAbbr + " " + timeStr, justification);
}
```

### Complete Example - Display Zone 1 Time

```monkeyc
import Toybox.Graphics;
import Toybox.System;
import Toybox.Time;
import Toybox.Application.Properties;

function onUpdate(dc as Dc) as Void {
    // 1. Load the zone setting (integer city ID)
    var zone1 = Properties.getValue("Zone1");
    if (zone1 == null) {
        zone1 = 0; // Default to London if not set
    }

    // 2. Get the current timezone offset (with automatic DST)
    var offsetSeconds = TzHelper.getCurrentOffset(zone1);

    // 3. Get the city abbreviation
    var cityLabel = TzHelper.getCityAbbr(zone1);

    // 4. Calculate the hour in that timezone
    var clockTime = System.getClockTime();
    var localOffset = clockTime.timeZoneOffset;
    var localSeconds = clockTime.hour * 3600 + clockTime.min * 60 + clockTime.sec;
    var utcSeconds = localSeconds - localOffset;
    var targetSeconds = utcSeconds + offsetSeconds;

    // Handle day wraparound
    if (targetSeconds < 0) {
        targetSeconds += 86400;
    } else if (targetSeconds >= 86400) {
        targetSeconds -= 86400;
    }

    var hour = (targetSeconds / 3600).toNumber();
    var minute = ((targetSeconds % 3600) / 60).toNumber();

    // 5. Format and display the time
    var timeString = hour.format("%02d") + ":" + minute.format("%02d");

    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(100, 100, Graphics.FONT_MEDIUM,
                cityLabel + " " + timeString,
                Graphics.TEXT_JUSTIFY_LEFT);
}
```

### Helper Function - Get World Time Hour

This is the same function used in GMTWorldTimeView.mc:

```monkeyc
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
```

## Benefits of This Approach

1. **Battery Efficient**: No network calls means less battery drain
2. **Offline Functionality**: Works without phone connection
3. **Always Accurate**: DST rules are calculated automatically
4. **Compact**: Only ~250 lines of code vs. API infrastructure
5. **Type Safe**: Integer IDs prevent string mismatch errors

## Migration from Old System

### Old System (API-based):
```xml
<property id="City1Label" type="string">NYC</property>
<property id="City1Offset" type="number">-5</property>
<property id="City1DST" type="boolean">false</property>
```

### New System (Embedded Rules):
```xml
<property id="Zone1" type="number">4</property>  <!-- 4 = New York -->
```

The DST is now calculated automatically - no manual toggle needed!

## Testing DST Transitions

To verify DST is working correctly, you can test around these dates:

- **US**: March 10, 2024 (start) and November 3, 2024 (end)
- **EU**: March 31, 2024 (start) and October 27, 2024 (end)
- **Australia**: October 6, 2024 (start) and April 6, 2025 (end)
- **New Zealand**: September 29, 2024 (start) and April 6, 2025 (end)

## Notes

- **Standard Offset**: The offset listed is the base offset WITHOUT DST. TzHelper automatically adds 1 hour when DST is active.
- **Southern Hemisphere**: Australia and New Zealand have inverted DST (summer is Dec-Feb).
- **No DST Cities**: Mexico City and São Paulo abolished DST in recent years.
- **30-Minute Offsets**: Kolkata (UTC+5:30) demonstrates support for non-hour offsets.
