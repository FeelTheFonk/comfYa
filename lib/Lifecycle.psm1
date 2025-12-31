# comfYa - Lifecycle Management Module
# Centralized logic for installation, execution, and updates

#Requires -Version 5.1

# -----------------------------------------------------------------------------
# INTERNAL HELPERS
# -----------------------------------------------------------------------------

function Resolve-ComfyEnvironment {
    param(
        [hashtable]$Config,
        [string]$InstallPath
    )
    $EnvMap = @{}
    foreach ($key in $Config.Environment.Keys) {
        $val = $Config.Environment[$key] -replace '\{InstallPath\}', $InstallPath
        if ($val -match '\{Dir:(.*?)\}') {
            $dirKey = $Matches[1]
            if ($Config.Directories.ContainsKey($dirKey)) {
                $val = $val -replace '\{Dir:.*?\}', $Config.Directories[$dirKey]
            }
        }
        $EnvMap[$key] = $val
    }
    return $EnvMap
}

function Sync-ComfyEnvironment {
    param([hashtable]$EnvMap, [bool]$Persist = $false)
    foreach ($key in $EnvMap.Keys) {
        $val = $EnvMap[$key]
        Set-Item -Path "env:$key" -Value $val
        if ($Persist) {
            [Environment]::SetEnvironmentVariable($key, $val, "User")
        }
    }
}

# -----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
# -----------------------------------------------------------------------------

function Install-ComfyProject {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [string]$InstallPath,
        [switch]$SkipValidation
    )
    
    if (-not $PSCmdlet.ShouldProcess($InstallPath, "Install ComfyUI Project")) { return }
    
    $GPU = Get-NvidiaGpuInfo -Config $Config
    
    # 1. Directory Structure
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
    foreach($p in $PathsToCreate) { 
        if (-not (Test-Path $p)) {
            New-Item -ItemType Directory -Force -Path $p | Out-Null 
        }
    }
    
    # 2. Python Environment
    Write-Step "Install" "Python" "Managing standalone Python $($Config.Python.Version)"
    try {
        & uv python install $Config.Python.Version
        & uv venv (Join-Path $InstallPath ".venv") --python $Config.Python.Version
    } catch {
        Write-Fatal "Python/Venv initialization failed" -Suggestion "Ensure 'uv' is working and you have internet access."
    }
    
    $VenvPython = Join-Path $InstallPath ".venv\Scripts\python.exe"
    
    # 3. Acceleration Stack
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
        Write-ComfyLog "Injecting SageAttention via SOTA wheel: $SageKey" -Level VERBOSE
        & uv pip install $SageUrl --python $VenvPython
    }
    
    # 4. Application Cloning
    Write-Step "Install" "App" "Cloning ComfyUI Core"
    $Repo = $Config.Sources.Repositories.ComfyUI
    $AppPath = Join-Path $InstallPath $Repo.Path
    if (-not (Test-Path $AppPath)) {
        try {
            & git clone --depth 1 $Repo.Url $AppPath
        } catch {
            Write-Fatal "Cloning failed" -Suggestion "Check your git installation and internet connection."
        }
    }
    & uv pip install -r (Join-Path $AppPath "requirements.txt") --python $VenvPython
    
    # 5. Security & Exclusions
    if ($Config.Security.DefenderExclusion) {
        Write-Step "Install" "Security" "Applying Windows Defender exclusions"
        Add-DefenderExclusion -Path $InstallPath
    }
    
    # 6. Environment Finalization
    Write-Step "Install" "Final" "Configuring environment variables"
    $EnvMap = Resolve-ComfyEnvironment -Config $Config -InstallPath $InstallPath
    Sync-ComfyEnvironment -EnvMap $EnvMap -Persist $true
    
    if (-not $SkipValidation) {
        $ValidatorPath = Join-Path $PSScriptRoot "..\validate.py"
        if (Test-Path $ValidatorPath) {
            & $VenvPython $ValidatorPath --path $InstallPath
        }
    }
    
    Write-Success "comfYa - Installation Complete at $InstallPath"
}

function Start-ComfyProject {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [string]$InstallPath,
        [ValidateSet("Auto", "Default", "HighVram", "LowVram", "Cpu")]
        [string]$Mode = "Auto"
    )
    
    if (-not $PSCmdlet.ShouldProcess($InstallPath, "Start ComfyUI")) { return }
    
    # 1. Proactive Mode Detection
    if ($Mode -eq "Auto") {
        try {
            $gpu = Get-NvidiaGpuInfo -Config $Config
            $totalVram = $gpu.Vram
            if ($totalVram -ge 12000) { $Mode = "HighVram" }
            elseif ($totalVram -ge 6000) { $Mode = "Default" }
            else { $Mode = "LowVram" }
            Write-ComfyLog "Auto-detected VRAM: ${totalVram}MB. Selecting mode: $Mode" -Level INFO
        }
        catch {
            Write-ComfyLog "GPU Detection failed, falling back to Default." -Level WARN
            $Mode = "Default"
        }
    }
    
    # 2. Preparation
    $VenvPath = Join-Path $InstallPath ".venv"
    if (-not (Test-Path $VenvPath)) {
        Write-Fatal "Environment not found" -Suggestion "Run 'comfya setup' first."
    }
    
    $EnvMap = Resolve-ComfyEnvironment -Config $Config -InstallPath $InstallPath
    Sync-ComfyEnvironment -EnvMap $EnvMap
    
    # 3. Execution
    $MainScript = Join-Path $InstallPath "ComfyUI\main.py"
    $PythonExe = Join-Path $VenvPath "Scripts\python.exe"
    $LaunchArgs = @($MainScript) + $Config.LaunchArgs[$Mode]
    
    Write-ComfyLog "Launching comfYa [$Mode]..." -Level SUCCESS
    Push-Location $InstallPath
    try {
        & $PythonExe @LaunchArgs
    }
    finally {
        Pop-Location
    }
}

function Update-ComfyProject {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [string]$InstallPath
    )
    
    if (-not $PSCmdlet.ShouldProcess($InstallPath, "Update ComfyUI Project")) { return }
    
    Write-Step "Update" "Init" "Synchronizing with SOTA repositories..."
    $PythonExe = Join-Path $InstallPath ".venv\Scripts\python.exe"
    
    # 1. Repository Synchronization
    $Repos = $Config.Sources.Repositories
    
    foreach ($key in $Repos.Keys) {
        $r = $Repos[$key]
        $fullPath = Join-Path $InstallPath $r.Path
        if (Test-Path $fullPath) {
            Write-ComfyLog "Updating $key ($($r.Path))..." -Level VERBOSE
            Push-Location $fullPath
            try {
                & git fetch origin
                & git reset --hard "origin/$($r.Branch)"
            } catch {
                Write-ComfyWarning "Failed to update $key. Repository might be locked or dirty."
            } finally {
                Pop-Location
            }
        }
    }
    
    # 2. Dependency Alignment
    Write-Step "Update" "Deps" "Aligning dependencies via uv"
    & uv pip install -r (Join-Path $InstallPath "ComfyUI\requirements.txt") --python $PythonExe
    
    Write-ComfyLog "Enforcing Optimization Stack (Triton, TorchAO)..." -Level VERBOSE
    & uv pip install --upgrade @($Config.Packages.Optimization) --python $PythonExe
    
    # 3. SageAttention Synchronization
    try {
        Write-ComfyLog "Checking for SageAttention updates..." -Level VERBOSE
        $GPU = Get-NvidiaGpuInfo -Config $Config
        $PyVerShort = $Config.Python.Version -replace '\.', ''
        $SageKey = "$($GPU.CudaVersion)_py$PyVerShort"
        $SageUrl = $Config.Sources.FallbackWheels.SageAttention[$SageKey]
        if ($SageUrl) {
            & uv pip install --upgrade $SageUrl --python $PythonExe
        }
    } catch {
        Write-ComfyLog "SageAttention update skipped (Non-critical)" -Level WARN
    }
    
    Write-Success "comfYa - All components synchronized."
}

Export-ModuleMember -Function @(
    'Install-ComfyProject'
    'Start-ComfyProject'
    'Update-ComfyProject'
)
