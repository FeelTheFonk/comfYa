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

[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
function Write-ComfyLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("DEBUG", "VERBOSE", "INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Level = "INFO",
        
        [string]$Phase,
        [string]$Step
    )
    
    # Threshold check
    if ($Script:LogLevel[$Level] -lt $Script:LogLevel[$Script:LogConfig.Level]) {
        return
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = if ($Phase -and $Step) { "[$Phase::$Step]" } elseif ($Phase) { "[$Phase]" } else { "" }
    
    # Visual Mapping
    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "VERBOSE" { "Gray" }
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
    }
    
    $symbol = switch ($Level) {
        "SUCCESS" { "v" } # Use safe characters for broad compatibility or specific Unicode if confirmed
        "WARN"    { "!" }
        "ERROR"   { "x" }
        Default   { " " }
    }

    # Attempt to use Unicode if the host supports it
    if ($OutputEncoding.WebName -eq "utf-8" -or $PSVersionTable.PSVersion.Major -ge 7) {
        $symbol = switch ($Level) {
            "SUCCESS" { [char]0x2714 } # ✔
            "WARN"    { [char]0x26A0 } # ⚠
            "ERROR"   { [char]0x2718 } # ✘
            Default   { " " }
        }
    }
    
    # Console output
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
    if ($symbol -ne " ") {
        Write-Host "$symbol " -NoNewline -ForegroundColor $color
    }
    if ($prefix) {
        $pad = 18 - $prefix.Length
        $paddedPrefix = if ($pad -gt 0) { $prefix + (" " * $pad) } else { $prefix }
        Write-Host "$paddedPrefix " -NoNewline -ForegroundColor Cyan
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
    Write-ComfyLog -Message $Message -Level INFO -Phase $Phase -Step $Step
}

function Write-Success {
    param([string]$Message)
    Write-ComfyLog -Message $Message -Level SUCCESS
}

function Write-ComfyWarning {
    param([string]$Message)
    Write-ComfyLog -Message $Message -Level WARN
}

[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
function Write-Fatal {
    param([string]$Message, [string]$Suggestion)
    Write-ComfyLog -Message $Message -Level ERROR -Phase "FATAL"
    if ($Suggestion) {
        Write-Host "`n    [TIP] " -NoNewline -ForegroundColor Cyan
        Write-Host "$Suggestion`n" -ForegroundColor Gray
    }
    throw $Message
}

[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
function Show-ComfyHeader {
    param([string]$Version)
    
    Clear-Host
    $title = "  comfYa Pinnacle v$Version  "
    $width = $title.Length + 4
    $line = "═" * $width
    
    Write-Host "`n  ╔$line╗" -ForegroundColor Cyan
    Write-Host "  ║  $title║" -ForegroundColor White -BackgroundColor Black
    Write-Host "  ╚$line╝`n" -ForegroundColor Cyan
    
    Write-Host " [System] " -NoNewline -ForegroundColor Cyan
    Write-Host "Initializing hardware-accelerated orchestrator...`n" -ForegroundColor Gray
}

[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
function Show-ComfyFooter {
    param()
    Write-Host "`n  " -NoNewline
    Write-Host ("─" * 40) -ForegroundColor DarkGray
    Write-Host "  Operation completed successfully.`n" -ForegroundColor Green
}

Export-ModuleMember -Function @(
    'Initialize-Logging'
    'Write-ComfyLog'
    'Write-Step'
    'Write-Success'
    'Write-ComfyWarning'
    'Write-Fatal'
    'Show-ComfyHeader'
    'Show-ComfyFooter'
)
