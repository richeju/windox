[CmdletBinding()]
param([ValidateSet('Audit', 'Apply')][string]$Mode = 'Audit')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Example of a safe, user-scoped, repeatable setting.
$target = 'Explorer: show file extensions'
$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$name = 'HideFileExt'
$desired = 0

if (-not (Test-Path $path)) {
    Write-Warning "Registry path not found: $path"
    return
}
$current = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name
if ($current -eq $desired) {
    Write-Host "[OK] $target"
} elseif ($Mode -eq 'Audit') {
    Write-Host "[DRIFT] $target (current: $current, expected: $desired)"
} else {
    New-ItemProperty -Path $path -Name $name -Value $desired -PropertyType DWord -Force | Out-Null
    Write-Host "[FIXED] $target (Explorer may need a restart)"
}
