# comfYa - Logging Module Tests

BeforeAll {
    $Root = Join-Path $PSScriptRoot ".."
    Import-Module (Join-Path $Root "lib\Logging.psm1") -Force
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
        }
    }
    
    Context "Log Level Handling" {
        It "Should accept valid log levels" {
            { Write-ComfyLog -Message "Test" -Level INFO } | Should -Not -Throw
            { Write-ComfyLog -Message "Test" -Level DEBUG } | Should -Not -Throw
            { Write-ComfyLog -Message "Test" -Level WARN } | Should -Not -Throw
        }
    }
    
    Context "Write-Step Function" {
        It "Should execute without error" {
            { Write-Step -Phase "Test" -Step "Unit" -Message "Testing" } | Should -Not -Throw
        }
    }
    
    Context "Write-Fatal Function" {
        It "Should throw with message" {
            { Write-Fatal -Message "Test fatal error" } | Should -Throw "*Test fatal error*"
        }
    }
}
