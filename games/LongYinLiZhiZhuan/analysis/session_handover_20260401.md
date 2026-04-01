# Session Handover — April 1 2026

## Task 1: Extract Cpp2IL Generic Method Mappings (HIGH PRIORITY)

### Problem
86 functions in the decompiled code are unnamed (FUN_180480570, FUN_180002f80, etc.). These are generic method instantiations that Il2CppDumper's dump.cs doesn't capture. They block full call graph analysis.

### What's ready
- Cpp2IL downloaded at `C:/dev/gameanalysis/Cpp2IL.exe` (pre-release.21)
- It successfully reads 9811+ generic method pointers from the game
- Current name_index.json has 60,020 names at `C:/dev/gameanalysis/game_b_decomps/name_index.json`
- Manual names for top 19 at `tools/manual_names.json`

### What to do
1. Write a Python script that reads GameAssembly.dll's generic method table (same data Cpp2IL reads) and outputs address→name mappings
2. OR: modify Cpp2IL to output a JSON mapping (it's open source at github.com/SamboyCoding/Cpp2IL)
3. OR: parse the `diffable-cs` output at `C:/dev/gameanalysis/cpp2il_cs/` — cross-reference method names with Ghidra addresses
4. Merge results into name_index.json
5. Re-run `python tools/resolve_decomps.py` (70 seconds on local SSD)
6. Output at `C:/dev/gameanalysis/game_b_decomps/decomps_resolved/`

### Key missing functions
```
FUN_180480570 = GameController.get_Instance (2554 refs) — MOST IMPORTANT
FUN_180002f80 = List<T>.get_Item (4082 refs)
FUN_1800d6520 = il2cpp_throw_NullReferenceException (37208 refs)
FUN_1800d64f0 = il2cpp_raise_exception (44108 refs)
FUN_1800d65e0 = Dictionary/List typed accessor (608 refs)
```

## Task 2: GitNexus Re-indexing

### What's ready
- 68,731 resolved C files at `C:/dev/gameanalysis/game_b_decomps/decomps_resolved/`
- Git repo initialized with `core.longpaths=true`
- GitNexus works locally (queried Z: drive database all session)

### What to do
1. After Task 1 re-resolves the decomps, run `npx gitnexus analyze` in the decomps_resolved folder
2. Previous attempt ran but was killed (took too long or failed silently)
3. The old database at `Z:/project/game-decomp-b/.gitnexus/lbug` still works for queries
4. Kaggle/Colab won't work (GLIBC_2.38 required, neither has it)

## Task 3: Side Panel Star Display (COSMETIC)

### Current state
- Event spawner works: spawn, combat, recruitment, difficulty all functional
- Map hover tooltip shows stars correctly at any difficulty
- Side panel shows approximate color (from difficultyRate * random), not exact user value
- Side panel star issue might be solved once anonymous functions are resolved (Task 1)

### Root cause
The difficulty is set inside CreateWorldEvent by `GetWorldEventRandomDifficulty * difficultyRate`. We control difficultyRate but the random factor makes the result non-deterministic. The side panel icon renders once during creation with this approximate value. Our post-spawn override of +0x64 only affects hover tooltip/gameplay, not the already-rendered side panel icon.

### Key code path
```
WorldEventIconController.Update (one-time init):
  - +0x5C=0 AND +0x5A=0 → show "new event" indicator (colored, with stars)
  - +0x5C=0 AND +0x5A=1 → hide indicator (plain white)
  - GetDifficultyColor(+0x64) → 6-entry table (grey/green/blue/purple/orange/red)
  - Star count from GetDifficultyStarString: unlimited stars, color capped at 5=red
```

### What might fix it
- Resolving anonymous functions (Task 1) might reveal a missed display flag
- OR: hook GetWorldEventRandomDifficulty to return exact desired value
- OR: find the correct MissionUIController instance and call RefreshWorldEventTable after setting +0x64

### Key EventData offsets
```
+0x50=areaID +0x54=direction +0x58=seen +0x5A=noticed +0x5B=hovering
+0x5C=showStars +0x5D=specialIcon +0x60=leftTime(int) +0x64=difficulty(float)
+0x68=difficultyRate(float) +0x6C=-1 +0x70=plotData +0x80=eventType
+0x90=rangeRate(float) +0x94=timestamp
```

## Key Technical Discoveries This Session

### il2cpp_runtime_invoke (CRITICAL)
Direct `call rax` crashes for methods using BinaryFormatter/serialization because hookCode has no RUNTIME_FUNCTION unwind tables. Use `il2cpp_runtime_invoke` instead. Pattern saved in `memory/feedback_il2cpp_runtime_invoke.md`.

### BinaryFormatter Clone behavior
- Clone serializes by field metadata (name/type), NOT by byte offset
- Writing bytes to WorldEventDataBase template does NOT propagate to EventData clone
- Only serializable sub-objects (like difficultyRate at *(+0x50)+0x68) carry through

### WorldEventController access pattern
- `readQword(wecClass + 0xB8)` → sf
- `readQword(sf)` = WEC singleton instance (NOT sf+0x8 which is a List)
- `readQword(sf) + 0x18` = WorldEventDataBase list (25 entries)
- Template index 19 = 武学奇才

### Difficulty control
- difficultyRate at `*(template+0x50)+0x68` — modify before CreateWorldEvent, restore after
- Post-spawn override: `writeFloat(newEvt + 0x64, difficulty)` for exact gameplay value

## Files created/modified this session
- `tools/cors_server.py` — HTTPS CORS server for release pipeline
- `tools/certs/localhost.crt + .key` — self-signed cert
- `tools/resolve_funcs.py` — resolve FUN_ addresses to C# names
- `tools/resolve_decomps.py` — batch resolve 68K decompiled files
- `tools/manual_names.json` — 19 manually identified generic functions
- `games/LongYinLiZhiZhuan/analysis/event_system_gitnexus.md` — full analysis
- `games/LongYinLiZhiZhuan/analysis/event_spawner_crash_analysis.md` — crash analysis
- `C:/dev/gameanalysis/game_b_decomps/decomps_resolved/` — 68K resolved C files
- `C:/dev/gameanalysis/game_b_decomps/decomps_resolved.zip` — 43.8MB for upload
- `C:/dev/gameanalysis/Cpp2IL.exe` — tool for generic method extraction
- `C:/dev/gameanalysis/cpp2il_cs/` — 6558 C# stub files
- `C:/dev/gameanalysis/cpp2il_isil/` — ISIL disassembly output
