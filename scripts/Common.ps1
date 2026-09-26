Set-StrictMode -Version Latest

function Write-Banner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Title
    )
    Write-Host ''
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ('-' * $Title.Length) -ForegroundColor DarkGray
    Write-Host ''
}

function Write-Step {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )
    Write-Host "[STEP] $Message" -ForegroundColor Cyan
    Write-Verbose $Message
}

function Write-Ok {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Change {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )
    Write-Host "[CHANGE] $Message" -ForegroundColor Yellow
}

function Write-Skip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )
    Write-Host "[SKIP] $Message" -ForegroundColor DarkGray
}

function Test-IsAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Verbose "Admin check failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-CommandAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Backup-File {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        Write-Verbose "Nothing to back up: $Path does not exist."
        return $null
    }
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$Path.backup-$timestamp"
    if ($PSCmdlet.ShouldProcess($Path, "Create backup at $backupPath")) {
        Copy-Item -Path $Path -Destination $backupPath -Force
        Write-Change -Message "Backup created: $backupPath"
    }
    return $backupPath
}

function Install-WingetPackage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WingetId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TestCommand
    )

    # Idempotency: skip when the binary is already available.
    if ($TestCommand -and (Test-CommandAvailable -Name $TestCommand)) {
        Write-Ok -Message "$DisplayName already installed"
        return
    }

    if (-not (Test-CommandAvailable -Name 'winget')) {
        Write-Warning "winget not found; cannot install $DisplayName automatically."
        return
    }

    if ($PSCmdlet.ShouldProcess($DisplayName, "Install via winget ($WingetId)")) {
        try {
            Write-Change -Message "Installing $DisplayName via winget..."
            winget install --id $WingetId --exact --silent --accept-package-agreements --accept-source-agreements
            Write-Ok -Message "$DisplayName installed"
        }
        catch {
            Write-Warning "Failed to install ${DisplayName}: $($_.Exception.Message)"
        }
    }
}

function Get-WindowsVersionInfo {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        return [pscustomobject]@{
            Caption      = $os.Caption
            Version      = $os.Version
            BuildNumber  = $os.BuildNumber
            Architecture = $os.OSArchitecture
        }
    }
    catch {
        Write-Verbose "Could not query Win32_OperatingSystem: $($_.Exception.Message)"
        return [pscustomobject]@{
            Caption      = 'Unknown'
            Version      = 'Unknown'
            BuildNumber  = 'Unknown'
            Architecture = 'Unknown'
        }
    }
}
