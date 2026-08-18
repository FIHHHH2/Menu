# UniMenu Git Push & Implementation Plan - FINAL

## Current Git Status
```
On branch main
Your branch is up to date with 'origin/main'.

Changes to be committed:
  modified:   .kilo/plans/1787029533643-mm2-ui-enhancement-plan.md
  modified:   UniMenu/mm2.lua
```

## Files Modified on Disk (NOT yet staged)

### 1. UniMenu/mm2.lua - ✅ DONE (has new content)
Full rewrite with optional MM2 detection and new features (Coins ESP, Auto Kill Murderer, Kill Everyone, Auto Grab Gun, MM2 Role ESP, Auto Dodge Knife, Coin Auto Farm).

### 2. UniMenu/lib/notifications.lua - ❌ NEEDS REWRITE
**Current (old):** Uses `basePositionOffset`, notifications stack from top-down with old logic
**Required:** Top-to-bottom stacking where:
- New notifications appear at TOP and push existing DOWN
- Duration: 0.75 seconds
- When notification expires, remaining move UP to fill gap
- No limit on concurrent notifications

### 3. UniMenu/ui.lua (Experience tab lines ~893-961) - ❌ NEEDS FIXES
**Bugs to fix:**
- Line ~896: `local playersCount = Instance.new("TextLabel")` missing proper indent
- Line ~897: `local players = Players:GetPlayers()` - unnecessary local
- Line ~900: `playersCount.Text = "Players: " .. #players` should use `#Players:GetPlayers()`
- Line ~906: `playersCount.Parent = placeFrame` → should be `playersCount.Parent = serverCard`
- Line ~919: `local gameCard = Instance.new("Frame")` → should be `local gameCard = Card(150, 3)`
- Line ~922: `gameDesc.Size = UDim2.new(1, -20, 0, 70)` → should be `0, 120`
- Line ~927: `gameDesc.Font = Enum.Font.GothamBold` → should be `Enum.Font.Gotham`
- Line ~928: `gameDesc.TextSize = 11` → should be `10`
- Line ~942: `placeName.Text` → should be `expName.Text`
- Line ~943: `placeCreator.Text` → should be `expCreator.Text`

**Summary of changes:**
- Server card height: 80 → 90
- Game card height: 70 → 150
- Game description text area: 70 → 120 height
- Fix undefined variable references

### 4. UniMenu/core/features.lua - ❌ NEEDS TROLLING SECTION
Add new `Trolling` tab after `Experience` tab with:
- Target Selection, TP to Target, Fling Target, Trap Target, Head Sit, Void Walk, Freeze Target, Loop Kill, Crash Target, Copy Target Pos

## After Implementation - Push to GitHub
```bash
cd A:\Potassium\Generated
git add -A
git commit -m "Fixed bugs, added features, improved notifications and UI"
git push origin main
```

## Verification Checklist
- [ ] Script runs without MM2 game
- [ ] Notifications stack from top-to-bottom, expire after 0.75s
- [ ] Experience tab shows game description properly (120px height)
- [ ] Trolling features appear in Trolling tab
- [ ] No undefined variable errors