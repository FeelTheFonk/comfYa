# comfYa - Core Library
# Common functions and utilities

#Requires -Version 5.1

#region Configuration Loading

function Get-ComfyConfig {
    <#
    .SYNOPSIS
        Loads the centralized configuration with environment override support.
    .DESCRIPTION
        Hierarchy: Environment Variables > Local config.psd1 > Defaults
    .OUTPUTS
        Hashtable containing merged configuration.
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath
    )
    
    # Determine config path
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $PSScriptRoot "..\config.psd1"
    }
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    
    # Load base configuration
    $config = Import-PowerShellDataFile -Path $ConfigPath
    
    # Apply environment overrides
    if ($env:COMFYUI_PYTHON_VERSION) {
        $config.Python.Version = $env:COMFYUI_PYTHON_VERSION
    }
    if ($env:COMFYUI_CUDA_VERSION) {
        $config.Cuda.PreferredVersion = $env:COMFYUI_CUDA_VERSION
    }
    
    return $config
}

function Get-InstallPath {
    <#
    .SYNOPSIS
        Resolves the installation path dynamically.
    .DESCRIPTION
        Priority: $env:COMFYUI_HOME > Script parent directory > Prompt user
    #>
    [CmdletBinding()]
    param(
        [string]$ProvidedPath,
        [switch]$NonInteractive
    )
    
    # 1. Parameter override
    if ($ProvidedPath -and $ProvidedPath -ne "") {
        return Resolve-Path -Path $ProvidedPath -ErrorAction SilentlyContinue | 
               Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
    }
    
    # 2. Environment variable
    if ($env:COMFYUI_HOME) {
        return $env:COMFYUI_HOME
    }
    
    # 3. Script parent directory (standard deployment)
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $parentPath = Split-Path $scriptRoot -Parent
    
    # If running from within the project
    if (Test-Path (Join-Path $scriptRoot "ComfyUI")) {
        return $scriptRoot
    }
    if (Test-Path (Join-Path $parentPath "ComfyUI")) {
        return $parentPath
    }
    
    # 4. Interactive prompt or default
    if (-not $NonInteractive) {
        $defaultPath = Join-Path $scriptRoot "ComfyUI"
        return $defaultPath
    }
    
    return $scriptRoot
}

#endregion

#region Logging

$Script:LogLevel = @{
    DEBUG = 0
    INFO  = 1
    WARN  = 2
    ERROR = 3
}

$Script:LogConfig = @{
    Level       = "INFO"
    FileEnabled = $false
    FilePath    = $null
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize the logging subsystem.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",
        [string]$LogDirectory,
        [string]$LogFileName = "comfyui-installer.log"
    )
    
    $Script:LogConfig.Level = $Level
    
    if ($LogDirectory) {
        New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
        $Script:LogConfig.FilePath = Join-Path $LogDirectory $LogFileName
        $Script:LogConfig.FileEnabled = $true
        
        # Rotate logs if needed
        if (Test-Path $Script:LogConfig.FilePath) {
            $logFile = Get-Item $Script:LogConfig.FilePath
            if ($logFile.Length -gt 10MB) {
                $archiveName = $LogFileName -replace '\.log$', "-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
                Move-Item $Script:LogConfig.FilePath (Join-Path $LogDirectory $archiveName) -Force
            }
        }
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Unified logging function with file and console output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",
        
        [string]$Phase,
        [string]$Step
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $prefix = if ($Phase -and $Step) { "[$Phase.$Step]" } elseif ($Phase) { "[$Phase]" } else { "" }
    
    # Check log level threshold
    if ($Script:LogLevel[$Level] -lt $Script:LogLevel[$Script:LogConfig.Level]) {
        return
    }
    
    # Console output with colors
    $color = switch ($Level) {
        "DEBUG" { "DarkGray" }
        "INFO"  { "White" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
    }
    
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
    if ($prefix) {
        Write-Host "$prefix " -NoNewline -ForegroundColor Cyan
    }
    Write-Host $Message -ForegroundColor $color
    
    # File output
    if ($Script:LogConfig.FileEnabled -and $Script:LogConfig.FilePath) {
        $logLine = "[$timestamp] [$Level] $prefix $Message"
        Add-Content -Path $Script:LogConfig.FilePath -Value $logLine -Encoding UTF8
    }
}

function Write-Step {
    [CmdletBinding()]
    param(
        [string]$Phase,
        [string]$Step, 
        [string]$Message
    )
    Write-Log -Message $Message -Level INFO -Phase $Phase -Step $Step
}

function Write-Success {
    [CmdletBinding()]
    param([string]$Message)
    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
    Write-Host $Message -ForegroundColor Gray
    Write-Log -Message "SUCCESS: $Message" -Level DEBUG
}

function Write-Warning2 {
    [CmdletBinding()]
    param([string]$Message)
    Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor Gray
    Write-Log -Message "WARNING: $Message" -Level WARN
}

function Write-Fatal {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Suggestion
    )
    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
    if ($Suggestion) {
        Write-Host "    → " -NoNewline -ForegroundColor DarkYellow
        Write-Host $Suggestion -ForegroundColor DarkYellow
    }
    Write-Log -Message "FATAL: $Message" -Level ERROR
    throw $Message
}

#endregion

#region System Utilities

function Test-Administrator {
    <#
    .SYNOPSIS
        Check if running with administrator privileges.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-ElevatedRestart {
    <#
    .SYNOPSIS
        Restart script with elevated privileges if needed.
    #>
    [CmdletBinding()]
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters
    )
    
    if (Test-Administrator) {
        return $false # Already admin
    }
    
    Write-Warning2 "Restarting with administrator privileges..."
    
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")
    foreach ($key in $Parameters.Keys) {
        $argList += "-$key"
        $argList += "`"$($Parameters[$key])`""
    }
    
    Start-Process pwsh -Verb RunAs -ArgumentList $argList
    return $true
}

function Update-EnvironmentPath {
    <#
    .SYNOPSIS
        Refresh PATH from registry without requiring restart.
    #>
    [CmdletBinding()]
    param()
    
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Invoke-SafeWebRequest {
    <#
    .SYNOPSIS
        Secure web request with TLS enforcement and error handling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        
        [string]$OutFile,
        
        [hashtable]$Headers = @{ "User-Agent" = "comfYa/0.1.0" },
        
        [int]$TimeoutSec = 60,
        
        [int]$RetryCount = 3
    )
    
    # Enforce TLS 1.2+
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    
    $attempt = 0
    while ($attempt -lt $RetryCount) {
        try {
            $params = @{
                Uri             = $Uri
                Headers         = $Headers
                UseBasicParsing = $true
                TimeoutSec      = $TimeoutSec
                ErrorAction     = 'Stop'
            }
            
            if ($OutFile) {
                $params.OutFile = $OutFile
                Invoke-WebRequest @params
                return $true
            } else {
                return Invoke-WebRequest @params
            }
        }
        catch {
            $attempt++
            if ($attempt -ge $RetryCount) {
                throw "Failed to download from $Uri after $RetryCount attempts: $_"
            }
            Write-Warning2 "Download attempt $attempt failed, retrying..."
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

#endregion

#region NVIDIA Utilities

function Get-NvidiaGpuInfo {
    <#
    .SYNOPSIS
        Detect NVIDIA GPU information using nvidia-smi.
    .OUTPUTS
        Hashtable with GpuName, DriverVersion, ComputeCapability, CudaVersion, SmArch
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Config
    )
    
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvidiaSmi) {
        throw "nvidia-smi not found. Install NVIDIA driver."
    }
    
    $output = & nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader,nounits 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "nvidia-smi failed: $output"
    }
    
    $parts = $output -split ','
    $gpuName = $parts[0].Trim()
    $driverVersion = $parts[1].Trim()
    $computeCap = $parts[2].Trim()
    $ccFloat = [float]$computeCap
    
    # Validate compute capability
    $minCC = if ($Config) { $Config.Gpu.MinComputeCapability } else { 7.5 }
    if ($ccFloat -lt $minCC) {
        throw "Compute capability $computeCap < $minCC. Upgrade GPU required."
    }
    
    # Determine SM architecture
    $smArch = "sm75"  # Default
    if ($Config -and $Config.Gpu.SmArchMapping) {
        foreach ($key in ($Config.Gpu.SmArchMapping.Keys | Sort-Object -Descending)) {
            if ($ccFloat -ge [float]$key) {
                $smArch = $Config.Gpu.SmArchMapping[$key]
                break
            }
        }
    } else {
        if ($ccFloat -ge 12.0)     { $smArch = "sm120" }
        elseif ($ccFloat -ge 10.0) { $smArch = "sm100" }
        elseif ($ccFloat -ge 8.9)  { $smArch = "sm89" }
        elseif ($ccFloat -ge 8.6)  { $smArch = "sm86" }
        elseif ($ccFloat -ge 8.0)  { $smArch = "sm80" }
    }
    
    # Determine CUDA version from driver
    $driverMajor = [int]($driverVersion -split '\.')[0]
    $cudaVersion = "cu121"  # Default
    
    if ($Config -and $Config.Cuda.DriverMapping) {
        foreach ($minDriver in ($Config.Cuda.DriverMapping.Keys | Sort-Object -Descending)) {
            if ($driverMajor -ge [int]$minDriver) {
                $cudaVersion = $Config.Cuda.DriverMapping[[int]$minDriver]
                break
            }
        }
    } else {
        if ($driverMajor -ge 570)     { $cudaVersion = "cu128" }
        elseif ($driverMajor -ge 560) { $cudaVersion = "cu124" }
        elseif ($driverMajor -ge 545) { $cudaVersion = "cu121" }
    }
    
    return @{
        GpuName           = $gpuName
        DriverVersion     = $driverVersion
        ComputeCapability = $computeCap
        CudaVersion       = $cudaVersion
        SmArch            = $smArch
    }
}

#endregion

#region Package Management

function Install-VCRedist {
    <#
    .SYNOPSIS
        Install Visual C++ Redistributable if not present.
    #>
    [CmdletBinding()]
    param(
        [string]$DownloadUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    )
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    
    if (Test-Path $regPath) {
        $reg = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if ($reg.Installed -eq 1 -and $reg.Major -ge 14) {
            Write-Success "VC++ Redistributable already installed (v$($reg.Major).$($reg.Minor))"
            return $true
        }
    }
    
    Write-Warning2 "Installing VC++ Redistributable..."
    $tempPath = Join-Path $env:TEMP "vc_redist.x64.exe"
    
    try {
        Invoke-SafeWebRequest -Uri $DownloadUrl -OutFile $tempPath
        $proc = Start-Process -FilePath $tempPath -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
        
        if ($proc.ExitCode -notin @(0, 3010)) {
            throw "Installation failed with code $($proc.ExitCode)"
        }
        
        Write-Success "VC++ Redistributable installed"
        return $true
    }
    finally {
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    }
}

function Install-Git {
    <#
    .SYNOPSIS
        Ensure Git is available, install via winget if needed.
    #>
    [CmdletBinding()]
    param()
    
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $version = & git --version
        Write-Success "Git present: $version"
        return $true
    }
    
    Write-Warning2 "Installing Git via winget..."
    $result = & winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements 2>&1
    
    Update-EnvironmentPath
    
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        throw "Git installation failed"
    }
    
    Write-Success "Git installed"
    return $true
}

function Install-Uv {
    <#
    .SYNOPSIS
        Ensure uv package manager is available.
    #>
    [CmdletBinding()]
    param(
        [string]$InstallerUrl = "https://astral.sh/uv/install.ps1"
    )
    
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if ($uv) {
        $version = & uv --version
        Write-Success "uv present: $version"
        return $true
    }
    
    Write-Warning2 "Installing uv..."
    
    # Download installer to temp file (secure: no Invoke-Expression on web content)
    $installerPath = Join-Path $env:TEMP "uv-install.ps1"
    Invoke-SafeWebRequest -Uri $InstallerUrl -OutFile $installerPath
    
    # Execute downloaded script
    & $installerPath
    
    # Cleanup
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    
    Update-EnvironmentPath
    
    # Also add typical uv path
    $uvPath = Join-Path $env:USERPROFILE ".local\bin"
    if ($uvPath -notin ($env:Path -split ';')) {
        $env:Path = "$uvPath;$env:Path"
    }
    
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) {
        throw "uv installation failed"
    }
    
    Write-Success "uv installed"
    return $true
}

#endregion

# Export all public functions
Export-ModuleMember -Function @(
    'Get-ComfyConfig'
    'Get-InstallPath'
    'Initialize-Logging'
    'Write-Log'
    'Write-Step'
    'Write-Success'
    'Write-Warning2'
    'Write-Fatal'
    'Test-Administrator'
    'Invoke-ElevatedRestart'
    'Update-EnvironmentPath'
    'Invoke-SafeWebRequest'
    'Get-NvidiaGpuInfo'
    'Install-VCRedist'
    'Install-Git'
    'Install-Uv'
)
