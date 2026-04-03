# Pipeline Research Checklist

Read these references BEFORE running or modifying the decompilation pipeline. Each item links to a specific issue we've encountered — reading these first would have prevented hours of debugging.

## Before Running Il2CppDumper

- [ ] **Verify binary/metadata version match** — using global-metadata.dat from one game version with GameAssembly.dll from another produces silently wrong output. Always copy both files from the same game install at the same time.
  - Reference: `docs/reverse-engineering/il2cppdumper-reference.md` → Common Pitfalls

- [ ] **Understand script.json address format** — addresses are decimal integers (RVAs), not hex. Add image base (0x180000000) to get virtual addresses.
  - Reference: `docs/reverse-engineering/il2cppdumper-reference.md` → Output Files

- [ ] **Plan for method overloads** — `il2cpp_class_get_method_from_name` returns only ONE match per param count. Use the iterator pattern (`il2cpp_class_get_methods`) when dealing with overloaded methods.
  - Reference: `docs/reverse-engineering/il2cppdumper-reference.md` → The Method Overload Problem

- [ ] **Plan for generic sharing** — multiple method names can map to the same address. Decide how to handle duplicates in name_index.json (keep first, keep most specific, or concatenate).
  - Reference: `docs/reverse-engineering/il2cppdumper-reference.md` → Generic Method Sharing

## Before Running Ghidra

- [ ] **Convert il2cpp.h first** — raw header uses C++ syntax that Ghidra rejects. Run `il2cpp_header_to_ghidra.py`.
  - Reference: `docs/reverse-engineering/il2cppdumper-reference.md` → il2cpp.h

- [ ] **Import script.json names BEFORE analysis** — write a preScript that creates function entries at all known addresses. This fixes missing functions and improves decompilation quality. Our current pipeline skips this step, causing 3,138 missing decomps.
  - Reference: `docs/reverse-engineering/ghidra-il2cpp-workflow.md` → Why step 4 matters

- [ ] **Set MAXMEM=16G** — default 2GB causes GC pauses on 33MB+ binaries.
  - Reference: `docs/reverse-engineering/ghidra-il2cpp-workflow.md` → Ghidra Settings

- [ ] **Handle createFunction() retry** — headless mode silently fails on some addresses (Ghidra issue #1765). Retry once.
  - Reference: `docs/reverse-engineering/ghidra-il2cpp-workflow.md` → Why Ghidra Misses Functions

- [ ] **Use correct compilerID or omit both** — supplying languageID without compilerID in headless mode causes wrong calling conventions (Ghidra issue #5531).
  - Reference: `docs/reverse-engineering/ghidra-il2cpp-workflow.md` → Ghidra Settings

## Before Name Resolution

- [ ] **Use valid C identifiers only** — resolved names must be parseable by tree-sitter C. Replace dots (`.`) with underscores. Do NOT insert `/*comments*/` between function name and `(`. Either use `$$` or `__` as class/method separator.
  - Reference: `docs/reverse-engineering/treesitter-c-parser-reference.md` → Name sanitization rules

- [ ] **Character safety table:**
  | Safe | Unsafe |
  |---|---|
  | `a-z A-Z 0-9 _ $` | `. < > , - :: @ # ! %` |
  - Reference: `docs/reverse-engineering/treesitter-c-parser-reference.md` → Identifier Rules

- [ ] **Consider `__` over `$$`** — `$$` works in tree-sitter-c but may fail in other C tools. `__` is universally valid. Changing to `__` would fix GitNexus CALLS edge detection (currently ~46K edges, expected ~200K).
  - Reference: `docs/reverse-engineering/treesitter-c-parser-reference.md` → Recommendations

## Before GitNexus Indexing

- [ ] **Run sanity check after indexing** — verify node count matches file count (>90%) and CALLS edges are in expected range (3-5 per function average).
  - Reference: coverage-maximizer skill → Sanity Check After Indexing

- [ ] **Check for parser failures** — if nodes << files, check for dots in names or invalid C syntax in function signatures.

## Before Using the Call Graph

- [ ] **CALLS edges are incomplete** — GitNexus detects ~46K out of ~200K expected calls due to `$$` separator. Always cross-verify with grep on decomp files when the graph returns empty.
  - Reference: `memory/project_gitnexus_limitations.md`

- [ ] **Inlined functions have empty call graphs** — ~3,500 stubs have no outgoing CALLS. If a method's decomp is trivially small, check callers for the inlined logic.
  - Reference: `docs/reverse-engineering/inline-functions-guide.md`

- [ ] **Use decomps for analysis, not CE disassembly** — we have 74K resolved decomps + dump.cs. Never use `mcp__cheatengine__disassemble` for code understanding.
  - Reference: `memory/feedback_use_decomps_not_disasm.md`

## Before Modifying the CT

- [ ] **Test with fresh CE attach** — `_il2cpp_init()` race conditions only appear on first use after attach. Close CE, reopen, reattach, test.
  - Reference: ct-updater skill → Step 6

- [ ] **Use iterator for overloaded methods** — `il2cpp_class_get_method_from_name` only returns first match per param count.
  - Reference: NoCost fix commit `16b61fc`

- [ ] **`ensure()` refreshes stale state** — if a class had `static=0` during init, ensure() re-reads it. But extra fields (like `skillOff`, `tagBaseOff`) must be passed explicitly.
  - Reference: ensure() fix commit `e0b81f4`
