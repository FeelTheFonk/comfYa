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
    param([hashtable]$Config, [string]$InstallPath)
    
    $VenvPath = Join-Path $InstallPath ".venv"
    if (-not (Test-Path $VenvPath)) {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log "Recreating missing .venv..." -Level WARN
        } else {
            Write-Host "Recreating missing .venv..." -ForegroundColor Yellow
        }
        & uv venv $VenvPath --python $Config.Python.Version
    }
    
    $Python = Join-Path $VenvPath "Scripts\python.exe"
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log "Auditing dependencies..." -Level INFO
    } else {
        Write-Host "Auditing dependencies..." -ForegroundColor Cyan
    }
    & uv pip install -r (Join-Path $InstallPath "ComfyUI\requirements.txt") --python $Python
    
    return $true
}

Export-ModuleMember -Function @(
    'Install-VCRedist'
    'Install-Git'
    'Install-Uv'
    'Repair-Environment'
)
