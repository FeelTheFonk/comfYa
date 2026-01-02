# Troubleshooting

Common issues and solutions.

## Installation Issues

### "nvidia-smi not found"

**Cause**: NVIDIA driver not installed or not in PATH.

**Solution**:
1. Download latest driver from [nvidia.com/drivers](https://www.nvidia.com/drivers)
2. Install and restart
3. Verify: `nvidia-smi` in terminal

---

### "Compute capability X.X < 7.5"

**Cause**: GPU too old (pre-RTX 20 series).

**Solution**: comfYa requires RTX 20xx or newer. Older GPUs are not supported.

---

### "config.psd1 not found"

**Cause**: Running commands from wrong directory or incomplete download.

**Solution**:
```powershell
cd C:\path\to\comfYa  # Navigate to correct folder
.\comfya.ps1 setup
```

---

### VC++ Redistributable Installation Failed

**Cause**: Insufficient permissions or corrupted download.

**Solution**:
1. Download manually: [aka.ms/vs/17/release/vc_redist.x64.exe](https://aka.ms/vs/17/release/vc_redist.x64.exe)
2. Run installer as admin
3. Re-run `.\comfya.ps1 setup`

---

## Runtime Issues

### "CUDA not available" / PyTorch not detecting GPU

**Cause**: Driver/CUDA mismatch or PyTorch installed for wrong CUDA version.

**Solution**:
```powershell
# Check driver version
nvidia-smi

# Verify PyTorch
.\comfya.ps1 doctor
```

If validation fails, use the integrated repair utility:
```powershell
.\comfya.ps1 doctor  # Select 'y' to trigger the environment repair process
```

---

### Triton import fails / "DLL load failed"

**Cause**: Missing Python headers or incompatible build.

**Solution**:
1. Verify VC++ Runtime installed
2. Check Python version matches wheel:
```powershell
.venv\Scripts\python.exe --version  # Should be 3.12.x
```
3. Reinstall triton-windows:
```powershell
uv pip install triton-windows --force-reinstall
```

---

### SageAttention "No module named 'sageattention'"

**Cause**: Installation failed or wheel incompatible.

**Solution**:
```powershell
# Check if installed
uv pip list | findstr sage
```

```powershell
# Reinstall using coordinates from the central configuration
.\comfya.ps1 doctor  # Select 'y' for self-healing
```

---

### ComfyUI slow / not using GPU optimizations

**Cause**: Launch args not applied.

**Solution**: Verify launch command:
```powershell
.venv\Scripts\python.exe ComfyUI\main.py --fast --highvram --use-sage-attention
```

Check console for:
```
Using sage attention
```

---

## Performance Issues

### Out of Memory (OOM) on large models

**Solution**: Use `--lowvram` instead of `--highvram`:
```powershell
.venv\Scripts\python.exe ComfyUI\main.py --fast --lowvram --use-sage-attention
```

---

### First generation very slow

**Cause**: Triton JIT compilation on first run.

**Solution**: This is normal. Subsequent generations will be faster.

---

## Update Issues

### "git reset --hard" fails

**Cause**: Local modifications conflict.

**Solution**:
```powershell
cd ComfyUI
git stash
git fetch origin
git reset --hard origin/master
git stash pop  # Optional: restore local changes
```

---

## Still Having Issues?

1. Run validation: `.\comfya.ps1 doctor`
2. Check logs: `logs/install.log`
3. Open issue: [GitHub Issues](https://github.com/FeelTheFonk/comfYa/issues)
