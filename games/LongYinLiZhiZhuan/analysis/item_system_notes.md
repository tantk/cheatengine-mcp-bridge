# LongYinLiZhiZhuan Item System Analysis

## IL2CPP Method RVAs (stable across sessions, add to GameAssembly.dll base)

### Item Creation
| Method | RVA | Signature |
|--------|-----|-----------|
| il2cpp_object_new | exported symbol | `Object* il2cpp_object_new(Il2CppClass*)` |
| ItemData..ctor(ItemType) | 0xCDE970 | `void .ctor(ItemType _type)` |
| ItemData.Clone | 0xCDB3B0 | `object Clone()` |

### Set Methods (initialize item by type - all on ItemData)
| Method | RVA | Signature |
|--------|-----|-----------|
| SetBookData | 0xCDDD10 | `ItemData SetBookData(int _skillID, int _rareLv)` |
| SetMaterialData | 0xCDDE20 | `ItemData SetMaterialData(int _subType, int _itemLv, int _rareLv)` |
| SetTreasureData | 0xCDDF40 | `ItemData SetTreasureData(int _subType, int _itemLv, int _rareLv)` |

### Generate Methods (on GameController - need instance)
| Method | RVA | Signature |
|--------|-----|-----------|
| GenerateBook | 0x795110 | `ItemData GenerateBook(int skillLv, float bossLv, int forceID, Random rand)` |
| GenerateMedData | 0x79DD10 | `ItemData GenerateMedData(int id, float bossLv)` |
| GenerateFoodData | 0x796F20 | `ItemData GenerateFoodData(int id, float bossLv)` |
| GenerateHorseData | 0x79D2E0 | `ItemData GenerateHorseData(int id, float bossLv)` |
| GenerateWeapon | 0x7A5B90 | `ItemData GenerateWeapon(int itemLv, int weaponID, float bossLv, HeroData)` |
| GenerateArmor | 0x794430 | `ItemData GenerateArmor(int itemLv, int littleType, float bossLv, HeroData)` |
| GenerateHelmet | 0x798D50 | `ItemData GenerateHelmet(int itemLv, int littleType, float bossLv, HeroData)` |
| GenerateShoes | 0x7A3C50 | `ItemData GenerateShoes(int itemLv, int littleType, float bossLv, HeroData)` |
| GenerateDecoration | 0x796330 | `ItemData GenerateDecoration(int itemLv, int littleType, float bossLv, HeroData)` |
| GenerateMaterial | 0x79DC30 | `ItemData GenerateMaterial(int itemLv, float bossLv)` |
| GenerateTreasure | 0x7A5A00 | `ItemData GenerateTreasure(int treasureType, int itemLv)` |

### Inventory Management (on ItemListData)
| Method | RVA | Signature |
|--------|-----|-----------|
| MergeList/GetItem | 0xCE5880 | `void MergeList(ItemListData target)` |
| RemoveList/LoseItem | 0xCE6100 | `void RemoveList(ItemListData target)` |
| OnDeserializedMethod | 0xCE61B0 | `void OnDeserializedMethod(StreamingContext)` |
| ClearAllItem | 0xCE4DD0 | `void ClearAllItem()` |
| ItemListData..ctor | 0xCE6310 | `void .ctor()` |

## ItemType Enum
| Value | Type |
|-------|------|
| 0 | Equip |
| 1 | Med |
| 2 | Food |
| 3 | Book |
| 4 | Treasure |
| 5 | Material |
| 6 | Horse |

## Memory Layout
```
GameController._instance (find via mono static field)
  +0x20 -> WorldData
    +0x50 -> Heros (List<HeroData>)
      [0] -> Player HeroData
        +0x220 -> ItemListData
          +0x28 -> allItem (List<ItemData>)
          +0x30 -> itemTypeList (List<List<ItemData>>) [JsonIgnore, rebuilt by OnDeserializedMethod]
```

## ItemData Layout
| Offset | Field | Type |
|--------|-------|------|
| 0x00 | klass (Il2CppClass*) | ptr |
| 0x10 | itemID | int32 |
| 0x14 | type (ItemType) | int32 |
| 0x18 | subType | int32 |
| 0x20 | name | string |
| 0x28 | checkName | string |
| 0x30 | describe | string |
| 0x38 | value | int32 |
| 0x3C | itemLv | int32 |
| 0x40 | rareLv | int32 |
| 0x44 | weight | float |
| 0x48 | isNew | bool |
| 0x58 | equipmentData | EquipmentData |
| 0x60 | medFoodData | MedFoodData |
| 0x68 | bookData | BookData |
| 0x70 | treasureData | TreasureData |
| 0x78 | materialData | MaterialData |
| 0x80 | horseData | HorseData |

## Proven Working Approach (Books, Materials)

**Full flow — stable, no crashes:**
1. `il2cpp_object_new(ItemData klass)` — allocate in managed heap
2. `.ctor(ItemType.Book=3)` — initialize as book
3. `SetBookData(skillID, rareLv)` — sets name, icon, value, everything from game DB
4. `il2cpp_object_new(ItemListData klass)` — create temp container
5. `ItemListData..ctor()` — initialize temp container
6. Manually write item into temp container's allItem[0], set count=1
7. `player.ItemListData.MergeList(tempContainer)` — game handles both lists correctly

**Key: use `createRemoteThread` not `executeCodeEx` (executeCodeEx doesn't work in this game)**

### Adding a Book
```
il2cpp_object_new(ItemData klass)
.ctor(ItemType.Book = 3)
SetBookData(skillID, rareLv)          -- RVA 0xCDDD10
  params: rcx=this, edx=skillID(0-999), r8d=rareLv(1-5)
  sets: name, icon, value, weight, bookData.skillID from game database
MergeList into player inventory
```

### Adding a Material
```
il2cpp_object_new(ItemData klass)
.ctor(ItemType.Material = 5)
SetMaterialData(subType, itemLv, rareLv)  -- RVA 0xCDDE20
  params: rcx=this, edx=subType, r8d=itemLv(0-5), r9d=rareLv(1-5)
  subTypes: 0=木材(wood), 1=矿料(ore), 2=药引(medicine), 3=食材(food), 4=毒物(poison)
  itemLv 5 = 绝世(legendary) prefix
MergeList into player inventory
```

### Adding a Horse
No SetHorseData method exists. Use manual field approach:
```
il2cpp_object_new(ItemData klass)
.ctor(ItemType.Horse = 6)
il2cpp_object_new(HorseData klass)     -- must create HorseData separately
Set newItem.horseData (offset 0x80) = newHorseData ptr
MergeList into player inventory
Then manually set fields on both objects (see below)
```

**ItemData fields to set (copy name from existing horse):**
- name (0x20): copy from template horse
- checkName (0x28): copy from template
- describe (0x30): copy from template
- value (0x38): e.g. 5000
- itemLv (0x3C): 0-5
- rareLv (0x40): 1-5
- weight (0x44): e.g. 3.0

**HorseData fields (all System.Single/float):**
| Offset | Field | Description |
|--------|-------|-------------|
| 0x10 | equiped | bool - is equipped |
| 0x14 | speed | base speed (existing horse ~46) |
| 0x18 | power | base power |
| 0x1C | sprint | sprint speed |
| 0x20 | resist | resistance |
| 0x24 | speedAdd | bonus speed |
| 0x28 | powerAdd | bonus power |
| 0x2C | sprintAdd | bonus sprint |
| 0x30 | resistAdd | bonus resist |
| 0x34 | maxWeightAdd | bonus carry weight |
| 0x38 | nowPower | current stamina/energy |
| 0x3C | favorRate | tame level / affinity |
| 0x40 | sprintTimeLeft | sprint duration remaining |
| 0x44 | sprintTimeCd | sprint cooldown |

**Note:** Horse name is borrowed from an existing horse in inventory (no Set method to auto-resolve names). For proper names, would need to find the horse name database lookup.

### Adding Medicine (type=1) or Food (type=2)
No SetMedData/SetFoodData exists. Both use the same MedFoodData sub-object.
```
il2cpp_object_new(ItemData klass)
.ctor(ItemType.Med=1 or ItemType.Food=2)
il2cpp_object_new(MedFoodData klass)      -- must create separately
Set newItem.medFoodData (offset 0x60) = newMedFoodData ptr
MergeList into player inventory
Then manually set fields (copy from existing item)
```

**ItemData fields:** same as Horse — copy name/checkName/describe from template, set value/itemLv/rareLv.

**MedFoodData fields:**
| Offset | Field | Type | Notes |
|--------|-------|------|-------|
| 0x10 | enhanceLv | Int32 | enhancement level |
| 0x18 | changeHeroState | ChangeHeroStateData | the actual consumption effect (healing, buffs) |
| 0x20 | randomSpeAddValue | Int32 | random bonus value |
| 0x28 | extraAddData | HeroSpeAddData | extra stat bonuses |

**IMPORTANT:** `changeHeroState` and `extraAddData` must be copied from an existing med/food item.
If these are null (0x0), the item appears in inventory but **cannot be consumed**.
Copy both pointers from a template item that has valid effects (check chs != 0).

**Med subTypes observed:** 0 (general medicine)
**Food subTypes observed:** 0=粥/糕(porridge/cake), 1=酒(wine)

**Limitation (OLD):** Was cloning from inventory templates. Name/effect borrowed.

### UPDATED: Adding Med/Food from Game Database (Proper Names + Effects)

The `GameDataController` has full item databases at:
- `medDataBase` offset 0x110: `List<ItemData>` — 36 medicines (6 categories x 6 levels 0-5)
- `foodDataBase` offset 0x118: `List<ItemData>` — 36 foods (same structure)
- `horseDataBase` offset 0x120: `List<ItemData>` — horses

Find `GameDataController._instance` via il2cpp API (static offset 0x20).

**CRITICAL: Deep Copy Approach (prevents GC/serializer crashes)**

The game's GC periodically scans all managed objects. If two objects share internal
reference-type pointers (e.g., item + DB template both point to same ChangeHeroStateData),
the serializer crashes in WriteZStream.

**Solution: allocate ALL objects fresh, copy only value-type fields.**

```
Step 1: Allocate fresh objects
  - il2cpp_object_new(ItemData klass)
  - il2cpp_object_new(MedFoodData klass)
  - il2cpp_object_new(ChangeHeroStateData klass) + call .ctor() [RVA 0xA09090]
    (.ctor creates fresh internal List<int>, avoiding shared references)
  - Link: item.medFoodData = newMFD, mfd.changeHeroState = newCHS

Step 2: Copy value-type fields from DB template
  - ItemData: type, subType, name*, checkName*, describe*, value, itemLv, rareLv, weight
    (* = string pointers, safe to share — strings are immutable in IL2CPP)
  - MedFoodData: enhanceLv (int), randomSpeAddValue (int)
  - ChangeHeroStateData: hp, maxhp, mana, maxMana, power, maxPower,
    externalInjury, internalInjury, poisonInjury, charm (ALL floats, 0x10-0x40)
  - DO NOT copy: changeAttri (List<int>, 0x38) — .ctor created fresh empty list
  - DO NOT copy: buffData (HeroSpeAddData, 0x48) — leave null, not needed for basic effects
  - DO NOT copy: extraAddData (MedFoodData.0x28) — leave null

Step 3: MergeList into player inventory
```

**WHY .ctor for ChangeHeroStateData:** It allocates internal `List<int>` (changeAttri).
Without .ctor, this field is null and the GC crashes when serializing.

**WHY NO .ctor for ItemData:** .ctor(Med=1) and .ctor(Food=2) crash from createRemoteThread.
Not needed — we copy all fields from DB template including type field.

**ChangeHeroStateData Layout:**
| Offset | Field | Type | Copy? |
|--------|-------|------|-------|
| 0x10 | hp | float | YES — healing amount |
| 0x14 | maxhp | float | YES |
| 0x18 | mana | float | YES — mana recovery |
| 0x1C | maxMana | float | YES |
| 0x20 | power | float | YES |
| 0x24 | maxPower | float | YES |
| 0x28 | externalInjury | float | YES |
| 0x2C | internalInjury | float | YES |
| 0x30 | poisonInjury | float | YES |
| 0x38 | changeAttri | List<int> | NO — .ctor creates fresh |
| 0x40 | charm | float | YES |
| 0x48 | buffData | HeroSpeAddData | NO — leave null |

**Grade 5 Medicine (DB indices):**
| Idx | Name | Effect |
|-----|------|--------|
| 5 | 万灵回生散 | HP recovery |
| 11 | 紫霄玄关散 | MP/Qi recovery |
| 17 | 九转还魂丹 | Full recovery |
| 23 | 天香断续散 | Injury healing |
| 29 | 还阳正气丹 | Meridian healing |

**Grade 5 Food (DB indices):**
| Idx | Name | Type |
|-----|------|------|
| 5 | 十全大补汤 | Soup |
| 11 | 龙脑酒 | Wine |
| 17 | 乳猪 | Meat |
| 23 | 杜康酒 | Wine |
| 29 | 烩八珍 | Soup |

## What Doesn't Work
- executeCodeEx: does NOT execute code in this game
- Manual insert into allItem + itemTypeList: crashes (inconsistent state)
- Manual insert into allItem + OnDeserializedMethod: works once, unstable for multiple items
- SetTreasureData: incomplete initialization, crashes (TreasureData has complex lists)
- ItemData.Clone(): returns null — possibly needs MethodInfo* param or main thread
- Copying reference-type pointers from DB: GC crash in WriteZStream (shared pointers)
- GenerateTreasure(int,int): returns null — needs investigation
- GenerateBook: returns null — complex params (float, Random object)
- GenerateHorseData: crashes game — needs main thread, not createRemoteThread
- All GameController.Generate* methods: likely need main thread execution

## What Works (CONFIRMED)
- Book: allocItem + ctor(3) + SetBookData + MergeList ✅
- Material: allocItem + ctor(5) + SetMaterialData + MergeList ✅
- Horse: allocItem + ctor(3) + fixType(6) + allocSubObj(HorseData) + copy value fields from DB + MergeList ✅
- Med/Food: allocItem + ctor(3) + fixType(1/2) + allocSubObj(MedFoodData)
  + allocSubObj(ChangeHeroStateData) + CHS.ctor + allocSubObj(HeroSpeAddData) + HSA.ctor
  + copy value fields + MergeList ✅ (with healing effects!)

## Critical Lessons
- **Always call ItemData.ctor()** even for manual items. Use ctor(3/Book) as a safe type
  that works from non-main thread, then change `type` field and swap sub-data references.
  Skipping ctor causes WriteZStream/GC crashes during autosave because IL2CPP internal
  state is not initialized.
- **Don't call createRemoteThread twice** on the same code. `shellExec()` already calls it.
- **Allocate HeroSpeAddData for MedFoodData.extraAddData** — prevents NullReferenceException
  in QuickDetail.ShowMedFoodQuickDetail (tooltip crash). HeroSpeAddData.ctor RVA: 0xBA0A20.
- **Copy float fields with writeFloat**, not writeInteger — avoids potential issues with
  padding bytes between float fields and reference fields.

## Console Commands (built-in, need GameConsoleController active)
tagpoint, conquer, herofavor, money, test, getbook, stopwar, fame, changemp, loyal, invincible, startplot, getfood, gethelmet, changeyear, randomitem, clear
