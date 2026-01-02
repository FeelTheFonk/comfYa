# comfYa - Configuration Tests
# Verifies the integrity of config.psd1

BeforeAll {
    $configPath = Join-Path $PSScriptRoot "..\config.psd1"
    if (Test-Path $configPath) {
        $Script:Config = Import-PowerShellDataFile -Path $configPath
    } else {
        Write-Error "CRITICAL: config.psd1 NOT FOUND at $configPath"
    }
}

Describe "Config Schema Integrity" {
    It "Should load as a hashtable" {
        $Script:Config | Should -Not -BeNull
        $Script:Config | Should -BeOfType [hashtable]
    }

    Context "Metadata" {
        It "Should have a valid Version string" {
            $Script:Config.Version | Should -Match "^\d+\.\d+\.\d+(-[A-Z]+)?$"
        }
        It "Should have a Schema version" {
            $Script:Config.Schema | Should -BeOfType [int]
        }
        It "Should have a UserAgent matching Version" {
            $Script:Config.UserAgent | Should -Match $Script:Config.Version
        }
    }

    Context "Mandatory Sections" {
        $sections = @(
            @{ Section = "Python" }
            @{ Section = "Cuda" }
            @{ Section = "Gpu" }
            @{ Section = "Sources" }
            @{ Section = "Directories" }
            @{ Section = "Environment" }
            @{ Section = "LaunchArgs" }
            @{ Section = "Packages" }
            @{ Section = "Logging" }
            @{ Section = "Security" }
        )
        It "Should contain section: <Section>" -TestCases $sections {
            param($Section)
            $Script:Config.ContainsKey($Section) | Should -Be $true
        }
    }

    Context "Python Configuration" {
        It "Should specify Python 3.12" {
            $Script:Config.Python.Version | Should -Be "3.12"
        }
        It "Should have strict versioning enabled" {
            $Script:Config.Python.StrictVersion | Should -Be $true
        }
    }

    Context "NVIDIA Configuration" {
        It "Should have preferred cu128" {
            $Script:Config.Cuda.PreferredVersion | Should -Be "cu128"
        }
        It "Should have fallback versions" {
            $Script:Config.Cuda.FallbackVersions | Should -Not -BeNullOrEmpty
        }
        It "Should have SM architecture mapping for RTX 20/30/40/50" {
            $Script:Config.Gpu.SmArchMapping.ContainsKey("7.5") | Should -Be $true # 20xx
            $Script:Config.Gpu.SmArchMapping.ContainsKey("8.6") | Should -Be $true # 30xx
            $Script:Config.Gpu.SmArchMapping.ContainsKey("8.9") | Should -Be $true # 40xx
            $Script:Config.Gpu.SmArchMapping.ContainsKey("10.0") | Should -Be $true # 50xx
        }
    }

    Context "Directory Structure" {
        It "Should have models root" {
            $Script:Config.Directories.Models.Root | Should -Be "models"
        }
    }
    
    Context "Diagnostics Section" {
        It "Should have Diagnostics section" {
            $Script:Config.ContainsKey("Diagnostics") | Should -Be $true
        }
        It "Should have CudaDLLs list" {
            $Script:Config.Diagnostics.CudaDLLs | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Requirements Section" {
        It "Should have Requirements section" {
            $Script:Config.ContainsKey("Requirements") | Should -Be $true
        }
        It "Should specify MinRamGB" {
            $Script:Config.Requirements.MinRamGB | Should -BeGreaterThan 0
        }
        It "Should specify MinDiskGB" {
            $Script:Config.Requirements.MinDiskGB | Should -BeGreaterThan 0
        }
        It "Should specify MinPsVer" {
            $Script:Config.Requirements.MinPsVer | Should -BeGreaterOrEqual 5.1
        }
    }
    
    Context "Sources Structure" {
        It "Should have PyTorch IndexUrls for all CUDA versions" {
            $Script:Config.Sources.PyTorch.IndexUrls.ContainsKey("cu128") | Should -Be $true
            $Script:Config.Sources.PyTorch.IndexUrls.ContainsKey("cu124") | Should -Be $true
            $Script:Config.Sources.PyTorch.IndexUrls.ContainsKey("cu121") | Should -Be $true
        }
        It "Should have valid repository URLs" {
            $Script:Config.Sources.Repositories.ComfyUI.Url | Should -Match "^https://github.com/"
            $Script:Config.Sources.Repositories.ComfyUIManager.Url | Should -Match "^https://github.com/"
        }
        It "Should have API URLs for dynamic resolution" {
            $Script:Config.Sources.APIs.SageAttention | Should -Match "^https://api.github.com/"
        }
    }
    
    Context "LaunchArgs Profiles" {
        It "Should have all VRAM profiles" {
            $Script:Config.LaunchArgs.ContainsKey("Default") | Should -Be $true
            $Script:Config.LaunchArgs.ContainsKey("HighVram") | Should -Be $true
            $Script:Config.LaunchArgs.ContainsKey("LowVram") | Should -Be $true
            $Script:Config.LaunchArgs.ContainsKey("Cpu") | Should -Be $true
        }
    }
    
    Context "Packages Structure" {
        It "Should have Core packages list" {
            $Script:Config.Packages.Core | Should -Not -BeNullOrEmpty
        }
        It "Should have ML packages list" {
            $Script:Config.Packages.ML | Should -Not -BeNullOrEmpty
        }
        It "Should have Optimization packages" {
            $Script:Config.Packages.Optimization | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Version Synchronization" {
    BeforeAll {
        $Script:Root = Split-Path $PSScriptRoot -Parent
        $Script:Config = Import-PowerShellDataFile -Path (Join-Path $Script:Root "config.psd1")
    }
    
    Context "Version Consistency Across Files" {
        It "Should have UserAgent containing Version" {
            $Script:Config.UserAgent | Should -Match $Script:Config.Version
        }
        
        It "Should have README title matching Version" {
            $readme = Get-Content (Join-Path $Script:Root "README.md") -First 1
            $readme | Should -Match $Script:Config.Version
        }
        
        It "Should have ARCHITECTURE title matching Version" {
            $arch = Get-Content (Join-Path $Script:Root "ARCHITECTURE.md") -First 1
            $arch | Should -Match $Script:Config.Version
        }
    }
}
