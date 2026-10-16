# Windows 11 default browser integration. No unsupported UserChoice hash edits.
[CmdletBinding()]
param([ValidateSet('Audit', 'Apply')][string]$Mode = 'Audit')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$chromePaths = @(
    (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Google\Chrome\Application\chrome.exe'),
    (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
)
$chromeInstalled = $false
foreach ($path in $chromePaths) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $chromeInstalled = $true
        break
    }
}

if (-not $chromeInstalled) {
    Write-Warning 'Google Chrome not detected; cannot configure the default browser.'
    return
}

$associations = @(
    @{ Name = 'http'; Path = 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice' },
    @{ Name = 'https'; Path = 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' },
    @{ Name = '.htm'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.htm\UserChoice' },
    @{ Name = '.html'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice' }
)

$notChrome = @()
foreach ($association in $associations) {
    $choice = Get-ItemProperty -LiteralPath $association.Path -Name ProgId -ErrorAction SilentlyContinue
    if ($null -eq $choice -or [string]$choice.ProgId -notlike 'ChromeHTML*') {
        $notChrome += $association.Name
    }
}
if ($notChrome.Count -eq 0) {
    Write-Host '[OK] Google Chrome is the current user default for web links and HTML.'
    return
}

Write-Host ("[DRIFT] Chrome is not the default for: " + ($notChrome -join ', '))
if ($Mode -eq 'Audit') { return }

# Windows 11 does not expose a supported per-user PowerShell API for setting
# protected UserChoice associations. Navigate directly to Chrome's default app
# settings using Microsoft's documented URI instead of spoofing UserChoice hashes.
# Selection still requires the user to click "Set default" once.
$uri = 'ms-settings:defaultapps'
$registered = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\RegisteredApplications' -Name 'Google Chrome' -ErrorAction SilentlyContinue
if ($null -ne $registered) {
    $uri = 'ms-settings:defaultapps?registeredAppMachine=Google%20Chrome'
} else {
    $registered = Get-ItemProperty -LiteralPath 'HKCU:\SOFTWARE\RegisteredApplications' -Name 'Google Chrome' -ErrorAction SilentlyContinue
    if ($null -ne $registered) {
        $uri = 'ms-settings:defaultapps?registeredAppUser=Google%20Chrome'
    }
}

try {
    Start-Process -FilePath $uri -ErrorAction Stop
    Write-Warning 'Windows Settings opened for Chrome. Click "Set default" once to finish; Windows requires a user choice for existing profiles.'
} catch {
    Write-Warning "Could not open Windows default app settings: $($_.Exception.Message). Navigate to Settings > Apps > Default apps > Google Chrome."
}
