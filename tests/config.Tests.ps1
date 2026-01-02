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
}
