# Architecture comfYa v0.2.1 (Pinnacle)

## Modern Modular Orchestrator

comfYa has evolved from a simple script collection into a high-performance modular orchestrator designed for absolute consistency and peak hardware utilization.

### Structural Overview

```mermaid
graph TD
    CLI[comfya.ps1 - Orchestrator] --> L[lib/Logging.psm1]
    CLI --> N[lib/Nvidia.psm1]
    CLI --> S[lib/SystemUtils.psm1]
    CLI --> P[lib/Package.psm1]
    CLI --> Life[lib/Lifecycle.psm1]

    subgraph "Single Source of Truth"
        ConfigPSD[(config.psd1)]
        ConfigJSON[(config.json)]
        CLI -.-> ConfigPSD
        ConfigPSD -- "Export" --> ConfigJSON
    end

    Life --> Setup[Install-ComfyProject]
    Life --> Run[Start-ComfyProject]
    Life --> Update[Update-ComfyProject]
    CLI --> Doctor[validate.py]
    
    Doctor -.-> ConfigJSON
```

### Core Principles

1.  **SSA (Single Source of Truth)**: No hardcoded version mappings. If `config.psd1` says CUDA 12.8, the entire stack (PowerShell & Python) respects it. Includes a **Recursive Placeholder Engine** (`{Dir:Key}`) for zero-redundancy pathing.
2.  **Domain Isolation**: GPU logic is isolated from OS logic, which is isolated from logging. This ensures "Pro" grade maintainability.
3.  **Proactive DX (Developer Experience)**:
    - **Smart Launcher**: Automatically detects VRAM and **picks the best GPU** on multi-GPU systems.
    - **Self-Healing**: `doctor` command can reconstruct environments and fix common dependency failures.
4.  **Hardware Invariance**: Detection logic is **locale-independent**, ensuring perfect parsing on any Windows international configuration.
5.  **Security Hardened**: Downloads (uv, VC++ Redist) are verified via SHA256 hashes, and TLS 1.3 is enforced.

---

### Module Responsibilities

| Module | Responsibility | Key Features |
| :--- | :--- | :--- |
| **Nvidia.psm1** | Hardware Intel | Locale-Invariant CC Detection, Multi-GPU Auto-selection |
| **Logging.psm1** | Truth Stream | Structured ANSI output, Automated Log Rotation |
| **SystemUtils.psm1** | Environment | Pre-flight checks, Secure Downloads, Registry |
| **Package.psm1** | Dependency Mgmt | Side-loading `uv`, `git` and binary redistributables |

---

## Performance Stack (SOTA)

-   **PyTorch Nightly**: Direct access to inductive optimizations.
-   **Triton-Windows**: JIT-compiled attention kernels.
-   **SageAttention 2.1**: Dynamic wheel injection for Ada/Blackwell architectures.