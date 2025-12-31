# comfYa - Unified Orchestrator CLI (v0.2.0)
# Professional management for peak hardware performance

#Requires -Version 5.1

param(
    [Parameter(Position=0)]
    [ValidateSet("setup", "run", "doctor", "update")]
    [string]$Command = "run",
    
    [string]$Home,
    [switch]$Force,
    [switch]$NonInteractive
)

# 1. Environment & Module Loading
$Root = $PSScriptRoot
$LibDir = Join-Path $Root "lib"

Import-Module (Join-Path $LibDir "Logging.psm1") -Force
Import-Module (Join-Path $LibDir "SystemUtils.psm1") -Force
Import-Module (Join-Path $LibDir "Nvidia.psm1") -Force
Import-Module (Join-Path $LibDir "Package.psm1") -Force

# 2. Configuration Initialization
try {
    $Config = Import-PowerShellDataFile -Path (Join-Path $Root "config.psd1")
    $InstallPath = if ($Home) { $Home } else { 
        if ($env:COMFYUI_HOME) { $env:COMFYUI_HOME } else { $Root }
    }
    
    Initialize-Logging -Config $Config -InstallPath $InstallPath
}
catch {
    Write-Error "Critical Failure: Could not load configuration or logging. $_"
    exit 1
}

# 3. Command Logic
switch ($Command) {
    "setup" {
        Write-Step "Bootstrap" "System" "Starting installation at $InstallPath"
        
        # Admin check
        if (-not (Test-Administrator)) {
            Invoke-ElevatedRestart -ScriptPath $PSCommandPath -Parameters @{ Command = "setup"; Home = $InstallPath }
            exit
        }
        
        # Requirements
        $sys = Test-SystemRequirements -Config $Config
        Write-Log "System: $($sys.FreeDisk)GB free, $($sys.TotalRAM)GB RAM" -Level VERBOSE
        
        # Dependencies
        Install-VCRedist -Config $Config
        Install-Git
        Install-Uv -Config $Config
        
        Update-EnvironmentPath
        Write-Success "Base system ready."
        
        # Trigger actual install script (to be refactored next)
        & (Join-Path $Root "install.ps1") -Home $InstallPath
    }
    
    "run" {
        & (Join-Path $Root "run.ps1") -Home $InstallPath
    }
    
    "doctor" {
        Write-Step "Diagnostics" "Check" "Running deep system validation..."
        
        # Pre-flight
        Test-PowerShellVersion
        $sys = Test-SystemRequirements -Config $Config
        
        # Validation script
        python (Join-Path $Root "validate.py")
        
        # GPU Info
        try {
            $gpu = Get-NvidiaGpuInfo -Config $Config
            Write-Success "GPU Detected: $($gpu.Name) (CUDA: $($gpu.CudaVersion))"
        }
        catch {
            Write-Fatal "GPU Diagnostics failed" -Suggestion "Ensure NVIDIA drivers are installed and nvidia-smi works."
        }
        
        # Self-Healing prompt
        if (-not $NonInteractive) {
            $answer = Read-Host "Would you like to run environment self-healing? (y/N)"
            if ($answer -match "y") {
                Repair-Environment -Config $Config -InstallPath $InstallPath
            }
        }
    }
    
    "update" {
        & (Join-Path $Root "update.ps1")
    }
}
