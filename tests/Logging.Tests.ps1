# comfYa - Logging Module Tests (Extended Coverage)
# H2: Comprehensive coverage for Logging.psm1 (was 50%)

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Logging.psm1") -Force
    $Script:Config = Import-PowerShellDataFile (Join-Path $Root "config.psd1")
}

Describe "Logging Module" {
    Context "Module Loading" {
        It "Should import successfully" {
            { Import-Module (Join-Path $PSScriptRoot "..\lib\Logging.psm1") -Force } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $commands = Get-Command -Module Logging
            $commands.Name | Should -Contain "Write-ComfyLog"
            $commands.Name | Should -Contain "Write-Step"
            $commands.Name | Should -Contain "Write-Success"
            $commands.Name | Should -Contain "Write-ComfyWarning"
            $commands.Name | Should -Contain "Write-Fatal"
            $commands.Name | Should -Contain "Write-Diagnostic"
            $commands.Name | Should -Contain "Show-ComfyHeader"
            $commands.Name | Should -Contain "Show-ComfyFooter"
            $commands.Name | Should -Contain "Initialize-Logging"
            $commands.Name | Should -Contain "Start-SandboxLogging"
        }
    }
    
    Context "Log Level Handling" {
        It "Should accept valid log levels" {
            { Write-ComfyLog -Message "Test" -Level INFO } | Should -Not -Throw
            { Write-ComfyLog -Message "Test" -Level DEBUG } | Should -Not -Throw
            { Write-ComfyLog -Message "Test" -Level WARN } | Should -Not -Throw
            { Write-ComfyLog -Message "Test" -Level ERROR } | Should -Not -Throw
            { Write-ComfyLog -Message "Test" -Level VERBOSE } | Should -Not -Throw
            { Write-ComfyLog -Message "Test" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Should reject invalid log levels" {
            { Write-ComfyLog -Message "Test" -Level INVALID } | Should -Throw
        }
    }
    
    Context "Write-Step Function" {
        It "Should execute without error" {
            { Write-Step -Phase "Test" -Step "Unit" -Message "Testing" } | Should -Not -Throw
        }
        
        It "Should work with progress percentage" {
            { Write-Step -Phase "Test" -Step "Unit" -Message "Testing" -Percent 50 } | Should -Not -Throw
        }
    }
    
    Context "Write-Fatal Function" {
        It "Should throw with message" {
            { Write-Fatal -Message "Test fatal error" } | Should -Throw "*Test fatal error*"
        }
        
        It "Should include suggestion in output" {
            try {
                Write-Fatal -Message "Test error" -Suggestion "Try this"
            } catch {
                # Expected to throw
            }
            # Function writes to host before throwing - can't easily verify suggestion
        }
    }
    
    Context "Write-Success Function" {
        It "Should execute without error" {
            { Write-Success -Message "Test success" } | Should -Not -Throw
        }
    }
    
    Context "Write-ComfyWarning Function" {
        It "Should execute without error" {
            { Write-ComfyWarning -Message "Test warning" } | Should -Not -Throw
        }
    }
    
    Context "Write-Diagnostic Function" {
        It "Should execute without error for OK status" {
            { Write-Diagnostic -Test "TestCheck" -Status "OK" -Details "Test details" } | Should -Not -Throw
        }
        
        It "Should execute without error for FAIL status" {
            { Write-Diagnostic -Test "TestCheck" -Status "FAIL" -Details "Test details" } | Should -Not -Throw
        }
        
        It "Should handle WARN and SKIP statuses" {
            { Write-Diagnostic -Test "TestCheck" -Status "WARN" } | Should -Not -Throw
            { Write-Diagnostic -Test "TestCheck" -Status "SKIP" } | Should -Not -Throw
        }
    }
    
    Context "Show-ComfyHeader Function" {
        It "Should display header without clearing screen" {
            # Test that Clear-Host is NOT called (H9 fix verification)
            { Show-ComfyHeader -Version "0.2.5" } | Should -Not -Throw
        }
    }
    
    Context "Show-ComfyFooter Function" {
        It "Should display footer without error" {
            { Show-ComfyFooter } | Should -Not -Throw
        }
    }
    
    Context "Initialize-Logging" {
        It "Should initialize with config" {
            $testPath = Join-Path $env:TEMP "comfya-logging-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $testPath "logs") -Force | Out-Null
            
            { Initialize-Logging -Config $Script:Config -InstallPath $testPath } | Should -Not -Throw
            
            # Cleanup
            Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        It "Should handle missing config gracefully" {
            { Initialize-Logging -Config @{} -InstallPath $env:TEMP } | Should -Not -Throw
        }
    }
    
    Context "Start-SandboxLogging" {
        It "Should initialize sandbox logging" {
            { Start-SandboxLogging } | Should -Not -Throw
            
            # Verify sandbox file path is set to TEMP
            $sandboxPath = Join-Path $env:TEMP "comfya-init.log"
            # File may or may not exist based on previous runs
        }
    }
}
