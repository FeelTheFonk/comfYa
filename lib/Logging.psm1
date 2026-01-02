# comfYa - Logging Module
# Professional structured logging with CLI and file support

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Script:LogLevel = @{
    DEBUG   = 0
    VERBOSE = 1
    INFO    = 2
    SUCCESS = 3
    WARN    = 4
    ERROR   = 5
}

$Script:LogConfig = @{
    Level         = "INFO"
    FileEnabled   = $false
    FilePath      = $null
    SandboxActive = $false  # [C2] Track sandbox state separately
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
            try {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            } catch {
                Write-ComfyWarning "Could not create log directory at $logDir. Falling back to sandbox."
                return
            }
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
        
        # Drain Sandbox if it exists
        $sandboxPath = Join-Path $env:TEMP "comfya-init.log"
        if (Test-Path $sandboxPath) {
            $content = Get-Content $sandboxPath
            $content | Out-File -FilePath $Script:LogConfig.FilePath -Append -Encoding UTF8
            Remove-Item $sandboxPath -Force -ErrorAction SilentlyContinue
            Write-ComfyLog "Sandbox logs integrated into main log stream." -Level DEBUG
        }
    }
}

function Start-SandboxLogging {
    [CmdletBinding()]
    param()
    
    $sandboxPath = Join-Path $env:TEMP "comfya-init.log"
    # Rotate sandbox if it's over 1MB
    if (Test-Path $sandboxPath) {
        $file = Get-Item $sandboxPath
        if ($file.Length -gt 1MB) { Remove-Item $sandboxPath -Force }
    }
    
    $Script:LogConfig.FilePath = $sandboxPath
    $Script:LogConfig.FileEnabled = $true
    $Script:LogConfig.SandboxActive = $true  # [C2] Mark as sandbox mode
    # [C2] Don't override global Level - sandbox captures all levels to file only
    
    Write-ComfyLog "Sandbox logging initialized at $sandboxPath" -Level DEBUG
}

function Write-ComfyLog {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("DEBUG", "VERBOSE", "INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Level = "INFO",
        
        [string]$Phase,
        [string]$Step
    )
    
    # Threshold check - [C2] In sandbox mode, still write to file but respect console threshold
    $writeToConsole = $Script:LogLevel[$Level] -ge $Script:LogLevel[$Script:LogConfig.Level]
    $writeToFile = $Script:LogConfig.FileEnabled -and $Script:LogConfig.FilePath

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

    # [SOTA] Unicode Detection: Improved resilience across Windows Terminal, VSCode and Legacy Hosts
    if ($OutputEncoding.WebName -eq "utf-8" -or $env:TERM_PROGRAM -eq "vscode" -or $env:WT_SESSION) {
        $symbol = switch ($Level) {
            "SUCCESS" { [char]0x2714 } # ✔
            "WARN"    { [char]0x26A0 } # ⚠
            "ERROR"   { [char]0x2718 } # ✘
            Default   { " " }
        }
    }
    
    # Console output - only if level meets threshold
    if ($writeToConsole) {
        Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
        if ($symbol -ne " ") {
            Write-Host "$symbol " -NoNewline -ForegroundColor $color
        }
        
        if ($prefix) {
            # SOT: Standardized 20-char padding for phase::step alignment
            $pad = 20 - $prefix.Length
            $paddedPrefix = if ($pad -gt 0) { $prefix + (" " * $pad) } else { $prefix }
            Write-Host "$paddedPrefix " -NoNewline -ForegroundColor Cyan
        }
        Write-Host $Message -ForegroundColor $color
    }
    
    # File output - always write in sandbox mode, otherwise respect threshold
    if ($writeToFile) {
        $logLine = "[$timestamp] [$Level] $prefix $Message"
        $logLine | Out-File -FilePath $Script:LogConfig.FilePath -Append -Encoding UTF8
    }
}

function Write-Step {
    param([string]$Phase, [string]$Step, [string]$Message, [int]$Percent = -1)
    
    if ($Percent -ge 0) {
        Write-Progress -Activity "comfYa $Phase" -Status "${Step}: $Message" -PercentComplete $Percent
    }
    
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

function Write-Diagnostic {
    param([string]$Test, [string]$Status, [string]$Details)
    
    $color = switch ($Status) {
        "OK"   { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        Default { "Gray" }
    }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
    Write-Host " (DIAG) " -NoNewline -ForegroundColor Magenta
    Write-Host "  $($Test.PadRight(25, '.')) " -NoNewline -ForegroundColor White
    Write-Host "[$Status]" -ForegroundColor $color -NoNewline
    if ($Details) { Write-Host " ($Details)" -ForegroundColor Gray }
    Write-Host ""
}

function Write-Fatal {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
    param([string]$Message, [string]$Suggestion)
    Write-ComfyLog -Message $Message -Level ERROR -Phase "FATAL"
    if ($Suggestion) {
        Write-Host "`n    [TIP] " -NoNewline -ForegroundColor Cyan
        Write-Host "$Suggestion`n" -ForegroundColor Gray
    }
    throw $Message
}

function Show-ComfyHeader {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
    param([string]$Version)
    
    # [H9] Removed Clear-Host - non-invasive behavior
    $title = "  comfYa Pinnacle v$Version  "
    $width = $title.Length + 4
    $line = "═" * $width
    
    Write-Host "`n  ╔$line╗" -ForegroundColor Cyan
    Write-Host "  ║  $title║" -ForegroundColor White -BackgroundColor Black
    Write-Host "  ╚$line╝`n" -ForegroundColor Cyan
    
    Write-Host " [System] " -NoNewline -ForegroundColor Cyan
    Write-Host "Initializing hardware-accelerated orchestrator...`n" -ForegroundColor Gray
}

function Show-ComfyFooter {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingWriteHost", "")]
    param()
    Write-Host "`n  " -NoNewline
    Write-Host ("─" * 40) -ForegroundColor DarkGray
    Write-Host "  Operation completed successfully.`n" -ForegroundColor Green
}

Export-ModuleMember -Function @(
    'Initialize-Logging'
    'Start-SandboxLogging'
    'Write-ComfyLog'
    'Write-Step'
    'Write-Success'
    'Write-ComfyWarning'
    'Write-Fatal'
    'Write-Diagnostic'
    'Show-ComfyHeader'
    'Show-ComfyFooter'
)
