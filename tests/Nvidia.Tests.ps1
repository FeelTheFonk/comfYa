# comfYa - Nvidia Module Tests (Extended Coverage)
# Comprehensive coverage for Nvidia.psm1

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Nvidia.psm1") -Force
    $Script:Config = Import-PowerShellDataFile (Join-Path $Root "config.psd1")
}

Describe "Nvidia Module" {
    Context "Module Loading" {
        It "Should import successfully" {
            { Import-Module (Join-Path $PSScriptRoot "..\lib\Nvidia.psm1") -Force } | Should -Not -Throw
        }
        
        It "Should export Get-NvidiaGpuInfo function" {
            $commands = Get-Command -Module Nvidia
            $commands.Name | Should -Contain "Get-NvidiaGpuInfo"
        }
    }

    Context "Get-NvidiaGpuInfo - Error Handling" {
        It "Should throw if nvidia-smi is missing" {
            # Mock Get-Command to return $null when checking for nvidia-smi
            Mock Get-Command {
                param($Name, $ErrorAction)
                return $null
            } -ModuleName Nvidia -ParameterFilter { $Name -eq "nvidia-smi" }
            
            { Get-NvidiaGpuInfo -Config $Script:Config } | Should -Throw "*nvidia-smi not found*"
        }
    }

    Context "Driver Version Mapping" {
        It "Should map driver 570+ to cu128" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "RTX 4090,570.12,8.9,24576"
            } -ModuleName Nvidia
            Mock Get-Command { return @{ Source = "nvidia-smi" } } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.CudaVersion | Should -Be "cu128"
        }
        
        It "Should map driver 560-569 to cu124" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "RTX 4080,560.00,8.9,16384"
            } -ModuleName Nvidia
            Mock Get-Command { return @{ Source = "nvidia-smi" } } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.CudaVersion | Should -Be "cu124"
        }
        
        It "Should map driver 545-559 to cu121" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "RTX 4090,545.24,8.9,24576"
            } -ModuleName Nvidia
            Mock Get-Command { return @{ Source = "nvidia-smi" } } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.CudaVersion | Should -Be "cu121"
        }
    }

    Context "SM Architecture Mapping" {
        $profiles = @(
            @{ Name = "RTX 2080 Ti"; CC = "7.5"; Vram = "11264"; ExpectedArch = "sm75" }
            @{ Name = "RTX 3090";    CC = "8.6"; Vram = "24576"; ExpectedArch = "sm86" }
            @{ Name = "RTX 4090";    CC = "8.9"; Vram = "24576"; ExpectedArch = "sm89" }
            @{ Name = "RTX 5090";    CC = "10.0"; Vram = "32768"; ExpectedArch = "sm100" }
        )

        It "Should correctly map <Name> (CC <CC>) to <ExpectedArch>" -TestCases $profiles {
            param($Name, $CC, $Vram, $ExpectedArch)
            
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "$Name,570.00,$CC,$Vram"
            } -ModuleName Nvidia
            Mock Get-Command { return @{ Source = "nvidia-smi" } } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.SmArch | Should -Be $ExpectedArch
        }
    }

    Context "Compute Capability Validation" {
        It "Should reject GPU below minimum CC requirement" {
            $lowCCConfig = @{
                Gpu = @{ MinComputeCapability = 8.0; SmArchMapping = $Script:Config.Gpu.SmArchMapping }
                Cuda = $Script:Config.Cuda
            }
            
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "GTX 1080 Ti,570.00,6.1,11264"  # CC 6.1 < 8.0
            } -ModuleName Nvidia
            Mock Get-Command { return @{ Source = "nvidia-smi" } } -ModuleName Nvidia
            
            { Get-NvidiaGpuInfo -Config $lowCCConfig } | Should -Throw "*Incompatible GPU*"
        }
    }

    Context "Localized Parsing (Internationalization)" {
        It "Should handle comma-separated decimals (FR/DE/ES locales)" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "RTX 4090,570.00,8,9,24576"  # CC as 8,9 instead of 8.9
            } -ModuleName Nvidia
            Mock Get-Command { return @{ Source = "nvidia-smi" } } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.ComputeCapability | Should -Be 8.9
        }
    }

    Context "Multi-GPU Selection" {
        It "Should select GPU with highest compute capability" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return @"
RTX 3060,570.00,8.6,12288
RTX 4090,570.00,8.9,24576
"@
            } -ModuleName Nvidia
            Mock Get-Command { return @{ Source = "nvidia-smi" } } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.Name | Should -Be "RTX 4090"
            $gpu.ComputeCapability | Should -Be 8.9
        }
    }

    Context "VRAM Reporting" {
        It "Should correctly report VRAM in MB" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "RTX 4090,570.00,8.9,24576"
            } -ModuleName Nvidia
            Mock Get-Command { return @{ Source = "nvidia-smi" } } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.Vram | Should -Be 24576
        }
    }
}
