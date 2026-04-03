# Advanced CE Lua Patterns for IL2CPP Game Hacking

Patterns sourced from FearlessRevolution community + our project experience.
Load this reference when building cheats that need AOB scanning, hooking, or dynamic pointer resolution.

## 1. AOB Scan — Executable Memory Only (+X filter)

Faster than `AOBScan()` — skips heap, data, stack. Only scans code sections.

```lua
function aob_register(sym, pat)
  local instr = AOBScan(pat, "+X")  -- "+X" = executable memory only
  if not instr or instr.Count == 0 then
    print("Pattern not found: " .. sym)
    return nil
  end
  local addr = tonumber(instr[0], 16)
  instr.destroy()
  unregisterSymbol(sym)
  registerSymbol(sym, addr)
  return addr
end

-- Usage:
local addr = aob_register("MyHook", "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC 20")
```

## 2. Module-Scoped Scanning with createMemScan

Restrict scan to GameAssembly.dll only — avoids false positives from other DLLs.

```lua
function scanModule(moduleName, aobPattern)
  local base = getAddress(moduleName)
  local size = getModuleSize(moduleName)
  if not base or not size then return nil end

  local scanner = createMemScan()
  local results = createFoundList(scanner)
  scanner.firstScan(
    soExactValue, vtByteArray, rtRounded,
    aobPattern, nil,
    base, base + size,    -- module bounds only
    "",
    fsmNotAligned, "", true, false, false, false)
  scanner.waitTillDone()
  results.initialize()

  local addr = nil
  if results.Count > 0 then
    addr = tonumber(results.Address[0], 16)
  end
  scanner.destroy()
  results.destroy()
  return addr, results.Count
end

-- Usage:
local addr, count = scanModule("GameAssembly.dll", "48 8B 05 ?? ?? ?? ?? 48 8B 40 ??")
print(string.format("Found %d at 0x%X", count, addr or 0))
```

## 3. Breakpoint-Based Hooking (No Code Injection)

Alternative to hookCode/executeCodeEx. Sets a debugger breakpoint — Lua callback fires when hit.
**No RUNTIME_FUNCTION unwind table issues** because no code is injected.

```lua
function hookWithBreakpoint(address, callback)
  debug_setBreakpoint(address, function()
    -- Register globals are set by CE debugger:
    -- RAX, RBX, RCX, RDX, RSI, RDI, RBP, RSP
    -- R8-R15, RIP, EFLAGS
    local result = callback({
      rax=RAX, rbx=RBX, rcx=RCX, rdx=RDX,
      rsi=RSI, rdi=RDI, rbp=RBP, rsp=RSP,
      r8=R8, r9=R9, r10=R10, r11=R11,
      r12=R12, r13=R13, r14=R14, r15=R15
    })
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
end

-- Usage: intercept IL2CPP method, read first arg (rcx = this pointer)
hookWithBreakpoint(getAddress("GameAssembly.dll") + 0x480570, function(regs)
  local thisPtr = regs.rcx
  local hp = readInteger(thisPtr + 0x48)
  print("HP = " .. hp)
  -- Modify: writeInteger(thisPtr + 0x48, 9999)
end)

-- Remove when done:
-- debug_removeBreakpoint(address)
```

**Caveat**: Breakpoints are slow (debugger trap per hit). Use for:
- One-shot reads/writes
- Infrequent method calls (save, level-up, buy)
- Exploration/debugging

Do NOT use for:
- Update() loops (60+ times/sec)
- Hot combat functions
- Anything called frequently

## 4. Register Capture + Disassembly Offset Extraction

Automatically find which register holds an object pointer and what field offset is accessed.
Useful for exploring unknown IL2CPP structs without reading decompiled code.

```lua
function findRegAndOffset(address, maxInstructions)
  maxInstructions = maxInstructions or 10
  local regNames = {'rax','rbx','rcx','rdx','rsi','rdi','r8','r9','r10','r11','r12','r13','r14','r15','rbp'}
  local addr = address

  for i = 0, maxInstructions - 1 do
    local _, disasm = disassemble(addr)
    if disasm then
      for _, reg in ipairs(regNames) do
        -- Match patterns like [rbx+0x48], [rsi+0x20], [r14+0x10]
        local offset = disasm:match("%[" .. reg .. "%+0?x?([0-9A-Fa-f]+)%]")
        if offset then
          return reg, tonumber(offset, 16), addr
        end
        -- Also match [rbx+rcx*8+0x20] (array access)
        offset = disasm:match("%[" .. reg .. "%+.-0?x?([0-9A-Fa-f]+)%]")
        if offset then
          return reg, tonumber(offset, 16), addr
        end
      end
    end
    addr = addr + (getInstructionSize(addr) or 1)
  end
  return nil, 0, nil
end

-- Usage: find what field an instruction accesses
local reg, offset, instrAddr = findRegAndOffset(targetAddress)
if reg then
  print(string.format("Accesses [%s+0x%X] at 0x%X", reg, offset, instrAddr))
end
```

## 5. Shared Memory for Live-Editable Cheat Parameters

Create named values visible in CE address list. User (or MCP) can edit them at runtime.

```lua
function createEditableParam(name, defaultValue, valueType)
  local size = (valueType == "float") and 4 or 8
  local addr = allocateSharedMemory(name, size + 16)
  unregisterSymbol(name)
  registerSymbol(name, addr, true)

  if valueType == "float" then
    writeFloat(addr, defaultValue)
  else
    writeQword(addr, defaultValue)
  end

  return addr
end

-- Usage: create editable difficulty multiplier
local diffAddr = createEditableParam("DifficultyMultiplier", 1.0, "float")

-- In your hook, read the live value:
local mult = readFloat(diffAddr)  -- user can change this in address list
```

## 6. Wildcard AOB Generation with Uniqueness Check

Auto-generate a minimal unique AOB pattern for any address. Useful after game updates.

```lua
function generateUniqueAOB(address, moduleName)
  local base = getAddress(moduleName)
  local size = getModuleSize(moduleName)

  local aob = {}
  local addr = address
  local maxBytes = 60

  while #aob < maxBytes do
    local instrSize = getInstructionSize(addr)
    if not instrSize or instrSize == 0 then break end

    -- Keep first byte (opcode), wildcard operand bytes
    table.insert(aob, string.format("%02X", readBytes(addr, 1)))
    for j = 2, instrSize do
      table.insert(aob, "??")
    end
    addr = addr + instrSize

    -- Check if pattern is unique in module
    local pattern = table.concat(aob, " ")
    local scanner = createMemScan()
    local results = createFoundList(scanner)
    scanner.firstScan(soExactValue, vtByteArray, rtRounded,
      pattern, nil, base, base + size, "",
      fsmNotAligned, "", true, false, false, false)
    scanner.waitTillDone()
    results.initialize()
    local count = results.Count
    scanner.destroy()
    results.destroy()

    if count == 1 then
      return pattern
    end
  end
  return nil  -- couldn't find unique pattern
end

-- Usage:
local pattern = generateUniqueAOB(getAddress("GameAssembly.dll") + 0x480570, "GameAssembly.dll")
print("Unique AOB: " .. (pattern or "FAILED"))
```

## 7. processMessages() for Long Operations

Prevent CE from freezing during heavy Lua work. Critical for MCP operations near the 30s timeout.

```lua
function scanAllClasses(callback)
  local total = getClassCount()  -- hypothetical
  for i = 0, total - 1 do
    callback(i)
    if i % 100 == 0 then
      processMessages()  -- keep CE responsive
    end
  end
end
```

## 8. Find CE Windows by Class Name

Iterate open CE forms to find and interact with specific dialogs programmatically.

```lua
function findCEWindow(className)
  for i = 0, getFormCount() - 1 do
    local form = getForm(i)
    if form.ClassName == className then
      return form
    end
  end
  return nil
end

-- Common CE form class names:
-- "TfrmStructures2"    = Structure Dissect
-- "TFoundCodeDialog"   = What Accesses This Address results
-- "TMemoryViewForm"    = Memory View
-- "TMainForm"          = Main CE window
```

## Quick Reference: Which Pattern to Use

| Situation | Use This |
|-----------|----------|
| Find a function by bytes | `aob_register()` with `"+X"` (#1) |
| Scan only GameAssembly.dll | `scanModule()` with `createMemScan` (#2) |
| Intercept a method safely (no crash risk) | `debug_setBreakpoint` (#3) |
| Explore unknown object fields | Register capture + disassembly (#4) |
| Expose tunable cheat values | `allocateSharedMemory` (#5) |
| Generate AOB for a function | `generateUniqueAOB()` (#6) |
| Long operation without timeout | `processMessages()` in loop (#7) |
