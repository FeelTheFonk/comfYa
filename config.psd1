# comfYa - Configuration
# PowerShell Data File

@{
    # =============================================================================
    # METADATA
    # =============================================================================
    Version   = "0.2.7"
    Schema    = 1
    UserAgent = "comfYa/0.2.7"
    
    # =============================================================================
    # SYSTEM REQUIREMENTS
    # =============================================================================
    Requirements = @{
        MinRamGB   = 16
        MinDiskGB  = 20
        MinPsVer   = 5.1
    }

    # =============================================================================
    # PYTHON CONFIGURATION
    # =============================================================================
    Python = @{
        Version       = "3.12"
        StrictVersion = $true
        MinVersion    = "3.11"
        MaxVersion    = "3.12"
    }
    
    # =============================================================================
    # CUDA CONFIGURATION
    # =============================================================================
    Cuda = @{
        PreferredVersion = "cu128"
        FallbackVersions = @("cu124", "cu121")
        MinDriverVersion = 525
        
        # Driver to CUDA mapping (verified from NVIDIA documentation)
        DriverMapping = @{
            "570" = "cu128"
            "560" = "cu124"
            "545" = "cu121"
            "525" = "cu118"
        }
    }
    
    # =============================================================================
    # GPU REQUIREMENTS
    # =============================================================================
    Gpu = @{
        # Minimum compute capability (set to 7.5 for RTX 20xx support, 8.0 for 30xx, 8.9 for 40xx)
        MinComputeCapability = 7.5
        
        # SM Architecture mapping
        SmArchMapping = @{
            "7.5"  = "sm75"   # RTX 20xx (Turing)
            "8.0"  = "sm80"   # A100 (Ampere)
            "8.6"  = "sm86"   # RTX 30xx (Ampere consumer)
            "8.9"  = "sm89"   # RTX 40xx (Ada Lovelace)
            "10.0" = "sm100"  # RTX 50xx (Blackwell)
            "12.0" = "sm120"  # Future
        }
    }
    
    # =============================================================================
    # PACKAGE SOURCES
    # =============================================================================
    Sources = @{
        PyTorch = @{
            Channel = "nightly"
            IndexUrls = @{
                cu128 = "https://download.pytorch.org/whl/nightly/cu128"
                cu124 = "https://download.pytorch.org/whl/nightly/cu124"
                cu121 = "https://download.pytorch.org/whl/nightly/cu121"
            }
        }
        
        Repositories = @{
            ComfyUI = @{
                Url    = "https://github.com/comfyanonymous/ComfyUI.git"
                Branch = "master"
                Path   = "ComfyUI"
            }
            ComfyUIManager = @{
                Url    = "https://github.com/Comfy-Org/ComfyUI-Manager.git"
                Branch = "main"
                Path   = "ComfyUI/custom_nodes/ComfyUI-Manager"
            }
        }
        
        APIs = @{
            SageAttention = "https://api.github.com/repos/woct0rdho/SageAttention/releases/latest"
            TritonWindows = "https://api.github.com/repos/woct0rdho/triton-windows/releases/latest"
        }
        
        Dependencies = @{
            VCRedist     = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
            VCRedistHash = $null  # MS-signed binary, hash changes with updates
            Uv           = "https://astral.sh/uv/install.ps1"
            UvHash       = $null  # Dynamic installer script, verification not possible
        }
        
        # Fallback wheel URLs (updated periodically)
        FallbackWheels = @{
            SageAttention = @{
                cu128_py312 = "https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows/sageattention-2.2.0+cu128torch2.8.0-cp312-cp312-win_amd64.whl"
                cu124_py312 = "https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows/sageattention-2.2.0+cu124torch2.8.0-cp312-cp312-win_amd64.whl"
            }
        }
    }
    
    # =============================================================================
    # DIRECTORY STRUCTURE
    # =============================================================================
    Directories = @{
        # Relative to InstallPath
        Models = @{
            Root        = "models"
            Checkpoints = "models/checkpoints"
            Loras       = "models/loras"
            Vae         = "models/vae"
            Clip        = "models/clip"
            Controlnet  = "models/controlnet"
            Upscale     = "models/upscale_models"
        }
        Output      = "output"
        Input       = "input"
        Logs        = "logs"
        TritonCache = ".triton_cache"
        CustomNodes = "ComfyUI/custom_nodes"
    }
    
    # =============================================================================
    # ENVIRONMENT VARIABLES
    # =============================================================================
    Environment = @{
        CUDA_MODULE_LOADING      = "LAZY"
        PYTORCH_CUDA_ALLOC_CONF  = "expandable_segments:True"
        TRITON_CACHE_DIR         = "{InstallPath}/{Dir:TritonCache}"
        TORCH_COMPILE_BACKEND    = "inductor"
    }
    
    # =============================================================================
    # LAUNCH ARGUMENTS
    # =============================================================================
    LaunchArgs = @{
        Default = @(
            "--fast"
            "--use-sage-attention"
        )
        HighVram = @(
            "--fast"
            "--highvram"
            "--use-sage-attention"
        )
        LowVram = @(
            "--fast"
            "--lowvram"
            "--use-sage-attention"
        )
        Cpu = @(
            "--cpu"
        )
    }
    
    # =============================================================================
    # CORE PACKAGES
    # =============================================================================
    Packages = @{
        Core = @(
            "numpy"
            "einops"
            "safetensors"
            "aiohttp"
            "pillow"
            "scipy"
            "tqdm"
            "pyyaml"
        )
        ML = @(
            "accelerate"
            "transformers"
            "diffusers"
        )
        Optimization = @(
            "triton-windows"
            "torchao"
        )
        Optional = @(
            "kornia"
            "spandrel"
            "soundfile"
            "xformers"
        )
    }
    
    # =============================================================================
    # LOGGING
    # =============================================================================
    Logging = @{
        Level          = "INFO"  # DEBUG, INFO, WARN, ERROR
        FileEnabled    = $true
        FileName       = "install.log"
        MaxFileSizeMB  = 10
        RetainCount    = 5
        TimestampFormat = "yyyy-MM-dd HH:mm:ss.fff"
    }
    
    # =============================================================================
    # DIAGNOSTICS
    # =============================================================================
    Diagnostics = @{
        # CUDA DLLs to verify during doctor command
        CudaDLLs = @(
            "cudnn64_9.dll"   # cuDNN 9.x
            "cublas64_12.dll" # cuBLAS 12.x
            "cudnn64_8.dll"   # cuDNN 8.x (fallback)
            "cublas64_11.dll" # cuBLAS 11.x (fallback)
        )
    }
    
    # =============================================================================
    # SECURITY
    # =============================================================================
    Security = @{
        VerifyDownloads   = $true
        MinTlsVersion     = "Tls12"
        AllowPrerelease   = $true  # For nightly builds
        DefenderExclusion = $true
        # [C3] Hash Strategy Note: VCRedist and Uv hashes are dynamic/signed,
        # verification relies on HTTPS + publisher signatures
    }
}
