# comfYa - Package Management Module
# Efficient management of uv, git, and system dependencies

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Install-VCRedist {
    param([hashtable]$Config)
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    if (Test-Path $regPath) {
        $reg = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        # [9] Smart Audit: Check for specific minor version if possible, otherwise assume 14.4x is "modern"
        if ($reg.Installed -eq 1 -and $reg.Major -ge 14 -and $reg.Minor -ge 40) { 
            Write-ComfyLog "VC++ Redist 14.40+ already installed. Skipping." -Level INFO
            return $true 
        }
    }
    
    $url = $Config.Sources.Dependencies.VCRedist
    $hash = $Config.Sources.Dependencies.VCRedistHash
    $temp = Join-Path $env:TEMP "vc_redist.x64.exe"
    
    Write-Step "Install" "VCRedist" "Downloading VC++ Redist (14.4x)..."
    Invoke-SafeWebRequest -Uri $url -OutFile $temp -ExpectedHash $hash -UserAgent $Config.UserAgent
    
    # [S1] Security: Verify Authenticode signature (Microsoft-signed binary)
    $signature = Get-AuthenticodeSignature -FilePath $temp
    if ($signature.Status -ne "Valid" -or $signature.SignerCertificate.Subject -notmatch "Microsoft") {
        Remove-Item $temp -Force -ErrorAction SilentlyContinue
        throw "VCRedist signature verification failed: $($signature.Status)"
    }
    Write-ComfyLog "VCRedist signature verified: $($signature.SignerCertificate.Subject)" -Level DEBUG
    
    $proc = Start-Process -FilePath $temp -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
    
    if ($proc.ExitCode -notin @(0, 3010)) { throw "VC++ Redist installation failed: $($proc.ExitCode)" }
    return $true
}



function Install-Git {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
    param()
    if (Get-Command git -ErrorAction SilentlyContinue) { return $true }
    
    if (Get-Command Write-ComfyLog -ErrorAction SilentlyContinue) {
        Write-ComfyLog "Installing Git via winget..." -Level INFO
    } else {
        Write-Host "Installing Git via winget..." -ForegroundColor Cyan
    }
    & winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
    if ($LASTEXITCODE -notin @(0, -1978335189)) { # -1978335189 = already installed
        Write-ComfyWarning "Git installation may have encountered issues (exit code: $LASTEXITCODE)"
    }
    
    return $null -ne (Get-Command git -ErrorAction SilentlyContinue)
}

function Install-Uv {
    param([hashtable]$Config)
    
    if (Get-Command uv -ErrorAction SilentlyContinue) { return $true }
    
    $url = $Config.Sources.Dependencies.Uv
    $hash = $Config.Sources.Dependencies.UvHash
    $temp = Join-Path $env:TEMP "uv-install.ps1"
    
    Write-ComfyLog "Downloading uv installer..." -Level INFO
    Invoke-SafeWebRequest -Uri $url -OutFile $temp -ExpectedHash $hash -UserAgent $Config.UserAgent
    
    # Run installer with appropriate PowerShell host
    $hostExe = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh.exe" } else { "powershell.exe" }
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File $temp
    if ($LASTEXITCODE -ne 0) {
        Write-ComfyWarning "uv installer returned exit code: $LASTEXITCODE"
    }
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
                Write-ComfyLog "Added $bin to environment path." -Level DEBUG
            }
        }
    }
    
    Update-EnvironmentPath
    return $null -ne (Get-Command uv -ErrorAction SilentlyContinue)
}

function Repair-Environment {
    param([hashtable]$Config, [string]$InstallPath, [switch]$Force)
    
    $VenvPath = Join-Path $InstallPath ".venv"
    $Python = Join-Path $VenvPath "Scripts\python.exe"
    
    # 1. Base Environment Restoration
    if (-not (Test-Path $VenvPath) -or $Force) {
        Write-ComfyLog "Initializing/Resetting virtual environment..." -Level WARN
        if (Test-Path $VenvPath) { Remove-Item $VenvPath -Recurse -Force -ErrorAction SilentlyContinue }
        & uv venv $VenvPath --python $Config.Python.Version
        if ($LASTEXITCODE -ne 0) { throw "uv venv failed (exit code: $LASTEXITCODE)" }
    }
    
    # 2. Dependency SOTA Audit
    Write-ComfyLog "Auditing and aligning SOTA dependencies..." -Level INFO
    
    # Core Application Requirements
    $ReqFile = Join-Path $InstallPath "ComfyUI\requirements.txt"
    if (Test-Path $ReqFile) {
        & uv pip install -r $ReqFile --python $Python
        if ($LASTEXITCODE -ne 0) { Write-ComfyWarning "Requirements install failed (exit code: $LASTEXITCODE)" }
    }
    
    # Acceleration Stack (Torch & Friends)
    try {
        $gpu = Get-NvidiaGpuInfo -Config $Config
        $IndexUrl = $Config.Sources.PyTorch.IndexUrls[$gpu.CudaVersion]
        Write-ComfyLog "Ensuring PyTorch Nightly alignment for $($gpu.CudaVersion)..." -Level VERBOSE
        & uv pip install --pre torch torchvision torchaudio --index-url $IndexUrl --python $Python
        if ($LASTEXITCODE -ne 0) { Write-ComfyWarning "PyTorch alignment failed (exit code: $LASTEXITCODE)" }
    } catch {
        Write-ComfyLog "GPU detection failed during repair, skipping Torch alignment." -Level WARN
    }
    
    # Cleanup & Optimization
    & uv pip install @($Config.Packages.Optimization) --python $Python
    if ($LASTEXITCODE -ne 0) { Write-ComfyWarning "Optimization install failed (exit code: $LASTEXITCODE)" }
    & uv pip install @($Config.Packages.Core) @($Config.Packages.ML) --python $Python
    if ($LASTEXITCODE -ne 0) { Write-ComfyWarning "Core/ML packages install failed (exit code: $LASTEXITCODE)" }
    
    Write-Success "Self-healing completed for environment at $InstallPath"
    return $true
}

function Invoke-PostInstallCleanup {
    [CmdletBinding()]
    param()
    
    Write-Step "Cleanup" "Temp" "Removing temporary orchestration artifacts..."
    $targets = @(
        (Join-Path $env:TEMP "uv-install.ps1"),
        (Join-Path $env:TEMP "vc_redist.x64.exe"),
        (Join-Path $env:TEMP "comfya-init.log")
    )
    
    foreach ($t in $targets) {
        if (Test-Path $t) {
            Remove-Item $t -Force -ErrorAction SilentlyContinue
            Write-ComfyLog "Removed: $t" -Level DEBUG
        }
    }
}

function Get-LatestGithubRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ApiUrl,
        [string]$MatchPattern,
        [string]$UserAgent = "comfYa"
    )
    
    try {
        $response = Invoke-SafeWebRequest -Uri $ApiUrl -UserAgent $UserAgent
        $content = $response.Content | ConvertFrom-Json
        
        if ($MatchPattern) {
            $asset = $content.assets | Where-Object { $_.name -match $MatchPattern } | Select-Object -First 1
            if ($asset) { return $asset.browser_download_url }
        }
        
        return $content.tag_name
    } catch {
        Write-ComfyWarning "GitHub API fetch failed for ${ApiUrl}: $_"
        return $null
    }
}

function Install-SageAttention {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [hashtable]$GPU,
        [Parameter(Mandatory)]
        [string]$PythonExe,
        [switch]$Upgrade
    )
    
    $sageApi = $Config.Sources.APIs.SageAttention
    # [SOTA] SageAttention uses ABI3 stable wheels (cp39-abi3) since v2.2.0-windows.post4
    $sagePattern = "$($GPU.CudaVersion).*abi3.*win_amd64"
    
    Write-Step "Install" "Sage" "Discovering SageAttention asset for $sagePattern"
    $dynamicSageUrl = Get-LatestGithubRelease -ApiUrl $sageApi -MatchPattern $sagePattern -UserAgent $Config.UserAgent
    
    $uvArgs = @($dynamicSageUrl, "--python", $PythonExe)
    if ($Upgrade) { $uvArgs = @("--upgrade") + $uvArgs }
    
    if ($dynamicSageUrl) {
        Write-ComfyLog "Injecting SageAttention via Dynamic SOTA wheel" -Level SUCCESS
        & uv pip install @uvArgs
        if ($LASTEXITCODE -ne 0) { throw "SageAttention installation failed (exit code: $LASTEXITCODE)" }
        return $true
    }
    
    # Fallback to static config
    # [SOTA] ABI3 wheels are Python-version independent
    $fallbackUrl = $Config.Sources.FallbackWheels.SageAttention[$GPU.CudaVersion]
    
    if ($fallbackUrl) {
        Write-ComfyWarning "GitHub API failed, using static fallback for SageAttention."
        $uvArgs[0] = $fallbackUrl
        & uv pip install @uvArgs
        if ($LASTEXITCODE -ne 0) { throw "SageAttention fallback installation failed (exit code: $LASTEXITCODE)" }
        return $true
    }
    
    Write-ComfyWarning "SageAttention installation skipped (No compatible wheel found)"
    return $false
}

Export-ModuleMember -Function @(
    'Install-VCRedist'
    'Install-Git'
    'Install-Uv'
    'Repair-Environment'
    'Get-LatestGithubRelease'
    'Invoke-PostInstallCleanup'
    'Install-SageAttention'
)
