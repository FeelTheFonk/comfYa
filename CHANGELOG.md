# Changelog

All notable changes to comfYa will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.3] - 2025-12-31
### Added
- **Recursive Placeholder Engine**: Expanded environment resolution to support nested and recursive `{Dir:Key}` placeholders in `config.psd1`.
- **Try/Finally Setup Guard**: Implementation of guaranteed post-install cleanup of temporary orchestration artifacts, even on failure.

### Changed
- **Architectural Purity (Cleaning)**: Consolidated `$InstallPath` resolution and elevation logic in the orchestrator to eliminate redundancy.
- **Module Hardening**: Centralized directory management in `Lifecycle.psm1` and moved environment syncing logic to `SystemUtils.psm1`.
- **Improved Visual Consistency**: Standardized Unicode symbol detection for superior cross-terminal feedback (VSCode, Windows Terminal).

### Fixed
- **Robust GPU Parsing**: Enhanced Compute Capability detection to handle localized decimal separators (e.g., European `8,9` format) without loss of precision.

## [0.2.2] - 2025-12-31
### Added
- **Automated Dependency Discovery**: Implementation of dynamic asset resolution via GitHub API for third-party components (SageAttention, Triton).
- **Environment Isolation**: Refined environment variable synchronization logic to minimize persistent system configuration changes.
- **Enhanced Diagnostics**: Deeper inspection of library integrity and directory permissions within the diagnostic framework.
- **Pre-flight Simulation**: Introduced a simulation mode to validate installation parameters without performing disk operations.
- **Sanitization Utility**: Added a dedicated command for secure environment cleanup and artifact removal.

### Changed
- **Initialization Sequence**: Optimized the startup flow to ensure administrative privilege verification occurs prior to persistent logging or bridge exportation.
- **Sandbox Logging**: Implemented a temporary logging mechanism for early initialization phases to improve error traceability.
- **Update Logic**: Refined the repository synchronization process to prevent accidental overwriting of local changes.

### Fixed
- **Localized Parsing**: Integrated culture-independent numeric parsing to ensure reliability on systems with international decimal separators.

## [0.2.1] - 2025-12-31

### Added
- **Pinnacle Architecture (SSA)**: Zero-gap configuration bridge via `config.psd1` ensuring absolute PowerShell/Python synchronization.
- **Security Hardening**: Automated Windows Defender exclusions and enforced TLS 1.3 for all secure downloads.
- **Diagnostic Engine**: New `doctor` framework with structured `[OK/FAIL]` checks and professional diagnostic output.
- **Pinnacle Visual System**: SOTA ANSI headers, standardized tabular alignment, and locale-independent hardware detection.
- **SageAttention 2.2**: Dynamic acceleration injection based on GPU Compute Capability and Python version.

### Changed
- **Modular Refactor**: Decomposed legacy scripts into hardened domain modules (`Nvidia`, `Logging`, `SystemUtils`, `Lifecycle`).
- **Unified CLI**: `comfya.ps1` now serves as the single-source orchestrator for all ComfyUI operations.
- **Hardware Intelligence**: Refactored detection logic to be fully locale-invariant (fixing international Windows edge cases).

### Fixed
- **Version Drift**: Eliminated all hardcoded version strings; all components now respect the central `config.psd1`.
- **PS 5.1 Compatibility**: Resolved attribute placement errors and UTF-8 symbol mangling in legacy hosts.

### Removed
- Legacy standalone scripts: `install.ps1`, `run.ps1`, `update.ps1`.
- Redundant logic/duplicated version mappings across the codebase.

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
