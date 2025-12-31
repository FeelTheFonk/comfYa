@echo off
:: comfYa Launcher
:: Reads configuration from PowerShell for consistency

cd /d "%~dp0"
if not exist ".venv\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found. Run install.ps1 first.
    pause
    exit /b 1
)

call .venv\Scripts\activate.bat

:: Environment variables (sync with config.psd1)
set CUDA_MODULE_LOADING=LAZY
set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
set TRITON_CACHE_DIR=%~dp0.triton_cache
set TORCH_COMPILE_BACKEND=inductor

echo.
echo +======================================+
echo ^|        comfYa - Starting             ^|
echo +======================================+
echo.

:: Launch args from config.psd1 LaunchArgs.HighVram
python ComfyUI\main.py --fast --highvram --use-sage-attention
if errorlevel 1 (
    echo.
    echo ERROR: ComfyUI exited with error code %errorlevel%
    pause
    exit /b %errorlevel%
)
