-- UniMenu Core Module
-- Shared services, state, utilities, and peer detection

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

-- ==================== SERVICES ====================
ctx.Services.Players = game:GetService("Players")
ctx.Services.RunService = game:GetService("RunService")
ctx.Services.UserInputService = game:GetService("UserInputService")
ctx.Services.TweenService = game:GetService("TweenService")
ctx.Services.TeleportService = game:GetService("TeleportService")
ctx.Services.SoundService = game:GetService("SoundService")
ctx.Services.Lighting = game:GetService("Lighting")
ctx.Services.HttpService = game:GetService("HttpService")
ctx.Services.PhysicsService = game:GetService("PhysicsService")
ctx.Services.PathfindingService = game:GetService("PathfindingService")
ctx.Services.ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = ctx.Services.Players
local RunService = ctx.Services.RunService
local UserInputService = ctx.Services.UserInputService
local TweenService = ctx.Services.TweenService
local TeleportService = ctx.Services.TeleportService
local SoundService = ctx.Services.SoundService
local Lighting = ctx.Services.Lighting
local HttpService = ctx.Services.HttpService
local ReplicatedStorage = ctx.Services.ReplicatedStorage

local player = Players.LocalPlayer
while not player do task.wait() player = Players.LocalPlayer end
local PlayerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ==================== CONNECTIONS TRACKING ====================
local Connections = {}
local function TrackConnection(conn)
    table.insert(Connections, conn)
    return conn
end

ctx.Core.TrackConnection = TrackConnection
ctx.Core.Connections = Connections

-- ==================== SHARED STATE DEFAULTS ====================
ctx.State.S = {
    esp = false,
    fullbright = false,
    triggerbot = false,
    showPeerIcon = false,
    fly = false,
    noclip = false,
    speed = 16,
    jumpPower = 50,
    infJump = false,
}

ctx.State.Music = {
    song = "",
    artist = "",
    album = "",
    active = false,
    user = "",
    apiKey = "",
    peerIcon = "rbxassetid://6274377121",
    coverAsset = "",
    coverIsProcedural = false,
    statusText = "Not connected",
    spotify = {
        clientId = "",
        accessToken = "",
        refreshToken = "",
        connected = false,
    },
}

ctx.State.MM2 = {
    roleESP = false,
    coinESP = false,
    autoKillMurderer = false,
    killEveryone = false,
    autoDodgeKnife = false,
    autoGrabGun = false,
    coinAutoFarm = false,
    lastCoinFarmTime = 0,
    coinFarmDelay = 0.5,
    lastGrabTime = 0,
    grabDelay = 1.0,
}

-- ==================== FPS STATE ====================
local FPS_SAMPLES = 30
local fpsSampleBuf = {}
local fpsSampleIdx = 0

local function GetFPSColor(fps)
    if fps >= 55 then
        return Color3.fromRGB(50, 220, 100)
    elseif fps >= 30 then
        local t = (fps - 30) / 25
        return Color3.fromRGB(math.floor(50 + 170 * (1 - t)), 220, math.floor(100 * t))
    elseif fps >= 15 then
        return Color3.fromRGB(255, 190, 30)
    else
        return Color3.fromRGB(255, 50, 50)
    end
end

ctx.Core.GetFPSColor = GetFPSColor

-- ==================== CHARACTER HELPERS ====================
local function GetCharacter()
    return player.Character
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRoot()
    local char = GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
end

ctx.Core.GetCharacter = GetCharacter
ctx.Core.GetHumanoid = GetHumanoid
ctx.Core.GetRoot = GetRoot

-- ==================== PEER DETECTION ====================
local S = ctx.State.S
local Music = ctx.State.Music
local peerBillboards = {}
local peerBroadcastTimer = 0
local espFolder = Instance.new("Folder")
espFolder.Name = "UniMenu_ESP"
espFolder.Parent = workspace
S.espFolder = espFolder

local function RemovePeerBillboard(plr)
    local bb = peerBillboards[plr.Name]
    if bb then
        bb:Destroy()
        peerBillboards[plr.Name] = nil
    end
end

local function CreatePeerBillboard(plr)
    if plr == player then return end
    RemovePeerBillboard(plr)
    
    local attr = plr:GetAttribute("UniMenu_Peer")
    if not attr then return end
    
    local ok, data = pcall(function() return HttpService:JSONDecode(attr) end)
    if not ok or not data or data.scriptVersion ~= "1.0.1" then return end
    
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not hrp then return end
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "UniMenu_Peer_" .. plr.Name .. "_Tag"
    bb.Adornee = hrp
    bb.Size = UDim2.new(0, 120, 0, 44)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 150
    bb.Parent = espFolder
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bg.BackgroundTransparency = 0.15
    bg.BorderSizePixel = 1
    bg.BorderColor3 = Color3.fromRGB(100, 100, 255)
    bg.Parent = bb
    
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "AvatarImage"
    avatar.Size = UDim2.new(0, 30, 0, 30)
    avatar.Position = UDim2.new(0, 4, 0, 4)
    avatar.BackgroundTransparency = 1
    avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=150&h=150"
    avatar.Parent = bg
    
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 22, 0, 22)
    icon.Position = UDim2.new(0, 38, 0, 4)
    icon.BackgroundTransparency = 1
    icon.Image = data.icon or "rbxassetid://6274377121"
    icon.Parent = bg
    
    local songLbl = Instance.new("TextLabel")
    songLbl.Size = UDim2.new(1, -30, 0, 16)
    songLbl.Position = UDim2.new(0, 62, 0, 4)
    songLbl.Text = "♪ " .. (data.song or "No song")
    songLbl.TextColor3 = data.active and Color3.fromRGB(50, 255, 140) or Color3.fromRGB(200, 200, 200)
    songLbl.BackgroundTransparency = 1
    songLbl.Font = Enum.Font.GothamBold
    songLbl.TextSize = 9
    songLbl.TextXAlignment = Enum.TextXAlignment.Left
    songLbl.TextTruncate = Enum.TextTruncate.AtEnd
    songLbl.Parent = bg
    
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -8, 0, 14)
    nameLbl.Position = UDim2.new(0, 4, 0, 24)
    nameLbl.Text = "@" .. plr.Name
    nameLbl.TextColor3 = Color3.fromRGB(100, 100, 255)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 8
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = bg
    
    peerBillboards[plr.Name] = bb
    
    local function UpdateContent()
        local newAttr = plr:GetAttribute("UniMenu_Peer")
        if not newAttr then
            RemovePeerBillboard(plr); return
        end
        local newData = HttpService:JSONDecode(newAttr)
        if not newData or newData.scriptVersion ~= "1.0.1" then
            RemovePeerBillboard(plr); return
        end
        data = newData
        icon.Image = data.icon or "rbxassetid://6274377121"
        songLbl.Text = "♪ " .. (data.song or "No song")
        songLbl.TextColor3 = data.active and Color3.fromRGB(50, 255, 140) or Color3.fromRGB(200, 200, 200)
    end
    
    local conn = plr:GetAttributeChangedSignal("UniMenu_Peer"):Connect(UpdateContent)
    table.insert(Connections, conn)
end

local function BroadcastPeerData()
    local data = HttpService:JSONEncode({
        icon = Music.peerIcon or "rbxassetid://6274377121",
        song = Music.song or "",
        artist = Music.artist or "",
        active = Music.active or false,
        ver = "10.0",
        scriptVersion = "1.0.1",
    })
    player:SetAttribute("UniMenu_Peer", data)
end

local function ScanPeers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr:GetAttribute("UniMenu_Peer") then
            CreatePeerBillboard(plr)
        end
    end
end

Players.PlayerRemoving:Connect(function(plr)
    RemovePeerBillboard(plr)
end)

Players.PlayerAdded:Connect(function(plr)
    plr:GetAttributeChangedSignal("UniMenu_Peer"):Connect(function()
        if plr:GetAttribute("UniMenu_Peer") then
            CreatePeerBillboard(plr)
        else
            RemovePeerBillboard(plr)
        end
    end)
end)

ctx.Core.BroadcastPeerData = BroadcastPeerData
ctx.Core.ScanPeers = ScanPeers
ctx.Core.RemovePeerBillboard = RemovePeerBillboard

-- ==================== NOTIFICATIONS ====================
local currentNotification = nil

local function RemoveCurrentNotification()
    if currentNotification then
        currentNotification:Destroy()
        currentNotification = nil
    end
end

-- Debug logging system
local function CreateLogger(module)
    return function(...)
        local args = {...}
        for i, v in ipairs(args) do
            args[i] = tostring(v)
        end
        local msg = string.format("[UniMenu:%s] %s", module, table.concat(args, " "))
        print(msg)
        -- Optional: Write to file
        -- local logFile = io.open("UniMenu/logs/debug.log", "a")
        -- logFile:write(string.format("%s %s\n", os.date("%Y-%m-%d %H:%M:%S"), msg))
        -- logFile:close()
    end
end

-- Initialize loggers
-- Ensure Utils module is loaded before assigning logger
local Utils = ctx.Modules.utils or {}
ctx.Modules.utils.Log = CreateLogger("Utils")
ctx.Core.DebugLog = CreateLogger("Core")

-- Configuration validation schema
local configSchema = {
    speed = { type = "number", min = 16, max = 1000 },
    jumpPower = { type = "number", min = 50, max = 1000 },
}

function ValidateConfig(config)
    for key, value in pairs(configSchema) do
        if config[key] and typeof(config[key]) ~= value.type then
            Utils.Warn("Invalid config:", key, "expected", value.type)
            config[key] = nil -- Reset invalid value
        elseif value.min and config[key] < value.min or value.max and config[key] > value.max then
            Utils.Warn("Config out of range:", key, "clamped to", value.min or value.max)
            config[key] = math.clamp(config[key], value.min, value.max)
        end
    end
end

-- Validate initial config
ValidateConfig(ctx.State.S)

ctx.Core.ShowNotification = ShowNotification
ctx.Core.RemoveCurrentNotification = RemoveCurrentNotification

-- ==================== UTILITY FUNCTIONS ====================
ctx.Core.Animate = function(obj, properties, duration, easingStyle, easingDirection, callback)
    local tweenInfo = TweenInfo.new(duration or 0.2, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out)
    local tween = TweenService:Create(obj, tweenInfo, properties)
    tween:Play()
    if callback then
        tween.Completed:Connect(callback)
    end
    return tween
end

ctx.Core.SafeGet = function(tbl, path, default)
    local current = tbl
    for _, key in ipairs(path) do
        if type(current) ~= "table" then return default end
        current = current[key]
    end
    return current ~= nil and current or default
end

-- ==================== EXPORT ====================
return ctx