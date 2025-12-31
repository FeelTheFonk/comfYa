# comfYa - Package Management Module
# Efficient management of uv, git, and system dependencies

#Requires -Version 5.1

function Install-VCRedist {
    param([hashtable]$Config)
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    if (Test-Path $regPath) {
        $reg = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if ($reg.Installed -eq 1 -and $reg.Major -ge 14) { return $true }
    }
    
    $url = $Config.Sources.Dependencies.VCRedist
    $hash = $Config.Sources.Dependencies.VCRedistHash # To be added to config.psd1
    $temp = Join-Path $env:TEMP "vc_redist.x64.exe"
    
    # Requirement: Invoke-SafeWebRequest must be imported
    Invoke-SafeWebRequest -Uri $url -OutFile $temp -ExpectedHash $hash
    
    $proc = Start-Process -FilePath $temp -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
    
    if ($proc.ExitCode -notin @(0, 3010)) { throw "VC++ Redist installation failed: $($proc.ExitCode)" }
    return $true
}


function Install-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) { return $true }
    
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log "Installing Git via winget..." -Level INFO
    } else {
        Write-Host "Installing Git via winget..." -ForegroundColor Cyan
    }
    & winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
    
    return (Get-Command git -ErrorAction SilentlyContinue) -ne $null
}

function Install-Uv {
    param([hashtable]$Config)
    
    if (Get-Command uv -ErrorAction SilentlyContinue) { return $true }
    
    $url = $Config.Sources.Dependencies.Uv
    $hash = $Config.Sources.Dependencies.UvHash
    $temp = Join-Path $env:TEMP "uv-install.ps1"
    
    Write-Log "Downloading uv installer with security verification..." -Level INFO
    Invoke-SafeWebRequest -Uri $url -OutFile $temp -ExpectedHash $hash
    
    # Run installer
    powershell -ExecutionPolicy Bypass -File $temp /S # Silent install
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
    
    # Adaptive Path Update
    $possibleBins = @(
        (Join-Path $env:USERPROFILE ".local\bin"),
        (Join-Path $env:APPDATA "uv\bin")
    )
    
    foreach ($bin in $possibleBins) {
        if (Test-Path $bin) {
            if ($bin -notin ($env:Path -split ';')) {
                $env:Path = "$bin;$env:Path"
                Write-Log "Added $bin to environment path." -Level DEBUG
            }
        }
    }
    
    Update-EnvironmentPath
    return (Get-Command uv -ErrorAction SilentlyContinue) -ne $null
}

function Repair-Environment {
    param([hashtable]$Config, [string]$InstallPath, [switch]$Force)
    
    $VenvPath = Join-Path $InstallPath ".venv"
    $Python = Join-Path $VenvPath "Scripts\python.exe"
    
    # 1. Base Environment Restoration
    if (-not (Test-Path $VenvPath) -or $Force) {
        Write-Log "Initializing/Resetting virtual environment..." -Level WARN
        if (Test-Path $VenvPath) { Remove-Item $VenvPath -Recurse -Force -ErrorAction SilentlyContinue }
        & uv venv $VenvPath --python $Config.Python.Version
    }
    
    # 2. Dependency SOTA Audit
    Write-Log "Auditing and aligning SOTA dependencies..." -Level INFO
    
    # Core Application Requirements
    $ReqFile = Join-Path $InstallPath "ComfyUI\requirements.txt"
    if (Test-Path $ReqFile) {
        & uv pip install -r $ReqFile --python $Python
    }
    
    # Acceleration Stack (Torch & Friends)
    try {
        $gpu = Get-NvidiaGpuInfo -Config $Config
        $IndexUrl = $Config.Sources.PyTorch.IndexUrls[$gpu.CudaVersion]
        Write-Log "Ensuring PyTorch Nightly alignment for $($gpu.CudaVersion)..." -Level VERBOSE
        & uv pip install --pre torch torchvision torchaudio --index-url $IndexUrl --python $Python
    } catch {
        Write-Log "GPU detection failed during repair, skipping Torch alignment." -Level WARN
    }
    
    # Cleanup & Optimization
    & uv pip install @($Config.Packages.Optimization) --python $Python
    & uv pip install @($Config.Packages.Core) @($Config.Packages.ML) --python $Python
    
    Write-Success "Self-healing completed for environment at $InstallPath"
    return $true
}

Export-ModuleMember -Function @(
    'Install-VCRedist'
    'Install-Git'
    'Install-Uv'
    'Repair-Environment'
)
