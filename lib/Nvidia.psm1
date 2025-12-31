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
    
    $output = & nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader,nounits 2>&1
    if ($LASTEXITCODE -ne 0) { throw "nvidia-smi failure: $output" }
    
    $parts = $output -split ','
    $gpuName = $parts[0].Trim()
    $driverVer = $parts[1].Trim()
    $ccMajorMinor = $parts[2].Trim()
    $cc = [float]$ccMajorMinor
    
    # 1. Validate Compute Capability
    $minCC = if ($Config -and $Config.Gpu -and $Config.Gpu.MinComputeCapability) { $Config.Gpu.MinComputeCapability } else { 7.5 }
    if ($cc -lt $minCC) { throw "Incompatible GPU: CC $cc < $minCC requirement." }
    
    # 2. Map SM Architecture (from config)
    $smArch = "sm75"
    if ($Config -and $Config.Gpu -and $Config.Gpu.SmArchMapping) {
        $sortedKeys = $Config.Gpu.SmArchMapping.Keys | ForEach-Object { [float]$_ } | Sort-Object -Descending
        foreach ($key in $sortedKeys) {
            if ($cc -ge $key) {
                $smArch = $Config.Gpu.SmArchMapping["$key"]
                break
            }
        }
    }
    
    # 3. Map CUDA Version (from driver)
    $driverMajor = [int]($driverVer -split '\.')[0]
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
        Name              = $gpuName
        Driver            = $driverVer
        ComputeCapability = $cc
        CudaVersion       = $cudaVer
        SmArch            = $smArch
    }
}

function Get-NvidiaVram {
    [CmdletBinding()]
    param()
    $vram = & nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>$null
    if ($LASTEXITCODE -ne 0) { return 0 }
    return [int]($vram.Trim())
}

Export-ModuleMember -Function @('Get-NvidiaGpuInfo', 'Get-NvidiaVram')
