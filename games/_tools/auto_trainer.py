#!/usr/bin/env python3
"""
Auto Trainer Generator for Unity IL2CPP Games
Input: dump.cs from Il2CppDumper
Output: .CT cheat table for Cheat Engine

Usage:
  python auto_trainer.py <dump.cs> [--output game.CT] [--game-name "My Game"]
"""

import re
import json
import os
import sys
import argparse
from dataclasses import dataclass, field
from typing import Optional
from xml.sax.saxutils import escape as xml_escape

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ============================================================
# DATA STRUCTURES
# ============================================================

@dataclass
class FieldInfo:
    name: str
    type: str
    offset: int
    is_static: bool = False

@dataclass
class MethodInfo:
    name: str
    rva: int
    signature: str

@dataclass
class ClassInfo:
    name: str
    namespace: str = ""
    parent: str = ""
    fields: dict = field(default_factory=dict)  # name -> FieldInfo
    methods: list = field(default_factory=list)  # list of MethodInfo
    has_instance: bool = False  # has _instance static field
    instance_offset: int = 0

@dataclass
class CheatTarget:
    category: str
    description: str
    class_name: str
    field_name: str
    field_type: str
    offset: int
    score: float
    pointer_chain: list = field(default_factory=list)  # list of (class, field, offset) tuples

# ============================================================
# PARSER: dump.cs -> ClassInfo[]
# ============================================================

def parse_dump_cs(path):
    """Parse Il2CppDumper's dump.cs line-by-line for speed."""
    classes = {}
    current_class = None
    last_rva = None

    re_class = re.compile(r'(?:public\s+)?class\s+(\w+)(?:\s*:\s*([\w,\s<>.]+))?\s*//')
    re_field = re.compile(r'\s+public\s+(.+?)\s+(\w+);\s*//\s*0x([0-9A-Fa-f]+)')
    re_static = re.compile(r'\[StaticField\]|\[static\]|static\s+')
    re_method_rva = re.compile(r'//\s*RVA:\s*0x([0-9A-Fa-f]+)')
    re_method_name = re.compile(r'public\s+\S+\s+(\w+)\((.*?)\)')

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            # Class definition
            m = re_class.search(line)
            if m:
                cname = m.group(1)
                parent = m.group(2).strip().split(",")[0].strip() if m.group(2) else ""
                current_class = ClassInfo(name=cname, parent=parent)
                classes[cname] = current_class
                last_rva = None
                continue

            if not current_class:
                continue

            # Field
            m = re_field.match(line)
            if m:
                ftype = m.group(1).strip()
                fname = m.group(2)
                foffset = int(m.group(3), 16)
                is_static = "static" in ftype or "[static]" in line
                ftype = ftype.replace("static ", "")
                fi = FieldInfo(name=fname, type=ftype, offset=foffset, is_static=is_static)
                current_class.fields[fname] = fi

                if fname in ("_instance", "Instance", "instance", "s_Instance"):
                    current_class.has_instance = True
                    current_class.instance_offset = foffset
                continue

            # Check for [static] on next line after field
            if "[static]" in line and current_class.fields:
                last_field = list(current_class.fields.values())[-1]
                last_field.is_static = True
                if last_field.name in ("_instance", "Instance", "instance", "s_Instance"):
                    current_class.has_instance = True
                    current_class.instance_offset = last_field.offset
                continue

            # Method RVA line
            m = re_method_rva.search(line)
            if m:
                last_rva = int(m.group(1), 16)
                continue

            # Method signature
            if last_rva is not None:
                m = re_method_name.search(line)
                if m:
                    current_class.methods.append(MethodInfo(
                        name=m.group(1), rva=last_rva, signature=m.group(2)
                    ))
                    last_rva = None

    return classes

# ============================================================
# DETECTOR: find cheat targets
# ============================================================

def load_patterns(path=None):
    if path is None:
        path = os.path.join(SCRIPT_DIR, "cheat_patterns.json")
    with open(path) as f:
        return json.load(f)

def score_field(field_name, field_type, patterns):
    """Score a field for cheat potential. Returns (score, category, description)."""
    best_score = 0
    best_cat = None
    best_desc = None
    name_lower = field_name.lower()

    for cat, info in patterns["categories"].items():
        score = 0

        # Check max_keywords first (more specific)
        for kw in info.get("max_keywords", []):
            if kw == name_lower:
                score += info["weight"] + 3  # exact match bonus
            elif kw in name_lower:
                score += info["weight"]

        # Check regular keywords
        for kw in info["keywords"]:
            if kw == name_lower:
                score += info["weight"] + 2
            elif kw in name_lower:
                score += info["weight"] - 1

        # Type match bonus
        for t in info["types"]:
            if t.lower() in field_type.lower():
                score += 2
                break

        if score > best_score:
            best_score = score
            best_cat = cat
            best_desc = info["description"]

    return best_score, best_cat, best_desc

def find_singletons(classes, patterns):
    """Find classes with _instance static field (likely managers/controllers)."""
    singletons = {}
    for name, cls in classes.items():
        # Skip engine/UI classes
        if any(ig in name for ig in patterns.get("ignore_classes", [])):
            continue
        if cls.has_instance:
            singletons[name] = cls
    return singletons

def find_player_class(classes, patterns):
    """Find the most likely player/character class."""
    candidates = {}

    for name, cls in classes.items():
        if any(ig in name for ig in patterns.get("ignore_classes", [])):
            continue

        score = 0

        # Name hints (strong signal)
        for hint in patterns.get("player_class_hints", []):
            if hint.lower() == name.lower():
                score += 30
            elif hint.lower() in name.lower():
                score += 15

        # Count cheat-relevant SIMPLE fields (not Lists, not strings)
        # Direct numeric fields (int/float) are better indicators than config lists
        cheat_fields = 0
        has_hp = False
        has_money = False
        for fname, fi in cls.fields.items():
            # Skip List/string/bool fields — these are usually config, not player stats
            if "List<" in fi.type or fi.type == "System.String" or fi.type == "System.Boolean":
                continue
            # Skip static fields
            if fi.is_static:
                continue
            s, cat, _ = score_field(fname, fi.type, patterns)
            if s >= 5:
                cheat_fields += 1
                if cat == "health":
                    has_hp = True
                if cat == "currency":
                    has_money = True

        score += cheat_fields * 5

        # Bonus for having both HP and money — strong player indicator
        if has_hp:
            score += 20
        if has_money:
            score += 10

        # Penalize classes that are mostly config (lots of List/static fields)
        total_fields = len(cls.fields)
        list_fields = sum(1 for f in cls.fields.values() if "List<" in f.type)
        if total_fields > 0 and list_fields / total_fields > 0.5:
            score -= 20  # Mostly lists = config class

        if score > 0:
            candidates[name] = score

    if not candidates:
        return None

    # Show top 5 for debugging
    top = sorted(candidates.items(), key=lambda x: -x[1])[:5]
    print("Player class candidates:")
    for name, sc in top:
        print(f"  {name}: {sc}")

    return max(candidates, key=candidates.get)

def find_pointer_chain(classes, singletons, target_class, patterns):
    """Try to find a pointer chain from a singleton to the target class."""
    # Direct: singleton has a field of type target_class
    for sname, scls in singletons.items():
        for fname, fi in scls.fields.items():
            if target_class in fi.type:
                return [(sname, fname, fi.offset)]

    # Two-hop: singleton -> intermediate -> target
    for sname, scls in singletons.items():
        for fname, fi in scls.fields.items():
            # Check if this field's type is a class that contains target
            ref_type = fi.type.split("<")[0].strip()  # strip generics
            if ref_type in classes:
                ref_cls = classes[ref_type]
                for rfname, rfi in ref_cls.fields.items():
                    if target_class in rfi.type:
                        return [
                            (sname, fname, fi.offset),
                            (ref_type, rfname, rfi.offset)
                        ]

    # Three-hop through List<> patterns
    for sname, scls in singletons.items():
        for fname, fi in scls.fields.items():
            if "List<" in fi.type:
                inner = re.search(r'List<(\w+)>', fi.type)
                if inner:
                    inner_type = inner.group(1)
                    if inner_type == target_class:
                        return [(sname, fname, fi.offset, "list_first")]
                    if inner_type in classes:
                        for rfname, rfi in classes[inner_type].fields.items():
                            if target_class in rfi.type:
                                return [
                                    (sname, fname, fi.offset, "list_first"),
                                    (inner_type, rfname, rfi.offset)
                                ]

    return None

def detect_cheats(classes, patterns):
    """Main detection: find all cheat targets with pointer chains."""
    singletons = find_singletons(classes, patterns)
    player_class = find_player_class(classes, patterns)

    print(f"\n=== Detection Results ===")
    print(f"Total classes: {len(classes)}")
    print(f"Singletons found: {len(singletons)} ({', '.join(singletons.keys())})")
    print(f"Likely player class: {player_class}")

    targets = []

    # Scan player class fields
    if player_class and player_class in classes:
        pcls = classes[player_class]
        chain = find_pointer_chain(classes, singletons, player_class, patterns)

        print(f"\nPointer chain to {player_class}:")
        if chain:
            for step in chain:
                extra = f" [{step[3]}]" if len(step) > 3 else ""
                print(f"  {step[0]}.{step[1]} (0x{step[2]:X}){extra}")
        else:
            print("  (not found - cheats will need manual pointer setup)")

        print(f"\nCheat targets in {player_class}:")
        for fname, fi in pcls.fields.items():
            if any(ig in fname for ig in patterns.get("ignore_fields", [])):
                continue
            score, cat, desc = score_field(fname, fi.type, patterns)
            if score >= 5:
                target = CheatTarget(
                    category=cat,
                    description=f"{desc}: {fname}",
                    class_name=player_class,
                    field_name=fname,
                    field_type=fi.type,
                    offset=fi.offset,
                    score=score,
                    pointer_chain=chain or []
                )
                targets.append(target)
                print(f"  [{cat}] {fname} ({fi.type}) @ 0x{fi.offset:X} score={score}")

    # Also scan singleton classes directly for currency/settings
    for sname, scls in singletons.items():
        for fname, fi in scls.fields.items():
            if any(ig in fname for ig in patterns.get("ignore_fields", [])):
                continue
            score, cat, desc = score_field(fname, fi.type, patterns)
            if score >= 8:  # higher threshold for singletons
                target = CheatTarget(
                    category=cat,
                    description=f"{desc}: {sname}.{fname}",
                    class_name=sname,
                    field_name=fname,
                    field_type=fi.type,
                    offset=fi.offset,
                    score=score,
                    pointer_chain=[(sname, "_instance", scls.instance_offset)]
                )
                # Avoid duplicates
                if not any(t.field_name == fname and t.class_name == sname for t in targets):
                    targets.append(target)
                    print(f"  [{cat}] {sname}.{fname} ({fi.type}) @ 0x{fi.offset:X} score={score}")

    targets.sort(key=lambda t: (-t.score, t.category))
    return targets, singletons, player_class

# ============================================================
# GENERATOR: CheatTarget[] -> .CT file
# ============================================================

def gen_lua_find_instance(class_name):
    """Generate Lua code to find a class instance via il2cpp API."""
    return f'''if syntaxcheck then return end
-- Find {class_name} via IL2CPP
local base = getAddress("GameAssembly.dll")
if not base or base == 0 then error("GameAssembly.dll not found") end
LaunchMonoDataCollector()
sleep(1000)
local cls = mono_findClass("", "{class_name}")
if not cls or cls == 0 then error("{class_name} class not found") end
local fields = mono_class_enumFields(cls)
local instance = nil
for _, f in ipairs(fields) do
  if f.name == "_instance" then
    instance = mono_class_getStaticFieldValue(cls, f.field)
    break
  end
end
if not instance or instance == 0 then error("{class_name}._instance not found") end'''

def gen_lua_navigate_chain(chain):
    """Generate Lua code to navigate a pointer chain."""
    code = ""
    var = "instance"
    for i, step in enumerate(chain):
        if len(step) > 3 and step[3] == "list_first":
            # Navigate through List<T> -> first element
            next_var = f"ptr{i}"
            code += f'\nlocal listPtr = readQword({var} + 0x{step[2]:X})'
            code += f'\nif not listPtr or listPtr == 0 then error("Null pointer at {step[0]}.{step[1]}") end'
            code += f'\nlocal listItems = readQword(listPtr + 0x10)'
            code += f'\nlocal {next_var} = readQword(listItems + 0x20)  -- first element'
            code += f'\nif not {next_var} or {next_var} == 0 then error("Empty list at {step[0]}.{step[1]}") end'
            var = next_var
        else:
            next_var = f"ptr{i}"
            code += f'\nlocal {next_var} = readQword({var} + 0x{step[2]:X})'
            code += f'\nif not {next_var} or {next_var} == 0 then error("Null at {step[0]}.{step[1]}") end'
            var = next_var
    return code, var

def gen_read_write(var, offset, field_type):
    """Generate read/write calls based on type."""
    if "int" in field_type.lower() or "int32" in field_type.lower():
        return f"readInteger({var} + 0x{offset:X})", f"writeInteger({var} + 0x{offset:X}, math.floor(val))"
    else:
        return f"readFloat({var} + 0x{offset:X})", f"writeFloat({var} + 0x{offset:X}, val * 1.0)"

def gen_cheat_entry(cheat_id, target):
    """Generate a CT XML entry for one cheat."""
    if not target.pointer_chain:
        return ""

    # Find which singleton to start from
    start_class = target.pointer_chain[0][0]

    lua_find = gen_lua_find_instance(start_class)

    # If target is on the singleton itself, navigate directly
    if target.class_name == start_class:
        nav_code = ""
        target_var = "instance"
    else:
        nav_code, target_var = gen_lua_navigate_chain(target.pointer_chain)

    read_expr, write_expr = gen_read_write(target_var, target.offset, target.field_type)

    lua_enable = f'''{lua_find}{nav_code}
local cur = {read_expr}
local input = InputQuery("{target.description}", "Current: " .. tostring(cur) .. ". Enter new value:", "9999")
if input then
  local val = tonumber(input) or 9999
  {write_expr}
  print("[{target.category}] {target.field_name} set to " .. val)
end'''

    lua_disable = f'''if syntaxcheck then return end
print("[{target.category}] {target.field_name} (value remains)")'''

    return f'''            <CheatEntry>
              <ID>{cheat_id}</ID>
              <Description>"{xml_escape(target.description)}"</Description>
              <Color>000000</Color>
              <VariableType>Auto Assembler Script</VariableType>
              <AssemblerScript><![CDATA[[ENABLE]
{{$lua}}
{lua_enable}
{{$asm}}

[DISABLE]
{{$lua}}
{lua_disable}
{{$asm}}
]]></AssemblerScript>
            </CheatEntry>'''

def generate_ct(game_name, targets):
    """Generate the full .CT file."""
    # Group targets by category
    categories = {}
    for t in targets:
        if t.category not in categories:
            categories[t.category] = []
        categories[t.category].append(t)

    entries = ""
    cheat_id = 100
    group_id = 10

    for cat, cat_targets in categories.items():
        cat_desc = cat_targets[0].description.split(":")[0] if cat_targets else cat.title()
        entries += f'''
        <CheatEntry>
          <ID>{group_id}</ID>
          <Description>"--- {xml_escape(cat_desc)} ---"</Description>
          <GroupHeader>1</GroupHeader>
          <Color>008000</Color>
          <CheatEntries>'''

        for t in cat_targets:
            entry = gen_cheat_entry(cheat_id, t)
            if entry:
                entries += "\n" + entry
            cheat_id += 1

        entries += '''
          </CheatEntries>
        </CheatEntry>
'''
        group_id += 10

    ct = f'''<?xml version="1.0" encoding="utf-8"?>
<CheatTable>
  <CheatTableName>{xml_escape(game_name)} - Auto Generated</CheatTableName>
  <CheatEntries>
    <CheatEntry>
      <ID>0</ID>
      <Description>"{xml_escape(game_name)} - Auto Generated Cheats"</Description>
      <GroupHeader>1</GroupHeader>
      <Color>FF0000</Color>
      <CheatEntries>{entries}
      </CheatEntries>
    </CheatEntry>
  </CheatEntries>
</CheatTable>
'''
    return ct

# ============================================================
# MAIN
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="Auto Trainer Generator for Unity IL2CPP Games")
    parser.add_argument("dump_cs", help="Path to dump.cs from Il2CppDumper")
    parser.add_argument("--output", "-o", help="Output .CT file path")
    parser.add_argument("--game-name", "-n", default="Game", help="Game name for the cheat table")
    parser.add_argument("--patterns", "-p", help="Path to cheat_patterns.json")
    parser.add_argument("--min-score", type=int, default=5, help="Minimum score for a cheat target")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    if not os.path.exists(args.dump_cs):
        print(f"Error: {args.dump_cs} not found")
        sys.exit(1)

    print(f"=== Auto Trainer Generator ===")
    print(f"Input: {args.dump_cs}")

    # Parse
    print("\nParsing dump.cs...")
    classes = parse_dump_cs(args.dump_cs)
    print(f"Parsed {len(classes)} classes")

    # Load patterns
    patterns = load_patterns(args.patterns)

    # Detect
    targets, singletons, player_class = detect_cheats(classes, patterns)
    print(f"\nFound {len(targets)} cheat targets")

    if not targets:
        print("No cheat targets found!")
        sys.exit(0)

    # Generate
    output = args.output or args.dump_cs.replace("dump.cs", f"{args.game_name}_auto.CT")
    print(f"\nGenerating CT: {output}")
    ct = generate_ct(args.game_name, targets)

    with open(output, "w", encoding="utf-8") as f:
        f.write(ct)

    print(f"Done! {len(targets)} cheats written to {output}")

    # Summary
    print(f"\n=== Summary ===")
    for cat in set(t.category for t in targets):
        cat_targets = [t for t in targets if t.category == cat]
        print(f"  {cat}: {len(cat_targets)} cheats")

if __name__ == "__main__":
    main()
