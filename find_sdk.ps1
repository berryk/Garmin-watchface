# Find Connect IQ SDK Installation
Write-Host "Searching for Connect IQ SDK..." -ForegroundColor Cyan

$sdkPaths = @(
    "$env:APPDATA\Garmin\ConnectIQ\Sdks",
    "$env:ProgramFiles\Garmin\ConnectIQ",
    "C:\Garmin\ConnectIQ"
)

foreach ($sdkPath in $sdkPaths) {
    if (Test-Path $sdkPath) {
        Write-Host "`nChecking: $sdkPath" -ForegroundColor Yellow
        
        $sdkDirs = Get-ChildItem -Path $sdkPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        
        foreach ($sdkDir in $sdkDirs) {
            $binPath = Join-Path $sdkDir.FullName "bin"
            
            if (Test-Path $binPath) {
                Write-Host "  Found SDK: $($sdkDir.Name)" -ForegroundColor Green
                
                $monkeydo = Join-Path $binPath "monkeydo.exe"
                $connectiq = Join-Path $binPath "connectiq.exe"
                
                if (Test-Path $monkeydo) {
                    Write-Host "    monkeydo.exe: $monkeydo" -ForegroundColor Green
                }
                if (Test-Path $connectiq) {
                    Write-Host "    connectiq.exe: $connectiq" -ForegroundColor Green
                }
            }
        }
    }
}

Write-Host "`nTo build and run without VS Code, use:" -ForegroundColor Cyan
Write-Host "  monkeydo monkey.jungle fenix7" -ForegroundColor Yellow
