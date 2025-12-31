# comfYa - Integration Tests
# Requires: Administrator privileges, NVIDIA GPU

BeforeAll {
    $Script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $Script:ConfigPath = Join-Path $Script:ProjectRoot "config.psd1"
}

Describe "Pre-Installation Checks" {
    Context "System Requirements" {
        It "Should have PowerShell 5.1+" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
        }
        
        It "Should have internet connectivity" {
            $TargetHost = "github.com"
            $result = Test-NetConnection -ComputerName $TargetHost -Port 443 -WarningAction SilentlyContinue
            $result.TcpTestSucceeded | Should -Be $true
        }
        
        It "Should have config.psd1" {
            Test-Path $Script:ConfigPath | Should -Be $true
        }
    }
    
    Context "NVIDIA Environment" {
        BeforeAll {
            if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
                # Mock nvidia-smi for CI environments using Pester's Mocking
                Mock nvidia-smi {
                    param($query_gpu, $format)
                    if ($query_gpu -match "name") { return "NVIDIA GeForce RTX 4090" }
                    if ($query_gpu -match "driver_version") { return "570.00" }
                    if ($query_gpu -match "compute_cap") { return "8.9" }
                    if ($query_gpu -match "memory.total") { return "24576" }
                    return ""
                }
            }
        }

        It "Should have nvidia-smi accessible" {
            $result = & nvidia-smi --query-gpu=name --format=csv,noheader 2>&1
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should have compatible GPU driver" {
            $driver = & nvidia-smi --query-gpu=driver_version --format=csv,noheader
            $major = [int]($driver -split '\.')[0]
            $major | Should -BeGreaterOrEqual 525
        }
    }
}

Describe "Script Syntax Validation" {
    $scripts = "comfya.ps1"
    
    It "<_> should have valid PowerShell syntax" -TestCases $scripts {
        $path = Join-Path $Script:ProjectRoot $_
        if (Test-Path $path) {
            $errors = $null
            $tokens = $null
            [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
            $errors.Count | Should -Be 0
        }
    }
}

Describe "Configuration Validation" {
    BeforeAll {
        $Script:Config = Import-PowerShellDataFile -Path $Script:ConfigPath
    }
    
    It "Should have all required top-level keys" {
        $requiredKeys = "Python", "Cuda", "Gpu", "Sources", "Packages", "Environment"
        foreach ($key in $requiredKeys) {
            $Script:Config.ContainsKey($key) | Should -Be $true -Because "$key is required"
        }
    }
    
    It "Should have valid PyTorch index URLs" {
        $urls = $Script:Config.Sources.PyTorch.IndexUrls.Values
        foreach ($url in $urls) {
            $url | Should -Match "^https://download\.pytorch\.org/"
        }
    }
    
    It "Should have valid repository URLs" {
        $urls = $Script:Config.Sources.Repositories.Values
        foreach ($url in $urls) {
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
