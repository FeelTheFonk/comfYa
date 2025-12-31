# comfYa - Unified Orchestrator CLI (v0.2.0)
# Professional management for peak hardware performance

#Requires -Version 5.1

param(
    [Parameter(Position=0)]
    [ValidateSet("setup", "run", "doctor", "update")]
    [string]$Command = "run",
    
    [string]$InstallHome,
    [switch]$Force,
    [switch]$NonInteractive,
    
    # Run specific params
    [ValidateSet("Auto", "Default", "HighVram", "LowVram", "Cpu")]
    [string]$Mode = "Auto"
)

# 1. Environment & Module Loading
$Root = $PSScriptRoot
$LibDir = Join-Path $Root "lib"

Import-Module (Join-Path $LibDir "Logging.psm1") -Force
Import-Module (Join-Path $LibDir "SystemUtils.psm1") -Force
Import-Module (Join-Path $LibDir "Nvidia.psm1") -Force
Import-Module (Join-Path $LibDir "Package.psm1") -Force
Import-Module (Join-Path $LibDir "Lifecycle.psm1") -Force

# 2. Configuration Initialization
try {
    $Config = Import-PowerShellDataFile -Path (Join-Path $Root "config.psd1")
    $InstallPath = if ($InstallHome) { $InstallHome } else { 
        if ($env:COMFYUI_HOME) { $env:COMFYUI_HOME } else { $Root }
    }
    
    Initialize-Logging -Config $Config -InstallPath $InstallPath
    Export-ComfyConfig -Config $Config -InstallPath $InstallPath
    Show-ComfyHeader -Version $Config.Version
}
catch {
    Write-Error "Critical Failure: Could not load configuration. $_"
    exit 1
}

# 3. Command Logic
switch ($Command) {
    "setup" {
        Write-Step "Bootstrap" "System" "Starting installation at $InstallPath"
        
        if (-not (Test-Administrator)) {
            Invoke-ElevatedRestart -ScriptPath $PSCommandPath -Parameters @{ Command = "setup"; InstallHome = $InstallPath }
            exit
        }
        
        # Base Requirements & Dependencies
        Test-SystemRequirement | Out-Null
        Install-VCRedist -Config $Config
        Install-Git
        Install-Uv -Config $Config
        Update-EnvironmentPath
        
        # Lifecycle Execution
        Install-ComfyProject -Config $Config -InstallPath $InstallPath
    }
    
    "run" {
        Start-ComfyProject -Config $Config -InstallPath $InstallPath -Mode $Mode
    }
    
    "doctor" {
        Write-Step "Diagnostics" "Check" "Running deep system validation..."
        
        Test-PowerShellVersion
        Test-SystemRequirement | Out-Null
        
        # GPU Diagnostics
        try {
            $gpu = Get-NvidiaGpuInfo -Config $Config
            Write-Success "GPU Detected: $($gpu.Name) (CUDA: $($gpu.CudaVersion))"
        }
        catch {
            Write-Fatal "GPU Diagnostics failed" -Suggestion "Ensure NVIDIA drivers are installed and nvidia-smi works."
        }
        
        # Environment Validation
        $VenvPython = Join-Path $InstallPath ".venv\Scripts\python.exe"
        if (Test-Path $VenvPython) {
            & $VenvPython (Join-Path $Root "validate.py") --path $InstallPath
        } else {
            Write-ComfyWarning "Virtual environment not found."
        }
        
        # Self-Healing
        if (-not $NonInteractive) {
            $answer = Read-Host "Would you like to run environment self-healing? (y/N)"
            if ($answer -match "y") {
                Repair-Environment -Config $Config -InstallPath $InstallPath -Force:$Force
            }
        }
    }
    
    "update" {
        Update-ComfyProject -Config $Config -InstallPath $InstallPath
    }
}

