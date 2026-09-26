#Requires -Version 5.1
<#
.SYNOPSIS
    Entry point for automated Windows DevOps workstation provisioning.
.DESCRIPTION
    Orchestrates prerequisites, WSL2, DevOps tools, PowerShell profile,
    Oh My Posh prompt and Windows Terminal configuration.
    Idempotent: safe to run multiple times.
.EXAMPLE
    .\bootstrap.ps1
.EXAMPLE
    .\bootstrap.ps1 -SkipDocker -SkipWSL
.EXAMPLE
    .\bootstrap.ps1 -Minimal
.EXAMPLE
    .\bootstrap.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipWSL,
    [switch]$SkipDocker,
    [switch]$Minimal,
    [switch]$InstallTools,
    [switch]$ConfigureTerminal,
    [switch]$SkipTools,
    [switch]$SkipTerminal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
. (Join-Path $ScriptRoot 'scripts/Common.ps1')

Write-Banner -Title 'DevOps Workstation Bootstrap'

$runTools = $true
$runTerminal = $true

if ($Minimal) {
    $SkipWSL = $true
    $SkipDocker = $true
}

# -InstallTools / -ConfigureTerminal act as focused-run selectors.
if ($InstallTools -and -not $ConfigureTerminal) {
    $runTerminal = $false
}
if ($ConfigureTerminal -and -not $InstallTools) {
    $runTools = $false
    $SkipWSL = $true
}
if ($SkipTools) { $runTools = $false }
if ($SkipTerminal) { $runTerminal = $false }

$results = [System.Collections.Generic.List[object]]::new()

try {
    Write-Step -Message 'Checking prerequisites (Windows version, admin rights)'
    & (Join-Path $ScriptRoot 'scripts/Install-Prerequisites.ps1')
    $results.Add([pscustomobject]@{ Component = 'Prerequisites'; Status = 'OK' })

    if (-not $SkipWSL) {
        Write-Step -Message 'Configuring WSL2 + Ubuntu'
        & (Join-Path $ScriptRoot 'scripts/Install-WSL.ps1')
        $results.Add([pscustomobject]@{ Component = 'WSL2'; Status = 'OK' })
    }
    else {
        Write-Skip -Message 'WSL installation disabled (-SkipWSL or -Minimal)'
        $results.Add([pscustomobject]@{ Component = 'WSL2'; Status = 'SKIP' })
    }

    if ($runTools) {
        Write-Step -Message 'Installing / validating DevOps tools'
        $toolParams = @{}
        if ($SkipDocker) { $toolParams['SkipDocker'] = $true }
        if ($Minimal) { $toolParams['Minimal'] = $true }
        & (Join-Path $ScriptRoot 'scripts/Install-DevOpsTools.ps1') @toolParams
        $results.Add([pscustomobject]@{ Component = 'DevOps tools'; Status = 'OK' })

        if (-not $SkipDocker -and -not $Minimal) {
            Write-Step -Message 'Configuring Docker Desktop (WSL2 backend + Ubuntu integration)'
            & (Join-Path $ScriptRoot 'scripts/Configure-Docker.ps1')
            $results.Add([pscustomobject]@{ Component = 'Docker Desktop'; Status = 'OK' })
        }
        else {
            Write-Skip -Message 'Docker configuration disabled (-SkipDocker or -Minimal)'
            $results.Add([pscustomobject]@{ Component = 'Docker Desktop'; Status = 'SKIP' })
        }
    }
    else {
        Write-Skip -Message 'DevOps tools step skipped'
    }

    Write-Step -Message 'Configuring PowerShell profile'
    & (Join-Path $ScriptRoot 'scripts/Configure-PowerShell.ps1')
    $results.Add([pscustomobject]@{ Component = 'PowerShell profile'; Status = 'OK' })

    if ($runTerminal) {
        Write-Step -Message 'Configuring Oh My Posh'
        & (Join-Path $ScriptRoot 'scripts/Configure-OhMyPosh.ps1')
        $results.Add([pscustomobject]@{ Component = 'Oh My Posh'; Status = 'OK' })

        Write-Step -Message 'Configuring Windows Terminal'
        & (Join-Path $ScriptRoot 'scripts/Configure-Terminal.ps1')
        $results.Add([pscustomobject]@{ Component = 'Windows Terminal'; Status = 'OK' })
    }
    else {
        Write-Skip -Message 'Terminal configuration skipped'
    }

    Write-Step -Message 'Validating environment'
    & (Join-Path $ScriptRoot 'scripts/Test-Environment.ps1')
}
catch {
    Write-Error "Bootstrap failed: $($_.Exception.Message)"
    exit 1
}

Write-Host ''
Write-Host 'Workstation ready.' -ForegroundColor Green
Write-Host 'Restart Windows Terminal to load the new configuration.' -ForegroundColor Cyan
exit 0
