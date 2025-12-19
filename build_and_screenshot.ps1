# GMT World Time Watchface - Build and Screenshot Automation Script
# This script builds the watchface for all devices and captures simulator screenshots

param(
    [string]$SdkPath = "",
    [string]$DevKey = "developer_key.pem",
    [switch]$SkipBuild = $false,
    [switch]$Help = $false
)

# Configuration
$ProjectName = "GMTWorldTime"
$ScreenshotDir = "screenshots"
$BinDir = "bin"
$ManifestPath = "manifest.xml"

# Devices to test - representative sample of different screen types/sizes
$TestDevices = @(
    @{ Id = "fenix7"; Name = "Fenix 7"; Resolution = "260x260"; Type = "Round" },
    @{ Id = "fenix5"; Name = "Fenix 5"; Resolution = "240x240"; Type = "Round" },
    @{ Id = "fenix8"; Name = "Fenix 8"; Resolution = "416x416"; Type = "Round AMOLED" },
    @{ Id = "venu3"; Name = "Venu 3"; Resolution = "454x454"; Type = "Round AMOLED" },
    @{ Id = "venu2"; Name = "Venu 2"; Resolution = "416x416"; Type = "Round AMOLED" },
    @{ Id = "venusq2"; Name = "Venu Sq 2"; Resolution = "320x360"; Type = "Rectangle" },
    @{ Id = "fr965"; Name = "Forerunner 965"; Resolution = "454x454"; Type = "Round AMOLED" },
    @{ Id = "fr265"; Name = "Forerunner 265"; Resolution = "416x416"; Type = "Round AMOLED" },
    @{ Id = "fr255"; Name = "Forerunner 255"; Resolution = "260x260"; Type = "Round MIP" },
    @{ Id = "fr245"; Name = "Forerunner 245"; Resolution = "240x240"; Type = "Round MIP" },
    @{ Id = "vivoactive5"; Name = "Vivoactive 5"; Resolution = "390x390"; Type = "Round AMOLED" },
    @{ Id = "vivoactive4"; Name = "Vivoactive 4"; Resolution = "260x260"; Type = "Round" },
    @{ Id = "epix2"; Name = "Epix 2"; Resolution = "416x416"; Type = "Round AMOLED" },
    @{ Id = "instinct2"; Name = "Instinct 2"; Resolution = "176x176"; Type = "Round MIP" },
    @{ Id = "enduro2"; Name = "Enduro 2"; Resolution = "280x280"; Type = "Round MIP" }
)

function Show-Help {
    Write-Host @"
GMT World Time Watchface - Build and Screenshot Tool
=====================================================

Usage: .\build_and_screenshot.ps1 [options]

Options:
    -SdkPath <path>    Path to Connect IQ SDK (auto-detected if not specified)
    -DevKey <file>     Path to developer key file (default: developer_key.pem)
    -SkipBuild         Skip building, only run simulator and take screenshots
    -Help              Show this help message

Examples:
    .\build_and_screenshot.ps1
    .\build_and_screenshot.ps1 -SdkPath "C:\ConnectIQ\Sdks\connectiq-sdk-4.2.0"
    .\build_and_screenshot.ps1 -SkipBuild

Requirements:
    1. Connect IQ SDK installed
    2. Developer key generated (developer_key.pem)
    3. Project source files in place

Output:
    - Compiled .prg files in bin\ folder
    - Screenshots in screenshots\ folder
    - Build report in screenshots\build_report.html
"@
}

function Find-ConnectIQSDK {
    # Common SDK locations
    $possiblePaths = @(
        "$env:APPDATA\Garmin\ConnectIQ\Sdks",
        "$env:LOCALAPPDATA\Garmin\ConnectIQ\Sdks",
        "C:\Garmin\ConnectIQ\Sdks",
        "$env:USERPROFILE\ConnectIQ\Sdks"
    )
    
    foreach ($basePath in $possiblePaths) {
        if (Test-Path $basePath) {
            $sdkFolders = Get-ChildItem -Path $basePath -Directory | Sort-Object Name -Descending
            foreach ($folder in $sdkFolders) {
                $binPath = Join-Path $folder.FullName "bin"
                if (Test-Path (Join-Path $binPath "monkeyc.bat")) {
                    return $folder.FullName
                }
            }
        }
    }
    
    # Check if SDK is in PATH
    $monkeyc = Get-Command "monkeyc" -ErrorAction SilentlyContinue
    if ($monkeyc) {
        return Split-Path (Split-Path $monkeyc.Source)
    }
    
    return $null
}

function Test-Prerequisites {
    param([string]$SdkPath)
    
    $errors = @()
    
    # Check SDK
    if (-not $SdkPath -or -not (Test-Path $SdkPath)) {
        $errors += "Connect IQ SDK not found. Please install from https://developer.garmin.com/connect-iq/sdk/"
    } else {
        $monkeycPath = Join-Path $SdkPath "bin\monkeyc.bat"
        $simulatorPath = Join-Path $SdkPath "bin\simulator.exe"
        
        if (-not (Test-Path $monkeycPath)) {
            $errors += "monkeyc compiler not found at: $monkeycPath"
        }
        if (-not (Test-Path $simulatorPath)) {
            $errors += "Simulator not found at: $simulatorPath"
        }
    }
    
    # Check manifest
    if (-not (Test-Path $ManifestPath)) {
        $errors += "manifest.xml not found in current directory"
    }
    
    # Check source files
    if (-not (Test-Path "source\GMTWorldTimeView.mc")) {
        $errors += "Source files not found"
    }
    
    # Check developer key
    if (-not (Test-Path $DevKey)) {
        Write-Host "WARNING: Developer key not found. Creating a temporary one..." -ForegroundColor Yellow
        # We'll handle this later
    }
    
    return $errors
}

function Build-ForDevice {
    param(
        [string]$SdkPath,
        [string]$DeviceId,
        [string]$OutputPath,
        [string]$DevKey
    )
    
    $monkeycPath = Join-Path $SdkPath "bin\monkeyc.bat"
    
    # Build command
    $buildArgs = @(
        "-d", $DeviceId,
        "-f", "monkey.jungle",
        "-o", $OutputPath,
        "-y", $DevKey,
        "-w"  # Show warnings
    )
    
    try {
        $process = Start-Process -FilePath $monkeycPath -ArgumentList $buildArgs -NoNewWindow -Wait -PassThru -RedirectStandardError "build_error.tmp"
        $exitCode = $process.ExitCode
        
        if (Test-Path "build_error.tmp") {
            $errorContent = Get-Content "build_error.tmp" -Raw
            Remove-Item "build_error.tmp" -Force
        }
        
        if ($exitCode -eq 0 -and (Test-Path $OutputPath)) {
            return @{ Success = $true; Error = $null }
        } else {
            return @{ Success = $false; Error = $errorContent }
        }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Start-SimulatorAndCapture {
    param(
        [string]$SdkPath,
        [string]$DeviceId,
        [string]$PrgPath,
        [string]$ScreenshotPath
    )
    
    $simulatorPath = Join-Path $SdkPath "bin\simulator.exe"
    $connectiqPath = Join-Path $SdkPath "bin\connectiq.bat"
    
    try {
        # Start the simulator
        Write-Host "    Starting simulator..." -ForegroundColor Gray
        
        # Use connectiq to start simulator with the device
        $simProcess = Start-Process -FilePath $simulatorPath -PassThru
        Start-Sleep -Seconds 3
        
        # Push the app to simulator using connectiq shell/monkeydo
        $monkeydoPath = Join-Path $SdkPath "bin\monkeydo.bat"
        if (Test-Path $monkeydoPath) {
            Start-Process -FilePath $monkeydoPath -ArgumentList @($PrgPath, $DeviceId) -NoNewWindow -Wait
        }
        
        Start-Sleep -Seconds 2
        
        # Take screenshot using Windows API
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        # Find the simulator window and capture it
        Start-Sleep -Seconds 1
        
        # Use nircmd or built-in screenshot if available
        # Fallback: use .NET to capture screen region
        
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bitmap = New-Object System.Drawing.Bitmap($screen.Bounds.Width, $screen.Bounds.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Bounds.Location, [System.Drawing.Point]::Empty, $screen.Bounds.Size)
        
        # Save full screen (we'll crop later or user can crop)
        $bitmap.Save($ScreenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $graphics.Dispose()
        $bitmap.Dispose()
        
        # Close simulator
        if ($simProcess -and -not $simProcess.HasExited) {
            $simProcess.CloseMainWindow()
            Start-Sleep -Milliseconds 500
            if (-not $simProcess.HasExited) {
                $simProcess.Kill()
            }
        }
        
        # Also try to close any other simulator windows
        Get-Process -Name "simulator" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        
        return @{ Success = $true; Error = $null }
    } catch {
        # Try to clean up
        Get-Process -Name "simulator" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function New-DeveloperKey {
    param([string]$SdkPath)
    
    Write-Host "Generating developer key..." -ForegroundColor Yellow
    
    # Try using openssl if available
    $openssl = Get-Command "openssl" -ErrorAction SilentlyContinue
    if ($openssl) {
        & openssl genrsa -out developer_key.pem 4096 2>&1 | Out-Null
        if (Test-Path "developer_key.pem") {
            Write-Host "Developer key generated: developer_key.pem" -ForegroundColor Green
            return $true
        }
    }
    
    # Try using SDK's built-in key generator
    $keygenPath = Join-Path $SdkPath "bin\generatekey.bat"
    if (Test-Path $keygenPath) {
        & $keygenPath developer_key.pem 2>&1 | Out-Null
        if (Test-Path "developer_key.pem") {
            Write-Host "Developer key generated: developer_key.pem" -ForegroundColor Green
            return $true
        }
    }
    
    Write-Host "Could not generate developer key automatically." -ForegroundColor Red
    Write-Host "Please generate manually using SDK Manager or openssl." -ForegroundColor Yellow
    return $false
}

function New-BuildReport {
    param(
        [array]$Results,
        [string]$OutputPath
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>GMT World Time - Build Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; background: #f5f5f5; }
        h1 { color: #333; }
        .summary { background: #fff; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .device-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
        .device-card { background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .device-header { padding: 15px; border-bottom: 1px solid #eee; }
        .device-name { font-weight: 600; font-size: 16px; }
        .device-info { color: #666; font-size: 12px; margin-top: 4px; }
        .device-screenshot { width: 100%; height: 250px; object-fit: contain; background: #1a1a1a; }
        .device-status { padding: 10px 15px; font-size: 12px; }
        .status-pass { background: #d4edda; color: #155724; }
        .status-fail { background: #f8d7da; color: #721c24; }
        .no-screenshot { display: flex; align-items: center; justify-content: center; height: 250px; background: #333; color: #666; }
        .stats { display: flex; gap: 20px; }
        .stat { text-align: center; }
        .stat-value { font-size: 32px; font-weight: 700; }
        .stat-label { color: #666; font-size: 14px; }
        .pass { color: #28a745; }
        .fail { color: #dc3545; }
    </style>
</head>
<body>
    <h1>🌍 GMT World Time Watchface - Build Report</h1>
    <p>Generated: $timestamp</p>
    
    <div class="summary">
        <div class="stats">
            <div class="stat">
                <div class="stat-value">$($Results.Count)</div>
                <div class="stat-label">Total Devices</div>
            </div>
            <div class="stat">
                <div class="stat-value pass">$($Results | Where-Object { $_.BuildSuccess } | Measure-Object | Select-Object -ExpandProperty Count)</div>
                <div class="stat-label">Build Passed</div>
            </div>
            <div class="stat">
                <div class="stat-value fail">$($Results | Where-Object { -not $_.BuildSuccess } | Measure-Object | Select-Object -ExpandProperty Count)</div>
                <div class="stat-label">Build Failed</div>
            </div>
        </div>
    </div>
    
    <h2>Device Results</h2>
    <div class="device-grid">
"@

    foreach ($result in $Results) {
        $statusClass = if ($result.BuildSuccess) { "status-pass" } else { "status-fail" }
        $statusText = if ($result.BuildSuccess) { "✓ Build Passed" } else { "✗ Build Failed" }
        
        $screenshotHtml = if ($result.ScreenshotPath -and (Test-Path $result.ScreenshotPath)) {
            "<img class='device-screenshot' src='$($result.ScreenshotFile)' alt='$($result.Name) screenshot'>"
        } else {
            "<div class='no-screenshot'>No screenshot available</div>"
        }
        
        $html += @"
        <div class="device-card">
            <div class="device-header">
                <div class="device-name">$($result.Name)</div>
                <div class="device-info">$($result.Id) • $($result.Resolution) • $($result.Type)</div>
            </div>
            $screenshotHtml
            <div class="device-status $statusClass">$statusText</div>
        </div>
"@
    }

    $html += @"
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
}

# Main Script
if ($Help) {
    Show-Help
    exit 0
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       GMT World Time Watchface - Build & Screenshot Tool     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Find SDK if not specified
if (-not $SdkPath) {
    Write-Host "Searching for Connect IQ SDK..." -ForegroundColor Yellow
    $SdkPath = Find-ConnectIQSDK
}

if ($SdkPath) {
    Write-Host "SDK found: $SdkPath" -ForegroundColor Green
} else {
    Write-Host "SDK not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install the Connect IQ SDK:" -ForegroundColor Yellow
    Write-Host "1. Go to https://developer.garmin.com/connect-iq/sdk/" -ForegroundColor Gray
    Write-Host "2. Download and install the SDK Manager" -ForegroundColor Gray
    Write-Host "3. Use SDK Manager to download the latest SDK" -ForegroundColor Gray
    Write-Host "4. Re-run this script" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or specify SDK path manually:" -ForegroundColor Yellow
    Write-Host "  .\build_and_screenshot.ps1 -SdkPath 'C:\path\to\sdk'" -ForegroundColor Gray
    exit 1
}

# Check prerequisites
$errors = Test-Prerequisites -SdkPath $SdkPath
if ($errors.Count -gt 0) {
    Write-Host "Prerequisites check failed:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    exit 1
}

# Check/create developer key
if (-not (Test-Path $DevKey)) {
    $keyCreated = New-DeveloperKey -SdkPath $SdkPath
    if (-not $keyCreated) {
        exit 1
    }
}

# Create output directories
if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir | Out-Null }
if (-not (Test-Path $ScreenshotDir)) { New-Item -ItemType Directory -Path $ScreenshotDir | Out-Null }

Write-Host ""
Write-Host "Starting build process for $($TestDevices.Count) devices..." -ForegroundColor Cyan
Write-Host ""

$results = @()

foreach ($device in $TestDevices) {
    $outputFile = Join-Path $BinDir "$ProjectName-$($device.Id).prg"
    $screenshotFile = "$($device.Id).png"
    $screenshotPath = Join-Path $ScreenshotDir $screenshotFile
    
    Write-Host "[$($results.Count + 1)/$($TestDevices.Count)] $($device.Name) ($($device.Id))" -ForegroundColor White
    
    $result = @{
        Id = $device.Id
        Name = $device.Name
        Resolution = $device.Resolution
        Type = $device.Type
        BuildSuccess = $false
        BuildError = $null
        ScreenshotSuccess = $false
        ScreenshotPath = $screenshotPath
        ScreenshotFile = $screenshotFile
    }
    
    # Build
    if (-not $SkipBuild) {
        Write-Host "    Building..." -ForegroundColor Gray
        $buildResult = Build-ForDevice -SdkPath $SdkPath -DeviceId $device.Id -OutputPath $outputFile -DevKey $DevKey
        $result.BuildSuccess = $buildResult.Success
        $result.BuildError = $buildResult.Error
        
        if ($buildResult.Success) {
            Write-Host "    Build: " -NoNewline -ForegroundColor Gray
            Write-Host "PASSED" -ForegroundColor Green
        } else {
            Write-Host "    Build: " -NoNewline -ForegroundColor Gray
            Write-Host "FAILED" -ForegroundColor Red
            if ($buildResult.Error) {
                Write-Host "    Error: $($buildResult.Error)" -ForegroundColor DarkRed
            }
        }
    } else {
        $result.BuildSuccess = Test-Path $outputFile
        Write-Host "    Build: SKIPPED (using existing)" -ForegroundColor Yellow
    }
    
    # Screenshot (only if build succeeded)
    if ($result.BuildSuccess -and (Test-Path $outputFile)) {
        Write-Host "    Capturing screenshot..." -ForegroundColor Gray
        $screenshotResult = Start-SimulatorAndCapture -SdkPath $SdkPath -DeviceId $device.Id -PrgPath $outputFile -ScreenshotPath $screenshotPath
        $result.ScreenshotSuccess = $screenshotResult.Success
        
        if ($screenshotResult.Success) {
            Write-Host "    Screenshot: " -NoNewline -ForegroundColor Gray
            Write-Host "SAVED" -ForegroundColor Green
        } else {
            Write-Host "    Screenshot: " -NoNewline -ForegroundColor Gray
            Write-Host "FAILED" -ForegroundColor Yellow
        }
    }
    
    $results += $result
    Write-Host ""
}

# Generate report
$reportPath = Join-Path $ScreenshotDir "build_report.html"
Write-Host "Generating build report..." -ForegroundColor Cyan
New-BuildReport -Results $results -OutputPath $reportPath

# Summary
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                         BUILD SUMMARY                           " -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$passed = ($results | Where-Object { $_.BuildSuccess }).Count
$failed = ($results | Where-Object { -not $_.BuildSuccess }).Count
$screenshots = ($results | Where-Object { $_.ScreenshotSuccess }).Count

Write-Host "  Total Devices:    $($results.Count)" -ForegroundColor White
Write-Host "  Builds Passed:    " -NoNewline -ForegroundColor White
Write-Host "$passed" -ForegroundColor Green
Write-Host "  Builds Failed:    " -NoNewline -ForegroundColor White
Write-Host "$failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Screenshots:      $screenshots" -ForegroundColor White
Write-Host ""
Write-Host "  Output folder:    $BinDir\" -ForegroundColor Gray
Write-Host "  Screenshots:      $ScreenshotDir\" -ForegroundColor Gray
Write-Host "  Build report:     $reportPath" -ForegroundColor Gray
Write-Host ""

# Open report
Write-Host "Opening build report..." -ForegroundColor Yellow
Start-Process $reportPath
