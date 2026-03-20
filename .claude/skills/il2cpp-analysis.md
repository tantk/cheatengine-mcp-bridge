---
name: IL2CPP Game DLL Analysis
description: Send IL2CPP game files to Ghidra server for reverse engineering. Always send GameAssembly.dll AND global-metadata.dat together.
---

# IL2CPP Game DLL Analysis

When analyzing a Unity IL2CPP game, you need TWO files for Ghidra/Il2CppDumper:

## Required Files

1. **GameAssembly.dll** — The compiled native code (all C# compiled to C++)
   - Location: `<GameRoot>/GameAssembly.dll`

2. **global-metadata.dat** — Class/method/field metadata for mapping
   - Location: `<GameRoot>/<GameName>_Data/il2cpp_data/Metadata/global-metadata.dat`

**BOTH files are required.** Without metadata, Ghidra cannot map addresses to class/method names.

## Ghidra Analysis Pipeline API (Ubuntu server)

The pipeline runs on Ubuntu server `tan`:
- **LAN**: `http://<LAN_IP>:9091` (same network)
- **Tailscale**: `http://<TAILSCALE_IP>:9091` (remote/different network)

### Submit for analysis (from Windows)
```bash
# From the game's root directory
cd "<GameRoot>"
curl.exe -F file=@GameAssembly.dll \
  -F "metadata=@<GameName>_Data/il2cpp_data/Metadata/global-metadata.dat" \
  http://<TAILSCALE_IP>:9091/analyze
```

### Check status / get results
```bash
# Check task status
curl.exe http://<TAILSCALE_IP>:9091/status/<task_id>

# Get results
curl.exe http://<TAILSCALE_IP>:9091/results/<task_id>

# List all tasks
curl.exe http://<TAILSCALE_IP>:9091/tasks

# Pipeline info
curl.exe http://<TAILSCALE_IP>:9091/
```

### PowerShell note
Use `curl.exe` not `curl` — PowerShell aliases `curl` to `Invoke-WebRequest` which has different syntax.

## Fallback: Manual SCP transfer
```bash
ssh rustan@tan "mkdir -p /tmp/<game_name>"
scp "<GameRoot>/GameAssembly.dll" \
    "<GameRoot>/<GameName>_Data/il2cpp_data/Metadata/global-metadata.dat" \
    rustan@tan:/tmp/<game_name>/
```

## Pipeline output

The pipeline runs Il2CppDumper + Ghidra to produce:
- `dump.cs` — C# class/method/field definitions
- `script.json` — Address-to-name mappings for Ghidra/IDA
- Decompiled method implementations

## How to Identify IL2CPP vs Mono

- **IL2CPP**: Has `GameAssembly.dll` + `global-metadata.dat`, no `Assembly-CSharp.dll` in Managed folder
- **Mono**: Has `Assembly-CSharp.dll` in `<GameName>_Data/Managed/`

## Notes

- The game dump text file (from Il2CppDumper or similar) provides class structures but NOT method implementations
- For actual decompiled logic, Ghidra analysis of GameAssembly.dll is needed
- CE's mono data collector still works with IL2CPP games for live memory inspection
