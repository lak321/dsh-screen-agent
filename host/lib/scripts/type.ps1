param([string]$Text)
# Chinese-safe typing: put text on clipboard, then send Ctrl+V
Set-Clipboard -Value $Text
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeySim {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@
# Ctrl+V (VK_CONTROL=0x11, V=0x56; KEYUP flag=2)
[KeySim]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
[KeySim]::keybd_event(0x56, 0, 0, [UIntPtr]::Zero)
[KeySim]::keybd_event(0x56, 0, 2, [UIntPtr]::Zero)
[KeySim]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero)
Write-Output "ok:typed"