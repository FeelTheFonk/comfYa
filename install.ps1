# comfYa - Core Installer Logic (v0.2.0)

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$Home,
    [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$LibDir = Join-Path $Root "lib"

# 1. Imports
Import-Module (Join-Path $LibDir "Logging.psm1") -Force
Import-Module (Join-Path $LibDir "SystemUtils.psm1") -Force
Import-Module (Join-Path $LibDir "Nvidia.psm1") -Force
Import-Module (Join-Path $LibDir "Package.psm1") -Force

# 2. Config & State
$Config = Import-PowerShellDataFile -Path (Join-Path $Root "config.psd1")
$InstallPath = if ($Home) { $Home } else { $Root }
$GPU = Get-NvidiaGpuInfo -Config $Config

# 3. Phase 2: Python Env Initialization
Write-Step "Install" "Env" "Initializing professional directory structure"
$dirs = $Config.Directories
$PathsToCreate = @($InstallPath)
foreach($d in $dirs.Values) {
    if ($d -is [hashtable]) {
        foreach($sd in $d.Values) { $PathsToCreate += Join-Path $InstallPath $sd }
    } else {
        $PathsToCreate += Join-Path $InstallPath $d
    }
}
foreach($p in $PathsToCreate) { New-Item -ItemType Directory -Force -Path $p | Out-Null }

Write-Step "Install" "Python" "Managing standalone Python $($Config.Python.Version)"
& uv python install $Config.Python.Version
& uv venv (Join-Path $InstallPath ".venv") --python $Config.Python.Version
$VenvPython = Join-Path $InstallPath ".venv\Scripts\python.exe"

# 4. Phase 3: Acceleration Stack
Write-Step "Install" "PyTorch" "Installing Nightly Optimized for $($GPU.CudaVersion)"
$IndexUrl = $Config.Sources.PyTorch.IndexUrls[$GPU.CudaVersion]
& uv pip install --pre torch torchvision torchaudio --index-url $IndexUrl --python $VenvPython

Write-Step "Install" "Optim" "Injecting Triton and Optimization Stack"
& uv pip install @($Config.Packages.Optimization) --python $VenvPython

# SageAttention (Auto-detection)
$PyVerShort = $Config.Python.Version -replace '\.', ''
$SageKey = "$($GPU.CudaVersion)_py$PyVerShort"
$SageUrl = $Config.Sources.FallbackWheels.SageAttention[$SageKey]
if ($SageUrl) {
    Write-Log "Injecting SageAttention via SOTA wheel: $SageKey" -Level VERBOSE
    & uv pip install $SageUrl --python $VenvPython
}

# 5. Phase 4: Application
Write-Step "Install" "App" "Cloning ComfyUI Core"
Set-Location $InstallPath
$AppPath = Join-Path $InstallPath "ComfyUI"
if (-not (Test-Path $AppPath)) {
    & git clone --depth 1 $Config.Sources.Repositories.ComfyUI $AppPath
}
& uv pip install -r (Join-Path $AppPath "requirements.txt") --python $VenvPython

# 6. Finalization
Write-Step "Install" "Final" "Configuring environment variables"
foreach ($key in $Config.Environment.Keys) {
    $val = $Config.Environment[$key] -replace '\{InstallPath\}', $InstallPath
    [Environment]::SetEnvironmentVariable($key, $val, "User")
}

if (-not $SkipValidation) {
    & $VenvPython (Join-Path $Root "validate.py")
}

Write-Success "comfYa v0.2.0 - Installation Complete."
