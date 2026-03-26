# IL2CPP Snapshot — LongYinLiZhiZhuan v1.0.0 f7.8 (2026-03-26)

> GameAssembly.dll base varies (ASLR). All method addresses shown as RVA (add to base for absolute address).
> Field offsets are stable within the same game version.
> Static field data pointer: klass + 0xB8

---

## GameController

### Static Fields

| Name | Offset | Notes |
|------|--------|-------|
| _instance | 0x0 | GameController singleton |
| difficultyExtraPoint | 0x8 | |
| CheckShowSpeHero | 0x10 | |

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| TestBuildPlayer | 0x18 | |
| worldData | 0x20 | ptr to WorldData |
| needAutoSave | 0x28 | |
| checkUpdateTime | 0x2C | |
| enterAreaHateAttackHero | 0x30 | |
| enterAreaBountyAttackHero | 0x38 | |
| enterAreaEnemyForceAttackHero | 0x40 | |
| enterAreaChallengeHero | 0x48 | |
| enterAreaHateSpeAttackHero | 0x50 | |

### Methods

| Name | Params | RVA |
|------|--------|-----|
| get_Instance | 0 | 0x7D5C80 |
| Update | 0 | 0x7D3620 |
| GenerateWeapon | 5 | 0x7A7C70 |
| GenerateWeapon | 4 | 0x7A73C0 |
| GenerateArmor | 4 | 0x795B70 |
| GenerateHelmet | 4 | 0x79A490 |
| GenerateShoes | 4 | 0x7A5480 |
| GenerateDecoration | 4 | 0x797A70 |
| GenerateTreasure | 2 | 0x7A7250 |
| GenerateTreasure | 3 | 0x7A7310 |
| GenerateMedData | 3 | 0x79F670 |
| GenerateFoodData | 4 | 0x7988C0 |
| GenerateHorseData | 3 | 0x79ECA0 |
| GenerateMaterial | 3 | 0x79F040 |
| GenerateBook | 4 | 0x796850 |
| GenerateHero | 0 | 0x79C590 |
| GenerateRandomItem | 6 | 0x7A3910 |

---

## GameDataController

### Static Fields

| Name | Offset | Notes |
|------|--------|-------|
| _instance | 0x20 | GameDataController singleton |

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| gameSaveData | 0x30 | |
| weaponDataBase | 0xF0 | List of weapon templates |
| armorDataBase | 0xF8 | List of armor templates |
| helmetDataBase | 0x100 | List of helmet templates |
| shoesDataBase | 0x108 | List of shoes templates |
| medDataBase | 0x110 | List of medicine templates |
| foodDataBase | 0x118 | List of food templates |
| horseDataBase | 0x120 | List of horse templates |
| kungfuSkillDataBase | 0x128 | List of skill book data |
| heroTagDataBase | 0x198 | List of talent/tag data |
| skinDataBase | 0x1A8 | |
| AchievementData | 0x1C0 | |

---

## HeroData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| isSummon | 0x10 | bool |
| summonID | 0x14 | int |
| heroID | 0x58 | int, 0 = player |
| speHero | 0x5C | int |
| dead | 0x61 | bool |
| heroName | 0x68 | Il2CppString* |
| heroFamilyName | 0x70 | Il2CppString* |
| isFemale | 0x80 | bool |
| belongForceID | 0x84 | int |
| skillForceID | 0x88 | int |
| forceJobType | 0x90 | int |
| heroForceLv | 0xB8 | int |
| heroStrengthLv | 0xBC | int |
| atAreaID | 0xC0 | int |
| age | 0xD4 | int |
| favor | 0x124 | float |
| baseAttri | 0x128 | List\<float\> |
| maxAttri | 0x130 | List\<float\> |
| totalAttri | 0x138 | List\<float\> |
| baseFightSkill | 0x140 | List |
| maxFightSkill | 0x148 | List |
| totalFightSkill | 0x150 | List |
| baseLivingSkill | 0x158 | List |
| maxLivingSkill | 0x160 | List |
| totalLivingSkill | 0x168 | List |
| hp | 0x178 | float |
| maxhp | 0x17C | float |
| power | 0x184 | float |
| maxPower | 0x188 | float |
| mana | 0x190 | float |
| maxMana | 0x194 | float |
| externalInjury | 0x1A0 | float |
| internalInjury | 0x1A4 | float |
| poisonInjury | 0x1A8 | float |
| governContribution | 0x1B4 | float |
| forceContribution | 0x1C0 | float |
| fame | 0x1C4 | float |
| badFame | 0x1C8 | float |
| loyal | 0x1CC | float |
| horseSaveRecord | 0x200 | |
| horse | 0x208 | ItemData* with horseData |
| horseArmor | 0x218 | |
| itemListData | 0x220 | ItemListData* |
| kungfuSkills | 0x260 | List\<KungfuSkillLvData\> |
| heroTagPoint | 0x35C | float |
| heroTagData | 0x360 | List |
| fightScore | 0x384 | float |

### Methods

| Name | Params | RVA |
|------|--------|-----|
| GetMaxTagNum | 0 | 0x895530 |
| GetItem | 5 | 0x894530 |
| Clone | 0 | 0x88BDB0 |

---

## ItemData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| itemID | 0x10 | int |
| type | 0x14 | int (0=equip, 1=med, 2=food, 3=book, 4=material, 5=treasure, 6=horse) |
| subType | 0x18 | int |
| name | 0x20 | Il2CppString* |
| describe | 0x30 | Il2CppString* |
| value | 0x38 | int |
| itemLv | 0x3C | int |
| rareLv | 0x40 | int |
| weight | 0x44 | float |
| equipmentData | 0x60 | ptr, for weapons/armor/helmet/shoes/decoration |
| medFoodData | 0x68 | ptr |
| bookData | 0x70 | ptr |
| treasureData | 0x78 | ptr |
| materialData | 0x80 | ptr |
| horseData | 0x88 | HorseData* |

### Methods

| Name | Params | RVA |
|------|--------|-----|
| .ctor | 1 | 0xC628D0 |
| SetBookData | 2 | 0xC61C70 |
| SetMaterialData | 3 | 0xC61D80 |
| SetTreasureData | 3 | 0xC61EA0 |
| Clone | 0 | 0xC5F2F0 |
| CountValueAndWeight | 0 | 0xC5F470 |

---

## ItemListData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| heroID | 0x10 | int |
| forceID | 0x14 | int |
| money | 0x18 | int |
| weight | 0x1C | float |
| maxWeight | 0x20 | float |
| allItem | 0x28 | List\<ItemData\> |

---

## ForceData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| forceID | 0x10 | int |
| forceName | 0x18 | Il2CppString* |
| bigForce | 0x24 | bool |
| forceLv | 0x34 | int |
| mainAreaID | 0x38 | int |
| leader | 0x58 | int, heroID |
| ownHeros | 0x70 | List |
| resourceStore | 0x88 | List\<float\> |
| forceStorage | 0xA0 | ItemListData* |
| forceFavor | 0xD0 | List\<float\>, indexed by forceID (50=neutral, 100=max) |
| allyForce | 0xD8 | List\<int\> |
| nowResearchTech | 0x128 | int, -1 = none |
| techLvData | 0x130 | List\<ForceTechLvData\> |
| playerOutForceContribution | 0x170 | float |

### Methods

| Name | Params | RVA |
|------|--------|-----|
| SetForceFavor | 2 | 0xBABC70 |
| GetForceFavor | 1 | 0xBA9DB0 |
| SetNowResearch | 2 | 0xBACD00 |
| UpgradeNowResearch | 1 | 0xBAD040 |

---

## WorldData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| Areas | 0x30 | List\<AreaData\> |
| ResourcePoints | 0x40 | |
| Forces | 0x48 | List\<ForceData\> |
| Heros | 0x50 | List\<HeroData\> |
| TempHeros | 0x58 | |
| gameMode | 0x9C | int |
| gameDifficulty | 0xA0 | int |
| worldTime | 0xA8 | |
| hour | 0xB4 | int |
| weaponResearchData | 0x1E0 | |
| forceSpeResearchData | 0x1F0 | |
| autoResearch | 0x238 | |

---

## AreaData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| areaID | 0x10 | int |
| areaName | 0x18 | Il2CppString* |
| belongForceID | 0x70 | int |
| areaTiles | 0xC0 | List\<AreaTileData\> |
| areaBranchDefenceUpgradeLeftTime | 0xD8 | int, days remaining |

---

## AreaTileData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| building | 0x28 | AreaBuildingData* |
| tileType | 0x30 | int |
| areaID | 0x40 | int |

---

## AreaBuildingData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| buildingID | 0x10 | int |
| lv | 0x14 | int |
| buildTimeLeft | 0x18 | int, days remaining |
| upgradeTimeLeft | 0x1C | int, days remaining |
| destroyTimeLeft | 0x20 | int, days remaining |

---

## HorseData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| equiped | 0x10 | int (0/1) |
| speed | 0x14 | float |
| power | 0x18 | float |
| sprint | 0x1C | float |
| resist | 0x20 | float |
| speedAdd | 0x24 | float |
| powerAdd | 0x28 | float |
| sprintAdd | 0x2C | float |
| resistAdd | 0x30 | float |
| maxWeightAdd | 0x34 | float |
| nowPower | 0x38 | float |
| favorRate | 0x3C | float (0.0-1.0, tame level) |
| sprintTimeLeft | 0x40 | float |
| sprintTimeCd | 0x44 | float |

---

## KungfuSkillLvData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| skillID | 0x10 | int |
| lv | 0x14 | int |
| fightExp | 0x18 | float |
| bookExp | 0x1C | float |
| equiped | 0x20 | bool |
| belongHeroID | 0x24 | int |
| power | 0x64 | float |

---

## ForceTechLvData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| techID | 0x10 | int |
| lv | 0x14 | int |
| researchPercent | 0x18 | float (0.0-1.0) |

---

## BattleController

### Static Fields

| Name | Offset | Notes |
|------|--------|-------|
| _instance | 0x50 | BattleController singleton |

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| teams | 0x70 | List |
| playerBattleUnit | 0x1A8 | |

---

## ForceSpeResearchData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| researchRate | 0x10 | |
| material | 0x18 | |
| addDamageRate | 0x20 | |
| researchBuff | 0x28 | |
| leftTime | 0x30 | |

---

## WeaponResearchData

### Instance Fields

| Name | Offset | Notes |
|------|--------|-------|
| lv | 0x10 | int |
| exp | 0x14 | int |
| researchTarget | 0x18 | |
| leftTime | 0x28 | |

---

## GlobalData

### Static Fields

| Name | Offset | Notes |
|------|--------|-------|
| MaxSkillNum | 0x130 | List\<float\>, skill tier limits |
| MaxAttackSkillNum | 0x84 | int |
| MaxHeroNum | 0x94 | int |

---

## Pointer Chain: GameController._instance to Player Hero

```
1. GameController klass + 0xB8          -> static field data
2. static + 0x0                         -> _instance (GameController)
3. instance + 0x20                      -> WorldData
4. WorldData + 0x48                     -> Forces (List<ForceData>)
5. WorldData + 0x50                     -> Heros (List<HeroData>)
6. Heros + 0x10                         -> _items array
7. _items + 0x20                        -> hero[0] (player)
```

---

## Key Database Offsets on GameDataController (instance)

| Database | Offset | Description |
|----------|--------|-------------|
| weaponDataBase | 0xF0 | Weapon templates |
| armorDataBase | 0xF8 | Armor templates |
| helmetDataBase | 0x100 | Helmet templates |
| shoesDataBase | 0x108 | Shoes templates |
| medDataBase | 0x110 | Medicine templates |
| foodDataBase | 0x118 | Food templates |
| horseDataBase | 0x120 | Horse templates |
| kungfuSkillDataBase | 0x128 | Skill book data |
| heroTagDataBase | 0x198 | Talent/tag data |

---

## IL2CPP Export Functions Used

All from GameAssembly.dll exports:

| Function |
|----------|
| il2cpp_domain_get |
| il2cpp_domain_get_assemblies |
| il2cpp_assembly_get_image |
| il2cpp_image_get_name |
| il2cpp_class_from_name |
| il2cpp_class_get_field_from_name |
| il2cpp_field_get_offset |
| il2cpp_class_get_fields |
| il2cpp_field_get_name |
| il2cpp_class_get_methods |
| il2cpp_method_get_name |
| il2cpp_method_get_param_count |
| il2cpp_class_get_method_from_name |
| il2cpp_object_new |
| il2cpp_string_new |
| il2cpp_runtime_invoke |

> **Note:** `LaunchMonoDataCollector()` is BROKEN for this game version.
> Use `executeCodeEx()` with il2cpp exports instead of `shellExec` / `createRemoteThread`.
