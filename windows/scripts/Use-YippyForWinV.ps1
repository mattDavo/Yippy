<#
.SYNOPSIS
    Frees Win+V from Windows' clipboard history, so Yippy can use it.

.DESCRIPTION
    Adds "V" to Explorer's DisabledHotkeys setting for the current user (each letter in it is a Win+letter
    shortcut Explorer leaves alone), then restarts Explorer so it lets go of Win+V. The taskbar disappears for
    a moment and open File Explorer windows close.

    Afterwards, set Yippy's shortcut to Win+V: click the shortcut box in Settings > Shortcut and press Win+V.
    Settings > Shortcut > "Use Win+V" in Yippy, or "Yippy.exe --use-win-v", does both steps in one go (so does
    the installer's Win+V option).

    Restore-WindowsWinV.ps1 undoes this. No administrator rights are needed.

.PARAMETER NoRestart
    Only change the setting; it takes effect the next time you sign in.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Use-YippyForWinV.ps1
#>
[CmdletBinding()]
param([switch]$NoRestart)

$ErrorActionPreference = 'Stop'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$name = 'DisabledHotkeys'

if (-not (Test-Path $key)) {
    New-Item -Path $key -Force | Out-Null
}
$letters = [string](Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue).$name

# -match ignores case, so "v" set by hand counts too
if ($letters -match 'V') {
    Write-Host 'Win+V is already freed from Windows.'
} else {
    Set-ItemProperty -Path $key -Name $name -Value ($letters + 'V') -Type String
    Write-Host 'Win+V is freed from Windows.'
}

if ($NoRestart) {
    Write-Host 'It takes effect the next time you sign in.'
    return
}

# Restart Explorer in this session only; Windows normally starts it again by itself
$session = (Get-Process -Id $PID).SessionId
Get-Process -Name explorer -ErrorAction SilentlyContinue |
    Where-Object { $_.SessionId -eq $session } |
    Stop-Process -Force
Start-Sleep -Seconds 3
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $session })) {
    Start-Process explorer.exe
}
Write-Host 'Explorer restarted. Now set Yippy''s shortcut to Win+V in Settings > General.'
