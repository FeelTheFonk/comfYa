# comfYa - System Utils Tests

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\SystemUtils.psm1") -Force
}

Describe "SystemUtils Module" {
    It "Should verify PowerShell version" {
        Test-PowerShellVersion | Should -Be $true
    }
    
    It "Should detect administrator privileges" {
        Test-Administrator | Should -BeOfType [bool]
    }
}
