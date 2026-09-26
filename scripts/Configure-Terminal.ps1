#Requires -Version 5.1
<#
.SYNOPSIS
    Safely patches Windows Terminal settings.json without destroying user config.
.DESCRIPTION
    Creates a timestamped backup, then sets PowerShell 7 as default,
    applies the Nerd Font face, light transparency and copy-on-select,
    while preserving unrelated profiles.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common.ps1')

$settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'

if (-not (Test-Path -Path $settingsPath)) {
    Write-Skip -Message "Windows Terminal settings not found at $settingsPath (open Terminal once, then re-run)"
    $example = Join-Path (Split-Path $PSScriptRoot -Parent) 'configs/terminal-settings.example.json'
    Write-Host "See example config: $example" -ForegroundColor DarkGray
    return
}

Backup-File -Path $settingsPath | Out-Null

try {
    $json = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Could not parse settings.json: $($_.Exception.Message)"
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

# PowerShell 7 as the default profile when its GUID is present.
$pwsh7 = $json.profiles.list | Where-Object { $_.name -match 'PowerShell' -and ($_.commandline -match 'pwsh' -or $_.source -match 'PowerShell') } | Select-Object -First 1
if ($pwsh7 -and $pwsh7.guid) {
    if (Set-PropIfDifferent -Object $json -Name 'defaultProfile' -Value $pwsh7.guid) { $changed = $true }
}

if (Set-PropIfDifferent -Object $json -Name 'copyOnSelect' -Value $true) { $changed = $true }

# Apply font + acrylic + cursor to project-owned profiles only.
foreach ($profile in $json.profiles.list) {
    if ($profile.name -match 'PowerShell|Ubuntu|Windows PowerShell') {
        if (-not $profile.PSObject.Properties['font']) {
            $profile | Add-Member -NotePropertyName 'font' -NotePropertyValue (@{ face = 'CaskaydiaCove Nerd Font' }) -Force
            $changed = $true
        }
        elseif ($profile.font.face -ne 'CaskaydiaCove Nerd Font') {
            $profile.font.face = 'CaskaydiaCove Nerd Font'
            $changed = $true
        }
        if (Set-PropIfDifferent -Object $profile -Name 'useAcrylic' -Value $true) { $changed = $true }
        if (Set-PropIfDifferent -Object $profile -Name 'acrylicOpacity' -Value 0.92) { $changed = $true }
        if (-not $profile.PSObject.Properties['cursor']) {
            $profile | Add-Member -NotePropertyName 'cursor' -NotePropertyValue (@{ shape = 'bar' }) -Force
            $changed = $true
        }
    }
}

if (-not $changed) {
    Write-Ok -Message 'Windows Terminal already configured'
    return
}

if ($PSCmdlet.ShouldProcess($settingsPath, 'Write patched Windows Terminal settings')) {
    $json | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
    Write-Change -Message 'Windows Terminal settings updated (backup preserved)'
}
