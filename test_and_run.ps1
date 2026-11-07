<#
.SYNOPSIS
    Test settings and run simulator directly without VS Code

.PARAMETER Scenario
    Test scenario to apply (default, asia, europe, americas, mixed, invalid_zones, long_labels)
    
.PARAMETER Device
    Target device (default: fenix7)
#>

param(
    [string]$Scenario = "default",
    [string]$Device = "fenix7"
)

# SDK path (found by find_sdk.ps1)
$SDK_PATH = "$env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-8.4.0-2025-12-03-5122605dc\bin"
$MONKEYDO = Join-Path $SDK_PATH "monkeydo.bat"

# App UUID
$APP_UUID = "a3421bee-d798-4dc2-a7c5-5a9b4d7e1234"
$SETTINGS_PATH = "$env:APPDATA\Garmin\ConnectIQ\Devices\$Device\SETTINGS\$APP_UUID.json"

# Test scenarios
$SCENARIOS = @{
    "default" = @{
        "City1Zone" = 0; "City1Label" = "LN"
        "City2Zone" = 13; "City2Label" = "HK"
        "City3Zone" = 4; "City3Label" = "NY"
        "City4Zone" = 7; "City4Label" = "SF"
    }
    "asia" = @{
        "City1Zone" = 14; "City1Label" = "TKY"
        "City2Zone" = 13; "City2Label" = "HK"
        "City3Zone" = 12; "City3Label" = "SG"
        "City4Zone" = 15; "City4Label" = "SHA"
    }
    "europe" = @{
        "City1Zone" = 0; "City1Label" = "LN"
        "City2Zone" = 1; "City2Label" = "PAR"
        "City3Zone" = 2; "City3Label" = "BER"
        "City4Zone" = 20; "City4Label" = "VIE"
    }
    "americas" = @{
        "City1Zone" = 4; "City1Label" = "NY"
        "City2Zone" = 5; "City2Label" = "CHI"
        "City3Zone" = 6; "City3Label" = "DEN"
        "City4Zone" = 7; "City4Label" = "LA"
    }
    "mixed" = @{
        "City1Zone" = 0; "City1Label" = "LN"
        "City2Zone" = 14; "City2Label" = "TKY"
        "City3Zone" = 4; "City3Label" = "NY"
        "City4Zone" = 16; "City4Label" = "SYD"
    }
    "invalid_zones" = @{
        "City1Zone" = 999; "City1Label" = "ERR"
        "City2Zone" = -1; "City2Label" = "BAD"
        "City3Zone" = 4; "City3Label" = "NY"
        "City4Zone" = 7; "City4Label" = "SF"
    }
    "long_labels" = @{
        "City1Zone" = 0; "City1Label" = "VERYLONGLABEL"
        "City2Zone" = 13; "City2Label" = "TOOLONG"
        "City3Zone" = 4; "City3Label" = "NY"
        "City4Zone" = 7; "City4Label" = "SF"
    }
}

Write-Host "=== GMT World Time - Quick Test & Run ===" -ForegroundColor Cyan
Write-Host "Scenario: $Scenario" -ForegroundColor Yellow
Write-Host "Device: $Device`n" -ForegroundColor Yellow

# Check if scenario exists
if (-not $SCENARIOS.ContainsKey($Scenario)) {
    Write-Host "ERROR: Unknown scenario '$Scenario'" -ForegroundColor Red
    Write-Host "Available: $($SCENARIOS.Keys -join ', ')" -ForegroundColor Yellow
    exit 1
}

# Check if monkeydo exists
if (-not (Test-Path $MONKEYDO)) {
    Write-Host "ERROR: monkeydo.exe not found at: $MONKEYDO" -ForegroundColor Red
    Write-Host "Run find_sdk.ps1 to locate your SDK" -ForegroundColor Yellow
    exit 1
}

# Create settings directory if needed
$settingsDir = Split-Path -Parent $SETTINGS_PATH
if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    Write-Host "Created settings directory" -ForegroundColor Gray
}

# Write settings
$settings = $SCENARIOS[$Scenario]
$json = $settings | ConvertTo-Json -Depth 10
Set-Content -Path $SETTINGS_PATH -Value $json -Encoding UTF8

Write-Host "Settings applied:" -ForegroundColor Green
$settings | Format-Table -AutoSize

Write-Host "`nBuilding and launching simulator..." -ForegroundColor Cyan
Write-Host "Command: monkeydo monkey.jungle $Device`n" -ForegroundColor Gray

# Run monkeydo
& $MONKEYDO "monkey.jungle" $Device

Write-Host "`nSimulator should be running!" -ForegroundColor Green
Write-Host "Check the simulator window for the watchface" -ForegroundColor Yellow
Write-Host "Logs will appear in the simulator's console" -ForegroundColor Yellow
