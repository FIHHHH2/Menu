# Modular Overhaul Plan

## Goal
Refactor the codebase into 5 compact, independent modules to improve maintainability and reduce update breaks.

## Module Structure

### 1. **Core Module** (`core.lua`)
- **Purpose**: Shared utilities, state management, and essential hooks.
- **Contents**:
  - Global state container (`ctx`)
  - Common functions: `Animate`, `TrackConnection`, `ShowNotification`
  - Attribute-based peer detection system
  - Basic UI components (buttons, labels)
- **Dependencies**: None

### 2. **Main UI Module** (`main_ui.lua`)
- **Purpose**: Universal UI and non-game-specific features.
- **Contents**:
  - Main menu, tabs, settings
  - Keybind management
  - Generic ESP/Chams systems
  - Music integration (Last.fm/Spotify)
- **Dependencies**: `core.lua`

### 3. **Murder Mystery Module** (`mm2.lua`)
- **Purpose**: Game-specific features for Murder Mystery 2.
- **Contents**:
  - Role-based ESP (Sheriff/Murderer/Innocent)
  - Gun/Trap/Coin ESP
  - Auto-shoot/auto-grab logic
- **Dependencies**: `core.lua`

### 4. **Utility Module** (`utils.lua`)
- **Purpose**: Shared helper functions and constants.
- **Contents**:
  - Color math, HTTP wrappers
  - UI positioning utilities
  - Game config constants
- **Dependencies**: None

### 5. **Loader Module** (`loader.lua`)
- **Purpose**: Conditional module loading based on game detection.
- **Contents**:
  - Game detection via `game.PlaceId`
  - Module loading order management
  - Error handling for failed loads
- **Dependencies**: `core.lua`, `utils.lua`

---

## **Key Changes**

1. **Dependency Isolation**
   - Modules only import `core.lua` or `utils.lua`
   - Game-specific modules don't reference other game modules

2. **State Management**
   - All shared state in `ctx` (initialized in `core.lua`)
   - No direct module-to-module state access

3. **UI Consolidation**
   - Generic UI in `main_ui.lua`
   - Game-specific UI in respective modules

4. **Error Resilience**
   - `pcall` wrapping in loader
   - Graceful degradation for game-specific features

---

## **Implementation Steps**

1. **Create Core Module**
   - Move state, utilities, peer detection to `core.lua`

2. **Refactor Main UI**
   - Merge `ui.lua` into `main_ui.lua`, removing game-specific code

3. **Extract MM2 Module**
   - Move Murder Mystery 2 logic to `mm2.lua`

4. **Create Utility Module**
   - Extract helpers into `utils.lua`

5. **Update Loader**
   - Add game detection via `game.PlaceId`
   - Load modules conditionally (e.g., load `mm2.lua` only if in MM2)

6. **Validate Independence**
   - Test modules in isolation
   - Ensure no circular dependencies

---

## **Validation Plan**

1. **Unit Tests**
   - Test core utilities and loader logic

2. **Game-Specific Tests**
   - Test MM2 features in Murder Mystery 2
   - Verify no errors in other games

3. **Update Simulation**
   - Introduce breaking changes to test adaptability

---

## **Open Questions (Resolved)**

1. **Additional Game Modules**: Only MM2 for now.
2. **Core Features**: Keep game-agnostic features (speed, etc.) in `core.lua`.
3. **Game Detection**: Use `game.PlaceId`.

## **Final Structure**
```
UniMenu/
├── core.lua
├── main_ui.lua
├── mm2.lua
├── utils.lua
└── loader.lua
```

**Next Step**: Proceed with implementation.