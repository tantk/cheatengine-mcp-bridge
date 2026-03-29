# Character Creation Talent Slot Limit Investigation

## Problem
The character creation screen limits talent slots to 5. The goal was to find and patch this limit.

## What Didn't Work

### 1. Patching GetMaxTagNum (RVA 0x625040)
- Patched to `mov eax, 99; ret` — no effect on creation screen
- This method controls in-game talent slots, not creation screen
- The creation screen doesn't call GetMaxTagNum at all

### 2. Patching GetHeroPermanentTagNum (RVA 0x623370)
- Patched to return 10 — no effect
- This method counts existing permanent tags, doesn't set a limit

### 3. Patching RandomGenerateHeroTag loop (RVA 0x55A210)
- Found `cmp ebx, 4` at RVA 0x55B193 (loop runs 0-4 = 5 iterations)
- Changed to `cmp ebx, 9` — no effect
- This controls how many random talents are GENERATED in the pool
- Only runs once per game launch (cached), and doesn't control UI slot count
- The loop is probability-based (random check per iteration), not guaranteed 5

### 4. Changing BirthSetting+0xEC
- Found value 5 on StartGameSettingController.BirthSetting object
- Changed to 10, even froze with timer — no effect
- False positive — unrelated field that happened to be 5

### 5. Hardware breakpoints on talent count addresses
- Game crashed when hardware write breakpoints triggered
- Unity games don't handle debug exceptions well

### 6. Writing directly to talent count addresses
- Found 3 addresses that track current selected talent count
- Writing to them crashed the game
- These are read-only display values, not the source of truth

## What Worked — The Discovery Path

### Step 1: Find the right controller class
The breakthrough was searching ALL classes in the IL2CPP image for active singleton instances with tag-related fields:

```lua
-- Iterate all classes, check for _instance != null, look for tag-related fields
for idx = 0, classCount - 1 do
  local klass = il2cpp_image_get_class(image, idx)
  local staticFields = readQword(klass + 0xB8)
  local inst = readQword(staticFields)
  if inst ~= 0 then
    -- Check fields for "tag", "birth", "talent" keywords
  end
end
```

This found **`StartMenuController`** — the actual creation screen controller with fields:
- `tagRoot` (+0xA8)
- `selfTagGrid` (+0xB0) — the selected talents grid
- `allTagGrid` (+0xB8) — the available talents grid
- `startChooseTagPrefab` (+0xC0)

Previous searches missed this because we were guessing class names (CreateHeroController, TagPanel, etc.) but the actual class is called `StartMenuController`.

### Step 2: Find the methods
Enumerated StartMenuController methods filtered for tag-related names:
- `StartChooseTagClicked(0)` RVA=0x9D4A30 — runs when clicking to ADD a talent
- `StartUnchooseTagClicked(0)` RVA=0x9D4F30 — runs when clicking to REMOVE
- `RefreshTagMenu(0)` RVA=0x9D1A60 — refreshes the talent UI display

### Step 3: Find the comparisons
Searched both methods for `cmp` instructions with value 5:

**StartChooseTagClicked + 0xE8:**
```asm
83 78 18 05     cmp dword ptr [rax+18], 05  ; compare selfTagList._size against 5
0F 8C C5000000  jl  +0xC5                   ; if count < 5, allow adding
```
This checks `selfTagList.Count < 5` before allowing a new talent to be added.

**RefreshTagMenu + 0x554:**
```asm
83 F8 05        cmp eax, 05                 ; compare count against 5
```
This disables/hides available talent buttons when count >= 5.

### Step 4: Patch both
Change the `05` byte to `0A` (10) in both locations:
- `StartChooseTagClicked`: byte at RVA 0x9D4B1B
- `RefreshTagMenu`: byte at RVA 0x9D1FB6

## Key Lessons

1. **The creation screen uses `StartMenuController`, not any "Create" or "Tag" named controller**
2. **The limit is enforced in TWO places** — the click handler AND the refresh/display handler. Both must be patched.
3. **`ManageTagController`** exists but is for IN-GAME talent management, not character creation. Its instance is null during creation.
4. **The talent count addresses the user found via scanning are display values** in native UI memory, not on IL2CPP managed objects. They can't be traced back to a class easily.
5. **Hardware breakpoints crash Unity games** — avoid using them.
6. **To find singleton controllers**: iterate all classes via `il2cpp_image_get_class`, check `klass+0xB8` for static fields, check if `_instance` is non-null.
7. **RandomGenerateHeroTag** only runs once per game launch. Re-entering character creation reuses cached data.

## Patch Summary

| Location | RVA | Original | Patched | Effect |
|----------|-----|----------|---------|--------|
| StartChooseTagClicked | 0x9D4B1B | 05 | 0A | Allow adding up to 10 talents |
| RefreshTagMenu | 0x9D1FB6 | 05 | 0A | Keep talent buttons enabled up to 10 |

Both are single-byte patches (change `05` to desired max).

## AOB Patterns for CT

For version-independent scanning within StartMenuController methods:
- StartChooseTagClicked: `83 78 18 05 48 8B 15` (cmp [rax+18],5 followed by mov rdx,[...])
- RefreshTagMenu: `83 F8 05 7C` (cmp eax,5 followed by jl) — but this pattern is common, needs context filtering
