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
    
    if (Get-Command Write-ComfyLog -ErrorAction SilentlyContinue) {
        Write-ComfyLog "Elevating privileges using $hostExe for $ScriptPath..." -Level WARN
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
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [string]$InstallPath
    )
    
    $Target = Join-Path $InstallPath "config.json"
    $newJson = $Config | ConvertTo-Json -Depth 10
    
    # [15] SyncCheck: Avoid writing if identical
    if (Test-Path $Target) {
        $oldJson = Get-Content $Target -Raw
        if ($oldJson -eq $newJson) {
            Write-ComfyLog "Configuration bridge is up to date." -Level DEBUG
            return
        }
    }
    
    if ($PSCmdlet.ShouldProcess($Target, "Export Configuration")) {
        $newJson | Out-File -FilePath $Target -Encoding UTF8
        Write-ComfyLog "Configuration bridge synchronized to $Target" -Level DEBUG
    }
}

function Update-EnvironmentPath {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    if ($PSCmdlet.ShouldProcess("Environment Path", "Refresh")) {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"
    }
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
    
    # [5] Security: Enforce TLS 1.3 (with 1.2 fallback for older systems if necessary, but roadmap says SOTA)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13 -bor [Net.SecurityProtocolType]::Tls12
    
    $attempt = 0
    while ($attempt -lt $RetryCount) {
        try {
            $params = @{
                Uri             = $Uri
                Headers         = @{ "User-Agent" = "comfYa/0.2.3" }
                UseBasicParsing = $true
                TimeoutSec      = 120
                ErrorAction     = 'Stop'
            }
            
            if ($OutFile) {
                $params.OutFile = $OutFile
                
                # [18] Proxy Support
                if ($env:HTTP_PROXY -or $env:HTTPS_PROXY) {
                    Write-ComfyLog "Using system proxy for download..." -Level DEBUG
                }
                
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

function Test-SystemRequirement {
    [CmdletBinding()]
    param([hashtable]$Config)
    
    $req = $Config.Requirements
    
    # Disk Space Check
    $drive = Get-PSDrive -Name ($PSScriptRoot[0])
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    $minDisk = if ($req.MinDiskGB) { $req.MinDiskGB } else { 20 }
    
    if ($freeGB -lt $minDisk) {
        if (Get-Command Write-ComfyWarning -ErrorAction SilentlyContinue) {
            Write-ComfyWarning "Low disk space: $freeGB GB. < $minDisk GB requirement."
        } else {
            Write-Warning "Low disk space: $freeGB GB. < $minDisk GB requirement."
        }
    }
    
    # RAM Check
    $mem = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize
    $totalRAM = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
    $minRam = if ($req.MinRamGB) { $req.MinRamGB } else { 16 }
    
    if ($totalRAM -lt $minRam) {
        if (Get-Command Write-ComfyWarning -ErrorAction SilentlyContinue) {
            Write-ComfyWarning "Low RAM detected: $totalRAM GB. < $minRam GB requirement."
        } else {
            Write-Warning "Low RAM detected: $totalRAM GB. < $minRam GB requirement."
        }
    }
    
    return @{ FreeDisk = $freeGB; TotalRAM = $totalRAM }
}

function Add-DefenderExclusion {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Path)
    
    if (-not (Test-Administrator)) {
        Write-ComfyLog "Elevation required for Defender exclusion. Skipping." -Level DEBUG
        return $false
    }
    
    if ($PSCmdlet.ShouldProcess($Path, "Add Windows Defender Exclusion")) {
        try {
            Add-MpPreference -ExclusionPath $Path -ErrorAction Stop
            Write-ComfyLog "Secure: Added Defender exclusion for $Path" -Level SUCCESS
            return $true
        } catch {
            Write-ComfyWarning "Failed to add Defender exclusion: $_"
            return $false
        }
    }
}

function Get-SecurePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$RequireWrite
    )
    
    $fullPath = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $fullPath) {
        # If it doesn't exist, check parent
        $parent = Split-Path $Path -Parent
        if (-not (Test-Path $parent)) { return $null }
        $fullPath = $Path
    } else {
        $fullPath = $fullPath.Path
    }
    
    if ($RequireWrite) {
        $testFile = Join-Path $fullPath ".write-test-$(Get-Random)"
        try {
            New-Item -ItemType File -Path $testFile -ErrorAction Stop | Out-Null
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        } catch {
            return $null
        }
    }
    
    return $fullPath
}

function Resolve-ComfyEnvironment {
    param(
        [hashtable]$Config,
        [string]$InstallPath
    )
    $EnvMap = @{}
    $dirs = $Config.Directories
    
    foreach ($key in $Config.Environment.Keys) {
        $val = $Config.Environment[$key]
        
        # [SOTA] Recursive expansion loop (limited to 3 for safety)
        for ($i=0; $i -lt 3; $i++) {
            $oldVal = $val
            $val = $val -replace '\{InstallPath\}', $InstallPath
            
            if ($val -match '\{Dir:(.*?)\}') {
                $dirKey = $Matches[1]
                if ($dirs.ContainsKey($dirKey)) {
                    $val = $val -replace "\{Dir:$dirKey\}", $dirs[$dirKey]
                }
            }
            if ($val -eq $oldVal) { break }
        }
        $EnvMap[$key] = $val
    }
    return $EnvMap
}

function Sync-ComfyEnvironment {
    param([hashtable]$EnvMap, [bool]$Persist = $false)
    foreach ($key in $EnvMap.Keys) {
        $val = $EnvMap[$key]
        Set-Item -Path "env:$key" -Value $val
        # [SOTA] Isolation: Persistent environment only during session-agnostic setup
        if ($Persist) {
            Write-ComfyLog "Hardening: Persisting environment variable: $key" -Level DEBUG
            [Environment]::SetEnvironmentVariable($key, $val, "User")
        }
    }
}

function Test-PowerShellVersion {
    param([hashtable]$Config)
    $minPs = if ($Config.Requirements.MinPsVer) { $Config.Requirements.MinPsVer } else { 5.1 }
    if ($PSVersionTable.PSVersion.Major -lt $minPs) {
        throw "PowerShell $minPs or 7+ is required. Current: $($PSVersionTable.PSVersion)"
    }
    return $true
}

Export-ModuleMember -Function @(
    'Test-Administrator'
    'Invoke-ElevatedRestart'
    'Update-EnvironmentPath'
    'Invoke-SafeWebRequest'
    'Test-SystemRequirement'
    'Test-PowerShellVersion'
    'Export-ComfyConfig'
    'Add-DefenderExclusion'
    'Get-SecurePath'
    'Resolve-ComfyEnvironment'
    'Sync-ComfyEnvironment'
)
