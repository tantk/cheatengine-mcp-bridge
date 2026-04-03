# Il2CppDumper Reference

Key details extracted from Perfare's docs, GitHub wiki, and community experience.

## Output Files

### script.json
- **Addresses are decimal integers** (RVAs from image base), NOT hex
- 5 sections: `ScriptMethod` (~95K), `ScriptString` (~19K), `ScriptMetadata` (~7K), `ScriptMetadataMethod` (~17K), `Addresses` (~69K)
- `ScriptMethod` entries: `Address` (decimal RVA), `Name` (Class$$Method), `Signature` (C-style), `TypeSignature` (type chars)
- **Duplicate names are common** — 4,295 names appear more than once (method overloads). Name-based lookup is unreliable without also checking address.
- **Shared addresses for generics** — 3,670 addresses map to multiple method names (IL2CPP generic sharing for reference types). This is correct behavior.
- Name encoding: `<` becomes `\u003C`, `>` becomes `\u003E` in JSON

### dump.cs
- Field offset comments (`// 0x18`) are **object instance offsets**, not binary addresses
- Method offset comments (`// RVA: 0xABCDEF`) ARE relative to image base
- Empty method bodies `{ }` don't mean the method does nothing — Il2CppDumper can't recover native code
- Generic method instantiations appear as **comments only**, not full declarations

### il2cpp.h
- Uses C++ inheritance syntax — **NOT compatible with Ghidra** without conversion
- Run `il2cpp_header_to_ghidra.py` to generate `il2cpp_ghidra.h` first
- Missing primitive types (`uint32_t` etc.) that Ghidra requires
- Alignment issues after conversion due to empty base optimization differences

### stringliteral.json
- **Addresses can be wrong** (known issue #594). Cross-reference with `ScriptString` section in script.json instead.

## Known Limitations

### What Il2CppDumper CANNOT do
- No method body recovery (only metadata and signatures)
- No local variable names (lost during IL2CPP compilation)
- No control flow / source comments
- No compiler-inlined methods (no standalone entry point exists)
- Cannot handle encrypted/obfuscated `global-metadata.dat`
- Complex custom attributes may be incomplete

### The Method Overload Problem

`il2cpp_class_get_method_from_name(klass, name, paramCount)` matches by **name + parameter count only**, not types. When two overloads have same name and param count but different types, it returns whichever it finds first.

**Example:** `ForceData$$CostResource` has three 2-param overloads:
- `CostResource(List<float>, bool)`
- `CostResource(List<ResourceData>, bool)`
- `CostResource(ResourceData, bool)`

Calling with paramCount=2 returns only ONE of these non-deterministically.

**Safe alternative — iterator pattern:**
```c
void* iter = NULL;
const MethodInfo* method;
while ((method = il2cpp_class_get_methods(klass, &iter))) {
    if (strcmp(il2cpp_method_get_name(method), "CostResource") == 0) {
        // Check parameter types with il2cpp_method_get_param
        // to find the specific overload you need
    }
}
```

### Generic Method Sharing
- IL2CPP shares code for all reference-type instantiations (`List<string>.Add()` and `List<object>.Add()` = same native function)
- Only value-type instantiations (`List<int>`) get separate compiled code
- When building name_index.json, later entries overwrite earlier ones silently — keep first or most specific name

## Ghidra Integration

### Correct workflow order
1. Run Il2CppDumper
2. Convert header: `python il2cpp_header_to_ghidra.py`
3. Import binary into Ghidra
4. **IMPORTANT: Import script.json names BEFORE analysis** — use `-preScript` to create function entries at all known addresses. This gives Ghidra better starting information.
5. Parse C header (`il2cpp_ghidra.h`) if using struct script
6. Run auto-analysis
7. Export decompiled functions

### Current pipeline gap
Our pipeline skips step 4 — Ghidra analyzes without IL2CPP symbol information, then we resolve names post-hoc. Importing names as a preScript would:
- Create function entries at all 95K addresses (fixes 3,138 missing decomps)
- Give Ghidra proper function boundaries before analysis
- Improve decompilation quality (Ghidra uses names/types during decompilation)

### Known Ghidra issues
- `createFunction()` can silently fail in headless mode (issue #1765) — retry once as workaround
- Ghidra 12 requires PyGhidra, not Jython — add `#@runtime PyGhidra` or use Java scripts
- Running Parse C Code multiple times without clearing old types = exponentially slower
- Supply correct compilerID in headless mode or let auto-detection work (issue #5531)

## Common Pitfalls

- **Binary/metadata version mismatch** — using global-metadata.dat from one version with GameAssembly.dll from another produces silently wrong output
- **Output goes to CWD** — not the input file directory
- **DummyDll/ assemblies have no IL code** — loading them in a runtime will fail
- **`ForceIl2CppVersion` may be needed** for newer Unity versions

## Sources
- [Perfare/Il2CppDumper GitHub](https://github.com/Perfare/Il2CppDumper)
- [Il2CppDumper DeepWiki](https://deepwiki.com/Perfare/Il2CppDumper)
- [Ghidra Integration Guide (BadMagic100)](https://gist.github.com/BadMagic100/47096cbcf64ec0509cf75d48cfbdaea5)
- [Il2CppDumper Script Improved (NyaMisty)](https://gist.github.com/NyaMisty/b61d3bad2101be3697574fb89203bbe2)
- [il2cpp.h Ghidra compatibility issue #443](https://github.com/Perfare/Il2CppDumper/issues/443)
