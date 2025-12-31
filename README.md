# comfYa

> ComfyUI Automated Installer for Windows NVIDIA

[![CI](https://github.com/FeelTheFonk/comfYa/actions/workflows/ci.yml/badge.svg)](https://github.com/FeelTheFonk/comfYa/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/FeelTheFonk/comfYa)](https://github.com/FeelTheFonk/comfYa/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- **Zero-configuration**: Auto-detects GPU, driver, and CUDA version
- **Optimized**: PyTorch Nightly, Triton, SageAttention
- **Portable**: Dynamic paths, environment variable overrides
- **Maintainable**: Centralized configuration, modular design

## Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Windows 10 | Windows 11 |
| GPU | RTX 20xx (CC 7.5) | RTX 40xx+ |
| Driver | 525+ | 570+ |
| RAM | 16 GB | 32+ GB |

## Quick Start

```powershell
# Install (run as Administrator)
.\install.ps1

# Launch
.\run.bat  # or .\run.ps1

# Update
.\update.ps1

# Validate
python validate.py
```

See [Quick Start Guide](docs/QUICK_START.md) for detailed instructions.

### Custom Installation Path

```powershell
$env:COMFYUI_HOME = "D:\MyComfyUI"
.\install.ps1
```

## Project Structure

```
comfYa/
├── install.ps1          # Main installer
├── run.ps1 / run.bat    # Launchers
├── update.ps1           # Update manager
├── validate.py          # Installation validator
├── config.psd1          # Configuration
├── lib/core.psm1        # Core module
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
| `COMFYUI_PYTHON_VERSION` | Python version override |
| `COMFYUI_CUDA_VERSION` | CUDA version (cu121/cu124/cu128) |

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
