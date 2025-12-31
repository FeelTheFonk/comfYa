# Quick Start

Get ComfyUI running in 5 minutes.

## Prerequisites

- Windows 10/11
- NVIDIA GPU (RTX 20xx or newer)
- NVIDIA Driver 525+ (570+ recommended)
- PowerShell 5.1+ or PowerShell 7+

## Installation

### 1. Download comfYa

```powershell
git clone https://github.com/FeelTheFonk/comfYa.git
cd comfYa
```

### 2. Run Installer (Admin Required)

```powershell
# Right-click PowerShell → Run as Administrator
.\comfya.ps1 setup
```

The installer will:
- Install VC++ Runtime if needed
- Install Git if needed
- Install uv package manager
- Create Python 3.12 virtual environment
- Install PyTorch Nightly + CUDA
- Install Triton and SageAttention
- Clone ComfyUI and ComfyUI-Manager

### 3. Launch

```powershell
.\run.bat
# or
.\comfya.ps1 run
```

Open browser: **http://127.0.0.1:8188**

## Verify Installation

```powershell
.\comfya.ps1 doctor
```

```text
--- comfYa SOTA Validation ---

  Hardware/CUDA............ OK   (RTX 4090 [CC 8.9])
  Acceleration............. SKIP (Triton v3.x | SageAttn missing)
```

## Update

```powershell
.\comfya.ps1 update
```

## Custom Install Path

```powershell
$env:COMFYUI_HOME = "D:\MyComfyUI"
.\comfya.ps1 setup
```

## Next Steps

- Download models to `models/checkpoints/`
- Install custom nodes via ComfyUI-Manager (in-app)
- See [Troubleshooting](TROUBLESHOOTING.md) for common issues
