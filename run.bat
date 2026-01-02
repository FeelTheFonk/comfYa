@echo off
:: comfYa - Batch Proxy
:: VRAM auto-detection launch wrapper

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
