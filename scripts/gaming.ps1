# Official Plarium Play installer + integrity-checked portable RSL-Xtender.
[CmdletBinding()]
param([ValidateSet('Audit','Apply')][string]$Mode = 'Audit')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-PlariumPlay {
    $paths = @(
        (Join-Path $env:LOCALAPPDATA 'PlariumPlay\PlariumPlay.exe'),
        (Join-Path $env:LOCALAPPDATA 'Plarium\PlariumPlay\PlariumPlay.exe'),
        (Join-Path $env:ProgramFiles 'Plarium Play\PlariumPlay.exe'),
        (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Plarium Play\PlariumPlay.exe')
    )
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    $root = Join-Path $env:LOCALAPPDATA 'Plarium\PlariumPlay'
    if (Test-Path -LiteralPath $root) {
        foreach ($dir in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
            $path = Join-Path $dir.FullName 'PlariumPlay.exe'
            if (Test-Path -LiteralPath $path) { return $path }
        }
    }
    return $null
}

function Test-RaidInstalled {
    $root = Join-Path $env:LOCALAPPDATA 'Plarium\PlariumPlay\StandAloneApps\raid'
    if (Test-Path -LiteralPath $root) {
        foreach ($dir in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath (Join-Path $dir.FullName 'Raid.exe')) { return $true }
        }
    }
    return $false
}

function Install-PlariumPlay {
    if (Find-PlariumPlay) { Write-Host '[OK] Plarium Play'; return }
    if ($Mode -eq 'Audit') { Write-Host '[MISSING] Plarium Play'; return }

    # /S is used by community automation; Plarium does not document this switch.
    $url = 'https://installer.plarium.com/desktop?lid=1&arc=64&os=windows'
    $file = Join-Path ([IO.Path]::GetTempPath()) ('PlariumPlay-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        Write-Host '[Windox] Downloading Plarium Play from Plarium'
        Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
        $signature = Get-AuthenticodeSignature -LiteralPath $file
        if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
            $signature.SignerCertificate.Subject -notmatch 'Plarium') {
            throw 'Plarium Play installer signature is not valid for Plarium. Refusing execution.'
        }
        Write-Host '[Windox] Installing Plarium Play silently'
        $process = Start-Process -FilePath $file -ArgumentList '/S' -Wait -PassThru
        if ($process.ExitCode -notin @(0,3010,1641)) {
            throw "Plarium Play installer failed (exit code $($process.ExitCode))."
        }
        if (Find-PlariumPlay) {
            Write-Host '[OK] Plarium Play installed'
        } else {
            Write-Warning 'Plarium installer exited, but launcher was not found in expected directories.'
        }
    } finally {
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
}

function Install-RslXtender {
    # Pin the official 1.1.56 GitHub release, with its published SHA-256.
    $version = '1.1.56'
    $sha256 = '2083ec43a11a2d4efbcb31f76ba62f50bdb06903b9aab1107fe7c138e0a5fe60'
    $url = 'https://github.com/IRSwish/xtender/releases/download/v1.1.56/RSL-Xtender-win-Portable.zip'
    $target = Join-Path $env:ProgramData "Windox\apps\RSL-Xtender\$version"
    $currentExe = $null
    if (Test-Path -LiteralPath $target) {
        $currentExe = Get-ChildItem -LiteralPath $target -Recurse -File -Filter 'RSL-Xtender.exe' -ErrorAction SilentlyContinue |
                      Select-Object -First 1
    }
    if (-not $currentExe) {
        foreach ($path in @(
            (Join-Path $env:LOCALAPPDATA 'RSL-Xtender\current\RSL-Xtender.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\RSL-Xtender\RSL-Xtender.exe')
        )) {
            if (Test-Path -LiteralPath $path) {
                Write-Host "[OK] RSL-Xtender already installed: $path"
                return
            }
        }
        if ($Mode -eq 'Audit') { Write-Host '[MISSING] RSL-Xtender'; return }

        $temp = Join-Path ([IO.Path]::GetTempPath()) ('rsl-xtender-' + [guid]::NewGuid().ToString('N'))
        $archive = Join-Path $temp 'xtender.zip'
        $stage = Join-Path $temp 'expanded'
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        try {
            Write-Host "[Windox] Downloading RSL-Xtender $version from its official GitHub release"
            Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
            $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
            if ($actual -ine $sha256) { throw "RSL-Xtender SHA256 mismatch: $actual" }
            Expand-Archive -LiteralPath $archive -DestinationPath $stage -Force
            $exe = Get-ChildItem -LiteralPath $stage -Recurse -File -Filter 'RSL-Xtender.exe' |
                   Select-Object -First 1
            if (-not $exe) { throw 'RSL-Xtender executable missing from portable archive.' }
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            if (-not (Test-Path -LiteralPath $target)) {
                Move-Item -LiteralPath $stage -Destination $target
            }
            $currentExe = Get-ChildItem -LiteralPath $target -Recurse -File -Filter 'RSL-Xtender.exe' |
                          Select-Object -First 1
            if (-not $currentExe) { throw 'RSL-Xtender executable not found after extraction.' }
            Write-Host "[OK] RSL-Xtender $version extracted"
        } finally {
            Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "[OK] RSL-Xtender $version"
    }
    if ($Mode -eq 'Apply' -and $currentExe) {
        $startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\RSL-Xtender.lnk'
        if (-not (Test-Path -LiteralPath $startMenu)) {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($startMenu)
            $shortcut.TargetPath = $currentExe.FullName
            $shortcut.WorkingDirectory = $currentExe.DirectoryName
            $shortcut.Save()
            Write-Host '[OK] RSL-Xtender Start Menu shortcut'
        }
    }
}

Install-PlariumPlay
if (Test-RaidInstalled) {
    Write-Host '[OK] RAID: Shadow Legends detected'
} else {
    Write-Host '[INFO] RAID game installation requires signing in to Plarium Play.'
}
Install-RslXtender
