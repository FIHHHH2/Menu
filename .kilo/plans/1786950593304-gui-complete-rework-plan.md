# UniMenu Bug Fixes & Feature Implementation Plan

## Issues to Fix

### 1. Missing Tabs Not Visible (Critical)
**Root Cause**: `mm2.lua` registers ALL core feature tabs (Combat, Movement, Visuals, Themes, Config, HUD, Keybinds, Music) at lines 1816-1818. If `mm2.lua` fails to load or has errors, these tabs appear empty.

**Location**: `mm2.lua:1465-1818` (builtInFeatures registration)

**Fix**: Move core feature registration out of `mm2.lua` into a separate `core/features.lua` module that loads independently, or ensure `mm2.lua` always loads successfully with proper error handling.

---

### 2. Trolling Tab Dropdown Menu Broken (Critical) ✅ DONE
**Root Cause**: Dropdown menu parented to `contentScroll` (a ScrollingFrame with `ClipsDescendants=true`) at line 1146, causing it to be clipped and unselectable.

**Location**: `ui.lua:1133-1201`

**Fix Applied**: Parent dropdown menu to main frame with ZIndex 200+, position absolutely relative to dropdown button using AbsolutePosition.

---

### 3. MM2 Hard Dependency Breaks Non-MM2 Games (Critical)
**Root Cause**: 
- `ui.lua:120` references `ctx.State.MM2.roleESP` directly
- `loader.lua:62` loads `mm2` as required module
- All core features registered inside `mm2.lua` only

**Fix**: 
- Make MM2 features conditional (register only if in MM2 game)
- Move universal features to separate module
- Add safe accessor for MM2 state
- Remove direct `ctx.State.MM2` references from `ui.lua`

---

### 4. Experience Cover Tab (New Feature)
**Requirement**: Copy of Music tab that shows experience thumbnail/cover with Place ID, Place Name, Player count

**Location**: Create new tab "Experience" in sidebar, add feature to `builtInFeatures` or new module

**Implementation**:
- Use `game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)` for name
- Use `game.PlaceId` and `game.JobId`
- Show player count `#Players:GetPlayers() / Players.MaxPlayers`
- Fetch experience thumbnail via `https://thumbnails.roblox.com/v1/places/gameicons?placeIds={placeId}&size=512x512&format=Png&isCircular=false`

---

### 5. HUD Redesign
**Changes**:
- Move FPS/Ping to topbar (right side)
- Remove "UniPanel HUD" text
- Keep username and displayname on topbar
- Remove player position from HUD body
- Keep music display, place info, player count

**Location**: `ui.lua:1822-2055` (BuildHUD function)

---

### 6. Keybind Display GUI (New Feature)
**Requirement**: Toggleable GUI at bottom-right showing active keybinds, following theme

**Implementation**:
- Add "Show Keybinds" toggle in Keybinds tab
- Create floating frame at bottom-right with list of keybinds
- Format: `[Key] Feature Name` (e.g., `[R] Aimbot`)
- Follow current theme colors
- Draggable/repositionable
- Toggleable via keybind and menu

---

### 7. Notification Stacking (Fix Verification)
**Current**: Stacks downward from top-right ✓
**Verify**: When first expires, next one animates down smoothly; no indefinite stacking off-screen

---

## Implementation Tasks (Priority Order)

### Task 1: Fix Trolling Tab Dropdown (High Priority - Quick Fix) ✅ DONE
- Parent dropdown to main GUI frame instead of contentScroll
- Increase ZIndex to 200+
- Position absolutely using dropdown button's AbsolutePosition

### Task 2: Create core/features.lua with Universal Features (High Priority)
- Create new module `core/features.lua` with Combat, Movement, Visuals, Server, Themes, Config, HUD, Keybinds, Music, Experience
- Register all built-in features in this module
- This module loads independently of MM2

### Task 3: Update mm2.lua to Only Register MM2 Features (High Priority)
- Remove `builtInFeatures` and its registration loop from mm2.lua
- Keep only MM2-specific feature registration (wrapped in `if isMM2 then`)
- Remove Theme/Config registration from mm2.lua (handled by core/features.lua)

### Task 4: Update loader.lua Load Order (High Priority)
- Load `core/features` before `mm2`
- Keep existing order for other modules

### Task 5: Update ui.lua for Safe MM2 Access (High Priority)
- Fix `ui.lua:120` reference to `ctx.State.MM2.roleESP` with safe accessor
- Update any other direct MM2 state references

### Task 6: Add Experience Tab (Medium Priority)
- Add "Experience" to sidebar items in BuildGUI
- Create experience cover display in BuildContent for Experience tab
- Fetch and cache experience thumbnail via Roblox thumbnails API

### Task 7: Redesign HUD (Medium Priority)
- Update BuildHUD to move FPS/Ping to titlebar (right side)
- Remove "UniPanel HUD" text from titlebar
- Keep username/displayname in titlebar
- Remove position info from HUD body
- Keep music display, place info, player count

### Task 8: Keybind Display GUI (Medium Priority)
- Add "Show Keybind Overlay" toggle in HUD tab
- Create floating frame at bottom-right with active keybind list
- Format: `[Key] Feature Name` with ON/OFF indicator
- Follow current theme colors
- Draggable/repositionable
- Toggleable via keybind and menu

### Task 9: Verify Notification Stacking (Low Priority)
- Test that notifications animate down when one expires
- Ensure max limit (3) prevents off-screen stacking

---

## File Changes Summary

| File | Changes |
|------|---------|
| `ui.lua` | Fix dropdown parenting ✅, safe MM2 access, HUD redesign, Experience tab content, keybind overlay, sidebar Experience tab |
| `mm2.lua` | Remove builtInFeatures, only register MM2 tab conditionally |
| `core/features.lua` | NEW - Universal feature definitions (Combat, Movement, Visuals, Server, Themes, Config, HUD, Keybinds, Music, Experience) |
| `loader.lua` | Load `core/features` before `mm2` |
| `core.lua` | Add safe MM2 accessor if needed, keybind overlay functions |

---

## Validation Checklist

- [ ] All tabs (Combat, Movement, Visuals, MM2, Trolling, Server, Themes, Config, HUD, Keybinds, Music, **Experience**) show content
- [ ] Trolling dropdown opens fully, all players selectable, no clipping ✅
- [ ] Script works in non-MM2 games (no MM2 errors)
- [ ] Experience tab shows place icon, name, ID, player count
- [ ] HUD topbar shows: Username (@displayname) | FPS: 60 | Ping: 45ms
- [ ] HUD body shows: Music, Place Info, Player Count (no position)
- [ ] Keybind overlay toggleable, shows active binds at bottom-right
- [ ] Notifications stack down, animate properly, max 3 visible

---

## Open Questions

1. **Experience thumbnail API**: Use Roblox's thumbnails API or a custom service? (Recommend Roblox official)
2. **Keybind overlay format**: Show all registered binds or only toggled-on binds? (Recommend all with state indicator)
3. **HUD position**: Keep at bottom-left or move? (Keep bottom-left as-is)
4. **Music vs Experience tab**: Should they share code or be separate? (Separate for clarity)

---