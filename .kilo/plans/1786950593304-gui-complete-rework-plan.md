# Bug Fixes Plan: Notifications, Keybind Sync, HUD Info

## Issues Identified

### 1. Notifications Not Appearing on Keybind Toggle
**Problem**: `ShowNotification` is called from `core.lua:1971` but the notification module in `lib/notifications.lua` defines its own `ShowNotification` that overwrites `ctx.Core.ShowNotification`. However, `core.lua` calls `ShowNotification` directly (local reference) which may be nil or referencing the old notification system that was removed.

**Root Cause**: The old notification code was removed from `core.lua` but the loader loads `lib/notifications.lua` AFTER `core.lua`, so `ctx.Core.ShowNotification` gets set correctly. However, the keybind listener in `core.lua` uses a LOCAL `ShowNotification` variable that doesn't exist anymore (was removed during the rework).

**Fix**: The keybind listener at `core.lua:1971` calls `ShowNotification` but there's no local `ShowNotification` function in `core.lua` anymore. Need to call `ctx.Core.ShowNotification` instead.

### 2. Toggle Button Not Updating When Keybind Toggled
**Problem**: `RegisterKeybindUIUpdater` is called at `ui.lua:1349` but the callback only updates the button if the button still exists. When switching tabs, buttons are destroyed and recreated, so the updater reference becomes stale.

**Root Cause**: The `RegisterKeybindUIUpdater` stores a callback, but when `BuildContent` is called (tab switch), new buttons are created without re-registering updaters for the new button instances.

**Fix**: Either:
- A) Rebuild keybind updaters when content rebuilds
- B) Store the kbName on the button and find buttons by name when keybind fires
- C) Use a polling mechanism to sync button states when tab becomes visible

**Recommended Fix**: Option B - When keybind fires, search for buttons with matching feature name and update them. Or simpler: when tab becomes active, rebuild the content fresh which already reads `feat.get()` state.

### 3. Notifications Stack Upwards (Wrong Direction)
**Problem**: `CalculatePosition` at `lib/notifications.lua:82-85` uses `-70 - (index * ...)` which moves UP as index increases.

**Fix**: Notifications should appear at TOP of screen and stack DOWN. Change:
- Base position: `UDim2.new(0, 8, 0, 8)` (top-left)
- Stack direction: `8 + (index * (notificationHeight + notificationGap))`
- New notifications appear BELOW previous ones

### 4. Missing HUD Info (Player Name, Place ID, FPS Counter)
**Problem**: HUD was simplified during rework. Need to add back:
- Player Name / Display Name in title bar
- FPS counter (live updating)
- Place Name, Place ID, Job ID info section

**Current HUD** (`ui.lua:1860-1950`):
- Title bar only shows "UniPanel HUD"
- Music section shows Spotify/Last.fm
- No player info, FPS, or place info

**Fix**: Add back these info sections to `BuildHUD`:
1. **Title Bar**: "UniPanel HUD | [DisplayName] (@UserName)"
2. **FPS/Ping Section**: Live updating via Heartbeat
3. **Place Info Section**: Place Name, Place ID, Job ID, Player count

---

## Implementation Tasks

### Task 1: Fix Keybind Notification Call
**File**: `UniMenu/core.lua:1971`
**Change**: Replace `ShowNotification(...)` with `ctx.Core.ShowNotification(...)`

```lua
-- Line 1970-1971 change from:
local state = reg.get() and "enabled" or "disabled"
ShowNotification(reg.featName .. " " .. state)

-- To:
local state = reg.get() and "enabled" or "disabled"
if ctx.Core.ShowNotification then
  ctx.Core.ShowNotification(reg.featName .. " " .. state)
end
```

### Task 2: Fix Toggle Button State Sync
**File**: `UniMenu/ui.lua:1347-1352`
**Change**: The updater callback already exists but needs to work across tab switches. The current implementation registers the updater AFTER the button click handler, but the `kbName` is constructed correctly.

**Current code at 1347-1352**:
```lua
-- Register keybind UI sync
local kbName = currentTab .. "::" .. feat.name
RegisterKeybindUIUpdater(kbName, function(newState)
  tBtn.Text = newState and "ON" or "OFF"
  tBtn.BackgroundColor3 = newState and XP.green or Color3.fromRGB(150, 150, 150)
end)
```

**Issue**: When tab switches, `tBtn` is destroyed. The callback still references the old button.

**Fix**: The `NotifyKeybindUIUpdate` function should search for the button by name in the current UI. Modify the approach:

1. When building toggle buttons, set `tBtn.Name = "Toggle_" .. feat.name`
2. In `NotifyKeybindUIUpdate`, find the button by name and update it:

```lua
-- In ui.lua, add helper function:
local function FindToggleButton(featName)
  if not contentContainerRef then return nil end
  local scroll = contentContainerRef:FindFirstChild("ContentScroll")
  if not scroll then return nil end
  for _, col in ipairs(scroll:GetChildren()) do
    if col:IsA("Frame") and (col.Name == "LeftColumn" or col.Name == "RightColumn") then
      for _, card in ipairs(col:GetChildren()) do
        if card:IsA("Frame") then
          for _, child in ipairs(card:GetDescendants()) do
            if child:IsA("TextButton") and child.Name == "Toggle_" .. featName then
              return child
            end
          end
        end
      end
    end
  end
  return nil
end
```

3. Update `NotifyKeybindUIUpdate` to use this helper

### Task 3: Fix Notification Stacking Direction
**File**: `UniMenu/lib/notifications.lua`
**Changes**:

1. Change base position from bottom-right to top-right:
```lua
-- Line 12-14, change from:
local basePosition = UDim2.new(1, -220, 1, -70)

-- To:
local basePosition = UDim2.new(1, -220, 0, 8) -- Top right
```

2. Fix `CalculatePosition` to stack DOWN:
```lua
-- Lines 82-86, change from:
local function CalculatePosition(index)
  local yOffset = -70 - (index * (notificationHeight + notificationGap))
  return UDim2.new(1, -210, 1, yOffset)
end

-- To:
local function CalculatePosition(index)
  local yOffset = 8 + (index * (notificationHeight + notificationGap))
  return UDim2.new(1, -220, 0, yOffset)
end
```

3. Fix `CalculateStartPosition`:
```lua
-- Lines 88-91, change from:
local function CalculateStartPosition(index)
  local yOffset = -30 - (index * (notificationHeight + notificationGap))
  return UDim2.new(1, -210, 1, yOffset)
end

-- To:
local function CalculateStartPosition(index)
  return UDim2.new(1, -180, 0, 8 + (index * (notificationHeight + notificationGap)))
end
```

### Task 4: Add HUD Info Sections
**File**: `UniMenu/ui.lua:1860-1950`
**Changes**:

1. Update title bar to show player name:
```lua
-- After line 1872, change:
hudTitle.Text = "UniPanel HUD"

-- To:
hudTitle.Text = "UniPanel HUD | " .. player.DisplayName .. " (@" .. player.Name .. ")"
```

2. Add FPS/Ping section after music frame:
```lua
-- After music frame (around line 1950), add:

-- FPS/Ping Display
local fpsFrame = Instance.new("Frame")
fpsFrame.Size = UDim2.new(1, 0, 0, 18)
fpsFrame.BackgroundColor3 = XP.panel2
fpsFrame.BackgroundTransparency = 0.3
fpsFrame.BorderSizePixel = 0
fpsFrame.LayoutOrder = 2
fpsFrame.Parent = content

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, -8, 1, 0)
fpsLabel.Position = UDim2.new(0, 4, 0, 0)
fpsLabel.Text = "FPS: -- | Ping: --ms"
fpsLabel.TextColor3 = XP.text
fpsLabel.BackgroundTransparency = 1
fpsLabel.Font = Enum.Font.Code
fpsLabel.TextSize = 9
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Parent = fpsFrame
```

3. Add Place Info section:
```lua
-- Place Info
local infoFrame = Instance.new("Frame")
infoFrame.Size = UDim2.new(1, 0, 0, 52)
infoFrame.BackgroundColor3 = XP.panel2
infoFrame.BackgroundTransparency = 0.3
infoFrame.BorderSizePixel = 0
infoFrame.LayoutOrder = 3
infoFrame.Parent = content

local placeName = Instance.new("TextLabel")
placeName.Size = UDim2.new(1, -8, 0, 14)
placeName.Position = UDim2.new(0, 4, 0, 0)
placeName.Text = "Place: " .. (game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "Unknown")
placeName.TextColor3 = XP.text
placeName.BackgroundTransparency = 1
placeName.Font = Enum.Font.Gotham
placeName.TextSize = 9
placeName.TextXAlignment = Enum.TextXAlignment.Left
placeName.TextTruncate = Enum.TextTruncate.AtEnd
placeName.Parent = infoFrame

local placeId = Instance.new("TextLabel")
placeId.Size = UDim2.new(1, -8, 0, 14)
placeId.Position = UDim2.new(0, 4, 0, 14)
placeId.Text = "Place ID: " .. tostring(game.PlaceId)
placeId.TextColor3 = XP.tabInactiveText
placeId.BackgroundTransparency = 1
placeId.Font = Enum.Font.Code
placeId.TextSize = 8
placeId.TextXAlignment = Enum.TextXAlignment.Left
placeId.Parent = infoFrame

local jobId = Instance.new("TextLabel")
jobId.Size = UDim2.new(1, -8, 0, 14)
jobId.Position = UDim2.new(0, 4, 0, 28)
jobId.Text = "Job ID: " .. tostring(game.JobId):sub(1, 36) .. "..."
jobId.TextColor3 = XP.tabInactiveText
jobId.BackgroundTransparency = 1
jobId.Font = Enum.Font.Code
jobId.TextSize = 8
jobId.TextXAlignment = Enum.TextXAlignment.Left
jobId.Parent = infoFrame

local playersCount = Instance.new("TextLabel")
playersCount.Size = UDim2.new(1, -8, 0, 14)
playersCount.Position = UDim2.new(0, 4, 0, 42)
playersCount.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
playersCount.TextColor3 = XP.accent
playersCount.BackgroundTransparency = 1
playersCount.Font = Enum.Font.GothamBold
playersCount.TextSize = 9
playersCount.TextXAlignment = Enum.TextXAlignment.Left
playersCount.Parent = infoFrame
```

4. Update HUD Heartbeat to update FPS and player count:
```lua
-- In the HUD Heartbeat connection, update fpsLabel and playersCount
```

---

## Files to Modify

1. `UniMenu/core.lua` - Fix `ShowNotification` call
2. `UniMenu/ui.lua` - Fix toggle button sync, add HUD info
3. `UniMenu/lib/notifications.lua` - Fix stacking direction

## Validation

- [ ] Keybind press shows notification
- [ ] Keybind press updates toggle button state immediately
- [ ] Notifications appear at top-right and stack downward
- [ ] HUD shows player name in title bar
- [ ] HUD shows FPS counter
- [ ] HUD shows Place Name, Place ID, Job ID, Player count