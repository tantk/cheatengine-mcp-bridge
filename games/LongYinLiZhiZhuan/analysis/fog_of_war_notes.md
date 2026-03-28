# Fog of War Removal — Dungeon Exploration

## How It Works

The dungeon exploration uses a grid system managed by `ExploreController`.
Calling `ExploreController.SeeAllTile()` reveals the entire map including
terrain, buildings, events, and exits — with proper visual fog removal.

## Key Classes

| Class | Purpose |
|-------|---------|
| ExploreController | Main dungeon controller (singleton, static+0x8) |
| ExplorePanelData | Map config (size, tiles, power) |
| ExploreTileData | Per-tile data (seen, row, col, type, events) |
| ExploreTileUnitController | Per-tile visual controller (RefreshColor, needRefreshColor) |

## ExploreController Fields

| Field | Offset | Type |
|-------|--------|------|
| exploreObj | 0x30 | |
| exploreGrid | 0x40 | |
| gridUnits | 0x80 | GameObject[,] — 2D array of tile GameObjects |
| playerGrid | 0x90 | Current player position |
| leftPower | 0x98 | Remaining stamina |
| exploreMapData | 0x70 | ExploreMapData |
| explorePanelData | 0x78 | ExplorePanelData |

## ExplorePanelData Fields

| Field | Offset |
|-------|--------|
| mapWidth | 0x18 |
| mapHeight | 0x1C |
| exploreTiles | 0x20 (List of ExploreTileData) |
| maxPower | 0x30 |

## ExploreTileData Fields

| Field | Offset | Notes |
|-------|--------|-------|
| name | 0x10 | |
| row | 0x20 | |
| column | 0x24 | |
| wallType | 0x30 | |
| doorOpen | 0x34 | |
| eventHappen | 0x35 | |
| exploreTileEventType | 0x38 | |
| seen | 0x58 | bool — fog state |
| moveAble | 0x59 | |

## ExploreTileUnitController Fields

| Field | Offset | Notes |
|-------|--------|-------|
| exploreTileData | 0x18 | Reference to tile data |
| been | 0x28 | bool — player has been here |
| needRefreshColor | 0x38 | bool — flag for visual update |

## Methods

| Method | Params | RVA (f8) | Notes |
|--------|--------|----------|-------|
| SeeAllTile | 0 | 0x6DDAF0 | **THE KEY METHOD** — reveals entire map with proper visuals |
| GetSeenTileNum | 0 | | Returns count of explored tiles |
| ManagePlayerAroundGrid | 1 | | Reveals adjacent tiles on move |
| PlayerEnterGrid | varies | | Called when player moves to tile |
| RefreshColor (ETUC) | 0 | 0x949610 | Visual fog refresh per tile |
| set_Seen (ETUC) | 1 | 0x94A3E0 | Sets seen + visual update |

## Implementation

```lua
-- 1. Find ExploreController singleton
local ecClass = findClass("ExploreController")
local ecInst = readQword(readQword(ecClass + 0xB8) + 0x8)

-- 2. Call SeeAllTile via executeCodeEx
executeCodeEx(0, nil, GA + SeeAllTileRVA, ecInst)
```

## What Didn't Work

1. **Patching GetSeeRange** — wrong system, causes world map lag for all NPCs
2. **Setting seen=1 directly on ExploreTileData** — reveals data (buildings show through fog) but NOT visual fog. Fog overlay remains. Also breaks normal exploration (game skips visual update for already-seen tiles).
3. **Setting needRefreshColor=1 on controllers** — didn't trigger refresh
4. **Using hookCode cmd=4** — cmdBuf+0x20 gets overwritten with GameController every frame, wrong `this` pointer → crash

## What Worked

`executeCodeEx(0, nil, SeeAllTileAddr, ExploreControllerInstance)` — calls the game's own reveal-all method from a remote thread. Works because SeeAllTile is a simple method that iterates tiles and calls set_Seen(true) on each, which handles both data AND visual updates.

## Notes

- ExploreController only exists when player is in a dungeon (BigMapRandomEvent)
- Dungeon maps are randomly generated (15x15, 20x20, 25x25 depending on difficulty)
- Grid is `GameObject[,]` (2D array) with ExploreTileUnitController components
- The controller klass pointer can be used to find all instances via AOBScan
- RVAs are version-specific — resolve at runtime via il2cpp_class_get_method_from_name
