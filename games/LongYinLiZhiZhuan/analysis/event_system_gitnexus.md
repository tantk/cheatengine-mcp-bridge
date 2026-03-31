# Event System Analysis — GitNexus Call Graph (March 31 2026)

## Key Classes & Methods Found

### EventData
| Method | RVA (from FUN_) | Notes |
|--------|-----------------|-------|
| `EventData___ctor` | 0x93B0A0 | Constructor — reveals field offsets |
| `EventData__Clone` | 0x93A310 | Deep clone via serialize/deserialize |
| `EventData__Name` | - | Get event name |
| `EventData__GetDescribe` | - | Get event description |
| `EventData__GetEventRareLv` | - | Get rarity level |
| `EventData__GetPosText` | - | Get position text |

### EventData Field Offsets (from constructor)
```
+0x34: int = -1 (speTargetID or similar, init to 0xFFFFFFFF)
+0x38: List<string> (initialized with empty list)
+0x40: List<string> (initialized with empty list)
+0x48: object (initialized via FUN_18020fb70)
+0x50: long = -1 (0xFFFFFFFFFFFFFFFF)
+0x68: float = 1.0 (0x3f800000) — likely difficultyRate
+0x6C: int = -1 — likely speTargetID
```
Note: these are DIFFERENT from the offsets in session_findings which start at +0x58. The constructor offsets may not include the IL2CPP object header (0x10 bytes). Need to verify at runtime.

### GameController Event Methods
| Method | Calls | Called By |
|--------|-------|----------|
| `GenerateRandomEvent` | CreateAreaMapRandomEvent, GetTimeRandomDifficulty, GlobalData.RandomRange | None (timer/callback) |
| `CreateAreaMapRandomEvent` (2 overloads) | Spine ctor | GenerateRandomEvent |
| `CreateBigMapRandomEvent` (4 overloads) | Various | None in graph (our cheat calls it) |
| `RemoveBigMapRandomEvent` (2 overloads) | - | - |
| `RemoveAreaMapRandomEvent` | - | - |

### Key Finding: GenerateRandomEvent creates AREA events, not BigMap events
This means 武学奇才 might be an area event (discovered while exploring an area) rather than a big map event (visible on world map). Need to verify.

### PlotController Event Methods
| Method | Notes |
|--------|-------|
| `StartRandomEventPlot` | Dispatches event plots by matching string in template list |
| `FindNearRandomEvent` | Finds events near player |
| `AskNearRandomEvent` | NPC tells player about nearby events |
| `HearNearRandomEventPlot` | Hear about event from NPC |
| `StartAskNearRandomEvent` | Start asking about events |

### FindSpeFollower Chain (武学奇才 event)
All on PlotController, all invoked via string callback (no direct callers in graph):
1. `FindSpeFollower` → calls RandomRange (difficulty), Spine ctor
2. `FindSpeFollowerFightResult` → after combat
3. `FindSpeFollowerRecruitChoosen` → player chooses to recruit
4. `FindSpeFollowerSkillChoosen` → adds ~22 extra skills
5. `FindSpeFollowerItemChoosen` → adds extra items
6. `FindSpeFollowerFinish` → completes recruitment

### Clone Methods Available
| Method | RVA | Notes |
|--------|-----|-------|
| `EventData__Clone` | 0x93A310 | Deep clone (serialize+deserialize) |
| `WorldEventDataBase__Clone` | 0xB91980 | Same pattern as EventData.Clone |
| `PlotData__Clone` | - | Clone plot data |
| `SinglePlotData__Clone` | - | Clone individual plot steps |

### RandomEventController
Only 2 methods found:
- `Awake` — initialization
- `get_Instance` — singleton accessor

This is minimal — the actual event logic lives in GameController, not RandomEventController.

### BigMapController Event Methods
| Method | Notes |
|--------|-------|
| `CreateBigMapRandomEvent` (2 overloads) | Creates event icon on big map |
| `CreateBigMapRandomEventIcon` | Creates the map icon |
| `RecreatAllBigMapRandomEvent` | Recreates all event icons (useful after loading) |

### AreaMapRandomEventController
| Method | Notes |
|--------|-------|
| `OnClick` | Player clicks area event |
| `OnHover` | Mouse hover |
| `RefreshColor` | Update event marker color |
| `Update` | Per-frame update |

## Implementation Plan (Updated)

### Approach: Clone Template + Register

1. **Find template at runtime** (CE MCP):
   - Get `RandomEventController._instance` singleton
   - Read `randomEventDataBase` list (+0x18)
   - Iterate 83 entries, read `eventName` (+0x10) to find 武学奇才
   - Or check `plotData` callback strings

2. **Clone template**:
   - Call `EventData__Clone(template)` on main thread → returns fresh copy
   - OR call `WorldEventDataBase__Clone` if needed

3. **Set parameters**:
   - difficulty (+0x64), leftTime (+0x60)
   - seen=1 (+0x58), noticed=1 (+0x5A)
   - Player's areaID for placement

4. **Register event**:
   - Try `GameController__CreateAreaMapRandomEvent` first (since GenerateRandomEvent uses this)
   - If that doesn't work, try `GameController__CreateBigMapRandomEvent`
   - May need to also call `BigMapController__CreateBigMapRandomEventIcon` for map display

## RESOLVED: 武学奇才 Template Location
**WorldEventDataBase index 19** — found in `C:/dev/gameanalysis/runtime_dumps/WorldEventDataBase.json`
- repeatType: 1 (repeatable), repeatDay: 0, lastTime: 20
- startCallPlot: "" (empty — FindSpeFollower callback is inside plotData, not in template)
- forceDifficulty: -1 (any)

## Function Name Resolver
`tools/resolve_funcs.py` — resolves FUN_ addresses to C# names using `name_index.json` (60,107 mappings)
`tools/resolve_decomps.py` — batch-resolves all 74K decompiled .c files

### Resolved Decomps (DONE 2026-03-31)
- Source: `C:/dev/gameanalysis/game_b_decomps/decomps/` (74,455 raw Ghidra files)
- Resolved: `C:/dev/gameanalysis/game_b_decomps/decomps_resolved/` (68,731 files with C# names)
- 60,020 functions mapped via `name_index.json`, only 86 IL2CPP runtime helpers remain unresolved
- Top unresolved: `FUN_1800d6520` (exception throw), `FUN_180002f80` (List.get_Item), `FUN_180480570` (singleton accessor)

### Next Steps
1. Manually identify the 86 unresolved IL2CPP helpers (analysis, not CPU work)
2. Re-index `decomps_resolved/` with GitNexus (CPU heavy — consider Colab/Kaggle)
3. Download `.gitnexus/lbug` output and use locally for queries
4. Continue event system investigation with CE MCP

## SOLVED: Exact Event Generation Recipe (from decompiled GenerateRandomEvent)

The game does exactly this in `GenerateRandomEvent` (line 265-290):
```
1. template = database[randomIndex]           // pick template from RandomEventController database
2. clone = EventData.Clone(template)          // deep clone (RVA 0x93A310)
3. clone.leftTime = RandomRange(5, 11)        // offset +0x60, random 5-11 days
4. difficulty = GetTimeRandomDifficulty()     // based on game time
5. clone.difficulty = difficulty * clone.difficultyRate  // offset +0x64
6. CreateAreaMapRandomEvent(gc, clone, areaID) // place on area map (RVA 0x78E870)
```

### Implementation for CT (3 steps):
1. **Clone**: cmd call `EventData.Clone(WorldEventDataBase[19])` → returns fresh EventData
2. **Write fields**: `leftTime=30.0` at +0x60, `difficulty=customFloat` at +0x64, `seen=1` at +0x58
3. **Register**: cmd call `CreateAreaMapRandomEvent(gc, clone, playerAreaID)`

### Key Addresses
| What | RVA | Notes |
|------|-----|-------|
| EventData.Clone | 0x93A310 | 1 param (template ptr), returns clone |
| CreateAreaMapRandomEvent | 0x78E870 | 3 params (gc, eventData, areaID as int) |
| GetTimeRandomDifficulty | 0x7AE660 | Optional — or just set difficulty directly |

### CE Session Findings (2026-03-31)

**Database access pattern (SOLVED):**
- `WorldEventController` class → `readQword(readQword(class+0xB8))` → `+0x18` = WorldEventDataBase list (25 entries)
- `RandomEventController` class → same pattern → `+0x18` = EventData list (83 entries, small encounters only)
- WorldEventDataBase entries are type `WorldEventDataBase`, NOT `EventData`
- EventData entries are type `EventData`

**Three CreateWorldEvent overloads:**
| RVA | Params | Notes |
|-----|--------|-------|
| 0xB90370 | (WEC, WorldEventDataBase) | 2-param, handles area selection + calls 6-param |
| 0xB90BE0 | (WEC, EventData, area, leftTime, difficulty, param6) | 6-param, calls EventData.Clone internally |
| (third overload exists too) | | |

**Current crash:** Calling 2-param CreateWorldEvent(0xB90370) crashes the game
- NOT a Clone issue — the crash happens in area selection before reaching Clone
- The function reads world data via FUN_180480570(0) which returns a singleton
- If that singleton or its sub-fields are null, it hits FUN_1800d6520 (exception/abort)
- 武学奇才 has repeatType=1 (field at +0x48 in WorldEventDataBase) which triggers "all faction areas" path
- This path iterates through world areas and may fail if world data isn't ready

**Next steps:**
1. Debug which null pointer causes the crash — add logging before the call
2. Try calling with repeatType=0 event first (simpler "random area" path)
3. Or try the 6-param overload directly with a manually created EventData clone
4. Or hook FUN_180480570 to understand what singleton it returns
