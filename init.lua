-- init.lua
-- Loadstring entry: load this to bootstrap the entire menu
-- Usage: loadstring(game:HttpGet("YOUR_RAW_URL/init.lua"))()

local BASE_URL = "https://raw.githubusercontent.com/FIHHHH2/Menu/refs/heads/main"

local function loadModule(name)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. "/" .. name .. ".lua"))()
    end)
    if not ok then
        warn("[Menu] Failed to load module: " .. name .. " | " .. tostring(result))
    end
    return result
end

-- Shared state table passed between all modules
local Shared = {
    Player       = game:GetService("Players").LocalPlayer,
    Character    = nil,
    HumanoidRP   = nil,
    Services     = {
        Players      = game:GetService("Players"),
        RunService   = game:GetService("RunService"),
        UserInput    = game:GetService("UserInputService"),
        TweenService = game:GetService("TweenService"),
        SoundService = game:GetService("SoundService"),
        Workspace    = game:GetService("Workspace"),
        Http         = game:GetService("HttpService"),
        CoreGui      = game:GetService("CoreGui"),
    },
    Flags        = {}, -- all toggle states live here
    GUI          = nil, -- set by UI_Handler
    Version      = "1.0.0",
}

Shared.Character = Shared.Player.Character or Shared.Player.CharacterAdded:Wait()
Shared.HumanoidRP = Shared.Character:WaitForChild("HumanoidRootPart")

Shared.Player.CharacterAdded:Connect(function(char)
    Shared.Character    = char
    Shared.HumanoidRP   = char:WaitForChild("HumanoidRootPart")
end)

-- Load order matters
loadModule("UI_Handler")(Shared)
loadModule("Main_Functions")(Shared)
loadModule("MM2_Functions")(Shared)
loadModule("Spotify_Handler")(Shared)
