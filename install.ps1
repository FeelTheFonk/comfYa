#Requires -Version 5.1
<#
.SYNOPSIS
    comfYa - ComfyUI Automated Installer for Windows NVIDIA
.DESCRIPTION
    Fully automated installation of ComfyUI with performance optimizations.
    Targets: Windows 10/11, RTX 20xx+, Python 3.12, PyTorch Nightly, Triton, SageAttention
.NOTES
    Run as administrator for system dependencies.
    No interaction required.
.PARAMETER InstallPath
    Installation directory. Defaults to $env:COMFYUI_HOME or script directory.
.PARAMETER SkipValidation
    Skip post-installation validation tests.
.PARAMETER ConfigFile
    Path to custom configuration file.
#>

[CmdletBinding()]
param(
    [string]$InstallPath,
    [switch]$SkipValidation,
    [string]$ConfigFile
)

#region Initialization
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Import core module (required)
$libPath = Join-Path $PSScriptRoot "lib\core.psm1"
if (-not (Test-Path $libPath)) {
    Write-Host "FATAL: lib/core.psm1 not found. Ensure complete installation." -ForegroundColor Red
    exit 1
}
Import-Module $libPath -Force -DisableNameChecking

# Load configuration
$configPath = if ($ConfigFile) { $ConfigFile } else { Join-Path $PSScriptRoot "config.psd1" }
if (Test-Path $configPath) {
    $Script:Config = Import-PowerShellDataFile -Path $configPath
} else {
    Write-Host "FATAL: config.psd1 not found. Ensure complete installation." -ForegroundColor Red
    exit 1
}

# Resolve install path dynamically
if (-not $InstallPath -or $InstallPath -eq "") {
    if ($env:COMFYUI_HOME -and $env:COMFYUI_HOME -ne "") {
        $InstallPath = $env:COMFYUI_HOME
    } elseif (Test-Path (Join-Path $PSScriptRoot "ComfyUI")) {
        $InstallPath = $PSScriptRoot
    } else {
        $InstallPath = $PSScriptRoot
    }
}

$Script:State = @{
    CudaVersion   = $null
    SmArch        = $null
    GpuName       = $null
    DriverVersion = $null
    InstallPath   = $InstallPath
}

# Initialize logging
$logDir = Join-Path $InstallPath "logs"
$logLevel = if ($PSBoundParameters.ContainsKey('Verbose')) { "DEBUG" } else { "INFO" }
Initialize-Logging -Level $logLevel -LogDirectory $logDir -LogFileName "install.log"
#endregion

# Get User-Agent from config
$Script:UserAgent = if ($Script:Config.UserAgent) { $Script:Config.UserAgent } else { "comfYa/0.1.0" }

#region Phase 1: System Bootstrap
function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-ElevatedRestart {
    if (-not (Test-Administrator)) {
        Write-Warning2 "Restarting with administrator privileges..."
        $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.ScriptName }
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"")
        if ($InstallPath) { $argList += @("-InstallPath", "`"$InstallPath`"") }
        if ($SkipValidation) { $argList += "-SkipValidation" }
        Start-Process pwsh -Verb RunAs -ArgumentList $argList
        exit
    }
}

function Get-NvidiaGpuInfo {
    Write-Step "1" "2" "NVIDIA GPU Detection"
    
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvidiaSmi) {
        Write-Fatal "nvidia-smi not found" "Install NVIDIA driver from nvidia.com/drivers"
    }
    
    $output = & nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader,nounits 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fatal "nvidia-smi failed: $output"
    }
    
    $parts = $output -split ','
    $Script:State.GpuName = $parts[0].Trim()
    $Script:State.DriverVersion = $parts[1].Trim()
    $computeCap = $parts[2].Trim()
    
    Write-Success "GPU: $($Script:State.GpuName)"
    Write-Success "Driver: $($Script:State.DriverVersion)"
    Write-Success "Compute Capability: $computeCap"
    
    $ccFloat = [float]$computeCap
    $minCC = $Script:Config.Gpu.MinComputeCapability
    if ($ccFloat -lt $minCC) {
        Write-Fatal "Compute capability $computeCap < $minCC" "GPU with CC $minCC+ required (RTX 20xx or newer)"
    }
    
    # Determine SM architecture
    $smMapping = @{
        12.0 = "sm120"; 10.0 = "sm100"; 8.9 = "sm89"
        8.6 = "sm86"; 8.0 = "sm80"; 7.5 = "sm75"
    }
    foreach ($threshold in ($smMapping.Keys | Sort-Object -Descending)) {
        if ($ccFloat -ge $threshold) {
            $Script:State.SmArch = $smMapping[$threshold]
            break
        }
    }
    Write-Success "Architecture: $($Script:State.SmArch)"
    
    # Map driver to CUDA version
    $driverMajor = [int]($Script:State.DriverVersion -split '\.')[0]
    $driverMapping = $Script:Config.Cuda.DriverMapping
    foreach ($minDriver in ($driverMapping.Keys | Sort-Object -Descending)) {
        if ($driverMajor -ge [int]$minDriver) {
            $Script:State.CudaVersion = $driverMapping[[int]$minDriver]
            break
        }
    }
    if (-not $Script:State.CudaVersion) {
        $Script:State.CudaVersion = "cu121"
    }
    Write-Success "Target CUDA: $($Script:State.CudaVersion)"
}

function Install-VCRedist {
    Write-Step "1" "3" "Visual C++ Redistributable Check"
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    
    if (Test-Path $regPath) {
        $reg = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if ($reg.Installed -eq 1 -and $reg.Major -ge 14) {
            Write-Success "VC++ Redistributable already installed (v$($reg.Major))"
            return
        }
    }
    
    Write-Warning2 "Installing VC++ Redistributable..."
    $tempPath = Join-Path $env:TEMP "vc_redist.x64.exe"
    $vcUrl = $Script:Config.Sources.Dependencies.VCRedist
    
    Invoke-SafeWebRequest -Uri $vcUrl -OutFile $tempPath
    $proc = Start-Process -FilePath $tempPath -ArgumentList "/install","/quiet","/norestart" -Wait -PassThru
    
    if ($proc.ExitCode -notin @(0, 3010)) {
        Write-Fatal "VC++ Redistributable installation failed (code: $($proc.ExitCode))"
    }
    
    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    Write-Success "VC++ Redistributable installed"
}

function Install-Git {
    Write-Step "1" "4" "Git Check"
    
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $version = & git --version
        Write-Success "Git present: $version"
        return
    }
    
    Write-Warning2 "Installing Git via winget..."
    & winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
    
    # Refresh PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Fatal "Git installation failed" "Install Git manually from git-scm.com"
    }
    Write-Success "Git installed"
}

function Install-Uv {
    Write-Step "1" "5" "uv Package Manager Check"
    
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if ($uv) {
        $version = & uv --version
        Write-Success "uv present: $version"
        return
    }
    
    Write-Warning2 "Installing uv..."
    $uvUrl = $Script:Config.Sources.Dependencies.Uv
    
    # Use safe web request
    $installerContent = (Invoke-SafeWebRequest -Uri $uvUrl).Content
    Invoke-Expression $installerContent
    
    # Refresh PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    $uvPath = Join-Path $env:USERPROFILE ".local\bin"
    if ($uvPath -notin ($env:Path -split ';')) {
        $env:Path = "$uvPath;$env:Path"
    }
    
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) {
        Write-Fatal "uv installation failed" "Install uv manually: irm https://astral.sh/uv/install.ps1 | iex"
    }
    Write-Success "uv installed"
}

function Set-DefenderExclusion {
    Write-Step "1" "6" "Windows Defender Configuration"
    
    try {
        Add-MpPreference -ExclusionPath $Script:State.InstallPath -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionProcess "python.exe" -ErrorAction SilentlyContinue
        Write-Success "Defender exclusions configured"
    } catch {
        Write-Warning2 "Unable to configure Defender (non-critical)"
    }
}
#endregion

#region Phase 2: Python Environment
function New-DirectoryStructure {
    Write-Step "2" "1" "Creating directory structure"
    
    $installPath = $Script:State.InstallPath
    
    # Build directory list from config
    $dirs = @($installPath)
    $dirConfig = $Script:Config.Directories
    
    # Models directories
    foreach ($key in $dirConfig.Models.Keys) {
        $dirs += Join-Path $installPath $dirConfig.Models[$key]
    }
    
    # Other directories
    $dirs += Join-Path $installPath $dirConfig.Output
    $dirs += Join-Path $installPath $dirConfig.Input
    $dirs += Join-Path $installPath $dirConfig.Logs
    $dirs += Join-Path $installPath $dirConfig.TritonCache
    
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    
    Set-Location $installPath
    Write-Success "Structure created: $installPath"
}

function Install-Python {
    Write-Step "2" "2" "Python Installation"
    
    $pyVersion = $Script:Config.Python.Version
    & uv python install $pyVersion
    if ($LASTEXITCODE -ne 0) {
        Write-Fatal "Python $pyVersion installation failed"
    }
    
    $pythonList = & uv python list --installed
    if ($pythonList -notmatch $pyVersion.Replace(".", "\.")) {
        Write-Fatal "Python $pyVersion not found after installation"
    }
    Write-Success "Python $pyVersion installed"
}

function New-VirtualEnv {
    Write-Step "2" "3" "Virtual environment creation"
    
    $pyVersion = $Script:Config.Python.Version
    & uv venv .venv --python $pyVersion
    if ($LASTEXITCODE -ne 0) {
        Write-Fatal "Virtual environment creation failed"
    }
    
    & ".\.venv\Scripts\Activate.ps1"
    
    $pyVersion = & python --version
    Write-Success "Venv activated: $pyVersion"
}

function Copy-PythonHeaders {
    Write-Step "2" "4" "Python headers configuration (Triton support)"
    
    $pyVersion = $Script:Config.Python.Version
    $pythonExe = & uv python find $pyVersion
    $pythonDir = Split-Path (Split-Path $pythonExe -Parent) -Parent
    
    $includeSource = Join-Path $pythonDir "include"
    $libsSource = Join-Path $pythonDir "libs"
    
    $includeDest = Join-Path $Script:State.InstallPath ".venv\include"
    $libsDest = Join-Path $Script:State.InstallPath ".venv\libs"
    
    if (Test-Path $includeSource) {
        New-Item -ItemType Directory -Force -Path $includeDest | Out-Null
        Copy-Item "$includeSource\*" $includeDest -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Python headers copied"
    } else {
        Write-Warning2 "Python headers not found (JIT compilation may fail)"
    }
    
    if (Test-Path $libsSource) {
        New-Item -ItemType Directory -Force -Path $libsDest | Out-Null
        Copy-Item "$libsSource\*" $libsDest -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Python libs copied"
    }
}
#endregion

#region Phase 3: Package Installation
function Install-PyTorchNightly {
    Write-Step "3" "1" "PyTorch Nightly Installation"
    
    $cudaVersion = $Script:State.CudaVersion
    $indexUrl = $Script:Config.Sources.PyTorch.IndexUrls[$cudaVersion]
    if (-not $indexUrl) {
        $indexUrl = "https://download.pytorch.org/whl/nightly/cu121"
    }
    
    Write-Success "Index: $indexUrl"
    
    & uv pip install --pre torch torchvision torchaudio --index-url $indexUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Warning2 "$cudaVersion failed, fallback to cu124..."
        $fallbackUrl = $Script:Config.Sources.PyTorch.IndexUrls["cu124"]
        & uv pip install --pre torch torchvision torchaudio --index-url $fallbackUrl
        if ($LASTEXITCODE -ne 0) {
            Write-Fatal "PyTorch installation failed"
        }
    }
    
    # Validation
    $check = & python -c "import torch; print(torch.cuda.is_available())" 2>&1
    if ($check -ne "True") {
        Write-Fatal "PyTorch CUDA not functional" "Verify NVIDIA driver and CUDA compatibility"
    }
    
    $torchVersion = & python -c "import torch; print(torch.__version__)"
    Write-Success "PyTorch installed: $torchVersion"
}

function Install-TritonWindows {
    Write-Step "3" "2" "Triton Windows Installation"
    
    & uv pip install triton-windows
    if ($LASTEXITCODE -ne 0) {
        Write-Fatal "triton-windows installation failed"
    }
    
    $check = & python -c "import triton; print(triton.__version__)" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning2 "Triton import failed (JIT compilation on first run)"
    } else {
        Write-Success "Triton installed: $check"
    }
}

function Install-SageAttention {
    Write-Step "3" "3" "SageAttention Installation"
    
    try {
        $headers = @{ "User-Agent" = "comfYa-Installer" }
        $apiUrl = $Script:Config.Sources.APIs.SageAttention
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 30 -ErrorAction Stop
        
        $cudaVersion = $Script:State.CudaVersion
        $pattern = "sageattention.*$cudaVersion.*cp312.*win_amd64\.whl"
        $asset = $release.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
        
        if ($asset) {
            $whlPath = Join-Path $env:TEMP $asset.name
            Invoke-SafeWebRequest -Uri $asset.browser_download_url -OutFile $whlPath
            & uv pip install $whlPath
            Remove-Item $whlPath -Force -ErrorAction SilentlyContinue
            Write-Success "SageAttention installed from release"
            return
        }
    } catch {
        Write-Warning2 "SageAttention API inaccessible, using fallback URL"
    }
    
    # Fallback
    $cudaVersion = $Script:State.CudaVersion
    $fallbackKey = "${cudaVersion}_py312"
    $fallbackUrl = $Script:Config.Sources.FallbackWheels.SageAttention[$fallbackKey]
    
    if (-not $fallbackUrl) {
        $fallbackUrl = $Script:Config.Sources.FallbackWheels.SageAttention["cu128_py312"]
    }
    
    $whlPath = Join-Path $env:TEMP "sageattention.whl"
    
    try {
        Invoke-SafeWebRequest -Uri $fallbackUrl -OutFile $whlPath
        & uv pip install $whlPath
        Remove-Item $whlPath -Force -ErrorAction SilentlyContinue
        Write-Success "SageAttention installed (fallback)"
    } catch {
        Write-Warning2 "SageAttention not installed (non-blocking)"
    }
}

function Install-OptionalPackages {
    Write-Step "3" "4" "Additional packages installation"
    
    # TorchAO
    & uv pip install torchao 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Success "torchao installed" }
    else { Write-Warning2 "torchao installation failed (non-critical)" }
    
    # xFormers
    & uv pip install xformers 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Success "xformers installed" }
    else { Write-Warning2 "xformers installation failed (non-critical)" }
    
    # Packages from config
    $allPackages = @()
    $allPackages += $Script:Config.Packages.Core
    $allPackages += $Script:Config.Packages.ML
    $allPackages += $Script:Config.Packages.Optional
    
    & uv pip install @allPackages
    Write-Success "Additional packages installed"
}
#endregion

#region Phase 4: ComfyUI
function Install-ComfyUI {
    Write-Step "4" "1" "ComfyUI Clone"
    
    $repoUrl = $Script:Config.Sources.Repositories.ComfyUI
    
    if (Test-Path "ComfyUI") {
        Write-Warning2 "ComfyUI exists, updating..."
        Push-Location ComfyUI
        & git fetch origin
        & git reset --hard origin/master
        Pop-Location
    } else {
        & git clone --depth 1 $repoUrl
    }
    
    if (-not (Test-Path "ComfyUI\main.py")) {
        Write-Fatal "ComfyUI clone failed"
    }
    Write-Success "ComfyUI ready"
}

function Install-ComfyUIRequirements {
    Write-Step "4" "2" "ComfyUI dependencies installation"
    
    $torchBefore = & python -c "import torch; print(torch.__version__)" 2>&1
    
    & uv pip install -r ComfyUI\requirements.txt
    
    $torchAfter = & python -c "import torch; print(torch.__version__)" 2>&1
    
    if ($torchBefore -ne $torchAfter -and $torchAfter -notmatch "dev") {
        Write-Warning2 "PyTorch downgrade detected, reinstalling Nightly..."
        Install-PyTorchNightly
    }
    
    Write-Success "ComfyUI dependencies installed"
}

function Install-ComfyUIManager {
    Write-Step "4" "3" "ComfyUI-Manager Installation"
    
    $managerPath = "ComfyUI\custom_nodes\ComfyUI-Manager"
    $repoUrl = $Script:Config.Sources.Repositories.ComfyUIManager
    
    if (Test-Path $managerPath) {
        Write-Warning2 "Manager exists, updating..."
        Push-Location $managerPath
        & git fetch origin
        & git reset --hard origin/main
        Pop-Location
    } else {
        & git clone --depth 1 $repoUrl $managerPath
    }
    
    if (-not (Test-Path "$managerPath\__init__.py")) {
        Write-Warning2 "ComfyUI-Manager installation incomplete"
    } else {
        Write-Success "ComfyUI-Manager ready"
    }
}
#endregion

#region Phase 5: Finalization
function Set-EnvironmentVariables {
    Write-Step "5" "1" "Environment configuration"
    
    # Set environment variables from config
    foreach ($key in $Script:Config.Environment.Keys) {
        $value = $Script:Config.Environment[$key]
        # Replace placeholder
        $value = $value -replace '\{InstallPath\}', $Script:State.InstallPath
        [Environment]::SetEnvironmentVariable($key, $value, "User")
    }
    
    Write-Success "Environment variables configured"
}

function Invoke-Validation {
    if ($SkipValidation) {
        Write-Warning2 "Validation skipped (-SkipValidation)"
        return
    }
    
    Write-Step "5" "2" "Installation validation"
    
    $validateScript = Join-Path $Script:State.InstallPath "validate.py"
    if (Test-Path $validateScript) {
        & python $validateScript
        if ($LASTEXITCODE -ne 0) {
            Write-Warning2 "Some validation tests failed"
        } else {
            Write-Success "Validation complete"
        }
    } else {
        Write-Warning2 "Validation script not found"
    }
}
#endregion

#region Main Execution
function Invoke-Installation {
    $startTime = Get-Date
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║     comfYa - ComfyUI Automated Installer                 ║" -ForegroundColor Magenta
    Write-Host "║     Windows NVIDIA Edition                               ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    
    # Phase 1
    Write-Host "═══ PHASE 1: System Bootstrap ═══" -ForegroundColor Yellow
    Invoke-ElevatedRestart
    Write-Step "1" "1" "Administrator privileges check"
    Write-Success "Running as administrator"
    Get-NvidiaGpuInfo
    Install-VCRedist
    Install-Git
    Install-Uv
    Set-DefenderExclusion
    
    # Phase 2
    Write-Host ""
    Write-Host "═══ PHASE 2: Python Environment ═══" -ForegroundColor Yellow
    New-DirectoryStructure
    Install-Python
    New-VirtualEnv
    Copy-PythonHeaders
    
    # Phase 3
    Write-Host ""
    Write-Host "═══ PHASE 3: Package Installation ═══" -ForegroundColor Yellow
    Install-PyTorchNightly
    Install-TritonWindows
    Install-SageAttention
    Install-OptionalPackages
    
    # Phase 4
    Write-Host ""
    Write-Host "═══ PHASE 4: ComfyUI ═══" -ForegroundColor Yellow
    Install-ComfyUI
    Install-ComfyUIRequirements
    Install-ComfyUIManager
    
    # Phase 5
    Write-Host ""
    Write-Host "═══ PHASE 5: Finalization ═══" -ForegroundColor Yellow
    Set-EnvironmentVariables
    Invoke-Validation
    
    # Summary
    $elapsed = (Get-Date) - $startTime
    $installPath = $Script:State.InstallPath
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║               Installation Complete                      ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Duration: $($elapsed.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host "  Location: $installPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Launch: .\run.bat or .\run.ps1" -ForegroundColor Cyan
    Write-Host "  Update: .\update.ps1" -ForegroundColor Cyan
    Write-Host ""
}

# Execution
try {
    Invoke-Installation
} catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
#endregion
