# Windox

Configure or restore a Windows 11 workstation with **one PowerShell line**. Windox uses **Chocolatey** for packages and applies repeatable Windows settings.

## Run from a fresh Windows installation

Open PowerShell and paste this **single line**:

```powershell
$env:WINDOX_MODE='Apply'; irm https://raw.githubusercontent.com/richeju/windox/main/install.ps1 | iex
```

If necessary, Windows displays a UAC prompt to run the installation as administrator. Approve it to continue. No Git clone and no WinGet prerequisite are needed.

What happens:
1. The small remote launcher downloads the Windox repository into a temporary folder.
2. `bootstrap.ps1` requests administrator privileges if required.
3. `scripts/chocolatey.ps1` installs Chocolatey (if missing), then the packages in `config/packages.json`.
4. `scripts/browser.ps1` checks Chrome's default status and opens its Windows settings page if a change is needed.
5. `scripts/gaming.ps1` installs Plarium Play unattended and places RSL-Xtender in a managed portable directory.
6. `scripts/system.ps1` applies the managed Windows preferences.
7. The temporary checkout is deleted by the launcher.

A run can be repeated: packages already managed by Chocolatey and settings already matching the desired state are skipped. Packages installed outside Chocolatey are **not** automatically recognized as managed by Chocolatey; review the manifest before running.

### Read-only audit

```powershell
irm https://raw.githubusercontent.com/richeju/windox/main/install.ps1 | iex
```

Audit is the default and makes **no changes**. When Chocolatey is not installed, Windox reports its absence and cannot yet audit its package inventory. Only `Apply` makes changes.

### Run from a local clone

```powershell
git clone https://github.com/richeju/windox.git
cd windox
.\bootstrap.ps1 -Mode Audit
.\bootstrap.ps1 -Mode Apply
```

You can skip package installation and apply just the Windows settings with `-SkipPackages`; Chocolatey is still checked as a prerequisite.

## Repository

```text
windox/
├── install.ps1              # Remote ZIP launcher
├── bootstrap.ps1            # Single orchestration entry point
├── config/
│   └── packages.json        # Chocolatey package IDs
├── scripts/
│   ├── chocolatey.ps1       # Chocolatey bootstrap and package convergence
│   ├── browser.ps1          # Chrome default-browser check and settings link
│   ├── gaming.ps1           # Plarium Play and RSL-Xtender
│   └── system.ps1           # Idempotent Windows settings
└── .gitignore
```

Initial applications: `7zip`, `powershell-core`, `thunderbird`, `pcloud`, and `googlechrome`. Git and VS Code are optional and not installed by default.

## Google Chrome

Windox installs **Google Chrome silently** through the Chocolatey `googlechrome` package. It checks whether Chrome handles `http`, `https`, `.htm` and `.html` for the account running Windox.

**Windows 11 protects an existing user's default-app choice.** There is no supported silent PowerShell command to force these per-user associations. If Chrome is not the default, Apply mode opens the official Windows Settings page for Chrome (via `ms-settings:defaultapps?registeredAppMachine=Google%20Chrome` when Chrome is registered machine-wide). Click **Set default** once. Audit mode only reports the current setting and does not open Settings.

In environments where UAC requires signing in as a *different* administrator, Windox examines that administrator's profile, not the original user's. The normal user can finish the default-app selection in their own session through Settings > Apps > Default apps > Google Chrome.

For provisioning *new user profiles*, Microsoft also supports importing a default-associations XML through DISM, but that does **not** retroactively change an existing logged-in user's defaults. Windox intentionally does not set a device-wide association policy or alter Windows' UserChoice registry hashes.

## Gaming: RAID and RSL-Xtender

- **RaidBot workspace:** Windox creates `C:\raidbot` if it does not already exist. In Audit mode, it only reports whether the folder exists. Existing content is preserved.
- **Microsoft Defender:** Windox checks whether `C:\raidbot` is excluded from Defender scanning and adds only that directory in Apply mode (via `Add-MpPreference -ExclusionPath`). The exclusion persists, also affects files created later in the folder, and reduces protection; do not store untrusted downloads there. Audit mode is read-only. If a managed antivirus policy prevents this change, Windox reports a failure without switching off antivirus protection.


- **Plarium Play:** downloaded from `installer.plarium.com`, with a valid Plarium Authenticode signature required. Launched with `/S` (an unofficial community-documented silent flag; it must be verified on a real Windows PC).
- **RAID: Shadow Legends:** after Plarium Play is installed, sign in with your **existing Plarium ID** and install RAID in the launcher. There is no confirmed fully unattended install of the game itself. Windox detects the game when present, but cannot bypass login.
- **RSL-Xtender:** official [IRSwish/xtender](https://github.com/IRSwish/xtender/releases) portable ZIP, pinned to **v1.1.56** and verified against the GitHub release SHA-256 before silent extraction into `%ProgramData%\Windox\apps\RSL-Xtender\1.1.56`. A Start Menu shortcut is added. Existing installations in common user locations are not duplicated.
- **Security:** Windox does not disable SmartScreen, antivirus software, or other protections. If Windows blocks a release, investigate its provenance rather than automatically whitelisting it.
- **Upgrade policy:** RSL-Xtender's pinned version only changes when this script is reviewed and updated; the app may offer its own updater.

The gaming module has not yet been tested on a Windows 11 workstation. If the Plarium installer changes its signing or silent-install behavior, the script reports a failure rather than silently running unknown software.

## Design and safety

- **No WinGet dependency:** packages are managed by Chocolatey (CLI 2.x compatible).
- **No surprise upgrades or removals:** missing Chocolatey packages are installed; existing ones are skipped. Windox does not upgrade every installed application.
- **No global execution-policy change:** the launcher temporarily permits execution of the downloaded scripts in the *current PowerShell process* and restores the previous setting. Group Policy may still restrict execution.
- **No secrets in Git:** do not commit passwords, tokens, SSH private keys, or BitLocker recovery keys.
- **Review code before remote execution:** `irm | iex` runs code fetched from a mutable `main` branch; you can pin it to a reviewed commit for stronger supply-chain protection.
- **Elevation:** the UAC prompt uses the elevated user's profile. If your standard and admin accounts are different, user-scoped preferences will apply to the admin account; run settings under the intended account instead.
- **Community packages:** Chocolatey community packages may depend on third-party downloads and are not guaranteed to be fully reproducible offline.

This initial release has **not yet been tested on a real Windows 11 machine**. Try Audit first when possible.
