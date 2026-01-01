# comfYa v0.2.4

> ComfyUI Automated Installer for Windows NVIDIA

[![CI](https://github.com/FeelTheFonk/comfYa/actions/workflows/ci.yml/badge.svg)](https://github.com/FeelTheFonk/comfYa/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/FeelTheFonk/comfYa)](https://github.com/FeelTheFonk/comfYa/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

- **Automated Configuration**: Automatic detection of hardware profiles and driver capabilities.
- **Optimized Execution**: Integration of high-performance backend components and kernels.
- **Path Portability**: Support for dynamic installation paths and environment overrides.
- **Verification Framework**: Comprehensive system validation and self-healing capabilities.

## Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Windows 10 | Windows 11 |
| GPU | RTX 20xx (CC 7.5) | RTX 40xx+ |
| Driver | 525+ | 570+ |
| RAM | 16 GB | 32+ GB |

## Quick Start

```powershell
# Unified CLI commands
.\comfya.ps1 setup
.\comfya.ps1 run
.\comfya.ps1 doctor
.\comfya.ps1 update
.\comfya.ps1 clean
```

For immediate launch using auto-detected VRAM, use the batch proxy:
```batch
.\run.bat
```

See [Quick Start Guide](docs/QUICK_START.md) for detailed instructions.

### Custom Installation Path

```powershell
$env:COMFYUI_HOME = "D:\MyComfyUI"
.\comfya.ps1 setup
```

## Project Structure

```
comfYa/
├── comfya.ps1           # Unified Orchestrator CLI
├── run.bat              # Launch Proxy
├── validate.py          # Installation validator
├── config.psd1          # Central SOT (PowerShell)
├── config.json          # Configuration bridge (Auto-generated)
├── lib/                 # Domain Modules (Lifecycle, Logging, Nvidia, etc.)
├── tests/               # Pester tests
├── docs/                # Documentation
└── .github/workflows/   # CI/CD
```

## Documentation

- [Quick Start](docs/QUICK_START.md) — Get running in 5 minutes
- [Troubleshooting](docs/TROUBLESHOOTING.md) — Common issues and solutions
- [Architecture](ARCHITECTURE.md) — Technical deep dive
- [Contributing](CONTRIBUTING.md) — How to contribute

## Configuration

Edit `config.psd1`:

```powershell
@{
    Version   = "0.2.4"
    Python = @{ Version = "3.12" }
    Cuda = @{ PreferredVersion = "cu128" }
    Gpu = @{ MinComputeCapability = 7.5 }
    LaunchArgs = @{
        HighVram = @("--fast", "--highvram", "--use-sage-attention")
    }
}
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `COMFYUI_HOME` | Installation path override |
| `CUDA_MODULE_LOADING` | Set to `LAZY` for optimized CUDA loading |
| `PYTORCH_CUDA_ALLOC_CONF` | Memory allocation strategy |
| `TRITON_CACHE_DIR` | Triton kernel cache location |
| `TORCH_COMPILE_BACKEND` | Compilation backend (default: `inductor`) |

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| CUDA not detected | Update NVIDIA driver to 570+ |
| Triton import fails | Reinstall: `uv pip install triton-windows --force-reinstall` |
| SageAttention missing | See [Troubleshooting Guide](docs/TROUBLESHOOTING.md) |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

[MIT](LICENSE)
