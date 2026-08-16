param([string]$Keys)
# Keys: SendKeys syntax (^c=Ctrl+C, %{F4}=Alt+F4, {ENTER}, {TAB}, {ESC}, ...)
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait($Keys)
Write-Output "ok:key"