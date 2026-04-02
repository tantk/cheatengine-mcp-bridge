#!/usr/bin/env python3
"""Compare two Il2CppDumper script.json files and report RVA changes."""

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

def load_methods(script_path: str) -> tuple[dict[str, int], dict[int, str]]:
    """Load script.json and return (name->rva, rva->name) mappings.

    Builds the reverse map directly from raw data to handle duplicate
    method names correctly (script.json has ~7K duplicates).
    """
    with open(script_path) as f:
        script = json.load(f)
    name_to_rva = {}
    rva_to_name = {}
    for entry in script["ScriptMethod"]:
        name = entry["Name"]
        rva = entry["Address"]
        name_to_rva[name] = rva
        rva_to_name[rva] = name
    return name_to_rva, rva_to_name


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


def _iter_ct_scripts(ct_path: str):
    """Parse CT XML and yield text from all LuaScript and AssemblerScript elements."""
    tree = ET.parse(ct_path)
    root = tree.getroot()
    for tag in ("LuaScript", "AssemblerScript"):
        for elem in root.iter(tag):
            text = elem.text or ""
            if text.strip():
                yield text


def extract_ct_rvas(ct_path: str, rva_range: tuple[int, int] | None = None) -> list[dict]:
    """Extract hardcoded RVAs from cheat table scripts.

    Parses both <LuaScript> and <AssemblerScript> sections. If rva_range
    is provided as (min_rva, max_rva), filters out hex constants that
    fall outside the valid method RVA range.
    """
    entries = []
    seen = set()

    for text in _iter_ct_scripts(ct_path):
        for match in re.finditer(r"0x([A-Fa-f0-9]{5,8})\b", text):
            rva = int(match.group(1), 16)
            if rva_range and not (rva_range[0] <= rva <= rva_range[1]):
                continue
            if rva in seen:
                continue
            seen.add(rva)
            line_start = text.rfind("\n", 0, match.start()) + 1
            line_end = text.find("\n", match.end())
            if line_end == -1:
                line_end = len(text)
            context = text[line_start:line_end].strip()
            entries.append({"rva": rva, "hex": f"0x{match.group(1)}", "context": context})

    return entries


def extract_ct_aobs(ct_path: str) -> list[dict]:
    """Extract AOB signatures from cheat table scripts.

    Matches inner table entries like: setBook = {sig="48 8B ...", off=0x3F}
    Uses a line-oriented regex to avoid matching the outer table name.
    """
    sigs = []
    for text in _iter_ct_scripts(ct_path):
        for match in re.finditer(
            r'^\s*(\w+)\s*=\s*\{[^}]*sig\s*=\s*"([0-9A-Fa-f ?]+)"',
            text,
            re.MULTILINE,
        ):
            sigs.append({"name": match.group(1), "sig": match.group(2)})
    return sigs


def analyze_ct_impact(
    ct_rvas: list[dict],
    old_rva_to_name: dict[int, str],
    new_methods: dict[str, int],
) -> list[dict]:
    """Cross-reference CT hardcoded RVAs against shifted methods."""
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
            results.append({**entry, "method": "not a script method", "new_rva": None, "new_hex": "N/A", "status": "UNKNOWN"})

    return results


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

    if diff["shifted"]:
        lines += [
            f"## Shifted Methods ({len(diff['shifted'])} total, showing top 100)",
            "| Method | Old RVA | New RVA | Delta |",
            "|---|---|---|---|",
        ]
        sorted_shifted = sorted(diff["shifted"], key=lambda x: abs(x["delta"]), reverse=True)
        for e in sorted_shifted[:100]:
            lines.append(
                f"| {e['name']} | 0x{e['old_rva']:X} | 0x{e['new_rva']:X} | {e['delta']:+d} |"
            )
        lines.append("")

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

    try:
        print(f"Loading old script: {args.old_script}")
        old_methods, old_rva_to_name = load_methods(args.old_script)
        print(f"  {len(old_methods)} methods")

        print(f"Loading new script: {args.new_script}")
        new_methods, _ = load_methods(args.new_script)
        print(f"  {len(new_methods)} methods")
    except FileNotFoundError as e:
        print(f"Error: file not found: {e.filename}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON: {e}", file=sys.stderr)
        return 2

    print("Diffing...")
    diff = diff_methods(old_methods, new_methods)

    ct_impact = []
    ct_aobs = []
    if args.ct:
        try:
            print(f"Analyzing CT impact: {args.ct}")
            rva_range = (min(old_methods.values()), max(old_methods.values())) if old_methods else None
            ct_rvas = extract_ct_rvas(args.ct, rva_range=rva_range)
            ct_impact = analyze_ct_impact(ct_rvas, old_rva_to_name, new_methods)
            ct_aobs = extract_ct_aobs(args.ct)
            print(f"  {len(ct_rvas)} hardcoded RVAs found, {len(ct_aobs)} AOB signatures")
        except (FileNotFoundError, ET.ParseError) as e:
            print(f"Error: CT file problem: {e}", file=sys.stderr)
            return 2

    report = generate_report(
        diff, ct_impact, ct_aobs,
        args.old_dll_size, args.new_dll_size,
        args.old_date, args.new_date,
    )

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

    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(report)
        print(f"\nFull report saved to: {args.output}")

    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
