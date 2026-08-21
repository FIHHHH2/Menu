# Fix "attempt to index nil with 'gui'" Error in core.lua

## Problem Analysis

The error occurs at `core.lua:49` where `uiManager.GetGUI()` returns only **one** value (a billboard GUI), but the code tries to unpack **two** values (`billboard, songTitle`). Additionally, line 53 calls a non-existent method `uiManager:AssignBillboard(player)`.

## Root Causes

1. **Incorrect return value unpacking** - `billboardPool.lua:GetGUI()` returns a single billboard, but `core.lua` expects two return values
2. **Missing method** - `AssignBillboard` doesn't exist in `uiManager` (only `GetGUI` and `ReturnGUI`)
3. **No nil guard** - If the GUI pool is empty, `GetGUI()` returns `nil`, causing downstream errors

## Files to Modify

### 1. `UniMenu/core.lua` (lines 40-57)

**Current broken code:**
```lua
local uiManager = require(script.Parent.gui.billboardPool)

game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        local playerScripts = character:WaitForChild("PlayerScripts")
        playerScripts.ChildAdded:Connect(function(script)
            if script.Name == "TargetScript" then
                player.scriptUserFlag = true
                local billboard, songTitle = uiManager.GetGUI()  -- ERROR: unpacks 2 values
                billboard.Parent = player
                player.BillboardGUI = billboard
                uiManager:AssignBillboard(player)  -- ERROR: method doesn't exist
            end
        end)
    end)
end)
```

**Fixed code:**
```lua
local uiManager = require(script.Parent.gui.billboardPool)

if not uiManager then
    error("[CORE] uiManager failed to load from billboardPool")
    return
end

game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        local playerScripts = character:WaitForChild("PlayerScripts")
        playerScripts.ChildAdded:Connect(function(script)
            if script.Name == "TargetScript" then
                player.scriptUserFlag = true
                local billboard = uiManager.GetGUI()  -- FIX: single return value
                if billboard then
                    billboard.Parent = player
                    player.BillboardGUI = billboard
                else
                    warn("[CORE] No available billboard GUI in pool")
                end
            end
        end)
    end)
end)
```

### 2. `UniMenu/gui/billboardPool.lua` (optional enhancement)

Add a safety check to auto-expand pool if empty:
```lua
GetGUI = function()
    if #uiManager.availableGUIs == 0 then
        -- Auto-expand pool by creating a new billboard
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ScriptUserBillboard"
        billboard.Size = UDim2.new(0, 150, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.Parent = game.Lighting
        return billboard
    end
    return table.remove(uiManager.availableGUIs, 1)
end
```

## Validation Steps

1. Load the script in Roblox Studio
2. Verify no "attempt to index nil" errors on startup
3. Add a `TargetScript` to a player's `PlayerScripts` 
4. Confirm billboard appears above player
5. Check Output window for any warnings

## Dependencies

- Requires `billboardPool.lua` to exist at `UniMenu/gui/billboardPool.lua`
- Module must properly return `uiManager` table with `GetGUI` function