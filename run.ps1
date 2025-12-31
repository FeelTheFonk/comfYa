# comfYa - Smart Launcher (v0.2.0)
# Proactive performance management and VRAM-aware orchestration

#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet("Auto", "Default", "HighVram", "LowVram", "Cpu")]
    [string]$Mode = "Auto",
    [string]$Home
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$LibDir = Join-Path $Root "lib"

# 1. Imports
Import-Module (Join-Path $LibDir "Logging.psm1") -Force
Import-Module (Join-Path $LibDir "Nvidia.psm1") -Force

# 2. Config & Path Resolution
$Config = Import-PowerShellDataFile -Path (Join-Path $Root "config.psd1")
$InstallPath = if ($Home) { $Home } else { 
    if ($env:COMFYUI_HOME) { $env:COMFYUI_HOME } else { $Root }
}
Set-Location $InstallPath

# 3. Smart Mode Selection (SOTA UX)
if ($Mode -eq "Auto") {
    try {
        $totalVram = Get-NvidiaVram
        
        if ($totalVram -ge 12000) { $Mode = "HighVram" }
        elseif ($totalVram -ge 6000) { $Mode = "Default" }
        else { $Mode = "LowVram" }
        
        Write-Log "Auto-detected VRAM: ${totalVram}MB. Selecting mode: $Mode" -Level INFO
    }
    catch {
        Write-Log "GPU Detection failed for Auto mode, falling back to Default." -Level WARN
        $Mode = "Default"
    }
}

# 4. Preparation
if (-not (Test-Path (Join-Path $InstallPath ".venv"))) {
    Write-Fatal "Environment not found" -Suggestion "Run 'comfya setup' first."
}

# Environment Sync
foreach ($key in $Config.Environment.Keys) {
    Set-Item -Path "env:$key" -Value ($Config.Environment[$key] -replace '\{InstallPath\}', $InstallPath)
}

# 5. Launch
$MainScript = Join-Path $InstallPath "ComfyUI\main.py"
$PythonExe = Join-Path $InstallPath ".venv\Scripts\python.exe"
$Args = @($MainScript) + $Config.LaunchArgs[$Mode]

Write-Log "Launching comfYa [$Mode]..." -Level SUCCESS
& $PythonExe @Args
