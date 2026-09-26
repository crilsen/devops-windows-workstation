#Requires -Version 5.1
<#
.SYNOPSIS
    Enables WSL2, installs Ubuntu and provisions the guest distribution.
.DESCRIPTION
    Handles host-side setup (.wslconfig, default version, Ubuntu install)
    and runs scripts/wsl-setup.sh inside Ubuntu for base packages,
    Kubernetes tooling and the selected cloud provider CLIs.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('AWS', 'Azure', 'OCI', 'GCP', 'All')]
    [string[]]$Cloud = @('AWS')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

if (-not (Test-CommandAvailable -Name 'wsl')) {
    Write-Warning 'WSL CLI not found. Enable WSL via an elevated session and retry.'
    Write-Host 'Run as admin: wsl --install' -ForegroundColor Yellow
    return
}

try {
    $wslStatus = wsl --status 2>&1 | Out-String
    Write-Verbose $wslStatus
    Write-Ok -Message 'WSL CLI available'
}
catch {
    Write-Warning "Could not query WSL status: $($_.Exception.Message)"
}

# Ensure WSL2 is the default version (requires elevation on first run).
try {
    if ($PSCmdlet.ShouldProcess('WSL', 'Set default version to 2')) {
        wsl --set-default-version 2 2>&1 | Write-Verbose
        Write-Ok -Message 'WSL default version set to 2'
    }
}
catch {
    Write-Warning "Could not set WSL default version (run elevated once): $($_.Exception.Message)"
}

# Install Ubuntu idempotently; skip when already present.
$ubuntuReady = $false
try {
    $distros = wsl --list --quiet 2>&1 | Out-String
    if ($distros -match 'Ubuntu') {
        Write-Ok -Message 'Ubuntu distribution already installed'
        $ubuntuReady = $true
    }
    elseif ($PSCmdlet.ShouldProcess('Ubuntu', 'Install via wsl')) {
        Write-Change -Message 'Installing Ubuntu...'
        wsl --install -d Ubuntu
        Write-Ok -Message 'Ubuntu install requested (a reboot may be required on first enablement)'
    }
}
catch {
    Write-Warning "Ubuntu install check failed: $($_.Exception.Message)"
}

# Base .wslconfig with conservative resource limits. Never overwrites without backup.
$wslConfigPath = Join-Path $env:USERPROFILE '.wslconfig'
$repoConfig = Join-Path (Split-Path $PSScriptRoot -Parent) 'configs/.wslconfig'

if (Test-Path -Path $wslConfigPath) {
    Write-Ok -Message '.wslconfig already exists (left untouched)'
}
else {
    if ($PSCmdlet.ShouldProcess($wslConfigPath, 'Create default .wslconfig')) {
        Copy-Item -Path $repoConfig -Destination $wslConfigPath -Force
        Write-Change -Message ".wslconfig created at $wslConfigPath"
    }
}

Write-Host 'Base WSL setup complete.' -ForegroundColor Cyan

# Guest provisioning: copy wsl-setup.sh into the distro and run it there.
# Skipped on fresh installs until Ubuntu first-run setup completes.
if (-not $ubuntuReady) {
    Write-Skip -Message 'Ubuntu guest provisioning skipped (complete the Ubuntu first-run setup, then re-run)'
    return
}

$guestScript = Join-Path $PSScriptRoot 'wsl-setup.sh'
$cloudArgs = @($Cloud | ForEach-Object { $_.ToLowerInvariant() }) -join ' '
try {
    $wslTest = wsl -d Ubuntu -- bash -lc 'echo guest-ready' 2>&1 | Out-String
    if ($wslTest -notmatch 'guest-ready') {
        Write-Skip -Message 'Ubuntu guest not responding yet (finish first-run setup, then re-run)'
        return
    }
}
catch {
    Write-Skip -Message 'Ubuntu guest not reachable yet (finish first-run setup, then re-run)'
    return
}

if ($PSCmdlet.ShouldProcess('Ubuntu guest', "Run wsl-setup.sh ($cloudArgs)")) {
    Copy-Item -Path $guestScript -Destination '\\wsl$\Ubuntu\tmp\devops-wsl-setup.sh' -Force
    wsl -d Ubuntu -- bash /tmp/devops-wsl-setup.sh $cloudArgs
    Write-Ok -Message 'Ubuntu guest provisioning complete'
}
