# GMT World Time - Build and Test Script
# This script builds and tests the watchface on the simulator

$ErrorActionPreference = "Continue"

# Configuration
$javaPath = "C:\Program Files\Java\jdk-17\bin\java.exe"
$sdkPath = "C:\Users\keith\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-8.4.0-2025-12-03-5122605dc"
$monkeyBrains = "$sdkPath\bin\monkeybrains.jar"
$shellExe = "$sdkPath\bin\shell.exe"
$simulatorExe = "$sdkPath\bin\simulator.exe"
$keyFile = "developer_key.der"

# Device to test
$device = "fenix7"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GMT World Time - Build and Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if key exists
if (-not (Test-Path $keyFile)) {
    Write-Host "ERROR: Developer key not found: $keyFile" -ForegroundColor Red
    exit 1
}

# Create bin directory
if (-not (Test-Path "bin")) {
    New-Item -ItemType Directory -Path "bin" | Out-Null
}

# Build
Write-Host "`nBuilding for $device..." -ForegroundColor Yellow
$buildOutput = & $javaPath -jar $monkeyBrains -o "bin\GMTWorldTime-$device.prg" -f monkey.jungle -d $device -y $keyFile -w 2>&1

$buildSuccess = $LASTEXITCODE -eq 0
if ($buildOutput -match "BUILD SUCCESSFUL") {
    Write-Host "Build SUCCESSFUL!" -ForegroundColor Green
    $prgSize = (Get-Item "bin\GMTWorldTime-$device.prg").Length
    Write-Host "Output: bin\GMTWorldTime-$device.prg ($prgSize bytes)" -ForegroundColor Gray
} else {
    Write-Host "Build FAILED!" -ForegroundColor Red
    Write-Host $buildOutput
    exit 1
}

# Ask to run simulator
$response = Read-Host "`nDo you want to run in simulator? (y/n)"
if ($response -eq "y") {
    Write-Host "Starting simulator..." -ForegroundColor Yellow
    Start-Process $simulatorExe
    Start-Sleep -Seconds 5
    
    Write-Host "Loading watchface..." -ForegroundColor Yellow
    & $javaPath -classpath $monkeyBrains com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux -f "bin\GMTWorldTime-$device.prg" -d $device -s $shellExe
}

Write-Host "`nDone!" -ForegroundColor Cyan
