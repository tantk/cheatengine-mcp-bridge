# Game Update Skill Design

## Overview

A single `/game-update` skill that orchestrates the full pipeline when the game receives a binary update: detect changes, archive the old binary, decompile the new one, resolve to 100% coverage, index the call graph, and produce an RVA diff report showing what shifted and which cheat table entries are affected.

**Does NOT auto-fix the CT** — that's a separate future skill. This skill detects, rebuilds, and reports.

## Trigger

User says: "game updated", "new version", "update decomps", "rebuild call graph", "check for DLL changes", "new patch"

## Phases

### Phase 1: Detect (~5 sec)

1. SHA256-hash the current archived binary at `C:/dev/gameanalysis/game_binary/GameAssembly.dll`
2. SHA256-hash the live game binary at `C:/Program Files (x86)/Steam/steamapps/common/LongYinLiZhiZhuan/GameAssembly.dll`
3. If hashes match → print "No binary changes detected", stop
4. If hashes differ → print size delta (bytes), proceed to Phase 2

### Phase 2: Archive (~10 sec)

1. Read the file modification timestamp of the **old** `C:/dev/gameanalysis/game_binary/GameAssembly.dll`
2. Format as `YYYY-MM-DD` (e.g., `2026-04-01`)
3. Create directory `C:/dev/gameanalysis/game_binary_versions/<YYYY-MM-DD>/`
   - If directory already exists (same-day update), append a counter: `2026-04-02_2`
4. Copy into the archive directory:
   - `game_binary/GameAssembly.dll`
   - `game_binary/global-metadata.dat`
   - `Il2CppDumper/script.json`
   - `game_b_decomps_new/name_index.json`
   - `game_b_decomps_new/manual_names.json`

### Phase 3: Copy New Binaries (~5 sec)

1. Copy from game install folder to `C:/dev/gameanalysis/game_binary/`:
   - `GameAssembly.dll`
   - `LongYinLiZhiZhuan_Data/il2cpp_data/Metadata/global-metadata.dat`
2. Verify copy succeeded (check file sizes are non-zero)

### Phase 4: Decompile (~40 min)

Invoke the `/game-decompiler` skill, which handles:
1. Il2CppDumper (~30 sec) → `script.json`, `dump.cs`, `il2cpp.h`
2. Build `name_index.json` from `script.json`
3. Ghidra headless analysis (~24 min)
4. Parallel decompile export (~15 min, 8 threads)
5. Output: ~74K raw `.c` files in `game_b_decomps_new/decomps/`

### Phase 5: Resolve + Index (~5 min)

Invoke the `/coverage-maximizer` skill, which handles:
1. 9 resolution techniques → 100% function name coverage
2. Verification (must confirm 100.00%)
3. Git init + commit in `decomps_resolved/`
4. GitNexus `analyze` → knowledge graph rebuild
5. Output: ~55K resolved `.c` files + LadybugDB

### Phase 6: RVA Diff Report

#### Data Loading
1. Load **old** `script.json` from the archive directory (`game_binary_versions/<date>/script.json`)
2. Load **new** `script.json` from `C:/dev/gameanalysis/Il2CppDumper/script.json`
3. Build method name → RVA maps from both

#### Diff Analysis
For every method name present in either version:
- **Shifted**: same name, different RVA → record old and new address
- **Added**: in new only → record as new method
- **Removed**: in old only → record as removed method

#### CT Impact Analysis
1. Parse the CT file (`games/LongYinLiZhiZhuan/patches/LongYinLiZhiZhuan.CT`) for all hardcoded RVAs (grep for hex patterns like `0x[A-F0-9]+` in Lua script sections)
2. Cross-reference each hardcoded RVA against the shifted methods list
3. Also extract AOB signatures from the CT and verify they still match at the expected locations in the new binary

#### Report Output

**Print to console**: summary with counts (shifted, added, removed, CT impact).

**Save to markdown**: full report at `C:/dev/gameanalysis/game_b_decomps_new/rva_diff_<old-date>_vs_<new-date>.md` containing:

```markdown
# RVA Diff Report: <old-date> → <new-date>

## Summary
- Binary size delta: +/-N bytes
- Methods shifted: N
- Methods added: N
- Methods removed: N

## Cheat Table Impact
| CT Entry | Method | Old RVA | New RVA | Status |
|---|---|---|---|---|
| Member Limit (display) | GetMaxHeroNum | 0xB991F0 | 0xB99230 | SHIFTED |
| Member Limit (check) | PopulationNotFull | 0xB9A110 | 0xB9A110 | OK |

## AOB Signature Check
| Signature | Status |
|---|---|
| setBook | OK / BROKEN |
| setMat | OK / BROKEN |
| ctor | OK / BROKEN |
| clone | OK / BROKEN |

## Shifted Methods (top 100 by reference count)
| Method | Old RVA | New RVA | Delta |
|---|---|---|---|
| ... | ... | ... | ... |

## Added Methods (N total)
...

## Removed Methods (N total)
...
```

## File Locations

| Artifact | Path |
|---|---|
| Versioned archives | `C:/dev/gameanalysis/game_binary_versions/<YYYY-MM-DD>/` |
| Diff report (markdown) | `C:/dev/gameanalysis/game_b_decomps_new/rva_diff_*.md` |
| Skill file | `~/.claude/skills/game-update/SKILL.md` |

## Scope Boundaries

**In scope:**
- Binary change detection (hash comparison)
- Versioned archiving of old binaries + indices
- Orchestrating game-decompiler and coverage-maximizer skills
- RVA diff generation and CT impact report

**Out of scope (future separate skill):**
- Auto-fixing CT hardcoded RVAs
- Auto-updating AOB signatures
- Patching the cheat table XML directly
