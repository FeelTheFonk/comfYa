#!/usr/bin/env python3
"""
comfYa Installation Validator
Comprehensive post-installation validation tests.
"""
import sys
import os
from pathlib import Path
from typing import Tuple, List

# =============================================================================
# CONFIGURATION
# =============================================================================

class ValidationConfig:
    """Validation test configuration."""
    REQUIRED_TESTS = ["torch_cuda"]  # Tests that must pass
    OPTIONAL_TESTS = ["triton", "sageattention", "flashattention", "torchao", "comfyui"]
    
    # Minimum requirements
    MIN_CUDA_VERSION = "11.8"
    MIN_COMPUTE_CAPABILITY = 7.5

# =============================================================================
# OUTPUT FORMATTING
# =============================================================================

class Colors:
    """ANSI color codes for terminal output."""
    RESET = "\033[0m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    GRAY = "\033[90m"
    MAGENTA = "\033[95m"

def print_header():
    """Print validation header."""
    print()
    print(f"{Colors.MAGENTA}╔══════════════════════════════════════════════════════╗{Colors.RESET}")
    print(f"{Colors.MAGENTA}║          comfYa - Installation Validation            ║{Colors.RESET}")
    print(f"{Colors.MAGENTA}╚══════════════════════════════════════════════════════╝{Colors.RESET}")
    print()

def print_test(name: str, status: str, details: str = ""):
    """Print formatted test result."""
    status_color = {
        "OK": Colors.GREEN,
        "FAIL": Colors.RED,
        "WARN": Colors.YELLOW,
        "SKIP": Colors.GRAY
    }.get(status.split()[0], Colors.RESET)
    
    padding = "." * (25 - len(name))
    detail_str = f" ({details})" if details else ""
    print(f"  {name}{padding} {status_color}{status}{detail_str}{Colors.RESET}")

def print_summary(results: List[Tuple[str, bool, bool]]):
    """Print validation summary."""
    print()
    print("═" * 55)
    
    critical_passed = all(passed for name, passed, is_critical in results if is_critical)
    total_passed = sum(1 for _, passed, _ in results if passed)
    total = len(results)
    
    if critical_passed and total_passed == total:
        print(f"  {Colors.GREEN}RESULT: {total_passed}/{total} tests passed ✓{Colors.RESET}")
        print(f"  {Colors.GREEN}Installation validated successfully!{Colors.RESET}")
    elif critical_passed:
        print(f"  {Colors.YELLOW}RESULT: {total_passed}/{total} tests passed{Colors.RESET}")
        print(f"  {Colors.YELLOW}Core components OK. Some optional features unavailable.{Colors.RESET}")
    else:
        print(f"  {Colors.RED}RESULT: {total_passed}/{total} tests passed{Colors.RESET}")
        print(f"  {Colors.RED}Critical components failed. Installation incomplete.{Colors.RESET}")
    
    print("═" * 55)
    print()
    
    return critical_passed

# =============================================================================
# VALIDATION TESTS
# =============================================================================

def test_torch_cuda() -> Tuple[bool, str]:
    """
    Test PyTorch CUDA availability and GPU detection.
    This is a CRITICAL test - installation fails if this doesn't pass.
    """
    try:
        import torch
        
        if not torch.cuda.is_available():
            return False, "CUDA not available"
        
        if torch.cuda.device_count() == 0:
            return False, "No GPU detected"
        
        gpu_name = torch.cuda.get_device_name(0)
        cuda_version = torch.version.cuda
        torch_version = torch.__version__
        
        # Validate CUDA version
        cuda_major = int(cuda_version.split('.')[0])
        if cuda_major < 11:
            return False, f"CUDA {cuda_version} too old (need 11.8+)"
        
        # Validate compute capability
        capability = torch.cuda.get_device_capability(0)
        cc = float(f"{capability[0]}.{capability[1]}")
        if cc < ValidationConfig.MIN_COMPUTE_CAPABILITY:
            return False, f"Compute capability {cc} < {ValidationConfig.MIN_COMPUTE_CAPABILITY}"
        
        return True, f"{gpu_name}, CUDA {cuda_version}, PyTorch {torch_version}"
        
    except ImportError:
        return False, "PyTorch not installed"
    except Exception as e:
        return False, str(e)

def test_triton() -> Tuple[bool, str]:
    """
    Test Triton availability.
    Non-critical - performance will be reduced without it.
    """
    try:
        import triton
        import triton.language as tl
        return True, f"v{triton.__version__}"
    except ImportError:
        return False, "Not installed"
    except Exception as e:
        return False, str(e)

def test_sageattention() -> Tuple[bool, str]:
    """
    Test SageAttention with a minimal forward pass.
    Non-critical - will fall back to other attention implementations.
    """
    try:
        import torch
        from sageattention import sageattn
        
        # Minimal functional test
        with torch.no_grad():
            q = torch.randn(1, 8, 64, 64, device="cuda", dtype=torch.float16)
            k = torch.randn(1, 8, 64, 64, device="cuda", dtype=torch.float16)
            v = torch.randn(1, 8, 64, 64, device="cuda", dtype=torch.float16)
            out = sageattn(q, k, v)
            
            if out.shape != q.shape:
                return False, "Shape mismatch"
            
            # Verify output is valid
            if torch.isnan(out).any() or torch.isinf(out).any():
                return False, "Invalid output (NaN/Inf)"
        
        return True, "Functional"
        
    except ImportError:
        return False, "Not installed"
    except Exception as e:
        return False, str(e)

def test_torchao() -> Tuple[bool, str]:
    """
    Test TorchAO availability.
    Non-critical - provides quantization features.
    """
    try:
        import torchao
        version = getattr(torchao, '__version__', 'unknown')
        return True, f"v{version}"
    except ImportError:
        return False, "Not installed"
    except Exception as e:
        return False, str(e)

def test_comfyui() -> Tuple[bool, str]:
    """
    Test ComfyUI installation and critical imports.
    Non-critical for validation - may fail outside ComfyUI context.
    """
    try:
        # Priority 1: Environment variable
        if os.environ.get("COMFYUI_HOME"):
            comfyui_path = Path(os.environ["COMFYUI_HOME"]) / "ComfyUI"
        else:
            # Priority 2: Script directory
            script_dir = Path(__file__).parent.resolve()
            comfyui_path = script_dir / "ComfyUI"
        
        if not comfyui_path.exists():
            # Priority 3: Current directory
            comfyui_path = Path.cwd() / "ComfyUI"
        
        if not comfyui_path.exists():
            return False, "ComfyUI directory not found"
        
        main_py = comfyui_path / "main.py"
        if not main_py.exists():
            return False, "main.py not found"
        
        # Add to path for import test
        sys.path.insert(0, str(comfyui_path))
        
        try:
            # Test critical imports
            import nodes
            import folder_paths
            return True, "Imports OK"
        except Exception as e:
            return False, f"Import error: {e}"
        finally:
            # Clean up path
            if str(comfyui_path) in sys.path:
                sys.path.remove(str(comfyui_path))
                
    except Exception as e:
        return False, str(e)

def test_xformers() -> Tuple[bool, str]:
    """
    Test xFormers availability (fallback attention).
    Non-critical.
    """
    try:
        import xformers
        import xformers.ops
        version = getattr(xformers, '__version__', 'unknown')
        return True, f"v{version}"
    except ImportError:
        return False, "Not installed"
    except Exception as e:
        return False, str(e)

def test_flashattention() -> Tuple[bool, str]:
    """
    Test FlashAttention-2 availability.
    Non-critical.
    """
    try:
        import flash_attn
        version = getattr(flash_attn, '__version__', 'unknown')
        return True, f"v{version}"
    except ImportError:
        return False, "Not installed"
    except Exception as e:
        return False, str(e)

# =============================================================================
# MAIN EXECUTION
# =============================================================================

def run_tests() -> List[Tuple[str, bool, bool]]:
    """Run all validation tests."""
    tests = [
        ("PyTorch CUDA", test_torch_cuda, True),
        ("Triton", test_triton, False),
        ("SageAttention", test_sageattention, False),
        ("FlashAttention", test_flashattention, False),
        ("TorchAO", test_torchao, False),
        ("xFormers", test_xformers, False),
        ("ComfyUI", test_comfyui, False),
    ]
    
    results = []
    
    for name, test_func, is_critical in tests:
        label = f"[{'CRIT' if is_critical else 'OPT'}] {name}"
        print(f"  Testing {name}...", end="\r")
        
        passed, details = test_func()
        
        if passed:
            status = "OK"
        elif is_critical:
            status = "FAIL"
        else:
            status = "SKIP"
        
        print_test(name, status, details)
        results.append((name, passed, is_critical))
    
    return results

def main() -> int:
    """Main entry point."""
    print_header()
    
    results = run_tests()
    success = print_summary(results)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
