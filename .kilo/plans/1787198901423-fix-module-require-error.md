# Fix "Failed to execute module core: attempt to index nil with 'gui'" Error

## Root Cause

The error occurs because `core.lua` uses `require(script.Parent.gui.billboardPool)` but the loader architecture loads modules via HTTP + `loadstring`, not as Roblox ModuleScripts. 

**The loader architecture:**
1. Loads modules via HTTP from GitHub
2. Executes them with `loadstring(src)(ctx)`
3. Modules should expose APIs via `ctx` table, not `return` values
3. `require()` doesn't work for HTTP-loaded modules

## Files to Fix

### 1. `UniMenu/core.lua` (lines 40-64)
Replace `require(script.Parent.gui.billboardPool)` with ctx-based access.

### 2. `UniMenu/modules/musicHook.lua` (line 1)
Same issue - uses `require(script.Parent.billboardPool)`

### 3. `UniMenu/gui/billboardPool.lua`
Must register itself in `ctx.Modules` when loaded.

### 4. `UniMenu/gui/scriptBillboard.lua`
Must register itself in `ctx.Modules`.

## Solution Pattern

Each module should:
```lua
local ctx = ...

-- Module logic here
local module = { ... }

-- Register in ctx for other modules to access
ctx.Modules = ctx.Modules or {}
ctx.Modules.billboardPool = module

return module  -- still return for any legacy require() calls
```

## Implementation Plan

1. **Update `billboardPool.lua`** - Add `ctx = ...` and register in `ctx.Modules`
2. **Update `scriptBillboard.lua`** - Same pattern
3. **Update `core.lua`** - Use `ctx.Modules.billboardPool` instead of `require()`
4. **Update `musicHook.lua`** - Use `ctx.Modules.billboardPool` instead of `require()`
5. **Update loader** - Ensure modules load in correct order

## Validation
- Test with Roblox executor
- Verify no "attempt to index nil" errors
- Confirm billboard GUIs appear for TargetScript users