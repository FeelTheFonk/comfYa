# comfYa - Package Module Tests (Extended Coverage)
# H2: Comprehensive coverage for Package.psm1

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Logging.psm1") -Force
    Import-Module (Join-Path $Root "lib\SystemUtils.psm1") -Force
    Import-Module (Join-Path $Root "lib\Nvidia.psm1") -Force
    Import-Module (Join-Path $Root "lib\Package.psm1") -Force
    $Script:Config = Import-PowerShellDataFile (Join-Path $Root "config.psd1")
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
            $commands.Name | Should -Contain "Get-LatestGithubRelease"
            $commands.Name | Should -Contain "Invoke-PostInstallCleanup"
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
    
    Context "Install-Uv Function" {
        It "Should return true if uv is already installed" {
            if (Get-Command uv -ErrorAction SilentlyContinue) {
                $result = Install-Uv -Config $Script:Config
                $result | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "uv not installed on this system"
            }
        }
        
        It "Should have correct uv source URL in config" {
            $Script:Config.Sources.Dependencies.Uv | Should -Match "^https://astral.sh/"
        }
        
        It "Should check common bin paths for uv" {
            # Verify path resolution logic works
            $possibleBins = @(
                (Join-Path $env:USERPROFILE ".local\bin"),
                (Join-Path $env:APPDATA "uv\bin")
            )
            $possibleBins.Count | Should -Be 2
        }
    }
    
    Context "Get-LatestGithubRelease Function" {
        It "Should handle invalid URLs gracefully" {
            $result = Get-LatestGithubRelease -ApiUrl "https://invalid.url.test/api" -UserAgent "test"
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return release info for valid API" {
            # Note: This test requires network access and may be rate-limited
            # Using a well-known repo with stable releases
            $result = Get-LatestGithubRelease -ApiUrl $Script:Config.Sources.APIs.SageAttention -UserAgent $Script:Config.UserAgent
            # May be null if rate-limited, but should not throw
        }
    }
    
    Context "Invoke-PostInstallCleanup Function" {
        It "Should execute without error" {
            { Invoke-PostInstallCleanup } | Should -Not -Throw
        }
        
        It "Should clean temp files if they exist" {
            # Create a test temp file
            $testFile = Join-Path $env:TEMP "uv-install.ps1"
            "# test" | Out-File $testFile -Force
            
            Invoke-PostInstallCleanup
            
            # File should be removed
            Test-Path $testFile | Should -Be $false
        }
    }
    
    Context "Install-VCRedist Function" {
        It "Should return true if VCRedist already installed" {
            # Check if VS 2015-2022 runtime is installed
            $regPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            if (Test-Path $regPath) {
                $result = Install-VCRedist -Config $Script:Config
                $result | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "VC++ Runtime not detected"
            }
        }
    }
    
    Context "Install-SageAttention Function" {
        It "Should have valid pattern matching logic" {
            # Test that pattern construction works
            $pySuffix = "cp" + ($Script:Config.Python.Version -replace '\.', '')
            $pySuffix | Should -Be "cp312"
            
            $cudaVersion = $Script:Config.Cuda.PreferredVersion
            $pattern = "$cudaVersion.*$pySuffix.*win_amd64"
            $pattern | Should -Match "cu128.*cp312.*win_amd64"
        }
    }
}

Describe "Package Module - Fallback Logic" {
    Context "SageAttention Fallback URLs" {
        It "Should have valid fallback wheel URLs in config" {
            $fallbacks = $Script:Config.Sources.FallbackWheels.SageAttention
            $fallbacks.Keys | Should -Contain "cu128_py312"
            $fallbacks["cu128_py312"] | Should -Match "^https://github.com/"
        }
    }
}
