# Device Compatibility Testing Guide

## Overview
This guide explains how to test the GMT World Time watchface across different Garmin devices using the Connect IQ Simulator.

## Test Matrix

### Round Watches (Primary Target)
Test on these devices to cover different screen sizes:

| Device | Resolution | API Level | Priority |
|--------|------------|-----------|----------|
| Fenix 7 | 260x260 | 4.0 | High |
| Venu 3 | 454x454 | 5.0 | High |
| Forerunner 965 | 454x454 | 5.0 | High |
| Vivoactive 5 | 390x390 | 5.0 | Medium |
| Fenix 5 | 240x240 | 3.1 | Medium |
| Forerunner 245 | 240x240 | 3.2 | Medium |

### Rectangular Watches
| Device | Resolution | API Level | Priority |
|--------|------------|-----------|----------|
| Venu Sq 2 | 320x360 | 4.2 | Medium |
| Vivoactive 3 | 240x240 | 3.1 | Low |

## Test Cases

### TC-001: Main Time Display
**Steps:**
1. Launch watchface in simulator
2. Verify time displays correctly in center
3. Change device time settings (12h/24h)
4. Verify format changes accordingly

**Expected:** Large, centered time display. Clear and readable.

### TC-002: Date Display
**Steps:**
1. Verify date shows at top of screen
2. Check format is "DAY DD MON" (e.g., "THU 19 DEC")
3. Change device date
4. Verify display updates

**Expected:** Date displays correctly at top with day, date number, and month.

### TC-003: Bluetooth Status
**Steps:**
1. Verify Bluetooth icon appears next to date
2. Simulate connected state - should show blue filled circle
3. Simulate disconnected state - should show gray empty circle

**Expected:** Icon changes based on connection status.

### TC-004: Step Count
**Steps:**
1. Verify step count displays at bottom
2. Check walking figure icon appears
3. Simulate different step counts (0, 999, 1000, 10000, 99999)
4. Verify thousands separator formatting

**Expected:** Steps display with proper formatting (e.g., "8,432").

### TC-005: World Times - Top Row (LN, HK)
**Steps:**
1. Verify London (LN) time appears on left
2. Verify Hong Kong (HK) time appears on right
3. Change device timezone
4. Verify world times calculate correctly

**Expected:** Correct hour display for each timezone.

### TC-006: World Times - Bottom Row (NY, SF)
**Steps:**
1. Verify New York (NY) time appears on left
2. Verify San Francisco (SF) time appears on right
3. Test at midnight UTC to verify day wraparound

**Expected:** Correct hour display for each timezone, handling day boundaries.

### TC-007: Low Power Mode
**Steps:**
1. Let simulator enter sleep mode
2. Verify watchface remains visible
3. Verify update frequency reduces

**Expected:** Display remains readable in low power mode.

### TC-008: Screen Size Adaptation
**Steps:**
1. Test on smallest supported device (240x240)
2. Test on largest supported device (454x454)
3. Verify all elements are visible and properly positioned

**Expected:** Layout adapts to screen size, no clipping or overlap.

## Running Tests in Simulator

### Prerequisites
1. Install Connect IQ SDK
2. Install VS Code with Monkey C extension

### Command Line Testing
```bash
# Build for specific device
connectiq build -d fenix7 -o bin/GMTWorldTime-fenix7.prg

# Run in simulator
connectiq simulate -d fenix7 bin/GMTWorldTime-fenix7.prg
```

### VS Code Testing
1. Press F5 to build and launch
2. Select target device from dropdown
3. Use simulator controls to test various scenarios

## Automated Testing Script

Create a batch file `test_all_devices.bat`:
```batch
@echo off
setlocal enabledelayedexpansion

set DEVICES=fenix7 fenix5 venu3 fr965 vivoactive5 venusq2

for %%d in (%DEVICES%) do (
    echo Building for %%d...
    connectiq build -d %%d -o bin\GMTWorldTime-%%d.prg
    if !errorlevel! neq 0 (
        echo FAILED: %%d
    ) else (
        echo PASSED: %%d
    )
)
```

## Known Limitations

1. **DST Handling**: Current implementation uses fixed UTC offsets. Cities observing DST may show incorrect times during DST transitions.

2. **Very Old Devices**: Some pre-2017 devices may not support all API features used.

3. **Memory Constraints**: Low-memory devices may have performance issues with complex formatting.

## Reporting Issues

When reporting issues, include:
- Device model
- Firmware version
- Screenshot if possible
- Steps to reproduce
