# Chocolatey prerequisite and desired packages (Chocolatey CLI 2.x compatible)
[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Apply')][string]$Mode = 'Audit',
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [switch]$SkipPackages
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ChocoPath {
    $candidate = Get-Command choco.exe -ErrorAction SilentlyContinue
    if ($candidate) { return $candidate.Source }

    $roots = @($env:ChocolateyInstall, (Join-Path $env:ProgramData 'chocolatey'))
    foreach ($root in $roots) {
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            $path = Join-Path $root 'bin\choco.exe'
            if (Test-Path -LiteralPath $path) { return $path }
        }
    }
    return $null
}

$choco = Get-ChocoPath
if (-not $choco) {
    if ($Mode -eq 'Audit') {
        Write-Host '[MISSING] Chocolatey (package audit unavailable)'
        return
    }

    Write-Host '[Windox] Installing Chocolatey'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $installer = Join-Path ([IO.Path]::GetTempPath()) ('chocolatey-install-' + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $installer -UseBasicParsing
        & $installer
    } finally {
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }

    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
    $choco = Get-ChocoPath
    if (-not $choco) { throw 'Chocolatey installer finished, but choco.exe was not found.' }
    Write-Host '[OK] Chocolatey installed'
} else {
    Write-Host '[OK] Chocolatey available'
}

if ($SkipPackages) {
    Write-Host '[Windox] Skipping packages by request'
    return
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ($null -eq $manifest.packages) { throw "Manifest must contain a 'packages' array." }

# 'choco list' in Chocolatey 2.x lists local packages (no --local-only switch).
# --limit-output produces one package per line: packageName|version.
$lines = @(& $choco list --limit-output)
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect installed Chocolatey packages (exit $LASTEXITCODE)."
}
$installed = @{}
foreach ($line in $lines) {
    if ([string]$line -match '^([^|\r\n]+)\|([^|\r\n]+)$') {
        $installed[$matches[1].Trim()] = $true
    }
}

$failed = New-Object 'System.Collections.Generic.List[string]'
foreach ($package in $manifest.packages) {
    $id = [string]$package.id
    if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$') {
        throw "Invalid Chocolatey package ID: '$id'"
    }
    if ($installed.ContainsKey($id)) {
        Write-Host "[OK] $id"
        continue
    }
    if ($Mode -eq 'Audit') {
        Write-Host "[MISSING] $id"
        continue
    }

    Write-Host "[Windox] Installing $id..."
    & $choco install $id --yes --no-progress --limit-output
    $exitCode = $LASTEXITCODE
    if ($exitCode -in @(0, 3010, 1641)) {
        $installed[$id] = $true
        if ($exitCode -ne 0) {
            Write-Warning "$id installed but a restart is required (exit $exitCode)."
        }
    } else {
        Write-Warning "Installation failed: $id (exit $exitCode)."
        $failed.Add($id)
    }
}
if ($failed.Count -gt 0) {
    throw ("Chocolatey package installation failed: " + ($failed -join ', '))
}
