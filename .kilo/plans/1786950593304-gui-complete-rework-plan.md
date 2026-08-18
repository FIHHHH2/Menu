# UniMenu Bug Fixes Plan

## Critical Issues Found

### Issue 1: Tabs Not Rendering (ui.lua)

**Problem**: After Trolling tab handling, code falls through to "DEFAULT: Render feature sections" which references `leftCol`/`rightCol` that only exist in Keybinds tab scope. This causes silent failures for ALL tabs except Music and Keybinds.

**Root Cause**: Lines 1030-1172 handle Trolling, then line 1174+ tries to use `leftCol`/`rightCol` which are nil for non-Keybinds tabs.

**Fix**: Create `leftCol`/`rightCol` containers for the default rendering path before line 1194.

**Location**: `ui.lua:1194-1195`

**Code Change**:
```lua
-- Before line 1194, add:
local leftCol = Instance.new("Frame")
leftCol.Name = "LeftColumn"
leftCol.Size = UDim2.new(0.49, 0, 1, 0)
leftCol.BackgroundTransparency = 1
leftCol.BorderSizePixel = 0
leftCol.ClipsDescendants = true
leftCol.Parent = contentScroll

local rightCol = Instance.new("Frame")
rightCol.Name = "RightColumn"
rightCol.Size = UDim2.new(0.49, 0, 1, 0)
rightCol.Position = UDim2.new(0.51, 0, 0, 0)
rightCol.BackgroundTransparency = 1
rightCol.BorderSizePixel = 0
rightCol.ClipsDescendants = true
rightCol.Parent = contentScroll

local leftLayout = Instance.new("UIListLayout")
leftLayout.FillDirection = Enum.FillDirection.Vertical
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftLayout.Padding = UDim.new(0, 6)
leftLayout.Parent = leftCol

local rightLayout = Instance.new("UIListLayout")
rightLayout.FillDirection = Enum.FillDirection.Vertical
rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
rightLayout.Padding = UDim.new(0, 6)
rightLayout.Parent = rightCol

local function UpdateCanvas()
  local maxH = math.max(leftLayout.AbsoluteContentSize.Y, rightLayout.AbsoluteContentSize.Y)
  contentScroll.CanvasSize = UDim2.new(0, 0, 0, maxH + 16)
end
leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
```

### Issue 2: Last.fm Not Detecting Song Changes (music/lastfm.lua)

**Problem**: Track change detection may fail because:
1. `lastTrackData` is module-local but `Music` state is shared
2. No debug logging to verify polling is working
3. Track end detection only triggers if `lastTrackData.song ~= ""`

**Fix**: Add debug output and ensure state sync.

**Location**: `music/lastfm.lua:95-103`

**Code Change**: Add track change logging:
```lua
-- After line 103, add:
if trackChanged then
  print("[Last.fm] Track changed:", newSong, "-", newArtist, "| Active:", newActive)
end
```

Also ensure the polling loop is actually running by checking `ctx.Core.isScriptRunning`.

## Implementation Tasks

1. [ ] Fix ui.lua line 1194 - add leftCol/rightCol creation before default rendering
2. [ ] Add debug logging to lastfm.lua track change detection
3. [ ] Verify isScriptRunning is set to true in core.lua Init()
4. [ ] Test all tabs render correctly
5. [ ] Test Last.fm track change detection with real Spotify playback

## Files to Modify

- `UniMenu/ui.lua` - Add column containers for default tab rendering
- `UniMenu/music/lastfm.lua` - Add debug logging for track changes
- `UniMenu/core.lua` - Verify isScriptRunning initialization