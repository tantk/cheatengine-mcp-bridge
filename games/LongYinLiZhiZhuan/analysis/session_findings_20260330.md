# Session Findings — March 29-30, 2026

## 1. Release Pipeline (4 Platforms)

### Skills Created
- **fearless-updater** — Browser automation: upload CT to FearlessRevolution forum via Plupload
- **baidu-uploader** — Browser automation: upload CT to Baidu Wangpan, save share link + 提取码 to `tools/baidu/shares.json`
- **bilibili-updater** — Browser automation: update video description with new Baidu link
- **youtube-updater** — YouTube Data API v3: update description via Python script (no browser)
- **release** — Orchestrates all 4 in sequence

### Key Techniques
- **FearlessRevolution**: phpBB Plupload API (`phpbb.plupload.uploader.addFile()`) — DataTransfer alone doesn't work
- **Baidu Wangpan**: localhost file server + file input DataTransfer works for Baidu (unlike phpBB)
- **Bilibili**: contenteditable div, replace innerText, dispatch input event
- **YouTube**: OAuth2 Desktop app, `youtube.videos().update()` API
- **File serving**: localhost HTTP server on port 18999, Chrome "Private Network Access" prompt (user clicks Allow once)
- **Baidu share link extraction**: zoom into tooltip at ~(460,440)-(650,590) — clipboard.readText() freezes page

### OAuth Setup (YouTube)
- Google Cloud project: polygon-analysis
- YouTube Data API v3 enabled
- OAuth consent screen: "YouTube Updater", External, test user tantk7@gmail.com
- Desktop app credentials at `tools/youtube/client_secret.json`
- Token cached at `tools/youtube/token.json`

---

## 2. Early f7 Compatibility

### Problem
Users on early f7 (pre-f7.6) reported horses/medicine/food generated with 0 stats.

### Root Cause
ItemData field offsets shifted by -8 bytes between early f7 and f7.6+:
- `medFoodData`: 0x60 (early f7) → 0x68 (f7.6+/f8)
- `horseData`: 0x80 (early f7) → 0x88 (f7.6+/f8)
- Basic fields (itemID, name, value, weight at 0x10-0x44) unchanged

### Fix
Auto-detection in `discover()`: check first horse template in horseDataBase — if `template+0x88` is null but `template+0x80` has data, use early f7 offsets.

### Steam Depot Downgrade
```
download_depot 3202030 3202031 <MANIFEST_ID>
```
March 24 manifest (f7.6): `6680997563017042212`
March 16 manifest (early f7): `2493790209650016491`

---

## 3. Character Creation Cheats

### Talent Slot Limit (5 → user-defined)
**Controller**: `StartMenuController` (NOT any "Create" or "Tag" named class)

**Found by**: iterating ALL classes via `il2cpp_image_get_class`, checking for active singleton instances with tag-related fields.

**Two patch locations** (both required):
1. `StartChooseTagClicked`: `cmp [rax+18], 05` — blocks adding when count >= 5
2. `RefreshTagMenu`: `cmp eax, 05` — disables talent buttons when count >= 5

Both are single-byte patches (change `05` to desired max). Found via byte scanning within the resolved method addresses.

**Key lesson**: `GetMaxTagNum` and `GetHeroPermanentTagNum` do NOT control creation screen slots. The creation UI uses `StartMenuController` methods, not `HeroData` methods.

### Talent Points
Write to `Player.heroTagPoint` (+0x35C) on `StartGameSettingController.Player`.

### Distribute Points (Attribute/Fight/Living)
Write to `StartMenuController` fields:
- `leftAttriPoint` (+0x80) — attribute points to distribute
- `leftFightSkillPoint` (+0x84) — fight skill points
- `leftLivingSkillPoint` (+0x88) — living skill points

### Character Creation Objects
- `StartMenuController._instance` — active during creation screen
- `StartGameSettingController._instance` — holds Player (HeroData) and BirthSetting
- `StartGameSettingController.Player` (+0x18) — the hero being created
- These are NULL outside the creation screen

### What Doesn't Work During Creation
- `_il2cpp_init()` — needs GameController which doesn't exist
- `GetMaxTagNum` patch — creation UI doesn't call it
- Hardware breakpoints — crash Unity games
- Writing to talent count display addresses — crashes game

---

## 4. Hero Generator

### Final Working Flow
```
GenerateHeroData(9-param) → ManagePlayerRecruitHero
```

**GenerateHeroData** (RVA 0x52A100, 9 parameters):
```
heroName=null, heroID=-1, belongForceID, heroForceLv,
heroDataBase=null, isTempHero=false, sexLimit(0/1/2),
isRandomEnemy=false, outSideForce=false
```

**ManagePlayerRecruitHero** (RVA 0x5533C0):
```
targetHero (HeroData*), isNewHero (bool=true)
```

This does full initialization: portrait, AI, area placement, faction assignment, master set to leader.

### SexLimit Enum
- 0 = None (random gender)
- 1 = Male
- 2 = Female

### What Didn't Work
- `GenerateHeroData` alone → hero has no portrait, can't be clicked
- `GenerateHeroData` + manual `List.Add` to `ForceData.ownHeros` → corrupts list
- `GenerateHeroData` + `WorldData.AddNewHero` + `HeroData.JoinForce` → missing 3 unknown init calls, hero not interactable
- `executeCodeEx` for game methods → crashes (needs main thread)

### WorldAddNewHero Internal Flow
```
GameController.WorldAddNewHero(forceID, heroForceLv, outSideForce):
  +0xB8: WorldData.AddNewHero(heroData)     — registers in world
  +0xEA: HeroData.JoinForce(...)            — assigns faction
  +0x110: unknown (critical init!)
  +0x12F: unknown
  +0x18C: unknown
```

### ManagePlayerRecruitHero Internal Flow
```
+0x43-0xAE: WorldData.Player() calls (4x)
+0xC4: HeroData method (0x621D60)
+0x11B: WorldData.AddNewHero
+0x140: HeroData.JoinForce
+0x16C: unknown (0x1022B20) — same mystery call as WorldAddNewHero!
+0x1B9: HeroData.JoinForce (2nd call)
+0x1CC: HeroData.ResetLoyal (0x636B40)
+0x1DC-0x202: more setup
```

### Post-Generation Stat Modification
After hero is created, directly write to HeroData fields:
- `boostList()` — adds flat value to all base stats AND raises max caps
- `age` (+0xD4) — override age
- `loyal` (+0x1CC) — set loyalty
- `atAreaID` (+0xC0) — place at player's location

### HeroData.JoinForce Parameters
```
JoinForce(_forceID, _forceLv, _generation, showInfo, setTeacherToLeader)
```
- `setTeacherToLeader=true` only when generating for player's faction

### hookCode Assembly
- cmd=5 uses `sub rsp,78` (more stack than cmd=1-4 which use `sub rsp,58`)
- MUST have separate cleanup paths (`genHeroError` with `add rsp,78`)
- CE assembler evaluates symbols even in comments — no colons/parentheses in `;` comments!

---

## 5. Face/Portrait System

### HeroFaceData
- Located at HeroData+0xE0
- Contains 8 qword sprite pointers at +0x10 through +0x80
- Uses Unity Spine skeleton rendering
- Male and female faces are separate pools

### Face Methods (ALL need main thread)
| Method | RVA | Description |
|--------|-----|-------------|
| `GenerateFaceCode()` | 0x61E1A0 | Export face as string |
| `LoadFaceCode(faceCode)` | 0x62EF90 | Import face from string |
| `RandomFaceData(includeNoRandom)` | 0x633540 | Randomize face |

### Face Databases
- `GDC.MaleFaceRandomID` (+0x168) — 6 male face variants
- `GDC.FemaleFaceRandomID` (+0x170) — 6 female face variants

### Safe Operations
- Copy `faceData` pointer between heroes — pure memory write
- Gender + face are linked — use `sexLimit` in GenerateHeroData for matching pair

---

## 6. World Event System (武学奇才)

### Event Structure
Events stored in `WorldData.WorldEventDatas` (+0x80), a `List<EventData>`.

### EventData Fields
| Offset | Field | Type | Description |
|--------|-------|------|-------------|
| +0x10 | eventName | string | Event name |
| +0x18 | eventDescribe | string | Description |
| +0x58 | seen | bool | Discovered by player |
| +0x59 | happened | bool | Already triggered |
| +0x5A | noticed | bool | Exists in world |
| +0x5E | autoDestroy | bool | Auto-remove |
| +0x60 | leftTime | float | Days remaining |
| +0x64 | difficulty | float | Affects generated hero quality |
| +0x68 | difficultyRate | float | Difficulty multiplier |
| +0x6C | speTargetID | int | Specific hero template (-1=random) |
| +0x70 | plotData | PlotData* | Event flow template |
| +0x90 | seeRange | float | Discovery range |

### 武学奇才 Event Flow
```
Player discovers event on world map (seen=true)
  → Player clicks → StartExplore with callback "0;1.2;FindSpeFollower"
    → PlotController.FindSpeFollower()
      → GetNowEventDifficulty()
      → GenerateHeroData(gc, forceID, heroID, difficulty...)
      → Player fights/interacts
      → FindSpeFollowerRecruitChoosen → recruit choice
      → ManagePlayerRecruitHero → joins faction
      → FindSpeFollowerFinish
```

### Reveal Cheat
Set `seen=1` (+0x58) to discover the event on the map.
Set `leftTime` (+0x60) to extend the timer.
Set `difficulty` (+0x64) to control hero quality.

### Spawning When Event Doesn't Exist
Current approach: call `GenerateRandomEvent()` on main thread repeatedly, check each new event, remove unwanted ones by shrinking list count.

### TODO: Targeted Event Creation
`GenerateRandomEvent()` must reference event templates internally. Need to:
1. Trace the function to find event type selection logic
2. Find the plotData template database
3. Use `il2cpp_object_new(EventDataClass)` + `CreateBigMapRandomEvent` for direct creation

### Related Methods
| Method | RVA | Params |
|--------|-----|--------|
| `GenerateRandomEvent` | 0x5310B0 | (none) |
| `CreateBigMapRandomEvent` | 0x51EDD0 | newRandomEvent, targetResourcePoint |
| `CreateBigMapRandomEvent` | 0x51EFB0 | newRandomEvent, targetAreaID |
| `CreateBigMapRandomEvent` | 0x51EEE0 | newRandomEvent, targetArea, rangeRate |
| `CreateBigMapRandomEvent` | 0x51EC50 | newRandomEvent, targetArea, direction, rangeRate |
| `RemoveEvent` | exists | (params unknown, method iterator didn't find it) |

---

## 7. CE/IL2CPP Technical Notes

### Stale CE State
- `_checkGameAlive()` added to detect stale state
- Calls `reinitializeSymbolhandler()` to auto-fix stale symbols
- CE's `getAddress()` returns stale addresses after game restart
- "Nearby allocation" popup = stale CE trying to allocate near invalid addresses

### Method Resolution
- `il2cpp_class_get_method_from_name` fails for some classes (returns 0)
- Fallback: use `il2cpp_class_get_methods` iterator + `il2cpp_method_get_name`
- Character creation cheats must scan all assemblies (not just Assembly-CSharp) since `_il2cpp_init` needs GameController

### Assembly Comments
- CE auto-assembler evaluates expressions even inside `;` comments
- No colons, parentheses, or symbol names in comments
- Symbols like `cmdBuf+0x88` in comments get evaluated

### hookCode Stack Management
- cmd=1-4 use `sub rsp,58` / `add rsp,58`
- cmd=5 uses `sub rsp,78` / `add rsp,78`
- Each command MUST have matching stack cleanup on all paths (success + error)
- Mismatched stack = hook stops running entirely

### ComboBox Dropdown
- CE ComboBox default style is editable (no dropdown arrow)
- `Style = 2` or `Style = "csDropDownList"` for proper dropdown — BUT causes AA failure in some versions
- Workaround: leave as default style, items still selectable
