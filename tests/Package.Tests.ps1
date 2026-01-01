# comfYa - Package Module Tests

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Logging.psm1") -Force
    Import-Module (Join-Path $Root "lib\SystemUtils.psm1") -Force
    Import-Module (Join-Path $Root "lib\Package.psm1") -Force
}

Describe "Package Module" {
    Context "Module Loading" {
        It "Should import successfully" {
            { Import-Module (Join-Path $PSScriptRoot "..\lib\Package.psm1") -Force } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $commands = Get-Command -Module Package
            $commands.Name | Should -Contain "Install-VCRedist"
            $commands.Name | Should -Contain "Install-Git"
            $commands.Name | Should -Contain "Install-Uv"
            $commands.Name | Should -Contain "Repair-Environment"
            $commands.Name | Should -Contain "Install-SageAttention"
        }
    }
    
    Context "Install-Git Function" {
        It "Should not throw when git is already installed" {
            if (Get-Command git -ErrorAction SilentlyContinue) {
                { Install-Git } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "Git not installed on this system"
            }
        }
        
        It "Should return boolean" {
            if (Get-Command git -ErrorAction SilentlyContinue) {
                $result = Install-Git
                $result | Should -BeOfType [bool]
            } else {
                Set-ItResult -Skipped -Because "Git not installed on this system"
            }
        }
    }
    
    Context "Get-LatestGithubRelease Function" {
        It "Should handle invalid URLs gracefully" {
            $result = Get-LatestGithubRelease -ApiUrl "https://invalid.url.test/api" -UserAgent "test"
            $result | Should -BeNullOrEmpty
        }
    }
}
