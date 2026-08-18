-- UniMenu Core Module
-- Services, shared state, feature registry, utility functions

local ctx = ...

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

local Players = ctx.Services.Players
local RunService = ctx.Services.RunService
local UserInputService = ctx.Services.UserInputService
local TweenService = ctx.Services.TweenService
local TeleportService = ctx.Services.TeleportService
local SoundService = ctx.Services.SoundService
local Lighting = ctx.Services.Lighting
local HttpService = ctx.Services.HttpService

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ==================== CONNECTIONS TRACKING ====================
local Connections = {}
local function TrackConnection(conn)
  table.insert(Connections, conn)
  return conn
end

ctx.Core.TrackConnection = TrackConnection

-- ==================== FPS STATE ====================
local FPS_SAMPLES = 30
local fpsSampleBuf = {}
local fpsSampleIdx = 0

local function GetFPSColor(fps)
  if fps >= 55 then
    return Color3.fromRGB(50, 220, 100)
  elseif fps >= 30 then
    local t = (fps - 30) / 25
    return Color3.fromRGB(
      math.floor(50 + 170 * (1 - t)),
      220,
      math.floor(100 * t)
    )
  elseif fps >= 15 then
    return Color3.fromRGB(255, 190, 30)
  else
    return Color3.fromRGB(255, 50, 50)
  end
end

ctx.Core.GetFPSColor = GetFPSColor
ctx.Core.FPS_SAMPLES = FPS_SAMPLES
ctx.Core.fpsSampleBuf = fpsSampleBuf
ctx.Core.fpsSampleIdx = fpsSampleIdx

-- ==================== PLAYER UTILITIES ====================
local function GetCharacter() return player.Character end
local function GetHumanoid()
  local char = GetCharacter()
  return char and char:FindFirstChildOfClass("Humanoid")
end
local function GetRoot()
  local char = GetCharacter()
  return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

local function IsPlayerActive()
  local char = GetCharacter()
  if not char then return false end
  local hum = char:FindFirstChildOfClass("Humanoid")
  if not hum or hum.Health <= 0 then return false end
  local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
  if not root then return false end
  return true
end

local function RestoreCollision()
  local char = GetCharacter()
  if char then
    for _, p in ipairs(char:GetDescendants()) do
      if p:IsA("BasePart") then
        if p:FindFirstAncestorWhichIsA("Accessory") or p:FindFirstAncestorWhichIsA("Tool") or p.Name == "Handle" then
          p.CanCollide = false
        elseif p.Name == "HumanoidRootPart" then
          p.CanCollide = false
        elseif p.Name == "Head" or p.Name == "Torso" or p.Name == "UpperTorso" or p.Name == "LowerTorso" then
          p.CanCollide = true
        else
          p.CanCollide = false
        end
      end
    end
  end
end

ctx.Core.GetCharacter = GetCharacter
ctx.Core.GetHumanoid = GetHumanoid
ctx.Core.GetRoot = GetRoot
ctx.Core.IsPlayerActive = IsPlayerActive
ctx.Core.RestoreCollision = RestoreCollision

local function Animate(object, properties, duration)
  duration = duration or 0.15
  local tween = TweenService:Create(object,
    TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
  tween:Play()
  return tween
end

ctx.Core.Animate = Animate

-- ==================== THEMES ====================
local Themes = {
  ["Windows XP Luna"] = {
    windowBg = Color3.fromRGB(58, 110, 165),
    windowBgLight = Color3.fromRGB(99, 160, 227),
    windowBgDark = Color3.fromRGB(30, 70, 130),
    titleBar = Color3.fromRGB(10, 36, 106),
    titleBarGrad1 = Color3.fromRGB(39, 105, 204),
    titleBarGrad2 = Color3.fromRGB(16, 66, 166),
    titleBarGrad3 = Color3.fromRGB(10, 36, 106),
    sidebar1 = Color3.fromRGB(222, 217, 202),
    sidebar2 = Color3.fromRGB(202, 195, 178),
    panel1 = Color3.fromRGB(246, 243, 232),
    panel2 = Color3.fromRGB(230, 225, 212),
    rowBg = Color3.fromRGB(255, 255, 255),
    borderLight = Color3.fromRGB(255, 255, 255),
    borderDark = Color3.fromRGB(150, 142, 125),
    tabActive = Color3.fromRGB(255, 255, 255),
    tabInactive = Color3.fromRGB(210, 204, 188),
    tabActiveText = Color3.fromRGB(10, 36, 106),
    tabInactiveText = Color3.fromRGB(60, 60, 60),
    text = Color3.fromRGB(20, 20, 20),
    accent = Color3.fromRGB(0, 100, 210),
    green = Color3.fromRGB(0, 180, 80),
    red = Color3.fromRGB(210, 45, 45),
    tagBg = Color3.fromRGB(246, 243, 232),
    tagHeader = Color3.fromRGB(39, 105, 204),
    tagText = Color3.fromRGB(20, 20, 20),
    tagBorder = Color3.fromRGB(10, 36, 106)
  },
  ["Windows Vista Aero"] = {
    windowBg = Color3.fromRGB(236, 242, 252),
    windowBgLight = Color3.fromRGB(255, 255, 255),
    windowBgDark = Color3.fromRGB(215, 228, 248),
    titleBar = Color3.fromRGB(62, 130, 210),
    titleBarGrad1 = Color3.fromRGB(155, 205, 255),
    titleBarGrad2 = Color3.fromRGB(62, 130, 210),
    titleBarGrad3 = Color3.fromRGB(22, 78, 168),
    sidebar1 = Color3.fromRGB(190, 215, 245),
    sidebar2 = Color3.fromRGB(165, 198, 238),
    panel1 = Color3.fromRGB(248, 251, 255),
    panel2 = Color3.fromRGB(232, 241, 254),
    rowBg = Color3.fromRGB(255, 255, 255),
    borderLight = Color3.fromRGB(170, 205, 245),
    borderDark = Color3.fromRGB(110, 160, 220),
    tabActive = Color3.fromRGB(255, 255, 255),
    tabInactive = Color3.fromRGB(200, 222, 248),
    tabActiveText = Color3.fromRGB(18, 70, 155),
    tabInactiveText = Color3.fromRGB(55, 95, 150),
    text = Color3.fromRGB(20, 20, 20),
    accent = Color3.fromRGB(0, 102, 204),
    green = Color3.fromRGB(0, 170, 80),
    red = Color3.fromRGB(200, 40, 40),
    tagBg = Color3.fromRGB(240, 246, 255),
    tagHeader = Color3.fromRGB(62, 130, 210),
    tagText = Color3.fromRGB(20, 20, 20),
    tagBorder = Color3.fromRGB(22, 78, 168)
  },
  ["Dark Obsidian"] = {
    windowBg = Color3.fromRGB(24, 24, 28),
    windowBgLight = Color3.fromRGB(35, 35, 42),
    windowBgDark = Color3.fromRGB(15, 15, 18),
    titleBar = Color3.fromRGB(18, 18, 22),
    titleBarGrad1 = Color3.fromRGB(45, 45, 55),
    titleBarGrad2 = Color3.fromRGB(25, 25, 32),
    titleBarGrad3 = Color3.fromRGB(18, 18, 22),
    sidebar1 = Color3.fromRGB(28, 28, 34),
    sidebar2 = Color3.fromRGB(22, 22, 26),
    panel1 = Color3.fromRGB(32, 32, 38),
    panel2 = Color3.fromRGB(26, 26, 30),
    rowBg = Color3.fromRGB(36, 36, 44),
    borderLight = Color3.fromRGB(60, 60, 75),
    borderDark = Color3.fromRGB(40, 40, 50),
    tabActive = Color3.fromRGB(50, 50, 62),
    tabInactive = Color3.fromRGB(24, 24, 30),
    tabActiveText = Color3.fromRGB(0, 220, 255),
    tabInactiveText = Color3.fromRGB(160, 160, 175),
    text = Color3.fromRGB(240, 240, 240),
    accent = Color3.fromRGB(0, 200, 255),
    green = Color3.fromRGB(0, 200, 100),
    red = Color3.fromRGB(230, 60, 60),
    tagBg = Color3.fromRGB(32, 32, 38),
    tagHeader = Color3.fromRGB(45, 45, 55),
    tagText = Color3.fromRGB(240, 240, 240),
    tagBorder = Color3.fromRGB(0, 200, 255)
  },
  ["Crimson Blood"] = {
    windowBg = Color3.fromRGB(35, 15, 15),
    windowBgLight = Color3.fromRGB(55, 20, 20),
    windowBgDark = Color3.fromRGB(20, 8, 8),
    titleBar = Color3.fromRGB(60, 10, 10),
    titleBarGrad1 = Color3.fromRGB(100, 20, 20),
    titleBarGrad2 = Color3.fromRGB(60, 12, 12),
    titleBarGrad3 = Color3.fromRGB(40, 8, 8),
    sidebar1 = Color3.fromRGB(30, 15, 15),
    sidebar2 = Color3.fromRGB(22, 10, 10),
    panel1 = Color3.fromRGB(40, 20, 20),
    panel2 = Color3.fromRGB(28, 14, 14),
    rowBg = Color3.fromRGB(48, 22, 22),
    borderLight = Color3.fromRGB(120, 40, 40),
    borderDark = Color3.fromRGB(70, 20, 20),
    tabActive = Color3.fromRGB(75, 25, 25),
    tabInactive = Color3.fromRGB(28, 12, 12),
    tabActiveText = Color3.fromRGB(255, 255, 255),
    tabInactiveText = Color3.fromRGB(200, 150, 150),
    text = Color3.fromRGB(255, 230, 230),
    accent = Color3.fromRGB(230, 40, 40),
    green = Color3.fromRGB(0, 180, 80),
    red = Color3.fromRGB(255, 60, 60),
    tagBg = Color3.fromRGB(40, 20, 20),
    tagHeader = Color3.fromRGB(80, 15, 15),
    tagText = Color3.fromRGB(255, 230, 230),
    tagBorder = Color3.fromRGB(230, 40, 40)
  },
  ["Emerald Cyber"] = {
    windowBg = Color3.fromRGB(15, 30, 20),
    windowBgLight = Color3.fromRGB(25, 50, 35),
    windowBgDark = Color3.fromRGB(10, 20, 12),
    titleBar = Color3.fromRGB(10, 50, 25),
    titleBarGrad1 = Color3.fromRGB(20, 90, 45),
    titleBarGrad2 = Color3.fromRGB(12, 60, 30),
    titleBarGrad3 = Color3.fromRGB(8, 40, 20),
    sidebar1 = Color3.fromRGB(18, 35, 22),
    sidebar2 = Color3.fromRGB(12, 25, 16),
    panel1 = Color3.fromRGB(22, 42, 28),
    panel2 = Color3.fromRGB(16, 32, 20),
    rowBg = Color3.fromRGB(26, 50, 34),
    borderLight = Color3.fromRGB(40, 120, 60),
    borderDark = Color3.fromRGB(20, 60, 30),
    tabActive = Color3.fromRGB(32, 75, 45),
    tabInactive = Color3.fromRGB(14, 28, 18),
    tabActiveText = Color3.fromRGB(255, 255, 255),
    tabInactiveText = Color3.fromRGB(150, 200, 170),
    text = Color3.fromRGB(220, 255, 230),
    accent = Color3.fromRGB(0, 230, 120),
    green = Color3.fromRGB(0, 220, 90),
    red = Color3.fromRGB(230, 60, 60),
    tagBg = Color3.fromRGB(22, 42, 28),
    tagHeader = Color3.fromRGB(20, 75, 38),
    tagText = Color3.fromRGB(220, 255, 230),
    tagBorder = Color3.fromRGB(0, 230, 120)
  },
  ["Royal Amethyst"] = {
    windowBg = Color3.fromRGB(30, 15, 40),
    windowBgLight = Color3.fromRGB(50, 25, 65),
    windowBgDark = Color3.fromRGB(18, 8, 25),
    titleBar = Color3.fromRGB(45, 15, 60),
    titleBarGrad1 = Color3.fromRGB(80, 25, 110),
    titleBarGrad2 = Color3.fromRGB(50, 15, 70),
    titleBarGrad3 = Color3.fromRGB(30, 8, 45),
    sidebar1 = Color3.fromRGB(26, 14, 34),
    sidebar2 = Color3.fromRGB(18, 8, 24),
    panel1 = Color3.fromRGB(35, 20, 46),
    panel2 = Color3.fromRGB(25, 12, 34),
    rowBg = Color3.fromRGB(42, 22, 55),
    borderLight = Color3.fromRGB(110, 50, 140),
    borderDark = Color3.fromRGB(60, 25, 80),
    tabActive = Color3.fromRGB(65, 30, 85),
    tabInactive = Color3.fromRGB(22, 10, 28),
    tabActiveText = Color3.fromRGB(255, 255, 255),
    tabInactiveText = Color3.fromRGB(190, 160, 210),
    text = Color3.fromRGB(245, 230, 255),
    accent = Color3.fromRGB(180, 80, 255),
    green = Color3.fromRGB(0, 190, 90),
    red = Color3.fromRGB(230, 60, 60),
    tagBg = Color3.fromRGB(35, 20, 46),
    tagHeader = Color3.fromRGB(65, 25, 85),
    tagText = Color3.fromRGB(245, 230, 255),
    tagBorder = Color3.fromRGB(180, 80, 255)
  }
}

ctx.Config.Themes = Themes
ctx.Config.currentThemeName = "Windows XP Luna"
ctx.Config.XP = Themes[ctx.Config.currentThemeName]

-- ==================== CONFIG ====================
local gameConfig = {
  walkSpeed = 50,
  jumpPower = 100,
  flySpeed = 50,
  spinSpeed = 30,
  hipHeight = 2,
  fov = 70,
  aimbotSmoothness = 0.25,
  aimbotFOV = 400,
  masterVolume = 1.0,
  espFillTrans = 0.85,
  espOutlineTrans = 0.1,
  espTextSize = 11,
  surfSpeed = 80,
  bhopAccel = 1.8,
  nightDimness = 0.45,
  chamsTrans = 0.65
}
ctx.Config.gameConfig = gameConfig

local initHum = GetHumanoid()
local originalWalkSpeed = initHum and initHum.WalkSpeed or 16
local originalJumpPower = initHum and initHum.JumpPower or 50
local originalHipHeight = initHum and initHum.HipHeight or 0
local originalGravity = workspace.Gravity
local originalFOV = camera.FieldOfView

ctx.Core.originalWalkSpeed = originalWalkSpeed
ctx.Core.originalJumpPower = originalJumpPower
ctx.Core.originalHipHeight = originalHipHeight
ctx.Core.originalGravity = originalGravity
ctx.Core.originalFOV = originalFOV

-- ==================== GROUPED STATE TABLES ====================
local S = {
  aimbot = false,
  triggerbot = false,
  autoClicker = false,
  speed = false,
  fly = false,
  flyBV = nil,
  jump = false,
  noclip = false,
  infJump = false,
  clickTP = false,
  spinbot = false,
  antiFling = false,
  hipHeight = false,
  lowGravity = false,
  cs2Bhop = false,
  cs2Surf = false,
  isSurfing = false,
  bhopWasOnGround = false,
  esp = false,
  fullbright = false,
  darkMode = false,
  nightFX = nil,
  chams = false,
  noFog = false,
  noVFX = false,
  xRay = false,
  freecam = false,
  freecamPart = nil,
  noVFXConn = nil,
  disabledVFX = {},
  fpsBoost = false,
  fpsBoostData = {},
  spectate = false,
  coinTweening = false,
  grabbingGun = false,
  espFolder = nil,
  showPeerIcon = true,
  hudEnabled = true,
  chamsFolder = nil,
  savedPositions = {},
  origTransparency = {},
  origSoundVolumes = {},
  origLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
  },
  aimbotTargetPart = "Head"
}
ctx.State.S = S

local Music = {
  user = "",
  apiKey = "b25b959554ed76058ac220b7b2e0a026",
  song = "",
  artist = "",
  album = "",
  active = false,
  coverAsset = "",
  coverIsProcedural = false,
  lastCoverUrl = "",
  dynamicColorEnabled = true,
  useSpotifyDirect = false,
  usingDynamicTheme = false,
  dynamicTheme = nil,
  statusText = "Enter Last.fm username to connect",
  hudLabel = nil,
  hudCover = nil,
  hudArtistLabel = nil,
  menuSongLbl = nil,
  menuArtLbl = nil,
  menuStatusLbl = nil,
  menuCover = nil,
  menuSpotifyStatus = nil,
  peerIcon = "rbxassetid://6274377121",
  spotify = {
    clientId = "",
    clientSecret = "",
    accessToken = "",
    refreshToken = "",
    expiresAt = 0,
    deviceId = "",
    connected = false,
    song = "",
    artist = "",
    album = "",
    isPlaying = false,
    progressMs = 0,
    durationMs = 0,
  },
}
ctx.State.Music = Music

local MM2 = {
  roleESP = false,
  gunESP = true,
  trapESP = false,
  coinESP = false,
  autoShoot = false,
  magicBullet = false,
  antiStab = false,
  autoCoins = false,
  autoGrabGun = false,
  knifeAura = false,
  autoFollow = false,
  platformMode = false,
  boostMode = false,
  auraRadius = 15,
  coinDelay = 0.25,
  lastCoinTime = 0,
  lastShootTime = 0,
  lastDodgeTime = 0,
  lastGrabTime = 0,
  trapFolder = nil
}
ctx.State.MM2 = MM2

-- GUI state
local isOpen = false
local gui = nil
local currentTab = "Movement"
local selectedPlayer = nil
local playerList = {}
local isTransitioning = false
local contentContainerRef = nil

local KEYBIND_FILE = "UniMenu_keybinds.json"
local SETTINGS_FILE = "UniMenu_settings.json"

local keybinds = { menuToggle = Enum.KeyCode.RightBracket }
local keybindRegistry = {}
local activeKeybindMap = {}

local function RebuildKeybindMap()
  activeKeybindMap = {}
  activeKeybindMap[keybinds.menuToggle] = "menuToggle"
  for name, _ in pairs(keybindRegistry) do
    local kc = keybinds[name]
    if kc then
      activeKeybindMap[kc] = name
    end
  end
end

local function SaveKeybinds()
  if typeof(writefile) ~= "function" then return end
  local data = {}
  for name, kc in pairs(keybinds) do
    if name ~= "menuToggle" and kc and typeof(kc) == "EnumItem" then
      data[name] = kc.Name
    end
  end
  local json = HttpService:JSONEncode(data)
  writefile(KEYBIND_FILE, json)
end

local function LoadKeybinds()
  if typeof(readfile) ~= "function" then return end
  if not isfile or not isfile(KEYBIND_FILE) then return end
  local ok, content = pcall(readfile, KEYBIND_FILE)
  if not ok or not content then return end
  local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
  if not ok2 or type(data) ~= "table" then return end
  for name, keyStr in pairs(data) do
    local kc = Enum.KeyCode[keyStr]
    if kc then
      keybinds[name] = kc
    end
  end
end

local function SaveSettings()
  if typeof(writefile) ~= "function" then return end
  local data = {
    lastfmUser = Music.user or "",
    peerIcon = Music.peerIcon or "rbxassetid://6274377121",
    currentTheme = ctx.Config.currentThemeName or "Windows XP Luna",
    useSpotifyDirect = Music.useSpotifyDirect or false,
    spotifyClientId = Music.spotify.clientId or "",
  }
  local json = HttpService:JSONEncode(data)
  writefile(SETTINGS_FILE, json)
end

local function LoadSettings()
  if typeof(readfile) ~= "function" then return end
  if not isfile or not isfile(SETTINGS_FILE) then return end
  local ok, content = pcall(readfile, SETTINGS_FILE)
  if not ok or not content then return end
  local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
  if not ok2 or type(data) ~= "table" then return end
  if type(data.lastfmUser) == "string" and #data.lastfmUser > 0 then
    Music.user = data.lastfmUser
  end
  if type(data.peerIcon) == "string" and #data.peerIcon > 0 then
    Music.peerIcon = data.peerIcon
  end
  if type(data.currentTheme) == "string" and Themes[data.currentTheme] then
    ctx.Config.currentThemeName = data.currentTheme
    ctx.Config.XP = Themes[data.currentTheme]
  end
  if type(data.useSpotifyDirect) == "boolean" then
    Music.useSpotifyDirect = data.useSpotifyDirect
  end
  if type(data.spotifyClientId) == "string" then
    Music.spotify.clientId = data.spotifyClientId
  end
end

ctx.Core.keybinds = keybinds
ctx.Core.keybindRegistry = keybindRegistry
ctx.Core.activeKeybindMap = activeKeybindMap
ctx.Core.RebuildKeybindMap = RebuildKeybindMap
ctx.Core.SaveKeybinds = SaveKeybinds
ctx.Core.LoadKeybinds = LoadKeybinds
ctx.Core.SaveSettings = SaveSettings
ctx.Core.LoadSettings = LoadSettings

-- ==================== LAST.FM MUSIC API ====================
local function MusicHTTP(url)
  local reqFn = (typeof(request) == "function" and request)
      or (typeof(http_request) == "function" and http_request)
      or (typeof(syn) == "table" and syn.request)
      or (typeof(http) == "table" and http.request)

  if reqFn then
    local ok1, res1 = pcall(reqFn, { Url = url, Method = "GET" })
    if ok1 and res1 and (res1.Body or res1.body) then
      local b = res1.Body or res1.body
      local code = res1.StatusCode or res1.status_code or 200
      if typeof(b) == "string" and #b > 0 then
        return { StatusCode = code, Body = b }
      end
    end
    local ok2, res2 = pcall(reqFn, { url = url, method = "GET" })
    if ok2 and res2 and (res2.Body or res2.body) then
      local b = res2.Body or res2.body
      local code = res2.StatusCode or res2.status_code or 200
      if typeof(b) == "string" and #b > 0 then
        return { StatusCode = code, Body = b }
      end
    end
  end

  local ok3, body = pcall(function() return game:HttpGet(url) end)
  if ok3 and body and typeof(body) == "string" and #body > 0 then
    return { StatusCode = 200, Body = body }
  end

  return nil
end

local function UrlEncode(str)
  return string.gsub(tostring(str), "([^%w_%-.~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

local function WriteAndSetCover(imgData)
  if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then return end
  local fileName = "unimenu_cover_" .. tostring(os.time()) .. ".jpg"
  writefile(fileName, imgData)
  Music.coverAsset = getcustomasset(fileName)
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
  ApplyCoverTheme(imgData)
end

local function ApplyCoverTheme(imgData)
  if not Music.dynamicColorEnabled then return end
  local hash = 0
  for i = 1, math.min(#imgData, 1024) do
    hash = (hash * 31 + string.byte(imgData, i)) % 0x7FFFFFFF
  end

  local hue1 = hash % 360
  local hue2 = (hue1 + 100 + (hash % 80)) % 360
  local sat1 = 0.45 + (hash % 30) / 100
  local sat2 = 0.45 + (math.floor(hash / 30) % 30) / 100
  local val1 = 0.25 + (hash % 25) / 100
  local val2 = 0.5 + (math.floor(hash / 25) % 30) / 100

  local theme = {
    windowBg = Color3.fromHSV(hue1 / 360, sat1, val1),
    windowBgLight = Color3.fromHSV(hue1 / 360, math.max(sat1 - 0.15, 0.1), math.min(val1 + 0.25, 0.9)),
    windowBgDark = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.1, 0.85), math.max(val1 - 0.1, 0.1)),
    titleBar = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.15, 0.9), math.max(val1 - 0.05, 0.08)),
    titleBarGrad1 = Color3.fromHSV(hue2 / 360, sat2, val2),
    titleBarGrad2 = Color3.fromHSV((hue1 + hue2) / 720, (sat1 + sat2) / 2, (val1 + val2) / 2),
    titleBarGrad3 = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.1, 0.9), math.max(val1 - 0.08, 0.05)),
    sidebar1 = Color3.fromHSV(hue1 / 360, 0.12, 0.95),
    sidebar2 = Color3.fromHSV(hue1 / 360, 0.15, 0.88),
    panel1 = Color3.fromHSV(hue1 / 360, 0.08, 0.98),
    panel2 = Color3.fromHSV(hue1 / 360, 0.1, 0.92),
    rowBg = Color3.fromHSV(hue1 / 360, 0.05, 1.0),
    borderLight = Color3.fromHSV(hue1 / 360, 0.05, 0.95),
    borderDark = Color3.fromHSV(hue1 / 360, 0.3, 0.4),
    tabActive = Color3.fromHSV(hue1 / 360, 0.02, 0.98),
    tabInactive = Color3.fromHSV(hue1 / 360, 0.08, 0.85),
    tabActiveText = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.2, 0.9), 0.15),
    tabInactiveText = Color3.fromHSV(hue1 / 360, 0.2, 0.35),
    text = Color3.fromHSV(hue1 / 360, 0.15, 0.12),
    accent = Color3.fromHSV(hue2 / 360, sat2, val2),
    green = Color3.fromHSV((hue1 + 120) % 360 / 360, 0.7, 0.6),
    red = Color3.fromHSV((hue1 - 30) % 360 / 360, 0.75, 0.55),
    tagBg = Color3.fromHSV(hue1 / 360, 0.08, 0.98),
    tagHeader = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.1, 0.85), math.max(val1 - 0.1, 0.2)),
    tagText = Color3.fromHSV(hue1 / 360, 0.15, 0.12),
    tagBorder = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.2, 0.9), math.max(val1 - 0.05, 0.08)),
  }

  Music.dynamicTheme = theme
  Music.usingDynamicTheme = true
  if ctx.Core.ApplyDynamicTheme then ctx.Core.ApplyDynamicTheme() end
end

local function ApplyDynamicTheme()
  if not Music.usingDynamicTheme or not Music.dynamicTheme then return end
  local theme = Music.dynamicTheme
  ctx.Config.XP = theme
  if ctx.UI and ctx.UI.BuildGUI then ctx.UI.BuildGUI() end
  if ctx.UI and ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
  if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
end

local function RevertToDefaultTheme()
  if not Music.usingDynamicTheme then return end
  local defaultTheme = Themes[currentThemeName] or Themes["Windows XP Luna"]
  ctx.Config.XP = defaultTheme
  Music.usingDynamicTheme = false
  Music.dynamicTheme = nil
  if ctx.UI and ctx.UI.BuildGUI then ctx.UI.BuildGUI() end
  if ctx.UI and ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
  if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
end

local function FetchCoverFromiTunes(song, artist)
  local query = UrlEncode(artist .. " " .. song)
  local url = "https://itunes.apple.com/search?term=" .. query .. "&media=music&entity=song&limit=1"
  local res = MusicHTTP(url)
  if not res or not res.Body or #res.Body < 10 then return end
  local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
  if not ok or not data or not data.results or #data.results == 0 then return end
  local artUrl = data.results[1].artworkUrl100
  if not artUrl or artUrl == "" then return end
  artUrl = artUrl:gsub("100x100bb", "600x600bb")
  local imgRes = MusicHTTP(artUrl)
  if imgRes and imgRes.Body and #imgRes.Body > 1000 then
    pcall(WriteAndSetCover, imgRes.Body)
  end
end

local function DownloadAlbumCover(lastfmImgUrl, song, artist)
  local cacheKey = (lastfmImgUrl or "") .. "|" .. (song or "") .. "|" .. (artist or "")
  if cacheKey == Music.lastCoverUrl and Music.coverAsset ~= "" then
    return
  end
  if cacheKey == Music.lastCoverUrl then
    -- Same song but cover not loaded yet, continue
    Music.coverAsset = ""
    Music.coverIsProcedural = false
  else
    Music.lastCoverUrl = cacheKey
    Music.coverAsset = ""
    Music.coverIsProcedural = false
  end
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end

  task.spawn(function()
    local lastfmHasImage = lastfmImgUrl and lastfmImgUrl ~= "" and
        not lastfmImgUrl:find("2a96cbd8b46e442fc41c2b86b821562f")
    if lastfmHasImage then
      local res = MusicHTTP(lastfmImgUrl)
      if res and res.Body and #res.Body > 1000 then
        pcall(WriteAndSetCover, res.Body)
        return
      end
    end

    if song and song ~= "" and artist and artist ~= "" then
      pcall(FetchCoverFromiTunes, song, artist)
    end

    task.wait(0.5)
    if Music.coverAsset == "" and Music.song ~= "" then
      pcall(BuildProceduralCover, song, artist)
    end
  end)
end

local function BuildProceduralCover(song, artist)
  local label = (song or "♪"):sub(1, 1):upper()
  local seedStr = (song or "") .. (artist or "")
  local hash = 0
  for i = 1, #seedStr do
    hash = (hash * 31 + string.byte(seedStr, i)) % 0x7FFFFFFF
  end
  local hue1 = hash % 360
  local hue2 = (hue1 + 80 + (hash % 120)) % 360
  local gen = hash % 4

  local success = pcall(function()
    local coverGui = Instance.new("ScreenGui")
    coverGui.Name = "UniMenu_ProceduralCover"
    coverGui.ResetOnSpawn = false
    coverGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    coverGui.DisplayOrder = -2147483647
    coverGui.IgnoreGuiInset = true
    coverGui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 100, 0, 100)
    frame.Position = UDim2.new(0, -110, 0, -110)
    frame.BackgroundColor3 = Color3.fromHSV(hue1 / 360, 0.4, 0.35)
    frame.BorderSizePixel = 0
    frame.Parent = coverGui

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, Color3.fromHSV(hue1 / 360, 0.5, 0.4)),
      ColorSequenceKeypoint.new(0.5, Color3.fromHSV(hue2 / 360, 0.45, 0.35)),
      ColorSequenceKeypoint.new(1, Color3.fromHSV(hue1 / 360, 0.3, 0.3))
    })
    grad.Rotation = gen == 0 and 0 or (gen == 1 and 45) or (gen == 2 and 90) or 135
    grad.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.08, 0)
    corner.Parent = frame

    local letter = Instance.new("TextLabel")
    letter.Size = UDim2.new(1, 0, 1, 0)
    letter.Position = UDim2.new(0, 0, 0, 0)
    letter.BackgroundTransparency = 1
    letter.Text = label
    letter.TextColor3 = Color3.fromHSV(((hue1 + 180) % 360) / 360, 0.3, 1)
    letter.Font = Enum.Font.GothamBlack
    letter.TextSize = 72
    letter.TextScaled = true
    letter.Parent = frame

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -8, 0, 14)
    sub.Position = UDim2.new(0, 4, 1, -18)
    sub.BackgroundTransparency = 1
    sub.Text = "♪ " .. (artist ~= "" and artist or "Now Playing")
    sub.TextColor3 = Color3.fromHSV(((hue1 + 180) % 360) / 360, 0.2, 0.9)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 10
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.TextXAlignment = Enum.TextXAlignment.Center
    sub.Parent = frame

    coverGui.Parent = game:GetService("CoreGui")
  end)

  if success then
    Music.coverAsset = "rbxasset://ProceduralCover"
    Music.coverIsProcedural = true
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
  end
end

local function LastfmPoll()
  if Music.user == "" then return end
  local url = "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user="
      .. UrlEncode(Music.user)
      .. "&api_key=" .. Music.apiKey
      .. "&format=json&limit=1"

  local res = MusicHTTP(url)
  if not res or not res.Body then
    local fallbackUrl = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user="
        .. UrlEncode(Music.user)
        .. "&api_key=" .. Music.apiKey
        .. "&format=json&limit=1"
    res = MusicHTTP(fallbackUrl)
  end

  if not res or not res.Body then
    Music.statusText = "[ERR] HTTP GET failed (no executor HTTP method responded)"
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    return
  end

  local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
  if not ok or not data then
    Music.statusText = "[ERR] Failed to decode JSON response"
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    return
  end

  if data.error then
    Music.statusText = "[ERR] " .. tostring(data.message or ("Error code " .. tostring(data.error)))
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    return
  end

  if not data.recenttracks then
    Music.statusText = "[ERR] No recent tracks found for user"
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
    return
  end

  local tracks = data.recenttracks.track
  local t = nil
  if typeof(tracks) == "table" then
    t = tracks[1] or tracks
  end

  if t and t.name then
    Music.song       = tostring(t.name)
    local art        = (t.artist and (t.artist["#text"] or t.artist.name or tostring(t.artist))) or ""
    Music.artist     = tostring(art)
    Music.album      = (t.album and (t.album["#text"] or tostring(t.album))) or ""
    Music.active     = (t["@attr"] and t["@attr"].nowplaying == "true") or false
    Music.statusText = Music.active and "[OK] Scrobbling live from Spotify" or
        "[OK] Connected (Idle / Last played track)"

    local imgUrl     = ""
    if t.image and typeof(t.image) == "table" then
      for _, img in ipairs(t.image) do
        if img["#text"] and img["#text"] ~= "" then
          imgUrl = img["#text"]
        end
      end
    end
    DownloadAlbumCover(imgUrl, Music.song, Music.artist)
  else
    Music.song = ""
    Music.artist = ""
    Music.active = false
    Music.coverAsset = ""
    Music.coverIsProcedural = false
    Music.statusText = "[OK] Connected (no scrobbles yet)"
    RevertToDefaultTheme()
  end
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
end

local lastfmPollingActive = false
local function StartLastfmPolling()
  if lastfmPollingActive then return end
  lastfmPollingActive = true
  task.spawn(function()
    while isScriptRunning do
      if Music.user ~= "" then
        LastfmPoll()
      end
      task.wait(4)
    end
    lastfmPollingActive = false
  end)
end

ctx.Core.StartLastfmPolling = StartLastfmPolling
ctx.Core.LastfmPoll = LastfmPoll
ctx.Core.MusicHTTP = MusicHTTP
ctx.Core.ApplyDynamicTheme = ApplyDynamicTheme
ctx.Core.RevertToDefaultTheme = RevertToDefaultTheme

-- ==================== LOAD MUSIC MODULES ====================
-- These will be loaded by the loader
ctx.Core.MusicModulesLoaded = false

-- ==================== FEATURE REGISTRY ====================
local features = {}
local heartbeatCallbacks = {}

local function RegisterFeatures(tabName, featureList)
  features[tabName] = featureList
end

local function RegisterHeartbeat(fn)
  table.insert(heartbeatCallbacks, fn)
end

local function RegisterConnection(fn)
  fn()
end

ctx.Core.features = features
ctx.Core.RegisterFeatures = RegisterFeatures
ctx.Core.RegisterHeartbeat = RegisterHeartbeat
ctx.Core.RegisterConnection = RegisterConnection

-- ==================== PEER DETECTION ====================
local peerBillboards = {}
local peerBroadcastTimer = 0

local function BroadcastPeerData()
  local data = HttpService:JSONEncode({
    icon = Music.peerIcon or "rbxassetid://6274377121",
    song = Music.song or "",
    artist = Music.artist or "",
    active = Music.active or false,
    ver = "10.0"
  })
  player:SetAttribute("UniMenu_Peer", data)
end

local function RemovePeerBillboard(plr)
  local bb = peerBillboards[plr.Name]
  if bb then
    bb:Destroy(); peerBillboards[plr.Name] = nil
  end
end

local function CreatePeerBillboard(plr)
  if plr == player then return end
  RemovePeerBillboard(plr)
  local char = plr.Character
  if not char then return end
  local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
  if not hrp then return end

  local espFolder = S.espFolder
  if not espFolder then return end

  local bb = Instance.new("BillboardGui")
  bb.Name = "UniMenu_Peer_" .. plr.Name
  bb.Adornee = hrp
  bb.Size = UDim2.new(0, 120, 0, 44)
  bb.StudsOffset = Vector3.new(0, 3.5, 0)
  bb.AlwaysOnTop = true
  bb.LightInfluence = 0
  bb.MaxDistance = 150
  bb.Parent = espFolder

  local bg = Instance.new("Frame")
  bg.Size = UDim2.new(1, 0, 1, 0)
  bg.BackgroundColor3 = ctx.Config.XP.windowBg
  bg.BackgroundTransparency = 0.15
  bg.BorderSizePixel = 1
  bg.BorderColor3 = ctx.Config.XP.accent
  bg.Parent = bb

  local icon = Instance.new("ImageLabel")
  icon.Size = UDim2.new(0, 22, 0, 22)
  icon.Position = UDim2.new(0, 4, 0, 4)
  icon.BackgroundTransparency = 1
  icon.Image = Music.peerIcon or "rbxassetid://6274377121"
  icon.Parent = bg

  local songLbl = Instance.new("TextLabel")
  songLbl.Size = UDim2.new(1, -30, 0, 16)
  songLbl.Position = UDim2.new(0, 28, 0, 4)
  songLbl.Text = "♪ ..."
  songLbl.TextColor3 = Color3.fromRGB(50, 255, 140)
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
  nameLbl.TextColor3 = ctx.Config.XP.accent
  nameLbl.BackgroundTransparency = 1
  nameLbl.Font = Enum.Font.GothamBold
  nameLbl.TextSize = 8
  nameLbl.TextXAlignment = Enum.TextXAlignment.Left
  nameLbl.Parent = bg

  peerBillboards[plr.Name] = bb

  local function UpdateContent()
    local attr = plr:GetAttribute("UniMenu_Peer")
    if not attr then
      RemovePeerBillboard(plr); return
    end
    local data
    local ok = pcall(function() data = HttpService:JSONDecode(attr) end)
    if not ok or type(data) ~= "table" then return end
    if data.icon and #data.icon > 0 then icon.Image = data.icon end
    if data.active and data.song and #data.song > 0 then
      songLbl.Text = "♪ " .. data.song
      songLbl.TextColor3 = Color3.fromRGB(50, 255, 140)
    elseif data.song and #data.song > 0 then
      songLbl.Text = "⏸ " .. data.song
      songLbl.TextColor3 = Color3.fromRGB(240, 248, 255)
    else
      songLbl.Text = "♪ No music"
      songLbl.TextColor3 = ctx.Config.XP.tabInactiveText
    end
  end
  UpdateContent()

  local conn
  conn = plr:GetAttributeChangedSignal("UniMenu_Peer"):Connect(function()
    if not bb.Parent then
      conn:Disconnect(); return
    end
    UpdateContent()
  end)
end

local function ScanPeers()
  for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then
      local attr = plr:GetAttribute("UniMenu_Peer")
      if attr then
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
          if not peerBillboards[plr.Name] or not peerBillboards[plr.Name].Parent then
            CreatePeerBillboard(plr)
          end
        end
      else
        RemovePeerBillboard(plr)
      end
    end
  end
end

local function TogglePeerIcon(state)
  S.showPeerIcon = state
  if not state then
    for name, bb in pairs(peerBillboards) do
      bb:Destroy(); peerBillboards[name] = nil
    end
  else
    ScanPeers()
  end
end

ctx.Core.BroadcastPeerData = BroadcastPeerData
ctx.Core.ScanPeers = ScanPeers
ctx.Core.TogglePeerIcon = TogglePeerIcon

-- ==================== MASTER SOUND VOLUME ====================
local function IsVoiceChatSound(sound)
  local name = sound.Name:lower()
  if name:find("voice") or name:find("mic") or name:find("chat") or name:find("audioin") then
    return true
  end
  if sound.Parent and sound.Parent.Name:lower():find("voice") then return true end
  return false
end

local function ApplySoundVolume(sound)
  if not sound:IsA("Sound") or IsVoiceChatSound(sound) then return end
  if S.origSoundVolumes[sound] == nil then
    S.origSoundVolumes[sound] = sound.Volume > 0 and sound.Volume or 1
  end
  sound.Volume = S.origSoundVolumes[sound] * gameConfig.masterVolume
end

local function SetMasterVolume(vol)
  gameConfig.masterVolume = math.clamp(vol, 0, 1)
  for _, obj in ipairs(SoundService:GetDescendants()) do
    if obj:IsA("Sound") then ApplySoundVolume(obj) end
  end
  for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("Sound") then ApplySoundVolume(obj) end
  end
end

TrackConnection(SoundService.DescendantAdded:Connect(function(descendant)
  if descendant:IsA("Sound") then ApplySoundVolume(descendant) end
end))

ctx.Core.SetMasterVolume = SetMasterVolume

-- ==================== VISUAL Toggles ====================
local function ToggleFullbright(state)
  S.fullbright = state
  if state and S.darkMode then
    S.darkMode = false
    if S.nightFX then
      pcall(function() S.nightFX:Destroy() end); S.nightFX = nil
    end
  end
  if state then
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
  else
    Lighting.Brightness = S.origLighting.Brightness
    Lighting.ClockTime = S.origLighting.ClockTime
    Lighting.FogEnd = S.origLighting.FogEnd
    Lighting.GlobalShadows = S.origLighting.GlobalShadows
    Lighting.Ambient = S.origLighting.Ambient
  end
end

local function UpdateDarkMode()
  if not S.darkMode then
    if S.nightFX then
      pcall(function() S.nightFX:Destroy() end); S.nightFX = nil
    end
    if not S.fullbright then
      Lighting.Brightness = S.origLighting.Brightness
      Lighting.ClockTime = S.origLighting.ClockTime
      Lighting.FogEnd = S.origLighting.FogEnd
      Lighting.GlobalShadows = S.origLighting.GlobalShadows
      Lighting.Ambient = S.origLighting.Ambient
      if S.origLighting.OutdoorAmbient then
        Lighting.OutdoorAmbient = S.origLighting.OutdoorAmbient
      end
    end
    return
  end
  if S.fullbright then S.fullbright = false end
  Lighting.ClockTime = 0
  Lighting.Brightness = math.max(0.1, 0.8 - (gameConfig.nightDimness * 0.7))
  Lighting.GlobalShadows = true
  Lighting.OutdoorAmbient = Color3.fromRGB(28, 32, 42)
  Lighting.Ambient = Color3.fromRGB(35, 40, 52)
  if not S.nightFX or not S.nightFX.Parent then
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "CheatMenu_NightMode"
    cc.Parent = Lighting
    S.nightFX = cc
  end
  S.nightFX.Brightness = -(gameConfig.nightDimness * 0.22)
  S.nightFX.Contrast = 0.04
  S.nightFX.Saturation = -0.08
  S.nightFX.TintColor = Color3.fromRGB(225, 235, 250)
end

local function ToggleDarkMode(state)
  S.darkMode = state
  UpdateDarkMode()
end

local function ToggleNoFog(state)
  S.noFog = state
  Lighting.FogEnd = state and 9e9 or S.origLighting.FogEnd
end

local function ToggleXRay(state)
  S.xRay = state
  if state then
    for _, p in ipairs(workspace:GetDescendants()) do
      if p:IsA("BasePart") and not p:IsDescendantOf(player.Character) and not Players:GetPlayerFromCharacter(p.Parent) then
        if not S.origTransparency[p] then S.origTransparency[p] = p.Transparency end
        p.Transparency = 0.65
      end
    end
  else
    for part, trans in pairs(S.origTransparency) do
      if part and part.Parent then part.Transparency = trans end
    end
    S.origTransparency = {}
  end
end

local function ToggleFPSBoost(state)
  S.fpsBoost = state
  if state then
    S.fpsBoostData = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
      if obj:IsA("SurfaceAppearance") then
        local p = obj.Parent
        if p then
          S.fpsBoostData[obj] = { type = "parent", value = p }; pcall(function() obj.Parent = nil end)
        end
      elseif obj:IsA("Decal") or obj:IsA("Texture") then
        local ok, cur = pcall(function() return obj.Transparency end)
        if ok and cur ~= 1 then
          S.fpsBoostData[obj] = { type = "transparency", value = cur }; pcall(function() obj.Transparency = 1 end)
        end
      elseif obj:IsA("SpecialMesh") then
        local ok, tid = pcall(function() return obj.TextureId end)
        if ok and tid ~= "" then
          S.fpsBoostData[obj] = { type = "meshTex", value = tid }; pcall(function() obj.TextureId = "" end)
        end
      elseif obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")
          or obj:IsA("Beam") or obj:IsA("Trail") then
        local ok, en = pcall(function() return obj.Enabled end)
        if ok and en then
          S.fpsBoostData[obj] = { type = "enabled", value = true }; pcall(function() obj.Enabled = false end)
        end
      end
    end
    S.fpsBoostData["globalShadows"] = Lighting.GlobalShadows
    Lighting.GlobalShadows = false
    S.fpsBoostData["fogEnd"] = Lighting.FogEnd
    Lighting.FogEnd = 100000
  else
    for obj, data in pairs(S.fpsBoostData) do
      pcall(function()
        if typeof(obj) == "string" then
          if obj == "globalShadows" then
            Lighting.GlobalShadows = data
          elseif obj == "fogEnd" then
            Lighting.FogEnd = data
          end
        else
          if data.type == "parent" then
            obj.Parent = data.value
          elseif obj.Parent ~= nil then
            if data.type == "transparency" then
              obj.Transparency = data.value
            elseif data.type == "meshTex" then
              obj.TextureId = data.value
            elseif data.type == "enabled" then
              obj.Enabled = data.value
            end
          end
        end
      end)
    end
    S.fpsBoostData = {}
  end
end

local function RestoreFPSBoost()
  if S.fpsBoost then ToggleFPSBoost(false) end
end

local function ToggleFreecam(state)
  S.freecam = state
  local hum = GetHumanoid()
  if state then
    if not S.freecamPart then
      S.freecamPart = Instance.new("Part")
      S.freecamPart.Size = Vector3.new(1, 1, 1)
      S.freecamPart.Transparency = 1
      S.freecamPart.CanCollide = false
      S.freecamPart.Anchored = true
      S.freecamPart.CFrame = camera.CFrame
      S.freecamPart.Parent = workspace
    end
    camera.CameraSubject = S.freecamPart
    if hum then hum.PlatformStand = true end
  else
    if S.freecamPart then
      S.freecamPart:Destroy(); S.freecamPart = nil
    end
    if hum then
      hum.PlatformStand = false; camera.CameraSubject = hum
    end
  end
end

ctx.Core.ToggleFullbright = ToggleFullbright
ctx.Core.ToggleDarkMode = ToggleDarkMode
ctx.Core.ToggleNoFog = ToggleNoFog
ctx.Core.ToggleXRay = ToggleXRay
ctx.Core.ToggleFPSBoost = ToggleFPSBoost
ctx.Core.RestoreFPSBoost = RestoreFPSBoost
ctx.Core.ToggleFreecam = ToggleFreecam
ctx.Core.UpdateDarkMode = UpdateDarkMode

-- ==================== UTILITY FUNCTIONS ====================
local function SavePosition()
  local root = GetRoot()
  if root then S.savedPositions["checkpoint"] = root.CFrame end
end

local function LoadPosition()
  local root = GetRoot()
  if root and S.savedPositions["checkpoint"] then
    root.CFrame = S.savedPositions["checkpoint"]
  end
end

local function SaveKeybinds_Alias() SaveKeybinds() end
local function LoadKeybinds_Alias() LoadKeybinds() end

local function Rejoin()
  SaveKeybinds()
  SaveSettings()
  if typeof(queue_on_teleport) == "function" then
    queue_on_teleport("if isfile and isfile('UniMenu_autorun.lua') then loadfile('UniMenu_autorun.lua')() end")
  end
  TeleportService:Teleport(game.PlaceId, player)
end

local function ServerHop()
  task.spawn(function()
    SaveKeybinds()
    SaveSettings()
    if typeof(queue_on_teleport) == "function" then
      queue_on_teleport("if isfile and isfile('UniMenu_autorun.lua') then loadfile('UniMenu_autorun.lua')() end")
    end
    local ok, result = pcall(function()
      return game:HttpGet("https://games.roblox.com/v1/games/" ..
        tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
    end)
    if ok and result then
      local success, data = pcall(function() return HttpService:JSONDecode(result) end)
      if success and data and data.data then
        for _, s in ipairs(data.data) do
          if s.playing and s.maxPlayers and s.playing < s.maxPlayers and s.id ~= game.JobId then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
            return
          end
        end
      end
    end
    TeleportService:Teleport(game.PlaceId, player)
  end)
end

local function ResetCharacter()
  local hum = GetHumanoid()
  if hum then hum.Health = 0 end
end

local antiAFKActive = false
local antiAFKConn = nil

local function ToggleAntiAFK(state)
  antiAFKActive = state
  if state then
    if not antiAFKConn then
      antiAFKConn = player.Idled:Connect(function()
        if not antiAFKActive then return end
        pcall(function()
          local vu = game:GetService("VirtualUser")
          if vu then
            vu:CaptureController(); vu:ClickButton2(Vector2.new(0, 0))
          end
        end)
      end)
      TrackConnection(antiAFKConn)
    end
  else
    if antiAFKConn then
      pcall(function() antiAFKConn:Disconnect() end); antiAFKConn = nil
    end
  end
end

local function CopyJobId()
  pcall(function() if setclipboard then setclipboard(tostring(game.JobId)) end end)
end

local function CopyPlaceId()
  pcall(function() if setclipboard then setclipboard(tostring(game.PlaceId)) end end)
end

local function CopyPlayerPosition()
  pcall(function()
    local root = GetRoot()
    if root and setclipboard then
      local p = root.Position
      setclipboard(string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z))
    end
  end)
end

local function UpdatePlayerList()
  playerList = {}
  for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then table.insert(playerList, plr) end
  end
  if selectedPlayer and not table.find(playerList, selectedPlayer) then
    selectedPlayer = nil
  end
end

local function TeleportToTarget()
  if not selectedPlayer or not selectedPlayer.Character then return end
  local targetRoot = selectedPlayer.Character:FindFirstChild("HumanoidRootPart") or
      selectedPlayer.Character.PrimaryPart
  local myRoot = GetRoot()
  if myRoot and targetRoot then
    myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
  end
end

local function FlingTarget()
  if not selectedPlayer or not selectedPlayer.Character then return end
  local targetRoot = selectedPlayer.Character:FindFirstChild("HumanoidRootPart") or
      selectedPlayer.Character.PrimaryPart
  local myRoot = GetRoot()
  local myHum = GetHumanoid()
  if not myRoot or not targetRoot or not myHum then return end
  if selectedPlayer == player then return end
  task.spawn(function()
    local bav = Instance.new("BodyAngularVelocity")
    bav.AngularVelocity = Vector3.new(0, 99999, 0)
    bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bav.Parent = targetRoot
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 200, 0)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = targetRoot
    for i = 1, 15 do
      if targetRoot and targetRoot.Parent then bv.Velocity = Vector3.new(0, 200, 0) end
      RunService.Heartbeat:Wait()
    end
    bav:Destroy()
    bv:Destroy()
  end)
end

local function TargetTrap()
  if not selectedPlayer or not selectedPlayer.Character then return end
  local targetRoot = selectedPlayer.Character:FindFirstChild("HumanoidRootPart") or
      selectedPlayer.Character.PrimaryPart
  if not targetRoot then return end
  local center = targetRoot.Position
  local parts = {}
  local offsets = {
    CFrame.new(0, 0, 4), CFrame.new(0, 0, -4),
    CFrame.new(4, 0, 0), CFrame.new(-4, 0, 0),
    CFrame.new(0, 4, 0), CFrame.new(0, -4, 0)
  }
  local sizes = {
    Vector3.new(8, 8, 1), Vector3.new(8, 8, 1),
    Vector3.new(1, 8, 8), Vector3.new(1, 8, 8),
    Vector3.new(8, 1, 8), Vector3.new(8, 1, 8)
  }
  for i = 1, 6 do
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = true
    p.Transparency = 0.5
    p.BrickColor = BrickColor.new("Bright red")
    p.Material = Enum.Material.Forcefield
    p.Size = sizes[i]
    p.CFrame = CFrame.new(center) * offsets[i]
    p.Parent = workspace
    table.insert(parts, p)
  end
  task.delay(5, function()
    for _, p in ipairs(parts) do
      if p and p.Parent then p:Destroy() end
    end
  end)
end

local function HeadSitTarget()
  if not selectedPlayer or not selectedPlayer.Character then return end
  local targetHead = selectedPlayer.Character:FindFirstChild("Head")
  local myRoot = GetRoot()
  local myHum = GetHumanoid()
  if myRoot and targetHead and myHum then
    myHum.Sit = true
    myRoot.CFrame = targetHead.CFrame + Vector3.new(0, 2, 0)
  end
end

ctx.Core.SavePosition = SavePosition
ctx.Core.LoadPosition = LoadPosition
ctx.Core.Rejoin = Rejoin
ctx.Core.ServerHop = ServerHop
ctx.Core.ResetCharacter = ResetCharacter
ctx.Core.ToggleAntiAFK = ToggleAntiAFK
ctx.Core.CopyJobId = CopyJobId
ctx.Core.CopyPlaceId = CopyPlaceId
ctx.Core.CopyPlayerPosition = CopyPlayerPosition
ctx.Core.UpdatePlayerList = UpdatePlayerList
ctx.Core.TeleportToTarget = TeleportToTarget
ctx.Core.FlingTarget = FlingTarget
ctx.Core.TargetTrap = TargetTrap
ctx.Core.HeadSitTarget = HeadSitTarget
ctx.Core.selectedPlayer = selectedPlayer
ctx.Core.playerList = playerList
ctx.Core.gui = gui
ctx.Core.isOpen = isOpen
ctx.Core.currentTab = currentTab
ctx.Core.contentContainerRef = contentContainerRef
ctx.Core.isTransitioning = isTransitioning

-- ==================== PERSIST SCRIPT ====================
local function PersistScript()
  if typeof(writefile) ~= "function" then return end
  if isfile and isfile("UniMenu_autorun.lua") then return end
  for level = 1, 20 do
    local ok, info = pcall(debug.getinfo, level, "S")
    if not ok or not info then break end
    if info.source and info.source:sub(1, 1) == "@" then
      local fpath = info.source:sub(2)
      if isfile and isfile(fpath) then
        local content
        local ok2 = pcall(function() content = readfile(fpath) end)
        if ok2 and content and #content > 100 then
          writefile("UniMenu_autorun.lua", content)
          return
        end
      end
    end
  end
end

ctx.Core.PersistScript = PersistScript

-- ==================== CLEANUP ====================
local function CleanupAll()
  isScriptRunning = false
  for _, conn in ipairs(Connections) do
    pcall(function() conn:Disconnect() end)
  end
  Connections = {}

  for _, g in ipairs(PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name == "CheatMenu" then g:Destroy() end
  end
  for _, g in ipairs(PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name == "CheatHUD" then g:Destroy() end
  end

  if S.espFolder then
    S.espFolder:Destroy(); S.espFolder = nil
  end
  if S.chamsFolder then
    S.chamsFolder:Destroy(); S.chamsFolder = nil
  end
  local gunFolder = workspace:FindFirstChild("CheatMenu_GunESP")
  if gunFolder then gunFolder:Destroy() end
  local coinFolder = workspace:FindFirstChild("CheatMenu_CoinESP")
  if coinFolder then coinFolder:Destroy() end
  if S.freecamPart then
    S.freecamPart:Destroy(); S.freecamPart = nil
  end
  fpsSampleBuf = {}; fpsSampleIdx = 0
  RestoreCollision()

  if S.flyBV then
    S.flyBV:Destroy(); S.flyBV = nil
  end

  for part, trans in pairs(S.origTransparency) do
    if part and part.Parent then part.Transparency = trans end
  end
  S.origTransparency = {}

  for sound, originalVol in pairs(S.origSoundVolumes) do
    if sound and sound.Parent then sound.Volume = originalVol end
  end
  S.origSoundVolumes = {}

  workspace.Gravity = originalGravity
  local hum = GetHumanoid()
  if hum then
    hum.HipHeight = originalHipHeight
    hum.WalkSpeed = originalWalkSpeed
    hum.JumpPower = originalJumpPower
    hum.PlatformStand = false
  end
  camera.CameraSubject = hum
  camera.FieldOfView = originalFOV
  RestoreFPSBoost()

  Lighting.Brightness = S.origLighting.Brightness
  Lighting.ClockTime = S.origLighting.ClockTime
  Lighting.FogEnd = S.origLighting.FogEnd
  Lighting.GlobalShadows = S.origLighting.GlobalShadows
  Lighting.Ambient = S.origLighting.Ambient

  if ctx.Game.MM2 and ctx.Game.MM2.RemoveMagicBulletHook then
    ctx.Game.MM2.RemoveMagicBulletHook()
  end
  MM2.magicBullet = false
end

ctx.Core.CleanupAll = CleanupAll
_G.CheatPanelCleanup = CleanupAll

-- ==================== STEP CONNECTION (NoClip, AntiFling) ====================
TrackConnection(RunService.Stepped:Connect(function()
  if S.noclip then
    local char = player.Character
    if char then
      for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.CanCollide then
          part.CanCollide = false
        end
      end
    end
  end
  if S.antiFling then
    local root = GetRoot()
    if root then
      pcall(function()
        root.RotVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.AssemblyAngularAcceleration = Vector3.zero
        if root.AssemblyLinearVelocity.Magnitude > 50 then
          root.AssemblyLinearVelocity = root.AssemblyLinearVelocity.Unit * 30
        end
        for _, c in ipairs(root:GetChildren()) do
          if c:IsA("BodyVelocity") or c:IsA("BodyForce") or c:IsA("BodyAngularVelocity") or c:IsA("BodyGyro")
              or c:IsA("VectorForce") or c:IsA("LineForce") then
            c:Destroy()
          end
        end
      end)
    end
  end
end))

-- ==================== INF JUMP & CLICK TP ====================
TrackConnection(UserInputService.JumpRequest:Connect(function()
  if S.infJump then
    local hum = GetHumanoid()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
  end
end))

TrackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if S.clickTP and input.UserInputType == Enum.UserInputType.MouseButton1
      and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
    local mouse = player:GetMouse()
    local root = GetRoot()
    if root and mouse.Hit then
      root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
    end
  end
end))

-- ==================== COLLISION GROUPS ====================
local playerCollisionGroup = "PlayerCollisionGroup"
local otherPlayersGroup = "OtherPlayersGroup"
local ghostGroup = "CoinFarmGhost"
pcall(function()
  PhysicsService:CreateCollisionGroup(playerCollisionGroup)
  PhysicsService:CreateCollisionGroup(otherPlayersGroup)
  PhysicsService:CreateCollisionGroup(ghostGroup)
  PhysicsService:CollisionGroupSetCollidable(playerCollisionGroup, otherPlayersGroup, false)
  PhysicsService:CollisionGroupSetCollidable(otherPlayersGroup, otherPlayersGroup, false)
  PhysicsService:CollisionGroupSetCollidable(ghostGroup, ghostGroup, false)
  PhysicsService:CollisionGroupSetCollidable(ghostGroup, "Default", false)
  PhysicsService:CollisionGroupSetCollidable(ghostGroup, playerCollisionGroup, false)
  PhysicsService:CollisionGroupSetCollidable(ghostGroup, otherPlayersGroup, false)
end)

local function setPlayerCollisionGroup(char, group)
  if not char then return end
  for _, part in ipairs(char:GetDescendants()) do
    if part:IsA("BasePart") then
      pcall(function() part.CollisionGroup = group end)
    end
  end
end

player.CharacterAdded:Connect(function(char)
  setPlayerCollisionGroup(char, playerCollisionGroup)
end)
setPlayerCollisionGroup(player.Character, playerCollisionGroup)

for _, plr in ipairs(Players:GetPlayers()) do
  if plr ~= player then
    if plr.Character then setPlayerCollisionGroup(plr.Character, otherPlayersGroup) end
    plr.CharacterAdded:Connect(function(c) setPlayerCollisionGroup(c, otherPlayersGroup) end)
  end
end
Players.PlayerAdded:Connect(function(plr)
  if plr ~= player then
    plr.CharacterAdded:Connect(function(c) setPlayerCollisionGroup(c, otherPlayersGroup) end)
  end
end)

-- ==================== MAIN HEARTBEAT LOOP ====================
TrackConnection(RunService.Heartbeat:Connect(function(deltaTime)
  local root = GetRoot()
  local hum = GetHumanoid()

  -- CS2 Surfing
  if S.cs2Surf and root and hum then
    if hum.FloorMaterial ~= Enum.Material.Air then
      local rayOrigin = root.Position + Vector3.new(0, 3, 0)
      local raycastParams = RaycastParams.new()
      raycastParams.FilterDescendantsInstances = { player.Character }
      raycastParams.FilterType = Enum.RaycastFilterType.Exclude
      local hit = workspace:Raycast(rayOrigin, Vector3.new(0, -6, 0), raycastParams)
      if hit then
        local n = hit.Normal
        local hSlope = Vector2.new(n.X, n.Z).Magnitude
        if hSlope > 0.3 and n.Y < 0.85 then
          S.isSurfing = true
          hum.PlatformStand = true
          local slideDir = Vector3.new(0, -1, 0) - (Vector3.new(0, -1, 0):Dot(n) * n)
          if slideDir.Magnitude > 0 then slideDir = slideDir.Unit end
          local camLook = camera.CFrame.LookVector
          local inputInfluence = camLook - (camLook:Dot(n) * n)
          if inputInfluence.Magnitude > 0 then inputInfluence = inputInfluence.Unit end
          local finalDir = (slideDir * 0.6 + inputInfluence * 0.4).Unit
          root.Velocity = finalDir * gameConfig.surfSpeed + Vector3.new(0, -2, 0)
        else
          if S.isSurfing then
            S.isSurfing = false; hum.PlatformStand = false
          end
        end
      else
        if S.isSurfing then
          S.isSurfing = false; hum.PlatformStand = false
        end
      end
    else
      if S.isSurfing then
        S.isSurfing = false; hum.PlatformStand = false
      end
    end
  end

  -- CS2 Bhop
  if S.cs2Bhop and hum and root then
    local onGround = hum.FloorMaterial ~= Enum.Material.Air
    if onGround and S.bhopWasOnGround == false then
      hum:ChangeState(Enum.HumanoidStateType.Jumping)
      local vel = root.Velocity
      local hSpeed = Vector2.new(vel.X, vel.Z).Magnitude
      if hSpeed > 0.5 then
        local hDir = Vector3.new(vel.X, 0, vel.Z).Unit
        root.Velocity = hDir * (hSpeed * gameConfig.bhopAccel) + Vector3.new(0, vel.Y, 0)
      end
    end
    S.bhopWasOnGround = onGround
  end

  -- Fly
  if S.fly and S.flyBV and S.flyBV.Parent then
    local moveDirection = Vector3.new(0, 0, 0)
    local forward = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector
    local up = camera.CFrame.UpVector
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - right end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + right end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + up end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection - up end
    if moveDirection.Magnitude > 0 then
      S.flyBV.Velocity = moveDirection.Unit * gameConfig.flySpeed
    else
      S.flyBV.Velocity = Vector3.new(0, 0, 0)
    end
  end

  -- Freecam
  if S.freecam and S.freecamPart then
    local moveDir = Vector3.new(0, 0, 0)
    local camCF = camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir - Vector3.new(0, 1, 0) end
    if moveDir.Magnitude > 0 then
      S.freecamPart.CFrame = S.freecamPart.CFrame + moveDir.Unit * (gameConfig.flySpeed * deltaTime)
    end
  end

  -- AutoClicker
  if S.autoClicker and typeof(mouse1click) == "function" then
    pcall(mouse1click)
  end

  -- Run additional heartbeat callbacks from modules
  for _, cb in ipairs(heartbeatCallbacks) do
    pcall(cb, deltaTime, root, hum)
  end

  -- Aimbot
  if S.aimbot and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
    local targetPartName = S.aimbotTargetPart or "Head"
    local closestPart, minDist = nil, gameConfig.aimbotFOV
    local mousePos = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
      if plr ~= player and plr.Character then
        local targetPart = plr.Character:FindFirstChild(targetPartName)
        local p_hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if targetPart and p_hum and p_hum.Health > 0 then
          local screenPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
          if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
            if dist < minDist then
              minDist = dist; closestPart = targetPart
            end
          end
        end
      end
    end
    if closestPart then
      local camPos = camera.CFrame.Position
      local targetPos = closestPart.Position
      local targetCFrame = CFrame.lookAt(camPos, targetPos)
      camera.CFrame = camera.CFrame:Lerp(targetCFrame, gameConfig.aimbotSmoothness)
    end
  end

  -- Triggerbot
  if S.triggerbot then
    local mouse = player:GetMouse()
    if mouse.Target then
      local targetChar = mouse.Target:FindFirstAncestorOfClass("Model")
      if targetChar and targetChar ~= player.Character and Players:GetPlayerFromCharacter(targetChar) then
        mouse1click()
      end
    end
  end
end))

-- ==================== PEER BROADCAST ====================
TrackConnection(RunService.Heartbeat:Connect(function(dt)
  peerBroadcastTimer = peerBroadcastTimer + dt
  if peerBroadcastTimer >= 2 then
    peerBroadcastTimer = 0
    BroadcastPeerData()
    if S.showPeerIcon then ScanPeers() end
  end
end))

-- ==================== PLAYER EVENTS ====================
TrackConnection(Players.PlayerAdded:Connect(function(plr)
  UpdatePlayerList()
  TrackConnection(plr.CharacterAdded:Connect(function()
    if S.esp then
      task.wait(0.3); if ctx.UI and ctx.UI.AddESP then ctx.UI.AddESP(plr) end
    end
    if S.chams then
      task.wait(0.3); if ctx.UI and ctx.UI.ToggleChams then ctx.UI.ToggleChams(true) end
    end
  end))
end))

TrackConnection(Players.PlayerRemoving:Connect(function(plr)
  if S.espFolder then
    local hl = S.espFolder:FindFirstChild(plr.Name .. "_HL")
    if hl then hl:Destroy() end
    local tag = S.espFolder:FindFirstChild(plr.Name .. "_Tag")
    if tag then tag:Destroy() end
  end
  RemovePeerBillboard(plr)
  UpdatePlayerList()
end))

for _, plr in ipairs(Players:GetPlayers()) do
  if plr ~= player then
    TrackConnection(plr.CharacterAdded:Connect(function()
      if S.esp then
        task.wait(0.3); if ctx.UI and ctx.UI.AddESP then ctx.UI.AddESP(plr) end
      end
      if S.chams then
        task.wait(0.3); if ctx.UI and ctx.UI.ToggleChams then ctx.UI.ToggleChams(true) end
      end
    end))
  end
end

UpdatePlayerList()

TrackConnection(player.CharacterAdded:Connect(function(char)
  task.wait(0.3)
  local hum = char:WaitForChild("Humanoid", 3)
  local root = char:WaitForChild("HumanoidRootPart", 3)
  if hum then
    if S.speed then hum.WalkSpeed = gameConfig.walkSpeed end
    if S.jump then hum.JumpPower = gameConfig.jumpPower end
    if S.hipHeight then hum.HipHeight = gameConfig.hipHeight end
  end
  if S.fly and root then
    if S.flyBV then S.flyBV:Destroy() end
    S.flyBV = Instance.new("BodyVelocity")
    S.flyBV.MaxForce = Vector3.new(40000, 40000, 40000)
    S.flyBV.Velocity = Vector3.new(0, 0, 0)
    S.flyBV.Parent = root
  end
  if not S.noclip then RestoreCollision() end
  S.bhopWasOnGround = false
end))

-- ==================== INIT ====================
local function Init()
  isScriptRunning = true
  -- FPS Uncap
  pcall(function() setfpscap(0) end)

  -- Load saved data
  LoadKeybinds()
  LoadSettings()

  -- Build keybind registry
  for tabName, tabFeats in pairs(features) do
    for _, feat in ipairs(tabFeats) do
      if feat.isToggle and feat.toggle and not feat.isButton then
        local kbName = tabName .. "::" .. feat.name
        if not keybindRegistry[kbName] then
          keybindRegistry[kbName] = {
            get = feat.get,
            toggle = feat.toggle,
            tab = tabName,
            featName = feat.name
          }
        end
      end
    end
  end
  RebuildKeybindMap()

  -- Start Last.fm polling if user is configured
  if StartLastfmPolling then StartLastfmPolling() end

  -- Broadcast peer + persist
  BroadcastPeerData()
  ScanPeers()
  PersistScript()

  -- Initialize player list for Trolling tab
  UpdatePlayerList()
  TrackConnection(Players.PlayerAdded:Connect(UpdatePlayerList))
  TrackConnection(Players.PlayerRemoving:Connect(UpdatePlayerList))

  -- Save on disconnect
  player.AncestryChanged:Connect(function(_, parent)
    if not parent then
      SaveKeybinds(); SaveSettings()
    end
  end)

  -- Teleport hook
  pcall(function()
    TeleportService.TeleportInitiate:Connect(function()
      SaveKeybinds(); SaveSettings()
      if typeof(queue_on_teleport) == "function" then
        queue_on_teleport("if isfile and isfile('UniMenu_autorun.lua') then loadfile('UniMenu_autorun.lua')() end")
      end
    end)
  end)

  -- Keybind listener
  TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == keybinds.menuToggle then
      if ctx.UI and ctx.UI.ToggleGUI then ctx.UI.ToggleGUI() end
      return
    end
    local kbName = activeKeybindMap[input.KeyCode]
    if kbName and kbName ~= "menuToggle" then
      local reg = keybindRegistry[kbName]
      if reg and reg.get and reg.toggle then
        reg.toggle(not reg.get())
        local state = reg.get() and "enabled" or "disabled"
        if ctx.Core.ShowNotification then
          ctx.Core.ShowNotification(reg.featName .. " " .. state)
        end
        -- Notify UI to update button state
        if ctx.Core.NotifyKeybindUIUpdate then
          ctx.Core.NotifyKeybindUIUpdate(kbName, reg.get())
        end
      end
    end
  end))

  -- Build HUD
  if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end

  -- Initialize Spotify
  if ctx.Core.Spotify and ctx.Core.Spotify.Init then
    ctx.Core.Spotify.Init()
  end

  RestoreCollision()
end

local function SetTheme(name)
  if not name or not Themes[name] then return false end
  ctx.Config.currentThemeName = name
  ctx.Config.XP = Themes[name]
  Music.usingDynamicTheme = false
  Music.dynamicTheme = nil
  SaveSettings()
  if ctx.UI and ctx.UI.ApplyTheme then ctx.UI.ApplyTheme() end
  return true
end

ctx.Core.SetTheme = SetTheme
ctx.Core.Init = Init
ctx.Modules.core = true
