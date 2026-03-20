-- ItemAdder.lua v3 - Main-thread execution via GameController.Update hook
-- CE Memory View > Tools > Lua Engine > Execute
--
-- Key change from v2: all game method calls (Clone, GetItem, SetBookData, etc.)
-- now execute on the game's main thread via a code cave hooked into
-- GameController.Update(). This fixes WriteZStream/GC crashes during autosave.

-- ============================================================
-- DATABASES FOR DROPDOWNS
-- ============================================================
local skillDB = {
  {279,"元始天功 内功"},{280,"飘飘欲仙 轻功"},{281,"虎啸龙吟 绝技"},
  {282,"照影神拳 拳掌"},{283,"诛仙剑法 剑法"},{284,"九州风雷刀 刀法"},
  {285,"大闹天宫棍 长兵"},{286,"碧海潮生曲 奇门"},{287,"多情飞刀 射术"},
  {317,"醉梦鱼龙舞 轻功"},{318,"净乐琉璃刀 刀法"},
  {352,"漫天花雨 绝技"},{353,"九天罗候针 射术"},
  {383,"黄帝秘经 内功"},{384,"灵犀一指 拳掌"},
  {419,"降龙掌法 拳掌"},{420,"打狗八绝棍 长兵"},
  {455,"帝王封禅功 绝技"},{456,"惊鸿一点枪 长兵"},
  {495,"遁甲天书 绝技"},{496,"天劫九重 奇门"},
  {526,"无尽剑意 剑法"},{566,"蚩尤鬼降 轻功"},
  {567,"万毒宝典 绝技"},{568,"金蚕王蛊 射术"},
  {604,"万恶魔功 内功"},{605,"血脉逆行 绝技"},{606,"杀人刀法 刀法"},
  {644,"归墟秘典 内功"},{645,"天人感应步 轻功"},{646,"轮回不灭法 绝技"},
  {689,"易筋经 内功"},{690,"洗髓经 内功"},
  {691,"金刚不坏神功 绝技"},{692,"达摩神杖 长兵"},
  {729,"太极神功 内功"},{730,"道德真经 绝技"},{731,"太极剑道 剑法"},
  {760,"霸刀一式 刀法"},{792,"敲爻歌诀 内功"},{793,"天遁剑法 剑法"},
  {825,"三洞灵宝经 内功"},{826,"诸天化身步 轻功"},
  {857,"斗转星移 绝技"},{887,"武库战车 轻功"},{888,"公输遗匣 奇门"},
  {917,"灭世天雷 射术"},{952,"大日如来功 内功"},
  {953,"龙象护法功 绝技"},{954,"因陀罗杵 奇门"},
  {989,"不老长春功 内功"},{990,"仙娥折梅 轻功"},
  {991,"白虹贯日掌 拳掌"},{992,"逆转周天大法 绝技"},
  {994,"心狂归藏功 内功"},{995,"龙胤归藏功 内功"},
}
local medDB = {
  {5,"万灵回生散 HP G5"},{11,"紫霄玄关散 MP G5"},{17,"九转还魂丹 Full G5"},
  {23,"天香断续散 Injury G5"},{29,"还阳正气丹 Meridian G5"},
  {4,"玉洞黑石丹 HP G4"},{10,"济生养气丸 MP G4"},{16,"生生造化丹 Full G4"},
  {22,"血府逐瘀散 Injury G4"},{28,"三黄宝腊丹 Meridian G4"},
  {3,"人参养荣丸 HP G3"},{9,"参苓白术散 MP G3"},{15,"天王补心丹 Full G3"},
}
local foodDB = {
  {5,"十全大补汤 Soup G5"},{11,"龙脑酒 Wine G5"},{17,"乳猪 Meat G5"},
  {23,"杜康酒 Wine G5"},{29,"烩八珍 Soup G5"},
  {4,"参茸熊掌 Soup G4"},{10,"虎骨酒 Wine G4"},{16,"红烧肉 Meat G4"},
  {22,"新丰酒 Wine G4"},{28,"四君子汤 Soup G4"},
  {3,"沙苑甲鱼汤 Soup G3"},{9,"鹿胎酒 Wine G3"},{15,"烧鸡 Meat G3"},
}
local horseDB = {
  {45,"神凫马 spd=95 G5"},{41,"赤兔马 spd=90 G5"},{43,"绝影马 spd=85 G5"},
  {40,"汗血马 spd=80 G5"},{42,"的卢马 spd=75 G5"},{47,"白龙驹 spd=70 G5"},
  {36,"斑豹马 spd=80 G4"},{35,"拳毛驹 spd=75 G4"},{33,"白蹄乌 spd=70 G4"},
}
local matDB = {
  {0,"Wood"},{1,"Ore"},{2,"Medicine"},{3,"Food Ingredient"},{4,"Poison"},
}

-- ============================================================
-- RVAs (from Il2CppDumper)
-- ============================================================
local RVA = {
  -- ItemData methods
  ctor       = 0xCDE970,  -- ItemData..ctor(ItemType)
  setBook    = 0xCDDD10,  -- SetBookData(skillID, rareLv)
  setMat     = 0xCDDE20,  -- SetMaterialData(subType, itemLv, rareLv)  (was 0xCDE1C0, check AOB)
  clone      = 0xCDB3B0,  -- ItemData.Clone()
  -- ItemListData
  ildCtor    = 0xCE6310,  -- ItemListData..ctor()
  mergeList  = 0xCE5880,  -- ItemListData.MergeList(ItemListData, bool)
  -- GameController generate methods (called on GC instance)
  genMedById   = 0x79DD10,  -- GenerateMedData(int id, float bossLv)
  genFoodById  = 0x796F20,  -- GenerateFoodData(int id, float bossLv)
  genHorseById = 0x79D2E0,  -- GenerateHorseData(int id, float bossLv)
  -- HeroData
  getItem    = 0x892A30,  -- GetItem(ItemData, showPop, showSpe, chestClick, skipPoison)
  -- GameController
  update     = 0x7D1B70,  -- Update()
}

-- AOB sigs for update-proofing (override RVAs if found)
local AOB_SIGS = {
  setBook   = {sig="48 8B 43 68 48 85 C0 0F 84 ?? ?? ?? ?? 89 78 10", off=0x3F},
  setMat    = {sig="89 6B 18 89 73 3C 89 7B 40", off=0x48},
  ctor      = {sig="C7 47 44 00 00 80 3F 48 8B CF E8 ?? ?? ?? ?? 89 5F 14 83 FB 06", off=0x6A},
  clone     = {sig="48 89 5C 24 08 57 48 83 EC 20 48 8B D9 E8 ?? ?? ?? ?? 48 8B F8 48 85 C0 74", off=0},
}

-- ============================================================
-- STATE
-- ============================================================
local S = {}

-- ============================================================
-- MAIN-THREAD HOOK
-- ============================================================
-- Command buffer layout (cmdBuf):
--   +0x00: command (dword)  0=idle, 1=addBook, 2=addMat, 3=addMedFood, 4=addHorse
--   +0x04: status  (dword)  0=pending, 1=done, 2=error
--   +0x08: param1  (dword)  e.g. skillID / subType / dbIndex
--   +0x0C: param2  (dword)  e.g. rareLv / itemLv / dbOffset
--   +0x10: param3  (dword)  e.g. rareLv for mat
--   +0x18: result  (qword)  returned item pointer
--   +0x20: gcInst  (qword)  GameController instance
--   +0x28: heroPtr (qword)  player HeroData pointer
--   +0x30: gdcInst (qword)  GameDataController instance
-- The hook runs inside GameController.Update on the main thread.
-- It checks cmdBuf+0, and if nonzero, dispatches the command.

local hookInstalled = false

local function installMainThreadHook()
  if hookInstalled then return true end
  local base = getAddress("GameAssembly.dll")
  if not base or base == 0 then return false end

  -- Resolve AOBs to override RVAs where possible
  for name, info in pairs(AOB_SIGS) do
    local r = AOBScan(info.sig, "+X")
    if r and stringlist_getCount(r) >= 1 then
      RVA[name] = tonumber(stringlist_getString(r, 0), 16) - info.off - base
      object_destroy(r)
    end
  end

  -- Build the AA script with resolved absolute addresses
  local function addr(rva) return string.format("%X", base + rva) end

  -- Generate methods: (GameController this, int id, float bossLv)
  -- x64 calling convention: rcx=this, edx=id, xmm2=bossLv (3rd param = float)
  -- HeroData.GetItem: rcx=this, rdx=ItemData, r8=showPop(bool), r9=showSpe(bool),
  --                   [rsp+20h]=chestClick(int), [rsp+28h]=skipPoison(bool)

  -- Read original bytes at Update() for restoration in the hook
  local updateAddr = base + RVA.update
  local origBytes = {}
  for i = 0, 15 do origBytes[i+1] = readBytes(updateAddr + i, 1) end
  -- Build hex string for readmem or db
  local origHex = ""
  for i = 1, 16 do origHex = origHex .. string.format("%02X ", origBytes[i]) end

  local aa = string.format([[
alloc(cmdBuf, 256)
alloc(hookCode, 2048)
registersymbol(cmdBuf)
registersymbol(hookCode)

cmdBuf:
dq 0 0 0 0 0 0 0 0 0 0

label(originalUpdate)
label(returnUpdate)
label(cmd3_medfood)
label(cmd4_horse)
label(tryFood)
label(afterGen)
label(genFail)
label(horseFail)
label(cmdDone)
label(cmdError)
label(noCmd)

%s:
  jmp hookCode
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
returnUpdate:

hookCode:
  push rax
  push rbx
  mov rbx,cmdBuf
  mov [rbx+20],rcx
  mov eax,[rbx]
  test eax,eax
  jz noCmd

  push rcx
  push rdx
  push r8
  push r9
  push r10
  push r11
  sub rsp,58

  cmp eax,3
  je cmd3_medfood
  cmp eax,4
  je cmd4_horse
  jmp cmdError

cmd3_medfood:
  mov rcx,[rbx+20]
  test rcx,rcx
  jz cmdError
  mov edx,[rbx+08]
  mov eax,42C80000
  movd xmm2,eax
  xor r9d,r9d
  mov eax,[rbx+0C]
  cmp eax,#272
  jne tryFood
  mov rax,%s
  call rax
  jmp afterGen
tryFood:
  mov rax,%s
  call rax
afterGen:
  test rax,rax
  jz genFail
  mov [rbx+18],rax
  mov rcx,[rbx+28]
  mov rdx,rax
  xor r8d,r8d
  inc r8d
  xor r9d,r9d
  inc r9d
  mov dword ptr [rsp+20],0
  mov byte ptr [rsp+28],0
  mov qword ptr [rsp+30],0
  mov rax,%s
  call rax
  jmp cmdDone

genFail:
  jmp cmdError

cmd4_horse:
  mov rcx,[rbx+20]
  test rcx,rcx
  jz cmdError
  mov edx,[rbx+08]
  mov eax,42C80000
  movd xmm2,eax
  xor r9d,r9d
  mov rax,%s
  call rax
  test rax,rax
  jz horseFail
  mov [rbx+18],rax
  mov rcx,[rbx+28]
  mov rdx,rax
  xor r8d,r8d
  inc r8d
  xor r9d,r9d
  inc r9d
  mov dword ptr [rsp+20],0
  mov byte ptr [rsp+28],0
  mov rax,%s
  call rax
  jmp cmdDone

horseFail:
  jmp cmdError

cmdDone:
  add rsp,58
  pop r11
  pop r10
  pop r9
  pop r8
  pop rdx
  pop rcx
  mov dword ptr [rbx+04],1
  mov dword ptr [rbx],0
  jmp noCmd

cmdError:
  add rsp,58
  pop r11
  pop r10
  pop r9
  pop r8
  pop rdx
  pop rcx
  mov dword ptr [rbx+04],2
  mov dword ptr [rbx],0

noCmd:
  pop rbx
  pop rax

originalUpdate:
  db %s
  jmp returnUpdate
]],
    addr(RVA.update),           -- hook location
    addr(RVA.genMedById),       -- GenerateMedData(int, float)
    addr(RVA.genFoodById),      -- GenerateFoodData(int, float)
    addr(RVA.getItem),          -- HeroData.GetItem
    addr(RVA.genHorseById),     -- GenerateHorseData(int, float)
    addr(RVA.getItem),          -- HeroData.GetItem (horse)
    origHex                     -- original bytes
  )

  local ok = autoAssemble(aa)
  if not ok then return false end
  hookInstalled = true
  return true
end

-- ============================================================
-- IL2CPP HELPERS (for discovery + book/material which work fine)
-- ============================================================
local WK = { code = nil, data = nil, str = nil }

local function allocWorkArea()
  if WK.code then return true end
  local ok = autoAssemble([[
alloc(wkCode, 512)
alloc(wkData, 512)
alloc(wkStr, 64)
registersymbol(wkCode)
registersymbol(wkData)
registersymbol(wkStr)
wkStr:
db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
wkData:
dq 0 0 0 0 0 0 0 0
wkCode:
ret
  ]])
  if not ok then return false end
  WK.code = getAddress("wkCode")
  WK.data = getAddress("wkData")
  WK.str = getAddress("wkStr")
  return true
end

local function shellExec(bytesFunc)
  local p = 0
  local function w(b) writeBytes(WK.code + p, b); p = p + #b end
  local function q(a) writeQword(WK.code + p, a); p = p + 8 end
  local function d(v) writeInteger(WK.code + p, v); p = p + 4 end
  bytesFunc(w, q, d)
  createRemoteThread(WK.code)
end

-- ============================================================
-- DISCOVERY
-- ============================================================
local function discover()
  S = {}
  S.base = getAddress("GameAssembly.dll")
  if not S.base or S.base == 0 then return false, "GameAssembly.dll not loaded" end

  if not allocWorkArea() then return false, "Work area alloc failed" end

  -- Install main-thread hook
  if not installMainThreadHook() then return false, "Hook install failed" end

  local domainGet = getAddress("GameAssembly.il2cpp_domain_get")
  local domainGetAsm = getAddress("GameAssembly.il2cpp_domain_get_assemblies")
  local imageFromAsm = getAddress("GameAssembly.il2cpp_assembly_get_image")
  local classFromName = getAddress("GameAssembly.il2cpp_class_from_name")
  local getStaticData = getAddress("GameAssembly.il2cpp_class_get_static_field_data")
  local objNew = getAddress("GameAssembly.il2cpp_object_new")
  if not objNew or objNew == 0 then return false, "il2cpp exports missing" end
  S.objNew = objNew

  -- Get domain + assemblies
  shellExec(function(w, q)
    w({0x48,0x83,0xEC,0x38})
    w({0x48,0xB8}); q(domainGet); w({0xFF,0xD0})
    w({0x48,0x8B,0xC8}); w({0x48,0x8D,0x54,0x24,0x20})
    w({0x48,0xB8}); q(domainGetAsm); w({0xFF,0xD0})
    w({0x48,0xA3}); q(WK.data)
    w({0x8B,0x44,0x24,0x20}); w({0x48,0xA3}); q(WK.data + 8)
    w({0x48,0x83,0xC4,0x38}); w({0xC3})
  end)
  sleep(300)
  local asmArr = readQword(WK.data)
  local asmCnt = readQword(WK.data + 8)
  if not asmArr or asmArr == 0 then return false, "No assemblies" end

  -- Find class helper
  local nsA = WK.str
  local nmA = WK.str + 8
  writeBytes(nsA, {0x00})

  local function findClass(name)
    local b = {}
    for i = 1, #name do b[i] = string.byte(name, i) end
    b[#b + 1] = 0
    writeBytes(nmA, b)
    for i = 0, asmCnt - 1 do
      local ap = readQword(asmArr + i * 8)
      if ap and ap ~= 0 then
        writeQword(WK.data + 0x10, 0)
        shellExec(function(w, q)
          w({0x48,0x83,0xEC,0x28})
          w({0x48,0xB9}); q(ap); w({0x48,0xB8}); q(imageFromAsm); w({0xFF,0xD0})
          w({0x48,0x8B,0xC8}); w({0x48,0xBA}); q(nsA); w({0x49,0xB8}); q(nmA)
          w({0x48,0xB8}); q(classFromName); w({0xFF,0xD0})
          w({0x48,0xA3}); q(WK.data + 0x10)
          w({0x48,0x83,0xC4,0x28}); w({0xC3})
        end)
        sleep(50)
        local cls = readQword(WK.data + 0x10)
        if cls and cls ~= 0 then return cls end
      end
    end
    return nil
  end

  local gcClass = findClass("GameController")
  if not gcClass then return false, "GameController not found" end
  local gdcClass = findClass("GameDataController")

  -- Get static data
  shellExec(function(w, q)
    w({0x48,0x83,0xEC,0x28})
    w({0x48,0xB9}); q(gcClass); w({0x48,0xB8}); q(getStaticData); w({0xFF,0xD0})
    w({0x48,0xA3}); q(WK.data + 0x20)
    if gdcClass then
      w({0x48,0xB9}); q(gdcClass); w({0x48,0xB8}); q(getStaticData); w({0xFF,0xD0})
      w({0x48,0xA3}); q(WK.data + 0x28)
    end
    w({0x48,0x83,0xC4,0x28}); w({0xC3})
  end)
  sleep(200)

  local gc = readQword(readQword(WK.data + 0x20))
  if not gc or gc == 0 then return false, "GC._instance null (load save)" end
  S.gc = gc

  if gdcClass then
    local gdcStatic = readQword(WK.data + 0x28)
    if gdcStatic and gdcStatic ~= 0 then S.gdc = readQword(gdcStatic + 0x20) end
  end

  -- Navigate to player HeroData
  local wd = readQword(gc + 0x20)
  if not wd or wd == 0 then return false, "WorldData null" end
  local ph = readQword(readQword(readQword(wd + 0x50) + 0x10) + 0x20)
  S.hero = ph
  S.ild = readQword(ph + 0x220)
  S.ildKlass = readQword(S.ild)

  -- Count items
  local ail = readQword(S.ild + 0x28)
  local ic = readInteger(ail + 0x18)

  -- Get klass pointers from live items (still needed for book/mat via shellcode)
  local ia = readQword(ail + 0x10)
  for i = 0, ic - 1 do
    local it = readQword(ia + 0x20 + i * 8)
    if it and it ~= 0 then
      if not S.itemKlass then S.itemKlass = readQword(it) end
    end
  end
  if not S.itemKlass then return false, "No items in inventory" end

  -- Write pointers to cmdBuf for the hook
  local cmdBuf = getAddress("cmdBuf")
  S.cmdBuf = cmdBuf
  writeQword(cmdBuf + 0x28, S.hero)  -- heroPtr
  writeQword(cmdBuf + 0x30, S.gdc or 0)   -- gdcInst

  S.ready = true
  return true, string.format("OK! %d items. Hook:Y GDC:%s", ic, S.gdc and "Y" or "N")
end

-- ============================================================
-- MAIN-THREAD COMMAND DISPATCH
-- ============================================================
local function mainThreadCmd(cmd, p1, p2, p3, timeout)
  if not S.cmdBuf then return false, "Not connected" end
  timeout = timeout or 3000
  -- Write params
  writeInteger(S.cmdBuf + 0x08, p1 or 0)
  writeInteger(S.cmdBuf + 0x0C, p2 or 0)
  writeInteger(S.cmdBuf + 0x10, p3 or 0)
  writeQword(S.cmdBuf + 0x18, 0) -- clear result
  writeInteger(S.cmdBuf + 0x04, 0) -- status = pending
  -- Issue command (atomic write triggers the hook)
  writeInteger(S.cmdBuf, cmd)
  -- Wait for completion
  local elapsed = 0
  while elapsed < timeout do
    local status = readInteger(S.cmdBuf + 0x04)
    if status == 1 then
      local result = readQword(S.cmdBuf + 0x18)
      return true, result
    elseif status == 2 then
      return false, "Command failed"
    end
    sleep(16) -- one frame at 60fps
    elapsed = elapsed + 16
  end
  return false, "Timeout"
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getItemName(ptr)
  if not ptr or ptr == 0 then return "?" end
  local np = readQword(ptr + 0x20)
  if not np or np == 0 then return "?" end
  local nl = readInteger(np + 0x10)
  if not nl or nl <= 0 or nl > 200 then return "?" end
  return readString(np + 0x14, nl * 2, true) or "?"
end

local function allocItem()
  writeQword(WK.data, 0)
  shellExec(function(w, q)
    w({0x48,0x83,0xEC,0x28})
    w({0x48,0xB9}); q(S.itemKlass)
    w({0x48,0xB8}); q(S.objNew); w({0xFF,0xD0})
    w({0x48,0xA3}); q(WK.data)
    w({0x48,0x83,0xC4,0x28}); w({0xC3})
  end)
  sleep(300)
  return readQword(WK.data)
end

local function callFunc(thisPtr, funcRVA, arg1, arg2, arg3)
  shellExec(function(w, q, d)
    w({0x48,0x83,0xEC,0x28})
    w({0x48,0xB9}); q(thisPtr)
    if arg1 then w({0xBA}); d(arg1) else w({0x33,0xD2}) end
    if arg2 then w({0x41,0xB8}); d(arg2) else w({0x45,0x33,0xC0}) end
    if arg3 then w({0x41,0xB9}); d(arg3) else w({0x4D,0x31,0xC9}) end
    w({0x48,0xB8}); q(S.base + funcRVA); w({0xFF,0xD0})
    w({0x48,0x83,0xC4,0x28}); w({0xC3})
  end)
  sleep(300)
end

local function mergeIntoInventory(itemPtr)
  writeQword(WK.data + 0x10, 0)
  shellExec(function(w, q)
    w({0x48,0x83,0xEC,0x28})
    w({0x48,0xB9}); q(S.ildKlass); w({0x48,0xB8}); q(S.objNew); w({0xFF,0xD0})
    w({0x48,0x85,0xC0}); w({0x74,0x35})
    w({0x48,0xA3}); q(WK.data + 0x10)
    w({0x48,0x8B,0xC8}); w({0x33,0xD2})
    w({0x48,0xB8}); q(S.base + RVA.ildCtor); w({0xFF,0xD0})
    w({0x48,0xA1}); q(WK.data + 0x10)
    w({0x48,0x8B,0x48,0x28}); w({0x48,0x8B,0x51,0x10})
    w({0x48,0xB8}); q(itemPtr)
    w({0x48,0x89,0x42,0x20})
    w({0xC7,0x41,0x18,0x01,0x00,0x00,0x00})
    w({0x48,0xB9}); q(S.ild)
    w({0x48,0xA1}); q(WK.data + 0x10)
    w({0x48,0x8B,0xD0}); w({0x45,0x33,0xC0})
    w({0x48,0xB8}); q(S.base + RVA.mergeList); w({0xFF,0xD0})
    w({0x48,0x83,0xC4,0x28}); w({0xC3})
  end)
  sleep(400)
end

-- ============================================================
-- ADD FUNCTIONS
-- ============================================================

-- Book: uses shellcode (already stable, no GC issues)
local function addBook(skillID, rareLv)
  if not S.ready then return false, "Connect first" end
  local ni = allocItem()
  if not ni or ni == 0 then return false, "alloc fail" end
  callFunc(ni, RVA.ctor, 3)
  callFunc(ni, RVA.setBook, skillID, rareLv)
  mergeIntoInventory(ni)
  return true, getItemName(ni)
end

-- Material: uses shellcode (already stable)
local function addMaterial(subType, itemLv, rareLv)
  if not S.ready then return false, "Connect first" end
  local ni = allocItem()
  if not ni or ni == 0 then return false, "alloc fail" end
  callFunc(ni, RVA.ctor, 5)
  callFunc(ni, RVA.setMat, subType, itemLv, rareLv)
  mergeIntoInventory(ni)
  return true, getItemName(ni)
end

-- Med/Food: MAIN THREAD via GameController.GenerateMedData/GenerateFoodData + HeroData.GetItem
local function addMedFood(dbIndex, dbOffset)
  if not S.ready then return false, "Connect first" end
  -- cmd=3, param1=id, param2=dbOffset
  local ok, result = mainThreadCmd(3, dbIndex, dbOffset)
  if not ok then return false, result end
  -- result = ItemData pointer (or 0)
  if result and result ~= 0 then
    return true, getItemName(result)
  end
  return true, "Added (name pending)"
end

-- Horse: MAIN THREAD via GameController.GenerateHorseData + HeroData.GetItem
local function addHorse(dbIndex)
  if not S.ready then return false, "Connect first" end
  -- cmd=4, param1=id
  local ok, result = mainThreadCmd(4, dbIndex)
  if not ok then return false, result end
  if result and result ~= 0 then
    return true, getItemName(result)
  end
  return true, "Added (name pending)"
end

-- ============================================================
-- GUI
-- ============================================================
if _itemAdderForm then _itemAdderForm.destroy() end
local frm = createForm(false)
_itemAdderForm = frm
frm.Caption = "LongYinLiZhiZhuan Item Adder v3 (Main Thread)"
frm.Width = 520; frm.Height = 480
frm.Position = "poScreenCenter"; frm.BorderStyle = "bsSingle"

local Y = 10
local lblStatus = createLabel(frm)
lblStatus.Left = 10; lblStatus.Top = 445; lblStatus.Width = 500
lblStatus.Caption = "Click Connect first"; lblStatus.Font.Color = 0x808080
local function setStatus(msg, color) lblStatus.Caption = msg; lblStatus.Font.Color = color or 0 end

-- CONNECT
local btnConn = createButton(frm)
btnConn.Left = 10; btnConn.Top = Y; btnConn.Width = 130; btnConn.Height = 28
btnConn.Caption = "Connect to Game"
btnConn.OnClick = function()
  setStatus("Connecting...", 0x008080)
  local ok, msg = discover()
  setStatus(ok and msg or ("ERR: " .. msg), ok and 0x008000 or 0x0000FF)
end
Y = Y + 38

-- BOOK
local lbl = createLabel(frm); lbl.Left = 10; lbl.Top = Y; lbl.Caption = "Martial Arts Book (G5)"
lbl.Font.Size = 9; lbl.Font.Style = "fsBold"; Y = Y + 20
local cmbSk = createComboBox(frm); cmbSk.Left = 10; cmbSk.Top = Y; cmbSk.Width = 320
for _, s in ipairs(skillDB) do cmbSk.Items.add(string.format("[%d] %s", s[1], s[2])) end
cmbSk.ItemIndex = 0
local edtID = createEdit(frm); edtID.Left = 340; edtID.Top = Y; edtID.Width = 50; edtID.Text = ""; edtID.Hint = "ID 0-999"; edtID.ShowHint = true
local lblIDHint = createLabel(frm); lblIDHint.Left = 342; lblIDHint.Top = Y - 14; lblIDHint.Caption = "ID 0-999"; lblIDHint.Font.Size = 7; lblIDHint.Font.Color = 0x808080
local btnBook = createButton(frm); btnBook.Left = 400; btnBook.Top = Y - 2; btnBook.Width = 100; btnBook.Height = 24
btnBook.Caption = "Add Book"
btnBook.OnClick = function()
  if not S.ready then setStatus("Connect first!", 0x0000FF); return end
  local sid = edtID.Text ~= "" and tonumber(edtID.Text) or skillDB[cmbSk.ItemIndex + 1][1]
  setStatus("Adding...", 0x008080)
  local ok, msg = addBook(sid, 5)
  setStatus(ok and ("Added: " .. msg) or ("ERR: " .. msg), ok and 0x008000 or 0x0000FF)
end
Y = Y + 32

-- MATERIAL
lbl = createLabel(frm); lbl.Left = 10; lbl.Top = Y; lbl.Caption = "Material"
lbl.Font.Size = 9; lbl.Font.Style = "fsBold"; Y = Y + 20
local cmbMT = createComboBox(frm); cmbMT.Left = 10; cmbMT.Top = Y; cmbMT.Width = 140
for _, m in ipairs(matDB) do cmbMT.Items.add(m[1] .. "-" .. m[2]) end; cmbMT.ItemIndex = 1
local lblML = createLabel(frm); lblML.Left = 160; lblML.Top = Y + 3; lblML.Caption = "Lv:"
local cmbML = createComboBox(frm); cmbML.Left = 180; cmbML.Top = Y; cmbML.Width = 35
for i = 0, 5 do cmbML.Items.add(tostring(i)) end; cmbML.ItemIndex = 5
local btnMat = createButton(frm); btnMat.Left = 400; btnMat.Top = Y - 2; btnMat.Width = 100; btnMat.Height = 24
btnMat.Caption = "Add Material"
btnMat.OnClick = function()
  if not S.ready then setStatus("Connect first!", 0x0000FF); return end
  setStatus("Adding...", 0x008080)
  local ok, msg = addMaterial(cmbMT.ItemIndex, cmbML.ItemIndex, 5)
  setStatus(ok and ("Added: " .. msg) or ("ERR: " .. msg), ok and 0x008000 or 0x0000FF)
end
Y = Y + 32

-- HORSE
lbl = createLabel(frm); lbl.Left = 10; lbl.Top = Y; lbl.Caption = "Horse"
lbl.Font.Size = 9; lbl.Font.Style = "fsBold"; Y = Y + 20
local cmbHr = createComboBox(frm); cmbHr.Left = 10; cmbHr.Top = Y; cmbHr.Width = 320
for _, h in ipairs(horseDB) do cmbHr.Items.add(string.format("[%d] %s", h[1], h[2])) end; cmbHr.ItemIndex = 0
local btnHr = createButton(frm); btnHr.Left = 400; btnHr.Top = Y - 2; btnHr.Width = 100; btnHr.Height = 24
btnHr.Caption = "Add Horse"
btnHr.OnClick = function()
  if not S.ready then setStatus("Connect first!", 0x0000FF); return end
  setStatus("Adding...", 0x008080)
  local ok, msg = addHorse(horseDB[cmbHr.ItemIndex + 1][1])
  setStatus(ok and ("Added: " .. msg) or ("ERR: " .. msg), ok and 0x008000 or 0x0000FF)
end
Y = Y + 32

-- MEDICINE
lbl = createLabel(frm); lbl.Left = 10; lbl.Top = Y; lbl.Caption = "Medicine (Main Thread)"
lbl.Font.Size = 9; lbl.Font.Style = "fsBold"; Y = Y + 20
local cmbMed = createComboBox(frm); cmbMed.Left = 10; cmbMed.Top = Y; cmbMed.Width = 320
for _, m in ipairs(medDB) do cmbMed.Items.add(string.format("[%d] %s", m[1], m[2])) end; cmbMed.ItemIndex = 0
local btnMed = createButton(frm); btnMed.Left = 400; btnMed.Top = Y - 2; btnMed.Width = 100; btnMed.Height = 24
btnMed.Caption = "Add Medicine"
btnMed.OnClick = function()
  if not S.ready then setStatus("Connect first!", 0x0000FF); return end
  setStatus("Adding...", 0x008080)
  local ok, msg = addMedFood(medDB[cmbMed.ItemIndex + 1][1], 0x110)
  setStatus(ok and ("Added: " .. msg) or ("ERR: " .. msg), ok and 0x008000 or 0x0000FF)
end
Y = Y + 32

-- FOOD
lbl = createLabel(frm); lbl.Left = 10; lbl.Top = Y; lbl.Caption = "Food (Main Thread)"
lbl.Font.Size = 9; lbl.Font.Style = "fsBold"; Y = Y + 20
local cmbFd = createComboBox(frm); cmbFd.Left = 10; cmbFd.Top = Y; cmbFd.Width = 320
for _, f in ipairs(foodDB) do cmbFd.Items.add(string.format("[%d] %s", f[1], f[2])) end; cmbFd.ItemIndex = 0
local btnFd = createButton(frm); btnFd.Left = 400; btnFd.Top = Y - 2; btnFd.Width = 100; btnFd.Height = 24
btnFd.Caption = "Add Food"
btnFd.OnClick = function()
  if not S.ready then setStatus("Connect first!", 0x0000FF); return end
  setStatus("Adding...", 0x008080)
  local ok, msg = addMedFood(foodDB[cmbFd.ItemIndex + 1][1], 0x118)
  setStatus(ok and ("Added: " .. msg) or ("ERR: " .. msg), ok and 0x008000 or 0x0000FF)
end

frm.Show()
