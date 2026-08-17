# UniMenu Modular

A fully refactored, high-performance, and modular cheat menu system for Roblox. By splitting the codebase into dedicated modules, UniMenu stays under Luau's 200-local register limit and guarantees maximum speed and expandability.

---

## Architecture Overview

```
UniMenu/
├── loader.lua          # Loader script you paste into your executor
├── core.lua            # Feature registry, game loop, and standard utilities
├── ui.lua              # Window builder, sidebar navigation, themes, HUD, notifications
├── mm2.lua             # MM2-specific ESP, auto-farm, knife/shoot auras, and magic bullet
└── lib/
    ├── utils.lua       # Core mathematics, vectors, and instance helper functions
    └── http.lua        # Generic and resilient executor-agnostic HTTP wrapper
```

---

## How to Execute

To load and run UniMenu, paste this loader code into your executor of choice (e.g., Synapse, Wave, Electron, etc.):

```lua
-- UniMenu Loader - Entry point for modular system
-- Paste this into your executor to load UniMenu

local BASE_URL = "https://raw.githubusercontent.com/FIHHHH2/Menu/main/UniMenu/"

local ctx = {
  Services = {},
  State = { S = {}, MM2 = {}, Music = {} },
  Config = { gameConfig = {}, Themes = {}, currentThemeName = "Windows XP Luna", XP = nil },
  Core = {},
  UI = {},
  Game = {},
  Modules = {}
}

local cache = {}

local function loadModule(name)
  if cache[name] then return cache[name] end
  
  local src
  if typeof(game.HttpGet) == "function" then
    local ok, result = pcall(game.HttpGet, game, BASE_URL .. name .. ".lua")
    if ok and result then src = result end
  end
  
  if not src and typeof(syn) == "table" and typeof(syn.request) == "function" then
    local ok, res = pcall(syn.request, { Url = BASE_URL .. name .. ".lua", Method = "GET" })
    if ok and res and (res.Body or res.body) then
      src = res.Body or res.body
    end
  end
  
  if not src and typeof(request) == "function" then
    local ok, res = pcall(request, { Url = BASE_URL .. name .. ".lua", Method = "GET" })
    if ok and res and (res.Body or res.body) then
      src = res.Body or res.body
    end
  end
  
  if not src then
    error("Failed to load module: " .. name .. " from " .. BASE_URL .. name .. ".lua")
  end
  
  local fn, err = loadstring(src)
  if not fn then
    error("Failed to compile module " .. name .. ": " .. tostring(err))
  end
  
  local ok, result = pcall(fn, ctx)
  if not ok then
    error("Failed to execute module " .. name .. ": " .. tostring(result))
  end
  
  cache[name] = true
  return true
end

-- Load modules in dependency order
loadModule("core")
loadModule("ui")
loadModule("mm2")
loadModule("lib/utils")
loadModule("lib/http")

-- Initialize everything
if ctx.Core.Init then
  ctx.Core.Init()
end
```

### Setup Instructions:
1. Upload your files (`core.lua`, `ui.lua`, `mm2.lua`, `lib/utils.lua`, `lib/http.lua`) to a GitHub repository.
2. Replace `<YOUR-USERNAME>` in the `BASE_URL` on line 4 with your actual GitHub username.
3. Keep the directory structure exactly the same on GitHub.
4. Execute!
