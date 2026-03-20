# LongYinLiZhiZhuan Cheat Table — Technical Architecture

## Overview

Single merged cheat table `LongYinLiZhiZhuan.CT` (v4) containing:
- 14 simple cheats (money, stats, HP, talents, skills, battle, reputation)
- 1 item adder with GUI (books, materials, medicine, food, horses)

## Game Technical Profile

| Property | Value |
|----------|-------|
| Engine | Unity IL2CPP (64-bit) |
| Key DLL | `GameAssembly.dll` + `global-metadata.dat` |
| Process | `LongYinLiZhiZhuan.exe` |
| ASLR | Yes (addresses change every launch) |
| BepInEx | Optional (hook auto-detects) |
| Save location | `%LOCALAPPDATA%Low\HuaLongZ\saves\` (per Windows user, shared across Steam accounts) |
| Released | March 2026, actively updated |

## Two API Layers

### Simple Cheats — Mono/IL2CPP introspection via CE
```
LaunchMonoDataCollector() → mono_findClass() → mono_class_enumFields()
→ mono_class_getStaticFieldValue() → readQword/writeFloat at offsets
```
- Each cheat has its own inline `getHero()` function with null guards
- Read/write field values directly — no function calls into the game
- Safe, fast, no hooks, no risk of crash

### Item Adder — Raw il2cpp API via shellcode
```
il2cpp_domain_get() → il2cpp_domain_get_assemblies() → il2cpp_assembly_get_image()
→ il2cpp_class_from_name() → il2cpp_class_get_method_from_name()
→ il2cpp_class_get_static_field_data() → il2cpp_object_new()
```
- Builds x64 shellcode in allocated memory (`wkCode`), executes via `createRemoteThread`
- Assembly image cached after first scan (58 assemblies → find Assembly-CSharp once)
- Connect time: ~1 second (was 15-20s before caching)

## Hook Mechanism — GameController.Update()

The Item Adder hooks `GameController.Update()` to execute `GetItem` on the game's main thread.
Two paths depending on whether BepInEx/Harmony is present:

### Path A: With BepInEx (Harmony Pointer Swap)

```
Game calls Update → FF 25 [rip+disp32] → reads pointer slot → jumps to target

Normal:  slot → Harmony dispatcher → plugins → real Update
Hooked:  slot → our hookCode → Harmony dispatcher → plugins → real Update
```

1. Detect `FF 25` at Update entry (Harmony's standard trampoline format)
2. Decode `disp32` to find the pointer slot address
3. Save current slot value (Harmony's dispatcher address)
4. Write `hookCode` address to the slot
5. Hook tail-calls saved address via `jmp [origUpdatePtr]`

**Works with ANY Harmony plugin** — the `FF 25` trampoline format is standard across all Harmony 2.x versions.

### Path B: Without BepInEx (Short E9 JMP)

```
Before: [push rbx][sub rsp,0x40][cmp byte ptr [rip+...]...
After:  [E9 rel32][NOP]         [cmp byte ptr [rip+...]...
                ↓
            hookCode → relay trampoline → [push rbx][sub rsp,0x40] → continues at Update+6
```

1. `hookCode` allocated near GameAssembly.dll: `alloc(hookCode, 2048, GameAssembly.dll)`
2. Parse `disassemble()` output to find first instruction boundary >= 5 bytes
3. Save those bytes only (typically 6: `push rbx; sub rsp,0x40` — no RIP-relative ops)
4. Write 5-byte `E9 rel32` JMP + NOP padding to fill to boundary
5. Relay trampoline: `[saved bytes] + FF 25 00 00 00 00 + [updateCodeAddr + boundary]`

**Why not save 14 bytes?** The `FF 25 00 00 00 00 + addr8` patch requires saving 14 bytes, which
often includes RIP-relative instructions like `cmp byte ptr [rip+disp32]`. When these are copied
to the relay at a different address, the `[rip+disp32]` offset points to wrong memory → crash.

**Why E9?** The 5-byte `E9 rel32` JMP only needs to save 5-6 bytes (first 1-2 simple instructions),
which are almost always non-RIP-relative stack setup instructions.

### Hook Assembly (x64)

```asm
hookCode:
  push rax
  push rbx
  mov rbx, cmdBuf
  mov eax, [rbx+0x40]      ; heartbeat counter
  inc eax
  mov [rbx+0x40], eax
  mov [rbx+0x20], rcx      ; save GameController instance
  cmp dword ptr [rbx+0x38], 1  ; commands enabled?
  jne noCmd
  mov eax, [rbx]            ; command ID
  test eax, eax
  jz noCmd
  cmp eax, 1
  je doGetItem
  ; Unknown command → set error, clear
  mov dword ptr [rbx+0x04], 2
  mov dword ptr [rbx], 0
  jmp noCmd

doGetItem:
  push rcx/rdx/r8/r9/r10/r11
  sub rsp, 0x58
  mov rcx, [rbx+0x28]      ; heroPtr
  mov rdx, [rbx+0x08]      ; itemDataPtr
  xor r8d, r8d; inc r8d    ; showPopInfo = 1
  xor r9d, r9d             ; showSpeGetItem = 0
  mov [rsp+0x20], 0        ; param5 = 0
  mov byte [rsp+0x28], 0   ; param6 = 0
  mov rax, [rbx+0x30]      ; getItemAddr
  call rax
  ; ... cleanup, set status=done, clear command ...

noCmd:
  pop rbx
  pop rax
tailcall:
  jmp [origUpdatePtr]       ; continue to original Update chain
```

### Command Buffer Layout

```
cmdBuf+0x00: command   (dword) 0=idle, 1=getItem
cmdBuf+0x04: status    (dword) 0=pending, 1=done, 2=error
cmdBuf+0x08: param1    (qword) item pointer
cmdBuf+0x20: gcInst    (qword) GameController instance (set by hook)
cmdBuf+0x28: heroPtr   (qword) player HeroData pointer (set by Lua)
cmdBuf+0x30: getItemAddr (qword) resolved GetItem function address
cmdBuf+0x38: enabled   (dword) 1=commands enabled (set after heartbeat verify)
cmdBuf+0x40: heartbeat (dword) frame counter (incremented each Update call)
```

## Item Creation Flows

### Book (skill book)
```
allocItem() → .ctor(3) → SetBookData(skillID, rareLv) → mainThreadGetItem()
```
- `SetBookData` resolved via `il2cpp_class_get_method_from_name` (AOB broke after update)
- `allocItem` and `callFunc` use `createRemoteThread` (safe for small field-setting functions)
- `mainThreadGetItem` dispatches via the Update() hook

### Material
```
allocItem() → .ctor(5) → SetMaterialData(subType, itemLv, rareLv) → mainThreadGetItem()
```
- `SetMaterialData` resolved via AOB scan (RVA 0xCDEA30)

### Medicine / Food
```
allocItem() → .ctor(1 or 2) → copy fields from GameDataController.medDataBase/foodDataBase
→ copy medFoodData pointer from template → mainThreadGetItem()
```
- No Set method exists — fields copied from database template
- `medFoodData` at item offset `+0x68` copied from template

### Horse
```
allocItem() → .ctor(6) → copy fields from GameDataController.horseDataBase
→ copy horseData pointer from template → mainThreadGetItem()
```
- No Set method exists — fields copied from database template
- `horseData` at item offset `+0x88` copied from template

## Address Resolution Strategy

| Address | Method | Update-proof? |
|---------|--------|---------------|
| `GameController` class | `il2cpp_class_from_name` | Yes |
| `Update` method | `il2cpp_class_get_method_from_name` | Yes |
| `GetItem` method | `il2cpp_class_get_method_from_name(5)` | Yes |
| `SetBookData` | `il2cpp_class_get_method_from_name(2)` | Yes |
| `.ctor` | AOB scan | Fragile (RVA may shift) |
| `SetMaterialData` | AOB scan | Fragile (RVA may shift) |
| Field offsets | Hardcoded | Fragile (breaks if dev adds fields) |
| Database offsets | Hardcoded (`gdc+0x110/118/120`) | Fragile |

## Key Pointer Chain

```
GameController._instance (static field data + 0x0)
  └→ +0x20: WorldData
       └→ +0x50: HerosList (List<HeroData>)
            └→ items[0] (+0x10 → array, +0x20 → first hero)
                 ├→ +0x124: favor (float, NPC only)
                 ├→ +0x130/0x148/0x160: skill/attribute lists
                 ├→ +0x178: HP (float)
                 ├→ +0x17C: maxHP (float)
                 ├→ +0x1A0/1A4/1A8: injuries (float)
                 ├→ +0x1C0: sect currency (float)
                 ├→ +0x1C4/1C8: fame / bad fame (float)
                 ├→ +0x220: ItemListData
                 │    ├→ +0x18: silver (int)
                 │    ├→ +0x20: maxWeight (float)
                 │    └→ +0x28: allItem (List<ItemData>)
                 └→ +0x35C: talent points (float)

GameDataController._instance (static field data + 0x20)
  ├→ +0x110: medDataBase (List<ItemData>)
  ├→ +0x118: foodDataBase (List<ItemData>)
  ├→ +0x120: horseDataBase (List<ItemData>)
  └→ +0x198: heroTagDataBase (tag/talent database)

BattleController._instance
  ├→ +0x70: teams (List)
  └→ +0x1A8: player unit
```

## ENABLE/DISABLE Lifecycle

### ENABLE (Item Adder)
1. Open debug log
2. `discover()`: find GameAssembly base, scan assemblies for game image, cache it
3. Resolve classes (GameController, GameDataController, HeroData, ItemData)
4. Resolve instances and pointer chain to hero/inventory
5. AOB scan for .ctor and SetMaterialData RVAs
6. `installMainThreadHook()`: detect BepInEx, install hook, verify heartbeat
7. Enable command gate (`cmdBuf+0x38 = 1`)
8. Build and show GUI form

### DISABLE (Item Adder)
1. Close debug log + destroy GUI form
2. Disarm command gate (`cmdBuf+0x38 = 0`) + clear pending command/status
3. Unhook: restore Harmony pointer slot OR restore original `_ia_patchLen` bytes
4. Sleep 100ms drain (wait for any in-flight Update frame)
5. Free relay trampoline if direct-patch path was used
6. Dealloc + unregister CE symbols: cmdBuf, hookCode, origUpdatePtr, wkCode, wkData, wkStr
7. Reset global Lua state

## Bugs Fixed

| Priority | Bug | Root Cause | Fix |
|----------|-----|-----------|-----|
| P0 | RIP-relative relay crash | 14-byte save copied `cmp byte ptr [rip+disp32]` to relay at different address | Use 5-byte E9 JMP, save only 6 bytes (simple stack ops) |
| P0 | Infinite recursion (direct-patch) | Hook tail-called back to patched entry | Relay trampoline executes saved bytes, jumps past patch |
| P1 | Stack corruption on unknown cmd | `jmp cmdError` from pre-push context hit `add rsp,58 + pops` | Inline error status at pre-push level, `jmp noCmd` |
| P1 | Stale session cleanup | `allocWorkArea` freed hook memory before unhooking | Unhook first, drain 100ms, then free |
| P1 | `bit32` not in CE Lua | CE uses Lua 5.3+ which lacks `bit32` library | Use `% 256` and `math.floor(x / 256)` |
| P1 | `disassemble()` API misuse | Returns single string, not (string, nextAddr) | Parse hex bytes from `"addr - XX XX - opcode"` format |
| P1 | SetBookData AOB broke | Game update shifted code, AOB pointed to garbage | Resolve via `il2cpp_class_get_method_from_name` |
| P2 | showSpeGetItem NullRef | `showSpeGetItem=1` triggers UI code when inventory closed | Set `r9d=0` (showSpeGetItem=false) |
| P2 | No item popup | All GetItem flags set to 0 | Set `r8d=1` (showPopInfo=true) |
| P2 | Undefined `cmd` in timeout | `mainThreadGetItem` used undefined variable | Use `readInteger(S.cmdBuf)` |
| P2 | Command gate not disarmed | DISABLE didn't stop command processing before unhook | Write `cmdBuf+0x38 = 0` before unhook |
| P3 | 15-20s connect time | 58 assemblies × 50ms × 5 class lookups | Cache Assembly-CSharp image, reuse for all lookups |

## CE Lua Gotchas

- **CE Lua is 5.3+**: No `bit32` library. Use native `&`, `>>` operators or plain math (`% 256`).
- **`disassemble(addr)`**: Returns a single string `"addr - XX XX - opcode"`, NOT two return values.
- **`LaunchMonoDataCollector()`**: Works for IL2CPP games (CE bridges mono API to il2cpp internally). Safe to call multiple times.
- **`createRemoteThread`**: Executes shellcode in the game process. Safe for small functions, NOT for GC-sensitive operations.
- **`autoAssemble` with `alloc(name, size, module)`**: Allocates within ±2GB of the named module. Essential for E9 rel32 JMP.
- **BepInEx toggle**: Rename `winhttp.dll` ↔ `winhttp.dll.disabled` in game folder.
