# Mouse simulation: click / double / right / drag
# CRITICAL: use $args, NOT param() -- PowerShell parses negative numbers
# like -1609 as parameter names and silently drops them (X1 becomes 0),
# which broke all secondary-monitor clicks (negative virtual coords).
# CRITICAL: declare DPI aware, otherwise SetCursorPos uses logical coords
# (125% scaling shifts 1.25x away from OCR physical-pixel coords).
$Action = [string]$args[0]
$X1 = [int]$args[1]
$Y1 = [int]$args[2]
$X2 = [int]$args[3]
$Y2 = [int]$args[4]
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiAware {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[DpiAware]::SetProcessDPIAware() | Out-Null
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MouseSim {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeySim {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@
$down = 0x02; $up = 0x04
if ($Action -eq 'click') {
    [MouseSim]::SetCursorPos($X1, $Y1)
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [MouseSim]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)
} elseif ($Action -eq 'double') {
    [MouseSim]::SetCursorPos($X1, $Y1)
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)
} elseif ($Action -eq 'right') {
    [MouseSim]::SetCursorPos($X1, $Y1)
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event(0x08, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [MouseSim]::mouse_event(0x10, 0, 0, 0, [UIntPtr]::Zero)
} elseif ($Action -eq 'drag') {
    [MouseSim]::SetCursorPos($X1, $Y1)
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero)
    $steps = 24
    for ($i = 1; $i -le $steps; $i++) {
        $x = $X1 + [int](($X2 - $X1) * $i / $steps)
        $y = $Y1 + [int](($Y2 - $Y1) * $i / $steps)
        [MouseSim]::SetCursorPos($x, $y)
        Start-Sleep -Milliseconds 14
    }
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)
} elseif ($Action -eq 'shift-drag') {
    # Shift + drag: keep Shift held during the drag (e.g. perfect circle in Paint)
    [KeySim]::keybd_event(0x10, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [MouseSim]::SetCursorPos($X1, $Y1)
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($down, 0, 0, 0, [UIntPtr]::Zero)
    $steps = 30
    for ($i = 1; $i -le $steps; $i++) {
        $x = $X1 + [int](($X2 - $X1) * $i / $steps)
        $y = $Y1 + [int](($Y2 - $Y1) * $i / $steps)
        [MouseSim]::SetCursorPos($x, $y)
        Start-Sleep -Milliseconds 14
    }
    Start-Sleep -Milliseconds 60
    [MouseSim]::mouse_event($up, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [KeySim]::keybd_event(0x10, 0, 2, [UIntPtr]::Zero)
}
Write-Output "ok:$Action"