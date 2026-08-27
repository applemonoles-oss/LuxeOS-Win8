Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap(120,120)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(30,30,40))
$br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0,200,180))
$f = New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold)
$g.DrawString("LuxeOS",$f,$br,4,42)
$g.Dispose()
$out = "C:\Users\Admin\Desktop\LuxeOS-Win8\tools\branding\logo.bmp"
$bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Bmp)
$bmp.Dispose()
Write-Host "logo.bmp created -> $out"
