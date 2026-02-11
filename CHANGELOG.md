# Changelog

All notable changes to comfYa will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
				
## [0.3.0] - 2026-02-11
### Added
- **CI/CD Security**: Integrated `ruff` with Bandit rules (S-series) for immediate security feedback in PRs.
- **Robust Scanning**: fallback mechanisms for `security-scan` workflow to support private repositories without GHAS.

### Changed
- **Release Optimization**: Lightweight release artifact (excluded documentation and tests) for faster deployment.
- **Dependency Checks**: ongoing updates to `dependency-check.yml`.

### Fixed
- **CI/CD**: Resolved CodeQL "Code Scanning not enabled" failure by adding graceful error handling.

## [0.2.8] - 2026-01-02
### Added
- **Orchestrator Tests**: New `comfya.Tests.ps1` with 10 tests covering CLI parameter validation, module dependencies, command routing, and security checks.
- **Python Validator Tests**: New `test_validate.py` with pytest tests for `validate.py` logic (config bridge, version checks, directories).
- **Extended Config Schema Tests**: Added 20+ tests in `config.Tests.ps1` covering Diagnostics, Requirements, Sources, LaunchArgs, and Packages sections.
- **Known Limitations Section**: Added clear scope documentation in README (Windows-only, NVIDIA-only, RTX 20xx+).
- **Complete SageAttention Fallbacks**: Added 6 fallback wheel URLs (cu121/cu124/cu128 × py311/py312).

### Changed
- **PowerShell Version Check**: `Test-PowerShellVersion` now correctly compares Major.Minor version instead of Major only.
- **ARCHITECTURE.md Mermaid**: Added missing `Lifecycle → Logging` dependency in diagram.
- **docs/README.md**: Synchronized environment variables table with main README (7 variables).
- **Security Documentation**: Expanded hash verification notes in `config.psd1` with risk assessment.

### Fixed
- **C1**: README.md example version drift (0.2.6 → 0.2.7).
- **C2**: Removed `__pycache__/` directory from project root.
- **I1**: `bug_report.yml` placeholder referenced deleted `install.ps1` script.
- **I2**: `TROUBLESHOOTING.md` used `python` instead of `.venv\Scripts\python.exe`.
- **T4**: CI workflow now excludes `Integration` tagged tests to prevent GPU-requiring tests from failing in headless CI.

## [0.2.7] - 2026-01-02
### Added
- **Extended Nvidia Tests**: Comprehensive test coverage for `Nvidia.psm1` (15%→75%) with 14 tests covering driver mapping, SM architecture, i18n parsing, multi-GPU selection.
- **Install-Uv Tests**: Added 3 tests for `Install-Uv` function in `Package.Tests.ps1`.
- **TLS 1.3 Fallback**: Graceful fallback to TLS 1.2 for systems without TLS 1.3 support.

### Changed
- **SSA-Compliant Validation**: `validate.py` now reads core packages from `config.json` instead of hardcoded list.
- **Mermaid Diagram**: Updated `ARCHITECTURE.md` to show Package/Nvidia module dependencies to Lifecycle.
- **Documentation Alignment**: Updated `docs/README.md` config table with Logging/Diagnostics/Security sections.

### Fixed
- **C1**: `bug_report.yml` referenced deleted scripts (`install.ps1`, `run.ps1`, `update.ps1`) - updated to current CLI commands.
- **C2**: `ci.yml` shell inconsistency in PS 5.1 matrix - Install Pester step now uses conditional shell.
- **Q2**: `CHANGELOG.md` referenced deleted `core.psm1` file.
- **Q3**: `Package.psm1` used incorrect PowerShell invocation with invalid `/S` parameter.
- **Q6**: `Nvidia.psm1` had `$invCulture` declared inside loop - moved outside for optimization.
- **T5**: `config.Tests.ps1` used fragile `$_` in TestCases - fixed to use explicit named parameter.
- **D4**: `TROUBLESHOOTING.md` referenced `python` instead of `.venv\Scripts\python.exe`.
- **D6**: `CONTRIBUTING.md` Pester install missing `-MinimumVersion 5.0`.

## [0.2.6] - 2026-01-02
### Added
- **Extended Test Coverage**: Comprehensive tests for `SystemUtils.psm1` (18%→80%), `Logging.psm1` (50%→90%), `Package.psm1` (43%→80%).
- **Test-UvAvailability Export**: Function now exported from `Lifecycle.psm1` for external testability.
- **.gitkeep Files**: Created placeholder files for `models/`, `output/`, `input/`, `logs/` directories.
- **Environment Docs**: Added `CUDA_PATH` and `HTTP_PROXY`/`HTTPS_PROXY` to README.

### Changed
- **Strict Python Validation**: `validate.py` now respects `StrictVersion` config setting and checks `MinVersion`/`MaxVersion` range.
- **SSA Hardening**: Removed hardcoded DLL fallback array from `doctor` command; config-only enforcement.

### Fixed
- **C1**: README example version drift (0.2.4→0.2.5).
- **C4**: `Get-SecurePath` dead code path when testing write on non-existent paths.
- **H3**: Added `$LASTEXITCODE` verification after `git merge` and `git fetch` operations.
- **H5**: Python version validation now fails correctly when `StrictVersion=true` and version mismatches.
- **M5**: Validator path resolution corrected from `$PSScriptRoot` (lib/) to project root.

## [0.2.5] - 2026-01-02
### Added
- **Lifecycle.Tests.ps1**: New comprehensive test coverage for the Lifecycle module (8 tests).
- **Enhanced validate.py**: Added 4 new validation tests (Python version, directories, core packages, config bridge).
- **Diagnostics Section**: New `config.psd1` section for CUDA DLLs and diagnostic settings.
- **PS 5.1 CI Matrix**: CI now tests on both PowerShell 5.1 and 7 for compatibility verification.

### Changed
- **SOTA Exit Code Handling**: All external calls (`uv`, `git`) now verify `$LASTEXITCODE` (20 calls hardened).
- **Robust GPU Parsing**: Enhanced `Get-NvidiaGpuInfo` with better locale handling and error recovery.
- **Non-Invasive Header**: Removed `Clear-Host` from `Show-ComfyHeader` to preserve terminal history.
- **UTF-8 Compliance**: `Export-ComfyConfig` now writes UTF-8 without BOM for JSON compatibility.
- **SSA Compliance**: Externalized hardcoded DLL list to config; removed version from `run.bat`.

### Fixed
- **C1**: Silent failures from external commands now throw/warn appropriately.
- **C2**: Sandbox logging race condition resolved by separating sandbox state.
- **C4**: GPU parsing handles comma-decimal locales and malformed output.
- **C5**: `$ValidatedPath` is now actually used after validation.
- **H12**: PS 5.1 UTF-8 BOM issue fixed using .NET fallback.

### Security
- Documented hash verification strategy for dynamic installers (VCRedist, uv) in config.

## [0.2.4] - 2026-01-01
### Added
- **Install-SageAttention**: Centralized function in `Package.psm1` eliminating code duplication.
- **Pre-Release Validation**: Release workflow now validates CI before creating releases.
- **Path Validation**: `comfya.ps1` now validates `$InstallPath` is writable before setup.

### Changed
- **SSA Enforcement**: Removed hardcoded version in `Invoke-SafeWebRequest`; now requires explicit `UserAgent` parameter.
- **Security Hardening**: TruffleHog action pinned by SHA for maximum supply-chain security.
- **Update-ComfyProject**: Added `Test-UvAvailability` pre-check for consistency with install flow.

### Fixed
- **Numbering**: Corrected duplicate step numbering in `comfya.ps1` (# 3 → # 4).
- **Documentation**: Fixed unclosed markdown code block in `TROUBLESHOOTING.md`.
- **CHANGELOG**: Removed reference to deleted `lib/core.psm1`.
- **README**: Removed undocumented environment variables (`COMFYUI_PYTHON_VERSION`, `COMFYUI_CUDA_VERSION`).
- **Clean Command**: `config.json` now properly cleaned by `Invoke-ComfyClean`.

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
- **Modules**: Domain-isolated modules in `lib/` directory
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
- Redundant logic in legacy modules (removed).
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
