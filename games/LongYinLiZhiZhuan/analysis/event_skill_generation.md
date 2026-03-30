# Event Skill Generation — 武学奇才 Hero Skills

## Key Finding

The 40 skills on event-recruited heroes do NOT come from GenerateHeroData. They come from the **interactive event stages** that run after the hero is created.

## GenerateHeroData Output
- ~18 base kungfu skills regardless of difficulty parameter
- ~27 items
- ~11k power score
- Difficulty parameter affects base attribute stats but NOT skill count/tier

## Event Flow (FindSpeFollower chain)

The full 武学奇才 event runs these stages:

| Stage | Method | RVA | What it does |
|-------|--------|-----|-------------|
| 1 | FindSpeFollower | 0x27DB60 | Generates base hero via GenerateHeroData, adds to plot hero list |
| 2 | FindSpeFollowerFightResult | 0x27C4B0 | After player fights the hero |
| 3 | FindSpeFollowerRecruitChoosen | 0x27D680 | Player chooses to recruit |
| 4 | **FindSpeFollowerSkillChoosen** | 0x27D880 | **Adds ~22 extra skills** |
| 5 | **FindSpeFollowerItemChoosen** | 0x27D3A0 | **Adds extra items** |
| 6 | FindSpeFollowerFinish | 0x27C920 | Completes recruitment |

All methods are on `PlotController` class.

## What FindSpeFollower Actually Calls After GenerateHeroData

Traced step by step from the disassembly:
```
+0x1ED: GenerateHeroData (6-param with xmm3 difficulty) → creates base hero
+0x208: List.Add → adds hero to plot's hero list
+0x232: il2cpp internal
+0x258: il2cpp internal
+0x26A: unknown method (RVA 0x75C8A0)
+0x292: HeroData.ChangeExternalInjury → sets injury (hero was in combat)
```

NO call to RandomGenerateNPCSkill, RandomGenerateNPCItem, or any skill method. The base 18 skills come from inside GenerateHeroData itself.

## How to Get 40 Skills Without the Event

### Approach: Call Event Stages Directly

PlotController stores the hero context in:
- `sourceInteractHero` (+0x68) — the player
- `targetInteractHero` (+0x70) — the event hero
- `plotInteractHeroList` (+0x78) — list of involved heroes

Proposed flow:
1. Generate hero via `GenerateHeroData` (9-param, with gender)
2. Get `PlotController._instance`
3. Write hero pointer to `PlotController.targetInteractHero` (+0x70)
4. Write player pointer to `PlotController.sourceInteractHero` (+0x68)
5. Call `FindSpeFollowerSkillChoosen()` on main thread → adds ~22 skills
6. Call `FindSpeFollowerItemChoosen()` on main thread → adds extra items
7. Call `ManagePlayerRecruitHero(hero, true)` → recruit to faction

### Risks
- These methods may trigger UI popups (plot dialogs, choice screens)
- They may read additional plot state that isn't set up (nowEvent, nowPlot, etc.)
- They may crash if PlotController isn't in the right state
- They may need the event to be "active" in PlotController.eventQueue

### Investigation Needed
1. Disassemble `FindSpeFollowerSkillChoosen` to see exactly what it reads/writes
2. Check if it reads from `nowEvent`, `nowPlot`, or other plot state fields
3. Check if it triggers UI (ShowPlot, AddPlotRecordText, etc.)
4. Determine minimum PlotController state needed for the call to succeed

### Alternative: Spawn the Actual Event
Instead of faking the event stages, properly spawn the 武学奇才 event on the world map so the player can interact with it normally. This gives the full experience including the interactive skill/item choices.

This requires finding the correct event template in `WorldPlotEventDataBase` (257 entries) and calling `WorldPlotEventController.StartNewWorldPlotEventFromDataBase(index)`.

## Key RVAs (all on PlotController unless noted)

| Method | RVA | Params |
|--------|-----|--------|
| FindSpeFollower | 0x27DB60 | (none) |
| FindSpeFollowerFightResult | 0x27C4B0 | (none) |
| FindSpeFollowerRecruitChoosen | 0x27D680 | (none) |
| FindSpeFollowerSkillChoosen | 0x27D880 | (none) |
| FindSpeFollowerItemChoosen | 0x27D3A0 | (none) |
| FindSpeFollowerFinish | 0x27C920 | (none) |
| GenerateHeroData (6-param) | 0x52B8D0 | heroID, belongForceID, heroForceLv, heroDataBase, isTempHero, isRandomEnemy + xmm3=difficulty |
| GenerateHeroData (9-param) | 0x52A100 | heroName, heroID, belongForceID, heroForceLv, heroDataBase, isTempHero, sexLimit, isRandomEnemy, outSideForce |
| ManagePlayerRecruitHero | 0x5533C0 | targetHero, isNewHero |
| WorldPlotEventController.StartNewWorldPlotEventFromDataBase | 0x941960 | index (int) |

## PlotController Fields

| Offset | Field | Used by event stages |
|--------|-------|---------------------|
| +0x68 | sourceInteractHero | Player hero |
| +0x70 | targetInteractHero | Event hero (the recruit target) |
| +0x78 | plotInteractHeroList | List of heroes in the plot |
| +0x98 | nowEvent | Current active event |
| +0xA0 | nowPlot | Current active plot |
| +0xA8 | nowSinglePlot | Current plot step |
