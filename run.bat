@echo off
:: comfYa - Batch Proxy (v0.2.4)
:: with VRAM auto-detection

setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "comfya.ps1" run -Mode Auto

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] comfYa failed with code %errorlevel%
    pause
    exit /b %errorlevel%
)
endlocal
