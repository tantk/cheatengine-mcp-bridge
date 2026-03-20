# LongYinLiZhiZhuan Cheat Table

**Game:** LongYinLiZhiZhuan / Dragon Hidden Power (Steam)
**Engine:** Unity IL2CPP (2020.3.48)
**Cheat Engine:** 7.5+
**Version:** v1.0

## Features

### Resources
- **Set Money (Silver)** - Set your silver to any amount
- **Set Sect Currency** - Set your sect/force contribution points

### Talents (TianFu)
- **Max Talent Slots (9 -> 99)** - Increases the maximum number of talents you can learn from 9 to 99
- **Set Talent Points** - Set your available talent points to any value

### Skills
- **Max Skill Learn Limits (all tiers -> 99)** - Removes the per-rarity skill learning cap (default: 12/10/8/6/4/2 -> all 99)
- **WuXueTianCai Buff** - Edit the combat skill EXP rate bonus (default 30%, set to any %)
- **BoXueDuoCai Buff** - Edit the non-combat (living) skill EXP rate bonus (default 30%, set to any %)

### Stats
- **Stat Cap Boost** - Raises all skill and attribute caps (default 99, adjustable). Runs on a 3-second timer to keep caps boosted.

## How to Use

1. Launch the game and load your save
2. Open **Cheat Engine 7.5+**
3. Attach to **LongYinLiZhiZhuan.exe** (`File -> Open Process`)
4. Load the cheat table (`File -> Open` -> select `LongYinLiZhiZhuan.CT`)
5. Expand the group headers and tick the cheats you want to enable
6. Cheats with dialogs (Money, Sect Currency, Talent Points, Buff editors) will prompt you for a value when enabled

## Notes

- All cheats use **data-only modifications** (no code injection), so they are safe and should not crash the game
- The talent buff editors (WuXueTianCai / BoXueDuoCai) require you to **have the corresponding talent** on your character for the buff to take effect
- Stat Cap Boost uses a timer that refreshes every 3 seconds. Disable it when you no longer need it
- The table dynamically resolves all addresses using Mono/IL2CPP, so it should work across game updates as long as the class structure hasn't changed
- **Save your game before enabling cheats** just in case

## Compatibility

- Tested on the Steam Demo and v1.0 Release
- Should work on future updates unless the developer changes class field layouts

## Credits

Created with [Cheat Engine MCP Bridge](https://github.com/miscusi-peek/cheatengine-mcp-bridge) + Claude AI
