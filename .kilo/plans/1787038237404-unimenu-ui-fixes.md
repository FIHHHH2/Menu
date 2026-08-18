# UniMenu Bug Fix Plan (Updated)

## Context
The UniMenu cheat panel (`A:\Potassium\Generated\UniMenu\`) has multiple UI issues reported by the user:
1. **Experience tab**: Unable to get game cover art
2. **Music tab**: Cover art not centered well, not scaled properly
3. **All UIs**: Everything should be squared (no squircle/rounded corners)
4. **Experience tab**: Place description text clipping/overflowing its frame
5. **Notifications**: Previous GUI doesn't delete itself when creating new notification
6. **Keybinds tab**: Clear (Clr) buttons clipping with keybind display
7. **Trolling tab**: Dropdown doesn't appear, nothing in the UI works

## Root Cause Analysis

### 1. Experience Tab Cover Art
- **File**: `ui.lua` lines 937-946 (`RefreshExperienceInfo`)
- **Issue**: Uses `thumbnails.roblox.com/v1/places/gameicons` endpoint which returns small 512x512 game icons, not the larger experience thumbnail
- **Fix**: Use `thumbnails.roblox.com/v1/places/gameicons?size=768x432` or the proper experience thumbnail endpoint

### 2. Music Tab Cover Art Positioning/Scaling
- **File**: `ui.lua` lines 565-590 (Music tab "Now Playing" card) and 2216-2238 (HUD music display)
- **Issues**:
  - Music cover uses `ScaleType.Crop` but positioned at (2,2) with size 64x64 - not centered
  - HUD music cover has `UICorner` with radius 4 (rounded) - should be square
  - No proper aspect ratio handling
- **Fix**: Center the cover art, use proper scaling, remove UICorner

### 3. Squircle/Rounded Corners - All UIs
- **Files found with UICorner**:
  - `ui.lua` line 2236-2238: HUD music cover (CornerRadius 4)
  - `core.lua` line 765-766: Some UI element (CornerRadius 0.08 - 8% of size = squircle)
  - `music/covers.lua` line 63-64: CornerRadius 8
  - `music/covers.lua` line 75-76: CornerRadius 1,0 (fully circular)
- **Fix**: Remove ALL UICorner instances or set CornerRadius to 0 for square corners

### 4. Experience Tab Place Description Clipping
- **File**: `ui.lua` lines 910-922 (`gameDesc` TextLabel)
- **Issue**: `TextWrapped = true` but `ClipsDescendants = true` on parent card may not be enough; text size 11 with 70px height may overflow
- **Fix**: Ensure parent card has `ClipsDescendants = true`, possibly reduce text size or increase card height

### 5. Notification GUI Cleanup
- **File**: `lib/notifications.lua`
- **Current state**: Uses single `currentNotification` reference
- **Issue**: The previous notification GUI might not be fully destroyed before creating new one; fade animation may not complete
- **Fix**: Ensure synchronous cleanup - destroy previous GUI immediately before creating new one, or await the fade completion

### 6. Keybinds Tab Clear Button Clipping
- **File**: `ui.lua` lines 1092-1138 (`keyLbl` and `clrBtn`)
- **Issue**: `keyLbl` size 70x20 at position (1, -102), `clrBtn` size 36x20 at (1, -74) - they overlap! The clrBtn is positioned inside the keyLbl's space
- **Fix**: Adjust positioning - keyLbl should end before clrBtn starts, or reduce keyLbl width

### 7. Trolling Tab Dropdown Not Working
- **File**: `ui.lua` lines 1247-1388
- **Issues**:
  - `playerList` is captured at line 39 as `local playerList = ctx.Core.playerList` - this is a snapshot, not a live reference
  - `dropdownMenu` parented to `frame` (line 1332) but positioned using absolute coordinates that may be wrong
  - `activeDropdowns` table referenced but not defined in scope
  - Dropdown options use `playerList` which may be empty if `UpdatePlayerList()` hasn't run yet
- **Fix**: 
  - Use `ctx.Core.playerList` directly (live reference)
  - Fix dropdown positioning
  - Define `activeDropdowns` or remove reference
  - Ensure `UpdatePlayerList()` is called before Trolling tab renders

## Files to Modify

1. **`lib/notifications.lua`** - Fix notification cleanup
2. **`ui.lua`** - Fix Experience cover art, Music cover art, square corners, description clipping, keybind clipping, Trolling dropdown
3. **`core.lua`** - Remove UICorner (line 765-766)
4. **`music/covers.lua`** - Remove UICorner instances

## Validation Plan

1. Load script in-game
2. Open Experience tab → verify cover art loads correctly
3. Open Music tab → verify cover art centered and squared
4. Open HUD → verify music cover is square (no rounded corners)
5. Open any tab → verify no rounded corners anywhere
6. Experience tab → verify description text doesn't clip
7. Trigger multiple notifications rapidly → only one shows, previous destroyed
8. Open Keybinds tab → verify Clear button doesn't overlap key display
9. Open Trolling tab → verify dropdown opens, shows players, selection works