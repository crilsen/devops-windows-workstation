#Requires -Version 5.1
<#
.SYNOPSIS
    Installs or updates the PowerShell profile with DevOps aliases and PSReadLine setup.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$repoProfile = Join-Path (Split-Path $PSScriptRoot -Parent) 'configs/Microsoft.PowerShell_profile.ps1'
$targetProfile = $PROFILE.CurrentUserAllHosts

if (-not (Test-Path -Path $repoProfile)) {
    Write-Error "Repo profile template not found: $repoProfile"
    exit 1
}

$targetDir = Split-Path $targetProfile -Parent
if (-not (Test-Path -Path $targetDir)) {
    if ($PSCmdlet.ShouldProcess($targetDir, 'Create profile directory')) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
}

if (Test-Path -Path $targetProfile) {
    $current = Get-Content -Path $targetProfile -Raw -ErrorAction SilentlyContinue
    $desired = Get-Content -Path $repoProfile -Raw
    if ($current -eq $desired) {
        Write-Ok -Message 'PowerShell profile already up to date'
        return
    }
    Backup-File -Path $targetProfile | Out-Null
    if ($PSCmdlet.ShouldProcess($targetProfile, 'Update PowerShell profile')) {
        Copy-Item -Path $repoProfile -Destination $targetProfile -Force
        Write-Change -Message 'PowerShell profile updated'
    }
}
else {
    if ($PSCmdlet.ShouldProcess($targetProfile, 'Install PowerShell profile')) {
        Copy-Item -Path $repoProfile -Destination $targetProfile -Force
        Write-Change -Message "PowerShell profile installed at $targetProfile"
    }
}
