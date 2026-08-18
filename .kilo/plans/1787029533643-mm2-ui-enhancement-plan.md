# UniMenu MM2 & UI Enhancement Plan

## 1. Notification System - No Limit with Cascade
**File:** `lib/notifications.lua`

**Changes:**
- Remove `maxConcurrent = 3` limit
- When notification expires, shift all notifications above it down by 1 position
- Track `basePositionOffset` (increments each time a notification expires and queue becomes empty)
- Reset to `basePositionOffset = 0` when queue fully empties

## 2. Bottom HUD Cleanup
**File:** `ui.lua` (BuildHUD function around line 2038)

**Changes:**
- Move player count INSIDE the game description box (placeFrame)
- Make player count text bold with accent color
- Remove duplicate player count display
- Scale song cover larger (from 52x52 to 64x64)
- Cleaner layout:
  - Remove separate player count line
  - Combine place info into single cleaner card

## 3. MM2 Features - Add Missing
**File:** `mm2.lua`

**Add to mm2FeatureList:**
1. **Coins ESP** - Highlight coins with ESP
2. **Auto Kill Murderer** - Kill the murderer automatically
3. **Kill Everyone** - Kill all players
4. **Auto Grab Gun** - Auto-collect gun when sheriff dies/drops
5. **MM2 Role ESP** - ESP showing [MURDERER]/[SHERIFF]/[INNOCENT]
6. **Auto Dodge Knife** - Automatically dodge incoming knife attacks
7. **Coin Auto Farm** - Teleport to collect coins (remove old "TP to roles" autofarm)

**Remove:**
- "Auto Farm (TP to Roles)" - replace with coin autofarm

## 4. Dropdown & Trolling Features
**Files:** `core/features.lua`, `mm2.lua`

**Add Trolling tab features:**
- TP to Target
- Fling Target
- Trap Target
- Head Sit Target
- Copy Target Position
- Freezes / Stun
- Loop Kill
- Void Walk (send to void)
- Crash (attempt to crash target)

## 5. MM2 State Updates
**File:** `core.lua` (MM2 state around line 431)

**Add to MM2 state:**
- autoKillMurderer
- killEveryone
- autoDodgeKnife
- loopKillTarget

## Implementation Order
1. Fix notifications.lua (cascade system)
2. Update ui.lua BuildHUD (cleaner layout)
3. Update mm2.lua (add missing features)
4. Update core/features.lua (add Trolling tab options)
5. Update core.lua (MM2 state additions)
