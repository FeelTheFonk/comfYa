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
| `Logging` | Log level, file rotation settings |
| `Diagnostics` | CUDA DLLs, system checks |
| `Security` | TLS, download verification |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `COMFYUI_HOME` | Installation path override |

## Scripts

| Command | Purpose |
|--------|---------|
| `comfya.ps1 setup` | Full system initialization (requires administrator privileges) |
| `run.bat` / `comfya.ps1 run` | Start the ComfyUI application |
| `comfya.ps1 update` | Synchronize repositories and dependencies |
| `comfya.ps1 clean` | Sanitize environment and remove temporary artifacts |
| `comfya.ps1 doctor` | System verification and automated repair |
