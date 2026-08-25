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

-- Universal HTTP Request engine with multi-executor normalization
local function httpRequest(opt)
    local req = (getgenv and (getgenv().request or getgenv().http_request))
             or (typeof(request) == "function" and request)
             or (typeof(http_request) == "function" and http_request)
             or (syn and typeof(syn.request) == "function" and syn.request)
             or (http and typeof(http.request) == "function" and http.request)

    local function normalize(res)
        if not res or type(res) ~= "table" then return res end
        local body = res.Body or res.body or ""
        local code = tonumber(res.StatusCode or res.statusCode or res.status_code or res.Status or res.status) or 200
        local hdrs = res.Headers or res.headers or {}
        return {
            Body        = body,
            body        = body,
            StatusCode  = code,
            statusCode  = code,
            status_code = code,
            Headers     = hdrs,
            headers     = hdrs,
            Success     = (code >= 200 and code < 300)
        }
    end

    if req then
        -- 1. Try standard uppercase option keys
        local ok1, res1 = pcall(function() return req(opt) end)
        if ok1 and res1 then return normalize(res1) end

        -- 2. Try lowercase option keys (Fluxus, Delta, Solara variants)
        local lowerOpt = {
            url     = opt.Url or opt.url,
            method  = opt.Method or opt.method or "GET",
            headers = opt.Headers or opt.headers or {},
            body    = opt.Body or opt.body
        }
        local ok2, res2 = pcall(function() return req(lowerOpt) end)
        if ok2 and res2 then return normalize(res2) end
    end

    -- Fallback to game:HttpGet ONLY for unauthenticated public GET requests
    local hasAuth = (opt.Headers and (opt.Headers["Authorization"] or opt.Headers["authorization"]))
                 or (opt.headers and (opt.headers["Authorization"] or opt.headers["authorization"]))
    if not hasAuth and (opt.Method == "GET" or not opt.Method) and (opt.Url or opt.url) then
        local ok, res = pcall(function() return game:HttpGet(opt.Url or opt.url) end)
        if ok and res and type(res) == "string" and #res > 0 then
            return normalize({ StatusCode = 200, Body = res })
        end
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
        SpotifyToken        = "",
        LastFMUser          = "",
        Keybinds            = {},
        Flags               = {},
    },
    GUI         = nil,
    Version     = "3.5.0",
}

-- Config persistence (writefile / readfile if executor supports it)
local CONFIG_FILE = "fih_config.json"
local function saveConfig()
    if not pcall(function() writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode(Shared.Config)) end) then end
end
local function loadConfig()
    local ok, src = pcall(function() return readfile(CONFIG_FILE) end)
    if ok and src and #src > 2 then
        local ok2, data = pcall(function() return game:GetService("HttpService"):JSONDecode(src) end)
        if ok2 and type(data) == "table" then
            for k, v in pairs(data) do
                Shared.Config[k] = v
            end
        end
    end
end
pcall(loadConfig)
Shared.SaveConfig = saveConfig

-- SpotifyHTTP: guaranteed header-carrying request for Spotify API endpoints
-- Uses executor's raw request function, never falls back to game:HttpGet (which strips headers)
local function spotifyHTTP(opt)
    local req = (getgenv and (getgenv().request or getgenv().http_request))
             or (typeof(request)      == "function" and request)
             or (typeof(http_request) == "function" and http_request)
             or (syn and syn.request)
             or (http and http.request)
    if not req then return nil, "No executor request function found" end

    -- Try uppercase keys first (most executors)
    local ok1, res1 = pcall(req, opt)
    if ok1 and res1 then return res1 end

    -- Try lowercase keys (some executors like Fluxus)
    local ok2, res2 = pcall(req, {
        url     = opt.Url,
        method  = opt.Method or "GET",
        headers = opt.Headers or {},
        body    = opt.Body,
    })
    if ok2 and res2 then return res2 end

    return nil, "Request failed"
end
Shared.SpotifyHTTP = spotifyHTTP

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

local isBladeBall = (game.PlaceId == 13772394625 or game.PlaceId == 14732610803 or game.PlaceId == 15131065025 or game.PlaceId == 15264892126 or game.PlaceId == 17135832729 or game.PlaceId == 15552588147 or game.GameId == 4777817887)
Shared.IsBladeBall = isBladeBall

-- Load order with zero-freeze staggered micro-yields
loadModule("UI_Handler")(Shared)
task.wait(0.01)
loadModule("Main_Functions")(Shared)
task.wait(0.01)
loadModule("Spy_Functions")(Shared)
task.wait(0.01)
if isMM2 then
    loadModule("MM2_Functions")(Shared)
    task.wait(0.01)
end
if isNDS then
    loadModule("NDS_Functions")(Shared)
    task.wait(0.01)
end
if isBladeBall then
    loadModule("BladeBall_Functions")(Shared)
    task.wait(0.01)
end
loadModule("Troll_Functions")(Shared)
task.wait(0.01)
loadModule("Music_Handler")(Shared)
