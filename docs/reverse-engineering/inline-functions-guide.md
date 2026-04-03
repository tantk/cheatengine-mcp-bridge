# Inline Functions in Reverse Engineering

A practical guide for identifying, analyzing, and recovering inlined functions in compiled binaries. Written for CTF competitors and game reverse engineers.

## What is Function Inlining?

When a compiler decides a function is small or frequently called, it copies the function's body directly into every call site instead of generating a CALL instruction. The original function may still exist as a stub entry point, or it may be eliminated entirely.

```
Source code:                    Compiled (inlined):
                                
int add(int a, int b) {         caller_function:
  return a + b;                   ; add() was here, now it's just:
}                                 add eax, ebx
                                  ; continues with caller's logic
void caller() {
  int x = add(3, 5);
}
```

The result: the binary has no `add` function. Its logic is fused into `caller`. The decompiler shows `caller` as one big function with the add logic embedded.

## Why Compilers Inline

Understanding *why* helps predict *what* gets inlined:

| Trigger | Description | Common in |
|---|---|---|
| Small body | < 10-20 instructions | Getters, setters, wrappers |
| `__forceinline` / `inline` | Developer requested | C++ headers, template code |
| Link-time optimization (LTO) | Compiler sees across translation units | Release builds |
| Profile-guided (PGO) | Hot functions inlined based on profiling | Game engines, browsers |
| Template instantiation | C++ templates generate per-type copies | STL, game ECS frameworks |
| IL2CPP AOT | C# → C++ → native, aggressive optimization | Unity games |

### What does NOT get inlined

- Virtual/polymorphic methods (can't resolve at compile time)
- Recursive functions (would cause infinite expansion)
- Functions with `try/catch` blocks (exception handling tables prevent inlining in many compilers)
- Very large functions (compiler heuristic says cost > benefit)
- Functions whose address is taken (`&func` forces a callable entry point to exist)

## Recognizing Inlined Code

### Sign 1: Stub functions

A function that metadata says should have real logic, but the decomp is trivially simple:

```c
// script.json says: ItemData$$GetHorseMaxWeightAdd at 0xC4E570
// dump.cs says: public float GetHorseMaxWeightAdd() { }
// But the decomp shows:
void FUN_180c4e570(longlong param_1) {
    if (*(int *)(param_1 + 0x18) != 0) return;
    return;
}
```

This is a leftover entry point. The real logic is at the call sites.

### Sign 2: Duplicated code blocks

If you see the same pattern of instructions at multiple unrelated locations:

```
Function A at 0x1000:     Function B at 0x5000:
  mov eax, [rcx+34h]       mov eax, [rcx+34h]      <- same code
  cvtsi2ss xmm0, eax       cvtsi2ss xmm0, eax      <- same code  
  addss xmm0, xmm1         addss xmm0, xmm1        <- same code
  ...continues A logic      ...continues B logic
```

This is the same function inlined at two call sites. The pattern `[rcx+34h]` → float conversion → add is the inlined function body.

### Sign 3: Unexpectedly large functions

A function that should be 50 lines has 1700 lines. It "does everything." In reality, it calls many small methods that all got inlined, inflating the code size:

- `CountHeroData` (our real example): 1700 lines in decomp, contains inlined logic from `GetHorseMaxWeightAdd`, `HorseData.Speed`, `HorseData.Power`, and dozens of other small methods

### Sign 4: Register-heavy code without function prologue

Inlined code doesn't have its own `push rbp; mov rbp, rsp` prologue. If you see a block of logic that manipulates data without any stack frame setup, sandwiched between other code, it may be inlined:

```asm
; caller's code
mov rcx, [rdi+208h]       ; load horse item pointer
; --- inlined GetHorseMaxWeightAdd starts here ---
mov eax, [rcx+18h]        ; check subtype
test eax, eax
jnz .skip
mov rax, [rcx+88h]        ; load horse data
movss xmm0, [rax+34h]     ; read maxWeightAdd field
; --- inlined GetHorseMaxWeightAdd ends here ---
addss xmm1, xmm0          ; caller continues
```

No CALL instruction. No RET. Just raw logic inserted into the caller.

### Sign 5: Metadata says it exists, but cross-references are wrong

In IDA/Ghidra, if a function has:
- Very few or zero cross-references pointing TO it
- But metadata (symbols, RTTI, IL2CPP tables) says it exists and is used heavily

The function is being inlined at call sites instead of being called normally. The few xrefs might be from cold/error paths where the compiler didn't inline.

## Techniques for Finding Inlined Code

### Technique 1: Metadata-guided (IL2CPP, .NET, Java)

**When you have metadata** (global-metadata.dat, PDB, DWARF):

1. Metadata tells you function X exists at address Y
2. Decomp at Y is a stub → compiler inlined the real logic
3. Find who calls address Y: `grep "FUN_Y" decomps/*.c`
4. The caller's decomp contains the real inlined logic

This is the easiest case. IL2CPP games always have metadata, so you always know what functions should exist.

```bash
# Example: find callers of GetHorseMaxWeightAdd
grep -rn "GetHorseMaxWeightAdd\|FUN_180c4e570" decomps_resolved/*.c
# Result: GameController$$CountHeroData.c contains the inlined logic
```

### Technique 2: String and constant tracing

**When you have no metadata** (stripped binary, CTF challenge):

1. Identify unique strings or constants the target function should use
2. Search the binary for those constants
3. Each hit is a potential inline site

```bash
# Example: looking for an inlined crypto function
# You know it uses the SHA-256 initial hash values
# Search for: 0x6a09e667 (SHA-256 H0)
grep -r "6a09e667" decomps/*.c
# Each match is either the original function or an inline site
```

**Constants to look for:**
- Crypto: hash initial values, S-box entries, round constants
- Math: pi, e, phi, common polynomial coefficients  
- Protocol: magic bytes, version numbers, header signatures
- Error: error code numbers, status values

### Technique 3: Binary diffing (debug vs release)

If you can obtain two builds of the same binary:

1. Debug build: functions are NOT inlined (compiler respects function boundaries)
2. Release build: functions ARE inlined

Diff the two in BinDiff or Diaphora:
- Functions present in debug but missing in release → inlined
- Functions in release that are much larger than in debug → contain inlined code

```bash
# Using BinDiff
bindiff debug.bndb release.bndb
# Look for: "unmatched functions" in debug = inlined in release
```

### Technique 4: Pattern matching across call sites

If the same small code pattern appears at N different locations:

1. Extract the byte pattern of the suspected inlined code
2. AOB scan the binary for all occurrences
3. Each hit is an inline site
4. The pattern IS the inlined function

```python
# Pseudocode: find repeated code patterns
from collections import Counter

patterns = Counter()
for func in all_functions:
    # Normalize: replace addresses/immediates with wildcards
    normalized = normalize(func.bytes)
    # Extract 16-byte sliding windows
    for i in range(len(normalized) - 16):
        patterns[normalized[i:i+16]] += 1

# Patterns appearing 5+ times are likely inlined functions
for pat, count in patterns.most_common(50):
    if count >= 5:
        print(f"Probable inline: {pat} ({count} sites)")
```

### Technique 5: DWARF debug info recovery

Even stripped binaries sometimes retain partial DWARF info. Inlined functions are tagged:

```bash
# Check for inlining info in DWARF
readelf --debug-dump=info binary | grep -A5 "DW_TAG_inlined_subroutine"
# Shows: original function name, source file, line number

# Or in Ghidra:
# Window > DWARF Info > look for DW_AT_inline entries
```

DWARF `DW_TAG_inlined_subroutine` entries contain:
- `DW_AT_abstract_origin`: points to the original function definition
- `DW_AT_low_pc` / `DW_AT_high_pc`: address range of inlined code
- `DW_AT_call_file` / `DW_AT_call_line`: where the inline was called from

### Technique 6: Compiler-specific heuristics

Different compilers leave different fingerprints:

**MSVC (Windows/Xbox):**
- Uses `__declspec(noinline)` attribute — search for functions that have it (these were NOT inlined, everything else might be)
- Inlined functions often keep `__security_cookie` checks at inline boundaries
- PDB files (if available) have full inline info in `S_INLINESITE` records

**GCC/Clang (Linux/macOS/iOS):**
- `-O2` and above enables inlining; `-O0` disables
- `__attribute__((always_inline))` forces inlining
- LTO (`.lto_` sections) means cross-module inlining happened
- Clang's `-Rpass=inline` output (if build logs are available) lists every inline decision

**IL2CPP (Unity):**
- C# methods are compiled to C++, then to native
- Small property getters (get_X, set_X) are almost always inlined
- Virtual method calls are NEVER inlined (vtable dispatch)
- Generic method instantiations create separate native functions per type

### Technique 7: Data breakpoints to find writers

When static analysis fails, use runtime:

1. Set a hardware write breakpoint on the target data (the field the function should modify)
2. Trigger the game action that should call the function
3. The breakpoint fires inside the CALLER (since the code is inlined there)
4. The instruction pointer shows exactly where the inlined code is

```
# In Cheat Engine:
debug_setBreakpoint(address_of_field, bptWrite, 4)
# Trigger game action
# Check RIP when breakpoint fires → that's the inlined code location
```

This works even when you have zero metadata. The data knows who writes to it.

### Technique 8: Reconstructing inlined functions from fragments

Once you've found multiple inline sites of the same function:

1. Extract the common code from each site
2. Align the sequences (they may differ slightly due to register allocation)
3. The intersection is the original function body
4. Create a pseudo-function in your notes / IDA database

```
Site 1:                    Site 2:                    Reconstructed:
mov eax, [rcx+34h]        mov eax, [rdx+34h]         load field at +34h
cvtsi2ss xmm0, eax        cvtsi2ss xmm1, eax         convert to float
addss xmm0, [rsp+20h]     addss xmm1, [rsp+40h]      add base weight
                                                       return float result
```

The register names differ (rcx vs rdx, xmm0 vs xmm1) but the structure is identical.

## IL2CPP-Specific Inlining

Unity IL2CPP has unique characteristics worth documenting separately.

### What IL2CPP aggressively inlines

| Method type | Inlined? | Example |
|---|---|---|
| Property getters (`get_X`) | Almost always | `get_Count`, `get_Item` |
| Property setters (`set_X`) | Almost always | `set_position`, `set_enabled` |
| Simple field accessors | Always | Reading `this.field` |
| Small utility methods | Usually | `Clamp`, `Min`, `Max` |
| Null checks | Always | `il2cpp_codegen_raise_null_reference` |
| Type checks | Usually | `IsInst`, class init guards |

### What IL2CPP never inlines

| Method type | Inlined? | Why |
|---|---|---|
| Virtual methods | Never | Vtable dispatch can't be resolved at compile time |
| Interface methods | Never | Same reason |
| Methods with `try/catch` | Never | Exception table complexity |
| Recursive methods | Never | Infinite expansion |
| Very large methods (>100 IL instructions) | Rarely | Cost exceeds benefit |

### IL2CPP metadata as an advantage

Unlike stripped C++ binaries, IL2CPP always preserves:
- `global-metadata.dat`: every class, method, field name and offset
- `script.json` (from Il2CppDumper): every method's address
- `dump.cs`: full C# class definitions

This means you can always:
1. Know a function SHOULD exist at address X
2. Detect that the decomp at X is a stub (inlined)
3. Find the real code by searching callers
4. Know the expected return type and parameters from dump.cs

### The "stub + inline" pattern

IL2CPP typically generates BOTH:
1. A standalone entry point (the stub) — used for reflection, delegate calls, and cold paths
2. Inlined code at hot call sites — used for normal execution

The stub exists because C# allows calling methods via reflection (`MethodInfo.Invoke`), which needs a callable address. The inlined version exists for performance. Both coexist.

```
Address 0xC4E570 (stub):         Address 0x77B2F0 (call site, inlined):
  check subtype                    load horse data
  return                           read maxWeightAdd at +0x34
                                   convert to float
                                   add to base weight
                                   store result
```

## Tools Reference

### Static analysis

| Tool | Inline detection capability |
|---|---|
| **IDA Pro** | `DW_TAG_inlined_subroutine` parsing, Lumina for pattern matching, FLIRT signatures |
| **Ghidra** | DWARF parser, Function ID, "Create Function" for manual splitting |
| **Binary Ninja** | High IL tracks inline boundaries, medium IL folds them |
| **radare2/rizin** | `afi` shows function info, `axt` for xrefs, `pdf` for disassembly |
| **BinDiff/Diaphora** | Compare debug vs release to find inlined functions |

### Runtime analysis

| Tool | Technique |
|---|---|
| **Cheat Engine** | Data breakpoints (`debug_setBreakpoint`) to find writers |
| **x64dbg** | Hardware breakpoints, trace logging, conditional breakpoints |
| **Frida** | Stalker for code tracing, Interceptor for hooking |
| **DynamoRIO** | Instruction-level tracing to build execution flow |
| **Intel Pin** | Custom pintool to log memory writes and their instruction source |

### IL2CPP-specific

| Tool | What it does |
|---|---|
| **Il2CppDumper** | Extracts metadata → script.json, dump.cs |
| **Cpp2IL** | Reconstructs C# IL from native code (can detect some inlines) |
| **il2cpp-inspector** | Alternative metadata extractor with inline hints |
| **Ghidra + Il2CppDumper scripts** | Apply method names from metadata to decomp |

## CTF Checklist: Suspected Inlined Function

When you suspect code is inlined during a CTF:

- [ ] **Check for metadata** — PDB, DWARF, IL2CPP metadata, symbol tables
- [ ] **Check function size** — if the stub is tiny (< 50 bytes) but should be complex, it's inlined
- [ ] **Search for constants** — unique values the function should use
- [ ] **Check callers** — who references this address? Their code contains the inlined logic
- [ ] **Pattern scan** — if you found the code once, scan for the same pattern elsewhere
- [ ] **Data breakpoint** — set a write BP on the target data to catch the writer at runtime
- [ ] **Compare builds** — if debug/release available, diff to find what disappeared
- [ ] **Check DWARF** — even stripped binaries may retain `DW_TAG_inlined_subroutine`
- [ ] **Reconstruct** — extract common code from multiple inline sites to rebuild the function

## Real-World Example: GetHorseMaxWeightAdd

From our LongYinLiZhiZhuan IL2CPP analysis:

**The puzzle:**
- `dump.cs` says `public float GetHorseMaxWeightAdd()` exists
- `script.json` says it's at RVA `0xC4E570`
- The decomp at that address is a 48-byte stub that returns void
- But `CountHeroData` (a 1700-line function) has the actual weight calculation

**How we found it:**
1. `dump.cs` told us the method should return float (not void) → stub is wrong
2. `script.json` showed the next method starts at `0xC4E5A0` → only 48 bytes for GetHorseMaxWeightAdd
3. Searched for `GetHorseMaxWeightAdd` in all decomps → found it referenced in `CountHeroData`
4. Read `CountHeroData` decomp lines 1636-1654 → found the actual weight calculation inlined there
5. The standalone stub at `0xC4E570` is just a leftover entry point for non-inlined call paths

**The fix (for cheat development):**
Instead of hooking the tiny stub, we hooked `CheckHeroItemWeightBiggerThanMax` — the function that reads the final computed weight. This function was NOT inlined (it's a boolean check called from AI code), so hooking it works reliably.

**Lesson:** When the target function is inlined, find a non-inlined function in the same call chain that achieves your goal. Don't fight the compiler — work with what it gives you.
