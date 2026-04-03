# Game Update Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a `/game-update` skill that detects game binary changes, archives old versions, orchestrates the full decompile+resolve pipeline, and produces an RVA diff report with CT impact analysis.

**Architecture:** Single SKILL.md file containing the full orchestration instructions. The skill delegates heavy lifting to existing `/game-decompiler` and `/coverage-maximizer` skills. Phase 6 (RVA diff + CT impact) is implemented as a standalone Python script so it can also be run independently.

**Tech Stack:** Python 3 (hashlib, json, struct, datetime), Bash, existing skills

---

### Task 1: Create the RVA diff script

The core new logic — compares two `script.json` files and produces a diff report. This is the only real code to write; the rest is a skill file with orchestration instructions.

**Files:**
- Create: `tools/rva_diff.py`

- [ ] **Step 1: Create rva_diff.py with argument parsing and script.json loading**

```python
#!/usr/bin/env python3
"""Compare two Il2CppDumper script.json files and report RVA changes."""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

IMAGE_BASE = 0x180000000


def load_methods(script_path: str) -> dict[str, int]:
    """Load script.json and return {method_name: rva} mapping."""
    with open(script_path) as f:
        script = json.load(f)
    methods = {}
    for entry in script["ScriptMethod"]:
        name = entry["Name"]
        rva = entry["Address"]
        methods[name] = rva
    return methods


def diff_methods(old: dict[str, int], new: dict[str, int]) -> dict:
    """Compare two method maps and return categorized diff."""
    all_names = set(old) | set(new)
    shifted = []
    added = []
    removed = []

    for name in sorted(all_names):
        if name in old and name in new:
            if old[name] != new[name]:
                shifted.append({
                    "name": name,
                    "old_rva": old[name],
                    "new_rva": new[name],
                    "delta": new[name] - old[name],
                })
        elif name in new:
            added.append({"name": name, "rva": new[name]})
        else:
            removed.append({"name": name, "rva": old[name]})

    return {"shifted": shifted, "added": added, "removed": removed}
```

- [ ] **Step 2: Add CT impact analysis function**

Append to `tools/rva_diff.py`:

```python
import re
import xml.etree.ElementTree as ET


def extract_ct_rvas(ct_path: str) -> list[dict]:
    """Extract hardcoded RVAs from cheat table Lua scripts.

    Parses the CT XML, finds all <LuaScript> sections, and greps for
    hex address patterns that look like RVAs (0x[A-Fa-f0-9]{5,8}).
    """
    tree = ET.parse(ct_path)
    root = tree.getroot()
    entries = []

    # Find all LuaScript elements
    for lua_elem in root.iter("LuaScript"):
        text = lua_elem.text or ""
        # Match patterns like: 0xB991F0 (5-8 hex digits, likely RVAs)
        for match in re.finditer(r"0x([A-Fa-f0-9]{5,8})\b", text):
            rva = int(match.group(1), 16)
            # Extract surrounding context (variable name or comment)
            line_start = text.rfind("\n", 0, match.start()) + 1
            line_end = text.find("\n", match.end())
            if line_end == -1:
                line_end = len(text)
            context = text[line_start:line_end].strip()
            entries.append({"rva": rva, "hex": f"0x{match.group(1)}", "context": context})

    return entries


def extract_ct_aobs(ct_path: str) -> list[dict]:
    """Extract AOB signatures from cheat table Lua scripts."""
    tree = ET.parse(ct_path)
    root = tree.getroot()
    sigs = []

    for lua_elem in root.iter("LuaScript"):
        text = lua_elem.text or ""
        # Match AOB_SIGS table entries or sig= patterns
        for match in re.finditer(
            r'(\w+)\s*=\s*\{[^}]*sig\s*=\s*"([0-9A-Fa-f ?]+)"', text
        ):
            sigs.append({"name": match.group(1), "sig": match.group(2)})

    return sigs


def analyze_ct_impact(
    ct_rvas: list[dict],
    old_methods: dict[str, int],
    new_methods: dict[str, int],
) -> list[dict]:
    """Cross-reference CT hardcoded RVAs against shifted methods."""
    # Build reverse maps: rva -> method name
    old_rva_to_name = {rva: name for name, rva in old_methods.items()}
    new_rva_to_name = {rva: name for name, rva in new_methods.items()}

    results = []
    for entry in ct_rvas:
        rva = entry["rva"]
        method = old_rva_to_name.get(rva, "unknown")
        if method != "unknown" and method in new_methods:
            new_rva = new_methods[method]
            status = "OK" if new_rva == rva else "SHIFTED"
            results.append({
                **entry,
                "method": method,
                "new_rva": new_rva,
                "new_hex": f"0x{new_rva:X}",
                "status": status,
            })
        elif method != "unknown":
            results.append({**entry, "method": method, "new_rva": None, "new_hex": "N/A", "status": "REMOVED"})
        else:
            # RVA not in old script.json — might be an IL2CPP runtime address, not a method RVA
            results.append({**entry, "method": "not a script method", "new_rva": None, "new_hex": "N/A", "status": "UNKNOWN"})

    return results
```

- [ ] **Step 3: Add markdown report generator**

Append to `tools/rva_diff.py`:

```python
def generate_report(
    diff: dict,
    ct_impact: list[dict],
    ct_aobs: list[dict],
    old_size: int,
    new_size: int,
    old_date: str,
    new_date: str,
) -> str:
    """Generate a markdown diff report."""
    lines = [
        f"# RVA Diff Report: {old_date} -> {new_date}",
        "",
        "## Summary",
        f"- Binary size delta: {new_size - old_size:+d} bytes ({old_size:,} -> {new_size:,})",
        f"- Methods shifted: {len(diff['shifted'])}",
        f"- Methods added: {len(diff['added'])}",
        f"- Methods removed: {len(diff['removed'])}",
        "",
    ]

    # CT Impact
    ct_relevant = [e for e in ct_impact if e["status"] != "UNKNOWN"]
    if ct_relevant:
        lines += [
            "## Cheat Table Impact",
            "| CT Context | Method | Old RVA | New RVA | Status |",
            "|---|---|---|---|---|",
        ]
        for e in ct_relevant:
            ctx = e["context"][:60] if len(e["context"]) > 60 else e["context"]
            lines.append(
                f"| `{ctx}` | {e['method']} | {e['hex']} | {e.get('new_hex', 'N/A')} | **{e['status']}** |"
            )
        lines.append("")

    # AOB Signatures
    if ct_aobs:
        lines += [
            "## AOB Signature Check",
            "",
            "AOB signatures use pattern matching and typically survive minor updates.",
            "Verify manually if methods they target have shifted.",
            "",
            "| Signature | Pattern |",
            "|---|---|",
        ]
        for sig in ct_aobs:
            lines.append(f"| {sig['name']} | `{sig['sig'][:50]}` |")
        lines.append("")

    # Shifted methods (top 100)
    if diff["shifted"]:
        lines += [
            f"## Shifted Methods ({len(diff['shifted'])} total, showing top 100)",
            "| Method | Old RVA | New RVA | Delta |",
            "|---|---|---|---|",
        ]
        # Sort by absolute delta descending
        sorted_shifted = sorted(diff["shifted"], key=lambda x: abs(x["delta"]), reverse=True)
        for e in sorted_shifted[:100]:
            lines.append(
                f"| {e['name']} | 0x{e['old_rva']:X} | 0x{e['new_rva']:X} | {e['delta']:+d} |"
            )
        lines.append("")

    # Added methods
    if diff["added"]:
        lines += [
            f"## Added Methods ({len(diff['added'])} total)",
            "| Method | RVA |",
            "|---|---|",
        ]
        for e in diff["added"][:50]:
            lines.append(f"| {e['name']} | 0x{e['rva']:X} |")
        if len(diff["added"]) > 50:
            lines.append(f"| ... and {len(diff['added']) - 50} more | |")
        lines.append("")

    # Removed methods
    if diff["removed"]:
        lines += [
            f"## Removed Methods ({len(diff['removed'])} total)",
            "| Method | Old RVA |",
            "|---|---|",
        ]
        for e in diff["removed"][:50]:
            lines.append(f"| {e['name']} | 0x{e['rva']:X} |")
        if len(diff["removed"]) > 50:
            lines.append(f"| ... and {len(diff['removed']) - 50} more | |")
        lines.append("")

    return "\n".join(lines)
```

- [ ] **Step 4: Add main function with CLI interface**

Append to `tools/rva_diff.py`:

```python
def main():
    parser = argparse.ArgumentParser(description="Compare two script.json files and produce RVA diff report")
    parser.add_argument("old_script", help="Path to old script.json")
    parser.add_argument("new_script", help="Path to new script.json")
    parser.add_argument("--ct", default=None, help="Path to cheat table (.CT) for impact analysis")
    parser.add_argument("--old-dll-size", type=int, default=0, help="Old DLL file size in bytes")
    parser.add_argument("--new-dll-size", type=int, default=0, help="New DLL file size in bytes")
    parser.add_argument("--old-date", default="old", help="Label for old version (e.g., 2026-04-01)")
    parser.add_argument("--new-date", default="new", help="Label for new version (e.g., 2026-04-02)")
    parser.add_argument("-o", "--output", default=None, help="Output markdown file path")
    args = parser.parse_args()

    print(f"Loading old script: {args.old_script}")
    old_methods = load_methods(args.old_script)
    print(f"  {len(old_methods)} methods")

    print(f"Loading new script: {args.new_script}")
    new_methods = load_methods(args.new_script)
    print(f"  {len(new_methods)} methods")

    print("Diffing...")
    diff = diff_methods(old_methods, new_methods)

    ct_impact = []
    ct_aobs = []
    if args.ct:
        print(f"Analyzing CT impact: {args.ct}")
        ct_rvas = extract_ct_rvas(args.ct)
        ct_impact = analyze_ct_impact(ct_rvas, old_methods, new_methods)
        ct_aobs = extract_ct_aobs(args.ct)
        print(f"  {len(ct_rvas)} hardcoded RVAs found, {len(ct_aobs)} AOB signatures")

    report = generate_report(
        diff, ct_impact, ct_aobs,
        args.old_dll_size, args.new_dll_size,
        args.old_date, args.new_date,
    )

    # Console summary
    print(f"\n--- RVA Diff: {args.old_date} -> {args.new_date} ---")
    print(f"  Shifted: {len(diff['shifted'])}")
    print(f"  Added:   {len(diff['added'])}")
    print(f"  Removed: {len(diff['removed'])}")

    broken = [e for e in ct_impact if e["status"] in ("SHIFTED", "REMOVED")]
    if broken:
        print(f"\n  !! CT IMPACT: {len(broken)} entries need updating:")
        for e in broken:
            print(f"     {e['hex']} ({e['method']}) -> {e['status']}")
    elif args.ct:
        print("\n  CT: all hardcoded RVAs unchanged")

    # Write report
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(report)
        print(f"\nFull report saved to: {args.output}")

    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Test the script against current data**

```bash
python tools/rva_diff.py \
  C:/dev/gameanalysis/Il2CppDumper/script.json \
  C:/dev/gameanalysis/Il2CppDumper/script.json \
  --ct games/LongYinLiZhiZhuan/patches/LongYinLiZhiZhuan.CT \
  --old-date 2026-04-01 --new-date 2026-04-01
```

Expected: 0 shifted, 0 added, 0 removed (same file compared to itself). CT extraction should list found RVAs.

- [ ] **Step 6: Commit**

```bash
git add tools/rva_diff.py
git commit -m "Add RVA diff tool for comparing script.json versions with CT impact analysis"
```

---

### Task 2: Create the game-update skill file

**Files:**
- Create: `.claude/skills/game-update/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

```markdown
---
name: game-update
description: Handle a game binary update end-to-end. Detects DLL changes, archives old version, runs the full decompile and coverage pipeline, and produces an RVA diff report with cheat table impact analysis. Use when the user says "game updated", "new version", "update decomps", "rebuild call graph", "check for DLL changes", "new patch", or after Steam updates the game.
---

# Game Update Pipeline

Orchestrates the full update pipeline when the game binary changes: detect, archive, decompile, resolve, index, and report.

**Total time: ~45 minutes** (mostly Ghidra analysis + parallel export).

## Paths

| Item | Path |
|---|---|
| Game install | `C:/Program Files (x86)/Steam/steamapps/common/LongYinLiZhiZhuan/` |
| Analysis workspace | `C:/dev/gameanalysis/` |
| Current binary | `C:/dev/gameanalysis/game_binary/` |
| Version archives | `C:/dev/gameanalysis/game_binary_versions/` |
| Decomps (new) | `C:/dev/gameanalysis/game_b_decomps_new/` |
| Il2CppDumper output | `C:/dev/gameanalysis/Il2CppDumper/` |
| Cheat table | `C:/dev/cheatenginemcp/games/LongYinLiZhiZhuan/patches/LongYinLiZhiZhuan.CT` |
| RVA diff tool | `C:/dev/cheatenginemcp/tools/rva_diff.py` |

## Phase 1: Detect Binary Changes

Compare hashes of the current archived DLL vs the live game DLL:

```bash
sha256sum "C:/dev/gameanalysis/game_binary/GameAssembly.dll"
sha256sum "C:/Program Files (x86)/Steam/steamapps/common/LongYinLiZhiZhuan/GameAssembly.dll"
```

- If hashes match: report "No binary changes detected" and **stop**.
- If hashes differ: report the size delta and proceed.

Also check global-metadata.dat:
```bash
sha256sum "C:/dev/gameanalysis/game_binary/global-metadata.dat"
sha256sum "C:/Program Files (x86)/Steam/steamapps/common/LongYinLiZhiZhuan/LongYinLiZhiZhuan_Data/il2cpp_data/Metadata/global-metadata.dat"
```

## Phase 2: Archive Old Version

1. Get the modification date of the **old** `C:/dev/gameanalysis/game_binary/GameAssembly.dll`:
```bash
stat -c %y "C:/dev/gameanalysis/game_binary/GameAssembly.dll" | cut -d' ' -f1
```

2. Create the versioned archive directory:
```bash
DATE=$(stat -c %y "C:/dev/gameanalysis/game_binary/GameAssembly.dll" | cut -d' ' -f1)
ARCHIVE="C:/dev/gameanalysis/game_binary_versions/$DATE"

# Handle same-day collision
if [ -d "$ARCHIVE" ]; then
  i=2; while [ -d "${ARCHIVE}_${i}" ]; do i=$((i+1)); done
  ARCHIVE="${ARCHIVE}_${i}"
fi

mkdir -p "$ARCHIVE"
```

3. Copy old files into the archive:
```bash
cp C:/dev/gameanalysis/game_binary/GameAssembly.dll "$ARCHIVE/"
cp C:/dev/gameanalysis/game_binary/global-metadata.dat "$ARCHIVE/"
cp C:/dev/gameanalysis/Il2CppDumper/script.json "$ARCHIVE/" 2>/dev/null
cp C:/dev/gameanalysis/game_b_decomps_new/name_index.json "$ARCHIVE/" 2>/dev/null
cp C:/dev/gameanalysis/game_b_decomps_new/manual_names.json "$ARCHIVE/" 2>/dev/null
```

Report: "Archived old binary to `game_binary_versions/<DATE>/`"

## Phase 3: Copy New Binaries

```bash
GAME="C:/Program Files (x86)/Steam/steamapps/common/LongYinLiZhiZhuan"
cp "$GAME/GameAssembly.dll" C:/dev/gameanalysis/game_binary/
cp "$GAME/LongYinLiZhiZhuan_Data/il2cpp_data/Metadata/global-metadata.dat" C:/dev/gameanalysis/game_binary/
```

Verify:
```bash
ls -la C:/dev/gameanalysis/game_binary/GameAssembly.dll
ls -la C:/dev/gameanalysis/game_binary/global-metadata.dat
```

Both files must be non-zero size.

## Phase 4: Decompile (~40 min)

Invoke the `/game-decompiler` skill. It handles:
1. Il2CppDumper (~30 sec) -> script.json, dump.cs, il2cpp.h
2. Build name_index.json from script.json
3. Ghidra headless analysis (~24 min)
4. Parallel decompile export (~15 min, 8 threads)

Wait for it to complete before proceeding.

## Phase 5: Resolve + Index (~5 min)

Invoke the `/coverage-maximizer` skill. It handles:
1. 9 resolution techniques -> 100% function name coverage
2. Verification (must confirm 100.00%)
3. Git init + commit in decomps_resolved/
4. GitNexus analyze -> knowledge graph rebuild

Wait for it to complete before proceeding.

## Phase 6: RVA Diff Report

Run the diff tool using the archived old script.json and the new one:

```bash
OLD_DATE="<date from Phase 2>"
NEW_DATE=$(stat -c %y "C:/dev/gameanalysis/game_binary/GameAssembly.dll" | cut -d' ' -f1)
OLD_SIZE=$(stat -c %s "C:/dev/gameanalysis/game_binary_versions/$OLD_DATE/GameAssembly.dll")
NEW_SIZE=$(stat -c %s "C:/dev/gameanalysis/game_binary/GameAssembly.dll")

python C:/dev/cheatenginemcp/tools/rva_diff.py \
  "C:/dev/gameanalysis/game_binary_versions/$OLD_DATE/script.json" \
  "C:/dev/gameanalysis/Il2CppDumper/script.json" \
  --ct "C:/dev/cheatenginemcp/games/LongYinLiZhiZhuan/patches/LongYinLiZhiZhuan.CT" \
  --old-dll-size "$OLD_SIZE" \
  --new-dll-size "$NEW_SIZE" \
  --old-date "$OLD_DATE" \
  --new-date "$NEW_DATE" \
  -o "C:/dev/gameanalysis/game_b_decomps_new/rva_diff_${OLD_DATE}_vs_${NEW_DATE}.md"
```

## Done

When complete, report to the user:

1. Summary: methods shifted/added/removed
2. CT impact: which hardcoded RVAs need updating (if any)
3. Full report location: `game_b_decomps_new/rva_diff_*.md`

If any CT entries show **SHIFTED** or **REMOVED**, remind the user to run the CT fix skill (or manually update addresses).
```

- [ ] **Step 2: Verify the skill appears in the skill list**

Run a command or check that `.claude/skills/game-update/SKILL.md` is properly detected.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/game-update/SKILL.md
git commit -m "Add game-update skill: orchestrates full pipeline on binary update"
```

---

### Task 3: End-to-end validation

- [ ] **Step 1: Test rva_diff.py with self-comparison (zero diff)**

```bash
python tools/rva_diff.py \
  C:/dev/gameanalysis/Il2CppDumper/script.json \
  C:/dev/gameanalysis/Il2CppDumper/script.json \
  --ct games/LongYinLiZhiZhuan/patches/LongYinLiZhiZhuan.CT \
  --old-dll-size 33284096 --new-dll-size 33284096 \
  --old-date 2026-04-01 --new-date 2026-04-01 \
  -o /tmp/test_rva_diff.md
```

Expected: 0 shifted, 0 added, 0 removed. CT RVAs listed as OK or UNKNOWN. Report file created.

- [ ] **Step 2: Verify CT extraction finds known RVAs**

The script should find at least the two known hardcoded RVAs (`0xB991F0`, `0xB9A110`) in its output. Check the console output and the report.

- [ ] **Step 3: Verify the markdown report is well-formed**

Read `/tmp/test_rva_diff.md` and confirm all sections render correctly.

- [ ] **Step 4: Clean up test artifacts**

```bash
rm /tmp/test_rva_diff.md
```
