param([string]$Title)
# Activate the top window whose title matches
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAct {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
$proc = Get-Process | Where-Object { $_.MainWindowTitle -and $_.MainWindowTitle -match $Title } | Select-Object -First 1
if ($proc) {
    [WinAct]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null
    [WinAct]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
    Write-Output ("ok:" + $proc.MainWindowTitle)
} else {
    Write-Output "notfound"
}