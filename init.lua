-- init.lua
-- Modular Loadstring Entry Point with Cache Busting
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/FIHHHH2/Menu/main/init.lua?t=" .. tick()))()

-- Terminate and disconnect all connections and objects from previous executions
pcall(function()
    local prev = (getgenv and getgenv().FihUI_Cleanup) or (rawget(_G, "FihUI_Cleanup"))
    if type(prev) == "function" then
        if getgenv then getgenv().FihUI_Cleanup = nil end
        _G.FihUI_Cleanup = nil
        prev()
    end
end)

local BASE_URL = "https://raw.githubusercontent.com/FIHHHH2/Menu/main"

local function loadModule(name)
    -- Local Studio / ModuleScript direct require support (Bypasses Studio loadstring block)
    local rep = game:GetService("ReplicatedStorage")
    local localFolder = rep:FindFirstChild("FihMenu")
    if localFolder and localFolder:FindFirstChild(name) then
        local targetMod = localFolder:FindFirstChild(name)
        if targetMod:IsA("ModuleScript") then
            local okReq, mod = pcall(require, targetMod)
            if okReq and type(mod) == "function" then
                return mod
            end
        end
    end

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
        local ok1, res1 = pcall(function() return req(opt) end)
        if ok1 and res1 then return normalize(res1) end

        local lowerOpt = {
            url     = opt.Url or opt.url,
            method  = opt.Method or opt.method or "GET",
            headers = opt.Headers or opt.headers or {},
            body    = opt.Body or opt.body
        }
        local ok2, res2 = pcall(function() return req(lowerOpt) end)
        if ok2 and res2 then return normalize(res2) end
    end

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

-- Comprehensive Cleanup & Residual Purge Engine (Instantaneous, non-blocking)
local function purgeAllResiduals()
    local containers = {}
    pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
    pcall(function()
        local gethui = rawget(getfenv and getfenv(0) or _G, "gethui") or (getgenv and getgenv().gethui)
        if type(gethui) == "function" then
            local hui = gethui()
            if hui and not table.find(containers, hui) then table.insert(containers, hui) end
        end
    end)
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        if lp then
            local pg = lp:FindFirstChildOfClass("PlayerGui")
            if pg and not table.find(containers, pg) then table.insert(containers, pg) end
        end
    end)
    pcall(function() table.insert(containers, game:GetService("Workspace")) end)
    pcall(function()
        if workspace.CurrentCamera and not table.find(containers, workspace.CurrentCamera) then
            table.insert(containers, workspace.CurrentCamera)
        end
    end)

    for _, container in ipairs(containers) do
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                local n = child.Name
                local isOurs = (n == "IE7_Menu" or n == "FihUi" or n == "Fih_CustomLeaderboard" or n == "Fih_CustomChat"
                    or n == "Fih_BottomHUD" or n == "Fih_ArtworkBillboard" or n == "Fih_NotifHub" or n == "Fih_SpyWindow"
                    or n == "Fih_TrollPanel" or n == "FihUI_ScreenGui" or n == "Fih_SongTitlePopup" or n == "Fih_GodPlatform"
                    or n:find("^Fih_") or n:find("^ESP_") or n:find("^Chams_") or n:find("^AeroChams")
                    or n:find("^UniversalESP") or n:find("^RoleESP") or n:find("^CoinESP") or n:find("^GunESP")
                    or n:find("^KillAuraBox") or n:find("^BB_BallESP") or n:find("^BB_ParryZone")
                    or n:find("^NDS_GodPlat") or n:find("^NDS_ShieldPart") or n:find("^PeerRadar"))

                if not isOurs and child:IsA("ScreenGui") then
                    if child:FindFirstChild("MainFrame") or child:FindFirstChild("QuadGrid") or child:FindFirstChild("TitleBar") or child:FindFirstChild("Fih_CustomLeaderboard") or child:FindFirstChild("Fih_BottomHUD") then
                        isOurs = true
                    end
                end

                if isOurs then
                    pcall(function() child:Destroy() end)
                end
            end
        end)
    end

    pcall(function()
        local Players = game:GetService("Players")
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                for _, d in ipairs(p.Character:GetChildren()) do
                    if d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("SelectionBox") or d:IsA("BoxHandleAdornment") or d:IsA("CylinderHandleAdornment") then
                        if d.Name:find("^Fih_") or d.Name:find("^ESP_") or d.Name:find("^Chams_") or d.Name:find("^AeroChams") or d.Name:find("^BB_") or d.Name:find("^NDS_") then
                            pcall(function() d:Destroy() end)
                        end
                    elseif d:IsA("BodyVelocity") or d:IsA("BodyGyro") or d:IsA("BodyPosition") then
                        if d.Name == "flightBV" or d.Name == "balloonBV" or d.Name:find("Fih") then
                            pcall(function() d:Destroy() end)
                        end
                    end
                end
            end
        end
    end)
end

purgeAllResiduals()

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
    Sliders     = {},
    Cleanups    = {},
    Config      = {
        SpotifyToken        = "",
        SpotifyRefreshToken = "",
        SpotifyClientID     = "",
        LastFMUser          = "",
        Keybinds            = {},
        Flags               = {},
    },
    GUI         = nil,
    Version     = "3.5.0",
}

local function addCleanup(item)
    if not item then return end
    table.insert(Shared.Cleanups, item)
end

local function cleanupAll()
    for _, item in ipairs(Shared.Cleanups) do
        pcall(function()
            if typeof(item) == "RBXScriptConnection" then
                item:Disconnect()
            elseif type(item) == "function" then
                item()
            elseif typeof(item) == "Instance" then
                item:Destroy()
            end
        end)
    end
    Shared.Cleanups = {}
    purgeAllResiduals()
end

Shared.AddCleanup = addCleanup
Shared.CleanupAll = cleanupAll
if getgenv then getgenv().FihUI_Cleanup = cleanupAll end
_G.FihUI_Cleanup = cleanupAll

-- Config persistence (writefile / readfile if executor supports it)
local CONFIG_FILE = "FihUi_Config.json"
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
            if data.Flags and type(data.Flags) == "table" then
                for k, v in pairs(data.Flags) do
                    Shared.Flags[k] = v
                end
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

-- Game Environment Detection (Multi-tier identification)
-- Detection happens here but MM2_Functions always loads regardless — it self-guards via Tabs["MM2"] check
local isMM2 = (game.PlaceId == 142823291 or game.GameId == 66654135 or game.PlaceId == 335132309 or game.PlaceId == 63518381)
if not isMM2 then
    pcall(function()
        local rep = game:GetService("ReplicatedStorage")
        -- Check common MM2 remote structures
        if rep:FindFirstChild("Remotes") and rep.Remotes:FindFirstChild("Gameplay") then
            isMM2 = true
        elseif rep:FindFirstChild("WeaponEvents") and rep.WeaponEvents:FindFirstChild("GunBeam") then
            isMM2 = true
        end
        -- Check PlayerGui for MM2 specific GUIs
        local lp = game:GetService("Players").LocalPlayer
        if lp and lp:FindFirstChild("PlayerGui") then
            local pg = lp.PlayerGui
            if pg:FindFirstChild("MainGUI") or pg:FindFirstChild("MainGui") or pg:FindFirstChild("MM2") then
                isMM2 = true
            end
        end
        -- Check Workspace for MM2 specific map objects
        if game.Workspace:FindFirstChild("Lobby") or game.Workspace:FindFirstChild("Map") then
            -- Could be MM2, check for coin spawners or lobby markers
            if game.Workspace:FindFirstChild("Coins") or game.Workspace:FindFirstChild("CoinSpawner") then
                isMM2 = true
            end
        end
    end)
end
Shared.IsMM2 = isMM2


local isNDS = (game.PlaceId == 189707 or game.GameId == 65241)
Shared.IsNDS = isNDS

local isBladeBall = (game.PlaceId == 13772394625 or game.PlaceId == 14732610803 or game.PlaceId == 15131065025 or game.PlaceId == 15264892126 or game.PlaceId == 17135832729 or game.PlaceId == 15552588147 or game.GameId == 4777817887)
Shared.IsBladeBall = isBladeBall

-- Load order with zero-freeze staggered micro-yields
loadModule("UI_Handler")(Shared)
task.wait(0.01)
loadModule("Core_Functions")(Shared)
task.wait(0.01)
loadModule("Main_Functions")(Shared)
task.wait(0.01)
loadModule("Spy_Functions")(Shared)
task.wait(0.01)
-- MM2_Functions always loads — it self-guards via Tabs["MM2"] nil check at line 22.
-- If UI_Handler detected MM2 via its own fallback, the tab+cols will exist and MM2_Functions will populate them.
-- If this game is not MM2, Tabs["MM2"] will be nil and MM2_Functions returns immediately (no cost).
loadModule("MM2_Functions")(Shared)
task.wait(0.01)

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

return Shared
