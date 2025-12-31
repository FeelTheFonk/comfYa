# comfYa - Unified Orchestrator CLI (v0.2.3)
# Professional management for peak hardware performance

#Requires -Version 5.1

param(
    [Parameter(Position=0)]
    [ValidateSet("setup", "run", "doctor", "update", "clean")]
    [string]$Command = "run",
    
    [string]$InstallHome,
    [switch]$Force,
    [switch]$NonInteractive,
    [switch]$Simulate,
    
    # Run specific params
    [ValidateSet("Auto", "Default", "HighVram", "LowVram", "Cpu")]
    [string]$Mode = "Auto"
)

# 1. Module Loading
$Root = $PSScriptRoot
$LibDir = Join-Path $Root "lib"

try {
    Import-Module (Join-Path $LibDir "Logging.psm1") -Force
    Start-SandboxLogging # Early-stage capture
    
    Import-Module (Join-Path $LibDir "SystemUtils.psm1") -Force
    Import-Module (Join-Path $LibDir "Nvidia.psm1") -Force
    Import-Module (Join-Path $LibDir "Package.psm1") -Force
    Import-Module (Join-Path $LibDir "Lifecycle.psm1") -Force
} catch {
    Write-Error "Critical Failure: Could not load library modules."
    exit 1
}

# 2. Global Path Resolution (SOT)
$InstallPath = if ($InstallHome) { $InstallHome } 
               elseif ($env:COMFYUI_HOME) { $env:COMFYUI_HOME } 
               else { $Root }

# 3. Elevation & Post-Elevation Initialization
if ($Command -eq "setup" -and -not (Test-Administrator)) {
    Write-ComfyLog "Elevation required for installation. Restarting..." -Level WARN
    Invoke-ElevatedRestart -ScriptPath $PSCommandPath -Parameters @{ Command = "setup"; InstallHome = $InstallPath }
    exit
}

try {
    # Initialize session after elevation check to avoid dual-logging/sync
    $Config = Import-PowerShellDataFile -Path (Join-Path $Root "config.psd1")
    
    Initialize-Logging -Config $Config -InstallPath $InstallPath
    Export-ComfyConfig -Config $Config -InstallPath $InstallPath
    Show-ComfyHeader -Version $Config.Version
}
catch {
    Write-Fatal "Could not load configuration." -Suggestion "Check config.psd1 syntax."
}

# 3. Command Logic
switch ($Command) {
    "setup" {
        try {
            Write-Step "Bootstrap" "System" "Commencing Pinnacle Installation at: $InstallPath"
            
            # Base Requirements
            $SysInfo = Test-SystemRequirement -Config $Config
            Install-VCRedist -Config $Config
            Install-Git
            Install-Uv -Config $Config
            Update-EnvironmentPath
            
            # Lifecycle execution
            Install-ComfyProject -Config $Config -InstallPath $InstallPath -Simulate:$Simulate
        }
        finally {
            # [SOTA] Reliable Sanitation: Cleanup artifacts even on failure
            Invoke-PostInstallCleanup
            Show-ComfyFooter
        }
    }
    
    "run" {
        Start-ComfyProject -Config $Config -InstallPath $InstallPath -Mode $Mode
    }
    
    "doctor" {
        Write-Step "Diagnostics" "Check" "Running deep system validation..."
        
        try {
            Test-PowerShellVersion -Config $Config
            Write-Diagnostic "PowerShell" "OK" "$($PSVersionTable.PSVersion)"
        } catch {
            Write-Diagnostic "PowerShell" "FAIL" "$_"
        }

        $sys = Test-SystemRequirement -Config $Config
        Write-Diagnostic "Memory" "OK" "$($sys.TotalRAM) GB"
        Write-Diagnostic "Disk Space" "OK" "$($sys.FreeDisk) GB"
        
        # GPU Diagnostics
        try {
            $gpu = Get-NvidiaGpuInfo -Config $Config
            Write-Diagnostic "Hardware" "OK" "$($gpu.Name) [$($gpu.SmArch)]"
            Write-Diagnostic "Driver" "OK" "$($gpu.Driver)"
            Write-Diagnostic "CUDA Target" "OK" "$($gpu.CudaVersion)"
        }
        catch {
            Write-Diagnostic "GPU Intel" "FAIL" "$_"
            Write-ComfyWarning "Ensure NVIDIA drivers are installed and nvidia-smi works."
        }
        
        # [16] Doctor Depth: DLL Integrity Check
        Write-Step "Diagnostics" "DLL" "Verifying CUDA kernel libraries..."
        $cudaPath = $env:CUDA_PATH
        if ($cudaPath -and (Test-Path $cudaPath)) {
            $dlls = @("cudnn64_8.dll", "cublas64_11.dll")
            foreach ($dll in $dlls) {
                $status = if (Get-ChildItem -Path $cudaPath -Include $dll -Recurse) { "OK" } else { "WARN" }
                Write-Diagnostic "Library: $dll" $status ($null)
            }
        } else {
            Write-Diagnostic "CUDA_PATH" "SKIP" "Not found in environment"
        }
        
        # Environment Validation
        $VenvPython = Join-Path $InstallPath ".venv\Scripts\python.exe"
        if (Test-Path $VenvPython) {
            Write-Step "Diagnostics" "Venv" "Verifying Python dependencies..."
            & $VenvPython (Join-Path $Root "validate.py") --path $InstallPath
        } else {
            Write-ComfyWarning "Virtual environment not found at $VenvPython"
        }
        
        # Self-Healing
        if (-not $NonInteractive) {
            Write-Host "`n"
            $answer = Read-Host "    [?] Run environment self-healing? (y/N)"
            if ($answer -match "y") {
                Repair-Environment -Config $Config -InstallPath $InstallPath -Force:$Force
            }
        }
        
        Show-ComfyFooter
    }
    
    "update" {
        Update-ComfyProject -Config $Config -InstallPath $InstallPath
        Show-ComfyFooter
    }
    
    "clean" {
        Invoke-ComfyClean -InstallPath $InstallPath
        Show-ComfyFooter
    }
}

