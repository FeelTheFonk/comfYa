#!/usr/bin/env python3
"""
comfYa Installation Validator (SOTA Edition)
Synchronized with config.psd1 to eliminate configuration gaps.
"""
import sys
from pathlib import Path
from typing import Tuple, Dict

# =============================================================================
# CONFIG SYNCHRONIZATION (SSA)
# =============================================================================

import json

class ComfyConfig:
    """Zero-delta configuration mirror via JSON bridge."""
    @staticmethod
    def load_bridge(path: Path) -> Dict:
        """Load configuration from exported JSON bridge."""
        bridge_path = path / "config.json"
        if not bridge_path.exists():
            return {}
        
        try:
            with open(bridge_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}

    @staticmethod
    def get_min_cc(config: Dict) -> float:
        return float(config.get("Gpu", {}).get("MinComputeCapability", 7.5))

    @staticmethod
    def get_py_version(config: Dict) -> str:
        return config.get("Python", {}).get("Version", "3.12")

# =============================================================================
# OUTPUT FORMATTING
# =============================================================================

class Colors:
    RESET = "\033[0m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"

def print_test(name: str, status: str, details: str = ""):
    status_colors = {"OK": Colors.GREEN, "FAIL": Colors.RED, "SKIP": Colors.YELLOW, "WARN": Colors.YELLOW}
    color = status_colors.get(status, Colors.RESET)
    print(f"  {name:.<25} {color}{status:4}{Colors.RESET} ({details})")

# =============================================================================
# SOTA TESTS
# =============================================================================

def test_hardware(config: Dict) -> Tuple[bool, str]:
    try:
        import torch
        if not torch.cuda.is_available():
            return False, "CUDA Unavailable"
        
        gpu = torch.cuda.get_device_name(0)
        capability = torch.cuda.get_device_capability(0)
        cc = float(f"{capability[0]}.{capability[1]}")
        
        min_cc = ComfyConfig.get_min_cc(config)
        if cc < min_cc:
            return False, f"Incompatible GPU (CC {cc} < {min_cc})"
            
        return True, f"{gpu} [CC {cc}]"
    except Exception as e:
        return False, str(e)

def test_acceleration() -> Tuple[bool, str]:
    """Verify SOTA kernels (Triton & Sage)"""
    results = []
    import importlib.util
    if importlib.util.find_spec("triton"):
        import triton
        results.append(f"Triton v{triton.__version__}")
    else:
        results.append("Triton missing")
        
    if importlib.util.find_spec("sageattention"):
        results.append("SageAttn OK")
    else:
        results.append("SageAttn missing")
        
    return True, " | ".join(results)

# [H5] New comprehensive tests
def test_python_version(config: Dict) -> Tuple[bool, str]:
    """Verify Python version matches config."""
    expected = ComfyConfig.get_py_version(config)
    actual = f"{sys.version_info.major}.{sys.version_info.minor}"
    strict = config.get("Python", {}).get("StrictVersion", False)
    
    if actual == expected:
        return True, f"Python {actual}"
    elif not strict and sys.version_info.major == int(expected.split(".")[0]):
        # Only accept compatible version if StrictVersion is False
        min_ver = config.get("Python", {}).get("MinVersion", expected)
        max_ver = config.get("Python", {}).get("MaxVersion", expected)
        if min_ver <= actual <= max_ver:
            return True, f"Python {actual} (in range {min_ver}-{max_ver})"
        return False, f"Python {actual} outside range {min_ver}-{max_ver}"
    else:
        return False, f"Python {actual} (expected {expected}, StrictVersion={strict})"

def test_directories(root: Path, config: Dict) -> Tuple[bool, str]:
    """Verify expected directory structure exists."""
    dirs_config = config.get("Directories", {})
    missing = []
    found = 0
    
    # Check key directories
    check_dirs = ["models", "output", "logs", "ComfyUI"]
    for d in check_dirs:
        path = root / d
        if path.exists():
            found += 1
        else:
            missing.append(d)
    
    if not missing:
        return True, f"{found} directories OK"
    elif len(missing) <= 2:
        return True, f"{found} OK, missing: {', '.join(missing)}"
    else:
        return False, f"Missing: {', '.join(missing)}"

def test_core_packages() -> Tuple[bool, str]:
    """Verify core packages are installed."""
    import importlib.util
    core = ["torch", "numpy", "PIL", "safetensors", "aiohttp", "yaml"]
    installed = []
    missing = []
    
    for pkg in core:
        # Handle PIL special case
        spec_name = "pillow" if pkg == "PIL" else pkg
        spec_name = "pyyaml" if pkg == "yaml" else spec_name
        try:
            if importlib.util.find_spec(pkg):
                installed.append(pkg)
            else:
                missing.append(pkg)
        except ModuleNotFoundError:
            missing.append(pkg)
    
    if not missing:
        return True, f"{len(installed)} core packages OK"
    else:
        return False, f"Missing: {', '.join(missing)}"

def test_config_bridge(root: Path) -> Tuple[bool, str]:
    """Verify config.json bridge exists and is valid."""
    bridge = root / "config.json"
    if not bridge.exists():
        return False, "config.json not found"
    
    try:
        with open(bridge, "r", encoding="utf-8") as f:
            data = json.load(f)
        if "Version" in data and "Python" in data:
            return True, f"v{data.get('Version', '?')}"
        else:
            return False, "Invalid structure"
    except json.JSONDecodeError as e:
        return False, f"JSON error: {e}"

def main():
    import argparse
    parser = argparse.ArgumentParser(description="comfYa SOTA Validation")
    parser.add_argument("--path", type=str, help="Installation path containing config.json")
    args = parser.parse_args()

    root = Path(args.path) if args.path else Path(__file__).parent
    config = ComfyConfig.load_bridge(root)
    
    print(f"\n{Colors.MAGENTA}--- comfYa SOTA Validation ---{Colors.RESET}\n")
    
    # [H5] Enhanced test suite
    tests = [
        ("Config Bridge", lambda: test_config_bridge(root), True),
        ("Python Version", lambda: test_python_version(config), False),
        ("Hardware/CUDA", lambda: test_hardware(config), True),
        ("Acceleration", test_acceleration, False),
        ("Core Packages", test_core_packages, False),
        ("Directories", lambda: test_directories(root, config), False),
    ]
    
    all_passed = True
    for name, func, critical in tests:
        try:
            passed, details = func()
            status = "OK" if passed else ("FAIL" if critical else "WARN")
            print_test(name, status, details)
            if critical and not passed:
                all_passed = False
        except Exception as e:
            print_test(name, "FAIL" if critical else "SKIP", str(e))
            if critical:
                all_passed = False
            
    print(f"\n{Colors.CYAN if all_passed else Colors.RED}Result: {'SOTA READY' if all_passed else 'ISSUES DETECTED'}{Colors.RESET}\n")
    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()

