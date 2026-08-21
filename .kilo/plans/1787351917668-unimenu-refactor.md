# UniMenu Refactoring Plan

## Goal
Fix bugs and implement quality-of-life (QoL) features in the UniMenu codebase without altering themes or UI design.

## Scope
- **Target Files**: `utils.lua`, `mm2.lua`, `main_ui.lua`, `loader.lua`, `core.lua`
- **Focus Areas**: Code stability, performance, memory management, and user experience.

## Tasks

### 1. **Utility Functions Optimization** (`utils.lua`)
- **DeepCopy**: Replace recursive implementation with an iterative approach using a stack to prevent stack overflows and improve performance.
- **HTTP Methods**: Consolidate `HttpGet`/`HttpPost` into a single function with timeout handling and error logging.
- **Math/Color Utilities**: Add input validation (e.g., clamp HSV values in `HSVToRGB`).

### 2. **Game-Specific Fixes (MM2)** (`mm2.lua`)
- **ESP Features**:
  - Use weak tables for `mm2EspObjects` and `coinEspObjects` to prevent memory leaks.
  - Debounce `UpdateMM2ESP` to reduce redundant updates.
- **Auto-Features**:
  - Add checks in `autoKillMurderer` to ensure the player has a gun before firing.
  - Implement cooldowns for `ToggleCoinAutoFarm` to avoid rate limits.

### 3. **UI/UX Improvements** (`main_ui.lua`)
- **Theme System**: Cache theme colors to avoid recalculating on every frame.
- **Keybind Management**: Centralize keybinds in a validated table to prevent conflicts.
- **Notifications**: Queue notifications with fade-out animations to prevent overlap.

### 4. **Module Loading & Core Services** (`loader.lua`, `core.lua`)
- **Module Caching**: Ensure modules are loaded only once and handle errors gracefully.
- **Peer Detection**: Throttle `ScanPeers` to reduce CPU usage (e.g., 0.5s delay).
- **State Management**: Validate state updates and use a single source of truth.

### 5. **Quality-of-Life Features**
- **Configuration Validation**: Add schema checks for settings (e.g., speed/jumpPower ranges).
- **Debug Logging**: Implement a toggleable debug mode with timestamps and module-specific logs.
- **Performance Metrics**: Track FPS and memory usage in `core.lua`.

## Validation Plan
1. **Unit Tests**:
   - Test `DeepCopy` with nested tables and metatables.
   - Validate `GetMM2Murderer` logic with mock data.
2. **Integration Tests**:
   - Verify ESP features across games without leaks.
   - Test UI theme switching for consistency.
3. **Stress Tests**:
   - Simulate 100+ players in MM2 for ESP performance.
   - Rapidly toggle features to check for race conditions.

## Open Questions
1. **Theme Reload**: Should themes be reloadable without restarting? (Recommended: Yes, with cache invalidation).
2. **Auto-Feature Safeguards**: Add distance thresholds for auto-kill/farm? (Recommended: Yes).
3. **Log Storage**: Store debug logs in `UniMenu/logs/` with rotation? (Recommended: Yes).

## Rollout
- Deploy fixes incrementally (utilities → game features → UI).
- Add `/feedback` command for user reports.
- Provide a changelog and updated documentation.

**Next Steps**: Resolve open questions and proceed with implementation.