#Requires -Version 5.1
<#
.SYNOPSIS
    Installs or validates DevOps tools on Windows, preferring winget.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipDocker,
    [switch]$Minimal
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

# Azure CLI stays optional and is installed only on demand.
if ($env:INSTALL_AZURE_CLI -eq '1') {
    $tools += @(@{ WingetId = 'Microsoft.AzureCLI'; DisplayName = 'Azure CLI'; TestCommand = 'az' })
}
else {
    Write-Skip -Message 'Azure CLI skipped (set INSTALL_AZURE_CLI=1 to include it)'
}

foreach ($tool in $tools) {
    Install-WingetPackage -WingetId $tool.WingetId -DisplayName $tool.DisplayName -TestCommand $tool.TestCommand
}
