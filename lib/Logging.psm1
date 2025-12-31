# comfYa - Logging Module
# Professional structured logging with CLI and file support

#Requires -Version 5.1

$Script:LogLevel = @{
    DEBUG   = 0
    VERBOSE = 1
    INFO    = 2
    SUCCESS = 3
    WARN    = 4
    ERROR   = 5
}

$Script:LogConfig = @{
    Level       = "INFO"
    FileEnabled = $false
    FilePath    = $null
}

function Initialize-Logging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [string]$InstallPath
    )
    
    if (-not $Config -or -not $Config.Logging) {
        $Script:LogConfig.Level = "INFO"
        return
    }
    
    $logCfg = $Config.Logging
    $Script:LogConfig.Level = if ($logCfg.Level) { $logCfg.Level } else { "INFO" }
    
    if ($logCfg.FileEnabled -and $InstallPath) {
        $logDir = Join-Path $InstallPath $Config.Directories.Logs
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        $Script:LogConfig.FilePath = Join-Path $logDir $logCfg.FileName
        $Script:LogConfig.FileEnabled = $true
        
        # Log Rotation
        if (Test-Path $Script:LogConfig.FilePath) {
            $logFile = Get-Item $Script:LogConfig.FilePath
            if ($logFile.Length -gt ($logCfg.MaxFileSizeMB * 1MB)) {
                $archive = $logCfg.FileName -replace '\.log$', "-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
                Move-Item $Script:LogConfig.FilePath (Join-Path $logDir $archive) -Force
            }
        }
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("DEBUG", "VERBOSE", "INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Level = "INFO",
        
        [string]$Phase,
        [string]$Step
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $prefix = if ($Phase -and $Step) { "[$Phase.$Step]" } elseif ($Phase) { "[$Phase]" } else { "" }
    
    # Threshold check
    if ($Script:LogLevel[$Level] -lt $Script:LogLevel[$Script:LogConfig.Level]) {
        return
    }
    
    # Console output
    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "VERBOSE" { "Gray" }
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
    }
    
    $symbol = switch ($Level) {
        "SUCCESS" { "✓" }
        "WARN"    { "⚠" }
        "ERROR"   { "✗" }
        Default   { " " }
    }
    
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
    if ($symbol -ne " ") {
        Write-Host "$symbol " -NoNewline -ForegroundColor $color
    }
    if ($prefix) {
        Write-Host "$prefix " -NoNewline -ForegroundColor Cyan
    }
    Write-Host $Message -ForegroundColor $color
    
    # File output
    if ($Script:LogConfig.FileEnabled -and $Script:LogConfig.FilePath) {
        $logLine = "[$timestamp] [$Level] $prefix $Message"
        $logLine | Out-File -FilePath $Script:LogConfig.FilePath -Append -Encoding UTF8
    }
}

function Write-Step {
    param([string]$Phase, [string]$Step, [string]$Message)
    Write-Log -Message $Message -Level INFO -Phase $Phase -Step $Step
}

function Write-Success {
    param([string]$Message)
    Write-Log -Message $Message -Level SUCCESS
}

function Write-Warning2 {
    param([string]$Message)
    Write-Log -Message $Message -Level WARN
}

function Write-Fatal {
    param([string]$Message, [string]$Suggestion)
    Write-Log -Message $Message -Level ERROR
    if ($Suggestion) {
        Write-Host "    → $Suggestion" -ForegroundColor DarkYellow
    }
    throw $Message
}

Export-ModuleMember -Function @(
    'Initialize-Logging'
    'Write-Log'
    'Write-Step'
    'Write-Success'
    'Write-Warning2'
    'Write-Fatal'
)
