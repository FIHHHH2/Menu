# HUD Text Polish - Remove Job ID, Improve Visibility

## Changes Required

### 1. HUD placeFrame - Remove Job ID
**Location**: `ui.lua` BuildHUD function (~line 2214-2223)

**Current State**:
- `jobId` label at position y=28 showing "Job ID: ..."

**Changes**:
- Remove the `jobId` TextLabel entirely
- Reduce `placeFrame` height from 52 to 38 (or keep 52 for spacing)
- Move `playersCount` up to y=28 (where jobId was)

### 2. HUD placeFrame - Improve Text Visibility
**Location**: `ui.lua` BuildHUD function (~line 2191-2234)

**Current State**:
- `placeName`: Font=Gotham, TextSize=9, Color=XP.text
- `placeId`: Font=Code, TextSize=8, Color=XP.tabInactiveText
- `playersCount`: Font=GothamBold, TextSize=9, Color=XP.accent

**Changes**:
- Increase text sizes slightly (e.g., +1 or +2)
- Make all bold (GothamBold or GothamSemibold)
- Use brighter colors for better visibility
- Note: Arimo font is not available in Roblox. Available fonts: Gotham, GothamBold, GothamSemibold, SourceSans, SourceSansBold, Code, etc.
- Recommendation: Use **GothamBold** or **GothamSemibold** for bold, or **SourceSansBold** for a cleaner look

### 3. Experience Tab gameDesc - Improve Visibility (if desired)
**Location**: `ui.lua` Experience tab content (~line 905-915)

**Current State**:
- `gameDesc`: Font=Gotham, TextSize=9, Color=XP.text

**Changes**:
- Same improvements: larger, bold, better color

---

## Open Questions

1. **Font Choice**: Arimo is not a Roblox built-in font. Should we use:
   - `GothamBold` (current bold font, clean)
   - `GothamSemibold` (medium-bold, modern)
   - `SourceSansBold` (clean, readable)
   - `SourceSansSemibold` (medium-bold)

2. **Text Sizes**: How much larger?
   - placeName: 9 → 11?
   - placeId: 8 → 10?
   - playersCount: 9 → 11?

3. **placeFrame Height**: After removing Job ID:
   - Reduce to 38 (tight)
   - Keep 52 (more breathing room)

4. **Should Experience tab gameDesc also be updated?** (same font/size changes)

---

## Implementation Tasks

1. Remove `jobId` label from placeFrame
2. Move `playersCount` up to fill the gap
3. Update placeName, placeId, playersCount fonts/sizes/colors
4. Optionally update Experience tab gameDesc