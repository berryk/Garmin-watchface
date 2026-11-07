<#
.SYNOPSIS
    Test script to change watchface settings in the simulator

.DESCRIPTION
    This script automatically modifies the settings JSON file for the GMT World Time watchface
    in the Connect IQ simulator. You can select from predefined test scenarios or create custom settings.

.PARAMETER Device
    The device simulator to target (default: fenix7)

.PARAMETER Scenario
    Predefined test scenario to apply
#>

param(
    [string]$Device = "fenix7",
    [string]$Scenario = "menu",
    [switch]$AutoLaunch = $false
)

# App UUID from manifest.xml
$APP_UUID = "a3421bee-d798-4dc2-a7c5-5a9b4d7e1234"

# Settings file path
$SETTINGS_PATH = "$env:APPDATA\Garmin\ConnectIQ\Devices\$Device\SETTINGS\$APP_UUID.json"

# Predefined test scenarios
$SCENARIOS = @{
    "default" = @{
        "City1Zone" = 0
        "City1Label" = "LN"
        "City2Zone" = 13
        "City2Label" = "HK"
        "City3Zone" = 4
        "City3Label" = "NY"
        "City4Zone" = 7
        "City4Label" = "SF"
    }
    "asia" = @{
        "City1Zone" = 14  # Tokyo
        "City1Label" = "TKY"
        "City2Zone" = 13  # Hong Kong
        "City2Label" = "HK"
        "City3Zone" = 12  # Singapore
        "City3Label" = "SG"
        "City4Zone" = 15  # Shanghai
        "City4Label" = "SHA"
    }
    "europe" = @{
        "City1Zone" = 0   # London
        "City1Label" = "LN"
        "City2Zone" = 1   # Paris
        "City2Label" = "PAR"
        "City3Zone" = 2   # Berlin
        "City3Label" = "BER"
        "City4Zone" = 20  # Vienna
        "City4Label" = "VIE"
    }
    "americas" = @{
        "City1Zone" = 4   # New York
        "City1Label" = "NY"
        "City2Zone" = 5   # Chicago
        "City2Label" = "CHI"
        "City3Zone" = 6   # Denver
        "City3Label" = "DEN"
        "City4Zone" = 7   # Los Angeles
        "City4Label" = "LA"
    }
    "mixed" = @{
        "City1Zone" = 0   # London
        "City1Label" = "LN"
        "City2Zone" = 14  # Tokyo
        "City2Label" = "TKY"
        "City3Zone" = 4   # New York
        "City3Label" = "NY"
        "City4Zone" = 16  # Sydney
        "City4Label" = "SYD"
    }
    "invalid_zones" = @{
        "City1Zone" = 999
        "City1Label" = "ERR"
        "City2Zone" = -1
        "City2Label" = "BAD"
        "City3Zone" = 4
        "City3Label" = "NY"
        "City4Zone" = 7
        "City4Label" = "SF"
    }
    "long_labels" = @{
        "City1Zone" = 0
        "City1Label" = "VERYLONGLABEL"
        "City2Zone" = 13
        "City2Label" = "TOOLONG"
        "City3Zone" = 4
        "City3Label" = "NY"
        "City4Zone" = 7
        "City4Label" = "SF"
    }
}

# Function to display menu
function Show-Menu {
    Write-Host "`n=== GMT World Time - Settings Test Script ===" -ForegroundColor Cyan
    Write-Host "Device: $Device" -ForegroundColor Yellow
    Write-Host "Settings File: $SETTINGS_PATH`n" -ForegroundColor Gray
    
    Write-Host "Available Test Scenarios:" -ForegroundColor Green
    Write-Host "  1. default        - Default settings (LN, HK, NY, SF)"
    Write-Host "  2. asia          - Asian cities (Tokyo, Hong Kong, Singapore, Shanghai)"
    Write-Host "  3. europe        - European cities (London, Paris, Berlin, Vienna)"
    Write-Host "  4. americas      - American cities (NY, Chicago, Denver, LA)"
    Write-Host "  5. mixed         - Mixed global cities (London, Tokyo, NY, Sydney)"
    Write-Host "  6. invalid_zones - Invalid zone IDs (999, -1) - Test error handling"
    Write-Host "  7. long_labels   - Very long labels - Test overflow handling"
    Write-Host "  8. custom        - Enter custom values"
    Write-Host "  9. show          - Show current settings"
    Write-Host "  0. exit          - Exit script`n"
}

# Function to apply settings
function Apply-Settings {
    param(
        $Settings,
        [bool]$Launch = $false
    )
    
    # Check if settings directory exists
    $settingsDir = Split-Path -Parent $SETTINGS_PATH
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        Write-Host "Created settings directory: $settingsDir" -ForegroundColor Yellow
    }
    
    # Convert to JSON and save
    $json = $Settings | ConvertTo-Json -Depth 10
    Set-Content -Path $SETTINGS_PATH -Value $json -Encoding UTF8
    
    Write-Host "`nSettings updated successfully!" -ForegroundColor Green
    Write-Host "File: $SETTINGS_PATH" -ForegroundColor Gray
    Write-Host "`nCurrent settings:" -ForegroundColor Cyan
    $Settings | Format-Table -AutoSize
    
    if ($Launch) {
        Write-Host "`nLaunching simulator..." -ForegroundColor Cyan
        Start-Simulator
    } else {
        Write-Host "`nIMPORTANT: Restart the simulator to apply changes!" -ForegroundColor Yellow
        Write-Host "  1. Stop the simulator (if running)" -ForegroundColor Gray
        Write-Host "  2. Press F5 in VS Code to restart" -ForegroundColor Gray
        Write-Host "`nTip: Use -AutoLaunch switch to automatically launch simulator" -ForegroundColor Gray
    }
}

# Function to show current settings
function Show-CurrentSettings {
    if (Test-Path $SETTINGS_PATH) {
        Write-Host "`nCurrent Settings:" -ForegroundColor Cyan
        $current = Get-Content $SETTINGS_PATH | ConvertFrom-Json
        $current | Format-List
    } else {
        Write-Host "`nNo settings file found. File will be created when you apply settings." -ForegroundColor Yellow
        Write-Host "Path: $SETTINGS_PATH" -ForegroundColor Gray
    }
}

# Function to launch simulator
function Start-Simulator {
    try {
        Write-Host "`nBuilding and launching simulator..." -ForegroundColor Cyan
        
        # Find Connect IQ SDK
        $sdkPaths = @(
            "$env:APPDATA\Garmin\ConnectIQ\Sdks",
            "$env:ProgramFiles\Garmin\ConnectIQ",
            "C:\Garmin\ConnectIQ"
        )
        
        $connectiqCmd = $null
        $monkeydoCmd = $null
        
        foreach ($sdkPath in $sdkPaths) {
            if (Test-Path $sdkPath) {
                Write-Host "Searching for SDK in: $sdkPath" -ForegroundColor Gray
                
                # Look for latest SDK version
                $sdkDirs = Get-ChildItem -Path $sdkPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
                
                foreach ($sdkDir in $sdkDirs) {
                    $binPath = Join-Path $sdkDir.FullName "bin"
                    
                    if (-not (Test-Path $binPath)) {
                        continue
                    }
                    
                    $connectiqExe = Join-Path $binPath "connectiq.exe"
                    $monkeydoExe = Join-Path $binPath "monkeydo.exe"
                    $monkeycExe = Join-Path $binPath "monkeyc.exe"
                    $simulatorExe = Join-Path $binPath "simulator.exe"
                    
                    if (Test-Path $monkeydoExe) {
                        $monkeydoCmd = $monkeydoExe
                        Write-Host "Found monkeydo: $monkeydoCmd" -ForegroundColor Green
                        break
                    }
                    
                    if (Test-Path $monkeycExe) {
                        $connectiqCmd = $monkeycExe
                        Write-Host "Found monkeyc: $connectiqCmd" -ForegroundColor Green
                        
                        if (Test-Path $simulatorExe) {
                            Write-Host "Found simulator: $simulatorExe" -ForegroundColor Green
                        }
                    }
                    
                    if (Test-Path $connectiqExe) {
                        $connectiqCmd = $connectiqExe
                        Write-Host "Found connectiq: $connectiqCmd" -ForegroundColor Green
                    }
                }
                
                if ($connectiqCmd -or $monkeydoCmd) {
                    break
                }
            }
        }
        
        # Try to find in PATH as fallback
        if (-not $connectiqCmd -and -not $monkeydoCmd) {
            $connectiqCmdObj = Get-Command connectiq -ErrorAction SilentlyContinue
            if ($connectiqCmdObj) {
                $connectiqCmd = $connectiqCmdObj.Source
            }
            
            $monkeydoCmdObj = Get-Command monkeydo -ErrorAction SilentlyContinue
            if ($monkeydoCmdObj) {
                $monkeydoCmd = $monkeydoCmdObj.Source
            }
        }
        
        if (-not $connectiqCmd -and -not $monkeydoCmd) {
            Write-Host "`nERROR: Could not find Connect IQ SDK tools" -ForegroundColor Red
            Write-Host "Please ensure the Connect IQ SDK is installed" -ForegroundColor Yellow
            Write-Host "`nAlternatively, build manually with:" -ForegroundColor Yellow
            Write-Host "  1. Open VS Code" -ForegroundColor Gray
            Write-Host "  2. Press F5 to build and launch" -ForegroundColor Gray
            return
        }
        
        # Build the project
        Write-Host "`nBuilding watchface for $Device..." -ForegroundColor Cyan
        
        $projectPath = Get-Location
        $outputDir = Join-Path $projectPath "bin"
        $outputFile = Join-Path $outputDir "GMTWorldTime-$Device.prg"
        
        # Create bin directory if it doesn't exist
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        # Use monkeydo if available (simpler), otherwise use connectiq
        if ($monkeydoCmd) {
            Write-Host "Using monkeydo to build and launch..." -ForegroundColor Gray
            Write-Host "Command: monkeydo monkey.jungle $Device --start" -ForegroundColor DarkGray
            
            $process = Start-Process -FilePath $monkeydoCmd -ArgumentList "monkey.jungle", $Device, "--start" -NoNewWindow -PassThru -Wait
            
            if ($process.ExitCode -eq 0) {
                Write-Host "`nSimulator launched successfully!" -ForegroundColor Green
                Write-Host "Check the simulator window and VS Code Output panel for logs" -ForegroundColor Yellow
            } else {
                Write-Host "`nBuild/launch failed with exit code: $($process.ExitCode)" -ForegroundColor Red
                Write-Host "Try building manually in VS Code (F5)" -ForegroundColor Yellow
            }
        } elseif ($connectiqCmd) {
            Write-Host "Using connectiq to build..." -ForegroundColor Gray
            
            # Build first
            $buildArgs = @("build", "-d", $Device, "-o", $outputFile)
            Write-Host "Command: connectiq $($buildArgs -join ' ')" -ForegroundColor DarkGray
            
            $buildProcess = Start-Process -FilePath $connectiqCmd -ArgumentList $buildArgs -NoNewWindow -PassThru -Wait
            
            if ($buildProcess.ExitCode -eq 0) {
                Write-Host "Build successful!" -ForegroundColor Green
                
                # Launch simulator
                Write-Host "Launching simulator..." -ForegroundColor Cyan
                $simArgs = @("simulate", "-d", $Device, $outputFile)
                Write-Host "Command: connectiq $($simArgs -join ' ')" -ForegroundColor DarkGray
                
                Start-Process -FilePath $connectiqCmd -ArgumentList $simArgs
                
                Write-Host "`nSimulator launched!" -ForegroundColor Green
                Write-Host "Check the simulator window and VS Code Output panel for logs" -ForegroundColor Yellow
            } else {
                Write-Host "`nBuild failed with exit code: $($buildProcess.ExitCode)" -ForegroundColor Red
                Write-Host "Try building manually in VS Code (F5)" -ForegroundColor Yellow
            }
        }
        
    } catch {
        Write-Host "`nError launching simulator: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Try building manually in VS Code (F5)" -ForegroundColor Yellow
    }
}

# Function to get custom settings
function Get-CustomSettings {
    Write-Host "`n=== Custom Settings ===" -ForegroundColor Cyan
    Write-Host "Enter values for each city (or press Enter for default)`n"
    
    # Zone IDs reference
    Write-Host "Zone IDs:" -ForegroundColor Yellow
    Write-Host "  0=London, 1=Paris, 2=Berlin, 3=Moscow, 4=New York, 5=Chicago"
    Write-Host "  6=Denver, 7=Los Angeles, 8=Mexico City, 9=Sao Paulo"
    Write-Host "  10=Dubai, 11=Kolkata, 12=Singapore, 13=Hong Kong, 14=Tokyo"
    Write-Host "  15=Shanghai, 16=Sydney, 17=Auckland, 18=Honolulu"
    Write-Host "  19=Johannesburg, 20=Vienna`n"
    
    $settings = @{}
    
    for ($i = 1; $i -le 4; $i++) {
        Write-Host "City ${i}:" -ForegroundColor Green
        $zone = Read-Host "  Zone ID (0-20)"
        $label = Read-Host "  Label (max 3 chars)"
        
        if ($zone -eq "") { $zone = 0 }
        if ($label -eq "") { $label = "C$i" }
        
        $settings["City${i}Zone"] = [int]$zone
        $settings["City${i}Label"] = $label
    }
    
    return $settings
}

# Main script logic
if ($Scenario -ne "menu") {
    # Direct scenario application
    if ($SCENARIOS.ContainsKey($Scenario)) {
        Apply-Settings -Settings $SCENARIOS[$Scenario] -Launch $AutoLaunch
    } else {
        Write-Host "Unknown scenario: $Scenario" -ForegroundColor Red
        Write-Host "Available scenarios: $($SCENARIOS.Keys -join ', ')" -ForegroundColor Yellow
    }
    exit
}

# Interactive menu
while ($true) {
    Show-Menu
    $choice = Read-Host "Select option (0-9)"
    
    switch ($choice) {
        "1" { Apply-Settings -Settings $SCENARIOS["default"] -Launch $AutoLaunch }
        "2" { Apply-Settings -Settings $SCENARIOS["asia"] -Launch $AutoLaunch }
        "3" { Apply-Settings -Settings $SCENARIOS["europe"] -Launch $AutoLaunch }
        "4" { Apply-Settings -Settings $SCENARIOS["americas"] -Launch $AutoLaunch }
        "5" { Apply-Settings -Settings $SCENARIOS["mixed"] -Launch $AutoLaunch }
        "6" { 
            Write-Host "`nWARNING: This scenario contains invalid zone IDs to test error handling!" -ForegroundColor Red
            $confirm = Read-Host "Continue? (y/n)"
            if ($confirm -eq "y") {
                Apply-Settings -Settings $SCENARIOS["invalid_zones"] -Launch $AutoLaunch
            }
        }
        "7" {
            Write-Host "`nWARNING: This scenario contains labels longer than 3 characters!" -ForegroundColor Red
            $confirm = Read-Host "Continue? (y/n)"
            if ($confirm -eq "y") {
                Apply-Settings -Settings $SCENARIOS["long_labels"] -Launch $AutoLaunch
            }
        }
        "8" { 
            $customSettings = Get-CustomSettings
            Apply-Settings -Settings $customSettings -Launch $AutoLaunch
        }
        "9" { Show-CurrentSettings }
        "0" { 
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit 
        }
        default { Write-Host "Invalid choice. Please select 0-9." -ForegroundColor Red }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
