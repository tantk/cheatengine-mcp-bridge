# Ghidra + IL2CPP Workflow: Key Learnings

Best practices extracted from community guides, Ghidra issues, and our own pipeline experience.

## Correct End-to-End Workflow

The order matters. Getting this wrong wastes hours or produces incomplete results.

```
1. Il2CppDumper          → script.json, dump.cs, il2cpp.h
2. Convert header        → il2cpp_ghidra.h (mandatory for Ghidra)
3. Import DLL to Ghidra  → create project
4. PRE-SCRIPT: Import    → create functions + labels at all script.json addresses
   script.json names       (BEFORE analysis, not after!)
5. Ghidra analysis       → ~24 min headless
6. POST-SCRIPT: Export   → parallel decompile, 8 threads
7. Name resolution       → apply names from name_index + manual_names
8. Stub enrichment       → annotate inlined stubs with caller context
9. GitNexus index        → build knowledge graph
```

### Why step 4 matters (our pipeline currently skips this)
Our current pipeline imports the DLL, runs analysis, exports decomps, then resolves names post-hoc. This means Ghidra analyzes blind — no IL2CPP symbol information. Consequences:
- **3,138 functions never exported** — Ghidra didn't recognize them as functions
- Decompilation quality may be lower (Ghidra uses function names/boundaries to improve output)
- Function boundaries may be wrong (Ghidra guesses without script.json's `Addresses` list)

**Fix:** Write a Java preScript that reads script.json and calls `createFunction()` + `createLabel()` at all addresses before analysis begins.

## Why Ghidra Misses Functions

| Cause | Impact | Fix |
|---|---|---|
| Bytes not recognized as code | Tiny thunks, optimized prologues stay undefined | Import script.json addresses as functions via preScript |
| `createFunction()` silently fails in headless | Known Ghidra issue #1765 | Retry once on failure |
| Bytes classified as data | Jump tables, vtables block function creation | `clearListing()` → `disassemble()` → `createFunction()` |
| Compiler-inlined methods | No entry point exists | Can't fix — this is inherent to compilation |
| Functions outside Ghidra's heuristic range | Aggressive Instruction Finder disabled by default | Import known addresses from script.json instead |

## Ghidra Settings for IL2CPP

### Mandatory
- `MAXMEM=16G` in `launch.properties` (default 2GB is too small for 33MB binaries)
- `JAVA_HOME_OVERRIDE` pointing to JDK 21+

### Recommended
- Decompiler timeout: increase from 30s to 120s for complex functions (state machines, coroutines)
- For headless: supply BOTH `languageID` AND `compilerID`, or supply NEITHER (Ghidra issue #5531 — headless defaults to wrong calling convention if only one is specified)
- For Windows x64 IL2CPP: `x86:LE:64:default` with `windows` compiler

### Avoid
- Aggressive Instruction Finder — unreliable, creates false functions. Import script.json addresses instead.
- Running Parse C Code multiple times without clearing old types — exponentially slower each time

## Handling Generic Methods

- IL2CPP shares code for reference-type generics (`List<string>.Add()` = `List<object>.Add()`)
- Multiple script.json entries point to same address — name_index.json builder must handle duplicates
- Shared methods receive `MethodInfo*` as hidden last parameter containing type arguments
- When building name_index: keep first/most-specific name, or use the non-generic base name

## Handling Thunks

- Adjustor thunks: adjust `this` pointer for virtual methods in multiple inheritance
- Method.Invoke thunks: wrappers for reflection calls
- Keep in export (small, fast to decompile) but flag separately in name resolution
- Our thunk detection (technique 3 in coverage-maximizer) identifies these by code pattern

## Handling Compiler Inlining

- ~3,500 IL2CPP methods are inlined (< 200 byte stubs)
- The stub at the method's address is a leftover entry point
- Real logic is expanded at call sites
- Cannot be fixed by decompilation — this is inherent to compilation
- Our stub enrichment step annotates stubs with caller locations

## Comparison: Ghidra vs Other Tools

| Tool | Speed | IL2CPP Support | Cost |
|---|---|---|---|
| Ghidra 12 | ~24 min analysis + ~20 min export (8 threads) | Good with scripts, misses ~5% functions | Free |
| IDA Pro | 2-4x faster, better decompilation quality | Better maintained scripts (NyaMisty) | $1,500 |
| Binary Ninja | 3-5x faster, native parallelism | No dedicated IL2CPP plugins | $299 |
| Cpp2IL | Instant (metadata only) | C# stubs + ISIL disasm, no full decomp | Free |
| Il2CppInspector | N/A (metadata tool) | Best generic method handling | Free (abandoned, ReduxFork active) |

## Pipeline Improvements (TODO)

### High priority
1. **Write Java preScript** to import script.json addresses before Ghidra analysis — fixes 3,138 missing functions
2. **Replace `$$` with `__`** in resolved names — fixes GitNexus CALLS edge detection (~200K edges instead of ~46K)
3. **Handle `createFunction()` retry** in preScript for headless failures

### Medium priority
4. Handle duplicate names in name_index.json builder (generic sharing)
5. Track `DecompInterface` reuse in ExportDecompsParallel.java (currently creates new process per task)

### Low priority
6. Import `il2cpp_ghidra.h` struct types for better decompilation quality
7. Increase decompiler timeout for complex functions

## Sources
- [Decompiling IL2CPP with Ghidra (BadMagic100)](https://gist.github.com/BadMagic100/47096cbcf64ec0509cf75d48cfbdaea5)
- [Unity IL2CPP RE Guide (toasterparty)](https://gist.github.com/toasterparty/57a50eddc2203fc6ca24cf96789f5dd2)
- [IL2CPP Internals: Generic Sharing (Unity Blog)](https://blog.unity.com/engine-platform/il2cpp-internals-generic-sharing-implementation)
- [Analysis of Large Binaries in Ghidra (kiwidog)](https://kiwidog.me/2021/07/analysis-of-large-binaries-and-games-in-ghidra-sre/)
- [Ghidra issue #1765: createFunction headless failure](https://github.com/NationalSecurityAgency/ghidra/issues/1765)
- [Ghidra issue #5531: headless vs GUI differences](https://github.com/NationalSecurityAgency/ghidra/issues/5531)
- [Ghidra issue #8321: .pdata function creation](https://github.com/NationalSecurityAgency/ghidra/issues/8321)
