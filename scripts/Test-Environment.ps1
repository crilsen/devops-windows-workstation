#Requires -Version 5.1
<#
.SYNOPSIS
    Validates the workstation and prints a summary table.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'Common.ps1')

function Get-ToolVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$VersionArgs
    )
    try {
        if (-not (Test-CommandAvailable -Name $Command)) { return 'missing' }
        $out = & $Command @VersionArgs 2>&1 | Select-Object -First 1 | Out-String
        $out = $out.Trim()
        if ($out.Length -gt 40) { return $out.Substring(0, 40) }
        return $out
    }
    catch {
        return 'error'
    }
}

$rows = [System.Collections.Generic.List[object]]::new()

function Add-Row {
    param([string]$Component, [string]$Command, [string[]]$VersionArgs = @('--version'))
    $version = Get-ToolVersion -Command $Command -VersionArgs $VersionArgs
    $status = if ($version -in @('missing', 'error')) { 'MISSING' } else { 'OK' }
    $rows.Add([pscustomobject]@{ Component = $Component; Status = $status; Version = $version })
}

Add-Row -Component 'PowerShell' -Command 'pwsh' -VersionArgs @('--version')
Add-Row -Component 'WSL' -Command 'wsl' -VersionArgs @('--version')
Add-Row -Component 'Ubuntu' -Command 'wsl' -VersionArgs @('--list')
Add-Row -Component 'Git' -Command 'git' -VersionArgs @('--version')
Add-Row -Component 'AWS CLI' -Command 'aws' -VersionArgs @('--version')
Add-Row -Component 'kubectl' -Command 'kubectl' -VersionArgs @('version', '--client')
Add-Row -Component 'Helm' -Command 'helm' -VersionArgs @('version', '--short')
Add-Row -Component 'Terraform' -Command 'terraform' -VersionArgs @('--version')
Add-Row -Component 'OpenTofu' -Command 'tofu' -VersionArgs @('--version')
Add-Row -Component 'Docker' -Command 'docker' -VersionArgs @('--version')
Add-Row -Component 'Oh My Posh' -Command 'oh-my-posh' -VersionArgs @('--version')
Add-Row -Component 'Windows Terminal' -Command 'wt' -VersionArgs @('--version')

# Nerd Font check is registry-based and best-effort.
try {
    $font = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction Stop |
        Select-Object -ExpandProperty PSObject.Properties |
        Where-Object { $_.Name -match 'Caskaydia|Cascadia.*Nerd|Nerd Font' } |
        Select-Object -First 1
    $fontStatus = if ($font) { 'OK' } else { 'MISSING' }
    $fontVersion = if ($font) { $font.Name } else { 'not detected' }
}
catch {
    $fontStatus = 'UNKNOWN'
    $fontVersion = 'check skipped'
}
$rows.Add([pscustomobject]@{ Component = 'Nerd Font'; Status = $fontStatus; Version = $fontVersion })

$rows | Format-Table -AutoSize | Out-Host

# Optional AWS identity check: read-only, only when credentials already exist.
if (Test-CommandAvailable -Name 'aws') {
    try {
        aws sts get-caller-identity 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok -Message 'AWS credentials valid (sts get-caller-identity succeeded)'
        }
        else {
            Write-Host '[SKIP] No AWS credentials configured (skipping sts check)' -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Verbose "AWS identity check skipped: $($_.Exception.Message)"
    }
}

$missing = @($rows | Where-Object { $_.Status -eq 'MISSING' })
if ($missing.Count -eq 0) {
    Write-Host 'All checked components are present.' -ForegroundColor Green
    exit 0
}
else {
    Write-Warning "$($missing.Count) component(s) missing: $($missing.Component -join ', ')"
    exit 0
}
