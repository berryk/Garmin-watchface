@echo off
REM GMT World Time Watchface - Multi-Device Build Test
REM This script builds the watchface for multiple devices to verify compatibility

setlocal enabledelayedexpansion

echo ============================================
echo GMT World Time Watchface - Build Test
echo ============================================
echo.

REM Create bin directory if it doesn't exist
if not exist "bin" mkdir bin

REM Define test devices (representative of different screen sizes/types)
set DEVICES=fenix7 fenix5 venu3 fr965 fr245 vivoactive5 venusq2 epix2

set PASS_COUNT=0
set FAIL_COUNT=0

echo Testing build for multiple devices...
echo.

for %%d in (%DEVICES%) do (
    echo Building for %%d...
    
    REM Try to build for this device
    call connectiq build -d %%d -o bin\GMTWorldTime-%%d.prg -y developer_key.pem 2>nul
    
    if !errorlevel! equ 0 (
        echo   [PASS] %%d - Build successful
        set /a PASS_COUNT+=1
    ) else (
        echo   [FAIL] %%d - Build failed
        set /a FAIL_COUNT+=1
    )
    echo.
)

echo ============================================
echo Build Test Summary
echo ============================================
echo Passed: %PASS_COUNT%
echo Failed: %FAIL_COUNT%
echo.

if %FAIL_COUNT% equ 0 (
    echo All builds successful!
) else (
    echo Some builds failed. Check output above for details.
)

echo.
echo Output files are in the bin\ folder
pause
