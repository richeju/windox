# Windox

Reproducible Windows 11 workstation setup and drift correction, powered by PowerShell and WinGet.

## Quick start

Open **PowerShell** on Windows 11, clone this repository, and run:

```powershell
git clone https://github.com/richeju/windox.git
cd windox
.\bootstrap.ps1 -Mode Audit
.\bootstrap.ps1 -Mode Apply
```

If Git is not installed yet, download the repository ZIP from GitHub, extract it, and run the script from the extracted folder.

**Audit is the default**: `.\bootstrap.ps1` only reports missing packages and setting drift. **Apply** installs missing WinGet packages and configures Windows. Commands are intended to be run from a regular, non-elevated user PowerShell session. If script execution is restricted, use a temporary *process-only* execution policy in a trusted session rather than permanently relaxing system policy.

## Files

- `bootstrap.ps1`: single entry point; safe-by-default audit or explicit apply.
- `config/packages.json`: desired WinGet package IDs. Edit to suit your workstation.
- `scripts/system.ps1`: idempotent, user-scoped Windows settings.
- `.gitignore`: excludes common local secrets and generated files.

## Design

- **Re-runnable:** installed packages and matching settings are skipped.
- **Reviewable:** dry-run-style Audit before Apply.
- **Conservative:** no automatic debloating, registry mass edits, disk formatting, account creation, or system-wide policy changes.
- **No secrets in Git:** never commit tokens, passwords, SSH private keys or recovery keys.
- **Versioned:** review diffs before running changes on your personal machine.

## Planned improvements

Add opt-in profiles (dev, gaming, media), managed app configuration, package version pinning where appropriate, better structured logging, backups for settings before modification, and PowerShell Pester tests.

> Initial scaffold; not yet executed on a Windows machine. Review `config/packages.json` before running Apply.
