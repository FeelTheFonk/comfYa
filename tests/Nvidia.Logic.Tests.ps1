# comfYa - Nvidia Logic Extreme Verification
# Tests detection across diverse hardware profiles and locales

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Nvidia.psm1") -Force
    $Script:Config = Import-PowerShellDataFile (Join-Path $Root "config.psd1")
}

Describe "Nvidia Module - Multi-Profile Logic" {
    Context "Localized Hardware Parsing [Step 8]" {
        It "Should handle comma-separated decimals (FR/DE/ES)" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "RTX 4090,570.00,8,9,24576" # Comma in CC
            } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.ComputeCapability | Should -Be 8.9
            $gpu.SmArch | Should -Be "sm89"
        }
    }

    Context "Hardware Profile Mapping" {
        $profiles = @(
            @{ Name = "RTX 2080 Ti"; CC = "7.5"; Vram = "11264"; ExpectedArch = "sm75" }
            @{ Name = "RTX 3090";    CC = "8.6"; Vram = "24576"; ExpectedArch = "sm86" }
            @{ Name = "RTX 4080";    CC = "8.9"; Vram = "16384"; ExpectedArch = "sm89" }
            @{ Name = "RTX 5090";    CC = "10.0"; Vram = "32768"; ExpectedArch = "sm100" }
        )

        It "Should correctly map <Name> to <ExpectedArch>" -TestCases $profiles {
            param($Name, $CC, $Vram, $ExpectedArch)
            
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "$Name,570.00,$CC,$Vram"
            } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.SmArch | Should -Be $ExpectedArch
        }
    }

    Context "CUDA Version Selection [Step 7]" {
        It "Should map driver 570+ to cu128" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "RTX 4090,570.12,8.9,24576"
            } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.CudaVersion | Should -Be "cu128"
        }
        
        It "Should fallback to cu121 for older driver 545" {
            Mock nvidia-smi {
                $global:LASTEXITCODE = 0
                return "RTX 4090,545.24,8.9,24576"
            } -ModuleName Nvidia
            
            $gpu = Get-NvidiaGpuInfo -Config $Script:Config
            $gpu.CudaVersion | Should -Be "cu121"
        }
    }
}
