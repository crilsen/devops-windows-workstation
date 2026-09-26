#Requires -Version 5.1
<#
.SYNOPSIS
    Validates Windows version, admin rights, winget, PS7 and Windows Terminal.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$info = Get-WindowsVersionInfo
Write-Host "Windows: $($info.Caption) $($info.Version) (build $($info.BuildNumber), $($info.Architecture))"

try {
    $build = [int]$info.BuildNumber
    if ($build -lt 19041) {
        Write-Warning 'Windows build is older than 19041. WSL2 and Windows Terminal may not work correctly.'
    }
    else {
        Write-Ok -Message "Windows build $build supports WSL2"
    }
}
catch {
    Write-Verbose "Build number comparison skipped: $($_.Exception.Message)"
}

if (Test-IsAdmin) {
    Write-Ok -Message 'Running with administrative privileges'
}
else {
    Write-Warning 'Not running as administrator. Some steps (WSL enablement, some installs) may require elevation.'
}

# winget is the preferred installer provider in this project.
if (Test-CommandAvailable -Name 'winget') {
    Write-Ok -Message 'winget available'
}
else {
    Write-Warning 'winget not found. Install App Installer from the Microsoft Store to enable automatic tool installation.'
}

Install-WingetPackage -WingetId 'Microsoft.PowerShell' -DisplayName 'PowerShell 7' -TestCommand 'pwsh'
Install-WingetPackage -WingetId 'Microsoft.WindowsTerminal' -DisplayName 'Windows Terminal' -TestCommand 'wt'

# Safe execution setup: CurrentUser scope only, never relax machine policy silently.
try {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    Write-Host "ExecutionPolicy (CurrentUser): $policy"
    if ($policy -in @('Restricted', 'AllSigned')) {
        if ($PSCmdlet.ShouldProcess('CurrentUser ExecutionPolicy', 'Set to RemoteSigned')) {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Change -Message 'ExecutionPolicy (CurrentUser) set to RemoteSigned'
        }
    }
    else {
        Write-Ok -Message "ExecutionPolicy (CurrentUser) is $policy"
    }
}
catch {
    Write-Warning "Could not adjust ExecutionPolicy: $($_.Exception.Message)"
}
