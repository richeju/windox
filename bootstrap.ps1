# Windox - single entry point for repeatable Windows setup
[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Apply')]
    [string]$Mode = 'Audit',
    [switch]$SkipPackages
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "[Windox] $Message" -ForegroundColor Cyan
}

function Test-Administrator {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Windox supports Windows only.'
}

# Chocolatey and machine-level package installation require elevation.
# A standard PowerShell window prompts for UAC once, without needing another command.
if ($Mode -eq 'Apply' -and -not (Test-Administrator)) {
    Write-Step 'Requesting administrator privileges (UAC)...'
    $shell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Mode Apply' -f $PSCommandPath
    if ($SkipPackages) { $arguments += ' -SkipPackages' }

    $process = Start-Process -FilePath $shell -ArgumentList $arguments -Verb RunAs -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Elevated Windox run failed (exit code $($process.ExitCode))."
    }
    return
}

$root = $PSScriptRoot
$manifestPath = Join-Path $root 'config\packages.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing package manifest: $manifestPath"
}

Write-Step "Mode: $Mode"
& (Join-Path $root 'scripts\chocolatey.ps1') -Mode $Mode -ManifestPath $manifestPath -SkipPackages:$SkipPackages
& (Join-Path $root 'scripts\gaming.ps1') -Mode $Mode
& (Join-Path $root 'scripts\system.ps1') -Mode $Mode
Write-Step 'Completed.'
