# Windox - repeatable Windows workstation setup
[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Apply')]
    [string]$Mode = 'Audit',
    [switch]$SkipPackages
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$manifestPath = Join-Path $root 'config/packages.json'

function Write-Step([string]$Message) { Write-Host "[Windox] $Message" -ForegroundColor Cyan }

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
    throw 'Windox runs on Windows only.'
}
if (-not (Test-Path $manifestPath)) { throw "Missing manifest: $manifestPath" }

Write-Step "Starting in $Mode mode"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if (-not $SkipPackages) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Warning 'WinGet is unavailable. Install/update Microsoft App Installer and retry.'
        if ($Mode -eq 'Apply') { throw 'WinGet is required to install packages.' }
    } else {
        foreach ($package in $manifest.packages) {
            $id = [string]$package.id
            if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$') {
                throw "Invalid package ID: $id"
            }
            # Avoid text-based matching: exact IDs only, no wildcard matching.
            $installedOutput = & $winget.Source list --id $id --exact --accept-source-agreements 2>&1
            $installedCode = $LASTEXITCODE
            $installed = ($installedCode -eq 0) -and
                ((($installedOutput | Out-String) -split '\r?\n') | Where-Object {
                    $_ -match ('(^|\s)' + [regex]::Escape($id) + '(\s|$)')
                } | Select-Object -First 1)
            if ($installed) {
                Write-Step "Installed: $id"
                continue
            }
            if ($Mode -eq 'Audit') {
                Write-Host "[MISSING] $id"
                continue
            }
            Write-Step "Installing $id"
            & $winget.Source install --id $id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Installation failed: $id (exit code $LASTEXITCODE)"
            }
        }
    }
}

# Conservative settings: no registry changes, no app removals, no policy changes.
& (Join-Path $root 'scripts/system.ps1') -Mode $Mode
Write-Step 'Finished. Review output for warnings or missing packages.'
