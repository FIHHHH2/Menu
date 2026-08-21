-- UniMenu Loader - Entry point for modular system
-- Paste this into your executor to load UniMenu

local BASE_URL = "https://raw.githubusercontent.com/FIHHHH2/Menu/main/UniMenu/"

local ctx = {
    Services = {},
    State = {
        S = {},
        MM2 = {},
        Music = {},
    },
    Config = {
        gameConfig = {},
        Themes = {},
        currentThemeName = "Windows XP Luna",
        XP = nil,
    },
    Core = {},
    UI = {},
    Game = {},
    Modules = {},
    Connections = {},
}

local cache = {}

local function loadModule(name)
    if cache[name] then
        return cache[name]
    end

    local src
    if typeof(game.HttpGet) == "function" then
        local ok, result = pcall(game.HttpGet, game, BASE_URL .. name .. ".lua")
        if ok and result then
            src = result
        end
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

-- ==================== GAME DETECTION ====================
local gameId = game.PlaceId
local isMM2 = (gameId == 142823291)  -- Murder Mystery 2 PlaceId

-- ==================== LOAD MODULES IN DEPENDENCY ORDER ====================
-- Always load these core modules
loadModule("utils")      -- Shared utilities
loadModule("core")       -- Core services, state, peer detection
loadModule("main_ui")    -- Main UI and universal features

-- Conditionally load game-specific modules
if isMM2 then
    print("[UniMenu] MM2 detected, loading MM2 module...")
    loadModule("mm2")
end

-- ==================== INITIALIZATION ====================
task.wait(0.5)  -- Allow modules to initialize

-- Initialize core systems
if ctx.Core and ctx.Core.BroadcastPeerData then
    ctx.Core.BroadcastPeerData()
end

if ctx.Core and ctx.Core.ScanPeers then
    ctx.Core.ScanPeers()
end

-- Initialize UI if available
if ctx.UI and ctx.UI.BuildGUI then
    print("[UniMenu] Initialized successfully! Press RightShift to open.")
end

-- Auto-save settings periodically
task.spawn(function()
    while task.wait(30) do
        -- Settings persistence would go here
    end
end)

-- Cleanup on script termination
game:GetService("Players").LocalPlayer.AncestryChanged:Connect(function(_, parent)
    if not parent then
        for _, conn in ipairs(ctx.Connections or {}) do
            if conn and conn.Disconnect then
                conn:Disconnect()
            end
        end
    end
end)