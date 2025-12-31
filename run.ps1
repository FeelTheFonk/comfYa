# comfYa Launcher - PowerShell
<#
.SYNOPSIS
    Launcher for ComfyUI with comfYa optimizations.
.PARAMETER Help
    Show help and exit.
.PARAMETER Version
    Show version and exit.
.PARAMETER Mode
    Launch mode (Default, HighVram, LowVram, Cpu). Defaults to HighVram.
#>
[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$Version,
    [ValidateSet("Default", "HighVram", "LowVram", "Cpu")]
    [string]$Mode = "HighVram"
)

$ErrorActionPreference = 'Stop'

# Dynamic path resolution
$InstallPath = if ($env:COMFYUI_HOME) { $env:COMFYUI_HOME } else { $PSScriptRoot }
$configPath = Join-Path $InstallPath "config.psd1"

if ($Help) {
    Write-Host "comfYa Launcher" -ForegroundColor Cyan
    Write-Host "Usage: .\run.ps1 [-Mode <String>] [-Version] [-Help]"
    Write-Host "Modes: Default, HighVram, LowVram, Cpu"
    exit 0
}

if ($Version) {
    if (Test-Path $configPath) {
        $config = Import-PowerShellDataFile -Path $configPath
        Write-Host "comfYa version: $($config.Version)" -ForegroundColor Cyan
    } else {
        Write-Host "comfYa version: unknown"
    }
    exit 0
}

if (-not (Test-Path (Join-Path $InstallPath ".venv"))) {
    Write-Host "ERROR: Virtual environment not found. Run install.ps1 first." -ForegroundColor Red
    exit 1
}

Set-Location $InstallPath
& ".venv\Scripts\Activate.ps1"

# Load environment from config
if (Test-Path $configPath) {
    $config = Import-PowerShellDataFile -Path $configPath
    foreach ($key in $config.Environment.Keys) {
        $value = $config.Environment[$key] -replace '\{InstallPath\}', $InstallPath
        Set-Item -Path "env:$key" -Value $value
    }
} else {
    $env:CUDA_MODULE_LOADING = "LAZY"
    $env:PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True"
    $env:TRITON_CACHE_DIR = Join-Path $InstallPath ".triton_cache"
    $env:TORCH_COMPILE_BACKEND = "inductor"
}

Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║        comfYa - Starting             ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "  Mode: $Mode" -ForegroundColor Gray
Write-Host ""

# Load launch args
$launchArgs = @("ComfyUI\main.py")
if (Test-Path $configPath) {
    $launchArgs += $config.LaunchArgs[$Mode]
} else {
    $launchArgs += @("--fast", "--highvram", "--use-sage-attention")
}

python @launchArgs
