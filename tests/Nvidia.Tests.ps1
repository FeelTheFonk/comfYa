# comfYa - Nvidia Module Tests
# Requires Pester

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Nvidia.psm1") -Force
}

Describe "Nvidia Module" {
    Context "Get-NvidiaGpuInfo" {
        It "Should throw if nvidia-smi is missing" {
            # Mocking Get-Command to fail
            Mock Get-Command { return $null } -ModuleName Nvidia
            { Get-NvidiaGpuInfo -Config $Config } | Should -Throw "*nvidia-smi not found*"
        }
    }
}
