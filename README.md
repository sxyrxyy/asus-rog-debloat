# Remove-ASUS-Bloatware

Removes pre-installed ASUS and bundled third-party software from ROG laptops.

## Usage

Run `-DryRun` first - it shows what's installed on your machine without touching anything.

```powershell
# Preview only
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Remove-ASUS-Bloatware.ps1 -DryRun

# Remove
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Remove-ASUS-Bloatware.ps1
```

If you're not already running as admin, the script asks for elevation automatically.

## Run directly from GitHub

Paste into an elevated PowerShell window - nothing is written to disk.

```powershell
# Preview
& ([ScriptBlock]::Create((irm 'https://raw.githubusercontent.com/sxyrxyy/asus-rog-debloat/main/Remove-ASUS-Bloatware.ps1'))) -DryRun

# Remove
& ([ScriptBlock]::Create((irm 'https://raw.githubusercontent.com/sxyrxyy/asus-rog-debloat/main/Remove-ASUS-Bloatware.ps1')))
```

## What gets removed

McAfee, WPS Office, Booking.com, Amazon Shopping, MyASUS, ASUS WebStorage, ROG Gaming Center, ASUS Live Update, Splendid, Tray Utility, ROG Aura Core, Virtual Drive, Sonic Studio, Sonic Radar, GameFirst.

## What stays

Armoury Crate and its dependencies. That's the software controlling the GPU mode switch (iGPU vs dGPU), performance profiles, and RGB. GPU drivers are not touched.

You'll probably need to restart after running.
