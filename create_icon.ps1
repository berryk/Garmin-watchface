Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap(40, 40)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)

# Fill with black background
$graphics.Clear([System.Drawing.Color]::Black)

# Draw white circle border
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
$graphics.DrawEllipse($pen, 2, 2, 35, 35)

# Draw GMT text
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$rect = New-Object System.Drawing.RectangleF(0, 0, 40, 40)
$graphics.DrawString("GMT", $font, $brush, $rect, $sf)

# Save
$graphics.Dispose()
$bmp.Save("resources\drawables\launcher_icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Launcher icon created: resources\drawables\launcher_icon.png" -ForegroundColor Green
