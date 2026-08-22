-- init.lua
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/FIHHHH2/Menu/main/init.lua"))()

local BASE_URL = "https://raw.githubusercontent.com/FIHHHH2/Menu/main"

local function loadModule(name)
    local url = BASE_URL .. "/" .. name .. ".lua"

    -- Step 1: fetch source
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if not ok or type(src) ~= "string" or #src == 0 then
        warn("[Menu] HttpGet failed: " .. name .. " -> " .. tostring(src))
        return function() end
    end

    -- Step 2: compile
    -- Use rawget to grab loadstring from env in case executor shadows it
    local ls = rawget(getfenv and getfenv(0) or _G, "loadstring") or loadstring
    if type(ls) ~= "function" then
        -- fallback: some executors expose it differently
        ls = _G["loadstring"]
    end
    local chunk, cerr = ls(src)
    if type(chunk) ~= "function" then
        warn("[Menu] Compile error: " .. name .. " -> " .. tostring(cerr))
        return function() end
    end

    -- Step 3: execute chunk (returns the module's function(Shared) wrapper)
    local ok2, mod = pcall(chunk)
    if not ok2 then
        warn("[Menu] Exec error: " .. name .. " -> " .. tostring(mod))
        return function() end
    end
    if type(mod) ~= "function" then
        warn("[Menu] Module did not return function: " .. name .. " (got " .. type(mod) .. ")")
        return function() end
    end
    return mod
end

-- Shared state table
local Shared = {
    Player     = game:GetService("Players").LocalPlayer,
    Character  = nil,
    HumanoidRP = nil,
    Services   = {
        Players      = game:GetService("Players"),
        RunService   = game:GetService("RunService"),
        UserInput    = game:GetService("UserInputService"),
        TweenService = game:GetService("TweenService"),
        SoundService = game:GetService("SoundService"),
        Workspace    = game:GetService("Workspace"),
        Http         = game:GetService("HttpService"),
        CoreGui      = game:GetService("CoreGui"),
    },
    Flags   = {},
    GUI     = nil,
    Version = "1.0.0",
}

Shared.Character  = Shared.Player.Character or Shared.Player.CharacterAdded:Wait()
Shared.HumanoidRP = Shared.Character:WaitForChild("HumanoidRootPart")

Shared.Player.CharacterAdded:Connect(function(char)
    Shared.Character  = char
    Shared.HumanoidRP = char:WaitForChild("HumanoidRootPart")
end)

-- Load order matters
loadModule("UI_Handler")(Shared)
loadModule("Main_Functions")(Shared)
loadModule("MM2_Functions")(Shared)
loadModule("Spotify_Handler")(Shared)
