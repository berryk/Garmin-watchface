@echo off
REM GMT World Time Watchface - Build and Screenshot Script
REM This script builds the watchface for multiple devices and launches simulator for screenshots

setlocal enabledelayedexpansion

echo.
echo ================================================================
echo    GMT World Time Watchface - Build ^& Screenshot Tool
echo ================================================================
echo.

REM Try to find SDK
set SDK_PATH=
for /d %%d in ("%APPDATA%\Garmin\ConnectIQ\Sdks\*") do set SDK_PATH=%%d
if "%SDK_PATH%"=="" (
    for /d %%d in ("%LOCALAPPDATA%\Garmin\ConnectIQ\Sdks\*") do set SDK_PATH=%%d
)

if "%SDK_PATH%"=="" (
    echo ERROR: Connect IQ SDK not found!
    echo.
    echo Please install the SDK:
    echo 1. Go to https://developer.garmin.com/connect-iq/sdk/
    echo 2. Download and run the SDK Manager
    echo 3. Install the latest SDK version
    echo 4. Run this script again
    echo.
    pause
    exit /b 1
)

echo Found SDK: %SDK_PATH%
echo.

REM Check for developer key
if not exist "developer_key.pem" (
    echo WARNING: developer_key.pem not found
    echo.
    echo Attempting to generate developer key...
    
    where openssl >nul 2>&1
    if !errorlevel! equ 0 (
        openssl genrsa -out developer_key.pem 4096 2>nul
        echo Developer key generated.
    ) else (
        echo Please generate a developer key manually:
        echo 1. Open Connect IQ SDK Manager
        echo 2. Go to Tools ^> Generate Key
        echo 3. Save as developer_key.pem in this folder
        pause
        exit /b 1
    )
)

REM Create directories
if not exist "bin" mkdir bin
if not exist "screenshots" mkdir screenshots

REM Device list
set DEVICES=fenix7 fenix5 venu3 venu2 venusq2 fr965 fr265 fr255 fr245 vivoactive5 vivoactive4 epix2 enduro2

echo Building for multiple devices...
echo.

set PASS=0
set FAIL=0

for %%d in (%DEVICES%) do (
    echo [%%d] Building...
    
    "%SDK_PATH%\bin\monkeyc.bat" -d %%d -f monkey.jungle -o bin\GMTWorldTime-%%d.prg -y developer_key.pem -w 2>nul
    
    if exist "bin\GMTWorldTime-%%d.prg" (
        echo [%%d] BUILD PASSED
        set /a PASS+=1
    ) else (
        echo [%%d] BUILD FAILED
        set /a FAIL+=1
    )
)

echo.
echo ================================================================
echo BUILD SUMMARY
echo ================================================================
echo Passed: %PASS%
echo Failed: %FAIL%
echo.

if %FAIL% gtr 0 (
    echo Some builds failed. Check the output above.
    echo.
)

echo.
echo Would you like to launch the simulator to take screenshots?
echo.
choice /c YN /m "Launch simulator"

if errorlevel 2 goto :end

echo.
echo Launching simulator for each device...
echo Take screenshots manually using File ^> Export ^> Screenshot in the simulator
echo.

for %%d in (%DEVICES%) do (
    if exist "bin\GMTWorldTime-%%d.prg" (
        echo.
        echo ================================================================
        echo Launching: %%d
        echo ================================================================
        echo.
        echo 1. Wait for simulator to load
        echo 2. Take screenshot: File ^> Export ^> Screenshot
        echo 3. Save to: screenshots\%%d.png
        echo 4. Close simulator to continue
        echo.
        
        start /wait "" "%SDK_PATH%\bin\simulator.exe"
        
        REM Give simulator time to start
        timeout /t 2 /nobreak >nul
        
        REM Push app to simulator
        "%SDK_PATH%\bin\monkeydo.bat" bin\GMTWorldTime-%%d.prg %%d 2>nul
        
        echo Press any key when done with %%d...
        pause >nul
        
        REM Kill simulator
        taskkill /f /im simulator.exe 2>nul
    )
)

:end
echo.
echo ================================================================
echo Complete!
echo ================================================================
echo.
echo Compiled files: bin\
echo Screenshots: screenshots\ (if taken)
echo.
pause
