---
name: cheat-creator
description: Create new cheats for LongYinLiZhiZhuan by analyzing the game's decompiled code and using Cheat Engine MCP. Use this skill when the user asks to create a new cheat, hack, mod, trainer feature, or wants to modify game behavior — e.g. "give me infinite money", "make combat faster", "add all items", "modify recruitment", "freeze health", "change drop rates". Also trigger when the user describes a desired game behavior change without explicitly saying "cheat".
---

# Cheat Creator for LongYinLiZhiZhuan

**BEFORE STARTING:** Read `docs/reverse-engineering/pipeline-research-checklist.md` → "Before Modifying the CT" and "Before Using the Call Graph" sections. Key rules: use method iterator for overloads (not `get_method_from_name`), test with fresh CE attach, always cross-verify call graph with grep.

Create cheats by: understanding what the user wants → finding the right game code → building the CE implementation.

## Workflow

### Phase 1: Understand the Request

Clarify what the user wants changed:
- What game mechanic? (combat, items, economy, stats, events, UI, etc.)
- Exact behavior? (set value, multiply, freeze, unlock, spawn, etc.)
- Persistence? (one-shot vs continuous, survives save/load?)

### Phase 2: Find the Game Code

Use the decompiled call graph to find relevant functions and data structures.

#### Step 2a: Search the knowledge graph

The GitNexus knowledge graph is at:
`C:/dev/gameanalysis/game_b_decomps_new/decomps_resolved/.gitnexus/lbug/`

Use the `lbug-query` skill to search for relevant classes, methods, and call flows. Example queries:
- Find a class: search for class name keywords
- Trace a flow: find what calls a function and what it calls
- Find field offsets: read the decompiled C file for the target method

**STOP: Do NOT use CE MCP disassemble for code analysis.** We have 74K fully resolved decomps + dump.cs with every class/method/field. If a grep times out, try a narrower path or read the specific file directly. Live disassembly is never needed for understanding game code — only for verifying AOB byte patterns at a known address.

**Inlined methods:** ~3,500 IL2CPP methods are compiler-inlined. Their decomp files are tiny stubs (< 200 bytes) because the real logic was expanded at call sites. If a method's decomp looks trivially simple but you expect real logic, search for the method name in OTHER decomps — the caller has the inlined code. This is normal IL2CPP compiler behavior, not a Ghidra bug.

#### Step 2b: Read decompiled source

The resolved decomps are at: `C:/dev/gameanalysis/game_b_decomps_new/decomps_resolved/`

Files are named `ClassName$$MethodName.c`. Read them to understand:
- What parameters the function takes
- What fields it reads/writes (offsets like `*(param_1 + 0x64)`)
- What other functions it calls
- Control flow and conditions

#### Step 2c: Check Il2CppDumper output

For class/field definitions with exact offsets:
- `C:/dev/gameanalysis/Il2CppDumper/dump.cs` — search for class name to get all fields with offsets
- `C:/dev/gameanalysis/Il2CppDumper/script.json` — get exact method RVAs

#### Step 2d: Resolve method addresses

Use `python tools/resolve_funcs.py <address>` to look up any FUN_xxx address, or search script.json:
```python
import json
with open("C:/dev/gameanalysis/Il2CppDumper/script.json") as f:
    data = json.load(f)
# Search by name
for m in data['ScriptMethod']:
    if 'TargetClass' in m['Name']:
        print(f"0x{0x180000000 + m['Address']:x}: {m['Name']}")
```

### Phase 3: Design the Cheat

Based on the code analysis, choose the implementation approach:

#### Simple value cheats (read/write memory)
For modifying numeric values (HP, money, stats):
1. Find the singleton instance (e.g., `GameController.get_Instance` → `+0xB8` → static fields)
2. Follow pointer chain to the target field
3. Use CE MCP `read_pointer_chain` / `write_integer` / `write_memory`

#### Function hook cheats (modify behavior)
For changing game logic:
1. Find the target function's RVA from script.json
2. Determine if it needs main-thread execution (anything touching Unity objects does)
3. Choose approach:
   - **executeCodeEx**: For calling IL2CPP functions directly (class init, method calls)
   - **hookCode with command buffer**: For main-thread operations (item creation, spawning)
   - **Auto Assemble (AOB)**: For patching instructions (NOPs, forced jumps, value overrides)
   - **debug_setBreakpoint**: For safe interception without code injection (avoids RUNTIME_FUNCTION crash). See `references/advanced_ce_patterns.md` for patterns.

For advanced patterns (module-scoped AOB scans, breakpoint hooking, wildcard AOB generation, shared memory parameters), read `references/advanced_ce_patterns.md`.

#### Key IL2CPP patterns for CE

**Get a singleton instance:**
```lua
-- Pattern: class has static field at +0xB8, instance at first qword
local classAddr = executeCodeEx(0, nil, il2cpp_class_from_name, domain, namespace, className)
local sf = readQword(classAddr + 0xB8)
local instance = readQword(sf)
```

**Call a managed method (safe way):**
```lua
-- ALWAYS use il2cpp_runtime_invoke for methods with serialization/exceptions
local method = _findMethodAddr(classAddr, "MethodName", paramCount)
local result = executeCodeEx(0, nil, il2cpp_runtime_invoke, method, instance, argsArray, 0)
```

**Read/write object fields:**
```lua
-- Field offsets from dump.cs or decompiled code
local heroData = readQword(instance + 0x20)  -- e.g., hero list
local hp = readInteger(heroData + 0x48)       -- e.g., HP field
writeInteger(heroData + 0x48, 9999)           -- set HP
```

### Phase 4: Implement with CE MCP

Use the Cheat Engine MCP tools:
- `mcp__cheatengine__evaluate_lua` — Run Lua code in CE (for complex logic)
- `mcp__cheatengine__read_pointer_chain` — Follow pointer chains
- `mcp__cheatengine__write_integer` / `write_memory` — Modify values
- `mcp__cheatengine__auto_assemble` — Inject assembly patches
- `mcp__cheatengine__aob_scan` — Find code patterns by byte signature
- `mcp__cheatengine__disassemble` — Check instructions at an address
- `mcp__cheatengine__get_symbol_address` — Resolve exported function names

### Phase 5: Test and Verify

1. Read the value back after writing to confirm it stuck
2. Check if the game reflects the change (some values are cached/derived)
3. If the value resets, find where it's being overwritten (set a data breakpoint)
4. If the game crashes, check:
   - Was the pointer chain valid? (null checks)
   - Was il2cpp_runtime_invoke used instead of direct call?
   - Was the operation on the main thread?

## Critical Rules

1. **NEVER call managed methods with direct `call rax`** — always use `il2cpp_runtime_invoke`. Direct calls crash because CE's hookCode has no RUNTIME_FUNCTION unwind tables.

2. **Main thread required** for: creating objects, modifying Unity components, calling methods that touch the scene graph. Use the Update() hook command buffer pattern.

3. **ASLR**: All addresses change every game launch. Use `getAddress()` with symbol names or AOB scans, never hardcoded addresses.

4. **Test with readback**: Always verify writes actually persisted. Some fields are properties backed by methods, not direct memory.

5. **Keep MCP calls fast**: The MCP bridge has a 30-second timeout. Don't loop heavily in Lua.

## Reference: Known Game Systems

| System | Key Class | Singleton? | Notes |
|--------|----------|------------|-------|
| Game state | GameController | Yes (+0xB8) | Master controller, has hero/force/world refs |
| Heroes | HeroData | Via GameController | Stats, skills, equipment at known offsets |
| Items | ItemData | Via inventory | Created via GetItem/GetBook/GetMed/etc. |
| Combat | BattleController | Yes | Turn-based, difficulty at specific offsets |
| Events | WorldEventController | Yes | Event spawning, difficulty, templates |
| Plot | PlotController | Yes | Story progression, NPC interactions |
| Map | AreaController | Yes | Area management, movement |
| UI | Various *UIController | Yes each | Panel-specific controllers |

## Reference: Existing Cheat Table Features (v6)

Already implemented in the CT (don't recreate):
- Basic stats (HP, attack, defense, etc.) — memory scan based
- ItemAdder (books, materials, meds, food, horses) — hookCode cmd 1-4
- Event spawner with difficulty control — hookCode + difficultyRate override
- Equipment generator (WIP) — hookCode cmd=4 doGenEquip
