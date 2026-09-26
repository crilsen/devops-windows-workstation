#Requires -Version 5.1
<#
.SYNOPSIS
    Enables WSL2, installs Ubuntu and creates a base .wslconfig.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

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
try {
    $distros = wsl --list --quiet 2>&1 | Out-String
    if ($distros -match 'Ubuntu') {
        Write-Ok -Message 'Ubuntu distribution already installed'
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

Write-Host 'Base WSL setup complete. No guest tooling is installed by this MVP.' -ForegroundColor Cyan
