# UniMenu Modular Refactor

A modular refactor of the Universal Cheat Panel into three `require()` modules to resolve register limit issues.

## Structure

```
UniMenu/
├── Bridge.lua              ← Entry point, shared state, module loader
├── GuiModule.lua           ← UI, themes, animations, HUD, music, ESP, features
└── MM2Module.lua           ← MM2 logic, getters/setters, heartbeat tick loops
```

## Usage

### **Method 1: Direct Execution (Recommended for Loadstring)**

Use `Bridge.lua` as your entry point:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR-USERNAME/UniMenu/main/UniMenu/Bridge.lua"))()
```

### **Method 2: Auto-generated Snapshot**

Create `UniMenu_autorun.lua` (auto-generated) in your repo and use it:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR-USERNAME/UniMenu/main/UniMenu_autorun.lua"))()
```

## Architecture

### **Bridge.lua**
- Entry point and shared state owner
- Owns: S, MM2, gameConfig, Music, Themes, XP, keybinds, Connections
- Loads GuiModule and MM2Module via `require()`
- Calls `GuiModule.Init(deps)` and `MM2Module.Init(deps)`
- Handles persistence and cleanup

### **GuiModule.lua**
- Builds entire UI including MM2 tabs
- Contains: Themes, ESP, Chams, X-Ray, Fullbright, Dark Mode, Night Mode
- Features table with MM2 toggle definitions
- Auto-generated music player with Last.fm integration
- HUD and visual helpers
- Music player with dynamic colors

### **MM2Module.lua**
- MM2 logic, getters/setters, and heartbeat tick loops
- Features:
  - Auto-grab sheriff gun
  - Auto-shoot murderer
  - Magic bullet (predicted throws)
  - Knife kill aura
  - Anti-stab ghost dodge
  - Auto-coin farming
  - Trap ESP & radar
  - Auto-follow, platform mode, boost mode
  - And more...

### **Features Summary**
- **Combat**: Aimbot, Triggerbot, Auto Clicker, Full weapon system
- **Movement**: Speed boost, fly mode, CS2 physics, anti-fling
- **Visuals**: ESP, Chams, X-Ray, Fullbright, Night mode, No VFX, FPS boost
- **MM2**: Auto-gameplay, role detection, ESP & radar
- **Trolling**: Teleportation, flinging, traps, spectating
- **Utilities**: Anti-AFK, copy ID/position, server navigation
- **Themes**: Windows Vista Aero, XP Luna, Dark Obsidian, Crimson Blood, Emerald Cyber, Royal Amethyst

## Configuration

- Configuration is stored in `gameConfig` table and persists via `SaveSettings()`
- Keybinds are managed and restored via `LoadKeybinds()`

## Notes

- All features are toggleable via the UI
- MM2 features can be toggled without MM2 module loaded (disabled)
- Use `S.esp` or `MM2.roleESP` to control visibility
- Modularity allows for easier feature development and maintenance

## Installation

1. Download or clone this repository
2. In Roblox execute one of the loadstring methods above
3. The menu should appear automatically

## Credits

- Original UniMenu by Various Developers
- Modular refactor by Kilo

## Contributing

- For bugs, issues, or feature requests, please create an issue in the repository
- Pull requests are welcome for improvements and bug fixes

## License

MIT License

---

### **Disclaimer**
This script is intended for educational and demonstration purposes only. Users are advised to respect the terms of service of the game they are playing and to use this script responsibly.