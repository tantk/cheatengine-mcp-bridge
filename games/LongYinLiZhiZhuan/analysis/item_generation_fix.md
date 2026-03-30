# Item Generation Fix — Use Game's Generate Methods

## Problem

Materials, medicine, food, and horses created by the Item Adder have empty/missing stats because we manually copy template fields instead of using the game's proper generation methods.

### Current Approach (broken stats)
```
1. Read template from database
2. il2cpp_object_new(ItemData) → allocate blank item
3. Copy fields one by one (itemID, name, value, weight...)
4. Copy medFoodData/horseData pointer (SHARED with template — not a fresh copy)
5. GetItem → add to inventory
```

### Correct Approach (proper stats)
```
1. Call GenerateMedData/GenerateFoodData/GenerateHorseData/GenerateMaterial
   → game creates item with full randomized stats
2. GetItem → add to inventory
```

## Items That Need Fixing

| Item Type | Current Method | Should Use | RVAs |
|-----------|---------------|------------|------|
| Material | Manual copy + SetMaterialData | GenerateMaterial | 0x52E770, 0x52E830, 0x52E430 |
| Medicine | Manual copy + shared medFoodData | GenerateMedData | 0x52EA60, 0x52E850 |
| Food | Manual copy + shared medFoodData | GenerateFoodData | 0x527CB0, 0x5277A0, 0x527A50 |
| Horse | Manual copy + cloned HorseData | GenerateHorseData | 0x52E090, 0x52DA30, 0x52DE10 |
| Horse Armor | Not implemented | GenerateHorseArmorData | 0x52D840 |

**Equipment already works** — uses Generate* via cmd=4 (GenerateWeapon, GenerateArmor, etc.)

## Method Parameters (need to verify)

All Generate methods are on GameController. Need to check exact parameters:
- `GenerateMedData(3 params)` — likely (gc, dbIndex, qualityLevel) or similar
- `GenerateFoodData(4 params)` — likely (gc, dbIndex, qualityLevel, ?)
- `GenerateFoodDataByLv` — generates by level
- `GenerateHorseData(3 params)` — likely (gc, dbIndex, qualityLevel)
- `GenerateMaterial(3 overloads)` — need to check each

## Implementation Plan

### Step 1: Resolve Parameters
For each Generate method, use `il2cpp_method_get_param_name` to get parameter names.

### Step 2: Use cmd=4 Pattern
Same as equipment generation — cmd=4 already handles:
```
rcx = GC (from [rbx+20])
edx = param1 ([rbx+10])
r8d = param2 ([rbx+14])
xmm2/xmm3 = float param ([rbx+18])
call [rbx+68]
result → [rbx+08]
```

Write the Generate* RVA to [rbx+68], set params, trigger cmd=4.

### Step 3: Replace addMedFood/addHorse
Replace the manual copy functions with Generate* calls.
Keep the same UI (dropdowns), just change the backend.

### Step 4: Add Quality/Level Controls
Since Generate* methods likely take a quality/level parameter, add a quality dropdown to medicine/food/horse sections (same as equipment's Lv/Rare dropdowns).

## What Won't Change
- Book/skill items — uses SetBookData, works fine
- Equipment — already uses Generate*, works fine
- The UI dropdowns for selecting which item — stays the same

## References
- Equipment generation: `addEquipGenerated()` function in CT (uses cmd=4)
- Horse rarity: already has quality dropdown (0-5)
- Medicine/Food databases: GDC+0x110 (med), GDC+0x118 (food)
- Horse database: GDC+0x120
