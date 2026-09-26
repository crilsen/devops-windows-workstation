#Requires -Version 5.1
<#
.SYNOPSIS
    Installs or validates DevOps tools on Windows, preferring winget.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipDocker,
    [switch]$Minimal,
    [ValidateSet('AWS', 'Azure', 'OCI', 'GCP', 'All')]
    [string[]]$Cloud = @('AWS')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$tools = @(
    @{ WingetId = 'Git.Git';                   DisplayName = 'Git';              TestCommand = 'git' }
    @{ WingetId = 'Microsoft.VisualStudioCode'; DisplayName = 'Visual Studio Code'; TestCommand = 'code' }
    @{ WingetId = 'Microsoft.PowerShell';       DisplayName = 'PowerShell 7';   TestCommand = 'pwsh' }
    @{ WingetId = 'Microsoft.WindowsTerminal';  DisplayName = 'Windows Terminal'; TestCommand = 'wt' }
    @{ WingetId = 'Amazon.AWSCLI';              DisplayName = 'AWS CLI v2';      TestCommand = 'aws' }
    @{ WingetId = 'Kubernetes.kubectl';         DisplayName = 'kubectl';         TestCommand = 'kubectl' }
    @{ WingetId = 'Helm.Helm';                  DisplayName = 'Helm';            TestCommand = 'helm' }
    @{ WingetId = 'HashiCorp.Terraform';        DisplayName = 'Terraform';       TestCommand = 'terraform' }
    @{ WingetId = 'OpenTofu.OpenTofu';          DisplayName = 'OpenTofu';        TestCommand = 'tofu' }
    @{ WingetId = 'GitHub.cli';                 DisplayName = 'GitHub CLI';      TestCommand = 'gh' }
    @{ WingetId = 'jqlang.jq';                  DisplayName = 'jq';              TestCommand = 'jq' }
    @{ WingetId = 'curl.curl';                  DisplayName = 'curl';            TestCommand = 'curl' }
    @{ WingetId = '7zip.7zip';                  DisplayName = '7-Zip';           TestCommand = '7z' }
)

# Cloud provider CLIs are opt-in per profile; AWS stays in the default set.
$wantAll = $Cloud -contains 'All'
if ($wantAll -or ($Cloud -contains 'Azure') -or ($env:INSTALL_AZURE_CLI -eq '1')) {
    $tools += @(@{ WingetId = 'Microsoft.AzureCLI'; DisplayName = 'Azure CLI'; TestCommand = 'az' })
}
else {
    Write-Skip -Message 'Azure CLI skipped (add -Cloud Azure or -Cloud All to include it)'
}
if ($wantAll -or ($Cloud -contains 'OCI')) {
    $tools += @(@{ WingetId = 'Oracle.OCI-CLI'; DisplayName = 'OCI CLI'; TestCommand = 'oci' })
}
else {
    Write-Skip -Message 'OCI CLI skipped (add -Cloud OCI or -Cloud All to include it)'
}
if ($wantAll -or ($Cloud -contains 'GCP')) {
    $tools += @(@{ WingetId = 'Google.CloudSDK'; DisplayName = 'Google Cloud CLI'; TestCommand = 'gcloud' })
}
else {
    Write-Skip -Message 'Google Cloud CLI skipped (add -Cloud GCP or -Cloud All to include it)'
}

if (-not $SkipDocker -and -not $Minimal) {
    $tools += @(@{ WingetId = 'Docker.DockerDesktop'; DisplayName = 'Docker Desktop'; TestCommand = 'docker' })
}
else {
    Write-Skip -Message 'Docker installation disabled'
}

if ($Minimal) {
    $minimalNames = @('Git', 'PowerShell 7', 'Windows Terminal', 'Visual Studio Code', 'AWS CLI v2', 'kubectl')
    $tools = $tools | Where-Object { $minimalNames -contains $_.DisplayName }
    Write-Host 'Minimal profile: installing core tools only.' -ForegroundColor Cyan
}

foreach ($tool in $tools) {
    Install-WingetPackage -WingetId $tool.WingetId -DisplayName $tool.DisplayName -TestCommand $tool.TestCommand
}
