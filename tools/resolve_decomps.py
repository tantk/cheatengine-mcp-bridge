"""Batch-resolve FUN_ references in all decompiled .c files.

Reads from source decomps dir, writes resolved versions to output dir.
Also renames files from FUN_XXXX.c to ClassName$$Method.c where possible.

Usage:
  python tools/resolve_decomps.py [--dry-run]
"""
import json
import re
import os
import sys
import time

NAME_INDEX = "C:/dev/gameanalysis/game_b_decomps/name_index.json"
MANUAL_NAMES = os.path.join(os.path.dirname(__file__), "manual_names.json")
SOURCE_DIR = "C:/dev/gameanalysis/game_b_decomps/decomps"
OUTPUT_DIR = "C:/dev/gameanalysis/game_b_decomps/decomps_resolved"

def main():
    dry_run = '--dry-run' in sys.argv

    print("Loading name index...")
    t0 = time.time()
    with open(NAME_INDEX, 'r') as f:
        raw = json.load(f)

    # Build addr -> name lookup and filename -> name lookup
    addr_to_name = {}
    file_to_name = {}
    for key, val in raw.items():
        name = val['name']
        m = re.match(r'FUN_([0-9a-fA-F]+)', key)
        if m:
            addr = m.group(1).lower()
            addr_to_name[addr] = name
            file_to_name[key] = name

    # Load manual names (override/supplement name_index)
    manual_count = 0
    if os.path.exists(MANUAL_NAMES):
        with open(MANUAL_NAMES, 'r') as f:
            manual = json.load(f)
        for key, name in manual.items():
            if key.startswith('_'):
                continue  # skip metadata keys like _comment, _updated
            m = re.match(r'FUN_([0-9a-fA-F]+)', key)
            if m:
                addr = m.group(1).lower()
                if addr not in addr_to_name:
                    manual_count += 1
                addr_to_name[addr] = name
                file_to_name[f"{key}-{m.group(1)}.c"] = name

    print(f"Loaded {len(addr_to_name)} mappings ({manual_count} from manual_names) in {time.time()-t0:.1f}s")

    # Compile regex for FUN_ references
    fun_pattern = re.compile(r'FUN_([0-9a-fA-F]+)')

    def resolve_content(text):
        def replacer(m):
            addr = m.group(1).lower()
            name = addr_to_name.get(addr)
            if name:
                # Sanitize name for C identifier context
                # NOTE: Do NOT insert /*FUN_xxx*/ between name and (
                # because GitNexus C parser needs identifier( to detect calls.
                safe = name.replace('<', '_').replace('>', '_').replace(',', '_').replace('.', '_').replace('$$', '__')
                return safe
            return m.group(0)
        return fun_pattern.sub(replacer, text)

    if not dry_run:
        os.makedirs(OUTPUT_DIR, exist_ok=True)

    files = os.listdir(SOURCE_DIR)
    total = len(files)
    resolved_count = 0
    skipped = 0
    t1 = time.time()

    for i, fname in enumerate(files):
        if not fname.endswith('.c'):
            skipped += 1
            continue

        src = os.path.join(SOURCE_DIR, fname)
        with open(src, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()

        new_content = resolve_content(content)

        # Determine output filename
        base = fname.replace('.c', '')
        new_name = file_to_name.get(fname)
        if new_name:
            # Sanitize for filesystem and GitNexus parser (dots break C identifier parsing)
            safe_name = new_name.replace('<', '[').replace('>', ']').replace(':', '_')
            safe_name = safe_name.replace('/', '_').replace('\\', '_').replace('?', '_')
            safe_name = safe_name.replace('*', '_').replace('"', '_').replace('|', '_')
            safe_name = safe_name.replace('.', '_').replace('$$', '__')
            out_fname = f"{safe_name}.c"
        else:
            out_fname = fname

        if not dry_run:
            out_path = os.path.join(OUTPUT_DIR, out_fname)
            with open(out_path, 'w', encoding='utf-8') as f:
                f.write(new_content)

        resolved_count += 1
        if (i + 1) % 5000 == 0:
            elapsed = time.time() - t1
            rate = (i + 1) / elapsed
            eta = (total - i - 1) / rate
            print(f"  {i+1}/{total} ({rate:.0f} files/s, ETA {eta:.0f}s)")

    elapsed = time.time() - t1
    print(f"\nDone: {resolved_count} files resolved, {skipped} skipped in {elapsed:.1f}s")
    if not dry_run:
        print(f"Output: {OUTPUT_DIR}")
    else:
        print("(dry run — no files written)")

if __name__ == '__main__':
    main()
