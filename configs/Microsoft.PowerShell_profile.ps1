# DevOps workstation profile (Windows PowerShell 5.1 / PowerShell 7).
# Idempotent by design: this file is deployed verbatim by Configure-PowerShell.ps1.

Set-StrictMode -Version Latest

# --- PSReadLine: history, completion, predictions ---------------------------
try {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    if (Get-Module PSReadLine) {
        Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
    }
} catch {
    Write-Verbose "PSReadLine setup skipped: $($_.Exception.Message)"
}

# --- Oh My Posh prompt ------------------------------------------------------
try {
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        $theme = $env:POSH_THEME
        if ([string]::IsNullOrWhiteSpace($theme)) {
            $theme = Join-Path $env:USERPROFILE '.oh-my-posh/devops-workstation.json'
        }
        if (Test-Path $theme) {
            oh-my-posh init pwsh --config $theme | Invoke-Expression
        }
    }
} catch {
    Write-Verbose "Oh My Posh init skipped: $($_.Exception.Message)"
}

# --- DevOps aliases and helpers ---------------------------------------------
function Invoke-KubectlContext { kubectl config current-context 2>$null }
function Invoke-GitStatusShort { git status --short --branch 2>$null }

Set-Alias -Name k -Value kubectl -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name tf -Value terraform -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name tg -Value terragrunt -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name g -Value git -Scope Global -ErrorAction SilentlyContinue
Set-Alias -Name d -Value docker -Scope Global -ErrorAction SilentlyContinue

function ll { Get-ChildItem -Force @args }
function which([string]$Name) { Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source }

# AWS helpers show intent without storing secrets.
function aws-whoami { aws sts get-caller-identity @args }
function aws-region { aws configure get region 2>$null }

# Keep PATH additions duplicate-free across reloads.
function Add-PathOnce([string]$Dir) {
    if ([string]::IsNullOrWhiteSpace($Dir)) { return }
    if (-not (Test-Path $Dir)) { return }
    $parts = $env:PATH -split ';'
    if ($parts -notcontains $Dir) { $env:PATH = ($parts + $Dir) -join ';' }
}
