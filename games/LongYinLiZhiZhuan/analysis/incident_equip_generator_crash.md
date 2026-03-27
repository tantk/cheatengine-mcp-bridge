# Incident Report: Equipment Generator (cmd=4) Crash/Timeout

## Date: 2026-03-27
## Status: RESOLVED

## Summary
hookCode cmd=4 (doGenEquip) consistently fails — either crashes the game or times out.
Books (cmd=2) and other item types work fine through the same hook.

## Symptoms
1. Click "Add Equip" → status shows "Generator timeout" after 3 seconds
2. Sometimes crashes the game entirely instead of timing out
3. cmdBuf becomes unreadable after crash (memory freed by dead process)
4. After restart + reconnect, same issue repeats

## Log Evidence
```
22:05:30 BTN AddEquip: type=Weapon item='[2] 钩爪' idx=2 rare=5 RVA=7A73C0
22:05:30 cmd4 GenEquip: RVA=7A73C0 idx=2 bossLv=5 rate=1.0
22:05:33 BTN AddEquip result: ok=false msg=Generator timeout

22:12:16 BTN AddEquip: type=Weapon item='[0] 手甲' idx=0 rare=5 RVA=7A73C0
22:12:16 cmd4 GenEquip: RVA=7A73C0 idx=0 bossLv=5 rate=1.0
22:12:20 BTN AddEquip result: ok=false msg=Generator timeout
```

Earlier in the session (before param swap fix, via MCP button click):
```
Generated: 劣质大剑 with 3 stats (bossLv=10, idx=10) — THIS WORKED
```

## cmdBuf State After Timeout
```
cmdBuf symbol registered but memory unreadable (readBytes returns nil)
pid=27464, process=LongYinLiZhiZhuan.exe (alive)
```
This means the game process is alive but the cmdBuf allocation is in freed/invalid memory.
Likely the hookCode itself crashed, which corrupted the stack or caused the Update function to stop running.

## What Works vs What Doesn't

### Works:
- cmd=1 (GetItem) — adding items to inventory ✓
- cmd=2 (CreateAndAdd) — books, materials ✓
- cmd=3 (AllocAndCtor) — object allocation ✓
- Equipment via template clone (addEquipment) — worked but no stats ✓
- First test via MCP: GenerateWeapon(idx=10, bossLv=10) → 劣质大剑 ✓

### Doesn't Work:
- cmd=4 (doGenEquip) — GenerateWeapon/Armor/etc consistently times out or crashes
- Tested: Weapon idx=0 (手甲), idx=2 (钩爪), idx=35 (软弓) — all fail
- Tested: Armor idx=0 (布甲) — also fails
- All with rare=5, rate=1.0

## hookCode Assembly (cmd=4)
```asm
doGenEquip:
  push rcx/rdx/r8/r9/r10/r11
  sub rsp,58
  mov rcx,[rbx+20]       ; GameController this (captured each frame)
  test rcx,rcx
  jz cmdError
  mov edx,[rbx+10]       ; param1 = bossLv (rarity, 0-5)
  mov r8d,[rbx+14]       ; param2 = weapon DB index
  mov eax,[rbx+18]       ; float bits
  movd xmm2,eax          ; set xmm2 (for 2-param methods)
  movd xmm3,eax          ; set xmm3 (for 3-param methods)
  xor r9d,r9d            ; MethodInfo* = NULL
  mov qword ptr [rsp+20],0
  mov rax,[rbx+68]       ; generator function address
  call rax               ; ← CRASHES HERE
  test rax,rax
  jz cmdError
  mov [rbx+08],rax
  jmp cmdDone
```

## Possible Causes

### 1. Parameter mismatch
- The early MCP test with (idx=10, bossLv=10) worked
- But that was BEFORE the param swap fix — so actually edx=10(idx), r8=10(bossLv)
- After the swap fix: edx=bossLv(5), r8=idx(0/2)
- **The early success might have been with the WRONG param order that accidentally worked**
- Need to verify: does edx=idx, r8=bossLv work? (original order before swap)

### 2. Stack alignment
- hookCode does 6 pushes (48 bytes) + sub rsp,58 (88 bytes) = 136 bytes
- Before the call, RSP should be 16-byte aligned
- 136 bytes from original RSP... need to verify alignment
- If misaligned, the MOVAPS instructions in GenerateWeapon's prologue crash (requires 16-byte alignment)

### 3. GameController this pointer stale
- cmdBuf+0x20 is written every frame by the hookCode
- But if the hook isn't running (detached), the value is stale
- The heartbeat counter (cmdBuf+0x40) should verify this but wasn't checked

### 4. Generator function address wrong
- RVA=0x7A73C0 is GenerateWeapon(4 params) from snapshot
- Code pages might not be loaded (we saw all-zeros earlier in some tests)
- If the function address points to unmapped memory, the call crashes

### 5. MethodInfo* parameter
- We pass r9=0 and [rsp+20]=0 for the hidden MethodInfo* parameter
- Some IL2CPP methods actually USE the MethodInfo* (e.g., for generic method resolution)
- If GenerateWeapon needs a valid MethodInfo*, passing NULL crashes

## Investigation Plan

### Step 1: Verify param order
Try BOTH orders:
- A: edx=5(rare), r8=0(idx) — current (swap)
- B: edx=0(idx), r8=5(rare) — original (pre-swap)
The first MCP test used B and worked.

### Step 2: Check stack alignment
Count exact bytes: entry RSP is 16-byte aligned (called from Update).
After hookCode entry: push rax(8) + push rbx(8) = RSP-16 (aligned)
At doGenEquip: push rcx..r11 (6*8=48) + sub rsp,58 (88) = 136 more
Total: 16+136 = 152 from entry. 152 mod 16 = 8. **RSP is MISALIGNED by 8!**
This causes MOVAPS in GenerateWeapon to crash.

**FIX: Change `sub rsp,58` to `sub rsp,48` or add one more push.**

### Step 3: Verify function address
Read bytes at GA+0x7A73C0 — if all zeros, the page isn't loaded.
Need to trigger page load by accessing nearby code first.

### Step 4: Test with valid MethodInfo*
Get the actual MethodInfo* for GenerateWeapon via il2cpp_class_get_method_from_name
and pass it instead of NULL.

## Priority Fix
**Stack alignment (Step 2) is most likely the cause.**
MOVAPS requires 16-byte aligned RSP. Our hookCode has 6 pushes (48 bytes) +
sub rsp,58 = total 136. RSP enters doGenEquip misaligned by 8 from the
noCmd push/pop of rax+rbx (16 bytes). The CALL instruction pushes return
address (8 bytes), making RSP aligned for the callee. But we need to verify
the exact alignment chain.

Actually: at hookCode entry, RSP has the return address from the JMP
(no CALL, so no extra push). Then push rax(8) + push rbx(8) = -16.
At doGenEquip: 6 more pushes (-48) + sub rsp,58 (-88).
Total: -16 - 48 - 88 = -152 from entry RSP.
Before our CALL rax: RSP = entry_RSP - 152.
CALL pushes return addr: RSP = entry_RSP - 160.
Callee sees RSP = entry_RSP - 160.
If entry_RSP was 16-aligned: 160 mod 16 = 0 → aligned ✓
If entry_RSP was 8-misaligned: 168 mod 16 = 8 → misaligned ✗

Need to verify what RSP is when hookCode runs. If Update() was called
normally, RSP at hookCode entry = Update's RSP after CALL = 8-misaligned
(return address pushed). So: entry = X+8 (misaligned).
X+8 - 152 = X - 144. CALL pushes: X - 152. 152 mod 16 = 8 → MISALIGNED!

**This is the bug. sub rsp,58 should be sub rsp,50 to fix alignment.**
Or change 6 pushes to 7 pushes (add a dummy push).
