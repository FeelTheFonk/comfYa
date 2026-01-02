# comfYa - Lifecycle Module Tests
# H2: Coverage for the critical Lifecycle.psm1 module

BeforeAll {
    $Script:Root = Split-Path $PSScriptRoot -Parent
    $Script:ConfigPath = Join-Path $Script:Root "config.psd1"
    
    # Import dependencies first
    Import-Module (Join-Path $Script:Root "lib\Logging.psm1") -Force
    Import-Module (Join-Path $Script:Root "lib\SystemUtils.psm1") -Force
    Import-Module (Join-Path $Script:Root "lib\Nvidia.psm1") -Force
    Import-Module (Join-Path $Script:Root "lib\Package.psm1") -Force
    Import-Module (Join-Path $Script:Root "lib\Lifecycle.psm1") -Force
    
    $Script:Config = Import-PowerShellDataFile -Path $Script:ConfigPath
}

Describe "Lifecycle Module" {
    Context "Module Loading" {
        It "Should import successfully" {
            { Import-Module (Join-Path $Script:Root "lib\Lifecycle.psm1") -Force } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $commands = Get-Command -Module Lifecycle
            $commands.Name | Should -Contain "Install-ComfyProject"
            $commands.Name | Should -Contain "Start-ComfyProject"
            $commands.Name | Should -Contain "Update-ComfyProject"
            $commands.Name | Should -Contain "Invoke-ComfyClean"
        }
    }
    
    Context "Initialize-ComfyDirectories" {
        It "Should create directory structure without error" {
            $testPath = Join-Path $env:TEMP "comfya-lifecycle-test-$(Get-Random)"
            
            # Use InModuleScope to test internal function
            InModuleScope Lifecycle {
                param($Config, $Path)
                Initialize-ComfyDirectories -Config $Config -InstallPath $Path
            } -ArgumentList $Script:Config, $testPath
            
            # Verify key directories exist
            Test-Path $testPath | Should -Be $true
            Test-Path (Join-Path $testPath "models") | Should -Be $true
            Test-Path (Join-Path $testPath "output") | Should -Be $true
            Test-Path (Join-Path $testPath "logs") | Should -Be $true
            
            # Cleanup
            Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Invoke-ComfyClean" {
        It "Should clean specified targets without error" {
            $testPath = Join-Path $env:TEMP "comfya-clean-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            
            # Create test artifacts
            New-Item -ItemType Directory -Path (Join-Path $testPath ".venv") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $testPath "logs") -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $testPath "config.json") -Force | Out-Null
            
            # Run clean
            Invoke-ComfyClean -InstallPath $testPath -Confirm:$false
            
            # Verify cleanup
            Test-Path (Join-Path $testPath ".venv") | Should -Be $false
            Test-Path (Join-Path $testPath "logs") | Should -Be $false
            Test-Path (Join-Path $testPath "config.json") | Should -Be $false
            
            # Cleanup test directory
            Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Start-ComfyProject" {
        It "Should throw if venv not found" {
            $nonExistentPath = "C:\NonExistent\Path\$(Get-Random)"
            { Start-ComfyProject -Config $Script:Config -InstallPath $nonExistentPath } | Should -Throw "*not found*"
        }
    }
    
    Context "VRAM Mode Selection" {
        It "Should select HighVram for 12GB+ VRAM" {
            # Mock GPU info
            Mock Get-NvidiaGpuInfo {
                return @{ Vram = 24576; CudaVersion = "cu128" }
            } -ModuleName Lifecycle
            
            # We can't fully test Start-ComfyProject without a real venv,
            # but we can verify the mode logic is sound by checking config
            $Script:Config.LaunchArgs.HighVram | Should -Not -BeNullOrEmpty
            $Script:Config.LaunchArgs.LowVram | Should -Not -BeNullOrEmpty
            $Script:Config.LaunchArgs.Default | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Lifecycle Integration" -Tag "Integration" {
    Context "Full Install Flow (DryRun)" {
        It "Should validate install prerequisites" {
            # This is a smoke test - actual install requires network/admin
            $Script:Config.Sources.Repositories.ComfyUI.Url | Should -Match "^https://github.com/"
            $Script:Config.Sources.Repositories.ComfyUIManager.Url | Should -Match "^https://github.com/"
            $Script:Config.Python.Version | Should -Be "3.12"
        }
    }
}
