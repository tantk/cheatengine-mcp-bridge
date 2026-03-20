-- AddBook.lua - Add martial art book to player inventory
-- Usage: Set TARGET_SKILL_ID and TARGET_RARE_LV below, then execute in CE Lua Engine
-- Skill IDs: see games/LongYinLiZhiZhuan/analysis/龙胤立志传数据资料.xlsx (全部武功 sheet)
--
-- How it works:
--   1. il2cpp_object_new() - allocate ItemData in managed heap
--   2. .ctor(ItemType.Book) - initialize as book
--   3. SetBookData(skillID, rareLv) - sets name, icon, value, everything
--   4. Insert into allItem list
--   5. Call OnDeserializedMethod to rebuild itemTypeList (prevents crash)

---------- CONFIGURATION ----------
TARGET_SKILL_ID = 200   -- Change this (0-999)
TARGET_RARE_LV  = 5     -- Quality: 1-5 (5 = highest)
-----------------------------------

-- RVAs from Il2CppDumper (stable across sessions, base changes)
local RVA_CTOR         = 0xCDE970  -- ItemData..ctor(ItemType)
local RVA_SET_BOOK     = 0xCDDD10  -- ItemData.SetBookData(int, int)
local RVA_ON_DESER     = 0xCE61B0  -- ItemListData.OnDeserializedMethod(StreamingContext)

print("=== AddBook Script ===")
print(string.format("Target: skillID=%d rareLv=%d", TARGET_SKILL_ID, TARGET_RARE_LV))

-- Step 1: Find GameAssembly base and key functions
local base = nil
for _, m in ipairs(enumModules()) do
  if m.Name == "GameAssembly.dll" then base = m.Address; break end
end
if not base then print("ERROR: GameAssembly.dll not found"); return end

local objNew = getAddress("GameAssembly.il2cpp_object_new")
if not objNew or objNew == 0 then print("ERROR: il2cpp_object_new not found"); return end

local ctorAddr    = base + RVA_CTOR
local setBookAddr = base + RVA_SET_BOOK
local onDeserAddr = base + RVA_ON_DESER

print(string.format("GameAssembly base: 0x%X", base))

-- Step 2: Find GameController._instance via mono
CESERVER_CONNECTIONS = nil
monopipe = nil
LaunchMonoDataCollector()
sleep(2000)

local gc = nil
local cls = mono_findClass("", "GameController")
if cls and cls ~= 0 then
  for _, f in ipairs(mono_class_enumFields(cls)) do
    if f.name == "_instance" then
      gc = mono_class_getStaticFieldValue(cls, f.field)
      break
    end
  end
end
if not gc or gc == 0 then print("ERROR: GameController._instance not found"); return end

-- Step 3: Navigate to player inventory
local wd  = readQword(gc + 0x20)
local hl  = readQword(wd + 0x50)
local ha  = readQword(hl + 0x10)
local ph  = readQword(ha + 0x20)
local ild = readQword(ph + 0x220)
local ail = readQword(ild + 0x28)
local ia  = readQword(ail + 0x10)
local ic  = readInteger(ail + 0x18)
local cap = readInteger(ia + 0x18)

if ic >= cap then print("ERROR: Inventory full, drop some items first"); return end

-- Step 4: Get ItemData Il2CppClass* from an existing book
local klass = nil
for i = 0, ic - 1 do
  local it = readQword(ia + 0x20 + i * 8)
  if it and it ~= 0 and readInteger(it + 0x14) == 3 then
    klass = readQword(it)
    break
  end
end
if not klass then print("ERROR: No book in inventory to get class pointer"); return end

-- Step 5: Build code cave - create item via game functions
local resultAddr = allocateMemory(64)
local codeAddr = allocateMemory(512)
if not resultAddr or not codeAddr then print("ERROR: Memory allocation failed"); return end

writeQword(resultAddr, 0)

-- Shellcode: il2cpp_object_new -> .ctor(Book) -> SetBookData(skillID, rareLv)
local p = 0
local function w(b) writeBytes(codeAddr + p, b); p = p + #b end
local function q(a) writeQword(codeAddr + p, a); p = p + 8 end
local function d(v) writeInteger(codeAddr + p, v); p = p + 4 end

w({0x48,0x83,0xEC,0x28})          -- sub rsp, 28h
w({0x48,0xB9}); q(klass)          -- mov rcx, klass
w({0x48,0xB8}); q(objNew)         -- mov rax, il2cpp_object_new
w({0xFF,0xD0})                     -- call rax
w({0x48,0x85,0xC0})               -- test rax, rax
w({0x74,0x30})                     -- jz done (skip 48 bytes)
w({0x48,0xA3}); q(resultAddr)     -- mov [resultAddr], rax
w({0x48,0x8B,0xC8})               -- mov rcx, rax
w({0xBA}); d(3)                    -- mov edx, 3 (Book)
w({0x4D,0x31,0xC0})               -- xor r8, r8
w({0x48,0xB8}); q(ctorAddr)       -- mov rax, .ctor
w({0xFF,0xD0})                     -- call rax
w({0x48,0xA1}); q(resultAddr)     -- mov rax, [resultAddr]
w({0x48,0x8B,0xC8})               -- mov rcx, rax
w({0xBA}); d(TARGET_SKILL_ID)     -- mov edx, skillID
w({0x41,0xB8}); d(TARGET_RARE_LV) -- mov r8d, rareLv
w({0x4D,0x31,0xC9})               -- xor r9, r9
w({0x48,0xB8}); q(setBookAddr)    -- mov rax, SetBookData
w({0xFF,0xD0})                     -- call rax
-- done:
w({0x48,0x83,0xC4,0x28})          -- add rsp, 28h
w({0xC3})                          -- ret

print("Creating book item...")
createRemoteThread(codeAddr)
sleep(500)

local newItem = readQword(resultAddr)
if not newItem or newItem == 0 then
  print("ERROR: il2cpp_object_new returned null")
  return
end

-- Verify item
local namePtr = readQword(newItem + 0x20)
local name = ""
if namePtr and namePtr ~= 0 then
  local nl = readInteger(namePtr + 0x10)
  if nl and nl > 0 and nl < 200 then name = readString(namePtr + 0x14, nl * 2, true) or "?" end
end
print(string.format("Created: %s (0x%X)", name, newItem))

-- Step 6: Insert into allItem
ia  = readQword(ail + 0x10)  -- re-read in case it changed
ic  = readInteger(ail + 0x18)
cap = readInteger(ia + 0x18)
if ic >= cap then print("ERROR: Inventory full"); return end

writeQword(ia + 0x20 + ic * 8, newItem)
writeInteger(ail + 0x18, ic + 1)

-- Step 7: Call OnDeserializedMethod to rebuild itemTypeList
local cave2 = allocateMemory(128)
if not cave2 then print("WARNING: Could not alloc for OnDeserialized, itemTypeList may be stale"); return end

writeBytes(cave2,    {0x48,0x83,0xEC,0x28})    -- sub rsp, 28h
writeBytes(cave2+4,  {0x48,0xB9})              -- mov rcx, ild
writeQword(cave2+6,  ild)
writeBytes(cave2+14, {0x33,0xD2})              -- xor edx, edx
writeBytes(cave2+16, {0x4D,0x31,0xC0})         -- xor r8, r8
writeBytes(cave2+19, {0x4D,0x31,0xC9})         -- xor r9, r9
writeBytes(cave2+22, {0x48,0xB8})              -- mov rax, OnDeserialized
writeQword(cave2+24, onDeserAddr)
writeBytes(cave2+32, {0xFF,0xD0})              -- call rax
writeBytes(cave2+34, {0x48,0x83,0xC4,0x28})    -- add rsp, 28h
writeBytes(cave2+38, {0xC3})                   -- ret

createRemoteThread(cave2)
sleep(300)

print(string.format("SUCCESS! '%s' added to inventory (total: %d)", name, readInteger(ail + 0x18)))
print("Open inventory to see the new book")
