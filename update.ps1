# comfYa - Update Manager (v0.2.0)
# Proactive maintenance and SOTA synchronization

#Requires -Version 5.1

[CmdletBinding()]
param([string]$Home)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$LibDir = Join-Path $Root "lib"

# 1. Imports
Import-Module (Join-Path $LibDir "Logging.psm1") -Force
Import-Module (Join-Path $LibDir "SystemUtils.psm1") -Force
Import-Module (Join-Path $LibDir "Nvidia.psm1") -Force

# 2. Config & Path Resolution
$Config = Import-PowerShellDataFile -Path (Join-Path $Root "config.psd1")
$InstallPath = if ($Home) { $Home } else { 
    if ($env:COMFYUI_HOME) { $env:COMFYUI_HOME } else { $Root }
}
Set-Location $InstallPath
$PythonExe = Join-Path $InstallPath ".venv\Scripts\python.exe"

Write-Step "Update" "Init" "Synchronizing with SOTA repositories..."

# 3. Repository Updates
$Repos = @{
    "ComfyUI Core"    = @{ Path = "ComfyUI"; Branch = "master" }
    "ComfyUI Manager" = @{ Path = "ComfyUI\custom_nodes\ComfyUI-Manager"; Branch = "main" }
}

foreach ($name in $Repos.Keys) {
    $r = $Repos[$name]
    if (Test-Path $r.Path) {
        Write-Log "Updating $name..." -Level VERBOSE
        Push-Location $r.Path
        & git fetch origin
        & git reset --hard "origin/$($r.Branch)"
        Pop-Location
    }
}

# 4. Dependency Alignment
Write-Step "Update" "Deps" "Aligning dependencies via uv"
& uv pip install -r ComfyUI\requirements.txt --python $PythonExe

# Optimization Stack
Write-Log "Enforcing Optimization Stack (Triton, TorchAO)..." -Level VERBOSE
& uv pip install --upgrade @($Config.Packages.Optimization) --python $PythonExe

# 5. SageAttention Check
try {
    Write-Log "Checking for SageAttention updates..." -Level VERBOSE
    $GPU = Get-NvidiaGpuInfo -Config $Config
    $PyVerShort = $Config.Python.Version -replace '\.', ''
    $SageKey = "$($GPU.CudaVersion)_py$PyVerShort"
    $SageUrl = $Config.Sources.FallbackWheels.SageAttention[$SageKey]
    if ($SageUrl) {
        & uv pip install --upgrade $SageUrl --python $PythonExe
    }
} catch {
    Write-Log "SageAttention update skipped (Non-critical)" -Level WARN
}

Write-Success "comfYa v0.2.0 - All components synchronized."
