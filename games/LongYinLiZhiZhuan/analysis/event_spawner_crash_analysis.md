# Event Spawner Crash Analysis (2026-03-31)

## Root Cause: EventData.Clone crashes when called from hookCode

Every path to spawning a world event goes through EventData.Clone (RVA 0x93A310):
- CreateWorldEvent(2-param, 0xB90370) → calls 6-param → calls Clone
- CreateWorldEvent(6-param, 0xB90BE0) → calls Clone directly
- Direct Clone via cmd=6 → crashes

Clone does BinaryFormatter serialization/deserialization (heavy .NET reflection).
This likely requires specific IL2CPP runtime state that isn't available when called from hookCode.

## What We Fixed Along The Way
1. WEC instance: `readQword(sf)` NOT `readQword(sf+0x8)` (sf+0x8 was a List, not WEC)
2. areaType=3 unhandled: force to 0 before calling
3. Dry-run validation: check WorldData/AreaList exist before calling

## Still Crashes After All Fixes
The crash is from Clone's internal BinaryFormatter, not from our parameter setup.

## Alternative Approaches to Try

### Option A: Skip Clone — Manually Allocate EventData
1. Call il2cpp_object_new(EventData_class) to allocate a new empty EventData
2. Copy fields from the WorldEventDataBase template manually (field by field)
3. Register in the active events list
4. Call BigMapController.RecreatAllBigMapRandomEvent to refresh UI

### Option B: Trigger ManageWorldEvent
Call ManageWorldEvent(wecInst) which is the game's own scheduled event creator.
Problem: it only creates events when random conditions are met (13-14% chance per area).

### Option C: Hook the Random Number Generator
Temporarily hook GlobalData.RandomRange to always return 0,
then trigger ManageWorldEvent. The forced RNG makes it always create an event.
After creation, unhook RandomRange.

### Option D: Save File Editing
Add the event directly to the save file (JSON/binary) and reload.
Avoids all runtime code execution issues.

### Option E: BepInEx Plugin
Write a C# plugin that runs INSIDE the game process with full .NET runtime access.
Clone/serialization would work natively. Most reliable but requires BepInEx enabled.
