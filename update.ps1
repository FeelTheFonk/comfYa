# comfYa Update Manager
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Dynamic path resolution
$InstallPath = if ($env:COMFYUI_HOME) { $env:COMFYUI_HOME } else { $PSScriptRoot }

# Import core library
$libPath = Join-Path $InstallPath "lib\core.psm1"
if (Test-Path $libPath) {
    Import-Module $libPath -Force
}

Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      comfYa - Update Manager         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Set-Location $InstallPath
if (Test-Path ".venv\Scripts\Activate.ps1") {
    & ".\.venv\Scripts\Activate.ps1"
} else {
    Write-Error "Virtual environment not found. Run install.ps1 first."
    exit 1
}

# Load config if available
$configPath = Join-Path $InstallPath "config.psd1"
$config = if (Test-Path $configPath) { Import-PowerShellDataFile -Path $configPath } else { $null }

# 1. ComfyUI
Write-Host "[1/5] Updating ComfyUI..." -ForegroundColor Yellow
if (Test-Path "ComfyUI") {
    Push-Location ComfyUI
    $currentCommit = git rev-parse HEAD 2>$null
    if ($currentCommit) {
        Write-Host "  → Current: $($currentCommit.Substring(0,7))" -ForegroundColor Gray
    }
    git fetch origin
    git reset --hard origin/master
    Pop-Location
    Write-Host "  ✓ ComfyUI updated" -ForegroundColor Green
}

# 2. ComfyUI-Manager
Write-Host "[2/5] Updating ComfyUI-Manager..." -ForegroundColor Yellow
$managerPath = "ComfyUI\custom_nodes\ComfyUI-Manager"
if (Test-Path $managerPath) {
    Push-Location $managerPath
    git fetch origin
    git reset --hard origin/main
    Pop-Location
    Write-Host "  ✓ Manager updated" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Manager not found, skipping" -ForegroundColor DarkYellow
}

# 3. Python dependencies
Write-Host "[3/5] Updating ComfyUI dependencies..." -ForegroundColor Yellow
& uv pip install -r ComfyUI\requirements.txt 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ⚠ Dependencies update had warnings" -ForegroundColor DarkYellow
} else {
    Write-Host "  ✓ Dependencies updated" -ForegroundColor Green
}

# 4. Optimization packages
Write-Host "[4/5] Updating optimization packages..." -ForegroundColor Yellow
& uv pip install --upgrade triton-windows torchao 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ⚠ Optimization packages update had warnings" -ForegroundColor DarkYellow
} else {
    Write-Host "  ✓ Optimization packages updated" -ForegroundColor Green
}

# 5. SageAttention check
Write-Host "[5/5] Checking SageAttention..." -ForegroundColor Yellow
try {
    $userAgent = if ($config -and $config.UserAgent) { $config.UserAgent } else { "comfYa/0.1.0" }
    $apiUrl = if ($config) { $config.Sources.APIs.SageAttention } else { "https://api.github.com/repos/woct0rdho/SageAttention/releases/latest" }
    
    $headers = @{ "User-Agent" = $userAgent }
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop -TimeoutSec 10
    $currentVersion = & python -c "from sageattention import __version__; print(__version__)" 2>&1
    
    if ($release.tag_name -notmatch [regex]::Escape($currentVersion)) {
        Write-Host "  → New version available: $($release.tag_name)" -ForegroundColor Yellow
        $cudaVersion = if ($config -and $env:CUDA_VERSION) { $env:CUDA_VERSION } else { "cu128" }
        $asset = $release.assets | Where-Object { $_.name -match "$cudaVersion.*cp312.*win_amd64\.whl" } | Select-Object -First 1
        if ($asset) {
            $whlPath = Join-Path $env:TEMP $asset.name
            if (Get-Command Invoke-SafeWebRequest -ErrorAction SilentlyContinue) {
                Invoke-SafeWebRequest -Uri $asset.browser_download_url -OutFile $whlPath
            } else {
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $whlPath -Headers $headers
            }
            & uv pip install $whlPath --force-reinstall 2>&1 | Out-Null
            Remove-Item $whlPath -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ SageAttention updated" -ForegroundColor Green
        }
    } else {
        Write-Host "  ✓ SageAttention up to date" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠ SageAttention check skipped: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Green
Write-Host "  Update completed successfully!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════" -ForegroundColor Green
Write-Host ""
