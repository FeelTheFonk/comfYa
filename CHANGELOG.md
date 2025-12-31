# Changelog

All notable changes to comfYa will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.1] - 2025-12-31 (Pinnacle)

### Added
- **Pinnacle Visual System**: Professional ANSI header, unified step alignment, and context-aware status symbols (✔/⚠/✘).
- **Operation Finalization**: New `Show-ComfyFooter` for clear completion feedback.
- **Environment Resolution Engine**: Centralized recursive path and environment variable resolution.
- **Multi-GPU Optimization**: Automated selection of the highest performance GPU based on CC and VRAM.

### Changed
- **Logic Deduplication**: Unified environment synchronization across setup/run/update flows.
- **Enhanced Bootstrapping**: Improved error handling and suggestion engine for `git` and `uv` failures.
- **Nvidia Module**: Refactored hardware detection for **Locale-Independence** (fixes CC parsing on international Windows).
- **Diagnostics**: `doctor` command upgraded with dynamic path validation and "Pinnacle" formatting.

### Fixed
- **PowerShell Compatibility**: Fixed attribute placement parser errors in PS 5.1.
- **UTF-8 Encoding**: Resolved mangled status symbols in terminal output.
- **Validation Gap**: Fixed `validate.py` failing when `COMFYUI_HOME` was set outside the script root.


### Added
- **Unified CLI**: `comfya.ps1` as the single orchestrator (setup, run, doctor, update).
- **Architectural Unification**: New `lib/Lifecycle.psm1` module consolidates logic from standalone scripts.
- **SSA Reinforcement**: Zero-gap configuration bridge via `config.json` for perfect PS/Python synchronization.
- **Lib/Nvidia**: Advanced GPU/CUDA/Arch detection with **modular VRAM query**.
- **Lib/Logging**: Structured ANSI logging with professional header and standardized warning levels.
- **Lib/SystemUtils**: Pre-flight requirement checks and enhanced elevation logic (host-aware).
- **Lib/Package**: Intelligent environment management with **Self-Healing** and hardened download security.
- **Smart Launcher**: VRAM-aware auto-mode selection (HighVram/Default/LowVram).

### Changed
- **Entry Points**: Radically simplified root directory; all operations consolidated into the unified CLI.
- **SSA Enforcement**: Purged ALL hardcoded Python versions and wheel keys. Dynamically driven by `config.psd1`.
- **Refactoring**: Standardized regex and version validation across Pester suites.
- **Security**: Hardened binary verification via SHA256 hashes and TLS 1.3 enforcement.

### Removed
- Legacy root scripts: `install.ps1`, `run.ps1`, `update.ps1`.
- Fragile regex-based configuration parsing in `validate.py`.
- Legacy `lib/core.psm1` (Decomposed).
- All duplicated version mappings and hardcoded paths.

## [0.1.0] - 2025-12-31

### Added
- **CI/CD**: 5 GitHub Actions workflows (ci, release, dependency-check, security-scan, stale)
- **Dependabot**: Automatic GitHub Actions updates
- **Templates**: Bug report, feature request, pull request templates
- **Configuration**: Centralized `config.psd1` with environment overrides
- **Module**: `lib/core.psm1` with reusable functions
- **Tests**: Comprehensive Pester test suite (55 tests)

### Changed
- **Refactor**: All PowerShell scripts (`install.ps1`, `update.ps1`, `run.ps1`, `core.psm1`) fully typed and analyzed.
- **Naming**: Renamed to "comfYa" throughout
- **Paths**: Dynamic resolution via `$PSScriptRoot` / `%~dp0` / `$env:COMFYUI_HOME`
- **Install**: Refactored to use config.psd1 for all settings
- **Launchers**: Now read from config for environment and launch args
- **GPU support**: Extended to RTX 20xx+ (Compute Capability 7.5+)
- **CI Tuning**: Optimized GitHub Actions workflows for speed and reliability.

### Fixed
- **CI/CD**: Resolved 99+ PSScriptAnalyzer issues and all Ruff linting errors in `validate.py`.
- **Pester**: Fixed all 55 tests including path resolution, variable scoping, and TLS enforcement logic.
- **DRY Violation**: Removed duplicated bootstrap functions from `install.ps1`.
- **Version Sync**: All version references unified
- **User-Agent**: Unified across all files via `config.UserAgent`
- **README**: Fixed invalid Release badge URL
- **run.ps1/run.bat**: Added `TORCH_COMPILE_BACKEND=inductor`

### Removed
- Unused Python imports and variables in `validate.py`.
- Redundant logic in `core.psm1`.
- Legacy `Invoke-Expression` calls for security.

### Security
- TLS 1.2+ enforcement
- `Invoke-SafeWebRequest` with retry logic
- CodeQL and TruffleHog in CI
- Pinned GitHub Actions to SHA

## [0.0.1-legacy] - 2025-12-30

### Added
- Initial installer prototype
- PyTorch Nightly, Triton, SageAttention support
- ComfyUI-Manager integration
