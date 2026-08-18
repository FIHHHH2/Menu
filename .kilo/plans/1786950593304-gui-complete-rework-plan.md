# HUD & Experience Tab UI Polish

## Changes Required

### 1. HUD - Player Count Integration
**Location**: `ui.lua` BuildHUD function (~line 2165-2230)

**Current State**:
- Separate `playersLabel` at LayoutOrder 2 showing "Players: --" 
- `placeFrame` at LayoutOrder 5 with placeName, placeId, jobId, playersCount (duplicate)

**Changes**:
- Remove the standalone `playersLabel` (InfoLine at line 2182)
- Move player count into `placeFrame` (the game description box)
- Make player count text bold and accent-colored within placeFrame
- Keep placeFrame but merge playersCount into it as a styled line

### 2. HUD - Larger Music Cover
**Location**: `ui.lua` BuildHUD function (~line 2125-2133)

**Current State**:
- `musicCover.Size = UDim2.new(0, 36, 0, 36)`

**Changes**:
- Increase cover size to `UDim2.new(0, 48, 0, 48)` or similar
- Adjust `musicText` and `musicSubtext` position/size to accommodate larger cover
- Increase `musicFrame` height accordingly

### 3. Experience Tab - Larger Experience Cover
**Location**: `ui.lua` Experience tab content (~line 859-880)

**Current State**:
- `expCover.Size = UDim2.new(0, 100, 0, 100)`

**Changes**:
- Increase to `UDim2.new(0, 140, 0, 140)` or similar
- Adjust layout positions of text labels (`expName`, `expId`, etc.) to flow beside the larger cover
- Increase `expCoverCard` height accordingly

---

## Implementation Tasks

1. **HUD**: Remove `playersLabel` (line 2182), integrate player count into `placeFrame` with bold/accent styling
2. **HUD**: Increase `musicCover` size from 36x36 to ~48x48, adjust adjacent text positions and frame height
3. **Experience Tab**: Increase `expCover` size from 100x100 to ~140x140, adjust card height and text label positions