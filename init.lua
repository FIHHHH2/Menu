-- init.lua
-- Modular Loadstring Entry Point with Cache Busting
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/FIHHHH2/Menu-Clean/main/init.lua?t=" .. tick()))()

-- Terminate and disconnect all connections and objects from previous executions
pcall(function()
    local prev = (getgenv and getgenv().FihUI_Cleanup) or (rawget(_G, "FihUI_Cleanup"))
    if type(prev) == "function" then
        if getgenv then getgenv().FihUI_Cleanup = nil end
        _G.FihUI_Cleanup = nil
        prev()
    end
end)

local BASE_URL = "https://raw.githubusercontent.com/FIHHHH2/Menu-Clean/main"

-- Safe Service Initializer
local function getService(name)
    local ok, s = pcall(function() return game:GetService(name) end)
    return ok and s or nil
end

local PlayersService = getService("Players") or game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer
if not localPlayer then
    local startTime = os.clock()
    while not localPlayer and (os.clock() - startTime < 5) do
        localPlayer = PlayersService.LocalPlayer
        task.wait(0.05)
    end
end

local function loadModule(name)
    -- Local Studio / ModuleScript direct require support (Bypasses Studio loadstring block)
    local rep = getService("ReplicatedStorage")
    if rep then
        local localFolder = rep:FindFirstChild("FihMenu")
        if localFolder and localFolder:FindFirstChild(name) then
            local targetMod = localFolder:FindFirstChild(name)
-- Universal HTTP Request engine with multi-executor normalization
local function httpRequest(opt)
    local env = (getgenv and getgenv()) or (getfenv and getfenv(0)) or _G
    local req = rawget(env, "request")
             or rawget(env, "http_request")
             or (getgenv and (getgenv().request or getgenv().http_request))
             or (typeof(request) == "function" and request)
             or (typeof(http_request) == "function" and http_request)
             or (syn and typeof(syn.request) == "function" and syn.request)
             or (http and typeof(http.request) == "function" and http.request)
             or (fluxus and typeof(fluxus.request) == "function" and fluxus.request)
             or (krnl and typeof(krnl.request) == "function" and krnl.request)

    local function normalize(res)
        if not res then return nil end
        if type(res) == "string" then
            return { Body = res, body = res, StatusCode = 200, statusCode = 200, status_code = 200, Success = true, Headers = {}, headers = {} }
        end
        if type(res) ~= "table" then return res end
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

    local urlStr = opt.Url or opt.url
    local methodStr = opt.Method or opt.method or "GET"

    if req then
        local ok1, res1 = pcall(function() return req(opt) end)
        if ok1 and res1 then return normalize(res1) end

        local lowerOpt = {
            url     = urlStr,
            method  = methodStr,
            headers = opt.Headers or opt.headers or {},
            body    = opt.Body or opt.body
        }
        local ok2, res2 = pcall(function() return req(lowerOpt) end)
        if ok2 and res2 then return normalize(res2) end
    end

    -- Fallback via HttpGet
    if (methodStr == "GET" or not methodStr) and urlStr then
        local ok, res = pcall(function() return game:HttpGet(urlStr) end)
        if ok and res and type(res) == "string" then
            return normalize({ StatusCode = 200, Body = res })
        end
    end

    return nil
end

local function loadModule(name)
    -- Local Studio / ModuleScript direct require support (Bypasses Studio loadstring block)
    local rep = getService("ReplicatedStorage")
    if rep then
        local localFolder = rep:FindFirstChild("FihMenu")
        if localFolder and localFolder:FindFirstChild(name) then
            local targetMod = localFolder:FindFirstChild(name)
            if targetMod and targetMod:IsA("ModuleScript") then
                local okReq, mod = pcall(require, targetMod)
                if okReq and type(mod) == "function" then
                    return mod
                end
            end
        end
    end

    -- Dynamic Cache Busting Request
    local url = BASE_URL .. "/" .. name .. ".lua?_t=" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
    local resp = httpRequest({
        Url = url,
        Method = "GET",
        Headers = {
            ["Cache-Control"] = "no-cache, no-store, must-revalidate",
            ["Pragma"] = "no-cache"
        }
    })

    local src = (resp and resp.Body) or ""
    if #src == 0 then
        local ok, fallbackSrc = pcall(function() return game:HttpGet(url) end)
        if ok and type(fallbackSrc) == "string" then src = fallbackSrc end
    end

    if #src == 0 then
        warn("[Menu-Clean] Failed to fetch module: " .. name .. " (URL: " .. url .. ")")
        return function() end
    end

    local ls = rawget(getfenv and getfenv(0) or _G, "loadstring") or loadstring
    if type(ls) ~= "function" then
        ls = _G["loadstring"]
    end
    if type(ls) ~= "function" then
        warn("[Menu] No valid loadstring function available for: " .. name)
        return function() end
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

-- Comprehensive Cleanup & Residual Purge Engine
local function purgeAllResiduals()
    local containers = {}
    local cg = getService("CoreGui")
    if cg then table.insert(containers, cg) end

    pcall(function()
        local gethui = rawget(getfenv and getfenv(0) or _G, "gethui") or (getgenv and getgenv().gethui)
        if type(gethui) == "function" then
            local hui = gethui()
            if hui and not table.find(containers, hui) then table.insert(containers, hui) end
        end
    end)

    pcall(function()
        local lp = localPlayer or PlayersService.LocalPlayer
        if lp then
            local pg = lp:FindFirstChildOfClass("PlayerGui")
            if pg and not table.find(containers, pg) then table.insert(containers, pg) end
        end
    end)

    local ws = getService("Workspace") or workspace
    if ws then table.insert(containers, ws) end

    if ws and ws.CurrentCamera and not table.find(containers, ws.CurrentCamera) then
        table.insert(containers, ws.CurrentCamera)
    end

    for _, container in ipairs(containers) do
        if container then
            pcall(function()
                for _, child in ipairs(container:GetChildren()) do
                    if child then
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
                end
            end)
        end
    end

    pcall(function()
        for _, p in ipairs(PlayersService:GetPlayers()) do
            if p and p.Character then
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
    Player      = localPlayer,
    Character   = nil,
    HumanoidRP  = nil,
    Services    = {
        Players      = PlayersService,
        RunService   = getService("RunService") or game:GetService("RunService"),
        UserInput    = getService("UserInputService") or game:GetService("UserInputService"),
        TweenService = getService("TweenService") or game:GetService("TweenService"),
        SoundService = getService("SoundService") or game:GetService("SoundService"),
        Workspace    = getService("Workspace") or workspace,
        Http         = getService("HttpService") or game:GetService("HttpService"),
        CoreGui      = getService("CoreGui"),
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
    Version     = "3.5.1",
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
    pcall(function()
        if writefile and Shared.Services.Http then
            writefile(CONFIG_FILE, Shared.Services.Http:JSONEncode(Shared.Config))
        end
    end)
end
local function loadConfig()
    pcall(function()
        if readfile and Shared.Services.Http then
            local src = readfile(CONFIG_FILE)
            if src and #src > 2 then
                local data = Shared.Services.Http:JSONDecode(src)
                if type(data) == "table" then
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
    end)
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

-- Character and RootPart initial bind
if Shared.Player then
    Shared.Character = Shared.Player.Character
    if Shared.Character then
        Shared.HumanoidRP = Shared.Character:FindFirstChild("HumanoidRootPart") or Shared.Character:WaitForChild("HumanoidRootPart", 3)
    end
    Shared.Player.CharacterAdded:Connect(function(char)
        Shared.Character  = char
        Shared.HumanoidRP = char:WaitForChild("HumanoidRootPart", 5) or char:FindFirstChild("HumanoidRootPart")
    end)
end

-- Load order with zero-freeze staggered micro-yields
loadModule("UI_Handler")(Shared)
task.wait(0.01)
loadModule("Core_Functions")(Shared)
task.wait(0.01)
loadModule("Music_Handler")(Shared)

return Shared
