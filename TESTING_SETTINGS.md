# Testing Settings Changes in Simulator

This guide explains how to test watchface settings changes in the Connect IQ simulator and debug any issues that arise.

## Quick Start

### 1. Run the Test Script

```powershell
.\test_settings.ps1
```

This will launch an interactive menu where you can:
- Apply predefined test scenarios
- Create custom settings
- View current settings

### 2. Select a Test Scenario

Choose from these options:
- **1. default** - Default settings (LN, HK, NY, SF)
- **2. asia** - Asian cities (Tokyo, Hong Kong, Singapore, Shanghai)
- **3. europe** - European cities (London, Paris, Berlin, Vienna)
- **4. americas** - American cities (NY, Chicago, Denver, LA)
- **5. mixed** - Mixed global cities (London, Tokyo, NY, Sydney)
- **6. invalid_zones** - Test error handling with invalid zone IDs
- **7. long_labels** - Test overflow handling with long labels
- **8. custom** - Enter your own values

### 3. Restart the Simulator

After the script updates the settings file, you **MUST** restart the simulator:
1. Stop the simulator (if running)
2. Press **F5** in VS Code to rebuild and restart
3. Check the output window for logs

## Understanding the Logs

With the new logging added, you'll see detailed output when the watchface loads and when settings change.

### View Logs Location

**In VS Code:**
- Go to **View** → **Output**
- Select **"Monkey C"** from the dropdown
- You'll see all System.println() output here

### Log Structure

#### 1. View Initialization Logs

```
========================================
VIEW: loadSettings() called
========================================
VIEW: Loading City 1...
VIEW: City1Zone = 0 (type: Toybox.Lang.Number)
VIEW: City1Label = LN
VIEW: City1 timezone string = Europe/London
VIEW: City1 loaded successfully
VIEW: City1Info - offset=0, dst=false, lastUpdate=0
VIEW: Loading City 2...
[... continues for all 4 cities ...]
VIEW: loadSettings() completed successfully
========================================
```

**What to look for:**
- ✅ Each city loads successfully
- ✅ Zone IDs are correct type (Number)
- ✅ Labels are correct type (String)
- ❌ ERROR messages if something fails
- ⚠️ offset=0 and lastUpdate=0 means no API data yet (expected on first load)

#### 2. Settings Change Logs

When you restart the simulator with new settings:

```
****************************************
APP: onSettingsChanged() called
****************************************
APP: Reloading view settings...
========================================
VIEW: loadSettings() called
========================================
[... city loading logs ...]
APP: Registering background temporal event (5 seconds)...
APP: Requesting UI update...
APP: onSettingsChanged() completed
****************************************
```

**What to look for:**
- ✅ `onSettingsChanged()` is called
- ✅ View reloads all settings
- ✅ Background service is triggered
- ❌ Check for any ERROR messages during reload

#### 3. Background API Call Logs

After 5 seconds, you should see background service logs:

```
########################################
BACKGROUND: onTemporalEvent() triggered
BACKGROUND: Starting timezone data fetch...
########################################
BACKGROUND: fetchTimezoneData() called for City 1
BACKGROUND: City 1 - isStale=true
BACKGROUND: City 1 - lastUpdate=0
BACKGROUND: Making API request to: http://worldtimeapi.org/api/timezone/Europe/London
BACKGROUND: API response received for City 1
BACKGROUND: Response code: 200
BACKGROUND: Parsing and saving data for City 1
BACKGROUND: fetchTimezoneData() called for City 2
[... continues for all cities ...]
BACKGROUND: All cities processed, exiting background service
########################################
```

**What to look for:**
- ✅ Background service triggers after settings change
- ✅ API requests are made for stale data
- ✅ Response code is 200 (success)
- ✅ Data is parsed and saved
- ❌ Response code != 200 means API failure
- ⚠️ "data is fresh, skipping fetch" means cached data is used (expected behavior)

#### 4. Background Data Received Logs

After API calls complete:

```
****************************************
APP: onBackgroundData() called
APP: Data received: null
****************************************
APP: Reloading view with new background data...
========================================
VIEW: loadSettings() called
========================================
[... city loading with NEW offset values ...]
VIEW: City1Info - offset=3600, dst=true, lastUpdate=1734892123
APP: onBackgroundData() completed
****************************************
```

**What to look for:**
- ✅ `onBackgroundData()` is called after API fetch
- ✅ Settings reload with fresh data
- ✅ offset values are non-zero (real timezone offsets)
- ✅ lastUpdate has a timestamp

## Common Issues and Solutions

### Issue 1: No Settings File Found

**Error:** Script says "No settings file found"

**Solution:**
1. Run the simulator at least once to create the settings directory
2. The script will create the file automatically on first use

### Issue 2: Settings Don't Change

**Symptom:** Settings file updates but watchface shows old values

**Cause:** Simulator doesn't hot-reload settings

**Solution:**
1. Stop the simulator completely
2. Press F5 to restart
3. Settings will load on startup

### Issue 3: No Background Service Logs

**Symptom:** No "BACKGROUND:" logs appear

**Possible Causes:**
1. **No internet connection** - Simulator needs network access
2. **Background service not triggered** - Wait 5-10 seconds after settings change
3. **Phone not connected** - Simulator's Bluetooth setting must be "connected"

**Solution:**
1. Check simulator's Bluetooth icon (should be blue/connected)
2. Wait longer - background services can be delayed
3. Check VS Code Output window for any errors

### Issue 4: API Calls Fail

**Symptom:** `Response code: 404` or other non-200 codes

**Possible Causes:**
1. Invalid timezone string
2. WorldTimeAPI down or rate-limited
3. Network firewall blocking request

**Solution:**
1. Test API manually: `curl http://worldtimeapi.org/api/timezone/Europe/London`
2. Check zone IDs are valid (0-20)
3. Try again later if rate-limited

### Issue 5: Watchface Crashes

**Symptom:** Simulator crashes or displays nothing

**Debug Steps:**
1. Check Output window for ERROR messages
2. Look for the last successful log before crash
3. Try the "invalid_zones" test scenario to see if error handling works
4. Check if crash happens during:
   - Settings load (VIEW logs)
   - Property access (check zone ID types)
   - API response parsing (BACKGROUND logs)

**Common crash causes:**
- Null pointer access (cityInfo is null)
- Type mismatch (zone ID not a Number)
- Division by zero in calculations
- Out of bounds array access

## Testing Workflow

### Complete Test Procedure

1. **Start with default settings**
   ```powershell
   .\test_settings.ps1
   # Select option 1 (default)
   ```

2. **Launch simulator**
   ```
   Press F5 in VS Code
   ```

3. **Verify default load**
   - Check Output window
   - Look for "VIEW: loadSettings() called"
   - Verify all 4 cities load successfully

4. **Test settings change**
   - Stop simulator
   - Run test script again
   - Select option 2 (asia)
   - Restart simulator (F5)

5. **Verify settings change**
   - Check for "APP: onSettingsChanged()" in logs
   - Verify new zone IDs loaded
   - Watch for background service logs after 5 seconds

6. **Test error handling**
   - Stop simulator
   - Run test script
   - Select option 6 (invalid_zones)
   - Restart simulator
   - Check logs for ERROR messages
   - Verify watchface doesn't crash

7. **Test API fetch**
   - Wait for background service logs
   - Check API response codes
   - Verify offset values update
   - Confirm lastUpdate timestamp is set

## Quick Command Reference

### Run Test Script (Interactive)
```powershell
.\test_settings.ps1
```

### Apply Specific Scenario Directly
```powershell
.\test_settings.ps1 -Scenario asia
.\test_settings.ps1 -Scenario europe
.\test_settings.ps1 -Scenario invalid_zones
```

### Specify Different Device
```powershell
.\test_settings.ps1 -Device venu3
.\test_settings.ps1 -Device fenix7
```

### Show Current Settings
```powershell
.\test_settings.ps1 -Scenario menu
# Then select option 9
```

### Find Settings File Manually
```powershell
Get-ChildItem "$env:APPDATA\Garmin\ConnectIQ\Devices" -Recurse -Filter "a3421bee-d798-4dc2-a7c5-5a9b4d7e1234.json"
```

## Zone ID Reference

Quick reference for manual testing:

| ID | Timezone | Label Example |
|----|----------|---------------|
| 0  | London | LN, LON |
| 1  | Paris | PAR |
| 2  | Berlin | BER |
| 3  | Moscow | MSK |
| 4  | New York | NY, NYC |
| 5  | Chicago | CHI |
| 6  | Denver | DEN |
| 7  | Los Angeles | LA, LAX |
| 8  | Mexico City | MEX |
| 9  | São Paulo | SAO |
| 10 | Dubai | DXB |
| 11 | Kolkata | KOL |
| 12 | Singapore | SG, SIN |
| 13 | Hong Kong | HK |
| 14 | Tokyo | TKY |
| 15 | Shanghai | SHA |
| 16 | Sydney | SYD |
| 17 | Auckland | AKL |
| 18 | Honolulu | HNL |
| 19 | Johannesburg | JHB |
| 20 | Vienna | VIE |

## Removing Logging (Production)

Once you've finished debugging, you may want to remove the verbose logging:

1. Search for `System.println` in your code
2. Comment out or remove logging statements
3. Keep only critical error logging if desired

Or create a DEBUG flag:
```monkeyc
const DEBUG = false;  // Set to false for production

if (DEBUG) {
    System.println("Debug message");
}
```

## Need More Help?

If you're still experiencing issues:

1. Check all log sections (VIEW, APP, BACKGROUND)
2. Note exactly where the last successful log appears
3. Copy relevant error messages
4. Check the crashlog if simulator crashes
5. Verify your SDK version supports background services

Good luck debugging! 🐛🔍
