# Special Hero Generation (武学奇才 Event) Investigation

## Event Structure

The 武学奇才 (Martial Arts Prodigy) event is a world map event stored in `WorldData.WorldEventDatas` (offset +0x80).

### EventData Fields
- `eventName` (+0x10): "武学奇才"
- `leftTime` (+0x60): countdown in game days
- `difficulty` (+0x64): affects generated hero quality
- `plotData` (+0x70): PlotData with event flow

### PlotData Flow
The event's PlotData has 1 sub-plot with 2 choices:
- **Choice 0**: `StartExplore` with callback `FindSpeFollower` (explore to find the hero)
  - Parameter: `0;1.2;FindSpeFollower`
- **Choice 1**: `HideInteractUI` (leave/ignore)

## FindSpeFollower Method

Located on **PlotController** at RVA `0x27DB60`.

### Call Chain
1. `GetNowEventDifficulty()` (RVA 0x2B27D0) — gets difficulty from current event
2. `GenerateHeroData()` (RVA 0x52B8D0) — generates the special hero

### GenerateHeroData Parameters (from FindSpeFollower call site)
```
GenerateHeroData(
  rcx = GameController instance,
  edx = forceID (-1 = random, use player's forceID to spawn in player faction),
  r8d = heroID (-1 = random),
  xmm3 = difficulty (float, derived from event difficulty),
  [rsp+20] = 0 (null),
  [rsp+28] = 1 (true, possibly isMale or generateEquip),
  [rsp+30] = 0 (false)
)
Returns: HeroData pointer
```

### Related Methods on PlotController
- `FindSpeFollower(0)` RVA=0x27DB60 — starts encounter
- `FindSpeFollowerFightResult(0)` RVA=0x27C4B0 — after fight
- `FindSpeFollowerRecruitChoosen(0)` RVA=0x27D680 — recruit choice
- `FindSpeFollowerSkillChoosen(0)` RVA=0x27D880 — skill selection
- `FindSpeFollowerItemChoosen(0)` RVA=0x27D3A0 — item choice
- `FindSpeFollowerFinish(0)` RVA=0x27C920 — completes

### Related Methods on GameController
- `GenerateHeroData(0)` RVA=0x52B8D0, 0x52B930, 0x52A100 (3 overloads)
- `GenerateHero(0)` RVA=0x52B980 (creates + adds to world?)
- `WorldAddNewHero(0)` RVA=0x564890
- `ManagePlayerRecruitHero(0)` RVA=0x5533C0

## Special Hero Database

- `GameDataController.SpeHeroDataBase` (+0x150): 170 preset special hero templates
- `GameDataController.loveableSpeHeroList` (+0x1D8): 46 entries
- `SpeHeroLimit` enum: None, NoneSpeHero, SpeHero

## Key Constraint

**GenerateHeroData MUST run on the main thread.** Calling via `executeCodeEx` (remote thread) crashes the game. Need to use the hookCode cmd system in GameController.Update.

## TODO: Implementation

1. Add cmd=5 to hookCode assembly for GenerateHeroData call
2. Set up cmdBuf parameters: forceID, heroID, difficulty
3. After GenerateHeroData returns HeroData, call WorldAddNewHero to add to world
4. Or call ManagePlayerRecruitHero to trigger the recruit dialog
5. Test with player's forceID (25) to spawn hero in player faction

## Alternative: Spawn the World Event

Instead of calling GenerateHeroData directly, we could create the 武学奇才 EventData and add it to WorldEventDatas. This lets the player interact with the event normally through the game UI.

Would need:
- Create EventData object with correct plotData reference
- Set location, difficulty, leftTime
- Add to WorldData.WorldEventDatas list
