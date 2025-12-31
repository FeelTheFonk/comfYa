# comfYa - System Utilities Module
# Professional OS, FS and Network utilities

#Requires -Version 5.1

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-ElevatedRestart {
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters
    )
    
    if (Test-Administrator) { return $false }
    
    $hostExe = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh.exe" } else { "powershell.exe" }
    
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log "Elevating privileges using $hostExe for $ScriptPath..." -Level WARN
    } else {
        Write-Host "Elevating privileges..." -ForegroundColor Yellow
    }
    
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")
    foreach ($key in $Parameters.Keys) {
        $argList += "-$key"
        $argList += "`"$($Parameters[$key])`""
    }
    
    Start-Process $hostExe -Verb RunAs -ArgumentList $argList
    return $true
}

function Export-ComfyConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [string]$InstallPath
    )
    
    $Target = Join-Path $InstallPath "config.json"
    $Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $Target -Encoding UTF8
    Write-Log "Configuration bridge exported to $Target" -Level DEBUG
}

function Update-EnvironmentPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Invoke-SafeWebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [string]$OutFile,
        [string]$ExpectedHash,
        [int]$RetryCount = 3
    )
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    
    $attempt = 0
    while ($attempt -lt $RetryCount) {
        try {
            $params = @{
                Uri             = $Uri
                Headers         = @{ "User-Agent" = "comfYa/0.2.0" }
                UseBasicParsing = $true
                TimeoutSec      = 120
                ErrorAction     = 'Stop'
            }
            
            if ($OutFile) {
                $params.OutFile = $OutFile
                Invoke-WebRequest @params
                
                if ($ExpectedHash) {
                    $actualHash = (Get-FileHash -Path $OutFile -Algorithm SHA256).Hash
                    if ($actualHash -ne $ExpectedHash) {
                        throw "Hash verification failed for $OutFile. Expected $ExpectedHash, got $actualHash"
                    }
                }
                return $true
            }
            return Invoke-WebRequest @params
        }
        catch {
            $attempt++
            if ($attempt -ge $RetryCount) { throw $_ }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

function Test-SystemRequirements {
    [CmdletBinding()]
    param([hashtable]$Config)
    
    # Disk Space Check
    $drive = Get-PSDrive -Name ($PSScriptRoot[0])
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    if ($freeGB -lt 20) {
        if (Get-Command Write-WarningComfy -ErrorAction SilentlyContinue) {
            Write-WarningComfy "Low disk space: $freeGB GB. Installation might fail."
        } else {
            Write-Warning "Low disk space: $freeGB GB. Installation might fail."
        }
    }
    
    # RAM Check
    $mem = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize
    $totalRAM = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
    if ($totalRAM -lt 16) {
        if (Get-Command Write-WarningComfy -ErrorAction SilentlyContinue) {
            Write-WarningComfy "Low RAM detected: $totalRAM GB. 16GB+ recommended."
        } else {
            Write-Warning "Low RAM detected: $totalRAM GB. 16GB+ recommended."
        }
    }
    
    return @{ FreeDisk = $freeGB; TotalRAM = $totalRAM }
}

function Test-PowerShellVersion {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.1 or 7+ is required. Current: $($PSVersionTable.PSVersion)"
    }
    return $true
}

Export-ModuleMember -Function @(
    'Test-Administrator'
    'Invoke-ElevatedRestart'
    'Update-EnvironmentPath'
    'Invoke-SafeWebRequest'
    'Test-SystemRequirements'
    'Test-PowerShellVersion'
    'Export-ComfyConfig'
)
