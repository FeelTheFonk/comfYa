# comfYa - Lifecycle Management Module
# Centralized logic for installation, execution, and updates

#Requires -Version 5.1

# -----------------------------------------------------------------------------
# INTERNAL HELPERS
# -----------------------------------------------------------------------------


function Test-UvAvailability {
    [CmdletBinding()]
    param()
    
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        # Try to refresh path if uv was just installed
        Update-EnvironmentPath
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
            Write-Fatal "uv is not available in the current session." -Suggestion "Please restart your terminal or ensure uv is in your PATH."
        }
    }
}

function Initialize-ComfyDirectories {
    param(
        [hashtable]$Config,
        [string]$InstallPath
    )
    Write-Step "Init" "FS" "Synchronizing directory structure"
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
            Write-ComfyLog "Created directory: $p" -Level DEBUG
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
        [switch]$SkipValidation,
        [switch]$Simulate
    )
    

    
    if (-not $PSCmdlet.ShouldProcess($InstallPath, "Install ComfyUI Project (Simulate: $Simulate)")) { return }
    
    $GPU = Get-NvidiaGpuInfo -Config $Config
    
    # 1. Directory Structure
    Initialize-ComfyDirectories -Config $Config -InstallPath $InstallPath
    
    # 2. Python Environment
    Write-Step "Install" "Python" "Managing standalone Python $($Config.Python.Version)"
    try {
        Test-UvAvailability # [11] Pre-Install Hook
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
    
    # [7] SageAttention (Dynamic SOTA Detection)
    $sageApi = $Config.Sources.APIs.SageAttention
    $pySuffix = "cp" + ($Config.Python.Version -replace '\.', '')
    $sagePattern = "$($GPU.CudaVersion).*$pySuffix.*win_amd64"
    
    Write-Step "Install" "Sage" "Discovering dynamic SageAttention asset for $sagePattern"
    $dynamicSageUrl = Get-LatestGithubRelease -ApiUrl $sageApi -MatchPattern $sagePattern
    
    if ($dynamicSageUrl) {
        Write-ComfyLog "Injecting SageAttention via Dynamic SOTA wheel: $dynamicSageUrl" -Level SUCCESS
        & uv pip install $dynamicSageUrl --python $VenvPython
    } else {
        # Fallback to config if API fails
        $SageKey = "$($GPU.CudaVersion)_py$($Config.Python.Version -replace '\.', '')"
        $fallbackUrl = $Config.Sources.FallbackWheels.SageAttention[$SageKey]
        if ($fallbackUrl) {
            Write-ComfyWarning "GitHub API failed, using static fallback for SageAttention."
            & uv pip install $fallbackUrl --python $VenvPython
        }
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
        [string]$InstallPath,
        [switch]$Force
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
                # [13] Non-Destructive: check for dirty state
                $status = & git status --porcelain
                if ($status -and -not $Force) {
                    Write-ComfyWarning "$key has local changes. Skipping hard reset. Use -Force to overwrite."
                    & git merge origin/$($r.Branch)
                } else {
                    & git reset --hard "origin/$($r.Branch)"
                }
            } catch {
                Write-ComfyWarning "Failed to update $key`: $_"
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

function Invoke-ComfyClean {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$InstallPath
    )
    
    Write-Step "Clean" "Init" "Starting environment sanitation at $InstallPath"
    
    $targets = @(
        ".venv",
        "__pycache__",
        "logs",
        ".triton_cache"
    )
    
    foreach ($t in $targets) {
        $p = Join-Path $InstallPath $t
        if (Test-Path $p) {
            if ($PSCmdlet.ShouldProcess($p, "Remove Item")) {
                Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Sanitized: $t"
            }
        }
    }
}

Export-ModuleMember -Function @(
    'Install-ComfyProject'
    'Start-ComfyProject'
    'Update-ComfyProject'
    'Invoke-ComfyClean'
)
