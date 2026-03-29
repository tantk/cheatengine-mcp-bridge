# Hero Generation & Appearance System

## Hero Generation Methods

### GameController Methods

| Method | RVA | Parameters | Description |
|--------|-----|-----------|-------------|
| `GenerateHeroData` | 0x52B8D0 | heroID, belongForceID, heroForceLv, heroDataBase, isTempHero, isRandomEnemy | Basic hero generation |
| `GenerateHeroData` | 0x52B930 | heroName, heroID, belongForceID, heroForceLv, isRandomEnemy | Named hero generation |
| `GenerateHeroData` | 0x52A100 | heroName, heroID, belongForceID, heroForceLv, heroDataBase, isTempHero, **sexLimit**, isRandomEnemy, outSideForce | Full control (gender!) |
| `GenerateHero` | 0x52B980 | (none visible) | High-level wrapper |
| `WorldAddNewHero` | 0x564890 | forceID, heroForceLv, outSideForce | Generate + register + assign faction |

### WorldAddNewHero Internal Flow
```
GameController.WorldAddNewHero(forceID, heroForceLv, outSideForce):
  +0xB8: WorldData.AddNewHero(heroData)    ← registers in world hero list
  +0xEA: HeroData.JoinForce(...)           ← assigns to faction, adds to ForceData.ownHeros
  +0x110: (unknown - UI refresh?)
  +0x12F: (unknown)
  +0x18C: (unknown)
```

### Key Insight
- `WorldAddNewHero` calls `WorldData.AddNewHero(target)` which takes a single HeroData param
- `WorldData.AddNewHero` just registers an already-created HeroData in the world
- `HeroData.JoinForce` handles faction assignment
- The hero creation (GenerateHeroData) is called internally before these

### Proper Hero Creation Flow
To create a fully functional hero with customization:
1. Call `GenerateHeroData` (9-param overload at 0x52A100) — control gender, faction, etc.
2. Call `WorldData.AddNewHero(heroData)` (RVA 0x795DE0) — register in world
3. Call `HeroData.JoinForce(...)` (RVA 0x62CFB0) — assign to faction
4. Optionally modify stats, face, etc.

### What Doesn't Work
- `GenerateHeroData` alone → hero exists but has no portrait, can't be clicked
- Manual `List.Add` to ownHeros → corrupts the list, hero is broken
- Calling game methods via `executeCodeEx` (remote thread) → crashes for most methods

## HeroData Fields (Character Stats)

### Identity
| Offset | Field | Type | Description |
|--------|-------|------|-------------|
| +0x58 | heroID | int | Unique hero identifier |
| +0x5C | speHero | byte | Special hero flag (SpeHeroLimit enum) |
| +0x5E | recruitAble | bool | Can be recruited |
| +0x60 | hide | bool | Hidden from world |
| +0x61 | dead | bool | Dead flag |
| +0x68 | heroName | string | Given name |
| +0x70 | heroFamilyName | string | Family name |
| +0x78 | heroNickName | string | Nickname |
| +0x80 | isFemale | bool | Gender (false=male, true=female) |
| +0xD4 | age | int | Current age |
| +0xD8 | generation | int | Generation |

### Faction
| Offset | Field | Type | Description |
|--------|-------|------|-------------|
| +0x84 | belongForceID | int | Faction ID |
| +0x88 | skillForceID | int | Skill school ID |
| +0x8C | outsideForce | bool | External faction flag |
| +0x90 | forceJobType | int | Job type in faction |
| +0xB4 | isLeader | bool | Is faction leader |
| +0xB8 | heroForceLv | int | Rank in faction |
| +0xBC | heroStrengthLv | int | Strength level |
| +0xC0 | atAreaID | int | Current area |
| +0x1CC | loyal | float | Loyalty |

### Attributes (6 values each: List<float>)
| Offset | Field | Description |
|--------|-------|-------------|
| +0x128 | baseAttri | Base attributes [6 floats] |
| +0x130 | maxAttri | Max attribute caps [6 floats] |
| +0x138 | totalAttri | Computed total [6 floats] |

### Fight Skills (9 values each: List<float>)
| Offset | Field | Description |
|--------|-------|-------------|
| +0x140 | baseFightSkill | Base fight skills [9 floats] |
| +0x148 | maxFightSkill | Max fight skill caps [9 floats] |
| +0x150 | totalFightSkill | Computed total [9 floats] |

### Living Skills (9 values each: List<float>)
| Offset | Field | Description |
|--------|-------|-------------|
| +0x158 | baseLivingSkill | Base living skills [9 floats] |
| +0x160 | maxLivingSkill | Max living skill caps [9 floats] |
| +0x168 | totalLivingSkill | Computed total [9 floats] |

### Combat Stats
| Offset | Field | Type |
|--------|-------|------|
| +0x178 | hp | float |
| +0x17C | maxhp | float |
| +0x184 | power | float |
| +0x188 | maxPower | float |
| +0x190 | mana | float |
| +0x194 | maxMana | float |
| +0x1A0 | externalInjury | float |
| +0x1A4 | internalInjury | float |
| +0x1A8 | poisonInjury | float |

### Personality & Alignment
| Offset | Field | Type |
|--------|-------|------|
| +0x1C4 | fame | float |
| +0x1C8 | badFame | float |
| +0x1D0 | evil | float |
| +0x1D4 | chaos | float |
| +0x1D8 | nature | int |
| +0x1DC | talent | int |
| +0x1E0 | hobby | int |

### Talents
| Offset | Field | Type |
|--------|-------|------|
| +0x35C | heroTagPoint | float | Talent points to spend |
| +0x360 | heroTagData | List | Selected talents |
| +0x384 | fightScore | float | Combat power rating |

### Appearance
| Offset | Field | Type | Description |
|--------|-------|------|-------------|
| +0xE0 | faceData | HeroFaceData | Face configuration (8 sprite pointers) |
| +0xE8 | skinColorDark | float | Skin color darkness |
| +0xEC | defaultSkinID | int | Default clothing |
| +0xF0 | skinID | int | Current clothing |
| +0xF4 | skinLv | int | Clothing level |

## Face/Portrait System

### HeroFaceData Object
- Located at HeroData+0xE0
- Contains 8 qword pointers at offsets +0x10 through +0x80 (16 bytes apart)
- Each points to a Spine sprite/attachment for face parts (eyes, hair, mouth, nose, brow, etc.)
- IL2CPP reflection only shows `faceID` at +0x10, but the object has more data

### Face Methods on HeroData (ALL NEED MAIN THREAD)
| Method | RVA | Parameters | Description |
|--------|-----|-----------|-------------|
| `GenerateFaceCode` | 0x61E1A0 | (none) | Export face as portable string code |
| `LoadFaceCode` | 0x62EF90 | faceCode (string) | Import face from string code |
| `RandomFaceData` | 0x633540 | includeNoRandom (bool) | Randomize face |
| `SetSkeletonFaceSlot` | 0x639560 | targetSkeleton, i | Set face slot on skeleton |
| `SetSkeletonGraphicFaceSlot` | 0x639A80 | targetSkeleton, i, targetID | Set face slot with specific ID |

### Face Code System
The game has a built-in face code import/export system:
- `GenerateFaceCode()` → returns a string that encodes the face
- `LoadFaceCode(string)` → applies a face code to the hero
- This enables: copy player's face to generated hero, share faces between heroes

### Face Databases in GameDataController
| Offset | Field | Description |
|--------|-------|-------------|
| +0x158 | MaleFaceTotalNum | Total male face variants |
| +0x160 | FemaleFaceTotalNum | Total female face variants |
| +0x168 | MaleFaceRandomID | List of random male face IDs |
| +0x170 | FemaleFaceRandomID | List of random female face IDs |

### Safe vs Unsafe Face Operations
- **SAFE**: Copy `faceData` pointer (hero+0xE0) between heroes — pure memory write
- **UNSAFE**: Calling any face method from remote thread — crashes game
- **NEEDS MAIN THREAD**: RandomFaceData, GenerateFaceCode, LoadFaceCode

## Character Creation Parameters

### StartMenuController (active during creation)
| Offset | Field | Current | Description |
|--------|-------|---------|-------------|
| +0x80 | leftAttriPoint | 60 | Attribute points to distribute |
| +0x84 | leftFightSkillPoint | 90 | Fight skill points |
| +0x88 | leftLivingSkillPoint | 90 | Living skill points |

### Talent Slot Limit
Found in two methods on StartMenuController:
- `StartChooseTagClicked`: `cmp [rax+18], 5` — blocks adding when count >= 5
- `RefreshTagMenu`: `cmp eax, 5` — disables UI when count >= 5
Both must be patched to increase the limit.

## TODO: Implementation Plan

### Phase 1 (Done)
- [x] WorldAddNewHero via cmd=5 (basic hero generation)
- [x] Faction and rank selection
- [x] Character creation: talent slots, talent points, distribute points

### Phase 2 (Next)
- [ ] Use 9-param GenerateHeroData (0x52A100) for gender control
- [ ] Add cmd=6 for face operations (RandomFaceData, LoadFaceCode)
- [ ] Post-generation stat editing (baseAttri, baseFightSkill, baseLivingSkill)
- [ ] Face code copy from player to generated hero
- [ ] Face code export/import UI in item adder

### Phase 3 (Future)
- [ ] Spawn 武学奇才 event on demand
- [ ] Specific hero template selection from SpeHeroDataBase (170 templates)
- [ ] Full character customization dialog (gender, stats, face code, talents)
