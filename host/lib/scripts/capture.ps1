param([string]$Out)
# Full virtual-desktop capture (all monitors incl. secondary) -> PNG
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$vx = [System.Windows.Forms.SystemInformation]::VirtualScreen.X
$vy = [System.Windows.Forms.SystemInformation]::VirtualScreen.Y
$vw = [System.Windows.Forms.SystemInformation]::VirtualScreen.Width
$vh = [System.Windows.Forms.SystemInformation]::VirtualScreen.Height
$bmp = New-Object System.Drawing.Bitmap($vw, $vh)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vx, $vy, 0, 0, (New-Object System.Drawing.Size($vw, $vh)))
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Output ("saved:" + $Out)