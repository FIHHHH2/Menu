-- init.lua
-- Modular Loadstring Entry Point with Cache Busting
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/FIHHHH2/Menu/main/init.lua?t=" .. tick()))()

local commitSha = nil
pcall(function()
    local res = game:HttpGet("https://api.github.com/repos/FIHHHH2/Menu/commits/main?t=" .. tostring(os.time()) .. tostring(math.random(1000, 9999)))
    local data = game:GetService("HttpService"):JSONDecode(res)
    if data and data.sha then
        commitSha = data.sha
    end
end)

local BASE_URL = "https://raw.githubusercontent.com/FIHHHH2/Menu/" .. (commitSha or "main")

local function loadModule(name)
    -- Cache busting prevents GitHub CDN from serving stale code
    local url = BASE_URL .. "/" .. name .. ".lua?t=" .. tostring(os.time()) .. tostring(math.random(1000, 9999))

    local ok, src = pcall(function() return game:HttpGet(url) end)
    if not ok or type(src) ~= "string" or #src == 0 then
        warn("[Menu] HttpGet failed: " .. name .. " -> " .. tostring(src))
        return function() end
    end

    local ls = rawget(getfenv and getfenv(0) or _G, "loadstring") or loadstring
    if type(ls) ~= "function" then
        ls = _G["loadstring"]
    end
    local chunk, cerr = ls(src)
    if type(chunk) ~= "function" then
        warn("[Menu] Compile error: " .. name .. " -> " .. tostring(cerr))
        return function() end
    end

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

-- Universal HTTP Request engine supporting getgenv.request, http_request, syn.request
local function httpRequest(opt)
    local req = (getgenv and (getgenv().request or getgenv().http_request)) or request or http_request or (syn and syn.request)
    if req then
        local ok1, res1 = pcall(function() return req(opt) end)
        if ok1 and res1 then return res1 end

        -- Some executors require lowercase parameters
        local lowerOpt = {
            url     = opt.Url or opt.url,
            method  = opt.Method or opt.method or "GET",
            headers = opt.Headers or opt.headers or {},
            body    = opt.Body or opt.body
        }
        local ok2, res2 = pcall(function() return req(lowerOpt) end)
        if ok2 and res2 then return res2 end
    end
    if (opt.Method == "GET" or not opt.Method) and opt.Url then
        local ok, res = pcall(function() return game:HttpGet(opt.Url) end)
        if ok and res then return { StatusCode = 200, Body = res } end
    end
    return nil
end

-- Shared state table
local Shared = {
    Player      = game:GetService("Players").LocalPlayer,
    Character   = nil,
    HumanoidRP  = nil,
    Services    = {
        Players      = game:GetService("Players"),
        RunService   = game:GetService("RunService"),
        UserInput    = game:GetService("UserInputService"),
        TweenService = game:GetService("TweenService"),
        SoundService = game:GetService("SoundService"),
        Workspace    = game:GetService("Workspace"),
        Http         = game:GetService("HttpService"),
        CoreGui      = game:GetService("CoreGui"),
    },
    HttpRequest = httpRequest,
    Flags       = {},
    Keybinds    = {},
    Toggles     = {},
    Config      = {
        SpotifyToken = "",
        LastFMUser   = "",
        Keybinds     = {},
        Flags        = {},
    },
    GUI         = nil,
    Version     = "3.5.0",
}

Shared.Character  = Shared.Player.Character or Shared.Player.CharacterAdded:Wait()
Shared.HumanoidRP = Shared.Character:WaitForChild("HumanoidRootPart")

Shared.Player.CharacterAdded:Connect(function(char)
    Shared.Character  = char
    Shared.HumanoidRP = char:WaitForChild("HumanoidRootPart")
end)

-- Game Environment Detection
local isMM2 = (game.PlaceId == 142823291 or game.GameId == 66654135 or game.PlaceId == 335132309 or game.PlaceId == 63518381)
Shared.IsMM2 = isMM2

local isNDS = (game.PlaceId == 189707 or game.GameId == 65241)
Shared.IsNDS = isNDS

-- Load order
loadModule("UI_Handler")(Shared)
loadModule("Main_Functions")(Shared)
if isMM2 then
    loadModule("MM2_Functions")(Shared)
end
if isNDS then
    loadModule("NDS_Functions")(Shared)
end
loadModule("Troll_Functions")(Shared)
loadModule("Music_Handler")(Shared)
