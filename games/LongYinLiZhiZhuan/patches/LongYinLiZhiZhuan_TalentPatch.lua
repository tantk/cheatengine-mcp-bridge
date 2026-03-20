-- LongYinLiZhiZhuan (龙隐力之传) - Talent Cap Patch
-- Increases max talent (天赋/Tag) slots from 9 to 99
--
-- Game: LongYinLiZhiZhuan.exe (Unity Mono, 64-bit)
-- Target: HeroData.GetMaxTagNum() method
--
-- The talent system is called "Tag" in code (天赋 in Chinese UI).
-- Talents include: 掌风, 经脉, 学识, 智力, etc.
--
-- GetMaxTagNum() has 3 return paths:
--   Path 1: returns 5  (special condition)
--   Path 2: returns [rax+A0] + 9  (main path, base + 9)
--   Path 3: returns 10 (when [this+0x58] != 0)
--
-- This patch changes the "add eax, 9" to "add eax, 99" in Path 2.

-- Activate mono data collector
LaunchMonoDataCollector()

-- Find and compile GetMaxTagNum
local classId = mono_findClass("", "HeroData")
local methods = mono_class_enumMethods(classId)

local targetAddr = nil
for _, m in ipairs(methods) do
  if m.name == "GetMaxTagNum" then
    targetAddr = mono_compile_method(m.method)
    break
  end
end

if not targetAddr or targetAddr == 0 then
  print("[TalentPatch] ERROR: Could not find GetMaxTagNum method")
  return
end

print(string.format("[TalentPatch] GetMaxTagNum compiled at: 0x%X", targetAddr))

-- Scan for the "add eax, 09" instruction (83 C0 09) within the method body
-- Search within 256 bytes of the method start
local found = false
for offset = 0, 255 do
  local b1 = readBytes(targetAddr + offset, 1)
  local b2 = readBytes(targetAddr + offset + 1, 1)
  local b3 = readBytes(targetAddr + offset + 2, 1)
  if b1 == 0x83 and b2 == 0xC0 and b3 == 0x09 then
    -- Verify next instruction is "add rsp, 20" (48 83 C4 20) to confirm context
    local b4 = readBytes(targetAddr + offset + 3, 1)
    local b5 = readBytes(targetAddr + offset + 4, 1)
    if b4 == 0x48 and b5 == 0x83 then
      local patchAddr = targetAddr + offset + 2
      writeBytes(patchAddr, 0x63) -- Change 9 to 99
      print(string.format("[TalentPatch] Patched at 0x%X: add eax,09 -> add eax,63 (99)", targetAddr + offset))
      found = true
      break
    end
  end
end

if not found then
  print("[TalentPatch] ERROR: Could not find patch target (add eax, 09)")
end
