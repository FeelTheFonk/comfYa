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

def main():
    import argparse
    parser = argparse.ArgumentParser(description="comfYa SOTA Validation")
    parser.add_argument("--path", type=str, help="Installation path containing config.json")
    args = parser.parse_args()

    root = Path(args.path) if args.path else Path(__file__).parent
    config = ComfyConfig.load_bridge(root)
    
    if args.path and not config:
        print(f"{Colors.RED}Error: config.json not found in {args.path}{Colors.RESET}")
        sys.exit(1)
    
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
