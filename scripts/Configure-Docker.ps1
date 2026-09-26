#Requires -Version 5.1
<#
.SYNOPSIS
    Applies safe, idempotent Docker Desktop settings for a WSL2 workflow.
.DESCRIPTION
    Patches %APPDATA%\Docker\settings.json with a timestamped backup:
    enables the WSL2 engine and WSL integration for Ubuntu, preserving
    every other user setting. Never fabricates a full settings file.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipDocker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

if ($SkipDocker) {
    Write-Skip -Message 'Docker configuration disabled (-SkipDocker)'
    return
}

if (-not (Test-CommandAvailable -Name 'docker')) {
    Write-Skip -Message 'Docker CLI not found; install Docker Desktop first, then re-run'
    return
}
Write-Ok -Message 'Docker CLI available'

$settingsPath = Join-Path $env:APPDATA 'Docker\settings.json'

if (-not (Test-Path -Path $settingsPath)) {
    Write-Skip -Message "Docker Desktop settings not found at $settingsPath (launch Docker Desktop once, then re-run)"
    $example = Join-Path (Split-Path $PSScriptRoot -Parent) 'configs/docker-settings.example.json'
    Write-Host "See example config: $example" -ForegroundColor DarkGray
    return
}

Backup-File -Path $settingsPath | Out-Null

try {
    $json = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Could not parse Docker settings.json: $($_.Exception.Message)"
    exit 1
}

$changed = $false

function Set-PropIfDifferent {
    param($Object, [string]$Name, $Value)
    if ($Object.$Name -ne $Value) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
        return $true
    }
    return $false
}

# WSL2 backend is required for the Ubuntu integration used by this project.
if (Set-PropIfDifferent -Object $json -Name 'wslEngineEnabled' -Value $true) { $changed = $true }

# Ensure Ubuntu stays integrated without dropping other user-selected distros.
$distros = @()
if ($json.PSObject.Properties['integratedWslDistros'] -and $json.integratedWslDistros) {
    $distros = @($json.integratedWslDistros)
}
if ($distros -notcontains 'Ubuntu') {
    $distros += 'Ubuntu'
    $json | Add-Member -NotePropertyName 'integratedWslDistros' -NotePropertyValue $distros -Force
    $changed = $true
}

if (-not $changed) {
    Write-Ok -Message 'Docker Desktop already configured (WSL2 engine + Ubuntu integration)'
    return
}

if ($PSCmdlet.ShouldProcess($settingsPath, 'Write patched Docker Desktop settings')) {
    $json | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
    Write-Change -Message 'Docker Desktop settings updated (backup preserved)'
    Write-Host 'Restart Docker Desktop to apply the new settings.' -ForegroundColor Cyan
}
