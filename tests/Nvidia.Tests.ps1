# comfYa - Nvidia Module Tests
# Requires Pester

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Nvidia.psm1") -Force
    $Script:Config = @{
        Gpu = @{ MinComputeCapability = 7.5 }
        Cuda = @{ PreferredVersion = "cu128" }
    }
}

Describe "Nvidia Module" {
    Context "Get-NvidiaGpuInfo" {
        It "Should throw if nvidia-smi is missing" {
            # Mocking Get-Command inside the Nvidia module to simulate missing driver
            Mock Get-Command { 
                param($Name)
                if ($Name -eq "nvidia-smi") { return $null }
                # For other calls, return actual (if needed) - but usually not needed for this test
            } -ModuleName Nvidia
            
            { Get-NvidiaGpuInfo -Config $Script:Config } | Should -Throw "*nvidia-smi not found*"
        }
    }
}
