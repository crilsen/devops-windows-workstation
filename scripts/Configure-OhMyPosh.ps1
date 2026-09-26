#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Oh My Posh, a Nerd Font, and deploys the bundled theme.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

Install-WingetPackage -WingetId 'JanDeDobbeleer.OhMyPosh' -DisplayName 'Oh My Posh' -TestCommand 'oh-my-posh'

# Nerd Font for prompt glyphs. CascadiaCode NF keeps Windows Terminal consistent.
Install-WingetPackage -WingetId 'Microsoft.CascadiaCode' -DisplayName 'Cascadia Code NF' -TestCommand ''

$repoTheme = Join-Path (Split-Path $PSScriptRoot -Parent) 'configs/oh-my-posh.json'
$themeDir = Join-Path $env:USERPROFILE '.oh-my-posh'
$targetTheme = Join-Path $themeDir 'devops-workstation.json'

if (-not (Test-Path -Path $themeDir)) {
    if ($PSCmdlet.ShouldProcess($themeDir, 'Create Oh My Posh theme directory')) {
        New-Item -ItemType Directory -Path $themeDir -Force | Out-Null
    }
}

if (Test-Path -Path $targetTheme) {
    $current = Get-Content -Path $targetTheme -Raw -ErrorAction SilentlyContinue
    $desired = Get-Content -Path $repoTheme -Raw
    if ($current -eq $desired) {
        Write-Ok -Message 'Oh My Posh theme already up to date'
        return
    }
    Backup-File -Path $targetTheme | Out-Null
}

if ($PSCmdlet.ShouldProcess($targetTheme, 'Deploy Oh My Posh theme')) {
    Copy-Item -Path $repoTheme -Destination $targetTheme -Force
    Write-Change -Message "Oh My Posh theme deployed to $targetTheme"
}

Write-Host 'Prompt reads POSH_THEME from the environment when set; otherwise the deployed theme is used.' -ForegroundColor DarkGray
