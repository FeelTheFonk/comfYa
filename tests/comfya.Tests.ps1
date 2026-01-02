# comfYa - Orchestrator CLI Tests
# T1: Coverage for the main comfya.ps1 CLI

BeforeAll {
    $Script:Root = Split-Path $PSScriptRoot -Parent
    $Script:ScriptPath = Join-Path $Script:Root "comfya.ps1"
    $Script:ConfigPath = Join-Path $Script:Root "config.psd1"
    $Script:Config = Import-PowerShellDataFile -Path $Script:ConfigPath
}

Describe "comfya.ps1 Orchestrator" {
    Context "Script Syntax" {
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $tokens = $null
            [System.Management.Automation.Language.Parser]::ParseFile($Script:ScriptPath, [ref]$tokens, [ref]$errors) | Out-Null
            $errors.Count | Should -Be 0
        }
    }
    
    Context "Parameter Validation" {
        It "Should accept valid commands" {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:ScriptPath, [ref]$null, [ref]$null)
            $params = $ast.ParamBlock.Parameters
            $commandParam = $params | Where-Object { $_.Name.VariablePath.UserPath -eq "Command" }
            $commandParam | Should -Not -BeNull
        }
        
        It "Should have ValidateSet for Command parameter" {
            $content = Get-Content $Script:ScriptPath -Raw
            $content | Should -Match 'ValidateSet\("setup", "run", "doctor", "update", "clean"\)'
        }
        
        It "Should have ValidateSet for Mode parameter" {
            $content = Get-Content $Script:ScriptPath -Raw
            $content | Should -Match 'ValidateSet\("Auto", "Default", "HighVram", "LowVram", "Cpu"\)'
        }
    }
    
    Context "Module Dependencies" {
        It "Should reference all required modules" {
            $content = Get-Content $Script:ScriptPath -Raw
            $content | Should -Match "Logging\.psm1"
            $content | Should -Match "SystemUtils\.psm1"
            $content | Should -Match "Nvidia\.psm1"
            $content | Should -Match "Package\.psm1"
            $content | Should -Match "Lifecycle\.psm1"
        }
    }
    
    Context "Command Routing" {
        It "Should have switch statement for all commands" {
            $content = Get-Content $Script:ScriptPath -Raw
            $content | Should -Match '"setup"'
            $content | Should -Match '"run"'
            $content | Should -Match '"doctor"'
            $content | Should -Match '"update"'
            $content | Should -Match '"clean"'
        }
    }
    
    Context "Config Loading" {
        It "Should load config.psd1 at runtime" {
            $content = Get-Content $Script:ScriptPath -Raw
            $content | Should -Match 'Import-PowerShellDataFile.*config\.psd1'
        }
    }
    
    Context "Version Alignment" {
        It "Should display version from config" {
            $content = Get-Content $Script:ScriptPath -Raw
            $content | Should -Match 'Show-ComfyHeader.*\$Config\.Version'
        }
    }
}

Describe "comfya.ps1 Security" {
    Context "Path Validation" {
        It "Should validate InstallPath for write operations" {
            $content = Get-Content $Script:ScriptPath -Raw
            $content | Should -Match 'Get-SecurePath.*RequireWrite'
        }
    }
    
    Context "Elevation Check" {
        It "Should check for admin rights on setup" {
            $content = Get-Content $Script:ScriptPath -Raw
            $content | Should -Match 'Test-Administrator'
        }
    }
}
