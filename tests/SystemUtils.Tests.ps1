# comfYa - System Utils Tests

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\SystemUtils.psm1") -Force
}

Describe "SystemUtils Module" {
    $MockConfig = @{ Requirements = @{ MinPsVer = 5.1; MinRamGB = 16; MinDiskGB = 20 } }

    It "Should verify PowerShell version" {
        Test-PowerShellVersion -Config $MockConfig | Should -Be $true
    }
    
    It "Should detect administrator privileges" {
        Test-Administrator | Should -BeOfType [bool]
    }
}
