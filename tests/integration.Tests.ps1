# comfYa - Integration Tests
# Requires: Administrator privileges, NVIDIA GPU

BeforeAll {
    $Script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $Script:InstallScript = Join-Path $Script:ProjectRoot "install.ps1"
    $Script:ConfigPath = Join-Path $Script:ProjectRoot "config.psd1"
}

Describe "Pre-Installation Checks" {
    Context "System Requirements" {
        It "Should have PowerShell 5.1+" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
        }
        
        It "Should have internet connectivity" {
            $result = Test-NetConnection -ComputerName "github.com" -Port 443 -WarningAction SilentlyContinue
            $result.TcpTestSucceeded | Should -Be $true
        }
        
        It "Should have config.psd1" {
            Test-Path $Script:ConfigPath | Should -Be $true
        }
    }
    
    Context "NVIDIA Environment" -Skip:(-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
        It "Should have nvidia-smi accessible" {
            $result = & nvidia-smi --query-gpu=name --format=csv,noheader 2>&1
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should have compatible GPU driver" {
            $driver = & nvidia-smi --query-gpu=driver_version --format=csv,noheader
            $major = [int]($driver -split '\.')[0]
            $major | Should -BeGreaterOrEqual 525
        }
    }
}

Describe "Script Syntax Validation" {
    $scripts = @(
        "install.ps1",
        "run.ps1",
        "update.ps1"
    )
    
    foreach ($script in $scripts) {
        It "$script should have valid PowerShell syntax" {
            $path = Join-Path $Script:ProjectRoot $script
            if (Test-Path $path) {
                $errors = $null
                $tokens = $null
                [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
                $errors.Count | Should -Be 0
            }
        }
    }
}

Describe "Configuration Validation" {
    BeforeAll {
        $Script:Config = Import-PowerShellDataFile -Path $Script:ConfigPath
    }
    
    It "Should have all required top-level keys" {
        $requiredKeys = @("Python", "Cuda", "Gpu", "Sources", "Packages", "Environment")
        foreach ($key in $requiredKeys) {
            $Script:Config.ContainsKey($key) | Should -Be $true -Because "$key is required"
        }
    }
    
    It "Should have valid PyTorch index URLs" {
        foreach ($url in $Script:Config.Sources.PyTorch.IndexUrls.Values) {
            $url | Should -Match "^https://download\.pytorch\.org/"
        }
    }
    
    It "Should have valid repository URLs" {
        foreach ($url in $Script:Config.Sources.Repositories.Values) {
            $url | Should -Match "^https://github\.com/"
        }
    }
}

Describe "Dry Run Installation" -Tag "DryRun" {
    Context "Directory Structure" {
        It "Should be able to create test directory structure" {
            $testRoot = Join-Path $env:TEMP "comfyui-test-$(Get-Random)"
            
            $dirs = @(
                $testRoot,
                "$testRoot\models\checkpoints",
                "$testRoot\models\loras",
                "$testRoot\.triton_cache"
            )
            
            foreach ($dir in $dirs) {
                New-Item -ItemType Directory -Force -Path $dir | Out-Null
            }
            
            foreach ($dir in $dirs) {
                Test-Path $dir | Should -Be $true
            }
            
            # Cleanup
            Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
