/**
 * TzHelper - Timezone Helper Class
 *
 * Provides embedded timezone calculation using DST rules.
 * This eliminates the need for API calls and enables offline functionality.
 *
 * Architecture: "Compact Atlas" approach
 * - Maps City IDs (integers) to standard offsets and DST rules
 * - Calculates DST mathematically based on calendar rules
 * - Supports both Northern and Southern Hemisphere DST
 */

import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;

class TzHelper {

    // DST Rule Constants
    enum {
        NO_DST = 0,      // No DST (Asia, most locations)
        RULE_US = 1,     // US: Mar 2nd Sun -> Nov 1st Sun
        RULE_EU = 2,     // Europe: Mar Last Sun -> Oct Last Sun
        RULE_AUS = 3,    // Australia: Oct 1st Sun -> Apr 1st Sun (Southern Hemisphere)
        RULE_NZ = 4      // New Zealand: Sep Last Sun -> Apr 1st Sun (Southern Hemisphere)
    }

    // City data structure: [standardOffsetSeconds, dstRule, abbreviation]
    // Standard offset is the offset WITHOUT DST applied
    private static const CITIES = [
        [0, RULE_EU, "LON"],           // 0: London (UTC+0, EU Rule)
        [3600, RULE_EU, "PAR"],        // 1: Paris (UTC+1, EU Rule)
        [3600, RULE_EU, "BER"],        // 2: Berlin (UTC+1, EU Rule)
        [10800, NO_DST, "MOS"],        // 3: Moscow (UTC+3, No DST)
        [-18000, RULE_US, "NYC"],      // 4: New York (UTC-5, US Rule)
        [-21600, RULE_US, "CHI"],      // 5: Chicago (UTC-6, US Rule)
        [-25200, RULE_US, "DEN"],      // 6: Denver (UTC-7, US Rule)
        [-28800, RULE_US, "LAX"],      // 7: Los Angeles (UTC-8, US Rule)
        [-21600, NO_DST, "MEX"],       // 8: Mexico City (UTC-6, No DST)
        [-10800, NO_DST, "SAO"],       // 9: São Paulo (UTC-3, No DST)
        [14400, NO_DST, "DXB"],        // 10: Dubai (UTC+4, No DST)
        [19800, NO_DST, "DEL"],        // 11: Kolkata (UTC+5:30, No DST)
        [28800, NO_DST, "SIN"],        // 12: Singapore (UTC+8, No DST)
        [28800, NO_DST, "HKG"],        // 13: Hong Kong (UTC+8, No DST)
        [32400, NO_DST, "TYO"],        // 14: Tokyo (UTC+9, No DST)
        [28800, NO_DST, "SHA"],        // 15: Shanghai (UTC+8, No DST)
        [36000, RULE_AUS, "SYD"],      // 16: Sydney (UTC+10, AUS Rule)
        [43200, RULE_NZ, "AKL"],       // 17: Auckland (UTC+12, NZ Rule)
        [-36000, NO_DST, "HNL"],       // 18: Honolulu (UTC-10, No DST)
        [7200, NO_DST, "JNB"],         // 19: Johannesburg (UTC+2, No DST)
        [3600, RULE_EU, "VIE"]         // 20: Vienna (UTC+1, EU Rule)
    ] as Array<Array>;

    /**
     * Get the current offset in seconds for a given city
     * @param cityId The city ID (0-20)
     * @return Offset in seconds from UTC (including DST if applicable)
     */
    static function getCurrentOffset(cityId as Number) as Number {
        if (cityId < 0 || cityId >= CITIES.size()) {
            return 0; // Default to UTC if invalid ID
        }

        var cityData = CITIES[cityId] as Array;
        var standardOffset = cityData[0] as Number;
        var dstRule = cityData[1] as Number;

        // Check if DST is currently active
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var inDst = isDst(now, dstRule);

        // Add 1 hour (3600 seconds) if DST is active
        return standardOffset + (inDst ? 3600 : 0);
    }

    /**
     * Get the city abbreviation for a given city ID
     * @param cityId The city ID (0-20)
     * @return City abbreviation (e.g., "LON", "NYC")
     */
    static function getCityAbbr(cityId as Number) as String {
        if (cityId < 0 || cityId >= CITIES.size()) {
            return "UTC";
        }

        var cityData = CITIES[cityId] as Array;
        return cityData[2] as String;
    }

    /**
     * Determine if DST is currently active for a given rule
     * @param now Current time info from Gregorian.info
     * @param rule DST rule constant (NO_DST, RULE_US, RULE_EU, RULE_AUS, RULE_NZ)
     * @return true if DST is active, false otherwise
     */
    static function isDst(now as Gregorian.Info, rule as Number) as Boolean {
        if (rule == NO_DST) {
            return false;
        }

        var year = now.year as Number;
        var month = now.month as Number;
        var day = now.day as Number;

        var startMonth, endMonth, startSunday, endSunday;

        // Define DST start and end rules
        if (rule == RULE_US) {
            // US: Second Sunday of March -> First Sunday of November
            startMonth = 3;
            endMonth = 11;
            startSunday = getNthSunday(year, startMonth, 2);
            endSunday = getNthSunday(year, endMonth, 1);
        } else if (rule == RULE_EU) {
            // Europe: Last Sunday of March -> Last Sunday of October
            startMonth = 3;
            endMonth = 10;
            startSunday = getNthSunday(year, startMonth, -1);
            endSunday = getNthSunday(year, endMonth, -1);
        } else if (rule == RULE_AUS) {
            // Australia: First Sunday of October -> First Sunday of April (Southern Hemisphere)
            startMonth = 10;
            endMonth = 4;
            startSunday = getNthSunday(year, startMonth, 1);
            endSunday = getNthSunday(year, endMonth, 1);
        } else if (rule == RULE_NZ) {
            // New Zealand: Last Sunday of September -> First Sunday of April (Southern Hemisphere)
            startMonth = 9;
            endMonth = 4;
            startSunday = getNthSunday(year, startMonth, -1);
            endSunday = getNthSunday(year, endMonth, 1);
        } else {
            return false;
        }

        // Handle Northern vs Southern Hemisphere logic
        if (startMonth < endMonth) {
            // Northern Hemisphere: DST active between start and end
            if (month < startMonth || month > endMonth) {
                return false;
            } else if (month > startMonth && month < endMonth) {
                return true;
            } else if (month == startMonth) {
                return day >= startSunday;
            } else { // month == endMonth
                return day < endSunday;
            }
        } else {
            // Southern Hemisphere: DST active when NOT between end and start
            if (month > endMonth && month < startMonth) {
                return false;
            } else if (month < endMonth || month > startMonth) {
                return true;
            } else if (month == startMonth) {
                return day >= startSunday;
            } else { // month == endMonth
                return day < endSunday;
            }
        }
    }

    /**
     * Get the Nth Sunday of a given month
     * @param year The year
     * @param month The month (1-12)
     * @param n Which Sunday (1 = first, 2 = second, -1 = last)
     * @return Day of month for the Nth Sunday
     */
    static function getNthSunday(year as Number, month as Number, n as Number) as Number {
        if (n == -1) {
            // Find the last Sunday by checking the last week of the month
            var daysInMonth = getDaysInMonth(year, month);

            // Start from the last day and work backwards
            for (var day = daysInMonth; day >= daysInMonth - 6; day--) {
                var moment = Gregorian.moment({
                    :year => year,
                    :month => month,
                    :day => day,
                    :hour => 12
                });
                var info = Gregorian.info(moment, Time.FORMAT_SHORT);

                // day_of_week: 1 = Sunday
                if (info.day_of_week == 1) {
                    return day;
                }
            }

            return daysInMonth; // Fallback (should never happen)
        } else {
            // Find the Nth Sunday (1st, 2nd, etc.)
            var sundayCount = 0;

            for (var day = 1; day <= 31; day++) {
                var moment = Gregorian.moment({
                    :year => year,
                    :month => month,
                    :day => day,
                    :hour => 12
                });
                var info = Gregorian.info(moment, Time.FORMAT_SHORT);

                // day_of_week: 1 = Sunday
                if (info.day_of_week == 1) {
                    sundayCount++;
                    if (sundayCount == n) {
                        return day;
                    }
                }
            }

            return 1; // Fallback (should never happen)
        }
    }

    /**
     * Get the number of days in a given month
     * @param year The year (for leap year calculation)
     * @param month The month (1-12)
     * @return Number of days in the month
     */
    private static function getDaysInMonth(year as Number, month as Number) as Number {
        if (month == 2) {
            // February - check for leap year
            if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
                return 29;
            } else {
                return 28;
            }
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else {
            return 31;
        }
    }
}
