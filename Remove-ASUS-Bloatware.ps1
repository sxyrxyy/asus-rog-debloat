param(
    [switch]$DryRun
)

# Re-launch as Administrator if not already elevated
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($PSCommandPath) {
        $relaunchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
        if ($DryRun) { $relaunchArgs += '-DryRun' }
        Start-Process powershell.exe -ArgumentList $relaunchArgs -Verb RunAs
    } else {
        $url      = 'https://raw.githubusercontent.com/sxyrxyy/asus-rog-debloat/main/Remove-ASUS-Bloatware.ps1'
        $tempPath = Join-Path $env:TEMP 'Remove-ASUS-Bloatware.ps1'
        try {
            Invoke-RestMethod $url -OutFile $tempPath
            $relaunchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tempPath)
            if ($DryRun) { $relaunchArgs += '-DryRun' }
            Start-Process powershell.exe -ArgumentList $relaunchArgs -Verb RunAs -Wait
        }
        finally {
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }
    }
    exit
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Remove-AppxBloatware {
    param([string[]]$Patterns)

    foreach ($pattern in $Patterns) {
        try {
            $packages = Get-AppxPackage -Name $pattern -AllUsers -ErrorAction SilentlyContinue
            if ($packages) {
                foreach ($pkg in $packages) {
                    if ($DryRun) {
                        Write-Status "[DRY RUN] Would remove AppX: $($pkg.Name)" 'Cyan'
                    } else {
                        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                        Write-Status "[REMOVED] AppX: $($pkg.Name)" 'Green'
                    }
                }
            } else {
                Write-Status "[SKIP] Not found: $pattern" 'Yellow'
            }
        } catch {
            Write-Status "[ERROR] Failed to remove $pattern`: $_" 'Red'
        }
    }
}

function Remove-Win32Bloatware {
    param([string[]]$DisplayNames)

    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($name in $DisplayNames) {
        $found = $false

        foreach ($regPath in $regPaths) {
            $entries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $name }

            foreach ($entry in $entries) {
                $found = $true
                $displayName  = $entry.DisplayName
                $uninstallStr = $entry.UninstallString

                if (-not $uninstallStr) { continue }

                if ($DryRun) {
                    Write-Status "[DRY RUN] Would remove Win32: $displayName" 'Cyan'
                    continue
                }

                try {
                    if ($uninstallStr -match 'msiexec') {
                        $productCode = [regex]::Match($uninstallStr, '\{[A-F0-9\-]+\}', 'IgnoreCase').Value
                        if (-not $productCode) {
                            Write-Status "[ERROR] Could not parse MSI product code from: $uninstallStr" 'Red'
                            continue
                        }
                        $proc = Start-Process 'msiexec.exe' `
                            -ArgumentList "/x $productCode /qn /norestart" `
                            -Wait -PassThru -ErrorAction Stop
                    } else {
                        if ($uninstallStr -match '^"([^"]+)"\s*(.*)$') {
                            $exePath     = $Matches[1]
                            $existingArgs = $Matches[2].Trim()
                        } else {
                            $exePath     = ($uninstallStr -split '\s+')[0]
                            $existingArgs = ($uninstallStr -split '\s+', 2)[1]
                        }
                        $silentArgs = (($existingArgs, '/S /VERYSILENT /SUPPRESSMSGBOXES /norestart') |
                            Where-Object { $_ }) -join ' '
                        $proc = Start-Process $exePath `
                            -ArgumentList $silentArgs `
                            -Wait -PassThru -ErrorAction Stop
                    }

                    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                        Write-Status "[REMOVED] $displayName" 'Green'
                    } else {
                        Write-Status "[ERROR] $displayName exited with code $($proc.ExitCode)" 'Red'
                    }
                } catch {
                    Write-Status "[ERROR] Failed to remove $displayName`: $_" 'Red'
                }
            }
        }

        if (-not $found) {
            Write-Status "[SKIP] Not found: $name" 'Yellow'
        }
    }
}

# ── PRESERVED (never touched) ─────────────────────────────────────────────────
# Armoury Crate                 — MUX switch (iGPU/dGPU), performance profiles, RGB
# ASUS System Control Interface — hardware driver, required by Armoury Crate
# ASUS Optimization Service     — runtime dependency of Armoury Crate
# NVIDIA / AMD drivers          — not ASUS software, out of scope

# ── AppX targets ──────────────────────────────────────────────────────────────
$appxTargets = @(
    '*MyASUS*',
    '*ASUSWebStorage*',
    '*ROGGamingCenter*',
    '*Booking*',
    '*Amazon.com*',
    '*McAfee*'
)

# ── Win32 targets ─────────────────────────────────────────────────────────────
$win32Targets = @(
    'ASUS Live Update*',
    'ASUS Splendid*',
    'ASUS Tray Utility*',
    'ROG Aura Core*',
    'ASUS Virtual Drive*',
    'Sonic Studio*',
    'Sonic Radar*',
    'GameFirst*',
    'McAfee LiveSafe*',
    'McAfee Total Protection*',
    'McAfee WebAdvisor*',
    'WPS Office*'
)

# ── Main ──────────────────────────────────────────────────────────────────────
Write-Host ''
if ($DryRun) {
    Write-Status '=== DRY RUN — no changes will be made ===' 'Cyan'
} else {
    Write-Status '=== ASUS ROG Bloatware Removal ===' 'White'
}
Write-Host ''

Write-Status '--- Store / UWP apps ---' 'White'
Remove-AppxBloatware -Patterns $appxTargets

Write-Host ''
Write-Status '--- Win32 apps ---' 'White'
Remove-Win32Bloatware -DisplayNames $win32Targets

Write-Host ''
Write-Status 'Done.' 'White'
if (-not $DryRun) {
    Write-Status 'A restart may be required for some removals to complete.' 'Yellow'
}
