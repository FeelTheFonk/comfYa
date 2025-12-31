# comfYa - NVIDIA GPU Module
# Professional CUDA and GPU detection logic

#Requires -Version 5.1

function Get-NvidiaGpuInfo {
    [CmdletBinding()]
    param([hashtable]$Config)
    
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvidiaSmi) {
        throw "nvidia-smi not found. NVIDIA drivers (525+) are mandatory."
    }
    
    # Query all GPUs: Name, Driver, CC, VRAM
    $output = & nvidia-smi --query-gpu=name,driver_version,compute_cap,memory.total --format=csv,noheader,nounits 2>&1
    if ($LASTEXITCODE -ne 0) { throw "nvidia-smi failure: $output" }
    
    $gpuList = @()
    $lines = $output -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
    
    foreach ($line in $lines) {
        $parts = $line -split ','
        $invCulture = [System.Globalization.CultureInfo]::InvariantCulture
        
        # [SOTA] Robust Parsing: handle cases where CC might contain a comma causing extra split parts
        # Standard columns: 0:Name, 1:Driver, 2:CC, 3:Vram
        # If CC is "8,9", we get 5 parts: [2]=8, [3]=9, [4]=Vram
        $ccPart = $parts[2].Trim()
        $vramPart = $parts[3].Trim()
        
        if ($parts.Count -gt 4) {
            $ccPart = "$($parts[2]).$($parts[3])".Trim()
            $vramPart = $parts[4].Trim()
        }
        
        $gpuInfo = @{
            Name              = $parts[0].Trim()
            Driver            = $parts[1].Trim()
            ComputeCapability = [double]::Parse(($ccPart -replace ',', '.'), $invCulture)
            Vram              = [int]::Parse($vramPart, $invCulture)
        }
        $gpuList += New-Object PSObject -Property $gpuInfo
    }
    
    # Select best GPU (Highest Compute Capability, then highest VRAM)
    $bestGpu = $gpuList | Sort-Object ComputeCapability, Vram -Descending | Select-Object -First 1
    
    if (-not $bestGpu) { throw "No NVIDIA GPUs detected via nvidia-smi" }
    
    $cc = $bestGpu.ComputeCapability
    
    # 1. Validate Compute Capability
    $minCC = if ($Config -and $Config.Gpu -and $Config.Gpu.MinComputeCapability) { $Config.Gpu.MinComputeCapability } else { 7.5 }
    if ($cc -lt $minCC) { throw "Incompatible GPU: CC $cc < $minCC requirement." }
    
    # 2. Map SM Architecture (from config)
    $smArch = "sm75"
    if ($Config -and $Config.Gpu -and $Config.Gpu.SmArchMapping) {
        $sortedKeys = $Config.Gpu.SmArchMapping.Keys | ForEach-Object { [double]::Parse($_, [System.Globalization.CultureInfo]::InvariantCulture) } | Sort-Object -Descending
        foreach ($key in $sortedKeys) {
            if ($cc -ge $key) {
                $smArch = $Config.Gpu.SmArchMapping["$($key.ToString('F1', [System.Globalization.CultureInfo]::InvariantCulture))"]
                if ($null -eq $smArch) {
                    # Fallback if key format in hashtable is slightly different
                    $smArch = $Config.Gpu.SmArchMapping[[string]$key]
                }
                break
            }
        }
    }
    
    # 3. Map CUDA Version (from driver)
    $driverMajor = [int]($bestGpu.Driver -split '\.')[0]
    $cudaVer = $Config.Cuda.PreferredVersion
    
    if ($Config.Cuda.DriverMapping) {
        $sortedDrivers = $Config.Cuda.DriverMapping.Keys | ForEach-Object { [int]$_ } | Sort-Object -Descending
        foreach ($minDriver in $sortedDrivers) {
            if ($driverMajor -ge $minDriver) {
                $cudaVer = $Config.Cuda.DriverMapping[[string]$minDriver]
                break
            }
        }
    }
    
    return @{
        Name              = $bestGpu.Name
        Driver            = $bestGpu.Driver
        ComputeCapability = $cc
        CudaVersion       = $cudaVer
        SmArch            = $smArch
        Vram              = $bestGpu.Vram
    }
}

Export-ModuleMember -Function @('Get-NvidiaGpuInfo')
