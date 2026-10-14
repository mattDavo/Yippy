<#
.SYNOPSIS
    Gives Win+V back to Windows' clipboard history.

.DESCRIPTION
    Removes "V" from Explorer's DisabledHotkeys setting for the current user, keeping any other letters in it,
    then restarts Explorer so it registers Win+V again. The taskbar disappears for a moment and open File
    Explorer windows close.

    If Yippy is running with Win+V as its shortcut, change Yippy's shortcut first (Settings > General >
    "Give Win+V Back to Windows" does both steps), or quit Yippy: while Yippy holds Win+V, Explorer can't take it.

    This undoes Use-YippyForWinV.ps1. No administrator rights are needed.

.PARAMETER NoRestart
    Only change the setting; it takes effect the next time you sign in.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Restore-WindowsWinV.ps1
#>
[CmdletBinding()]
param([switch]$NoRestart)

$ErrorActionPreference = 'Stop'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$name = 'DisabledHotkeys'

$letters = [string](Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue).$name
if ($letters -notmatch 'V') {
    Write-Host 'Win+V already belongs to Windows.'
} else {
    $remaining = $letters -replace '[vV]', ''
    if ($remaining.Length -eq 0) {
        Remove-ItemProperty -Path $key -Name $name
    } else {
        Set-ItemProperty -Path $key -Name $name -Value $remaining -Type String
    }
    Write-Host 'Win+V is given back to Windows.'
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
Write-Host 'Explorer restarted. Win+V opens Windows'' clipboard history again.'
