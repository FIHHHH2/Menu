-- Universal Cheat Panel v10 (Windows Vista Aero & Themed Overhead Nametags)
if _G.CheatPanelCleanup then
  pcall(_G.CheatPanelCleanup)
end

-- ==================== FPS UNCAP ====================
-- Try executor-native setfpscap (Synapse X / Wave / Fluxus etc.)
local uncapOk = pcall(function()
  setfpscap(0)
end)
-- Fallback: settings().Rendering quality cap (works on some executors)
if not uncapOk then
  pcall(function()
    local rs = settings().Rendering
    if rs then
      rs.FrameRateManager = Enum.FrameRateManager.Adaptive
      rs.QualityLevel     = Enum.QualityLevel.Automatic
    end
  end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Global tracking table for cleanup
local Connections = {}
local function TrackConnection(conn)
  table.insert(Connections, conn)
  return conn
end

-- FPS State Tracking
local FPS_SAMPLES  = 30
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

-- Safely get character / parts
local function GetCharacter()
  return player.Character
end

local function GetHumanoid()
  local char = GetCharacter()
  return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRoot()
  local char = GetCharacter()
  return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

-- Safety check: returns true only if player is alive, has a character, and is in a playable state (not dead/spectating)
local function IsPlayerActive()
  local char = GetCharacter()
  if not char then return false end
  local hum = char:FindFirstChildOfClass("Humanoid")
  if not hum or hum.Health <= 0 then return false end
  -- Optional: ensure we're not in the lobby by checking if character is on a valid map
  local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
  if not root then return false end
  return true
end

-- Restore character collisions to standard Roblox physics (accessories NEVER collide)
local function RestoreCollision()
  local char = GetCharacter()
  if char then
    for _, p in ipairs(char:GetDescendants()) do
      if p:IsA("BasePart") then
        -- Accessories, hats, hair, tools, and handles must NEVER collide with the map
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

-- Themes Palette Definition
local Themes              = {
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
    -- Overhead Tag Colors
    tagBg = Color3.fromRGB(246, 243, 232),
    tagHeader = Color3.fromRGB(39, 105, 204),
    tagText = Color3.fromRGB(20, 20, 20),
    tagBorder = Color3.fromRGB(10, 36, 106)
  },
  ["Windows Vista Aero"] = {
    -- Authentic glass chrome: vivid blue title bar, light silver-white content areas
    windowBg        = Color3.fromRGB(236, 242, 252), -- cool off-white content
    windowBgLight   = Color3.fromRGB(255, 255, 255), -- pure white top
    windowBgDark    = Color3.fromRGB(215, 228, 248), -- soft blue-grey bottom
    titleBar        = Color3.fromRGB(62, 130, 210),  -- vivid Vista blue
    titleBarGrad1   = Color3.fromRGB(155, 205, 255), -- glass shimmer highlight (top)
    titleBarGrad2   = Color3.fromRGB(62, 130, 210),  -- mid vivid blue
    titleBarGrad3   = Color3.fromRGB(22, 78, 168),   -- deep blue bottom
    sidebar1        = Color3.fromRGB(190, 215, 245), -- light cool blue sidebar
    sidebar2        = Color3.fromRGB(165, 198, 238), -- slightly deeper sidebar
    panel1          = Color3.fromRGB(248, 251, 255), -- near-white panel
    panel2          = Color3.fromRGB(232, 241, 254), -- faint blue-tinted panel
    rowBg           = Color3.fromRGB(255, 255, 255), -- white rows
    borderLight     = Color3.fromRGB(170, 205, 245), -- soft glass blue border
    borderDark      = Color3.fromRGB(110, 160, 220), -- medium blue border
    tabActive       = Color3.fromRGB(255, 255, 255), -- white active tab
    tabInactive     = Color3.fromRGB(200, 222, 248), -- ice-blue inactive tab
    tabActiveText   = Color3.fromRGB(18, 70, 155),   -- dark navy text on white
    tabInactiveText = Color3.fromRGB(55, 95, 150),   -- medium blue-grey text
    text            = Color3.fromRGB(20, 20, 20),    -- near-black (light bg)
    accent          = Color3.fromRGB(0, 102, 204),   -- Vista signature blue
    green           = Color3.fromRGB(0, 170, 80),
    red             = Color3.fromRGB(200, 40, 40),
    -- Overhead Tag Colors
    tagBg           = Color3.fromRGB(240, 246, 255),
    tagHeader       = Color3.fromRGB(62, 130, 210),
    tagText         = Color3.fromRGB(20, 20, 20),
    tagBorder       = Color3.fromRGB(22, 78, 168)
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
    -- Overhead Tag Colors
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
    -- Overhead Tag Colors
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
    -- Overhead Tag Colors
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
    -- Overhead Tag Colors
    tagBg = Color3.fromRGB(35, 20, 46),
    tagHeader = Color3.fromRGB(65, 25, 85),
    tagText = Color3.fromRGB(245, 230, 255),
    tagBorder = Color3.fromRGB(180, 80, 255)
  }
}

local currentThemeName    = "Windows XP Luna"
local XP                  = Themes[currentThemeName]

-- Configuration State
local gameConfig          = {
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
  nightDimness = 0.45
}

local initHum             = GetHumanoid()
local originalWalkSpeed   = initHum and initHum.WalkSpeed or 16
local originalJumpPower   = initHum and initHum.JumpPower or 50
local originalHipHeight   = initHum and initHum.HipHeight or 0
local originalGravity     = workspace.Gravity
local originalFOV         = camera.FieldOfView

-- ==================== GROUPED STATE TABLES ====================
-- Collapsing individual locals into tables to stay under Luau's 200-register limit.

local S                   = {
  -- Combat
  aimbot           = false,
  triggerbot       = false,
  autoClicker      = false,
  -- Movement
  speed            = false,
  fly              = false,
  flyBV            = nil,
  jump             = false,
  noclip           = false,
  infJump          = false,
  clickTP          = false,
  spinbot          = false,
  antiFling        = false,
  hipHeight        = false,
  lowGravity       = false,
  cs2Bhop          = false,
  cs2Surf          = false,
  isSurfing        = false,
  bhopWasOnGround  = false,
  -- Visuals
  esp              = false,
  fullbright       = false,
  darkMode         = false,
  nightFX          = nil,
  chams            = false,
  noFog            = false,
  noVFX            = false,
  xRay             = false,
  freecam          = false,
  freecamPart      = nil,
  noVFXConn        = nil,
  disabledVFX      = {},
  fpsBoost         = false,
  fpsBoostData     = {},
  -- Misc / Exploits
  spectate         = false,
  coinTweening     = false,
  grabbingGun      = false,
  -- Shared data
  espFolder        = nil,
  showPeerIcon     = true,
  hudEnabled       = true,
  chamsFolder      = nil,
  savedPositions   = {},
  origTransparency = {},
  origSoundVolumes = {},
  origLighting     = {
    Brightness     = Lighting.Brightness,
    ClockTime      = Lighting.ClockTime,
    FogEnd         = Lighting.FogEnd,
    GlobalShadows  = Lighting.GlobalShadows,
    Ambient        = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
  },
}

local Music               = {
  user                = "",
  apiKey              = "b25b959554ed76058ac220b7b2e0a026",
  song                = "",
  artist              = "",
  album               = "",
  active              = false,
  coverAsset          = "",
  coverIsProcedural   = false,
  lastCoverUrl        = "",
  dynamicColorEnabled = true,
  usingDynamicTheme   = false,
  dynamicTheme        = nil,
  statusText          = "Enter Last.fm username to connect",
  hudLabel            = nil,
  hudCover            = nil,
  menuSongLbl         = nil,
  menuArtLbl          = nil,
  menuStatusLbl       = nil,
  menuCover           = nil,
  peerIcon            = "rbxassetid://6274377121",
}

local MM2                 = {
  roleESP       = false,
  gunESP        = true,
  trapESP       = false,
  coinESP       = false,
  autoShoot     = false,
  magicBullet   = false,
  antiStab      = false,
  autoCoins     = false,
  autoGrabGun   = false,
  knifeAura     = false,
  autoFollow    = false,
  platformMode  = false,
  boostMode     = false,
  auraRadius    = 15,
  coinDelay     = 0.25,
  lastCoinTime  = 0,
  lastShootTime = 0,
  lastDodgeTime = 0,
  lastGrabTime  = 0,
  trapFolder    = nil,
}

-- GUI state (kept as separate locals — small count, frequently accessed)
local isOpen              = false
local gui                 = nil
local currentTab          = "Movement"
local selectedPlayer      = nil
local playerList          = {}
local isTransitioning     = false
local contentContainerRef = nil

local HttpService         = game:GetService("HttpService")

local KEYBIND_FILE        = "UniMenu_keybinds.json"
local SETTINGS_FILE       = "UniMenu_settings.json"

local keybinds            = {
  menuToggle = Enum.KeyCode.RightBracket
}

-- Keybind registry: maps keybind name -> { get, toggle, tab, featName }
-- Populated dynamically in BuildContent when the Keybinds tab renders.
local keybindRegistry     = {}

-- Active keybind map: maps KeyCode -> keybind name (for fast lookup)
local activeKeybindMap    = {}
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

-- Save keybinds to file (KeyCode -> name string, stored as key name string)
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

-- Load keybinds from file on startup
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

-- Save settings (Last.fm username etc.) to file
local function SaveSettings()
  if typeof(writefile) ~= "function" then return end
  local data = {
    lastfmUser = Music.user or "",
    peerIcon   = Music.peerIcon or "rbxassetid://6274377121",
  }
  local json = HttpService:JSONEncode(data)
  writefile(SETTINGS_FILE, json)
end

-- Load settings from file
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
end



local BuildGUI, BuildContent, BuildHUD

local function Animate(object, properties, duration)
  duration = duration or 0.15
  local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    properties)
  tween:Play()
  return tween
end

local isScriptRunning   = true
local lastESPUpdateTick = 0

-- ==================== UNIVERSAL MASTER SOUND CONTROLLER ====================
local function IsVoiceChatSound(sound)
  local name = sound.Name:lower()
  if name:find("voice") or name:find("mic") or name:find("chat") or name:find("audioin") then
    return true
  end
  if sound.Parent and sound.Parent.Name:lower():find("voice") then
    return true
  end
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
    if obj:IsA("Sound") then
      ApplySoundVolume(obj)
    end
  end
  for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("Sound") then
      ApplySoundVolume(obj)
    end
  end
end

TrackConnection(SoundService.DescendantAdded:Connect(function(descendant)
  if descendant:IsA("Sound") then
    ApplySoundVolume(descendant)
  end
end))

-- ==================== CLEANUP HANDLER ====================
local function CleanupAll()
  isScriptRunning = false
  for _, conn in ipairs(Connections) do
    pcall(function() conn:Disconnect() end)
  end
  Connections = {}

  for _, g in ipairs(PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name == "CheatMenu" then
      g:Destroy()
    end
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
  ResetCoinCache()
  if S.freecamPart then
    S.freecamPart:Destroy(); S.freecamPart = nil
  end
  fpsSampleBuf = {}; fpsSampleIdx = 0

  RestoreCollision()

  if S.flyBV then
    S.flyBV:Destroy()
    S.flyBV = nil
  end

  for part, trans in pairs(S.origTransparency) do
    if part and part.Parent then part.Transparency = trans end
  end
  S.origTransparency = {}

  for sound, originalVol in pairs(S.origSoundVolumes) do
    if sound and sound.Parent then
      sound.Volume = originalVol
    end
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

  RemoveMagicBulletHook()
  MM2.magicBullet = false
end

_G.CheatPanelCleanup = CleanupAll
_G.UpdateMagicBullet = UpdateMagicBullet

-- ==================== THEMED ESP & OVERHEAD NAMETAGS ====================
local function GetESPFolder()
  local f = workspace:FindFirstChild("CheatMenu_ESP")
  if not f then
    f = Instance.new("Folder")
    f.Name = "CheatMenu_ESP"
    f.Parent = workspace
  end
  S.espFolder = f
  return f
end

local function ClearESP()
  if S.espFolder then S.espFolder:ClearAllChildren() end
  local existing = workspace:FindFirstChild("CheatMenu_ESP")
  if existing then existing:ClearAllChildren() end
end

local function AddESP(targetPlr)
  if targetPlr == player or (not S.esp and not MM2.roleESP) then return end
  local char = targetPlr.Character
  if not char then return end

  local folder = GetESPFolder()
  local oldHL = folder:FindFirstChild(targetPlr.Name .. "_HL")
  if oldHL then oldHL:Destroy() end
  local oldBB = folder:FindFirstChild(targetPlr.Name .. "_Tag")
  if oldBB then oldBB:Destroy() end

  -- Determine Role Color & Header for MM2
  local fillColor = Color3.fromRGB(255, 50, 50)
  local headerColor = XP.tagHeader
  local rolePrefix = ""
  if MM2.roleESP then
    local bp = targetPlr:FindFirstChild("Backpack")
    local hasKnife = (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
    local hasGun = (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun"))
    if hasKnife then
      fillColor = Color3.fromRGB(255, 30, 30)
      headerColor = Color3.fromRGB(210, 25, 25)
      rolePrefix = "[MURDERER] "
    elseif hasGun then
      fillColor = Color3.fromRGB(30, 140, 255)
      headerColor = Color3.fromRGB(20, 110, 225)
      rolePrefix = "[SHERIFF] "
    else
      fillColor = Color3.fromRGB(40, 215, 90)
      headerColor = Color3.fromRGB(25, 150, 65)
      rolePrefix = "[INNOCENT] "
    end
  end

  local hl = Instance.new("Highlight")
  hl.Name = targetPlr.Name .. "_HL"
  hl.FillColor = fillColor
  hl.FillTransparency = gameConfig.espFillTrans
  hl.OutlineColor = Color3.fromRGB(255, 255, 255)
  hl.OutlineTransparency = gameConfig.espOutlineTrans
  hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
  hl.Adornee = char
  hl.Parent = folder

  local head = char:FindFirstChild("Head")
  if head then
    local bb = Instance.new("BillboardGui")
    bb.Name = targetPlr.Name .. "_Tag"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 140, 0, 34)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 80   -- hide beyond 80 studs
    bb.LightInfluence = 0 -- consistent visibility regardless of lighting
    bb.ClipsDescendants = false
    bb.Parent = folder

    local tagWindow = Instance.new("Frame")
    tagWindow.Name = "TagWindow"
    tagWindow.Size = UDim2.new(1, 0, 1, 0)
    tagWindow.BackgroundColor3 = XP.tagBg
    tagWindow.BackgroundTransparency = 0.35
    tagWindow.BorderSizePixel = 1
    tagWindow.BorderColor3 = XP.tagBorder
    tagWindow.Parent = bb

    local tagHeader = Instance.new("Frame")
    tagHeader.Name = "TagHeader"
    tagHeader.Size = UDim2.new(1, 0, 0, 16)
    tagHeader.BackgroundColor3 = headerColor
    tagHeader.BackgroundTransparency = 0.2
    tagHeader.BorderSizePixel = 0
    tagHeader.Parent = tagWindow

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -6, 1, 0)
    nameLabel.Position = UDim2.new(0, 3, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = rolePrefix .. targetPlr.DisplayName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = gameConfig.espTextSize
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = tagHeader

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, -6, 0, 18)
    infoLabel.Position = UDim2.new(0, 3, 0, 17)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "@" .. targetPlr.Name .. " | [0m]"
    infoLabel.TextColor3 = XP.tagText
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = math.max(gameConfig.espTextSize - 2, 8)
    infoLabel.TextTruncate = Enum.TextTruncate.AtEnd
    infoLabel.Parent = tagWindow
  end
end

local function UpdateESP()
  ClearESP()
  if not S.esp then return end
  for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then AddESP(plr) end
  end
end

local function UpdateESPTheme()
  if not S.espFolder then return end
  for _, tag in ipairs(S.espFolder:GetChildren()) do
    if tag:IsA("BillboardGui") and tag:FindFirstChild("TagWindow") then
      local win = tag.TagWindow
      win.BackgroundColor3 = XP.tagBg
      win.BorderColor3 = XP.tagBorder
      if win:FindFirstChild("TagHeader") then
        win.TagHeader.BackgroundColor3 = XP.tagHeader
      end
      if win:FindFirstChild("InfoLabel") then
        win.InfoLabel.TextColor3 = XP.tagText
      end
    end
  end
end

local function UpdateESPTransparency()
  if not S.espFolder then return end
  for _, child in ipairs(S.espFolder:GetChildren()) do
    if child:IsA("Highlight") then
      child.FillTransparency = gameConfig.espFillTrans
      child.OutlineTransparency = gameConfig.espOutlineTrans
    end
  end
end

local function ToggleESP(state)
  S.esp = state
  if state then UpdateESP() else ClearESP() end
end

-- ==================== PEER DETECTION (same-script users) ====================
local peerBillboards = {} -- playerName -> BillboardGui

local function BroadcastPeerData()
  local data = HttpService:JSONEncode({
    icon = Music.peerIcon or "rbxassetid://6274377121",
    song = Music.song or "",
    artist = Music.artist or "",
    active = Music.active or false,
    ver = "9.7",
  })
  player:SetAttribute("UniMenu_Peer", data)
end

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

  local char = plr.Character
  if not char then return end
  local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
  if not hrp then return end

  local bb = Instance.new("BillboardGui")
  bb.Name = "UniMenu_Peer_" .. plr.Name
  bb.Adornee = hrp
  bb.Size = UDim2.new(0, 120, 0, 44)
  bb.StudsOffset = Vector3.new(0, 3.5, 0)
  bb.AlwaysOnTop = true
  bb.LightInfluence = 0
  bb.MaxDistance = 150
  bb.Parent = GetESPFolder()

  local bg = Instance.new("Frame")
  bg.Size = UDim2.new(1, 0, 1, 0)
  bg.BackgroundColor3 = XP.windowBg
  bg.BackgroundTransparency = 0.15
  bg.BorderSizePixel = 1
  bg.BorderColor3 = XP.accent
  bg.Parent = bb

  local bgGrad = Instance.new("UIGradient")
  bgGrad.Rotation = 90
  bgGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.windowBgLight),
    ColorSequenceKeypoint.new(1, XP.windowBgDark),
  })
  bgGrad.Parent = bg

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
  nameLbl.TextColor3 = XP.accent
  nameLbl.BackgroundTransparency = 1
  nameLbl.Font = Enum.Font.GothamBold
  nameLbl.TextSize = 8
  nameLbl.TextXAlignment = Enum.TextXAlignment.Left
  nameLbl.Parent = bg

  peerBillboards[plr.Name] = bb

  local function UpdateContent()
    local attr = plr:GetAttribute("UniMenu_Peer")
    if not attr then
      -- Player no longer has the attribute — remove billboard
      RemovePeerBillboard(plr)
      return
    end
    local data
    local ok = pcall(function() data = HttpService:JSONDecode(attr) end)
    if not ok or type(data) ~= "table" then return end

    if data.icon and #data.icon > 0 then
      icon.Image = data.icon
    end

    if data.active and data.song and #data.song > 0 then
      songLbl.Text = "♪ " .. data.song
      songLbl.TextColor3 = Color3.fromRGB(50, 255, 140)
    elseif data.song and #data.song > 0 then
      songLbl.Text = "⏸ " .. data.song
      songLbl.TextColor3 = Color3.fromRGB(240, 248, 255)
    else
      songLbl.Text = "♪ No music"
      songLbl.TextColor3 = XP.tabInactiveText
    end
  end

  UpdateContent()

  local conn
  conn = plr:GetAttributeChangedSignal("UniMenu_Peer"):Connect(function()
    if not bb.Parent then
      conn:Disconnect()
      return
    end
    UpdateContent()
  end)
  bb:GetPropertyChangedSignal("Parent"):Connect(function()
    if not bb.Parent and conn then
      conn:Disconnect()
    end
  end)
end

local PeerFolder, PeerTracker = Instance.new("Folder"), nil
PeerFolder.Name = "UniMenu_Peers"
PeerFolder.Parent = workspace

local function ScanPeers()
  for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then
      local attr = plr:GetAttribute("UniMenu_Peer")
      if attr then
        -- This player uses the same script
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
          if not peerBillboards[plr.Name] or not peerBillboards[plr.Name].Parent then
            CreatePeerBillboard(plr)
          end
        end
      else
        -- Player doesn't use the script
        RemovePeerBillboard(plr)
      end
    end
  end
end

-- Listen for players joining/leaving
Players.PlayerRemoving:Connect(function(plr)
  RemovePeerBillboard(plr)
end)

-- Update billboard adornee when characters respawn
Players.PlayerAdded:Connect(function(plr)
  plr.CharacterAdded:Connect(function()
    task.wait(1)
    if plr:GetAttribute("UniMenu_Peer") then
      CreatePeerBillboard(plr)
    end
  end)
end)

-- Existing players' characters respawning
for _, plr in ipairs(Players:GetPlayers()) do
  if plr ~= player then
    plr.CharacterAdded:Connect(function()
      task.wait(1)
      if plr:GetAttribute("UniMenu_Peer") then
        CreatePeerBillboard(plr)
      end
    end)
  end
end

-- Periodic scan for peer attributes + broadcast our own data
local peerBroadcastTimer = 0
TrackConnection(RunService.Heartbeat:Connect(function(dt)
  peerBroadcastTimer = peerBroadcastTimer + dt
  if peerBroadcastTimer >= 2 then
    peerBroadcastTimer = 0
    BroadcastPeerData()
    ScanPeers()
  end
end))

-- Initial broadcast + scan
BroadcastPeerData()
ScanPeers()

local function TogglePeerIcon(state)
  S.showPeerIcon = state
  if not state then
    for name, bb in pairs(peerBillboards) do
      bb:Destroy()
      peerBillboards[name] = nil
    end
  else
    ScanPeers()
  end
end

local function ToggleHUD(state)
  S.hudEnabled = state
  BuildHUD()
end

local function UpdateChamsTransparency()
  if not S.chamsFolder then return end
  for _, child in ipairs(S.chamsFolder:GetChildren()) do
    if child:IsA("BoxHandleAdornment") then
      child.Transparency = gameConfig.chamsTrans
    end
  end
end

local function ToggleChams(state)
  S.chams = state
  if state then
    if not S.chamsFolder then
      S.chamsFolder = Instance.new("Folder")
      S.chamsFolder.Name = "CheatMenu_Chams"
      S.chamsFolder.Parent = workspace
    end
    S.chamsFolder:ClearAllChildren()
    for _, plr in ipairs(Players:GetPlayers()) do
      if plr ~= player and plr.Character then
        for _, part in ipairs(plr.Character:GetChildren()) do
          if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local bbg = Instance.new("BoxHandleAdornment")
            bbg.Name = "ChamBox"
            bbg.Adornee = part
            bbg.AlwaysOnTop = true
            bbg.ZIndex = 5
            bbg.Size = part.Size
            bbg.Color3 = Color3.fromRGB(0, 255, 200)
            bbg.Transparency = gameConfig.chamsTrans
            bbg.Parent = S.chamsFolder
          end
        end
      end
    end
  else
    if S.chamsFolder then
      S.chamsFolder:Destroy()
      S.chamsFolder = nil
    end
  end
end

-- ==================== VISUAL HELPERS ====================
local function ToggleXRay(state)
  S.xRay = state
  if state then
    for _, p in ipairs(workspace:GetDescendants()) do
      if p:IsA("BasePart") and not p:IsDescendantOf(player.Character) and not Players:GetPlayerFromCharacter(p.Parent) then
        if not S.origTransparency[p] then
          S.origTransparency[p] = p.Transparency
        end
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

local function UpdateDarkMode()
  if not S.darkMode then
    if S.nightFX then
      pcall(function() S.nightFX:Destroy() end)
      S.nightFX = nil
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

  if S.fullbright then
    S.fullbright = false
  end

  -- Dim lighting for night play
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

local function ToggleFullbright(state)
  S.fullbright = state
  if state and S.darkMode then
    S.darkMode = false
    if S.nightFX then
      pcall(function() S.nightFX:Destroy() end)
      S.nightFX = nil
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

local function ToggleNoFog(state)
  S.noFog = state
  Lighting.FogEnd = state and 9e9 or S.origLighting.FogEnd
end

-- VFX class blacklist: particles, weather emitters, screen effects
local VFX_CLASSES = {
  "ParticleEmitter", "Smoke", "Fire", "Sparkles", "Beam", "Trail",
  "BloomEffect", "BlurEffect", "SunRaysEffect", "DepthOfFieldEffect",
  "ColorCorrectionEffect", "Atmosphere"
}
local function IsVFX(obj)
  for _, cls in ipairs(VFX_CLASSES) do
    if obj:IsA(cls) then return true end
  end
  return false
end
local function KillVFX(obj)
  if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
    if obj.Enabled ~= false then
      S.disabledVFX[obj] = true
      obj.Enabled = false
    end
  elseif obj:IsA("Beam") or obj:IsA("Trail") then
    if obj.Enabled ~= false then
      S.disabledVFX[obj] = true
      obj.Enabled = false
    end
  elseif obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect")
      or obj:IsA("DepthOfFieldEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("Atmosphere") then
    if obj.Enabled ~= false then
      S.disabledVFX[obj] = true
      obj.Enabled = false
    end
  end
end
local function RestoreVFX()
  for obj, _ in pairs(S.disabledVFX) do
    pcall(function()
      if obj and obj.Parent then
        obj.Enabled = true
      end
    end)
  end
  S.disabledVFX = {}
end
local function ToggleNoVFX(state)
  S.noVFX = state
  if state then
    -- Kill all existing VFX across the entire game tree
    for _, obj in ipairs(game:GetDescendants()) do
      if IsVFX(obj) then
        pcall(KillVFX, obj)
      end
    end
    -- Monitor and kill any new VFX that get added
    if S.noVFXConn then S.noVFXConn:Disconnect() end
    S.noVFXConn = TrackConnection(game.DescendantAdded:Connect(function(obj)
      if S.noVFX and IsVFX(obj) then
        task.defer(function()
          if S.noVFX then pcall(KillVFX, obj) end
        end)
      end
    end))
  else
    if S.noVFXConn then
      S.noVFXConn:Disconnect(); S.noVFXConn = nil
    end
    RestoreVFX()
  end
end

-- ==================== FPS BOOST ====================
local function ToggleFPSBoost(state)
  S.fpsBoost = state
  if state then
    S.fpsBoostData = {}

    -- 1. Strip textures / decals / surface appearances / particles from workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
      if obj:IsA("SurfaceAppearance") then
        -- No Transparency property — must reparent out
        local p = obj.Parent
        if p then
          S.fpsBoostData[obj] = { type = "parent", value = p }
          pcall(function() obj.Parent = nil end)
        end
      elseif obj:IsA("Decal") or obj:IsA("Texture") then
        local ok, cur = pcall(function() return obj.Transparency end)
        if ok and cur ~= 1 then
          S.fpsBoostData[obj] = { type = "transparency", value = cur }
          pcall(function() obj.Transparency = 1 end)
        end
      elseif obj:IsA("SpecialMesh") then
        local ok, tid = pcall(function() return obj.TextureId end)
        if ok and tid ~= "" then
          S.fpsBoostData[obj] = { type = "meshTex", value = tid }
          pcall(function() obj.TextureId = "" end)
        end
      elseif obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")
          or obj:IsA("Beam") or obj:IsA("Trail") then
        local ok, en = pcall(function() return obj.Enabled end)
        if ok and en then
          S.fpsBoostData[obj] = { type = "enabled", value = true }
          pcall(function() obj.Enabled = false end)
        end
      end
    end

    -- 2. Kill Lighting post-processing, Sky, and Atmosphere
    for _, obj in ipairs(Lighting:GetChildren()) do
      if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect")
          or obj:IsA("DepthOfFieldEffect") or obj:IsA("ColorCorrectionEffect")
          or obj:IsA("Atmosphere") or obj:IsA("Sky") then
        -- Sky and Atmosphere have no Enabled property — reparent both
        if obj:IsA("Sky") or obj:IsA("Atmosphere") then
          S.fpsBoostData[obj] = { type = "parent", value = Lighting }
          pcall(function() obj.Parent = nil end)
        else
          local ok, en = pcall(function() return obj.Enabled end)
          if ok and en then
            S.fpsBoostData[obj] = { type = "enabled", value = true }
            pcall(function() obj.Enabled = false end)
          end
        end
      end
    end

    -- 3. Disable shadows
    S.fpsBoostData["globalShadows"] = Lighting.GlobalShadows
    Lighting.GlobalShadows = false

    -- 4. Push fog horizon out to skip GPU fog culling
    S.fpsBoostData["fogEnd"] = Lighting.FogEnd
    Lighting.FogEnd = 100000

    -- 5. Lock render fidelity — reduce quality settings
    pcall(function()
      local rs = settings().Rendering
      if rs then
        S.fpsBoostData["qualityLevel"] = rs.QualityLevel
        rs.QualityLevel = Enum.QualityLevel.Level01
      end
    end)
  else
    -- Restore all saved values
    for obj, data in pairs(S.fpsBoostData) do
      pcall(function()
        if typeof(obj) == "string" then
          -- Plain string keys map to Lighting scalar properties
          if obj == "globalShadows" then
            Lighting.GlobalShadows = data
          elseif obj == "fogEnd" then
            Lighting.FogEnd = data
          elseif obj == "qualityLevel" then
            settings().Rendering.QualityLevel = data
          end
        else
          if data.type == "parent" then
            -- Reparent-based restore (Sky, Atmosphere, SurfaceAppearance)
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
  if S.fpsBoost then
    ToggleFPSBoost(false)
  end
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
      hum.PlatformStand = false
      camera.CameraSubject = hum
    end
  end
end

-- ==================== TROLLING & UTILITY ====================
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
      if targetRoot and targetRoot.Parent then
        bv.Velocity = Vector3.new(0, 200, 0)
      end
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

-- ==================== MM2 UTILITIES ====================
local function GetMM2Murderer()
  for _, p in ipairs(Players:GetPlayers()) do
    local char = p.Character
    local bp = p:FindFirstChild("Backpack")
    local hasK = (char and (char:FindFirstChild("Knife") or char:FindFirstChildWhichIsA("Tool") and (char:FindFirstChildWhichIsA("Tool").Name:lower():find("knife") or char:FindFirstChildWhichIsA("Tool"):FindFirstChild("KnifeServer"))))
        or
        (bp and (bp:FindFirstChild("Knife") or bp:FindFirstChildWhichIsA("Tool") and (bp:FindFirstChildWhichIsA("Tool").Name:lower():find("knife") or bp:FindFirstChildWhichIsA("Tool"):FindFirstChild("KnifeServer"))))
    if hasK then return p end
  end
  return nil
end

local function GetMM2Sheriff()
  for _, p in ipairs(Players:GetPlayers()) do
    local char = p.Character
    local bp = p:FindFirstChild("Backpack")
    local hasG = (char and (char:FindFirstChild("Gun") or char:FindFirstChildWhichIsA("Tool") and (char:FindFirstChildWhichIsA("Tool").Name:lower():find("gun") or char:FindFirstChildWhichIsA("Tool"):FindFirstChild("GunServer"))))
        or
        (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChildWhichIsA("Tool") and (bp:FindFirstChildWhichIsA("Tool").Name:lower():find("gun") or bp:FindFirstChildWhichIsA("Tool"):FindFirstChild("GunServer"))))
    if hasG then return p end
  end
  return nil
end

local cachedDroppedGun = nil
local lastGunSearchTick = 0

local function GetMM2DroppedGun()
  if cachedDroppedGun and cachedDroppedGun.Parent and cachedDroppedGun:IsDescendantOf(workspace) then
    return cachedDroppedGun
  end
  cachedDroppedGun = nil

  local now = tick()
  if now - lastGunSearchTick < 0.4 then
    return nil
  end
  lastGunSearchTick = now

  -- Fast 1: Direct child of workspace
  local directGun = workspace:FindFirstChild("GunDrop")
  if directGun then
    local p = directGun:IsA("BasePart") and directGun or directGun:FindFirstChildWhichIsA("BasePart") or
        directGun:FindFirstChild("Handle")
    if p then
      cachedDroppedGun = p
      return p
    end
  end

  -- Fast 2: Direct child of active map models
  for _, child in ipairs(workspace:GetChildren()) do
    if child:IsA("Model") and child.Name ~= "Lobby" and child.Name ~= "Terrain" and not Players:GetPlayerFromCharacter(child) then
      local mapGun = child:FindFirstChild("GunDrop")
      if mapGun then
        local p = mapGun:IsA("BasePart") and mapGun or mapGun:FindFirstChildWhichIsA("BasePart") or
            mapGun:FindFirstChild("Handle")
        if p then
          cachedDroppedGun = p
          return p
        end
      end
    end
  end

  return nil
end

local function GrabDroppedGun()
  if not IsPlayerActive() then return end
  local gunPart = GetMM2DroppedGun()
  local root = GetRoot()
  if gunPart and root then
    local savedPos = root.CFrame
    root.CFrame = gunPart.CFrame + Vector3.new(0, 1.2, 0)
    if typeof(firetouchinterest) == "function" then
      pcall(function()
        firetouchinterest(root, gunPart, 0)
        firetouchinterest(root, gunPart, 1)
      end)
    end
    task.wait(0.15)
    if root and root.Parent then
      root.CFrame = savedPos
    end
  end
end

local function AutoGrabSheriffGun()
  if not IsPlayerActive() then return end
  local m = GetMM2Murderer()
  if m ~= player then return end
  local gunPart = GetMM2DroppedGun()
  local root = GetRoot()
  if gunPart and root then
    local savedPos = root.CFrame
    root.CFrame = gunPart.CFrame + Vector3.new(0, 1.2, 0)
    if typeof(firetouchinterest) == "function" then
      pcall(function()
        firetouchinterest(root, gunPart, 0)
        firetouchinterest(root, gunPart, 1)
      end)
    end
    task.wait(0.15)
    if root and root.Parent then
      root.CFrame = savedPos
    end
  end
end

-- ==================== AUTO FOLLOW BEHIND ====================
-- High-precision follower that mimics target's exact movement state
-- (walking, jumping, climbing, swimming) with dynamic obstacle avoidance
local autoFollowConn = nil
local autoFollowTarget = nil
local followPath = nil
local pathWaypoints = {}
local currentWaypointIndex = 1
local lastTargetPos = Vector3.new()
local stuckTimer = 0
local lastPosition = Vector3.new()

local function SetAutoFollowTarget()
  if not selectedPlayer or not selectedPlayer.Character then return end
  autoFollowTarget = selectedPlayer
  followPath = nil
  pathWaypoints = {}
  currentWaypointIndex = 1
  stuckTimer = 0
  lastPosition = Vector3.new()
end

local function ComputePath(startPos, endPos, myChar)
  local path = PathfindingService:CreatePath({
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentCanClimb = true,
    AgentCanSwim = true,
    WaypointSpacing = 4,
    Costs = {
      Water = 10,
      Danger = math.huge
    }
  })

  local success = pcall(function()
    path:ComputeAsync(startPos, endPos)
  end)

  if success and path.Status == Enum.PathStatus.Success then
    return path:GetWaypoints()
  end
  return nil
end

local function GetTargetMovementState(targetChar, targetHum, targetRoot)
  if not targetHum or not targetRoot then return "idle" end

  local moveDir = targetHum.MoveDirection
  local velocity = targetRoot.AssemblyLinearVelocity
  local speed = velocity.Magnitude
  local state = targetHum:GetState()

  if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
    return "jumping"
  elseif state == Enum.HumanoidStateType.Climbing then
    return "climbing"
  elseif state == Enum.HumanoidStateType.Swimming then
    return "swimming"
  elseif speed > 2 then
    return "running"
  elseif speed > 0.5 then
    return "walking"
  else
    return "idle"
  end
end

local function MimicMovementState(myHum, myRoot, targetState, targetMoveDir)
  if not myHum or not myRoot then return end

  if targetState == "jumping" then
    if myHum:GetState() ~= Enum.HumanoidStateType.Jumping and
        myHum:GetState() ~= Enum.HumanoidStateType.Freefall then
      myHum.Jump = true
    end
  elseif targetState == "climbing" then
    -- Climbing is automatic when touching climbable surfaces
  elseif targetState == "swimming" then
    -- Swimming is automatic in water
  end

  -- Apply movement direction
  if targetMoveDir.Magnitude > 0 then
    myHum:Move(targetMoveDir, false)
  end
end

local function CheckStuck(myRoot, dt)
  if not myRoot then return false end

  local currentPos = myRoot.Position
  local moved = (currentPos - lastPosition).Magnitude

  if moved < 0.5 then
    stuckTimer = stuckTimer + dt
  else
    stuckTimer = 0
  end

  lastPosition = currentPos
  return stuckTimer > 1.5 -- Stuck for more than 1.5 seconds
end

local function FindClearPositionAround(targetPos, myRoot)
  -- Raycast in multiple directions to find clear ground
  local rayParams = RaycastParams.new()
  rayParams.FilterDescendantsInstances = { GetCharacter() }
  rayParams.FilterType = Enum.RaycastFilterType.Exclude

  local directions = {
    Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
    Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
    Vector3.new(1, 0, 1).Unit, Vector3.new(-1, 0, 1).Unit,
    Vector3.new(1, 0, -1).Unit, Vector3.new(-1, 0, -1).Unit
  }

  for _, dir in ipairs(directions) do
    local testPos = targetPos + dir * 6
    local ray = workspace:Raycast(testPos + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), rayParams)
    if ray and ray.Instance then
      return ray.Position + Vector3.new(0, 3, 0)
    end
  end

  return targetPos + Vector3.new(0, 3, 0)
end

local function StartAutoFollow()
  if autoFollowConn then return end
  SetAutoFollowTarget()
  if not autoFollowTarget then return end

  autoFollowConn = RunService.Heartbeat:Connect(function(dt)
    if not MM2.autoFollow or not autoFollowTarget or not autoFollowTarget.Character then
      if autoFollowConn then
        autoFollowConn:Disconnect()
        autoFollowConn = nil
      end
      return
    end

    local myChar = GetCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local targetChar = autoFollowTarget.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

    if not myRoot or not targetRoot or not myHum or not targetHum then return end

    -- Calculate ideal follow position (behind target)
    local behindOffset = targetRoot.CFrame.LookVector * -5 + Vector3.new(0, 0, 0)
    local idealPos = targetRoot.Position + behindOffset

    -- Get target's movement state
    local targetState = GetTargetMovementState(targetChar, targetHum, targetRoot)
    local targetMoveDir = targetHum.MoveDirection

    -- Mimic target's movement state
    MimicMovementState(myHum, myRoot, targetState, targetMoveDir)

    -- Check if stuck on geometry
    local isStuck = CheckStuck(myRoot, dt)

    -- Distance to ideal position
    local distToIdeal = (idealPos - myRoot.Position).Magnitude

    -- Recompute path if target moved significantly or we're stuck
    local targetMoved = (targetRoot.Position - lastTargetPos).Magnitude > 3

    if targetMoved or isStuck or #pathWaypoints == 0 then
      lastTargetPos = targetRoot.Position

      -- Try direct movement first if close
      if distToIdeal < 8 and not isStuck then
        pathWaypoints = {}
        currentWaypointIndex = 1
      else
        -- Compute new path
        local waypoints = ComputePath(myRoot.Position, idealPos, myChar)
        if waypoints and #waypoints > 0 then
          pathWaypoints = waypoints
          currentWaypointIndex = 1
        else
          -- Pathfinding failed, use obstacle avoidance
          local clearPos = FindClearPositionAround(idealPos, myRoot)
          local fallbackWaypoints = ComputePath(myRoot.Position, clearPos, myChar)
          if fallbackWaypoints and #fallbackWaypoints > 0 then
            pathWaypoints = fallbackWaypoints
            currentWaypointIndex = 1
          else
            pathWaypoints = {}
          end
        end
      end
    end

    -- Follow computed path
    if #pathWaypoints > 0 and currentWaypointIndex <= #pathWaypoints then
      local waypoint = pathWaypoints[currentWaypointIndex]
      local waypointPos = waypoint.Position

      -- Move towards waypoint
      local toWaypoint = waypointPos - myRoot.Position
      local waypointDist = toWaypoint.Magnitude

      if waypointDist < 3 then
        currentWaypointIndex = currentWaypointIndex + 1
      else
        local moveDir = toWaypoint.Unit
        myHum:Move(moveDir, false)

        -- Handle jumping at jump waypoints
        if waypoint.Action == Enum.PathWaypointAction.Jump then
          if myHum:GetState() ~= Enum.HumanoidStateType.Jumping then
            myHum.Jump = true
          end
        end
      end
    else
      -- No path or path complete, direct move to ideal position
      local toIdeal = idealPos - myRoot.Position
      if toIdeal.Magnitude > 2 then
        myHum:Move(toIdeal.Unit, false)
      else
        myHum:Move(Vector3.new(), false)
      end
    end

    -- Face target
    myRoot.CFrame = CFrame.new(myRoot.Position,
      Vector3.new(targetRoot.Position.X, myRoot.Position.Y, targetRoot.Position.Z))
  end)
end

local function StopAutoFollow()
  if autoFollowConn then
    autoFollowConn:Disconnect()
    autoFollowConn = nil
  end
  followPath = nil
  pathWaypoints = {}
  currentWaypointIndex = 1
  stuckTimer = 0
  lastPosition = Vector3.new()
  autoFollowTarget = nil
end

-- ==================== PLATFORM MODE ====================
local platformConn = nil
local platformTarget = nil

local function StartPlatformMode()
  if platformConn then return end
  if not selectedPlayer or not selectedPlayer.Character then return end
  platformTarget = selectedPlayer

  platformConn = RunService.Heartbeat:Connect(function()
    if not MM2.platformMode or not platformTarget or not platformTarget.Character then
      if platformConn then
        platformConn:Disconnect()
        platformConn = nil
      end
      return
    end

    local myChar = GetCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetChar = platformTarget.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

    if not myRoot or not targetRoot or not targetHum then return end

    local targetPos = targetRoot.Position - Vector3.new(0, 3.5, 0)
    myRoot.CFrame = CFrame.new(targetPos)
    myRoot.Anchored = true
    myRoot.Velocity = Vector3.zero
    myRoot.RotVelocity = Vector3.zero
  end)
end

local function StopPlatformMode()
  if platformConn then
    platformConn:Disconnect()
    platformConn = nil
  end
  if platformTarget and platformTarget.Character then
    local myChar = GetCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then myRoot.Anchored = false end
  end
  platformTarget = nil
end

-- ==================== BOOST MODE ====================
local boostConn = nil
local boostTarget = nil

local function StartBoostMode()
  if boostConn then return end
  if not selectedPlayer or not selectedPlayer.Character then return end
  boostTarget = selectedPlayer

  boostConn = RunService.Heartbeat:Connect(function()
    if not MM2.boostMode or not boostTarget or not boostTarget.Character then
      if boostConn then
        boostConn:Disconnect()
        boostConn = nil
      end
      return
    end

    local myChar = GetCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetChar = boostTarget.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

    if not myRoot or not targetRoot or not targetHum then return end

    local targetPos = targetRoot.Position - targetRoot.CFrame.LookVector * 4 - Vector3.new(0, 1, 0)
    myRoot.CFrame = CFrame.new(targetPos)
    myRoot.Anchored = true
    myRoot.Velocity = Vector3.zero
    myRoot.RotVelocity = Vector3.zero

    targetRoot.Velocity = targetRoot.CFrame.LookVector * 80 + Vector3.new(0, 20, 0)
  end)
end

local function StopBoostMode()
  if boostConn then
    boostConn:Disconnect()
    boostConn = nil
  end
  if boostTarget and boostTarget.Character then
    local myChar = GetCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then myRoot.Anchored = false end
  end
  boostTarget = nil
end

-- ==================== MAGIC BULLET ====================
-- Auto-switch: hooks stay installed but activate per equipped weapon.
--   Gun  -> silent aim on GetMouseTargetCFrame / GetTargetPosition
--           (direct hitbox, no prediction, bypasses client raycast).
--   Knife -> predicted throw via ThrowKnife hook
--           (lead = dist / 120 studs/s, capped at 0.35s).
--   KillEvent bypass fires for both weapons.
local magicBulletWeaponService = nil
local magicBulletOriginalGetMouseTargetCFrame = nil
local magicBulletOriginalGetTargetPosition = nil
local magicBulletOriginalThrowKnife = nil

local KillEventRemote = nil
local KillEventConn = nil

local function GetBestMagicBulletTarget()
  local m = GetMM2Murderer()
  if m and m.Character then
    local mRoot = m.Character:FindFirstChild("HumanoidRootPart")
    local mHum = m.Character:FindFirstChildOfClass("Humanoid")
    if mRoot and mHum and mHum.Health > 0 then
      return m.Character
    end
  end
  return nil
end

local function magicBulletGetEquippedWeapon()
  local char = GetCharacter()
  if char then
    if char:FindFirstChild("Gun") then return "gun" end
    if char:FindFirstChild("Knife") then return "knife" end
    for _, tool in ipairs(char:GetChildren()) do
      if tool:IsA("Tool") then
        local name = tool.Name:lower()
        if name:find("gun") then return "gun" end
        if name:find("knife") then return "knife" end
      end
    end
  end
  if player.Backpack then
    if player.Backpack:FindFirstChild("Gun") then return "gun" end
    if player.Backpack:FindFirstChild("Knife") then return "knife" end
    for _, tool in ipairs(player.Backpack:GetChildren()) do
      if tool:IsA("Tool") then
        local name = tool.Name:lower()
        if name:find("gun") then return "gun" end
        if name:find("knife") then return "knife" end
      end
    end
  end
  return nil
end

local function magicBulletResolveCFrame(predictionSeconds)
  predictionSeconds = predictionSeconds or 0.12
  local targetChar = GetBestMagicBulletTarget()
  if not targetChar then return nil end

  local targetPart = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Head")
  if not targetPart then return nil end

  local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
  if targetRoot then
    local vel = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.zero
    return CFrame.new(targetPart.Position + vel * predictionSeconds + Vector3.new(0, 0.3, 0))
  end
  return CFrame.new(targetPart.Position)
end

local function ApplyMagicBulletHook()
  if magicBulletWeaponService then
    return
  end
  magicBulletOriginalGetMouseTargetCFrame = nil
  magicBulletOriginalGetTargetPosition = nil
  magicBulletOriginalThrowKnife = nil

  local ws = game:GetService("ReplicatedStorage")
  local clientServices = ws:FindFirstChild("ClientServices")
  if not clientServices then return end
  local weaponService = clientServices:FindFirstChild("WeaponService")
  if not weaponService or not weaponService:IsA("ModuleScript") then return end

  local ok, mod = pcall(function() return require(weaponService) end)
  if not ok or type(mod) ~= "table" then return end

  magicBulletWeaponService = weaponService
  if not KillEventRemote then
    KillEventRemote = ws.Remotes and ws.Remotes.Gameplay and ws.Remotes.Gameplay:FindFirstChild("KillEvent")
  end
  if KillEventConn then
    KillEventConn:Disconnect()
    KillEventConn = nil
  end
  if KillEventRemote and KillEventRemote:IsA("RemoteEvent") then
    KillEventConn = KillEventRemote.OnClientEvent:Connect(function(...)
      if not MM2.magicBullet then return end
      local killer, victim = ...
      if killer and victim and killer == player and victim ~= player then
        task.wait(0.05)
        local char = GetCharacter()
        local hasWeapon = char and (char:FindFirstChild("Gun") or char:FindFirstChild("Knife"))
            or (player.Backpack and (player.Backpack:FindFirstChild("Gun") or player.Backpack:FindFirstChild("Knife")))
        if hasWeapon then
          local targetChar = GetBestMagicBulletTarget()
          if targetChar then
            KillEventRemote:FireServer(player, targetChar)
          end
        end
      end
    end)
  end

  -- Gun silent aim: only active while a gun is equipped
  if type(mod.GetMouseTargetCFrame) == "function" then
    magicBulletOriginalGetMouseTargetCFrame = mod.GetMouseTargetCFrame
    mod.GetMouseTargetCFrame = function(...)
      if MM2.magicBullet and magicBulletGetEquippedWeapon() == "gun" then
        local forced = magicBulletResolveCFrame()
        if forced then
          return forced
        end
      end
      return magicBulletOriginalGetMouseTargetCFrame(...)
    end
  end

  if type(mod.GetTargetPosition) == "function" then
    magicBulletOriginalGetTargetPosition = mod.GetTargetPosition
    mod.GetTargetPosition = function(...)
      if MM2.magicBullet and magicBulletGetEquippedWeapon() == "gun" then
        local forced = magicBulletResolveCFrame()
        if forced then
          return forced
        end
      end
      return magicBulletOriginalGetTargetPosition(...)
    end
  end

  -- Magic Projectile: Homing Knife Throw
  -- Replaces the original ThrowKnife with a custom projectile that:
  --   1. Spawns a client-side knife projectile on throw
  --   2. Computes a lead-intercept trajectory using predictive pathing
  --   3. Steers dynamically via PID-like correction toward the target
  --   4. Forces server hit registration via touch interest when in range
  if type(mod.ThrowKnife) == "function" then
    magicBulletOriginalThrowKnife = mod.ThrowKnife
    mod.ThrowKnife = function(...)
      if MM2.magicBullet and magicBulletGetEquippedWeapon() == "knife" then
        local targetChar = GetBestMagicBulletTarget()
        if targetChar then
          LaunchMagicProjectile(targetChar)
        end
      end
      return magicBulletOriginalThrowKnife(...)
    end
  end
end

local function RemoveMagicBulletHook()
  if KillEventConn then
    KillEventConn:Disconnect()
    KillEventConn = nil
  end
  CleanupMagicProjectile()
  if magicBulletWeaponService then
    local ok, mod = pcall(function() return require(magicBulletWeaponService) end)
    if ok and type(mod) == "table" then
      if magicBulletOriginalGetMouseTargetCFrame and type(mod.GetMouseTargetCFrame) == "function" then
        mod.GetMouseTargetCFrame = magicBulletOriginalGetMouseTargetCFrame
      end
      if magicBulletOriginalGetTargetPosition and type(mod.GetTargetPosition) == "function" then
        mod.GetTargetPosition = magicBulletOriginalGetTargetPosition
      end
      if magicBulletOriginalThrowKnife and type(mod.ThrowKnife) == "function" then
        mod.ThrowKnife = magicBulletOriginalThrowKnife
      end
    end
  end
  magicBulletWeaponService = nil
  magicBulletOriginalGetMouseTargetCFrame = nil
  magicBulletOriginalGetTargetPosition = nil
  magicBulletOriginalThrowKnife = nil
end

-- ==================== MAGIC PROJECTILE: HOMING KNIFE THROW ====================
-- Custom projectile system for knife throwing with:
--   - Predictive lead calculation (intercept point)
--   - Dynamic PID-like steering correction
--   - Bezier curve pathing for natural arc
--   - Server hit registration via touch interest
local magicProjectileConn = nil
local magicProjectile = nil

local function CalculateInterceptPoint(targetRoot, projectileSpeed)
  -- Lead target based on current velocity and distance
  local myRoot = GetRoot()
  if not myRoot then return targetRoot.Position end

  local targetPos = targetRoot.Position
  local targetVel = targetRoot.AssemblyLinearVelocity or Vector3.zero
  local projectilePos = myRoot.Position
  local distance = (targetPos - projectilePos).Magnitude

  -- Time of flight estimation
  local flightTime = distance / projectileSpeed

  -- Predict target position with velocity
  local predictedPos = targetPos + targetVel * flightTime

  -- Iterative refinement for better accuracy
  for i = 1, 3 do
    local newDist = (predictedPos - projectilePos).Magnitude
    local newTime = newDist / projectileSpeed
    predictedPos = targetPos + targetVel * newTime
  end

  return predictedPos
end

local function CreateMagicProjectile(targetChar)
  local myRoot = GetRoot()
  if not myRoot then return nil end

  -- Create visual projectile
  local proj = Instance.new("Part")
  proj.Name = "MagicProjectile_Knife"
  proj.Size = Vector3.new(0.8, 2, 0.8)
  proj.Material = Enum.Material.Metal
  proj.BrickColor = BrickColor.new("Bright orange")
  proj.CanCollide = false
  proj.Massless = true
  proj.Anchored = true
  proj.CFrame = myRoot.CFrame * CFrame.new(0, 1, -3)
  proj.Parent = workspace

  -- Add trail effect
  local trail = Instance.new("Trail")
  trail.Color = ColorSequence.new(Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 60, 0))
  trail.Lifetime = 0.4
  trail.MinLength = 0.1
  trail.WidthScale = NumberSequence.new(0.5, 0)
  trail.Parent = proj

  -- Point light for visibility
  local light = Instance.new("PointLight")
  light.Color = Color3.fromRGB(255, 120, 0)
  light.Brightness = 2
  light.Range = 15
  light.Parent = proj

  -- Align to trajectory
  local align = Instance.new("AlignOrientation")
  align.Mode = Enum.OrientationAlignmentMode.OneAttachment
  align.RigidityEnabled = true
  align.Parent = proj

  local attach = Instance.new("Attachment")
  attach.Parent = proj
  align.Attachment0 = attach

  return proj
end

local function LaunchMagicProjectile(targetChar)
  if magicProjectileConn then return end

  local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
  local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
  if not targetRoot or not targetHum or targetHum.Health <= 0 then return end

  local myRoot = GetRoot()
  if not myRoot then return end

  -- Configurable projectile parameters
  local PROJECTILE_SPEED = 140
  local MAX_FLIGHT_TIME = 4.0
  local STEER_STRENGTH = 12    -- PID P term
  local STEER_DAMPENING = 0.85 -- Velocity retention

  -- Create projectile
  magicProjectile = CreateMagicProjectile(targetChar)
  if not magicProjectile then return end

  local startTime = tick()
  local lastVelocity = Vector3.zero
  local integralError = Vector3.zero -- PID I term

  magicProjectileConn = RunService.Heartbeat:Connect(function(dt)
    if not magicProjectile or not magicProjectile.Parent or not MM2.magicBullet then
      if magicProjectileConn then
        magicProjectileConn:Disconnect()
        magicProjectileConn = nil
      end
      if magicProjectile then magicProjectile:Destroy() end
      magicProjectile = nil
      return
    end

    -- Check target validity
    if not targetRoot.Parent or not targetHum or targetHum.Health <= 0 then
      -- Target lost, try to find new target
      local newTarget = GetBestMagicBulletTarget()
      if newTarget then
        targetChar = newTarget
        targetRoot = newTarget:FindFirstChild("HumanoidRootPart")
        targetHum = newTarget:FindFirstChildOfClass("Humanoid")
      else
        -- No valid target, self-destruct
        magicProjectile:Destroy()
        magicProjectile = nil
        return
      end
    end

    -- Check max flight time
    if tick() - startTime > MAX_FLIGHT_TIME then
      magicProjectile:Destroy()
      magicProjectile = nil
      return
    end

    -- Calculate intercept point (lead target)
    local interceptPos = CalculateInterceptPoint(targetRoot, PROJECTILE_SPEED)
    local currentPos = magicProjectile.Position
    local toTarget = interceptPos - currentPos
    local distance = toTarget.Magnitude

    -- Desired direction
    local desiredDir = toTarget.Unit

    -- Current velocity direction
    local currentVelDir = lastVelocity.Magnitude > 0 and lastVelocity.Unit or desiredDir

    -- PID-like steering correction
    local error = desiredDir - currentVelDir
    integralError = integralError + error * dt
    local derivative = error / dt

    -- Apply correction
    local steerForce = error * STEER_STRENGTH + integralError * 2
    local newDir = (currentVelDir + steerForce).Unit

    -- Smooth velocity transition (dampening)
    local newVelocity = newDir * PROJECTILE_SPEED
    lastVelocity = lastVelocity * STEER_DAMPENING + newVelocity * (1 - STEER_DAMPENING)

    -- Update position
    local newPos = currentPos + lastVelocity * dt
    magicProjectile.CFrame = CFrame.lookAt(newPos, newPos + lastVelocity.Unit)

    -- Update AlignOrientation for visual alignment
    local align = magicProjectile:FindFirstChild("AlignOrientation")
    if align then
      align.CFrame = CFrame.lookAt(Vector3.zero, lastVelocity.Unit)
    end

    -- Force hit registration when close
    if distance < 4 then
      magicProjectile.CFrame = CFrame.lookAt(currentPos, targetRoot.Position)
      if typeof(firetouchinterest) == "function" then
        pcall(function()
          firetouchinterest(targetRoot, magicProjectile, 0)
          firetouchinterest(targetRoot, magicProjectile, 1)
        end)
      end

      -- Also fire KillEvent if available
      if KillEventRemote and KillEventRemote:IsA("RemoteEvent") then
        KillEventRemote:FireServer(player, targetChar)
      end

      -- Cleanup
      task.delay(0.1, function()
        if magicProjectile then magicProjectile:Destroy() end
      end)
      magicProjectile = nil
      if magicProjectileConn then
        magicProjectileConn:Disconnect()
        magicProjectileConn = nil
      end
    end
  end)
end

local function CleanupMagicProjectile()
  if magicProjectileConn then
    magicProjectileConn:Disconnect()
    magicProjectileConn = nil
  end
  if magicProjectile then
    magicProjectile:Destroy()
    magicProjectile = nil
  end
end

local function UpdateMagicBullet()
  if MM2.magicBullet then
    ApplyMagicBulletHook()
  else
    RemoveMagicBulletHook()
  end
end

player.CharacterAdded:Connect(function()
  task.wait(0.5)
  UpdateMagicBullet()
end)

TrackConnection(RunService.Heartbeat:Connect(function()
  if MM2.magicBullet then
    ApplyMagicBulletHook()
  end
end))

local cachedCoinContainer = nil
local lastCoinContainerCheck = 0
local collectedCoinSet = {}

local function ResetCoinCache()
  cachedCoinContainer = nil
  lastCoinContainerCheck = 0
  collectedCoinSet = {}
end

local function GetMM2ActiveCoins()
  local now = tick()
  if not cachedCoinContainer or not cachedCoinContainer.Parent or (now - lastCoinContainerCheck > 1.5) then
    lastCoinContainerCheck = now
    cachedCoinContainer = nil
    collectedCoinSet = {}
    for _, map in ipairs(workspace:GetChildren()) do
      if (map:IsA("Model") or map:IsA("Folder")) and map.Name ~= "Lobby" and map.Name ~= "WeaponDisplays" and map.Name ~= "Terrain" and map.Name ~= "RCCars" and not Players:GetPlayerFromCharacter(map) then
        local cc = map:FindFirstChild("CoinContainer") or map:FindFirstChild("CoinAreas") or map:FindFirstChild("Coins")
        if cc then
          cachedCoinContainer = cc
          break
        end
      end
    end
  end

  local coins = {}
  if cachedCoinContainer and cachedCoinContainer.Parent then
    for _, coin in ipairs(cachedCoinContainer:GetChildren()) do
      local coinKey = tostring(coin)
      if coin:IsA("BasePart") and not collectedCoinSet[coinKey] then
        if coin:FindFirstChild("CoinVisual") or coin.Name == "Coin_Server" or coin.Name:lower():find("coin") then
          table.insert(coins, coin)
        end
      end
    end
  end
  return coins
end

local function MarkCoinCollected(coin)
  if coin then
    collectedCoinSet[tostring(coin)] = true
  end
end

local function TeleportToMurderer()
  local m = GetMM2Murderer()
  local root = GetRoot()
  if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") and root then
    root.CFrame = m.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
  end
end

local function TeleportToSheriff()
  local s = GetMM2Sheriff()
  local root = GetRoot()
  if s and s.Character and s.Character:FindFirstChild("HumanoidRootPart") and root then
    root.CFrame = s.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
  end
end

local function TeleportToLobby()
  local root = GetRoot()
  if not root then return end
  local lobby = workspace:FindFirstChild("Lobby")
  if lobby then
    local spawns = lobby:FindFirstChild("Spawns")
    if spawns then
      local spawnPart = spawns:FindFirstChildWhichIsA("SpawnLocation") or spawns:FindFirstChildWhichIsA("BasePart")
      if spawnPart then
        root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
        return
      end
    end
    local spawnPart = lobby:FindFirstChildWhichIsA("SpawnLocation") or lobby:FindFirstChildWhichIsA("BasePart")
    if spawnPart then
      root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
      return
    end
  end
  root.CFrame = CFrame.new(Vector3.new(-108, 140, -11))
end

local function KillAllMurderer()
  local char = player.Character
  local knife = (char and char:FindFirstChild("Knife")) or
      (player.Backpack and player.Backpack:FindFirstChild("Knife"))
  if not knife then return end
  if knife.Parent ~= char then knife.Parent = char end

  local root = GetRoot()
  if not root then return end
  local oldCF = root.CFrame
  local knifeHandle = knife:FindFirstChild("Handle")

  for _, target in ipairs(Players:GetPlayers()) do
    if target ~= player and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
      local tHum = target.Character:FindFirstChildOfClass("Humanoid")
      local tRoot = target.Character.HumanoidRootPart
      if tHum and tHum.Health > 0 then
        root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 1.2)
        task.wait(0.05)
        if knifeHandle and typeof(firetouchinterest) == "function" then
          pcall(function()
            firetouchinterest(tRoot, knifeHandle, 0)
            firetouchinterest(tRoot, knifeHandle, 1)
          end)
        end
        if knife and knife.Parent == char then
          pcall(function() knife:Activate() end)
        end
        task.wait(0.05)
      end
    end
  end
  root.CFrame = oldCF
end

local function ShootMurdererSheriff()
  if not IsPlayerActive() then return end
  local char = player.Character
  local gun = (char and char:FindFirstChild("Gun")) or (player.Backpack and player.Backpack:FindFirstChild("Gun"))
  if not gun then return end
  if gun.Parent ~= char then gun.Parent = char end

  local m = GetMM2Murderer()
  if not m or not m.Character or not m.Character:FindFirstChild("HumanoidRootPart") then return end

  local targetRoot = m.Character.HumanoidRootPart
  local vel = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.zero
  local predPos = targetRoot.Position + vel * 0.12 + Vector3.new(0, 0.5, 0)

  -- Get correct shoot origin from GunRaycastAttachment (required by game)
  local hrp = char:FindFirstChild("HumanoidRootPart")
  local attach = hrp and hrp:FindFirstChild("GunRaycastAttachment")
  local originCFrame = attach and attach.WorldCFrame or (hrp and hrp.CFrame) or nil

  -- Get target CFrame via WeaponService if available, else fallback
  local targetCFrame = CFrame.new(predPos)
  pcall(function()
    local WeaponService = require(game:GetService("ReplicatedStorage"):WaitForChild("ClientServices"):WaitForChild(
      "WeaponService"))
    targetCFrame = WeaponService:GetMouseTargetCFrame()
  end)
  if not targetCFrame then targetCFrame = CFrame.new(predPos) end

  local shootRemote = gun:FindFirstChild("Shoot")
  if shootRemote and shootRemote:IsA("RemoteEvent") and originCFrame then
    pcall(function()
      shootRemote:FireServer(originCFrame, targetCFrame)
    end)
  end
  pcall(function() gun:Activate() end)
end

local function UpdateTrapESP()
  if not S.espFolder then return end
  for _, child in ipairs(workspace:GetDescendants()) do
    if child:IsA("BasePart") and (child.Name:lower():find("trap") or child.Name:lower():find("beartrap")) and not (player.Character and child:IsDescendantOf(player.Character)) then
      local tagId = "Trap_" .. tostring(child:GetFullName()):gsub("[^%w]", "_")
      local existing = S.espFolder:FindFirstChild(tagId)
      if MM2.trapESP then
        if not existing then
          local bb = Instance.new("BillboardGui")
          bb.Name = tagId
          bb.Adornee = child
          bb.Size = UDim2.new(0, 100, 0, 30)
          bb.AlwaysOnTop = true
          bb.StudsOffset = Vector3.new(0, 1.5, 0)
          bb.Parent = S.espFolder

          local lbl = Instance.new("TextLabel")
          lbl.Size = UDim2.new(1, 0, 1, 0)
          lbl.Text = "[TRAP]"
          lbl.TextColor3 = Color3.fromRGB(255, 60, 0)
          lbl.BackgroundTransparency = 1
          lbl.Font = Enum.Font.GothamBold
          lbl.TextSize = 10
          lbl.Parent = bb
        end
      else
        if existing then existing:Destroy() end
      end
    end
  end
end

local function DodgeMurdererKnife()
  local m = GetMM2Murderer()
  local root = GetRoot()
  if not m or not m.Character or not m.Character:FindFirstChild("HumanoidRootPart") or not root then return end

  local mChar = m.Character
  local mKnife = mChar:FindFirstChild("Knife") or (m.Backpack and m.Backpack:FindFirstChild("Knife"))
  if not mKnife then return end

  local mRoot = mChar.HumanoidRootPart
  local dist = (mRoot.Position - root.Position).Magnitude
  if dist <= 14 then
    MM2.lastDodgeTime = tick()
    local dodgeDir = (root.Position - mRoot.Position).Unit
    if dodgeDir.Magnitude < 0.1 then dodgeDir = Vector3.new(0, 1, 0) end
    root.CFrame = root.CFrame + (dodgeDir * 18) + Vector3.new(0, 8, 0)
    root.AssemblyLinearVelocity = Vector3.new(0, 20, 0)
  end
end

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
            vu:CaptureController()
            vu:ClickButton2(Vector2.new(0, 0))
          end
        end)
      end)
      TrackConnection(antiAFKConn)
    end
  else
    if antiAFKConn then
      pcall(function() antiAFKConn:Disconnect() end)
      antiAFKConn = nil
    end
  end
end

local function CopyJobId()
  pcall(function()
    if setclipboard then setclipboard(tostring(game.JobId)) end
  end)
end

local function CopyPlaceId()
  pcall(function()
    if setclipboard then setclipboard(tostring(game.PlaceId)) end
  end)
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

-- ==================== STRICT 3-TIER FEATURES DEFINITIONS ====================
local features = {
  Combat = {
    { isSection = true,         name = "Targeting & Aim" },
    {
      name = "Aimbot (Hold RMB)",
      desc = "Smooth lock to nearest target while holding RMB",
      isToggle = true,
      get = function()
        return S.aimbot
      end,
      toggle = function(state)
        S.aimbot = state
      end
    },
    {
      name = "Cycle Target Part",
      desc = "Cycles between Head, Root, Torso",
      isCyclePart = true
    },
    {
      name = "Triggerbot",
      desc = "Auto-click when crosshair detects player",
      isToggle = true,
      get = function()
        return
            S.triggerbot
      end,
      toggle = function(
          state)
        S.triggerbot = state
      end
    },
    {
      name = "Auto Clicker",
      desc = "Continuous rapid left mouse clicks",
      isToggle = true,
      get = function()
        return
            S.autoClicker
      end,
      toggle = function(
          state)
        S.autoClicker = state
      end
    },
    { isSection = true,         name = "Combat Actions" },
    { name = "Reset Character", desc = "Instant respawn character", isButton = true, action = ResetCharacter }
  },
  Movement = {
    { isSection = true,        name = "CS2 Physics Engine" },
    {
      name = "CS2 Surfing",
      desc = "Ramp surf smoothly along angled walls",
      isToggle = true,
      get = function()
        return
            S.cs2Surf
      end,
      toggle = function(
          state)
        S.cs2Surf = state
      end
    },
    {
      name = "CS2 Auto-Bhop",
      desc = "Perfect bunnyhopping on jump contact",
      isToggle = true,
      get = function()
        return
            S.cs2Bhop
      end,
      toggle = function(
          state)
        S.cs2Bhop = state
      end
    },
    { name = "CS2 Surf Speed", desc = "Configure surf ramp velocity", hasSlider = true, configKey = "surfSpeed", min = 30,  max = 200 },
    { name = "CS2 Bhop Accel", desc = "Air acceleration multiplier",  hasSlider = true, configKey = "bhopAccel", min = 1.0, max = 3.5, isDecimal = true },

    { isSection = true,        name = "Speed & Flight" },
    {
      name = "Speed Boost",
      desc = "Toggle customized walking velocity",
      isToggle = true,
      get = function() return S.speed end,
      toggle = function(state)
        S.speed = state
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = state and gameConfig.walkSpeed or originalWalkSpeed end
      end
    },
    {
      name = "Walk Speed Value",
      desc = "Configure walk speed amount",
      hasSlider = true,
      configKey = "walkSpeed",
      min = 16,
      max = 200,
      onChange = function(v)
        if S.speed then
          local hum = GetHumanoid(); if hum then hum.WalkSpeed = v end
        end
      end
    },
    {
      name = "Fly Mode",
      desc = "Fly freely with WASD + Space/Shift",
      isToggle = true,
      get = function() return S.fly end,
      toggle = function(state)
        S.fly = state
        local hum = GetHumanoid()
        local root = GetRoot()
        if hum then hum.PlatformStand = state end
        if state then
          if not S.flyBV and root then
            S.flyBV = Instance.new("BodyVelocity")
            S.flyBV.MaxForce = Vector3.new(40000, 40000, 40000)
            S.flyBV.Velocity = Vector3.new(0, 0, 0)
            S.flyBV.Parent = root
          end
        else
          if S.flyBV then
            S.flyBV:Destroy()
            S.flyBV = nil
          end
        end
      end
    },
    { name = "Fly Speed Value", desc = "Configure flight speed velocity", hasSlider = true, configKey = "flySpeed", min = 10, max = 200 },
    {
      name = "Jump Boost",
      desc = "Toggle customized jump power",
      isToggle = true,
      get = function() return S.jump end,
      toggle = function(state)
        S.jump = state
        local hum = GetHumanoid()
        if hum then hum.JumpPower = state and gameConfig.jumpPower or originalJumpPower end
      end
    },
    {
      name = "Jump Power Value",
      desc = "Configure jump power height",
      hasSlider = true,
      configKey = "jumpPower",
      min = 50,
      max = 300,
      onChange = function(v)
        if S.jump then
          local hum = GetHumanoid(); if hum then hum.JumpPower = v end
        end
      end
    },
    {
      name = "Infinite Jump",
      desc = "Jump infinitely mid-air",
      isToggle = true,
      get = function()
        return S
            .infJump
      end,
      toggle = function(
          state)
        S.infJump = state
      end
    },

    { isSection = true,         name = "Physics & Traversal" },
    {
      name = "NoClip",
      desc = "Walk freely through walls",
      isToggle = true,
      get = function() return S.noclip end,
      toggle = function(state)
        S.noclip = state
        if not state then RestoreCollision() end
      end
    },
    {
      name = "Click Teleport",
      desc = "Ctrl + Click to teleport anywhere",
      isToggle = true,
      get = function()
        return
            S.clickTP
      end,
      toggle = function(
          state)
        S.clickTP = state
      end
    },
    {
      name = "Low Gravity",
      desc = "Floaty moon physics",
      isToggle = true,
      get = function() return S.lowGravity end,
      toggle = function(state)
        S.lowGravity = state
        workspace.Gravity = state and 40 or originalGravity
      end
    },
    {
      name = "Hip Height Mod",
      desc = "Toggle elevated torso height",
      isToggle = true,
      get = function() return S.hipHeight end,
      toggle = function(state)
        S.hipHeight = state
        local hum = GetHumanoid()
        if hum then hum.HipHeight = state and gameConfig.hipHeight or originalHipHeight end
      end
    },
    {
      name = "Hip Height Value",
      desc = "Configure character torso elevation",
      hasSlider = true,
      configKey = "hipHeight",
      min = 0,
      max = 20,
      onChange = function(v)
        if S.hipHeight then
          local hum = GetHumanoid(); if hum then hum.HipHeight = v end
        end
      end
    },
    {
      name = "Spinbot",
      desc = "Rapidly spin character in place",
      isToggle = true,
      get = function()
        return
            S.spinbot
      end,
      toggle = function(
          state)
        S.spinbot = state
      end
    },
    { name = "Spin Speed",    desc = "Configure spinbot rotation velocity", hasSlider = true, configKey = "spinSpeed", min = 5, max = 100 },
    {
      name = "Anti-Fling",
      desc = "Prevent physics fling displacement",
      isToggle = true,
      get = function()
        return
            S.antiFling
      end,
      toggle = function(
          state)
        S.antiFling = state
      end
    },

    { isSection = true,       name = "Waypoints" },
    { name = "Save Position", desc = "Save current coordinates",            isButton = true,  action = SavePosition },
    { name = "Load Position", desc = "Teleport to saved coordinates",       isButton = true,  action = LoadPosition }
  },
  Visuals = {
    { isSection = true,           name = "Player Visuals & ESP" },
    {
      name = "ESP Highlights",
      desc = "Highlight all players & distance",
      isToggle = true,
      get = function()
        return
            S.esp
      end,
      toggle = function(
          state)
        ToggleESP(state)
      end
    },
    { name = "ESP Fill Alpha",    desc = "Adjust highlight interior opacity", hasSlider = true, configKey = "espFillTrans",    min = 0, max = 1, isDecimal = true, onChange = UpdateESPTransparency },
    { name = "ESP Outline Alpha", desc = "Adjust highlight outline opacity",  hasSlider = true, configKey = "espOutlineTrans", min = 0, max = 1, isDecimal = true, onChange = UpdateESPTransparency },
    {
      name = "Player Chams",
      desc = "3D Wall-penetrating body boxes",
      isToggle = true,
      get = function()
        return
            S.chams
      end,
      toggle = function(
          state)
        ToggleChams(state)
      end
    },
    { name = "Chams Alpha", desc = "Adjust 3D box opacity", hasSlider = true, configKey = "chamsTrans", min = 0, max = 1, isDecimal = true, onChange = UpdateChamsTransparency },

    { isSection = true,     name = "World & Lighting" },
    {
      name = "Fullbright",
      desc = "Max ambient light & clear visibility",
      isToggle = true,
      get = function()
        return
            S.fullbright
      end,
      toggle = function(
          state)
        ToggleFullbright(state)
      end
    },
    {
      name = "Night Mode (Eye Saver)",
      desc = "Dim world lighting & glare for night play",
      isToggle = true,
      get = function()
        return
            S.darkMode
      end,
      toggle = function(
          state)
        ToggleDarkMode(state)
      end
    },
    {
      name = "Night Dimness Level",
      desc = "Adjust how dark the world becomes",
      hasSlider = true,
      configKey = "nightDimness",
      min = 0.1,
      max = 0.8,
      isDecimal = true,
      onChange = function()
        if S.darkMode then
          UpdateDarkMode()
        end
      end
    },
    {
      name = "No Fog",
      desc = "Remove all game atmosphere fog",
      isToggle = true,
      get = function()
        return
            S.noFog
      end,
      toggle = function(
          state)
        ToggleNoFog(state)
      end
    },
    {
      name = "No VFX",
      desc = "Kill particles, weather, bloom & screen FX",
      isToggle = true,
      get = function()
        return
            S.noVFX
      end,
      toggle = function(
          state)
        ToggleNoVFX(state)
      end
    },
    {
      name = "FPS Boost",
      desc = "Strip textures, Decals, shadows, Sky & post-FX for max framerate",
      isToggle = true,
      get = function()
        return
            S.fpsBoost
      end,
      toggle = function(
          state)
        ToggleFPSBoost(state)
      end
    },
    {
      name = "X-Ray Vision",
      desc = "Make world structures see-through",
      isToggle = true,
      get = function()
        return
            S.xRay
      end,
      toggle = function(
          state)
        ToggleXRay(state)
      end
    },
    {
      name = "Freecam Mode",
      desc = "Detached free spectator camera",
      isToggle = true,
      get = function()
        return
            S.freecam
      end,
      toggle = function(
          state)
        ToggleFreecam(state)
      end
    }
  },
  MM2 = {
    { isSection = true, name = "Role Radar & ESP" },
    {
      name = "MM2 Role ESP",
      desc = "Live Auto-Revealer: Murderer (Red), Sheriff (Blue), Innocents (Green)",
      isToggle = true,
      get = function() return MM2.roleESP end,
      toggle = function(state)
        MM2.roleESP = state
        if state then ToggleESP(true) else UpdateESPTheme() end
      end
    },
    {
      name = "Dropped Gun ESP",
      desc = "Gold 3D Box & Marker on dropped Sheriff gun",
      isToggle = true,
      get = function()
        return
            MM2.gunESP
      end,
      toggle = function(
          state)
        MM2.gunESP = state
      end
    },
    {
      name = "Trap ESP & Radar",
      desc = "Highlight all active murderer bear traps across map",
      isToggle = true,
      get = function() return MM2.trapESP end,
      toggle = function(state)
        MM2.trapESP = state
        if not state and S.espFolder then
          for _, ch in ipairs(S.espFolder:GetChildren()) do
            if ch.Name:find("Trap_") then ch:Destroy() end
          end
        end
      end
    },
    {
      name = "Coin ESP",
      desc = "Highlight MM2 coins through walls",
      isToggle = true,
      get = function() return MM2.coinESP end,
      toggle = function(state)
        MM2.coinESP = state
        if not state then
          local coinFolder = workspace:FindFirstChild("CheatMenu_CoinESP")
          if coinFolder then coinFolder:ClearAllChildren() end
        end
      end
    },

    { isSection = true, name = "Automation & Auras" },
    {
      name = "Auto Grab Sheriff Gun",
      desc = "Auto equip dropped Sheriff gun (Murderer only)",
      isToggle = true,
      get = function()
        return
            MM2.autoGrabGun
      end,
      toggle = function(
          state)
        MM2.autoGrabGun = state
      end
    },
    {
      name = "Auto-Shoot Murderer",
      desc = "Auto equip gun and fire at Murderer when visible",
      isToggle = true,
      get = function()
        return
            MM2.autoShoot
      end,
      toggle = function(
          state)
        MM2.autoShoot = state
      end
    },
    {
      name = "Magic Bullet",
      desc = "Auto-switch: gun=silent aim, knife=predicted throw",
      isToggle = true,
      get = function()
        return
            MM2.magicBullet
      end,
      toggle = function(
          state)
        MM2.magicBullet = state
        UpdateMagicBullet()
      end
    },
    {
      name = "Knife Kill Aura",
      desc = "Auto-slash nearby innocents if you are Murderer",
      isToggle = true,
      get = function()
        return
            MM2.knifeAura
      end,
      toggle = function(
          state)
        MM2.knifeAura = state
      end
    },
    {
      name = "Kill Aura Range",
      desc = "Radius for auto knife stabbing",
      hasSlider = true,
      configKey = "MM2.auraRadius",
      min = 5,
      max = 40,
      onChange = function(
          v)
        MM2.auraRadius = v
      end
    },

    { isSection = true,                  name = "Survival & Defense" },
    {
      name = "Anti-Stab Ghost Dodge",
      desc = "Auto-teleport away if Murderer lunges with knife",
      isToggle = true,
      get = function()
        return
            MM2.antiStab
      end,
      toggle = function(
          state)
        MM2.antiStab = state
      end
    },
    {
      name = "Auto-Collect Coins",
      desc = "Auto-farm all spawned coins across the active map",
      isToggle = true,
      get = function()
        return
            MM2.autoCoins
      end,
      toggle = function(
          state)
        MM2.autoCoins = state
      end
    },
    {
      name = "Coin Farm Speed",
      desc = "Delay between collecting coin nodes",
      hasSlider = true,
      configKey = "MM2.coinDelay",
      min = 0.1,
      max = 1.0,
      isDecimal = true,
      onChange = function(
          v)
        MM2.coinDelay = v
      end
    },

    { isSection = true,                  name = "Instant Actions" },
    { name = "Grab Dropped Gun",         desc = "Teleport directly to dropped gun",        isButton = true, action = GrabDroppedGun,      condition = IsPlayerActive },
    { name = "Shoot Murderer (Sheriff)", desc = "Equip gun and fire directly at Murderer", isButton = true, action = ShootMurdererSheriff },
    { name = "Kill All (Murderer)",      desc = "Auto-slash every innocent on the map",    isButton = true, action = KillAllMurderer },
    { name = "TP to Murderer",           desc = "Teleport behind active Murderer",         isButton = true, action = TeleportToMurderer },
    { name = "TP to Sheriff",            desc = "Teleport behind active Sheriff / Hero",   isButton = true, action = TeleportToSheriff },
    { name = "TP to Lobby",              desc = "Safely return to game lobby",             isButton = true, action = TeleportToLobby }
  },
  Trolling = {
    { isSection = true,            name = "Direct Actions" },
    { name = "Teleport to Target", desc = "Teleport instantly to target player",        isButton = true, action = TeleportToTarget },
    { name = "Fling Target",       desc = "Fling target player (self-fling protected)", isButton = true, action = FlingTarget },
    { name = "Target Trap",        desc = "Trap player in forcefield cage",             isButton = true, action = TargetTrap },
    { name = "Head Sit",           desc = "Sit on target player's head",                isButton = true, action = HeadSitTarget },

    { isSection = true,            name = "Persistent Toggles" },
    {
      name = "Spectate Target",
      desc = "Attach camera to follow target",
      isToggle = true,
      get = function() return S.spectate end,
      toggle = function(state)
        S.spectate = state
        if state and selectedPlayer and selectedPlayer.Character then
          local hum = selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
          if hum then camera.CameraSubject = hum end
        else
          local myHum = GetHumanoid()
          if myHum then camera.CameraSubject = myHum end
        end
      end
    },
    {
      name = "Auto Follow Behind",
      desc = "Perfectly follow behind selected player",
      isToggle = true,
      get = function()
        return
            MM2.autoFollow
      end,
      toggle = function(
          state)
        MM2.autoFollow = state
        if state then StartAutoFollow() else StopAutoFollow() end
      end
    },
    {
      name = "Platform Mode",
      desc = "Act as platform under selected player for infinite jumps",
      isToggle = true,
      get = function()
        return
            MM2.platformMode
      end,
      toggle = function(
          state)
        MM2.platformMode = state
        if state then StartPlatformMode() else StopPlatformMode() end
      end
    },
    {
      name = "Boost Mode",
      desc = "Push selected player forward using your hitbox",
      isToggle = true,
      get = function()
        return MM2.boostMode
      end,
      toggle = function(
          state)
        MM2.boostMode = state
        if state then StartBoostMode() else StopBoostMode() end
      end
    }
  },
  Server = {
    { isSection = true,       name = "Server Navigation" },
    { name = "Rejoin Server", desc = "Re-connect to current server",          isButton = true, action = Rejoin },
    { name = "Server Hop",    desc = "Hop to another active server instance", isButton = true, action = ServerHop },

    { isSection = true,       name = "Session & Utilities" },
    {
      name = "Anti-AFK Protection",
      desc = "Prevents 20-minute idle kick",
      isToggle = true,
      get = function()
        return
            antiAFKActive
      end,
      toggle = function(
          state)
        ToggleAntiAFK(state)
      end
    },
    { name = "Copy Server Job ID", desc = "Copy current JobId to clipboard",         isButton = true, action = CopyJobId },
    { name = "Copy Place ID",      desc = "Copy active PlaceId to clipboard",        isButton = true, action = CopyPlaceId },
    { name = "Copy Position",      desc = "Copy character coordinates to clipboard", isButton = true, action = CopyPlayerPosition }
  },
  Themes = {
    { isSection = true, name = "Aero & Retro Styles" },
    {
      name = "Windows Vista Aero",
      desc = "Authentic Glass & Slate Blue Theme",
      isButton = true,
      action = function()
        currentThemeName = "Windows Vista Aero"; XP = Themes[currentThemeName]
        BuildGUI(); UpdateESPTheme(); BuildHUD()
      end
    },
    {
      name = "Windows XP Luna",
      desc = "Classic Windows XP Luna Theme",
      isButton = true,
      action = function()
        currentThemeName = "Windows XP Luna"; XP = Themes[currentThemeName]
        BuildGUI(); UpdateESPTheme(); BuildHUD()
      end
    },

    { isSection = true, name = "Modern Colorways" },
    {
      name = "Dark Obsidian",
      desc = "Modern Matte Black & Cyan",
      isButton = true,
      action = function()
        currentThemeName = "Dark Obsidian"; XP = Themes[currentThemeName]
        BuildGUI(); UpdateESPTheme(); BuildHUD()
      end
    },
    {
      name = "Crimson Blood",
      desc = "Dark Ruby & Neon Red",
      isButton = true,
      action = function()
        currentThemeName = "Crimson Blood"; XP = Themes[currentThemeName]
        BuildGUI(); UpdateESPTheme(); BuildHUD()
      end
    },
    {
      name = "Emerald Cyber",
      desc = "Deep Forest & Neon Green",
      isButton = true,
      action = function()
        currentThemeName = "Emerald Cyber"; XP = Themes[currentThemeName]
        BuildGUI(); UpdateESPTheme(); BuildHUD()
      end
    },
    {
      name = "Royal Amethyst",
      desc = "Deep Purple & Gold",
      isButton = true,
      action = function()
        currentThemeName = "Royal Amethyst"; XP = Themes[currentThemeName]
        BuildGUI(); UpdateESPTheme(); BuildHUD()
      end
    }
  },
  Config = {
    { isSection = true,             name = "Camera Settings" },
    {
      name = "Camera FOV",
      desc = "Adjust field of view",
      hasSlider = true,
      configKey = "fov",
      min = 30,
      max = 120,
      onChange = function(v)
        camera.FieldOfView = v
      end
    },

    { isSection = true,             name = "Aimbot Tuning" },
    { name = "Aimbot Smoothness",   desc = "Control aim lock speed",                  hasSlider = true, configKey = "aimbotSmoothness", min = 0.05, max = 1.0, isDecimal = true },
    { name = "Aimbot FOV Radius",   desc = "Aimbot maximum search distance",          hasSlider = true, configKey = "aimbotFOV",        min = 50,   max = 800 },

    { isSection = true,             name = "Audio & Visuals" },
    { name = "Master Sound Volume", desc = "Adjust client game volume (ignoring VC)", hasSlider = true, configKey = "masterVolume",     min = 0,    max = 1,   isDecimal = true, onChange = SetMasterVolume },
    {
      name = "ESP Text Size",
      desc = "Adjust overhead name tag font size",
      hasSlider = true,
      configKey = "espTextSize",
      min = 8,
      max = 22,
      onChange = function(v)
        if S.espFolder then
          for _, tag in ipairs(S.espFolder:GetChildren()) do
            if tag:IsA("BillboardGui") and tag:FindFirstChild("TagWindow") then
              local head = tag.TagWindow:FindFirstChild("TagHeader")
              if head and head:FindFirstChild("NameLabel") then
                head.NameLabel.TextSize = v
              end
              local info = tag.TagWindow:FindFirstChild("InfoLabel")
              if info then
                info.TextSize = math.max(v - 2, 8)
              end
            end
          end
        end
      end
    }
  },
  HUD = {
    { isSection = true, name = "Bottom HUD" },
    {
      name = "Show Bottom HUD",
      desc = "Toggle the bottom-left info HUD",
      isToggle = true,
      get = function() return S.hudEnabled end,
      toggle = function(state)
        ToggleHUD(state)
      end
    }
  },
  Music = {
    { isSection = true, name = "Music Colors" },
    {
      name = "Dynamic UI Colors from Cover",
      desc = "Auto-adapt GUI theme from song cover art palette",
      isToggle = true,
      get = function() return Music.dynamicColorEnabled end,
      toggle = function(state)
        Music.dynamicColorEnabled = state
        if not state then RevertToDefaultTheme() end
      end
    }
  },
}

-- ==================== EVENT CONNECTIONS ====================

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

local function UpdateMusicUI()
  if Music.hudLabel and Music.hudLabel.Parent then
    if Music.song ~= "" then
      local prefix = Music.active and "♪ " or "⏸ "
      local txt = prefix .. Music.song
      if Music.artist ~= "" then txt = txt .. " - " .. Music.artist end
      Music.hudLabel.Text = txt
      Music.hudLabel.TextColor3 = Music.active and Color3.fromRGB(50, 255, 140) or Color3.fromRGB(240, 248, 255)
    else
      Music.hudLabel.Text = "♪ No music playing"
      Music.hudLabel.TextColor3 = Color3.fromRGB(200, 220, 245)
    end
  end
  if Music.hudCover and Music.hudCover.Parent then
    if Music.coverAsset ~= "" and not Music.coverIsProcedural then
      Music.hudCover.Image = Music.coverAsset
      Music.hudCover.Visible = true
    elseif Music.coverIsProcedural then
      Music.hudCover.Image = ""
      Music.hudCover.Visible = true
    else
      Music.hudCover.Visible = false
    end
  end
  if Music.menuSongLbl and Music.menuSongLbl.Parent then
    Music.menuSongLbl.Text = Music.song ~= "" and Music.song or "No track playing"
  end
  if Music.menuArtLbl and Music.menuArtLbl.Parent then
    Music.menuArtLbl.Text = Music.artist ~= "" and ("by " .. Music.artist) or ""
  end
  if Music.menuStatusLbl and Music.menuStatusLbl.Parent then
    Music.menuStatusLbl.Text = Music.statusText
    Music.menuStatusLbl.TextColor3 = Music.active and Color3.fromRGB(30, 215, 96) or
        (Music.song ~= "" and Color3.fromRGB(255, 200, 50) or XP.tabInactiveText)
  end
  if Music.menuCover and Music.menuCover.Parent then
    -- Always show the cover box; swap between real art and the placeholder icon child
    if Music.coverIsProcedural then
      Music.menuCover.Image = ""
    else
      Music.menuCover.Image = Music.coverAsset
    end
    local iconChild = Music.menuCover:FindFirstChildOfClass("TextLabel")
    if iconChild then
      iconChild.Visible = (Music.coverAsset == "")
    end
  end
end

local function WriteAndSetCover(imgData)
  if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then return end
  local fileName = "unimenu_cover_" .. tostring(os.time()) .. ".jpg"
  writefile(fileName, imgData)
  Music.coverAsset = getcustomasset(fileName)
  UpdateMusicUI()
  ApplyCoverTheme(imgData)
end

-- Extract dominant colors from cover image data and apply as dynamic theme
local function ApplyCoverTheme(imgData)
  if not Music.dynamicColorEnabled then return end
  -- Use a hash of the image data to generate a consistent but varied color scheme
  -- Since we can't decode JPG pixels easily, we hash the raw bytes
  local hash = 0
  for i = 1, math.min(#imgData, 1024) do
    hash = (hash * 31 + string.byte(imgData, i)) % 0x7FFFFFFF
  end

  -- Generate two hues with guaranteed separation to avoid monochromatic
  local hue1 = hash % 360
  local hue2 = (hue1 + 100 + (hash % 80)) % 360         -- 100-180 degree separation
  local sat1 = 0.45 + (hash % 30) / 100                 -- 0.45-0.75 saturation
  local sat2 = 0.45 + (math.floor(hash / 30) % 30) / 100
  local val1 = 0.25 + (hash % 25) / 100                 -- 0.25-0.5 value
  local val2 = 0.5 + (math.floor(hash / 25) % 30) / 100 -- 0.5-0.8 value

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
  ApplyDynamicTheme()
end

local function ApplyDynamicTheme()
  if not Music.usingDynamicTheme or not Music.dynamicTheme then return end
  local theme = Music.dynamicTheme
  XP = theme
  if gui then BuildGUI() end
  UpdateESPTheme()
  BuildHUD()
  UpdateMusicUI()
end

local function RevertToDefaultTheme()
  if not Music.usingDynamicTheme then return end
  local defaultTheme = Themes[currentThemeName] or Themes["Windows XP Luna"]
  XP = defaultTheme
  Music.usingDynamicTheme = false
  Music.dynamicTheme = nil
  if gui then BuildGUI() end
  UpdateESPTheme()
  BuildHUD()
  UpdateMusicUI()
end

local function FetchCoverFromiTunes(song, artist)
  -- iTunes Search API — works for singles, obscure artists, everything in Apple Music catalog
  local query = UrlEncode(artist .. " " .. song)
  local url = "https://itunes.apple.com/search?term=" .. query .. "&media=music&entity=song&limit=1"
  local res = MusicHTTP(url)
  if not res or not res.Body or #res.Body < 10 then return end
  local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
  if not ok or not data or not data.results or #data.results == 0 then return end
  local artUrl = data.results[1].artworkUrl100
  if not artUrl or artUrl == "" then return end
  -- Upgrade to higher resolution (600x600)
  artUrl = artUrl:gsub("100x100bb", "600x600bb")
  local imgRes = MusicHTTP(artUrl)
  if imgRes and imgRes.Body and #imgRes.Body > 1000 then
    pcall(WriteAndSetCover, imgRes.Body)
  end
end

local function DownloadAlbumCover(lastfmImgUrl, song, artist)
  local cacheKey = (lastfmImgUrl or "") .. "|" .. (song or "") .. "|" .. (artist or "")
  if cacheKey == Music.lastCoverUrl and Music.coverAsset ~= "" then
    return -- already showing the right art
  end
  Music.lastCoverUrl = cacheKey
  Music.coverAsset = ""
  UpdateMusicUI()

  task.spawn(function()
    -- 1. Try Last.fm provided image (works for popular albums)
    local lastfmHasImage = lastfmImgUrl and lastfmImgUrl ~= "" and
        not lastfmImgUrl:find("2a96cbd8b46e442fc41c2b86b821562f")
    if lastfmHasImage then
      local res = MusicHTTP(lastfmImgUrl)
      if res and res.Body and #res.Body > 1000 then
        pcall(WriteAndSetCover, res.Body)
        return -- success, done
      end
    end

    -- 2. Fallback: iTunes Search API (covers singles & less popular artists)
    if song and song ~= "" and artist and artist ~= "" then
      pcall(FetchCoverFromiTunes, song, artist)
    end

    -- 3. Final fallback: if no image asset was set, build a procedural
    --    visual representation (animated gradient keyed off the song hash)
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
    coverGui.Name = "ProceduralCover"
    coverGui.ResetOnSpawn = false
    coverGui.IgnoreGuiInset = true
    coverGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = Color3.fromHSV(hue1 / 360, 0.7, 0.25)
    frame.Parent = coverGui

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, Color3.fromHSV(hue1 / 360, 0.85, 0.55)),
      ColorSequenceKeypoint.new(1, Color3.fromHSV(hue2 / 360, 0.85, 0.35)),
    })
    grad.Rotation = gen * 45
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
    UpdateMusicUI()
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
    UpdateMusicUI()
    return
  end

  local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
  if not ok or not data then
    Music.statusText = "[ERR] Failed to decode JSON response"
    UpdateMusicUI()
    return
  end

  if data.error then
    Music.statusText = "[ERR] " .. tostring(data.message or ("Error code " .. tostring(data.error)))
    UpdateMusicUI()
    return
  end

  if not data.recenttracks then
    Music.statusText = "[ERR] No recent tracks found for user"
    UpdateMusicUI()
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

    -- Extract album cover image URL
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
  UpdateMusicUI()
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

local function SpotifyDisconnect()
  spotifyToken = ""; spotifyRefreshToken = ""
  spotifyConnected = false; spotifyPlaying = false
  spotifySong = "Not connected"; spotifyArtist = ""
  SpotifyRefreshUI()
end

local function SpotifyNext()
  SpotifyRequest("POST", "/me/player/next"); task.wait(0.4); SpotifyPoll()
end
local function SpotifyPrev()
  SpotifyRequest("POST", "/me/player/previous"); task.wait(0.4); SpotifyPoll()
end
local function SpotifySetVolume(vol)
  spotifyVolume = math.clamp(math.floor(vol), 0, 100); SpotifyRequest("PUT",
    "/me/player/volume?volume_percent=" .. spotifyVolume)
end

local function SpotifyTogglePlay()
  if spotifyPlaying then
    SpotifyRequest("PUT", "/me/player/pause"); spotifyPlaying = false
  else
    SpotifyRequest("PUT", "/me/player/play"); spotifyPlaying = true
  end
  SpotifyRefreshUI(); task.wait(0.4); SpotifyPoll()
end

-- ==================== EVENT CONNECTIONS ====================

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
        -- Nullify all rotational forces
        root.RotVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.AssemblyAngularAcceleration = Vector3.zero
        -- Cap linear velocity to prevent fling
        if root.AssemblyLinearVelocity.Magnitude > 50 then
          root.AssemblyLinearVelocity = root.AssemblyLinearVelocity.Unit * 30
        end
        -- Remove any external forces applied to root
        for _, c in ipairs(root:GetChildren()) do
          if c:IsA("BodyVelocity") or c:IsA("BodyForce") or c:IsA("BodyAngularVelocity") or c:IsA("BodyGyro") or c:IsA("VectorForce") or c:IsA("LineForce") then
            c:Destroy()
          end
        end
      end)
    end
  end
end))

TrackConnection(UserInputService.JumpRequest:Connect(function()
  if S.infJump then
    local hum = GetHumanoid()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
  end
end))

TrackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
  if gpe then return end
  if S.clickTP and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
    local mouse = player:GetMouse()
    local root = GetRoot()
    if root and mouse.Hit then
      root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
    end
  end
end))

-- Setup collision groups to prevent player-to-player collision manipulation
local PhysicsService = game:GetService("PhysicsService")
local playerCollisionGroup = "PlayerCollisionGroup"
local otherPlayersGroup = "OtherPlayersGroup"
local ghostGroup = "CoinFarmGhost"
pcall(function()
  PhysicsService:CreateCollisionGroup(playerCollisionGroup)
  PhysicsService:CreateCollisionGroup(otherPlayersGroup)
  PhysicsService:CreateCollisionGroup(ghostGroup)
  PhysicsService:CollisionGroupSetCollidable(playerCollisionGroup, otherPlayersGroup, false)
  PhysicsService:CollisionGroupSetCollidable(otherPlayersGroup, otherPlayersGroup, false)
  -- Ghost group collides with nothing
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

local function applyLocalCollisionGroup()
  local char = player.Character
  if char then setPlayerCollisionGroup(char, playerCollisionGroup) end
end
player.CharacterAdded:Connect(applyLocalCollisionGroup)
applyLocalCollisionGroup()

for _, plr in ipairs(Players:GetPlayers()) do
  if plr ~= player then
    local function applyOtherCollisionGroup(c)
      if c then setPlayerCollisionGroup(c, otherPlayersGroup) end
    end
    if plr.Character then applyOtherCollisionGroup(plr.Character) end
    plr.CharacterAdded:Connect(applyOtherCollisionGroup)
  end
end
Players.PlayerAdded:Connect(function(plr)
  if plr ~= player then
    plr.CharacterAdded:Connect(function(c)
      setPlayerCollisionGroup(c, otherPlayersGroup)
    end)
  end
end)

-- Main Heartbeat Loop: CS2 Mechanics, Aimbot, Fly, Visuals, Trolling
TrackConnection(RunService.Heartbeat:Connect(function(deltaTime)
  local root = GetRoot()
  local hum = GetHumanoid()

  -- 1. CS2 Surfing Engine
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
            S.isSurfing = false
            hum.PlatformStand = false
          end
        end
      else
        if S.isSurfing then
          S.isSurfing = false
          hum.PlatformStand = false
        end
      end
    else
      if S.isSurfing then
        S.isSurfing = false
        hum.PlatformStand = false
      end
    end
  end

  -- 2. CS2 Auto-Bhop
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

  -- 4. Fly Movement
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

  -- 5. Freecam Movement
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

  -- 7. Auto Clicker
  if S.autoClicker and typeof(mouse1click) == "function" then
    pcall(mouse1click)
  end

  -- 8. MM2 Auto-Shoot
  if MM2.autoShoot and tick() - MM2.lastShootTime >= 0.5 then
    local myChar = player.Character
    local hasGun = (myChar and myChar:FindFirstChild("Gun")) or
        (player.Backpack and player.Backpack:FindFirstChild("Gun"))
    local m = GetMM2Murderer()
    if hasGun and m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") then
      MM2.lastShootTime = tick()
      ShootMurdererSheriff()
    end
  end

  if MM2.antiStab and tick() - MM2.lastDodgeTime >= 0.8 then
    DodgeMurdererKnife()
  end

  -- 8b. MM2 Auto Grab Sheriff Gun
  if MM2.autoGrabGun and tick() - MM2.lastGrabTime >= 0.5 then
    if IsPlayerActive() then
      local gunPart = GetMM2DroppedGun()
      if gunPart then
        MM2.lastGrabTime = tick()
        AutoGrabSheriffGun()
      end
    end
  end

  if MM2.trapESP then
    UpdateTrapESP()
  end

  if MM2.knifeAura and root then
    local myChar = player.Character
    local knife = (myChar and (myChar:FindFirstChild("Knife") or myChar:FindFirstChildWhichIsA("Tool") and myChar:FindFirstChildWhichIsA("Tool").Name:lower():find("knife")))
        or
        (player.Backpack and (player.Backpack:FindFirstChild("Knife") or player.Backpack:FindFirstChildWhichIsA("Tool") and player.Backpack:FindFirstChildWhichIsA("Tool").Name:lower():find("knife")))
    if knife then
      if knife.Parent ~= myChar then knife.Parent = myChar end
      local knifeHandle = knife:FindFirstChild("Handle")
      for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
          local targetRoot = plr.Character.HumanoidRootPart
          local dist = (targetRoot.Position - root.Position).Magnitude
          if dist <= MM2.auraRadius then
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tHum and tHum.Health > 0 then
              if knifeHandle and typeof(firetouchinterest) == "function" then
                pcall(function()
                  firetouchinterest(targetRoot, knifeHandle, 0)
                  firetouchinterest(targetRoot, knifeHandle, 1)
                end)
              end
              pcall(function() knife:Activate() end)
            end
          end
        end
      end
    end
  end

  if MM2.autoCoins and root and not S.coinTweening then
    local hum = GetHumanoid()
    if not hum or hum.Health <= 0 then return end
    local now = tick()
    if now - MM2.lastCoinTime < MM2.coinDelay then return end
    MM2.lastCoinTime = now

    local activeCoins = GetMM2ActiveCoins()
    if #activeCoins == 0 then return end

    -- Pick the closest uncollected coin relative to current position
    local closestCoin, closestDist = nil, math.huge
    local rootPos = root.Position
    for _, coin in ipairs(activeCoins) do
      if coin and coin and coin.Parent and coin:IsA("BasePart") and not collectedCoinSet[tostring(coin)] then
        local d = (coin.Position - rootPos).Magnitude
        if d < closestDist then
          closestDist = d
          closestCoin = coin
        end
      end
    end

    if not closestCoin then
      ResetCoinCache()
      return
    end

    S.coinTweening = true
    task.spawn(function()
      -- Continuous coin-to-coin loop: keep collecting the next closest coin
      -- until none remain or autofarm is disabled.
      while MM2.autoCoins and S.coinTweening and not collectedCoinSet[tostring(closestCoin)] do
        -- Only run while the player is alive and in a playable state
        local loopHum = GetHumanoid()
        if not loopHum or loopHum.Health <= 0 then
          S.coinTweening = false
          ResetCoinCache()
          return
        end

        local char = GetCharacter()
        local tweenRoot = GetRoot()
        if not tweenRoot or not char then
          S.coinTweening = false
          ResetCoinCache()
          return
        end

        if not closestCoin.Parent or not closestCoin:IsDescendantOf(workspace) then
          MarkCoinCollected(closestCoin)
          S.coinTweening = false
          ResetCoinCache()
          return
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local originalPlatformStand = hum and hum.PlatformStand
        local originalCollide = {}
        for _, p in ipairs(char:GetDescendants()) do
          if p:IsA("BasePart") then
            originalCollide[p] = p.CanCollide
            p.CanCollide = false -- Disable ALL collision (like NoClip)
            -- Also set collision group to ensure nothing touches us
            pcall(function() p.CollisionGroup = "CoinFarmGhost" end)
          end
        end
        if hum then
          hum.PlatformStand = true
          task.wait(0.03)
        end

        -- Anchor the root part completely
        local wasAnchored = tweenRoot.Anchored
        tweenRoot.Anchored = true
        tweenRoot.AssemblyLinearVelocity = Vector3.zero
        tweenRoot.AssemblyAngularVelocity = Vector3.zero

        -- Tween to coin using CFrame (true anchored tween)
        local distance = (closestCoin.Position - tweenRoot.Position).Magnitude
        local speed = 300 -- studs/sec
        local tweenTime = math.clamp(distance / speed, 0.1, 2)
        local tween = TweenService:Create(tweenRoot, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
          { CFrame = closestCoin.CFrame * CFrame.new(0, -1, 0) })
        tween:Play()
        tween.Completed:Wait()

        -- Collect
        local collectedHere = false
        if closestCoin.Parent and closestCoin:IsDescendantOf(workspace) then
          if typeof(firetouchinterest) == "function" then
            pcall(function()
              firetouchinterest(tweenRoot, closestCoin, 0)
              firetouchinterest(tweenRoot, closestCoin, 1)
            end)
          end
          task.wait(0.1)
          collectedHere = true
        end

        -- Restore anchored state
        tweenRoot.Anchored = wasAnchored
        if hum then hum.PlatformStand = originalPlatformStand end
        for p, wasCollide in pairs(originalCollide) do
          if p and p.Parent then
            p.CanCollide = wasCollide
          end
        end

        MarkCoinCollected(closestCoin)

        if not collectedHere then
          -- Failed to reach/collect (e.g. timed out) — stop to avoid infinite loop
          S.coinTweening = false
          ResetCoinCache()
          return
        end

        -- Pick the next closest uncollected coin for the next iteration
        local activeCoins2 = GetMM2ActiveCoins()
        local nextCoin, nextDist = nil, math.huge
        local rPos = (GetRoot() and GetRoot().Position) or Vector3.new()
        for _, coin in ipairs(activeCoins2) do
          if coin and coin.Parent and coin:IsA("BasePart") and not collectedCoinSet[tostring(coin)] then
            local d = (coin.Position - rPos).Magnitude
            if d < nextDist then
              nextDist = d
              nextCoin = coin
            end
          end
        end

        if not nextCoin then
          -- All coins collected
          S.coinTweening = false
          ResetCoinCache()
          return
        end

        closestCoin = nextCoin
        task.wait(MM2.coinDelay)
      end

      S.coinTweening = false
      ResetCoinCache()
    end)
  end

  -- 8. ESP Themed Tag Distance Update (only when general ESP is on)
  if S.esp and S.espFolder then
    local now = tick()
    local shouldUpdateText = (now - lastESPUpdateTick >= 0.1)
    if shouldUpdateText then
      lastESPUpdateTick = now
    end

    local myRoot = GetRoot()
    for _, plr in ipairs(Players:GetPlayers()) do
      if plr ~= player and plr.Character then
        local char      = plr.Character
        local tag       = S.espFolder:FindFirstChild(plr.Name .. "_Tag")
        local hl        = S.espFolder:FindFirstChild(plr.Name .. "_HL")
        local targetHRP = char:FindFirstChild("HumanoidRootPart")

        if not tag or not hl or not hl.Adornee or hl.Adornee ~= char then
          AddESP(plr)
        elseif shouldUpdateText then
          -- Throttled distance update (10Hz)
          if tag:FindFirstChild("TagWindow") and tag.TagWindow:FindFirstChild("InfoLabel") and myRoot and targetHRP then
            local dist = (myRoot.Position - targetHRP.Position).Magnitude
            tag.TagWindow.InfoLabel.Text = "@" .. plr.Name .. " • [" .. math.floor(dist * 0.28) .. "m]"
          end
        end
      end
    end
  end

  -- MM2 Role ESP color updates (runs independently, only updates existing highlights)
  if MM2.roleESP and S.espFolder then
    for _, plr in ipairs(Players:GetPlayers()) do
      if plr ~= player and plr.Character then
        local char = plr.Character
        local hl   = S.espFolder:FindFirstChild(plr.Name .. "_HL")
        if hl then
          local bp          = plr:FindFirstChild("Backpack")
          local hasKnife    = (char:FindFirstChild("Knife") or (char:FindFirstChildWhichIsA("Tool") and char:FindFirstChildWhichIsA("Tool").Name:lower():find("knife")))
              or
              (bp and (bp:FindFirstChild("Knife") or (bp:FindFirstChildWhichIsA("Tool") and bp:FindFirstChildWhichIsA("Tool").Name:lower():find("knife"))))
          local hasGun      = (char:FindFirstChild("Gun") or (char:FindFirstChildWhichIsA("Tool") and char:FindFirstChildWhichIsA("Tool").Name:lower():find("gun")))
              or
              (bp and (bp:FindFirstChild("Gun") or (bp:FindFirstChildWhichIsA("Tool") and bp:FindFirstChildWhichIsA("Tool").Name:lower():find("gun"))))

          local targetColor = Color3.fromRGB(40, 215, 90) -- Innocent
          local headerColor = Color3.fromRGB(25, 150, 65)

          if hasKnife then
            targetColor = Color3.fromRGB(255, 30, 30) -- Murderer
            headerColor = Color3.fromRGB(210, 25, 25)
          elseif hasGun then
            targetColor = Color3.fromRGB(30, 140, 255) -- Sheriff
            headerColor = Color3.fromRGB(20, 110, 225)
          end

          if hl.FillColor ~= targetColor then
            hl.FillColor = targetColor
          end

          local tag = S.espFolder:FindFirstChild(plr.Name .. "_Tag")
          if tag then
            local tagWin = tag:FindFirstChild("TagWindow")
            if tagWin then
              local tagHead = tagWin:FindFirstChild("TagHeader")
              if tagHead then
                tagHead.BackgroundColor3 = headerColor
                local nameLbl = tagHead:FindFirstChild("NameLabel")
                if nameLbl then
                  local roleText = "[INNOCENT]"
                  if hasKnife then roleText = "[MURDERER]" elseif hasGun then roleText = "[SHERIFF]" end
                  nameLbl.Text = roleText .. " " .. plr.DisplayName
                end
              end
            end
          end
        end
      end
    end
  end

  -- 11. MM2 Dropped Gun ESP Box & Tag
  if (MM2.roleESP or MM2.gunESP) then
    local gunPart = GetMM2DroppedGun()
    local gunFolder = workspace:FindFirstChild("CheatMenu_GunESP")
    if not gunFolder then
      gunFolder = Instance.new("Folder")
      gunFolder.Name = "CheatMenu_GunESP"
      gunFolder.Parent = workspace
    end

    if gunPart and MM2.gunESP then
      local hl = gunFolder:FindFirstChild("GunDrop_HL")
      if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "GunDrop_HL"
        hl.FillColor = Color3.fromRGB(255, 215, 0) -- Gold
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.2
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = gunFolder
      end
      hl.Adornee = gunPart

      local tag = gunFolder:FindFirstChild("GunDrop_Tag")
      if not tag then
        tag = Instance.new("BillboardGui")
        tag.Name = "GunDrop_Tag"
        tag.Size = UDim2.new(0, 140, 0, 36)
        tag.StudsOffset = Vector3.new(0, 2.5, 0)
        tag.AlwaysOnTop = true
        tag.MaxDistance = 500
        tag.LightInfluence = 0
        tag.Parent = gunFolder

        local win = Instance.new("Frame")
        win.Name = "TagWindow"
        win.Size = UDim2.new(1, 0, 1, 0)
        win.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        win.BackgroundTransparency = 0.2
        win.BorderSizePixel = 1
        win.BorderColor3 = Color3.fromRGB(255, 215, 0)
        win.Parent = tag

        local head = Instance.new("Frame")
        head.Name = "TagHeader"
        head.Size = UDim2.new(1, 0, 0, 16)
        head.BackgroundColor3 = Color3.fromRGB(230, 180, 0)
        head.BorderSizePixel = 0
        head.Parent = win

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Title"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Text = "★ [DROPPED GUN]"
        lbl.TextColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.BackgroundTransparency = 1
        lbl.Parent = head

        local distLbl = Instance.new("TextLabel")
        distLbl.Name = "DistLabel"
        distLbl.Size = UDim2.new(1, -6, 0, 18)
        distLbl.Position = UDim2.new(0, 3, 0, 17)
        distLbl.Text = "Dropped Gun"
        distLbl.TextColor3 = Color3.fromRGB(255, 230, 100)
        distLbl.Font = Enum.Font.GothamBold
        distLbl.TextSize = 9
        distLbl.BackgroundTransparency = 1
        distLbl.Parent = win
      end
      tag.Adornee = gunPart
      if root and tag:FindFirstChild("TagWindow") and tag.TagWindow:FindFirstChild("DistLabel") then
        local dist = (root.Position - gunPart.Position).Magnitude
        tag.TagWindow.DistLabel.Text = "[" .. math.floor(dist * 0.28) .. "m] • Touch to Grab"
      end
    else
      gunFolder:ClearAllChildren()
    end
  else
    local gunFolder = workspace:FindFirstChild("CheatMenu_GunESP")
    if gunFolder then gunFolder:ClearAllChildren() end
  end

  -- 11. MM2 Coin ESP
  if MM2.coinESP then
    local coinFolder = workspace:FindFirstChild("CheatMenu_CoinESP")
    if not coinFolder then
      coinFolder = Instance.new("Folder")
      coinFolder.Name = "CheatMenu_CoinESP"
      coinFolder.Parent = workspace
    end

    local activeCoins = GetMM2ActiveCoins()
    local validCoinParts = {}
    for _, coin in ipairs(activeCoins) do
      if coin and coin.Parent and coin:IsA("BasePart") then
        table.insert(validCoinParts, coin)
      end
    end

    local existingCoinTags = {}
    for _, child in ipairs(coinFolder:GetChildren()) do
      existingCoinTags[child.Name] = child
    end

    for _, coinPart in ipairs(validCoinParts) do
      local coinId = tostring(coinPart:GetFullName()):gsub("[^%w]", "_")
      local hl = coinFolder:FindFirstChild(coinId .. "_HL")
      local tag = coinFolder:FindFirstChild(coinId .. "_Tag")
      if not hl then
        hl = Instance.new("Highlight")
        hl.Name = coinId .. "_HL"
        hl.FillColor = Color3.fromRGB(255, 215, 0)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = coinFolder
      end
      hl.Adornee = coinPart

      if not tag then
        tag = Instance.new("BillboardGui")
        tag.Name = coinId .. "_Tag"
        tag.Size = UDim2.new(0, 80, 0, 20)
        tag.StudsOffset = Vector3.new(0, 2, 0)
        tag.AlwaysOnTop = true
        tag.MaxDistance = 200
        tag.LightInfluence = 0
        tag.Parent = coinFolder

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Text = "[COIN]"
        lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.Parent = tag
      end
      tag.Adornee = coinPart
      existingCoinTags[coinId .. "_HL"] = nil
      existingCoinTags[coinId .. "_Tag"] = nil
    end

    for name, child in pairs(existingCoinTags) do
      child:Destroy()
    end
  else
    local coinFolder = workspace:FindFirstChild("CheatMenu_CoinESP")
    if coinFolder then coinFolder:ClearAllChildren() end
  end

  -- 12. AIMBOT (Right Click Hold Check)
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
              minDist = dist
              closestPart = targetPart
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

  -- 12. Triggerbot Loop
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

TrackConnection(Players.PlayerAdded:Connect(function(plr)
  UpdatePlayerList()
  plr.CharacterAdded:Connect(function()
    if S.esp then
      task.wait(0.3); AddESP(plr)
    end
    if S.chams then
      task.wait(0.3); ToggleChams(true)
    end
  end)
end))

TrackConnection(Players.PlayerRemoving:Connect(function(plr)
  if S.espFolder then
    local hl = S.espFolder:FindFirstChild(plr.Name .. "_HL")
    if hl then hl:Destroy() end
    local tag = S.espFolder:FindFirstChild(plr.Name .. "_Tag")
    if tag then tag:Destroy() end
  end
  UpdatePlayerList()
end))

for _, plr in ipairs(Players:GetPlayers()) do
  if plr ~= player then
    TrackConnection(plr.CharacterAdded:Connect(function()
      if S.esp then
        task.wait(0.3); AddESP(plr)
      end
      if S.chams then
        task.wait(0.3); ToggleChams(true)
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
    originalWalkSpeed = hum.WalkSpeed
    originalJumpPower = hum.JumpPower
    originalHipHeight = hum.HipHeight
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
  if not S.noclip then
    RestoreCollision()
  end
  if S.spectate then
    local myHum = GetHumanoid()
    if myHum then camera.CameraSubject = myHum end
    S.spectate = false
  end
  S.bhopWasOnGround = false
  ResetCoinCache()
end))

-- ==================== CLEAN SLIDER COMPONENT ====================
local function CreateSlider(container, configKey, minVal, maxVal, isDecimal, onChange)
  local sliderTrack = Instance.new("Frame")
  sliderTrack.Size = UDim2.new(1, -12, 0, 6)
  sliderTrack.Position = UDim2.new(0, 6, 0, 18)
  sliderTrack.BackgroundColor3 = Color3.fromRGB(150, 155, 165)
  sliderTrack.BorderSizePixel = 1
  sliderTrack.BorderColor3 = XP.borderDark
  sliderTrack.Parent = container

  local sliderFill = Instance.new("Frame")
  sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
  sliderFill.BackgroundColor3 = XP.accent
  sliderFill.BorderSizePixel = 0
  sliderFill.Parent = sliderTrack

  local knob = Instance.new("Frame")
  knob.Size = UDim2.new(0, 8, 0, 10)
  knob.Position = UDim2.new(0.5, -4, 0.5, -5)
  knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  knob.BorderSizePixel = 1
  knob.BorderColor3 = Color3.fromRGB(100, 100, 100)
  knob.Parent = sliderTrack

  local valLabel = Instance.new("TextLabel")
  valLabel.Size = UDim2.new(0.35, -6, 0, 14)
  valLabel.Position = UDim2.new(0.65, 0, 0, 2)
  valLabel.TextColor3 = XP.accent
  valLabel.BackgroundTransparency = 1
  valLabel.Font = Enum.Font.GothamBold
  valLabel.TextSize = 9
  valLabel.TextXAlignment = Enum.TextXAlignment.Right
  valLabel.Parent = container

  local function UpdateVisual(val)
    local pct = math.clamp((val - minVal) / (maxVal - minVal), 0, 1)
    sliderFill.Size = UDim2.new(pct, 0, 1, 0)
    knob.Position = UDim2.new(pct, -4, 0.5, -4)
    if isDecimal then
      valLabel.Text = string.format("%.2f", val)
    else
      valLabel.Text = tostring(math.floor(val))
    end
  end

  local currentVal = gameConfig[configKey] or minVal
  UpdateVisual(currentVal)

  local isDragging = false
  local connChange, connEnd

  local function ApplyInput(input)
    local mousePos = input.Position.X
    local trackPos = sliderTrack.AbsolutePosition.X
    local trackWidth = sliderTrack.AbsoluteSize.X
    if trackWidth <= 0 then return end

    local pct = math.clamp((mousePos - trackPos) / trackWidth, 0, 1)
    local val = minVal + (maxVal - minVal) * pct
    if not isDecimal then
      val = math.floor(val + 0.5)
    end
    gameConfig[configKey] = val
    UpdateVisual(val)
    if onChange then onChange(val) end
  end

  local function StartDrag(input)
    isDragging = true
    ApplyInput(input)

    if connChange then connChange:Disconnect() end
    if connEnd then connEnd:Disconnect() end

    connChange = UserInputService.InputChanged:Connect(function(moveInput)
      if isDragging and moveInput.UserInputType == Enum.UserInputType.MouseMovement then
        ApplyInput(moveInput)
      end
    end)

    connEnd = UserInputService.InputEnded:Connect(function(endInput)
      if endInput.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = false
        if connChange then
          connChange:Disconnect(); connChange = nil
        end
        if connEnd then
          connEnd:Disconnect(); connEnd = nil
        end
      end
    end)
  end

  sliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then StartDrag(input) end
  end)
  knob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then StartDrag(input) end
  end)
end

-- ==================== BUILD UI CONTENT ====================
BuildContent = function(container)
  if not contentContainerRef then return end

  local contentScroll = contentContainerRef:FindFirstChildOfClass("ScrollingFrame")
  if not contentScroll then return end

  for _, child in ipairs(contentScroll:GetChildren()) do
    if child:IsA("Frame") or child:IsA("UIListLayout") or child:IsA("UIPadding") then
      child:Destroy()
    end
  end

  -- ==================== MUSIC (LAST.FM) CUSTOM UI ====================
  if currentTab == "Music" then
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = contentScroll

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 4)
    listPad.Parent = contentScroll

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
      contentScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 18)
    end)

    local function Card(h, order, bg)
      local c = Instance.new("Frame")
      c.Size = UDim2.new(1, 0, 0, h)
      c.BackgroundColor3 = bg or XP.panel2
      c.BackgroundTransparency = 0
      c.BorderSizePixel = 1
      c.BorderColor3 = XP.borderDark
      c.LayoutOrder = order
      c.Parent = contentScroll
      return c
    end

    local function Lbl(parent, txt, font, size, color, x, y, w, h, trunc)
      local l = Instance.new("TextLabel")
      l.Size = UDim2.new(w or 1, -10, 0, h or 16)
      l.Position = UDim2.new(0, x or 8, 0, y or 0)
      l.Text = txt; l.Font = font; l.TextSize = size
      l.TextColor3 = color; l.BackgroundTransparency = 1
      l.TextXAlignment = Enum.TextXAlignment.Left
      if trunc then l.TextTruncate = Enum.TextTruncate.AtEnd end
      l.Parent = parent; return l
    end

    -- Card 1: Now Playing
    local npCard = Card(104, 1, Color3.fromRGB(12, 16, 24))
    npCard.BorderColor3 = Color3.fromRGB(30, 215, 96)

    local mCover = Instance.new("ImageLabel")
    mCover.Size = UDim2.new(0, 80, 0, 80)
    mCover.Position = UDim2.new(0, 12, 0, 12)
    mCover.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
    mCover.BorderSizePixel = 1
    mCover.BorderColor3 = Color3.fromRGB(30, 215, 96)
    mCover.ScaleType = Enum.ScaleType.Crop
    mCover.Image = Music.coverAsset
    mCover.Parent = npCard
    Music.menuCover = mCover

    local mIcon = Instance.new("TextLabel")
    mIcon.Size = UDim2.new(1, 0, 1, 0)
    mIcon.Text = "♪"
    mIcon.Font = Enum.Font.GothamBold
    mIcon.TextSize = 32
    mIcon.TextColor3 = Color3.fromRGB(40, 58, 80)
    mIcon.BackgroundTransparency = 1
    mIcon.TextXAlignment = Enum.TextXAlignment.Center
    mIcon.Visible = (Music.coverAsset == "")
    mIcon.Parent = mCover

    local TX = 104
    Lbl(npCard, "♪  Now Playing", Enum.Font.GothamBold, 11, Color3.fromRGB(30, 215, 96), TX, 10)

    local statusLbl2 = Lbl(npCard, Music.statusText, Enum.Font.Gotham, 9, XP.tabInactiveText, TX, 26, 1, 12, true)
    Music.menuStatusLbl = statusLbl2

    local songLbl2 = Lbl(npCard, Music.song ~= "" and Music.song or "No track playing",
      Enum.Font.GothamBold, 12, Color3.fromRGB(240, 248, 255), TX, 42, 1, 18, true)
    Music.menuSongLbl = songLbl2

    local artLbl2 = Lbl(npCard, Music.artist ~= "" and ("by " .. Music.artist) or "",
      Enum.Font.Gotham, 10, Color3.fromRGB(30, 215, 96), TX, 62, 1, 14, true)
    Music.menuArtLbl = artLbl2

    Lbl(npCard, Music.album ~= "" and ("💿 " .. Music.album) or "",
      Enum.Font.Gotham, 9, Color3.fromRGB(130, 160, 200), TX, 78, 1, 12, true)

    -- Card 2: Username Setup
    local setupCard = Card(100, 2)
    Lbl(setupCard, "Last.fm Username", Enum.Font.GothamBold, 11, XP.text, 10, 8)

    local userBox = Instance.new("TextBox")
    userBox.Size = UDim2.new(1, -20, 0, 28)
    userBox.Position = UDim2.new(0, 10, 0, 28)
    userBox.Text = Music.user
    userBox.PlaceholderText = "your_lastfm_username"
    userBox.TextColor3 = XP.text
    userBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 145)
    userBox.BackgroundColor3 = XP.panel1
    userBox.BorderSizePixel = 1; userBox.BorderColor3 = XP.borderDark
    userBox.Font = Enum.Font.Code; userBox.TextSize = 11
    userBox.TextXAlignment = Enum.TextXAlignment.Left
    userBox.ClearTextOnFocus = false
    userBox.Parent = setupCard

    local function ActionBtn(parent, lbl, x, y, w, clr, fn)
      local b = Instance.new("TextButton")
      b.Size = UDim2.new(0, w, 0, 26); b.Position = UDim2.new(0, x, 0, y)
      b.Text = lbl; b.Font = Enum.Font.GothamBold; b.TextSize = 10
      b.TextColor3 = Color3.fromRGB(255, 255, 255); b.BackgroundColor3 = clr
      b.BorderSizePixel = 1
      b.BorderColor3 = XP.borderDark
      b.Parent = parent
      b.MouseButton1Click:Connect(function() task.spawn(fn) end)
      return b
    end

    ActionBtn(setupCard, "⚡ Connect & Save", 10, 66, 145, Color3.fromRGB(22, 175, 76), function()
      Music.user = userBox.Text:gsub("%s+", ""):lower()
      userBox.Text = Music.user
      SaveSettings()
      StartLastfmPolling()
      LastfmPoll()
    end)

    ActionBtn(setupCard, "↺ Refresh", 162, 66, 90, XP.accent, function()
      Music.user = userBox.Text:gsub("%s+", ""):lower()
      LastfmPoll()
    end)

    local iconCard = Card(100, 3)
    Lbl(iconCard, "Peer Icon (rbxassetid://...)", Enum.Font.GothamBold, 11, XP.text, 10, 8)

    local iconBox = Instance.new("TextBox")
    iconBox.Size = UDim2.new(1, -20, 0, 28)
    iconBox.Position = UDim2.new(0, 10, 0, 28)
    iconBox.Text = Music.peerIcon or "rbxassetid://6274377121"
    iconBox.PlaceholderText = "rbxassetid://6274377121"
    iconBox.TextColor3 = XP.text
    iconBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 145)
    iconBox.BackgroundColor3 = XP.panel1
    iconBox.BorderSizePixel = 1; iconBox.BorderColor3 = XP.borderDark
    iconBox.Font = Enum.Font.Code; iconBox.TextSize = 11
    iconBox.TextXAlignment = Enum.TextXAlignment.Left
    iconBox.ClearTextOnFocus = false
    iconBox.Parent = iconCard

    ActionBtn(iconCard, "💾 Save Icon", 10, 66, 130, Color3.fromRGB(22, 175, 76), function()
      local raw = iconBox.Text:gsub("%s+", "")
      if raw == "" then raw = "rbxassetid://6274377121" end
      Music.peerIcon = raw
      iconBox.Text = raw
      SaveSettings()
      BroadcastPeerData()
    end)

    ActionBtn(iconCard, "↺ Reset", 150, 66, 100, XP.accent, function()
      iconBox.Text = "rbxassetid://6274377121"
      Music.peerIcon = "rbxassetid://6274377121"
      SaveSettings()
      BroadcastPeerData()
    end)

    -- Card 4: Quick Guide
    local guideCard = Card(112, 4)
    local steps = {
      { "♪ Link Spotify → Last.fm (free, 30 sec):", true },
      { "1. Create a free account at last.fm", false },
      { "2. Go to last.fm/settings/applications", false },
      { "3. Click Connect next to Spotify Scrobbling", false },
      { "4. Enter your username above & click Connect", false },
      { "Any Spotify track will now appear live on your HUD!", false },
    }
    for i, s in ipairs(steps) do
      Lbl(guideCard, s[1],
        s[2] and Enum.Font.GothamBold or Enum.Font.Gotham,
        s[2] and 10 or 9,
        s[2] and Color3.fromRGB(30, 215, 96) or XP.text,
        10, 4 + (i - 1) * 18, 1, 14, true)
    end

    UpdateMusicUI()
    return
  end

  -- ==================== KEYBINDS TAB ====================
  if currentTab == "Keybinds" then
    local kbContainer = Instance.new("Frame")
    kbContainer.Name = "KeybindContainer"
    kbContainer.Size = UDim2.new(1, 0, 0, 0)
    kbContainer.BackgroundTransparency = 1
    kbContainer.BorderSizePixel = 0
    kbContainer.LayoutOrder = 0
    kbContainer.Parent = contentScroll

    local kbLayout = Instance.new("UIListLayout")
    kbLayout.FillDirection = Enum.FillDirection.Vertical
    kbLayout.SortOrder = Enum.SortOrder.LayoutOrder
    kbLayout.Padding = UDim.new(0, 6)
    kbLayout.Parent = kbContainer

    local function updateCanvas()
      kbContainer.Size = UDim2.new(1, 0, 0, kbLayout.AbsoluteContentSize.Y)
      contentScroll.CanvasSize = UDim2.new(0, 0, 0, kbLayout.AbsoluteContentSize.Y + 16)
    end
    kbLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

    -- Gather all toggle features grouped by tab/section
    local grouped = {}
    for tabName, tabFeats in pairs(features) do
      local sectionName = "General"
      local toggles = {}
      for _, feat in ipairs(tabFeats) do
        if feat.isSection then sectionName = feat.name end
        if feat.isToggle and feat.toggle then
          table.insert(toggles, { section = sectionName, feat = feat })
        end
      end
      if #toggles > 0 then
        grouped[tabName] = toggles
      end
    end

    local sortedTabs = {}
    for tabName, _ in pairs(grouped) do
      table.insert(sortedTabs, tabName)
    end
    table.sort(sortedTabs)

    local function getKbName(tabName, featName)
      return tabName .. "::" .. featName
    end

    -- Register all toggle features into the keybind registry
    for tabName, toggles in pairs(grouped) do
      for _, entry in ipairs(toggles) do
        local kbName = getKbName(tabName, entry.feat.name)
        if not keybindRegistry[kbName] then
          keybindRegistry[kbName] = {
            get = entry.feat.get,
            toggle = entry.feat.toggle,
            tab = tabName,
            featName = entry.feat.name,
          }
        end
      end
    end
    RebuildKeybindMap()

    local function keyCodeName(kc)
      if not kc then return "None" end
      local n = tostring(kc.Name or kc)
      if n:match("^Enum.KeyCode%.") then n = n:sub(17) end
      return n
    end

    local ROW_H = 36
    local CTRL_H = 22
    local CTRL_GAP = 4
    local STATE_W = 34
    local KEY_W = 50
    local SET_W = 42
    local CLR_W = 54
    local CTRLS_TOTAL = CTRL_GAP + CLR_W + CTRL_GAP + SET_W + CTRL_GAP + KEY_W + CTRL_GAP + STATE_W

    local layoutOrder = 0

    local function makeKeybindRow(entry, tabName)
      local kbName = getKbName(tabName, entry.feat.name)

      local row = Instance.new("Frame")
      row.Name = "KbRow_" .. entry.feat.name
      row.Size = UDim2.new(1, 0, 0, 36)
      row.BackgroundColor3 = XP.rowBg
      row.BackgroundTransparency = 0.35
      row.BorderSizePixel = 0
      row.LayoutOrder = layoutOrder
      layoutOrder = layoutOrder + 1
      row.Parent = kbContainer

      local nameLbl = Instance.new("TextLabel")
      nameLbl.Size = UDim2.new(1, -120, 1, 0)
      nameLbl.Position = UDim2.new(0, 10, 0, 0)
      nameLbl.Text = entry.feat.name
      nameLbl.TextColor3 = XP.text
      nameLbl.BackgroundTransparency = 1
      nameLbl.Font = Enum.Font.Gotham
      nameLbl.TextSize = 11
      nameLbl.TextXAlignment = Enum.TextXAlignment.Left
      nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
      nameLbl.Parent = row

      local keyLbl = Instance.new("TextLabel")
      keyLbl.Name = "KeyLabel"
      keyLbl.Size = UDim2.new(0, 70, 0, 22)
      keyLbl.Position = UDim2.new(1, -102, 0.5, -11)
      keyLbl.Text = keyCodeName(keybinds[kbName])
      keyLbl.TextColor3 = keybinds[kbName] and XP.accent or Color3.fromRGB(150, 150, 150)
      keyLbl.BackgroundColor3 = XP.panel1
      keyLbl.BackgroundTransparency = 0.2
      keyLbl.BorderSizePixel = 1
      keyLbl.BorderColor3 = XP.borderDark
      keyLbl.Font = Enum.Font.Code
      keyLbl.TextSize = 10
      keyLbl.TextXAlignment = Enum.TextXAlignment.Center
      keyLbl.Parent = row

      local setBtn = Instance.new("TextButton")
      setBtn.Size = UDim2.new(0, 36, 0, 22)
      setBtn.Position = UDim2.new(1, -36, 0.5, -11)
      setBtn.Text = "Set"
      setBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
      setBtn.BackgroundColor3 = XP.titleBar
      setBtn.BorderSizePixel = 1
      setBtn.BorderColor3 = XP.borderDark
      setBtn.Font = Enum.Font.GothamBold
      setBtn.TextSize = 9
      setBtn.Parent = row

      local setGrad = Instance.new("UIGradient")
      setGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
        ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
      })
      setGrad.Parent = setBtn

      local clrBtn = Instance.new("TextButton")
      clrBtn.Size = UDim2.new(0, 36, 0, 22)
      clrBtn.Position = UDim2.new(1, -74, 0.5, -11)
      clrBtn.Text = "Clr"
      clrBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
      clrBtn.BackgroundColor3 = Color3.fromRGB(140, 45, 45)
      clrBtn.BorderSizePixel = 1
      clrBtn.BorderColor3 = XP.borderDark
      clrBtn.Font = Enum.Font.GothamBold
      clrBtn.TextSize = 9
      clrBtn.Parent = row

      clrBtn.MouseButton1Click:Connect(function()
        keybinds[kbName] = nil
        keyLbl.Text = "None"
        keyLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        RebuildKeybindMap()
        SaveKeybinds()
      end)

      setBtn.MouseButton1Click:Connect(function()
        setBtn.Text = "[..]"
        local capturing = true
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
          if not capturing then return end
          capturing = false
          if conn then conn:Disconnect() end
          if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode ~= Enum.KeyCode.Escape then
            if keybinds[kbName] then
              activeKeybindMap[keybinds[kbName]] = nil
            end
            keybinds[kbName] = input.KeyCode
            keyLbl.Text = keyCodeName(input.KeyCode)
            keyLbl.TextColor3 = XP.accent
            RebuildKeybindMap()
            SaveKeybinds()
          end
          setBtn.Text = "Set"
        end)
        task.delay(3, function()
          if capturing then
            capturing = false
            if conn then conn:Disconnect() end
            setBtn.Text = "Set"
          end
        end)
      end)
    end

    for _, tabName in ipairs(sortedTabs) do
      local sectionHeader = Instance.new("Frame")
      sectionHeader.Name = "Section_" .. tabName
      sectionHeader.Size = UDim2.new(1, 0, 0, 26)
      sectionHeader.BackgroundColor3 = XP.titleBar
      sectionHeader.BackgroundTransparency = 0.15
      sectionHeader.BorderSizePixel = 1
      sectionHeader.BorderColor3 = XP.borderDark
      sectionHeader.LayoutOrder = layoutOrder
      layoutOrder = layoutOrder + 1
      sectionHeader.Parent = kbContainer

      local shGrad = Instance.new("UIGradient")
      shGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
        ColorSequenceKeypoint.new(0.5, XP.titleBarGrad2),
        ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
      })
      shGrad.Rotation = 90
      shGrad.Parent = sectionHeader

      local shLabel = Instance.new("TextLabel")
      shLabel.Size = UDim2.new(1, -10, 1, 0)
      shLabel.Position = UDim2.new(0, 8, 0, 0)
      shLabel.Text = string.upper(tabName)
      shLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
      shLabel.BackgroundTransparency = 1
      shLabel.TextXAlignment = Enum.TextXAlignment.Left
      shLabel.Font = Enum.Font.GothamBold
      shLabel.TextSize = 11
      shLabel.Parent = sectionHeader

      for _, entry in ipairs(grouped[tabName]) do
        makeKeybindRow(entry, tabName)
      end
    end

    return
  end

  -- ==================== 4-QUADRANT DUAL-COLUMN CARD GRID ====================
  local leftCol = Instance.new("Frame")
  leftCol.Name = "LeftColumn"
  leftCol.Size = UDim2.new(0.49, 0, 1, 0)
  leftCol.Position = UDim2.new(0, 0, 0, 0)
  leftCol.BackgroundTransparency = 1
  leftCol.BorderSizePixel = 0
  leftCol.Parent = contentScroll

  local rightCol = Instance.new("Frame")
  rightCol.Name = "RightColumn"
  rightCol.Size = UDim2.new(0.49, 0, 1, 0)
  rightCol.Position = UDim2.new(0.51, 0, 0, 0)
  rightCol.BackgroundTransparency = 1
  rightCol.BorderSizePixel = 0
  rightCol.Parent = contentScroll

  local leftLayout = Instance.new("UIListLayout")
  leftLayout.FillDirection = Enum.FillDirection.Vertical
  leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
  leftLayout.Padding = UDim.new(0, 6)
  leftLayout.Parent = leftCol

  local rightLayout = Instance.new("UIListLayout")
  rightLayout.FillDirection = Enum.FillDirection.Vertical
  rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
  rightLayout.Padding = UDim.new(0, 6)
  rightLayout.Parent = rightCol

  local function UpdateCanvas()
    local maxH = math.max(leftLayout.AbsoluteContentSize.Y, rightLayout.AbsoluteContentSize.Y)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, maxH + 16)
  end

  leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
  rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)

  -- Fully Opaque Trolling Player Dropdown Card
  if currentTab == "Trolling" then
    local dropCard = Instance.new("Frame")
    dropCard.Size = UDim2.new(1, 0, 0, 56)
    dropCard.BackgroundColor3 = XP.panel2
    dropCard.BorderSizePixel = 1
    dropCard.BorderColor3 = XP.borderDark
    dropCard.LayoutOrder = 0
    dropCard.ZIndex = 5
    dropCard.Parent = leftCol

    local dropHead = Instance.new("Frame")
    dropHead.Size = UDim2.new(1, 0, 0, 20)
    dropHead.BackgroundColor3 = XP.titleBar
    dropHead.BorderSizePixel = 0
    dropHead.ZIndex = 5
    dropHead.Parent = dropCard

    local dropHeadGrad = Instance.new("UIGradient")
    dropHeadGrad.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
      ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
    })
    dropHeadGrad.Parent = dropHead

    local dropLabel = Instance.new("TextLabel")
    dropLabel.Size = UDim2.new(1, -8, 1, 0)
    dropLabel.Position = UDim2.new(0, 6, 0, 0)
    dropLabel.Text = "TARGET PLAYER SELECTION"
    dropLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropLabel.BackgroundTransparency = 1
    dropLabel.TextXAlignment = Enum.TextXAlignment.Left
    dropLabel.Font = Enum.Font.GothamBold
    dropLabel.TextSize = 8
    dropLabel.ZIndex = 5
    dropLabel.Parent = dropHead

    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(1, -12, 0, 24)
    dropdown.Position = UDim2.new(0, 6, 0, 24)
    dropdown.Text = selectedPlayer and (selectedPlayer.DisplayName .. " (@" .. selectedPlayer.Name .. ")") or
        "Select Target Player..."
    dropdown.TextColor3 = XP.text
    dropdown.BackgroundColor3 = XP.panel1
    dropdown.BackgroundTransparency = 0
    dropdown.BorderSizePixel = 1
    dropdown.BorderColor3 = XP.borderDark
    dropdown.Font = Enum.Font.Gotham
    dropdown.TextSize = 10
    dropdown.TextXAlignment = Enum.TextXAlignment.Left
    dropdown.ZIndex = 6
    dropdown.Parent = dropCard

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 16, 1, 0)
    arrow.Position = UDim2.new(1, -18, 0, 0)
    arrow.Text = "v"
    arrow.TextColor3 = XP.text
    arrow.BackgroundTransparency = 1
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 9
    arrow.ZIndex = 6
    arrow.Parent = dropdown

    local dropdownOpen = false
    local dropdownMenu = nil

    dropdown.MouseButton1Click:Connect(function()
      dropdownOpen = not dropdownOpen
      if dropdownOpen then
        if dropdownMenu then dropdownMenu:Destroy() end
        dropdownMenu = Instance.new("Frame")
        dropdownMenu.Size = UDim2.new(1, -12, 0, math.min(#playerList * 22 + 4, 140))
        dropdownMenu.Position = UDim2.new(0, 6, 0, 50)
        dropdownMenu.BackgroundColor3 = XP.panel1
        dropdownMenu.BackgroundTransparency = 0
        dropdownMenu.BorderSizePixel = 1
        dropdownMenu.BorderColor3 = XP.accent
        dropdownMenu.Parent = dropCard
        dropdownMenu.ZIndex = 30

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -4, 1, -4)
        scroll.Position = UDim2.new(0, 2, 0, 2)
        scroll.BackgroundTransparency = 1
        scroll.ScrollBarThickness = 0
        scroll.CanvasSize = UDim2.new(0, 0, 0, #playerList * 22)
        scroll.Parent = dropdownMenu
        scroll.ZIndex = 31

        local scrollLayout = Instance.new("UIListLayout")
        scrollLayout.Padding = UDim.new(0, 1)
        scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
        scrollLayout.Parent = scroll

        for _, plr in ipairs(playerList) do
          local opt = Instance.new("TextButton")
          opt.Size = UDim2.new(1, 0, 0, 20)
          opt.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
          opt.TextColor3 = XP.text
          opt.BackgroundColor3 = XP.panel2
          opt.BackgroundTransparency = 0
          opt.BorderSizePixel = 0
          opt.Font = Enum.Font.Gotham
          opt.TextSize = 9
          opt.TextXAlignment = Enum.TextXAlignment.Left
          opt.Parent = scroll
          opt.ZIndex = 32

          opt.MouseEnter:Connect(function()
            Animate(opt, { BackgroundColor3 = XP.accent, TextColor3 = Color3.fromRGB(255, 255, 255) }, 0.1)
          end)
          opt.MouseLeave:Connect(function()
            Animate(opt, { BackgroundColor3 = XP.panel2, TextColor3 = XP.text }, 0.1)
          end)

          opt.MouseButton1Click:Connect(function()
            selectedPlayer = plr
            dropdown.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
            dropdownOpen = false
            if dropdownMenu then
              dropdownMenu:Destroy(); dropdownMenu = nil
            end
          end)
        end
      else
        if dropdownMenu then
          dropdownMenu:Destroy(); dropdownMenu = nil
        end
      end
    end)
  end

  -- Group items by Section
  local tabFeatures = features[currentTab] or {}
  local sections = {}
  local currentSec = { name = "General", items = {} }
  table.insert(sections, currentSec)

  for _, feat in ipairs(tabFeatures) do
    if feat.isSection then
      currentSec = { name = feat.name, items = {} }
      table.insert(sections, currentSec)
    else
      table.insert(currentSec.items, feat)
    end
  end

  local validSections = {}
  for _, s in ipairs(sections) do
    if #s.items > 0 then table.insert(validSections, s) end
  end

  -- Render sections into Quadrant Cards (Left / Right columns)
  for secIdx, sec in ipairs(validSections) do
    local targetCol = (secIdx % 2 == 1) and leftCol or rightCol

    local card = Instance.new("Frame")
    card.Name = "Quadrant_" .. secIdx
    card.Size = UDim2.new(1, 0, 0, 0)
    card.BackgroundColor3 = XP.panel2
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 1
    card.BorderColor3 = XP.borderDark
    card.LayoutOrder = secIdx
    card.Parent = targetCol

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.FillDirection = Enum.FillDirection.Vertical
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Padding = UDim.new(0, 2)
    cardLayout.Parent = card

    local cardHead = Instance.new("Frame")
    cardHead.Size = UDim2.new(1, 0, 0, 20)
    cardHead.BackgroundColor3 = XP.titleBar
    cardHead.BorderSizePixel = 0
    cardHead.LayoutOrder = 0
    cardHead.Parent = card

    local chGrad = Instance.new("UIGradient")
    chGrad.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
      ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
    })
    chGrad.Parent = cardHead

    local chLabel = Instance.new("TextLabel")
    chLabel.Size = UDim2.new(1, -8, 1, 0)
    chLabel.Position = UDim2.new(0, 6, 0, 0)
    chLabel.Text = string.upper(sec.name)
    chLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    chLabel.BackgroundTransparency = 1
    chLabel.TextXAlignment = Enum.TextXAlignment.Left
    chLabel.Font = Enum.Font.GothamBold
    chLabel.TextSize = 8
    chLabel.Parent = cardHead

    for itemIdx, feat in ipairs(sec.items) do
      if feat.hasSlider then
        local sRow = Instance.new("Frame")
        sRow.Size = UDim2.new(1, 0, 0, 28)
        sRow.BackgroundColor3 = XP.rowBg
        sRow.BackgroundTransparency = 0.4
        sRow.BorderSizePixel = 0
        sRow.LayoutOrder = itemIdx
        sRow.Parent = card

        local sLbl = Instance.new("TextLabel")
        sLbl.Size = UDim2.new(0.65, -6, 0, 14)
        sLbl.Position = UDim2.new(0, 6, 0, 1)
        sLbl.Text = feat.name
        sLbl.TextColor3 = XP.text
        sLbl.BackgroundTransparency = 1
        sLbl.Font = Enum.Font.GothamBold
        sLbl.TextSize = 9
        sLbl.TextXAlignment = Enum.TextXAlignment.Left
        sLbl.TextTruncate = Enum.TextTruncate.AtEnd
        sLbl.Parent = sRow

        CreateSlider(sRow, feat.configKey, feat.min, feat.max, feat.isDecimal, function(val)
          if feat.onChange then feat.onChange(val) end
        end)
      else
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundColor3 = XP.rowBg
        row.BackgroundTransparency = 0.4
        row.BorderSizePixel = 0
        row.LayoutOrder = itemIdx
        row.Parent = card

        local rLbl = Instance.new("TextLabel")
        rLbl.Size = UDim2.new(1, -54, 1, 0)
        rLbl.Position = UDim2.new(0, 6, 0, 0)
        rLbl.Text = feat.name
        rLbl.TextColor3 = XP.text
        rLbl.BackgroundTransparency = 1
        rLbl.Font = Enum.Font.GothamBold
        rLbl.TextSize = 9
        rLbl.TextXAlignment = Enum.TextXAlignment.Left
        rLbl.TextTruncate = Enum.TextTruncate.AtEnd
        rLbl.Parent = row

        if feat.isToggle then
          local tBtn = Instance.new("TextButton")
          tBtn.Size = UDim2.new(0, 42, 0, 16)
          tBtn.Position = UDim2.new(1, -48, 0.5, -8)
          local activeState = feat.get and feat.get() or false
          tBtn.Text = activeState and "ON" or "OFF"
          tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
          tBtn.BackgroundColor3 = activeState and XP.green or Color3.fromRGB(150, 150, 150)
          tBtn.BorderSizePixel = 1
          tBtn.BorderColor3 = XP.borderDark
          tBtn.Font = Enum.Font.GothamBold
          tBtn.TextSize = 8
          tBtn.Parent = row

          tBtn.MouseButton1Click:Connect(function()
            local newState = not (feat.get and feat.get() or false)
            tBtn.Text = newState and "ON" or "OFF"
            tBtn.BackgroundColor3 = newState and XP.green or Color3.fromRGB(150, 150, 150)
            if feat.toggle then feat.toggle(newState) end
          end)
        elseif feat.isButton then
          local bBtn = Instance.new("TextButton")
          bBtn.Size = UDim2.new(0, 42, 0, 16)
          bBtn.Position = UDim2.new(1, -48, 0.5, -8)
          bBtn.Text = feat.buttonText or "RUN"
          bBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
          bBtn.BackgroundColor3 = XP.accent
          bBtn.BorderSizePixel = 1
          bBtn.BorderColor3 = XP.borderDark
          bBtn.Font = Enum.Font.GothamBold
          bBtn.TextSize = 8
          bBtn.Parent = row

          bBtn.MouseButton1Click:Connect(function()
            if feat.condition and not feat.condition() then return end
            if feat.action then feat.action() end
          end)
        elseif feat.isCyclePart then
          local partOptions = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" }
          local currentPart = S.aimbotTargetPart or "Head"
          local currentIndex = table.find(partOptions, currentPart) or 1

          local leftBtn = Instance.new("TextButton")
          leftBtn.Size = UDim2.new(0, 20, 0, 16)
          leftBtn.Position = UDim2.new(1, -100, 0.5, -8)
          leftBtn.Text = "<"
          leftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
          leftBtn.BackgroundColor3 = XP.accent
          leftBtn.BorderSizePixel = 1
          leftBtn.BorderColor3 = XP.borderDark
          leftBtn.Font = Enum.Font.GothamBold
          leftBtn.TextSize = 8
          leftBtn.Parent = row

          local partLabel = Instance.new("TextLabel")
          partLabel.Size = UDim2.new(0, 60, 0, 16)
          partLabel.Position = UDim2.new(1, -80, 0.5, -8)
          partLabel.Text = currentPart
          partLabel.TextColor3 = XP.text
          partLabel.BackgroundTransparency = 1
          partLabel.Font = Enum.Font.GothamBold
          partLabel.TextSize = 8
          partLabel.TextXAlignment = Enum.TextXAlignment.Center
          partLabel.Parent = row

          local rightBtn = Instance.new("TextButton")
          rightBtn.Size = UDim2.new(0, 20, 0, 16)
          rightBtn.Position = UDim2.new(1, -20, 0.5, -8)
          rightBtn.Text = ">"
          rightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
          rightBtn.BackgroundColor3 = XP.accent
          rightBtn.BorderSizePixel = 1
          rightBtn.BorderColor3 = XP.borderDark
          rightBtn.Font = Enum.Font.GothamBold
          rightBtn.TextSize = 8
          rightBtn.Parent = row

          local function updatePartLabel()
            currentPart = S.aimbotTargetPart or "Head"
            partLabel.Text = currentPart
          end

          leftBtn.MouseButton1Click:Connect(function()
            currentIndex = currentIndex - 1
            if currentIndex < 1 then currentIndex = #partOptions end
            S.aimbotTargetPart = partOptions[currentIndex]
            updatePartLabel()
          end)

          rightBtn.MouseButton1Click:Connect(function()
            currentIndex = currentIndex + 1
            if currentIndex > #partOptions then currentIndex = 1 end
            S.aimbotTargetPart = partOptions[currentIndex]
            updatePartLabel()
          end)
        end
      end
    end

    cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
      card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 4)
    end)
    card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 4)
  end
end

-- ==================== BUILD MAIN GUI ====================
BuildGUI = function()
  for _, g in ipairs(PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name == "CheatMenu" then
      g:Destroy()
    end
  end

  gui = Instance.new("ScreenGui")
  gui.Name = "CheatMenu"
  gui.ResetOnSpawn = false
  gui.Parent = PlayerGui
  gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

  local frame = Instance.new("Frame")
  frame.Size = UDim2.new(0, 640, 0, 520)
  frame.Position = UDim2.new(0.5, -320, 0.5, -260)
  frame.BackgroundColor3 = XP.windowBg
  frame.BackgroundTransparency = 0.15
  frame.BorderSizePixel = 1
  frame.BorderColor3 = XP.borderLight
  frame.Parent = gui

  local winGrad = Instance.new("UIGradient")
  winGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.windowBgLight),
    ColorSequenceKeypoint.new(0.4, XP.windowBg),
    ColorSequenceKeypoint.new(1, XP.windowBgDark)
  })
  winGrad.Rotation = 90
  winGrad.Parent = frame

  local innerBorder = Instance.new("Frame")
  innerBorder.Size = UDim2.new(1, -4, 1, -4)
  innerBorder.Position = UDim2.new(0, 2, 0, 2)
  innerBorder.BackgroundTransparency = 1
  innerBorder.BorderSizePixel = 1
  innerBorder.BorderColor3 = Color3.fromRGB(168, 194, 223)
  innerBorder.Parent = frame

  local titleBar = Instance.new("Frame")
  titleBar.Size = UDim2.new(1, 0, 0, 32)
  titleBar.BackgroundColor3 = XP.titleBar
  titleBar.BackgroundTransparency = 0.1
  titleBar.BorderSizePixel = 0
  titleBar.Parent = frame

  local tbGrad = Instance.new("UIGradient")
  tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
    ColorSequenceKeypoint.new(0.5, XP.titleBarGrad2),
    ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
  })
  tbGrad.Rotation = 90
  tbGrad.Parent = titleBar

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(0.7, 0, 1, 0)
  title.Position = UDim2.new(0, 10, 0, 0)
  title.Text = "Universal Cheat Panel v10 • [" .. currentThemeName .. "]"
  title.TextColor3 = Color3.fromRGB(255, 255, 255)
  title.BackgroundTransparency = 1
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Font = Enum.Font.GothamBold
  title.TextSize = 12
  title.Parent = titleBar

  local closeBtn = Instance.new("TextButton")
  closeBtn.Size = UDim2.new(0, 22, 0, 22)
  closeBtn.Position = UDim2.new(1, -30, 0.5, -11)
  closeBtn.Text = "X"
  closeBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
  closeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  closeBtn.BackgroundTransparency = 0.9
  closeBtn.BorderSizePixel = 1
  closeBtn.BorderColor3 = Color3.fromRGB(160, 160, 160)
  closeBtn.Font = Enum.Font.GothamBold
  closeBtn.TextSize = 11
  closeBtn.Parent = titleBar

  closeBtn.MouseEnter:Connect(function()
    Animate(closeBtn, { BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(200, 50, 50) }, 0.1)
  end)
  closeBtn.MouseLeave:Connect(function()
    Animate(closeBtn, { BackgroundTransparency = 0.9, BackgroundColor3 = Color3.fromRGB(255, 255, 255) }, 0.1)
  end)
  closeBtn.MouseButton1Click:Connect(function()
    isOpen = false
    if gui then
      gui:Destroy(); gui = nil
    end
  end)

  -- High-Visibility Sidebar
  local sidebar = Instance.new("Frame")
  sidebar.Size = UDim2.new(0, 125, 1, -32)
  sidebar.Position = UDim2.new(0, 0, 0, 32)
  sidebar.BackgroundColor3 = XP.sidebar1
  sidebar.BackgroundTransparency = 0
  sidebar.BorderSizePixel = 0
  sidebar.Parent = frame

  local sideGrad = Instance.new("UIGradient")
  sideGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.sidebar1),
    ColorSequenceKeypoint.new(1, XP.sidebar2)
  })
  sideGrad.Rotation = 90
  sideGrad.Parent = sidebar

  local sidebarLayout = Instance.new("UIListLayout")
  sidebarLayout.FillDirection = Enum.FillDirection.Vertical
  sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
  sidebarLayout.Padding = UDim.new(0, 3)
  sidebarLayout.Parent = sidebar

  local sidebarPadding = Instance.new("UIPadding")
  sidebarPadding.PaddingTop = UDim.new(0, 4)
  sidebarPadding.PaddingLeft = UDim.new(0, 4)
  sidebarPadding.PaddingRight = UDim.new(0, 4)
  sidebarPadding.Parent = sidebar

  local sidebarItems = {
    { isHeader = true, name = "MAIN GAMEPLAY" },
    { tab = "Combat" },
    { tab = "Movement" },
    { tab = "Visuals" },

    { isHeader = true, name = "GAME & EXPLOITS" },
    { tab = "MM2" },
    { tab = "Trolling" },

    { isHeader = true, name = "SYSTEM & UTILS" },
    { tab = "Server" },
    { tab = "Themes" },
    { tab = "Config" },
    { tab = "HUD" },
    { tab = "Keybinds" },
    { tab = "Music" }
  }
  local tabButtons = {}

  for i, item in ipairs(sidebarItems) do
    if item.isHeader then
      -- Taller container: spacing + separator line + label
      local groupH = i == 1 and 18 or 24
      local divContainer = Instance.new("Frame")
      divContainer.Size = UDim2.new(1, 0, 0, groupH)
      divContainer.BackgroundTransparency = 1
      divContainer.BorderSizePixel = 0
      divContainer.LayoutOrder = i
      divContainer.Parent = sidebar

      -- Full-width horizontal rule above every group except the first
      if i > 1 then
        local divLine = Instance.new("Frame")
        divLine.Size = UDim2.new(1, 4, 0, 1) -- bleed past padding
        divLine.Position = UDim2.new(0, -4, 0, 3)
        divLine.BackgroundColor3 = XP.borderDark
        divLine.BackgroundTransparency = 0.3
        divLine.BorderSizePixel = 0
        divLine.Parent = divContainer
      end

      -- 3px left accent rail (full height of container)
      local accentRail = Instance.new("Frame")
      accentRail.Size = UDim2.new(0, 3, 1, 0)
      accentRail.Position = UDim2.new(0, -4, 0, 0) -- flush with sidebar left edge
      accentRail.BackgroundColor3 = XP.accent
      accentRail.BackgroundTransparency = 0.25
      accentRail.BorderSizePixel = 0
      accentRail.Parent = divContainer

      -- Category label (small-caps style)
      local divLabel = Instance.new("TextLabel")
      divLabel.Size = UDim2.new(1, -6, 1, 0)
      divLabel.Position = UDim2.new(0, 4, 0, i == 1 and 3 or 8)
      divLabel.Text = item.name
      divLabel.TextColor3 = XP.accent
      divLabel.BackgroundTransparency = 1
      divLabel.TextXAlignment = Enum.TextXAlignment.Left
      divLabel.Font = Enum.Font.GothamBold
      divLabel.TextSize = 7
      divLabel.Parent = divContainer
    else
      local tabName = item.tab
      local isSelected = (tabName == currentTab)

      local btn = Instance.new("TextButton")
      btn.Size = UDim2.new(1, 0, 0, 25)
      btn.Text = "  " .. tabName
      btn.TextColor3 = isSelected and XP.tabActiveText or XP.tabInactiveText
      btn.BackgroundColor3 = isSelected and XP.tabActive or XP.tabInactive
      btn.BackgroundTransparency = isSelected and 0 or 0.2
      btn.BorderSizePixel = 1
      btn.BorderColor3 = isSelected and XP.accent or XP.borderDark
      btn.Font = Enum.Font.GothamBold
      btn.TextSize = 10
      btn.TextXAlignment = Enum.TextXAlignment.Left
      btn.LayoutOrder = i
      btn.Parent = sidebar
      tabButtons[tabName] = btn

      local activeBar = Instance.new("Frame")
      activeBar.Name = "ActiveBar"
      activeBar.Size = UDim2.new(0, 4, 1, 0)
      activeBar.Position = UDim2.new(0, 0, 0, 0)
      activeBar.BackgroundColor3 = XP.accent
      activeBar.BorderSizePixel = 0
      activeBar.Visible = isSelected
      activeBar.Parent = btn

      btn.MouseEnter:Connect(function()
        if currentTab ~= tabName then
          Animate(btn, { BackgroundTransparency = 0.05, BackgroundColor3 = Color3.fromRGB(245, 240, 230) }, 0.1)
        end
      end)
      btn.MouseLeave:Connect(function()
        if currentTab ~= tabName then
          Animate(btn, { BackgroundTransparency = 0.2, BackgroundColor3 = XP.tabInactive }, 0.1)
        end
      end)

      btn.MouseButton1Click:Connect(function()
        if tabName == currentTab or isTransitioning then return end
        isTransitioning = true

        for name, b in pairs(tabButtons) do
          local sel = (name == tabName)
          b.TextColor3 = sel and XP.tabActiveText or XP.tabInactiveText
          b.BackgroundColor3 = sel and XP.tabActive or XP.tabInactive
          b.BackgroundTransparency = sel and 0 or 0.2
          b.BorderColor3 = sel and XP.accent or XP.borderDark
          local ab = b:FindFirstChild("ActiveBar")
          if ab then ab.Visible = sel end
        end

        currentTab = tabName
        BuildContent(contentContainerRef)
        isTransitioning = false
      end)
    end
  end

  local contentPanel = Instance.new("Frame")
  contentPanel.Size = UDim2.new(1, -135, 1, -40)
  contentPanel.Position = UDim2.new(0, 130, 0, 36)
  contentPanel.BackgroundColor3 = XP.panel1
  contentPanel.BackgroundTransparency = 0.2
  contentPanel.BorderSizePixel = 1
  contentPanel.BorderColor3 = XP.borderDark
  contentPanel.Parent = frame

  local cGrad = Instance.new("UIGradient")
  cGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.panel1),
    ColorSequenceKeypoint.new(1, XP.panel2)
  })
  cGrad.Rotation = 90
  cGrad.Parent = contentPanel

  contentContainerRef = Instance.new("Frame")
  contentContainerRef.Size = UDim2.new(1, -8, 1, -8)
  contentContainerRef.Position = UDim2.new(0, 4, 0, 4)
  contentContainerRef.BackgroundTransparency = 1
  contentContainerRef.BorderSizePixel = 0
  contentContainerRef.Parent = contentPanel

  local contentScroll = Instance.new("ScrollingFrame")
  contentScroll.Size = UDim2.new(1, 0, 1, 0)
  contentScroll.BackgroundTransparency = 1
  contentScroll.ScrollBarThickness = 0
  contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
  contentScroll.Parent = contentContainerRef

  local layout = Instance.new("UIListLayout")
  layout.Padding = UDim.new(0, 4)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = contentScroll

  BuildContent(contentContainerRef)

  -- Window Dragging Logic
  local dragging, dragStart, startPos
  titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = true
      dragStart = input.Position
      startPos = frame.Position

      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
          dragging = false
        end
      end)
    end
  end)

  titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
      local delta = input.Position - dragStart
      frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale,
        startPos.Y.Offset + delta.Y)
    end
  end)

  -- ==================== INTERACTIVE RESIZE HANDLE ====================
  local resizeHandle = Instance.new("TextButton")
  resizeHandle.Name = "ResizeHandle"
  resizeHandle.Size = UDim2.new(0, 18, 0, 18)
  resizeHandle.Position = UDim2.new(1, -18, 1, -18)
  resizeHandle.BackgroundTransparency = 1
  resizeHandle.Text = "///"
  resizeHandle.TextColor3 = XP.borderDark
  resizeHandle.Font = Enum.Font.GothamBold
  resizeHandle.TextSize = 10
  resizeHandle.ZIndex = 50
  resizeHandle.Parent = frame

  local resizing, resizeStartPos, startSize
  resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      resizing = true
      resizeStartPos = input.Position
      startSize = frame.AbsoluteSize

      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
          resizing = false
        end
      end)
    end
  end)

  UserInputService.InputChanged:Connect(function(input)
    if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
      local delta = input.Position - resizeStartPos
      local newWidth = math.clamp(startSize.X + delta.X, 420, 900)
      local newHeight = math.clamp(startSize.Y + delta.Y, 380, 800)
      frame.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
  end)
end

-- ==================== BUILD HUD (bottom-left overlay) ====================

BuildHUD = function()
  if not S.hudEnabled then
    for _, g in ipairs(PlayerGui:GetChildren()) do
      if g:IsA("ScreenGui") and g.Name == "CheatHUD" then g:Destroy() end
    end
    return
  end

  for _, g in ipairs(PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name == "CheatHUD" then g:Destroy() end
  end

  local hudGui = Instance.new("ScreenGui")
  hudGui.Name = "CheatHUD"
  hudGui.ResetOnSpawn = false
  hudGui.DisplayOrder = 999999 -- Topmost above all other UI
  hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  hudGui.Parent = PlayerGui

  -- Main frame — bottom-left, compact
  local frame = Instance.new("Frame")
  frame.Name = "HUDFrame"
  frame.Size = UDim2.new(0, 350, 0, 145)
  frame.Position = UDim2.new(0, 8, 1, -153)
  frame.BackgroundColor3 = XP.windowBg
  frame.BackgroundTransparency = 0.12
  frame.BorderSizePixel = 0
  frame.Parent = hudGui

  local grad = Instance.new("UIGradient")
  grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.windowBgLight),
    ColorSequenceKeypoint.new(0.5, XP.windowBg),
    ColorSequenceKeypoint.new(1, XP.windowBgDark)
  })
  grad.Rotation = 90; grad.Parent = frame

  -- Left accent stripe
  local stripe = Instance.new("Frame")
  stripe.Size = UDim2.new(0, 3, 1, 0); stripe.BackgroundColor3 = XP.accent
  stripe.BorderSizePixel = 0; stripe.Parent = frame

  -- Title bar (display name + FPS)
  local titleBar = Instance.new("Frame")
  titleBar.Size = UDim2.new(1, 0, 0, 24); titleBar.BackgroundColor3 = XP.titleBar
  titleBar.BackgroundTransparency = 0.1; titleBar.BorderSizePixel = 0; titleBar.Parent = frame

  local tbGrad = Instance.new("UIGradient")
  tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
    ColorSequenceKeypoint.new(0.5, XP.titleBarGrad2),
    ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
  })
  tbGrad.Rotation = 0; tbGrad.Parent = titleBar

  local dispLbl = Instance.new("TextLabel")
  dispLbl.Size = UDim2.new(1, -90, 1, 0); dispLbl.Position = UDim2.new(0, 10, 0, 0)
  dispLbl.Text = player.DisplayName
  dispLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
  dispLbl.BackgroundTransparency = 1; dispLbl.Font = Enum.Font.GothamBold
  dispLbl.TextSize = 13; dispLbl.TextXAlignment = Enum.TextXAlignment.Left
  dispLbl.TextTruncate = Enum.TextTruncate.AtEnd; dispLbl.Parent = titleBar

  -- FPS label on title bar (right-aligned)
  local fpsTop = Instance.new("TextLabel")
  fpsTop.Name = "HUD_FPS_Top"
  fpsTop.Size = UDim2.new(0, 76, 1, 0)
  fpsTop.Position = UDim2.new(1, -82, 0, 0)
  fpsTop.Text = "-- FPS"
  fpsTop.TextColor3 = Color3.fromRGB(50, 220, 100)
  fpsTop.BackgroundTransparency = 1
  fpsTop.Font = Enum.Font.GothamBold
  fpsTop.TextSize = 11
  fpsTop.TextXAlignment = Enum.TextXAlignment.Right
  fpsTop.Parent = titleBar

  -- Album Cover Image — larger, left side
  local hudCover = Instance.new("ImageLabel")
  hudCover.Name = "HUD_Cover"
  hudCover.Size = UDim2.new(0, 100, 0, 100)
  hudCover.Position = UDim2.new(0, 8, 0, 34)
  hudCover.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
  hudCover.BorderSizePixel = 0
  hudCover.ScaleType = Enum.ScaleType.Crop
  hudCover.Visible = (Music.coverAsset ~= "")
  if Music.coverAsset ~= "" then hudCover.Image = Music.coverAsset end
  hudCover.Parent = frame
  local coverStroke = Instance.new("UIStroke")
  coverStroke.Color = XP.accent
  coverStroke.Thickness = 2
  coverStroke.Parent = hudCover
  Music.hudCover = hudCover

  -- @username (bright ice-white tone)
  local userLbl = Instance.new("TextLabel")
  userLbl.Size = UDim2.new(1, -130, 0, 16); userLbl.Position = UDim2.new(0, 128, 0, 30)
  userLbl.Text = "@" .. player.Name
  userLbl.TextColor3 = Color3.fromRGB(225, 238, 255)
  userLbl.BackgroundTransparency = 1; userLbl.Font = Enum.Font.GothamBold
  userLbl.TextSize = 12; userLbl.TextXAlignment = Enum.TextXAlignment.Left
  userLbl.TextTruncate = Enum.TextTruncate.AtEnd; userLbl.Parent = frame

  -- Game name (bright cyan tone)
  local gameLbl = Instance.new("TextLabel")
  gameLbl.Name = "HUD_GameName"
  gameLbl.Size = UDim2.new(1, -130, 0, 18); gameLbl.Position = UDim2.new(0, 128, 0, 50)
  gameLbl.Text = "▶ " .. game.Name
  gameLbl.TextColor3 = Color3.fromRGB(80, 215, 255)
  gameLbl.BackgroundTransparency = 1; gameLbl.Font = Enum.Font.GothamBold
  gameLbl.TextSize = 13; gameLbl.TextXAlignment = Enum.TextXAlignment.Left
  gameLbl.TextTruncate = Enum.TextTruncate.AtEnd; gameLbl.Parent = frame

  -- Place ID (light silver tone)
  local pidLbl = Instance.new("TextLabel")
  pidLbl.Size = UDim2.new(1, -130, 0, 16); pidLbl.Position = UDim2.new(0, 128, 0, 70)
  pidLbl.Text = "Place: " .. tostring(game.PlaceId)
  pidLbl.TextColor3 = Color3.fromRGB(210, 225, 245)
  pidLbl.BackgroundTransparency = 1; pidLbl.Font = Enum.Font.Code
  pidLbl.TextSize = 12; pidLbl.TextXAlignment = Enum.TextXAlignment.Left; pidLbl.Parent = frame

  -- Now Playing Music label
  local musicLbl = Instance.new("TextLabel")
  musicLbl.Name = "HUD_Music"
  musicLbl.Size = UDim2.new(1, -130, 0, 16); musicLbl.Position = UDim2.new(0, 128, 0, 88)
  musicLbl.Text = Music.song ~= "" and ("♪ " .. Music.song .. (Music.artist ~= "" and " - " .. Music.artist or "")) or
      "♪ No music playing"
  musicLbl.TextColor3 = Music.active and Color3.fromRGB(50, 255, 140) or Color3.fromRGB(240, 248, 255)
  musicLbl.BackgroundTransparency = 1; musicLbl.Font = Enum.Font.GothamBold
  musicLbl.TextSize = 12; musicLbl.TextXAlignment = Enum.TextXAlignment.Left
  musicLbl.TextTruncate = Enum.TextTruncate.AtEnd; musicLbl.Parent = frame
  Music.hudLabel = musicLbl

  -- ==================== AUDIO VISUALIZER (bar graph) ====================
  local NUM_BARS = 19
  local VIZ_HEIGHT = 22
  local vizContainer = Instance.new("Frame")
  vizContainer.Name = "HUD_Visualizer"
  vizContainer.Size = UDim2.new(1, -130, 0, VIZ_HEIGHT)
  vizContainer.Position = UDim2.new(0, 128, 0, 106)
  vizContainer.BackgroundTransparency = 1
  vizContainer.BorderSizePixel = 0
  vizContainer.ClipsDescendants = true
  vizContainer.Parent = frame

  local vizBars = {}
  local vizTargets = {}
  local barWidth = 12
  local barGap = 3
  local totalBarSpan = NUM_BARS * (barWidth + barGap) - barGap

  for i = 1, NUM_BARS do
    local bar = Instance.new("Frame")
    bar.Name = "VizBar" .. i
    bar.AnchorPoint = Vector2.new(0, 1) -- bottom-anchored
    bar.Size = UDim2.new(0, barWidth, 0, 2)
    bar.Position = UDim2.new(0, (i - 1) * (barWidth + barGap), 1, 0)
    bar.BackgroundColor3 = XP.accent
    bar.BackgroundTransparency = 0.05
    bar.BorderSizePixel = 0
    bar.Parent = vizContainer

    local barGrad = Instance.new("UIGradient")
    barGrad.Rotation = 90
    barGrad.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, XP.accent),
      ColorSequenceKeypoint.new(0.5, XP.green or Color3.fromRGB(50, 220, 100)),
      ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 180, 80))
    })
    barGrad.Parent = bar

    vizBars[i] = bar
    vizTargets[i] = 2
  end

  -- Visualizer animation loop
  local vizTime = 0
  TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if not hudGui or not hudGui.Parent then return end
    if dt <= 0 then dt = 0.016 end
    vizTime = vizTime + dt

    local musicActive = Music.active and Music.song ~= ""

    for i = 1, NUM_BARS do
      -- Simulate audio spectrum with layered sine waves
      local freq = 3.0 + (i / NUM_BARS) * 7
      local wave1 = math.sin(vizTime * freq + i * 0.6) * 0.5 + 0.5
      local wave2 = math.sin(vizTime * (freq * 0.5) + i * 1.3) * 0.5 + 0.5
      local wave3 = math.sin(vizTime * (freq * 1.5) + i * 0.2) * 0.5 + 0.5
      local amp = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2)

      -- Shape the spectrum: higher bars in the middle (like real music)
      local center = (NUM_BARS + 1) / 2
      local distFromCenter = math.abs(i - center) / center
      local envelope = 1 - distFromCenter * 0.4

      if musicActive then
        -- Energetic bars when music playing
        amp = amp * envelope * (0.5 + wave2 * 0.5)
      else
        -- Subtle idle when no music
        amp = amp * envelope * 0.15
      end

      -- Smooth interpolation toward target height
      local targetHeight = math.clamp(2 + amp * (VIZ_HEIGHT - 4), 2, VIZ_HEIGHT)
      vizTargets[i] = vizTargets[i] + (targetHeight - vizTargets[i]) * math.min(dt * 14, 1)
      vizBars[i].Size = UDim2.new(0, barWidth, 0, vizTargets[i])
    end
  end))

  -- FPS Heartbeat updater attached to hudGui lifecycle
  TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if not hudGui or not hudGui.Parent then return end
    if dt <= 0 then dt = 0.016 end
    fpsSampleIdx = ((fpsSampleIdx or 0) % FPS_SAMPLES) + 1
    fpsSampleBuf[fpsSampleIdx] = 1 / dt
    local sum, count = 0, 0
    for _, v in ipairs(fpsSampleBuf) do
      sum = sum + v; count = count + 1
    end
    local avg = math.floor(sum / math.max(count, 1))
    local col = GetFPSColor(avg)
    fpsTop.Text = tostring(avg) .. " FPS"
    fpsTop.TextColor3 = col
  end))

  -- Try to fetch real game name async via MarketplaceService
  task.spawn(function()
    local ok, info = pcall(function()
      return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and info and info.Name and gameLbl and gameLbl.Parent then
      gameLbl.Text = "▶ " .. info.Name
    end
  end)

  UpdateMusicUI()
end

-- Fixed single-notification system (topmost layer, 0.75s fade-out, replaces previous)
local NOTIFICATION_POSITION = UDim2.new(1, -210, 1, -60)
local NOTIFICATION_SIZE = UDim2.new(0, 200, 0, 50)

local currentNotification = nil

local function ShowNotification(message)
  -- Destroy existing notification if any
  if currentNotification and currentNotification.gui and currentNotification.gui.Parent then
    currentNotification.gui:Destroy()
    currentNotification = nil
  end

  local notificationGui = Instance.new("ScreenGui")
  notificationGui.Name = "UniMenuNotification"
  notificationGui.ResetOnSpawn = false
  notificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  notificationGui.DisplayOrder = 2147483647 -- Topmost layer
  notificationGui.IgnoreGuiInset = true
  notificationGui.Parent = game:GetService("CoreGui")

  local frame = Instance.new("Frame")
  frame.Name = "NotificationFrame"
  frame.Size = NOTIFICATION_SIZE
  frame.Position = NOTIFICATION_POSITION
  frame.BackgroundColor3 = XP.panel1
  frame.BackgroundTransparency = 1
  frame.BorderSizePixel = 1
  frame.BorderColor3 = XP.borderDark
  frame.ZIndex = 2147483647
  frame.Parent = notificationGui

  local titleBar = Instance.new("Frame")
  titleBar.Size = UDim2.new(1, 0, 0, 20)
  titleBar.Position = UDim2.new(0, 0, 0, 0)
  titleBar.BackgroundColor3 = XP.accent
  titleBar.BorderSizePixel = 0
  titleBar.Parent = frame

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -40, 1, 0)
  title.Position = UDim2.new(0, 8, 0, 0)
  title.Text = "Notification"
  title.TextColor3 = Color3.fromRGB(255, 255, 255)
  title.BackgroundTransparency = 1
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Font = Enum.Font.GothamBold
  title.TextSize = 11
  title.Parent = titleBar

  local closeBtn = Instance.new("TextButton")
  closeBtn.Size = UDim2.new(0, 20, 0, 20)
  closeBtn.Position = UDim2.new(1, -24, 0, 0)
  closeBtn.Text = "X"
  closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
  closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
  closeBtn.BackgroundTransparency = 0.8
  closeBtn.BorderSizePixel = 0
  closeBtn.Font = Enum.Font.GothamBold
  closeBtn.TextSize = 11
  closeBtn.Parent = titleBar

  local messageLabel = Instance.new("TextLabel")
  messageLabel.Size = UDim2.new(1, -16, 1, -28)
  messageLabel.Position = UDim2.new(0, 8, 0, 24)
  messageLabel.Text = message
  messageLabel.TextColor3 = XP.text
  messageLabel.BackgroundTransparency = 1
  messageLabel.TextXAlignment = Enum.TextXAlignment.Center
  messageLabel.Font = Enum.Font.Gotham
  messageLabel.TextSize = 10
  messageLabel.TextWrapped = true
  messageLabel.Parent = frame

  currentNotification = { gui = notificationGui, frame = frame, message = message }

  closeBtn.MouseButton1Click:Connect(function()
    RemoveNotification()
  end)

  -- Pop-in bounce animation
  local tweenService = game:GetService("TweenService")

  -- Initial position (off-screen bottom right)
  frame.Position = UDim2.new(1, -210, 1, -30)

  -- Bounce in animation
  local bounceInfo = TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
  local bounceGoal = { Position = NOTIFICATION_POSITION }
  local bounceTween = tweenService:Create(frame, bounceInfo, bounceGoal)

  -- Fade in animation
  local fadeInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear)
  local fadeGoal = { BackgroundTransparency = 0 }
  local fadeTween = tweenService:Create(frame, fadeInfo, fadeGoal)

  bounceTween:Play()
  fadeTween:Play()

  -- Auto-close after 1 second with fade out
  task.delay(1, function()
    if currentNotification and currentNotification.gui == notificationGui and notificationGui.Parent then
      RemoveNotification()
    end
  end)
end

local function RemoveNotification()
  if not currentNotification then return end

  local gui = currentNotification.gui
  local frame = currentNotification.frame
  if not gui or not gui.Parent then
    currentNotification = nil
    return
  end
  if not frame then
    gui:Destroy()
    currentNotification = nil
    return
  end

  -- Fade out animation (0.75s)
  local tweenService = game:GetService("TweenService")
  local fadeOutInfo = TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
  local fadeOutGoal = { BackgroundTransparency = 1 }
  local fadeOutTween = tweenService:Create(frame, fadeOutInfo, fadeOutGoal)
  fadeOutTween:Play()

  -- Wait for fade to complete, then destroy
  task.delay(0.75, function()
    if gui and gui.Parent then
      gui:Destroy()
    end
    currentNotification = nil
  end)
end

-- Keybind Toggle Listener
TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
  if gameProcessed then return end
  if input.KeyCode == keybinds.menuToggle then
    if gui then
      gui:Destroy(); gui = nil; isOpen = false
    else
      isOpen = true; BuildGUI()
    end
    return
  end
  -- Check all registered feature keybinds
  local kbName = activeKeybindMap[input.KeyCode]
  if kbName and kbName ~= "menuToggle" then
    local reg = keybindRegistry[kbName]
    if reg and reg.get and reg.toggle then
      reg.toggle(not reg.get())
      -- Show notification
      local state = reg.get() and "enabled" or "disabled"
      ShowNotification(reg.featName .. " " .. state)
    end
  end
end))

-- ==================== PERSIST SCRIPT FOR SERVER HOPPING ====================
-- Save this script's source to disk so queue_on_teleport can reload it after a hop
local function PersistScript()
  if typeof(writefile) ~= "function" then return end
  -- If already persisted, nothing to do
  if isfile and isfile("UniMenu_autorun.lua") then return end
  -- Walk the call stack to find the main chunk's file path
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
  -- Fallback: try common file paths
  local candidates = {
    "UniMenu.lua",
    "UniMenu/UniMenu.lua",
    "scripts/UniMenu.lua",
  }
  for _, path in ipairs(candidates) do
    if isfile and isfile(path) then
      local content
      local ok2 = pcall(function() content = readfile(path) end)
      if ok2 and content and #content > 100 then
        writefile("UniMenu_autorun.lua", content)
        return
      end
    end
  end
end

PersistScript()

-- Load saved keybinds and settings on join
LoadKeybinds()
LoadSettings()

-- Build keybind registry for ALL features at startup (not just when Keybinds tab opens)
local function RegisterAllFeatureKeybinds()
  local function getKbName(tabName, featName)
    return tabName .. "::" .. featName
  end
  for tabName, tabFeats in pairs(features) do
    local sectionName = "General"
    for _, feat in ipairs(tabFeats) do
      if feat.isSection then sectionName = feat.name end
      if feat.isToggle and feat.toggle and not feat.isButton then
        local kbName = getKbName(tabName, feat.name)
        if not keybindRegistry[kbName] then
          keybindRegistry[kbName] = {
            get = feat.get,
            toggle = feat.toggle,
            tab = tabName,
            featName = feat.name,
          }
        end
      end
    end
  end
end
RegisterAllFeatureKeybinds()
RebuildKeybindMap()

-- Auto-connect Last.fm if we have a saved username
if Music.user ~= "" then
  task.spawn(function()
    StartLastfmPolling()
    LastfmPoll()
  end)
end

-- Save everything on leave/disconnect
game:GetService("Players").LocalPlayer.AncestryChanged:Connect(function(_, parent)
  if not parent then
    SaveKeybinds()
    SaveSettings()
  end
end)

-- Global teleport hook: save data and queue script re-execution on ANY teleport
local function OnTeleport()
  SaveKeybinds()
  SaveSettings()
  if typeof(queue_on_teleport) == "function" then
    queue_on_teleport("if isfile and isfile('UniMenu_autorun.lua') then loadfile('UniMenu_autorun.lua')() end")
  end
end
-- Hook TeleportInitiate (fires before teleport on the client)
pcall(function()
  TeleportService.TeleportInitiate:Connect(OnTeleport)
end)
-- Also listen for LocalPlayerTeleporting (alternate event name)
pcall(function()
  if TeleportService.LocalPlayerTeleporting then
    TeleportService.LocalPlayerTeleporting:Connect(OnTeleport)
  end
end)

RestoreCollision()
-- BuildGUI()  -- Main GUI hidden on launch; press ] to open
BuildHUD()

--[[
# ALL FEATURES INCLUDED IN THE SCRIPT
# ===================================
# COMBAT
#   - Aimbot (Right-click hold, configurable FOV & smoothness)
#   - Triggerbot (Auto-click on target)
#   - Auto Clicker
#
# MOVEMENT
#   - Speed Hack (WalkSpeed)
#   - Fly (BodyVelocity-based, WASD + Space/Shift)
#   - Infinite Jump
#   - Noclip
#   - Click Teleport
#   - Spinbot
#   - Anti-Fling
#   - Hip Height
#   - Low Gravity
#   - CS2 Bhop (Auto-bunnyhop with momentum preservation)
#   - CS2 Surf (Ramp surfing on triangular surfaces)
#
# VISUALS
#   - ESP (Highlight + Billboard name tags, distance)
#   - Fullbright
#   - Dark Mode (Night vision)
#   - Chams (BoxHandleAdornment)
#   - No Fog
#   - No VFX (Particles, Beams, Trails, Post-processing)
#   - X-Ray (Transparency)
#   - Freecam
#   - FPS Boost (Strip textures, decals, lighting effects)
#
# MM2 (MURDER MYSTERY 2)
#   - Role ESP (Murderer/Sheriff/Innocent colors)
#   - Gun ESP (Dropped gun highlight + tag)
#   - Trap ESP
#   - Coin ESP
#   - Auto Shoot (Sheriff)
#   - Anti Stab (Dodge murderer)
#   - Auto Collect Coins
#   - Knife Aura
#   - Auto Teleport to Murderer
#
# MISC / EXPLOITS
#   - Spectate
#   - Coin Tweening
#   - Grab Gun
#   - Teleport to Target
#   - Head Sit
#
# MUSIC / SOCIAL
#   - Last.fm Integration (Now Playing)
#   - Peer Detection (Other users with same script)
#   - Overhead Nametags (Themed)
#
# UI / QUALITY OF LIFE
#   - Themed Cheat Panel (Windows XP Luna, Vista Aero, Dark Obsidian, Crimson Blood, Emerald Cyber, Royal Amethyst)
#   - Keybind System (Customizable, persistent)
#   - Settings Persistence (JSON files)
#   - Notifications (Fixed position, 1s duration, fade out)
#   - HUD (FPS, Ping, Time, Game name)
#   - Server Hop Persistence (queue_on_teleport)
#}
]]
