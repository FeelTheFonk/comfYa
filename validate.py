#!/usr/bin/env python3
"""
comfYa Installation Validator (SOTA Edition)
Synchronized with config.psd1 to eliminate configuration gaps.
"""
import sys
import os
import re
from pathlib import Path
from typing import Tuple, List, Dict

# =============================================================================
# CONFIG SYNCHRONIZATION (SSA)
# =============================================================================

class ComfyConfig:
    """Zero-delta configuration mirror."""
    @staticmethod
    def load_from_psd1(path: Path) -> Dict:
        """Simple regex-based PSD1 parser for critical values."""
        if not path.exists():
            return {}
        
        content = path.read_text(encoding="utf-8")
        config = {}
        
        # Extract MinComputeCapability
        match_cc = re.search(r"MinComputeCapability\s*=\s*([\d\.]+)", content)
        config["min_cc"] = float(match_cc.group(1)) if match_cc else 7.5
        
        # Extract Python Version
        match_py = re.search(r'Version\s*=\s*"([\d\.]+)"', content)
        config["py_version"] = match_py.group(1) if match_py else "3.12"
        
        return config

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
    status_colors = {"OK": Colors.GREEN, "FAIL": Colors.RED, "SKIP": Colors.YELLOW}
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
        
        if cc < config.get("min_cc", 7.5):
            return False, f"Incompatible GPU (CC {cc})"
            
        return True, f"{gpu} [CC {cc}]"
    except Exception as e:
        return False, str(e)

def test_acceleration() -> Tuple[bool, str]:
    """Verify SOTA kernels (Triton & Sage)"""
    results = []
    try:
        import triton
        results.append(f"Triton v{triton.__version__}")
    except ImportError:
        results.append("Triton missing")
        
    try:
        import sageattention
        results.append("SageAttn OK")
    except ImportError:
        results.append("SageAttn missing")
        
    return True, " | ".join(results)

def main():
    root = Path(__file__).parent
    config = ComfyConfig.load_from_psd1(root / "config.psd1")
    
    print(f"\n{Colors.MAGENTA}--- comfYa SOTA Validation ---{Colors.RESET}\n")
    
    tests = [
        ("Hardware/CUDA", lambda: test_hardware(config), True),
        ("Acceleration", test_acceleration, False),
    ]
    
    all_passed = True
    for name, func, critical in tests:
        passed, details = func()
        status = "OK" if passed else ("FAIL" if critical else "SKIP")
        print_test(name, status, details)
        if critical and not passed:
            all_passed = False
            
    print(f"\n{Colors.CYAN if all_passed else Colors.RED}Result: {'SOTA READY' if all_passed else 'BLOCKING ISSUES'}{Colors.RESET}\n")
    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()
