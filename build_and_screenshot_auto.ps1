# GMT World Time Watchface - Fully Automated Build and Screenshot Script
# This script runs completely unattended - no manual interaction required

param(
    [string]$SdkPath = "",
    [string]$DevKey = "developer_key.der",
    [switch]$BuildOnly = $false,
    [switch]$Help = $false
)

# Configuration
$ProjectName = "GMTWorldTime"
$ScreenshotDir = "screenshots"
$BinDir = "bin"

# Devices to test - representative sample
$TestDevices = @(
    @{ Id = "fenix7"; Name = "Fenix 7"; Resolution = "260x260"; Type = "Round" },
    @{ Id = "fenix5"; Name = "Fenix 5"; Resolution = "240x240"; Type = "Round" },
    @{ Id = "venu"; Name = "Venu (1st Gen)"; Resolution = "390x390"; Type = "Round AMOLED" },
    @{ Id = "venu2"; Name = "Venu 2"; Resolution = "416x416"; Type = "Round AMOLED" },
    @{ Id = "venu3"; Name = "Venu 3"; Resolution = "454x454"; Type = "Round AMOLED" },
    @{ Id = "venu441mm"; Name = "Venu 4 (41mm)"; Resolution = "390x390"; Type = "Round AMOLED" },
    @{ Id = "venu445mm"; Name = "Venu 4 (45mm)"; Resolution = "454x454"; Type = "Round AMOLED" },
    @{ Id = "venux1"; Name = "Venu X1"; Resolution = "390x390"; Type = "Round AMOLED" },
    @{ Id = "venusq2"; Name = "Venu Sq 2"; Resolution = "320x360"; Type = "Rectangle" },
    @{ Id = "fr965"; Name = "Forerunner 965"; Resolution = "454x454"; Type = "Round AMOLED" },
    @{ Id = "fr255"; Name = "Forerunner 255"; Resolution = "260x260"; Type = "Round MIP" },
    @{ Id = "fr245"; Name = "Forerunner 245"; Resolution = "240x240"; Type = "Round MIP" },
    @{ Id = "vivoactive5"; Name = "Vivoactive 5"; Resolution = "390x390"; Type = "Round AMOLED" },
    @{ Id = "vivoactive4"; Name = "Vivoactive 4"; Resolution = "260x260"; Type = "Round" },
    @{ Id = "epix2"; Name = "Epix 2"; Resolution = "416x416"; Type = "Round AMOLED" },
    @{ Id = "enduro2"; Name = "Enduro 2"; Resolution = "280x280"; Type = "Round MIP" },
    @{ Id = "lily2"; Name = "Lily 2"; Resolution = "240x201"; Type = "Rectangle" }
)

# Add required assemblies for window manipulation and screenshots
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;

public class WindowCapture {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
    
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindowDC(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    
    [DllImport("gdi32.dll")]
    public static extern bool BitBlt(IntPtr hdcDest, int xDest, int yDest, int wDest, int hDest, 
        IntPtr hdcSource, int xSrc, int ySrc, int RasterOp);
    
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    
    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
    
    public const int SW_RESTORE = 9;
    public const int SW_SHOW = 5;
    public const int SRCCOPY = 0x00CC0020;
    
    public static IntPtr FindSimulatorWindow() {
        IntPtr result = IntPtr.Zero;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (IsWindowVisible(hWnd)) {
                int length = GetWindowTextLength(hWnd);
                if (length > 0) {
                    var sb = new System.Text.StringBuilder(length + 1);
                    GetWindowText(hWnd, sb, sb.Capacity);
                    string title = sb.ToString();
                    if (title.Contains("Connect IQ") || title.Contains("Simulator") || title.Contains("simulator")) {
                        result = hWnd;
                        return false;
                    }
                }
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }
    
    public static Bitmap CaptureWindow(IntPtr hWnd) {
        RECT rect;
        GetWindowRect(hWnd, out rect);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        
        if (width <= 0 || height <= 0) return null;
        
        Bitmap bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            IntPtr hdcBitmap = g.GetHdc();
            PrintWindow(hWnd, hdcBitmap, 0);
            g.ReleaseHdc(hdcBitmap);
        }
        return bmp;
    }
}
"@ -ReferencedAssemblies System.Drawing

function Find-ConnectIQSDK {
    $possiblePaths = @(
        "$env:APPDATA\Garmin\ConnectIQ\Sdks",
        "$env:LOCALAPPDATA\Garmin\ConnectIQ\Sdks",
        "C:\Garmin\ConnectIQ\Sdks"
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
    return $null
}

function Build-ForDevice {
    param($SdkPath, $DeviceId, $OutputPath, $DevKey)
    
    $javaPath = "C:\Program Files\Java\jdk-17\bin\java.exe"
    $monkeyBrains = Join-Path $SdkPath "bin\monkeybrains.jar"
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $javaPath
    $pinfo.Arguments = "-jar `"$monkeyBrains`" -o `"$OutputPath`" -f monkey.jungle -d $DeviceId -y `"$DevKey`" -w"
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit(120000) # 2 min timeout
    
    return (Test-Path $OutputPath)
}

function Start-SimulatorWithApp {
    param($SdkPath, $DeviceId, $PrgPath)
    
    # Kill any existing simulator
    Get-Process -Name "simulator" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    
    $simulatorPath = Join-Path $SdkPath "bin\simulator.exe"
    $javaPath = "C:\Program Files\Java\jdk-17\bin\java.exe"
    $monkeyBrains = Join-Path $SdkPath "bin\monkeybrains.jar"
    $shellExe = Join-Path $SdkPath "bin\shell.exe"
    
    # Start simulator
    $simProcess = Start-Process -FilePath $simulatorPath -PassThru -WindowStyle Normal
    Start-Sleep -Seconds 3
    
    # Load the app using MonkeyDoDeux directly via Java
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $javaPath
    $pinfo.Arguments = "-classpath `"$monkeyBrains`" com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux -f `"$PrgPath`" -d $DeviceId -s `"$shellExe`""
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit(30000)
    
    # Wait for watchface to render
    Start-Sleep -Seconds 2
    
    return $simProcess
}

function Capture-SimulatorScreenshot {
    param($OutputPath)
    
    # Find simulator window
    $hwnd = [WindowCapture]::FindSimulatorWindow()
    
    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Host "    Could not find simulator window" -ForegroundColor Yellow
        return $false
    }
    
    # Bring window to foreground
    [WindowCapture]::ShowWindow($hwnd, [WindowCapture]::SW_RESTORE)
    [WindowCapture]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 500
    
    # Capture the window
    $bitmap = [WindowCapture]::CaptureWindow($hwnd)
    
    if ($bitmap -eq $null) {
        Write-Host "    Could not capture window" -ForegroundColor Yellow
        return $false
    }
    
    # Save screenshot
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    
    return $true
}

function Stop-Simulator {
    Get-Process -Name "simulator" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

function New-HtmlReport {
    param($Results, $OutputPath)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $passedCount = ($Results | Where-Object { $_.BuildSuccess }).Count
    $failedCount = ($Results | Where-Object { -not $_.BuildSuccess }).Count
    
    $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>GMT World Time - Build Report</title>
    <style>
        * { box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 40px; background: #0a0a0a; color: #fff; }
        h1 { color: #fff; font-weight: 300; margin-bottom: 10px; }
        .timestamp { color: #666; margin-bottom: 30px; }
        .summary { display: flex; gap: 30px; margin-bottom: 40px; }
        .stat { background: #1a1a1a; padding: 20px 30px; border-radius: 12px; text-align: center; }
        .stat-value { font-size: 42px; font-weight: 700; }
        .stat-label { color: #888; font-size: 14px; margin-top: 5px; }
        .pass { color: #4ade80; }
        .fail { color: #f87171; }
        .device-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }
        .device-card { background: #1a1a1a; border-radius: 12px; overflow: hidden; }
        .device-header { padding: 15px 20px; border-bottom: 1px solid #333; }
        .device-name { font-weight: 600; font-size: 15px; }
        .device-info { color: #666; font-size: 11px; margin-top: 4px; }
        .device-screenshot { width: 100%; aspect-ratio: 1; object-fit: contain; background: #000; }
        .no-screenshot { width: 100%; aspect-ratio: 1; display: flex; align-items: center; justify-content: center; background: #0a0a0a; color: #444; font-size: 14px; }
        .device-status { padding: 12px 20px; font-size: 12px; font-weight: 500; }
        .status-pass { background: #052e16; color: #4ade80; }
        .status-fail { background: #450a0a; color: #f87171; }
    </style>
</head>
<body>
    <h1>GMT World Time Watchface</h1>
    <p class="timestamp">Build Report - $timestamp</p>
    
    <div class="summary">
        <div class="stat">
            <div class="stat-value">$($Results.Count)</div>
            <div class="stat-label">Devices Tested</div>
        </div>
        <div class="stat">
            <div class="stat-value pass">$passedCount</div>
            <div class="stat-label">Build Passed</div>
        </div>
        <div class="stat">
            <div class="stat-value fail">$failedCount</div>
            <div class="stat-label">Build Failed</div>
        </div>
    </div>
    
    <div class="device-grid">
"@

    $htmlCards = ""
    foreach ($result in $Results) {
        $statusClass = "status-fail"
        $statusText = "X Build Failed"
        if ($result.BuildSuccess) {
            $statusClass = "status-pass"
            $statusText = "OK Build Passed"
        }
        
        $screenshotHtml = "<div class='no-screenshot'>No screenshot</div>"
        if ($result.ScreenshotSuccess -and (Test-Path $result.ScreenshotPath)) {
            $screenshotHtml = "<img class='device-screenshot' src='$($result.ScreenshotFile)' alt='$($result.Name)'>"
        }
        
        $htmlCards += @"
        <div class="device-card">
            <div class="device-header">
                <div class="device-name">$($result.Name)</div>
                <div class="device-info">$($result.Id) - $($result.Resolution) - $($result.Type)</div>
            </div>
            $screenshotHtml
            <div class="device-status $statusClass">$statusText</div>
        </div>
"@
    }

    $htmlFooter = @"
    </div>
</body>
</html>
"@

    $fullHtml = $htmlHeader + $htmlCards + $htmlFooter
    $fullHtml | Out-File -FilePath $OutputPath -Encoding UTF8
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "     GMT World Time - Automated Build and Screenshot (Unattended)      " -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

# Find SDK
if (-not $SdkPath) {
    Write-Host "Searching for Connect IQ SDK..." -ForegroundColor Yellow
    $SdkPath = Find-ConnectIQSDK
}

if (-not $SdkPath) {
    Write-Host "ERROR: Connect IQ SDK not found!" -ForegroundColor Red
    Write-Host "Please install from: https://developer.garmin.com/connect-iq/sdk/" -ForegroundColor Yellow
    exit 1
}

Write-Host "SDK: $SdkPath" -ForegroundColor Green

# Check developer key
if (-not (Test-Path $DevKey)) {
    Write-Host "Generating developer key..." -ForegroundColor Yellow
    $openssl = Get-Command "openssl" -ErrorAction SilentlyContinue
    if ($openssl) {
        & openssl genrsa -out $DevKey 4096 2>&1 | Out-Null
        Write-Host "Developer key generated." -ForegroundColor Green
    } else {
        Write-Host "ERROR: No developer key and OpenSSL not available." -ForegroundColor Red
        exit 1
    }
}

# Create directories
if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Path $BinDir | Out-Null }
if (-not (Test-Path $ScreenshotDir)) { New-Item -ItemType Directory -Path $ScreenshotDir | Out-Null }

Write-Host ""
Write-Host "Processing $($TestDevices.Count) devices..." -ForegroundColor Cyan
Write-Host ""

$results = @()
$deviceNum = 0

foreach ($device in $TestDevices) {
    $deviceNum++
    $prgPath = Join-Path $BinDir "$ProjectName-$($device.Id).prg"
    $screenshotFile = "$($device.Id).png"
    $screenshotPath = Join-Path $ScreenshotDir $screenshotFile
    
    Write-Host "[$deviceNum/$($TestDevices.Count)] $($device.Name)" -ForegroundColor White -NoNewline
    Write-Host " ($($device.Id))" -ForegroundColor DarkGray
    
    $result = @{
        Id = $device.Id
        Name = $device.Name
        Resolution = $device.Resolution
        Type = $device.Type
        BuildSuccess = $false
        ScreenshotSuccess = $false
        ScreenshotPath = $screenshotPath
        ScreenshotFile = $screenshotFile
    }
    
    # Build
    Write-Host "    Building... " -NoNewline -ForegroundColor Gray
    $buildSuccess = Build-ForDevice -SdkPath $SdkPath -DeviceId $device.Id -OutputPath $prgPath -DevKey $DevKey
    $result.BuildSuccess = $buildSuccess
    
    if ($buildSuccess) {
        Write-Host "OK" -ForegroundColor Green
        
        if (-not $BuildOnly) {
            # Screenshot
            Write-Host "    Screenshot... " -NoNewline -ForegroundColor Gray
            
            $simProcess = Start-SimulatorWithApp -SdkPath $SdkPath -DeviceId $device.Id -PrgPath $prgPath
            
            $screenshotSuccess = Capture-SimulatorScreenshot -OutputPath $screenshotPath
            $result.ScreenshotSuccess = $screenshotSuccess
            
            if ($screenshotSuccess) {
                Write-Host "OK" -ForegroundColor Green
            } else {
                Write-Host "SKIP" -ForegroundColor Yellow
            }
            
            Stop-Simulator
        }
    } else {
        Write-Host "FAILED" -ForegroundColor Red
    }
    
    $results += $result
}

# Generate report
$reportPath = Join-Path $ScreenshotDir "build_report.html"
Write-Host ""
Write-Host "Generating report..." -ForegroundColor Cyan
New-HtmlReport -Results $results -OutputPath $reportPath

# Summary
$passed = ($results | Where-Object { $_.BuildSuccess }).Count
$failed = ($results | Where-Object { -not $_.BuildSuccess }).Count
$screenshots = ($results | Where-Object { $_.ScreenshotSuccess }).Count

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "                           SUMMARY                                      " -ForegroundColor Cyan  
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Builds Passed:   $passed / $($results.Count)" -ForegroundColor $(if ($passed -eq $results.Count) { "Green" } else { "Yellow" })
Write-Host "  Screenshots:     $screenshots" -ForegroundColor White
Write-Host ""
Write-Host "  Output:          $BinDir\" -ForegroundColor Gray
Write-Host "  Screenshots:     $ScreenshotDir\" -ForegroundColor Gray
Write-Host "  Report:          $reportPath" -ForegroundColor Gray
Write-Host ""

# Open report
Start-Process $reportPath

Write-Host "Done!" -ForegroundColor Green
