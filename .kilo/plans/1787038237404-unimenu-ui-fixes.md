# UniMenu UI Fixes & Spotify Integration Plan

## Overview
This plan addresses UI issues and adds Spotify integration. All changes are implementation-ready.

## Tasks

### 1. Make MM2 Module Optional
**File**: `loader.lua`
- **Change**: Conditionally load `mm2.lua` only if MM2 is detected.
  ```lua
  -- Detect MM2 before loading module
  local isMM2 = false
  pcall(function()
    isMM2 = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") \
            and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Gameplay")
  end)
  if isMM2 then
    loadModule("mm2")
  end
  ```

### 2. Add Spotify Tab with OAuth & Controls
**File**: `ui.lua`
- **Change**: Add new tab with Spotify authentication and playback controls.
  ```lua
  -- Spotify Tab
  if currentTab == "Spotify" then
    local spotifyCard = Card(200, 1)
    Lbl(spotifyCard, "Spotify Connect", Enum.Font.GothamBold, 12, XP.text, 10, 8)
    
    -- Client ID Input
    local clientIdBox = Instance.new("TextBox")
    clientIdBox.Size = UDim2.new(1, -20, 0, 30)
    clientIdBox.Position = UDim2.new(0, 10, 0, 40)
    clientIdBox.Text = Music.spotify.clientId or ""
    clientIdBox.PlaceholderText = "Spotify Client ID"
    clientIdBox.Parent = spotifyCard

    -- Connect Button
    ActionBtn(spotifyCard, "Connect", 10, 80, 80, Color3.fromRGB(30, 200, 80), function()
      -- Trigger OAuth flow
      if ctx.Core.Spotify.StartAuth() then
        ctx.Core.ShowNotification("Spotify: Check browser for auth")
      end
    end)

    -- Playback Controls
    if Music.spotify.connected then
      ActionBtn(spotifyCard, "Play", 100, 80, 60, XP.accent, function() ctx.Core.Spotify.Play() end)
      ActionBtn(spotifyCard, "Pause", 170, 80, 60, Color3.fromRGB(200, 50, 50), function() ctx.Core.Spotify.Pause() end)
      -- Add Next/Prev/Volume sliders similarly
    end
  end
  ```

### 3. Fix Notification Cleanup
**File**: `lib/notifications.lua`
- **Change**: Destroy previous notification GUI immediately when creating a new one.
  ```lua
  -- In ShowNotification, before creating new GUI:
  RemoveCurrentNotification() -- Destroy previous GUI sync
  ```

### 4. Square All UI Elements
**Files**: `ui.lua`, `music/covers.lua`, `core.lua`
- **Change**: Remove all `UICorner` instances.

### 5. Fix Experience Tab Cover Art
**File**: `ui.lua`
- **Change**: Use higher-resolution thumbnail URL.
  ```lua
  local url = "https://thumbnails.roblox.com/v1/places/gameicons?placeIds=" .. game.PlaceId .. "&size=256x256&format=Png&isCircular=false"
  ```

### 6. Fix Music Tab Cover Art Positioning
**File**: `ui.lua`
- **Change**: Adjust cover art size/position and use `ScaleType.Fit`.
  ```lua
  mCover.Size = UDim2.new(0, 60, 0, 60)
  mCover.Position = UDim2.new(0, 4, 0, 4)
  mCover.ScaleType = Enum.ScaleType.Fit
  ```

### 7. Fix Place Description Clipping
**File**: `ui.lua`
- **Change**: Increase `gameCard` height and ensure text wraps.
  ```lua
  gameCard.Size = UDim2.new(1, 0, 0, 140)
  gameDesc.Size = UDim2.new(1, -20, 1, -38)
  ```

### 8. Fix Keybind Overlay Clipping
**File**: `ui.lua`
- **Change**: Adjust button positions in keybind rows.
  ```lua
  keyLbl.Size = UDim2.new(0, 58, 0, 20)
  keyLbl.Position = UDim2.new(1, -112, 0.5, -10)
  clrBtn.Position = UDim2.new(1, -36, 0.5, -10)
  ```

### 9. Fix Trolling Tab Dropdown
**File**: `ui.lua`
- **Change**: Use live player list, correct dropdown positioning, and add action buttons.
  ```lua
  -- Use live player list
  local livePlayerList = ctx.Core.playerList or {}
  
  -- Position dropdown menu relative to dropCard
  dropdownMenu.Position = UDim2.new(0, 6, 0, 52)
  dropdownMenu.Parent = dropCard
  
  -- Add action buttons after selection
  if selectedPlayer then
    -- Action buttons code as previously planned
  end
  ```

## Validation Steps
1. **MM2 Optional**: Test GUI in non-MM2 game → no errors.
2. **Spotify**: Authenticate → control playback.
3. **Notifications**: Rapid triggers → no stacking.
4. **UI Corners**: Verify all elements are squared.
5. **Cover Art**: Experience/Music tabs display correct images.
6. **Description**: No text clipping in Experience tab.
7. **Keybinds**: No button overlap in overlay.
8. **Trolling**: Dropdown works, actions functional.

## Implementation
Execute the code changes above. Test each fix in a Roblox environment.