# comfYa - Lifecycle Management Module
# Centralized logic for installation, execution, and updates

#Requires -Version 5.1

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
    
    # 1. Directory Structure Implementation
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
    & uv python install $Config.Python.Version
    & uv venv (Join-Path $InstallPath ".venv") --python $Config.Python.Version
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
    $AppPath = Join-Path $InstallPath "ComfyUI"
    if (-not (Test-Path $AppPath)) {
        & git clone --depth 1 $Config.Sources.Repositories.ComfyUI $AppPath
    }
    & uv pip install -r (Join-Path $AppPath "requirements.txt") --python $VenvPython
    
    # 5. Environment Finalization
    Write-Step "Install" "Final" "Configuring environment variables"
    foreach ($key in $Config.Environment.Keys) {
        $val = $Config.Environment[$key] -replace '\{InstallPath\}', $InstallPath
        if ($val -match '\{Dir:(.*?)\}') {
            $dirKey = $Matches[1]
            if ($Config.Directories.ContainsKey($dirKey)) {
                $val = $val -replace '\{Dir:.*?\}', $Config.Directories[$dirKey]
            }
        }
        [Environment]::SetEnvironmentVariable($key, $val, "User")
    }
    
    if (-not $SkipValidation) {
        # Note: validate.py expects to be in the root of the project (usually $InstallPath or where comfya.ps1 is)
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
    
    # Environment Variables Sync
    foreach ($key in $Config.Environment.Keys) {
        $val = $Config.Environment[$key] -replace '\{InstallPath\}', $InstallPath
        if ($val -match '\{Dir:(.*?)\}') {
            $dirKey = $Matches[1]
            if ($Config.Directories.ContainsKey($dirKey)) {
                $val = $val -replace '\{Dir:.*?\}', $Config.Directories[$dirKey]
            }
        }
        Set-Item -Path "env:$key" -Value $val
    }
    
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
    $Repos = @{
        "ComfyUI Core"    = @{ Path = (Join-Path $InstallPath "ComfyUI"); Branch = "master" }
        "ComfyUI Manager" = @{ Path = (Join-Path $InstallPath "ComfyUI\custom_nodes\ComfyUI-Manager"); Branch = "main" }
    }
    
    foreach ($name in $Repos.Keys) {
        $r = $Repos[$name]
        if (Test-Path $r.Path) {
            Write-ComfyLog "Updating $name..." -Level VERBOSE
            Push-Location $r.Path
            try {
                & git fetch origin
                & git reset --hard "origin/$($r.Branch)"
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
