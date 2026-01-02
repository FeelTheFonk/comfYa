# comfYa - System Utils Tests (Extended Coverage)
# H1/H2: Comprehensive coverage for SystemUtils.psm1 (was 18%)

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Logging.psm1") -Force
    Import-Module (Join-Path $Root "lib\SystemUtils.psm1") -Force
    $Script:Config = Import-PowerShellDataFile (Join-Path $Root "config.psd1")
}

Describe "SystemUtils Module" {
    $MockConfig = @{ Requirements = @{ MinPsVer = 5.1; MinRamGB = 16; MinDiskGB = 20 } }

    Context "Module Loading" {
        It "Should import successfully" {
            { Import-Module (Join-Path $PSScriptRoot "..\lib\SystemUtils.psm1") -Force } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $commands = Get-Command -Module SystemUtils
            $commands.Name | Should -Contain "Test-Administrator"
            $commands.Name | Should -Contain "Invoke-ElevatedRestart"
            $commands.Name | Should -Contain "Update-EnvironmentPath"
            $commands.Name | Should -Contain "Invoke-SafeWebRequest"
            $commands.Name | Should -Contain "Test-SystemRequirement"
            $commands.Name | Should -Contain "Export-ComfyConfig"
            $commands.Name | Should -Contain "Add-DefenderExclusion"
            $commands.Name | Should -Contain "Get-SecurePath"
            $commands.Name | Should -Contain "Resolve-ComfyEnvironment"
            $commands.Name | Should -Contain "Sync-ComfyEnvironment"
        }
    }

    Context "Test-Administrator" {
        It "Should verify PowerShell version" {
            Test-PowerShellVersion -Config $MockConfig | Should -Be $true
        }
        
        It "Should detect administrator privileges" {
            Test-Administrator | Should -BeOfType [bool]
        }
    }

    Context "Test-SystemRequirement" {
        It "Should return RAM and disk info" {
            $result = Test-SystemRequirement -Config $MockConfig
            $result.TotalRAM | Should -BeGreaterThan 0
            $result.FreeDisk | Should -BeGreaterThan 0
        }
    }

    Context "Get-SecurePath" {
        It "Should return null for non-existent path with non-existent parent" {
            $result = Get-SecurePath -Path "Z:\NonExistent\Path\$(Get-Random)"
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return path for existing directory" {
            $result = Get-SecurePath -Path $env:TEMP
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Be (Resolve-Path $env:TEMP).Path
        }
        
        It "Should validate write permission when requested" {
            $result = Get-SecurePath -Path $env:TEMP -RequireWrite
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle new path with existing parent" {
            $newPath = Join-Path $env:TEMP "comfya-test-new-$(Get-Random)"
            $result = Get-SecurePath -Path $newPath
            $result | Should -Be $newPath
        }
    }

    Context "Update-EnvironmentPath" {
        It "Should refresh environment path without error" {
            { Update-EnvironmentPath } | Should -Not -Throw
        }
    }

    Context "Export-ComfyConfig" {
        It "Should export config to JSON file" {
            $testPath = Join-Path $env:TEMP "comfya-config-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            Export-ComfyConfig -Config $Script:Config -InstallPath $testPath
            
            $jsonPath = Join-Path $testPath "config.json"
            Test-Path $jsonPath | Should -Be $true
            
            $loaded = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $loaded.Version | Should -Be $Script:Config.Version
            
            # Cleanup
            Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        It "Should skip write if content unchanged" {
            $testPath = Join-Path $env:TEMP "comfya-config-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            # First export
            Export-ComfyConfig -Config $Script:Config -InstallPath $testPath
            $jsonPath = Join-Path $testPath "config.json"
            $firstWrite = (Get-Item $jsonPath).LastWriteTime
            
            Start-Sleep -Milliseconds 100
            
            # Second export (should skip)
            Export-ComfyConfig -Config $Script:Config -InstallPath $testPath
            $secondWrite = (Get-Item $jsonPath).LastWriteTime
            
            $secondWrite | Should -Be $firstWrite
            
            # Cleanup
            Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Resolve-ComfyEnvironment" {
        It "Should resolve environment placeholders" {
            $testPath = "C:\TestInstall"
            $result = Resolve-ComfyEnvironment -Config $Script:Config -InstallPath $testPath
            
            $result | Should -BeOfType [hashtable]
            $result.TRITON_CACHE_DIR | Should -Match $testPath.Replace('\', '/')
        }
    }

    Context "Sync-ComfyEnvironment" {
        It "Should set environment variables" {
            $envMap = @{ COMFYA_TEST_VAR = "test_value_$(Get-Random)" }
            Sync-ComfyEnvironment -EnvMap $envMap
            
            $env:COMFYA_TEST_VAR | Should -Be $envMap.COMFYA_TEST_VAR
            
            # Cleanup
            Remove-Item env:COMFYA_TEST_VAR -ErrorAction SilentlyContinue
        }
    }

    Context "Invoke-SafeWebRequest" {
        It "Should handle invalid URLs gracefully after retries" {
            { Invoke-SafeWebRequest -Uri "https://invalid.url.test.local/file" -UserAgent "test" -RetryCount 1 } | Should -Throw
        }
    }
}
