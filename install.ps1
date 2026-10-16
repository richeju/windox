# Windox remote installer. Review this file before remote execution.
# Usage: irm https://raw.githubusercontent.com/richeju/windox/main/install.ps1 | iex
# Optional: $env:WINDOX_MODE = 'Apply'  (defaults to Audit)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mode = if ($env:WINDOX_MODE) { $env:WINDOX_MODE } else { 'Audit' }
if ($mode -notin @('Audit', 'Apply')) {
    throw "Invalid WINDOX_MODE: $mode. Expected Audit or Apply."
}
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Windox supports Windows only.'
}

$workDir = Join-Path ([IO.Path]::GetTempPath()) ('windox-' + [guid]::NewGuid().ToString('N'))
$archive = Join-Path $workDir 'windox.zip'
$expanded = Join-Path $workDir 'source'
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
try {
    $url = 'https://github.com/richeju/windox/archive/refs/heads/main.zip'
    Write-Host "[Windox] Downloading repository from $url"
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
    Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
    $entry = Join-Path $expanded 'windox-main\bootstrap.ps1'
    if (-not (Test-Path -LiteralPath $entry)) {
        throw "Missing bootstrap.ps1 in downloaded archive."
    }
    Write-Host "[Windox] Running bootstrap in $mode mode"
    # The ZIP contains unsigned local scripts. Relax policy only for this process
    # and restore the previous process-scoped setting before returning.
    $originalPolicy = Get-ExecutionPolicy -Scope Process
    $changedPolicy = $false
    try {
        if ($originalPolicy -ne 'Bypass') {
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
            $changedPolicy = $true
        }
        & $entry -Mode $mode
    } finally {
        if ($changedPolicy) {
            Set-ExecutionPolicy -ExecutionPolicy $originalPolicy -Scope Process -Force -ErrorAction SilentlyContinue
        }
    }
} finally {
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
}
