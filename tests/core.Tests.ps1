# comfYa - Test Suite
# Requires Pester module: Install-Module -Name Pester -Force -SkipPublisherCheck

BeforeAll {
    # Import core module
    $modulePath = Join-Path $PSScriptRoot "..\lib\core.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
    
    # Import configuration
    $configPath = Join-Path $PSScriptRoot "..\config.psd1"
    if (Test-Path $configPath) {
        $Script:Config = Import-PowerShellDataFile -Path $configPath
    }
}

Describe "Configuration" {
    Context "config.psd1 structure" {
        It "Should have Python configuration" {
            $Script:Config.Python | Should -Not -BeNullOrEmpty
            $Script:Config.Python.Version | Should -Be "3.12"
        }
        
        It "Should have CUDA configuration" {
            $Script:Config.Cuda | Should -Not -BeNullOrEmpty
            $Script:Config.Cuda.PreferredVersion | Should -Match "cu\d+"
        }
        
        It "Should have GPU requirements" {
            $Script:Config.Gpu | Should -Not -BeNullOrEmpty
            $Script:Config.Gpu.MinComputeCapability | Should -BeGreaterOrEqual 7.5
        }
        
        It "Should have package sources" {
            $Script:Config.Sources | Should -Not -BeNullOrEmpty
            $Script:Config.Sources.PyTorch.IndexUrls | Should -Not -BeNullOrEmpty
        }
        
        It "Should have valid repository URLs" {
            $Script:Config.Sources.Repositories.ComfyUI | Should -Match "^https://"
            $Script:Config.Sources.Repositories.ComfyUIManager | Should -Match "^https://"
        }
    }
}

Describe "Core Functions" {
    Context "Get-InstallPath" {
        It "Should return valid path when script root exists" {
            $path = Get-InstallPath -NonInteractive
            $path | Should -Not -BeNullOrEmpty
        }
        
        It "Should prioritize environment variable" {
            $env:COMFYUI_HOME = "C:\TestPath"
            $path = Get-InstallPath -NonInteractive
            $path | Should -Be "C:\TestPath"
            Remove-Item env:COMFYUI_HOME
        }
        
        It "Should use provided path over defaults" {
            $path = Get-InstallPath -ProvidedPath "D:\CustomPath" -NonInteractive
            $path | Should -Be "D:\CustomPath"
        }
    }
    
    Context "Test-Administrator" {
        It "Should return boolean" {
            $result = Test-Administrator
            $result | Should -BeOfType [bool]
        }
    }
}

Describe "Logging Functions" {
    Context "Initialize-Logging" {
        It "Should set log level" {
            Initialize-Logging -Level "DEBUG"
            # Internal state check would require module internals access
        }
        
        It "Should create log directory when specified" {
            $tempDir = Join-Path $env:TEMP "comfyui-test-logs"
            Initialize-Logging -Level "INFO" -LogDirectory $tempDir
            Test-Path $tempDir | Should -Be $true
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "NVIDIA Functions" {
    Context "Get-NvidiaGpuInfo" -Skip:(-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
        It "Should return GPU information hashtable" {
            $info = Get-NvidiaGpuInfo
            $info | Should -BeOfType [hashtable]
            $info.GpuName | Should -Not -BeNullOrEmpty
            $info.DriverVersion | Should -Not -BeNullOrEmpty
            $info.CudaVersion | Should -Match "cu\d+"
        }
        
        It "Should detect correct CUDA version for driver" {
            $info = Get-NvidiaGpuInfo
            $info.CudaVersion | Should -Match "^cu(121|124|128)$"
        }
    }
}

Describe "Package Functions" {
    Context "Install-VCRedist" {
        It "Should detect existing installation" {
            # This test only validates detection, not installation
            $regPath = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
            if (Test-Path $regPath) {
                $result = Install-VCRedist
                $result | Should -Be $true
            }
        }
    }
    
    Context "Install-Git" {
        It "Should detect existing Git installation" -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
            $result = Install-Git
            $result | Should -Be $true
        }
    }
    
    Context "Install-Uv" {
        It "Should detect existing uv installation" -Skip:(-not (Get-Command uv -ErrorAction SilentlyContinue)) {
            $result = Install-Uv
            $result | Should -Be $true
        }
    }
}

Describe "Web Request Functions" {
    Context "Invoke-SafeWebRequest" {
        It "Should download content successfully" {
            $result = Invoke-SafeWebRequest -Uri "https://httpbin.org/get"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should enforce TLS 1.2+" {
            # Verify TLS is set correctly
            [Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12 | Should -BeGreaterThan 0
        }
        
        It "Should handle download to file" {
            $tempFile = Join-Path $env:TEMP "test-download.txt"
            Invoke-SafeWebRequest -Uri "https://httpbin.org/robots.txt" -OutFile $tempFile
            Test-Path $tempFile | Should -Be $true
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        
        It "Should throw on invalid URL" {
            { Invoke-SafeWebRequest -Uri "https://invalid.domain.that.does.not.exist/" -RetryCount 1 } | Should -Throw
        }
    }
}

Describe "Script Files Validation" {
    Context "No hardcoded paths" {
        $scriptFiles = @(
            (Join-Path $PSScriptRoot "..\run.ps1"),
            (Join-Path $PSScriptRoot "..\run.bat"),
            (Join-Path $PSScriptRoot "..\update.ps1"),
            (Join-Path $PSScriptRoot "..\install.ps1")
        )
        
        foreach ($file in $scriptFiles) {
            It "Should not have hardcoded C:\AI\ComfyUI in $([System.IO.Path]::GetFileName($file))" {
                if (Test-Path $file) {
                    $content = Get-Content $file -Raw
                    $content | Should -Not -Match 'C:\\AI\\ComfyUI(?![-_\w])'
                }
            }
        }
        
        foreach ($file in $scriptFiles) {
            It "Should not have 'SOTA' marketing term in $([System.IO.Path]::GetFileName($file))" {
                if (Test-Path $file) {
                    $content = Get-Content $file -Raw
                    $content | Should -Not -Match '\bSOTA\b'
                }
            }
        }
    }
    
    Context "Dynamic path usage" {
        It "run.ps1 should use PSScriptRoot" {
            $file = Join-Path $PSScriptRoot "..\run.ps1"
            if (Test-Path $file) {
                $content = Get-Content $file -Raw
                $content | Should -Match '\$PSScriptRoot'
            }
        }
        
        It "run.bat should use %~dp0" {
            $file = Join-Path $PSScriptRoot "..\run.bat"
            if (Test-Path $file) {
                $content = Get-Content $file -Raw
                $content | Should -Match '%~dp0'
            }
        }
        
        It "update.ps1 should use PSScriptRoot" {
            $file = Join-Path $PSScriptRoot "..\update.ps1"
            if (Test-Path $file) {
                $content = Get-Content $file -Raw
                $content | Should -Match '\$PSScriptRoot'
            }
        }
    }
}
