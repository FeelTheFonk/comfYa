# comfYa Documentation

## Quick Links

- [Quick Start](QUICK_START.md) — Get ComfyUI running in 5 minutes
- [Troubleshooting](TROUBLESHOOTING.md) — Common issues and solutions
- [Architecture](../ARCHITECTURE.md) — Technical deep dive

## Overview

comfYa is an automated installer for ComfyUI on Windows with NVIDIA GPUs. It handles:

1. **System Bootstrap** — VC++ Runtime, Git, uv package manager
2. **Python Environment** — Python 3.12 via uv, virtual environment
3. **CUDA Stack** — PyTorch Nightly, Triton, SageAttention
4. **ComfyUI** — Core + Manager installation

## Configuration

All settings in [`config.psd1`](../config.psd1):

| Section | Purpose |
|---------|---------|
| `Python` | Version constraints |
| `Cuda` | CUDA version mapping |
| `Gpu` | Compute capability requirements |
| `Sources` | URLs for dependencies |
| `LaunchArgs` | ComfyUI launch options |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `COMFYUI_HOME` | Installation path override |
| `COMFYUI_PYTHON_VERSION` | Python version override |
| `COMFYUI_CUDA_VERSION` | CUDA version override |

## Scripts

| Script | Purpose |
|--------|---------|
| `install.ps1` | Full installation (run as admin) |
| `run.ps1` / `run.bat` | Launch ComfyUI |
| `update.ps1` | Update ComfyUI and dependencies |
| `validate.py` | Verify installation |
