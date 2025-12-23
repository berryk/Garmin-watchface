# Testing WorldTimeAPI Integration

This document describes how to test the WorldTimeAPI integration with smart caching.

## Automated Testing (Recommended)

### 1. GitHub Actions Build Test

The easiest way to test is to push your changes and let GitHub Actions build for all devices:

```bash
# Your changes are already committed and pushed!
# Check the GitHub Actions tab to see the build status
```

**What it tests:**
- ✅ Compilation for 16+ different Garmin devices
- ✅ Code syntax and type checking
- ✅ Resource validation (strings, settings, properties)
- ✅ Screenshot generation for each device
- 📊 Build artifacts available for download

**Check build status at:**
https://github.com/berryk/Garmin-watchface/actions

---

## Manual Testing

### 2. Local Build (Requires Docker)

Build for a specific device:

```bash
./scripts/local-build.sh venu2s
```

This will:
- Build the watchface for the specified device
- Create a `.prg` file in `bin/`
- Generate a screenshot in `screenshots/`

**Available devices:**
fenix7, fenix5, venu, venu2, venu2s, venu3, fr965, fr255, fr245, vivoactive5, epix2, etc.

### 3. Testing on Real Device

1. Build the watchface for your device
2. Transfer the `.prg` file to your watch using Garmin Express or Connect IQ app
3. Set as active watchface
4. Configure timezone settings in Garmin Connect Mobile app

---

## Feature Testing Checklist

### Settings Configuration

- [ ] Open Garmin Connect Mobile app
- [ ] Navigate to watchface settings
- [ ] Verify timezone dropdowns appear for all 4 cities
- [ ] Verify all 20 timezones are available:
  - Europe: London, Paris, Berlin, Moscow
  - Americas: New York, Chicago, Denver, Los Angeles, Mexico City, São Paulo
  - Asia: Dubai, Kolkata, Singapore, Hong Kong, Tokyo, Shanghai
  - Pacific: Sydney, Auckland, Honolulu
  - Africa: Johannesburg
- [ ] Verify label fields accept 3-character abbreviations
- [ ] Change a timezone and save

### Background Service Testing

**Initial Data Fetch:**
- [ ] After installing watchface, wait 5 seconds
- [ ] Background service should fetch timezone data for all 4 configured cities
- [ ] Times should display correctly (may take a minute for first sync)

**Settings Change Trigger:**
- [ ] Change a timezone in settings
- [ ] Background service should trigger within 5 seconds
- [ ] New timezone data should be fetched

**Daily Refresh:**
- [ ] Data should automatically refresh after 24 hours
- [ ] Check Application Storage to see cached data

### Smart Caching Testing

**Cache Validation:**
- [ ] Verify timezone data is stored between watch restarts
- [ ] Times should display immediately on startup (using cached data)
- [ ] Background refresh happens without user interaction

**DST Prediction (Advanced):**
- [ ] If a timezone passes its DST transition time while offline:
  - Watch should apply ±1 hour heuristic prediction
  - Background service should fetch exact data on next sync

### Display Testing

**Watchface Display:**
- [ ] All 4 configured timezones show correct hours
- [ ] User-specified labels appear correctly
- [ ] Main time displays correctly
- [ ] Date, Bluetooth, and step count still work

**Timezone Accuracy:**
- [ ] Compare displayed times with known correct times for each timezone
- [ ] Test cities in different DST states
- [ ] Test across day boundaries (23:00 → 00:00)

---

## API Testing

### Manual API Verification

You can test the WorldTimeAPI endpoints directly:

```bash
# Test London timezone
curl "http://worldtimeapi.org/api/timezone/Europe/London"

# Test New York timezone
curl "http://worldtimeapi.org/api/timezone/America/New_York"
```

**Expected response includes:**
- `raw_offset`: Base UTC offset in seconds
- `dst_offset`: DST adjustment in seconds (3600 if active, 0 if not)
- `dst`: Boolean indicating if DST is active
- `dst_until` or `dst_from`: ISO 8601 timestamp of next transition

### Network Failure Testing

- [ ] Enable airplane mode
- [ ] Install watchface (will use default offsets)
- [ ] Disable airplane mode
- [ ] Background service should fetch data within 5 seconds
- [ ] Times should update to accurate values

---

## Code Validation

### Static Analysis

Run the validation script to check for common issues:

```bash
./scripts/validate-code.sh
```

This checks:
- All timezone data files exist
- Settings/properties/strings are consistent
- No syntax errors in MonkeyC files
- Background service is properly registered

---

## Debugging

### Viewing Logs (Simulator)

If using the Connect IQ simulator:

1. Launch simulator with logging enabled
2. View console output for:
   - API request/response logs
   - Storage read/write operations
   - Timezone calculation results

### Common Issues

**Times show as "00":**
- Background service may not have run yet
- Check phone is connected (Bluetooth)
- Wait 5-10 seconds after changing settings

**Times are incorrect:**
- Verify API response has correct data
- Check device timezone settings
- Ensure cached data hasn't expired

**Background service not running:**
- Verify Communications permission in manifest
- Check phone has internet connection
- Ensure Background permission is granted

---

## Performance Testing

### Battery Impact

The smart caching design minimizes battery usage:

- **API calls**: Maximum 4 calls per 24 hours (one per timezone)
- **Background service**: Only runs when triggered (settings change or 24h refresh)
- **Storage**: Minimal - ~200 bytes per timezone

### Memory Usage

- TimezoneInfo objects: ~100 bytes each × 4 = 400 bytes
- Storage: ~200 bytes per timezone × 4 = 800 bytes
- Total overhead: ~1.2 KB

---

## Next Steps

After testing:

1. ✅ Verify all builds pass on GitHub Actions
2. 📱 Test on your actual Garmin device
3. 🌐 Check timezone accuracy for your location
4. 🔋 Monitor battery usage over a few days
5. 🐛 Report any issues or bugs

## Test Results Template

```markdown
### Test Results

**Device:** (e.g., Fenix 7)
**Date:** YYYY-MM-DD
**Build:** (commit hash or build number)

#### Compilation: ✅ / ❌
#### Settings UI: ✅ / ❌
#### Background Service: ✅ / ❌
#### Timezone Accuracy: ✅ / ❌
#### Display: ✅ / ❌

**Notes:**
(Any observations, issues, or special cases)
```
