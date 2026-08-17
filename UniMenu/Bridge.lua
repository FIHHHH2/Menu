-- UniMenu Bridge Module - Entry Point & Shared State
-- Loads GuiModule and MM2Module, owns all shared state, handles persistence

if _G.CheatPanelCleanup then
  pcall(_G.CheatPanelCleanup)
end

-- ==================== FPS UNCAP ====================
local uncapOk = pcall(function()
  setfpscap(0)
end)
if not uncapOk then
  pcall(function()
    local rs = settings().Rendering
    if rs then
      rs.FrameRateManager = Enum.FrameRateManager.Adaptive
      rs.QualityLevel     = Enum.QualityLevel.Automatic
    end
  end)
end

-- ==================== SERVICES ====================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local TeleportService  = game:GetService("TeleportService")
local SoundService     = game:GetService("SoundService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")

local player           = Players.LocalPlayer
local PlayerGui        = player:WaitForChild("PlayerGui")
local camera           = workspace.CurrentCamera

-- ==================== SHARED STATE TABLES ====================
local Connections      = {}
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

-- Safety check: returns true only if player is alive, has a character, and is in a playable state
local function IsPlayerActive()
  local char = GetCharacter()
  if not char then return false end
  local hum = char:FindFirstChildOfClass("Humanoid")
  if not hum or hum.Health <= 0 then return false end
  local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
  if not root then return false end
  return true
end

-- Restore character collisions to standard Roblox physics
local function RestoreCollision()
  local char = GetCharacter()
  if char then
    for _, p in ipairs(char:GetDescendants()) do
      if p:IsA("BasePart") then
        if p:FindFirstAncestorWhichIsA("Accessory") or p:FindFirstAncestorWhichIsA("Tool") or p.Name == "Handle" then
          p.CanCollide = false
        elseif p.Name == "HumanoidRootPart" then
          p.CanCollide = false
        else
          p.CanCollide = true
        end
      end
    end
  end
end

-- ==================== UNIVERSAL STATE (S) ====================
local S                = {
  -- ESP / Visuals
  esp                = false,
  espFillTrans       = 0.5,
  espOutlineTrans    = 0,
  chams              = false,
  chamsTrans         = 0.3,
  xray               = false,
  fullbright         = false,
  darkMode           = false,
  noFog              = false,
  noVFX              = false,
  freecam            = false,
  fpsBoost           = false,
  origTransparency   = {},
  origMaterials      = {},
  origLighting       = {},
  espFolder          = nil,
  chamsFolder        = nil,
  freecamPart        = nil,
  freecamCF          = nil,
  flyBV              = nil,
  flySpeed           = 50,
  walkSpeed          = 16,
  jumpPower          = 50,
  infJump            = false,
  noclip             = false,
  clickTp            = false,
  spinbot            = false,
  spinSpeed          = 20,
  antiFling          = false,
  hipHeight          = 0,
  lowGrav            = false,
  gravityVal         = 196.2,
  surfSpeed          = 100,
  bhopAccel          = 1.5,
  customWalk         = false,
  customWalkSpeed    = 16,
  customJump         = false,
  customJumpPower    = 50,
  autoClick          = false,
  clickDelay         = 0.1,
  aimbot             = false,
  aimFOV             = 120,
  aimSmooth          = 0.2,
  triggerbot         = false,
  elevatedTorso      = false,
  torsoHeight        = 2,
  showHitboxes       = false,
  hitboxSize         = 3,
  hitboxTransparency = 0.5,
  hitboxColor        = Color3.fromRGB(255, 0, 0),
  coinTweening       = false,
  savedPosition      = nil,
  peerIcon           = false,
  hud                = true,
  usingDynamicTheme  = false,
  dynamicTheme       = nil,
  masterVolume       = 1,
  origSoundVolumes   = {},
  menuToggle         = Enum.KeyCode.RightBracket,
}

-- ==================== MM2 STATE ====================
local MM2              = {
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

-- ==================== GAME CONFIG ====================
local gameConfig       = {
  masterVolume = 1,
}

-- ==================== MUSIC STATE ====================
local Music            = {
  user       = "",
  lastfmKey  = "b25b959554ed76058ac220b7b2e0a026",
  coverCache = nil,
  isPlaying  = false,
  peerIcon   = "rbxassetid://6274377121",
}

-- ==================== THEMES PALETTE DEFINITION ====================
local Themes           = {
  ["Windows XP Luna"] = {
    name = "Windows XP Luna",
    bg = Color3.fromRGB(0, 51, 102),
    bgSecondary = Color3.fromRGB(0, 76, 153),
    bgTeritary = Color3.fromRGB(0, 102, 204),
    accent = Color3.fromRGB(0, 120, 215),
    accentHover = Color3.fromRGB(0, 153, 255),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(180, 200, 255),
    border = Color3.fromRGB(0, 102, 204),
    shadow = Color3.fromRGB(0, 0, 0),
    sliderTrack = Color3.fromRGB(0, 76, 153),
    sliderFill = Color3.fromRGB(0, 153, 255),
    toggleOff = Color3.fromRGB(0, 76, 153),
    toggleOn = Color3.fromRGB(0, 153, 255),
    button = Color3.fromRGB(0, 76, 153),
    buttonHover = Color3.fromRGB(0, 102, 204),
    scrollbar = Color3.fromRGB(0, 51, 102),
    scrollbarThumb = Color3.fromRGB(0, 102, 204),
    dropdown = Color3.fromRGB(0, 51, 102),
    dropdownHover = Color3.fromRGB(0, 76, 153),
    inputBg = Color3.fromRGB(0, 76, 153),
    inputText = Color3.fromRGB(255, 255, 255),
    tabActive = Color3.fromRGB(0, 120, 215),
    tabInactive = Color3.fromRGB(0, 51, 102),
    closeBtn = Color3.fromRGB(180, 0, 0),
    closeBtnHover = Color3.fromRGB(255, 50, 50),
    notificationBg = Color3.fromRGB(0, 51, 102),
    notificationText = Color3.fromRGB(255, 255, 255),
  },
  ["Windows Vista Aero"] = {
    name = "Windows Vista Aero",
    bg = Color3.fromRGB(30, 30, 45),
    bgSecondary = Color3.fromRGB(45, 45, 65),
    bgTeritary = Color3.fromRGB(60, 60, 85),
    accent = Color3.fromRGB(100, 180, 255),
    accentHover = Color3.fromRGB(140, 210, 255),
    text = Color3.fromRGB(240, 240, 255),
    textDim = Color3.fromRGB(180, 190, 220),
    border = Color3.fromRGB(80, 140, 220),
    shadow = Color3.fromRGB(0, 0, 0),
    sliderTrack = Color3.fromRGB(45, 45, 65),
    sliderFill = Color3.fromRGB(100, 180, 255),
    toggleOff = Color3.fromRGB(45, 45, 65),
    toggleOn = Color3.fromRGB(100, 180, 255),
    button = Color3.fromRGB(45, 45, 65),
    buttonHover = Color3.fromRGB(60, 60, 85),
    scrollbar = Color3.fromRGB(30, 30, 45),
    scrollbarThumb = Color3.fromRGB(80, 140, 220),
    dropdown = Color3.fromRGB(30, 30, 45),
    dropdownHover = Color3.fromRGB(45, 45, 65),
    inputBg = Color3.fromRGB(45, 45, 65),
    inputText = Color3.fromRGB(240, 240, 255),
    tabActive = Color3.fromRGB(100, 180, 255),
    tabInactive = Color3.fromRGB(30, 30, 45),
    closeBtn = Color3.fromRGB(220, 60, 60),
    closeBtnHover = Color3.fromRGB(255, 100, 100),
    notificationBg = Color3.fromRGB(30, 30, 45),
    notificationText = Color3.fromRGB(240, 240, 255),
  },
  ["Dark Cyberpunk"] = {
    name = "Dark Cyberpunk",
    bg = Color3.fromRGB(10, 10, 20),
    bgSecondary = Color3.fromRGB(20, 20, 35),
    bgTeritary = Color3.fromRGB(30, 30, 50),
    accent = Color3.fromRGB(0, 255, 200),
    accentHover = Color3.fromRGB(100, 255, 230),
    text = Color3.fromRGB(220, 255, 250),
    textDim = Color3.fromRGB(120, 200, 190),
    border = Color3.fromRGB(0, 200, 160),
    shadow = Color3.fromRGB(0, 0, 0),
    sliderTrack = Color3.fromRGB(20, 20, 35),
    sliderFill = Color3.fromRGB(0, 255, 200),
    toggleOff = Color3.fromRGB(20, 20, 35),
    toggleOn = Color3.fromRGB(0, 255, 200),
    button = Color3.fromRGB(20, 20, 35),
    buttonHover = Color3.fromRGB(30, 30, 50),
    scrollbar = Color3.fromRGB(10, 10, 20),
    scrollbarThumb = Color3.fromRGB(0, 200, 160),
    dropdown = Color3.fromRGB(10, 10, 20),
    dropdownHover = Color3.fromRGB(20, 20, 35),
    inputBg = Color3.fromRGB(20, 20, 35),
    inputText = Color3.fromRGB(220, 255, 250),
    tabActive = Color3.fromRGB(0, 255, 200),
    tabInactive = Color3.fromRGB(10, 10, 20),
    closeBtn = Color3.fromRGB(255, 50, 100),
    closeBtnHover = Color3.fromRGB(255, 100, 150),
    notificationBg = Color3.fromRGB(10, 10, 20),
    notificationText = Color3.fromRGB(220, 255, 250),
  },
  ["Light Modern"] = {
    name = "Light Modern",
    bg = Color3.fromRGB(245, 245, 250),
    bgSecondary = Color3.fromRGB(230, 230, 240),
    bgTeritary = Color3.fromRGB(215, 215, 230),
    accent = Color3.fromRGB(0, 120, 215),
    accentHover = Color3.fromRGB(0, 150, 255),
    text = Color3.fromRGB(30, 30, 40),
    textDim = Color3.fromRGB(100, 100, 120),
    border = Color3.fromRGB(180, 180, 200),
    shadow = Color3.fromRGB(0, 0, 0, 0.1),
    sliderTrack = Color3.fromRGB(230, 230, 240),
    sliderFill = Color3.fromRGB(0, 120, 215),
    toggleOff = Color3.fromRGB(230, 230, 240),
    toggleOn = Color3.fromRGB(0, 120, 215),
    button = Color3.fromRGB(230, 230, 240),
    buttonHover = Color3.fromRGB(215, 215, 230),
    scrollbar = Color3.fromRGB(245, 245, 250),
    scrollbarThumb = Color3.fromRGB(180, 180, 200),
    dropdown = Color3.fromRGB(245, 245, 250),
    dropdownHover = Color3.fromRGB(230, 230, 240),
    inputBg = Color3.fromRGB(255, 255, 255),
    inputText = Color3.fromRGB(30, 30, 40),
    tabActive = Color3.fromRGB(0, 120, 215),
    tabInactive = Color3.fromRGB(245, 245, 250),
    closeBtn = Color3.fromRGB(220, 50, 50),
    closeBtnHover = Color3.fromRGB(255, 80, 80),
    notificationBg = Color3.fromRGB(245, 245, 250),
    notificationText = Color3.fromRGB(30, 30, 40),
  },
}

local currentThemeName = "Windows XP Luna"
local XP               = Themes[currentThemeName]

-- ==================== KEYBINDS ====================
local KEYBIND_FILE     = "UniMenu_keybinds.json"
local SETTINGS_FILE    = "UniMenu_settings.json"

local keybinds         = {
  menuToggle = Enum.KeyCode.RightBracket
}

local keybindRegistry  = {}
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
    peerIcon   = Music.peerIcon or "rbxassetid://6274377121",
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
end

-- ==================== ANIMATION HELPER ====================
local function Animate(object, properties, duration)
  duration = duration or 0.15
  local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    properties)
  tween:Play()
  return tween
end

local isScriptRunning = true
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

  -- ResetCoinCache will be called from MM2Module if needed
  if typeof(_G.UniMenu_ResetCoinCache) == "function" then
    pcall(_G.UniMenu_ResetCoinCache)
  end

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

  if S.origLighting then
    for prop, val in pairs(S.origLighting) do
      pcall(function() Lighting[prop] = val end)
    end
    S.origLighting = {}
  end

  if S.origMaterials then
    for part, mat in pairs(S.origMaterials) do
      if part and part.Parent then
        part.Material = mat
      end
    end
    S.origMaterials = {}
  end
end

_G.CheatPanelCleanup = CleanupAll

-- ==================== PERSIST SCRIPT FOR SERVER HOPPING ====================
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

  local candidates = {
    "UniMenu.lua",
    "UniMenu/Bridge.lua",
    "scripts/UniMenu.lua",
    "scripts/UniMenu/Bridge.lua",
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

-- ==================== LOAD MODULES ====================
local GuiModule = require(script.Parent.GuiModule)
local MM2Module = require(script.Parent.MM2Module)

-- ==================== DEPENDENCY INJECTION ====================
local deps = {
  -- State tables
  state = S,
  MM2 = MM2,
  gameConfig = gameConfig,
  Music = Music,
  Themes = Themes,
  XP = XP,
  currentThemeName = currentThemeName,

  -- Services
  Players = Players,
  RunService = RunService,
  UserInputService = UserInputService,
  TweenService = TweenService,
  TeleportService = TeleportService,
  SoundService = SoundService,
  Lighting = Lighting,
  HttpService = HttpService,

  -- Player refs
  player = player,
  PlayerGui = PlayerGui,
  camera = camera,

  -- Keybinds
  keybinds = keybinds,
  keybindRegistry = keybindRegistry,
  activeKeybindMap = activeKeybindMap,
  KEYBIND_FILE = KEYBIND_FILE,
  SETTINGS_FILE = SETTINGS_FILE,
  RebuildKeybindMap = RebuildKeybindMap,
  SaveKeybinds = SaveKeybinds,
  LoadKeybinds = LoadKeybinds,
  SaveSettings = SaveSettings,
  LoadSettings = LoadSettings,

  -- Utilities
  Connections = Connections,
  TrackConnection = TrackConnection,
  GetFPSColor = GetFPSColor,
  GetCharacter = GetCharacter,
  GetHumanoid = GetHumanoid,
  GetRoot = GetRoot,
  IsPlayerActive = IsPlayerActive,
  RestoreCollision = RestoreCollision,
  Animate = Animate,
  CleanupAll = CleanupAll,
  FPS_SAMPLES = FPS_SAMPLES,
  fpsSampleBuf = fpsSampleBuf,
  fpsSampleIdx = fpsSampleIdx,
  isScriptRunning = isScriptRunning,
  lastESPUpdateTick = lastESPUpdateTick,
  IsVoiceChatSound = IsVoiceChatSound,
  ApplySoundVolume = ApplySoundVolume,
  SetMasterVolume = SetMasterVolume,

  -- Modules (cross-references)
  gui = GuiModule,
  mm2 = MM2Module,

  -- Persistence
  PersistScript = PersistScript,
}

-- Expose a few globals for backward compatibility / cross-module access
_G.UniMenu_Deps = deps
_G.UniMenu_ResetCoinCache = function() end -- Will be overwritten by MM2Module

-- ==================== INITIALIZATION ====================
LoadKeybinds()
LoadSettings()

GuiModule.Init(deps)
MM2Module.Init(deps)

-- Register all feature keybinds at startup
local function RegisterAllFeatureKeybinds()
  local function getKbName(tabName, featName)
    return tabName .. "::" .. featName
  end
  for tabName, tabFeats in pairs(GuiModule.features) do
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
  RebuildKeybindMap()
end

RegisterAllFeatureKeybinds()

-- Auto-connect Last.fm if we have a saved username
if Music.user ~= "" then
  task.spawn(function()
    GuiModule.StartLastfmPolling()
    GuiModule.LastfmPoll()
  end)
end

-- Save everything on leave/disconnect
TrackConnection(player.AncestryChanged:Connect(function(_, parent)
  if not parent then
    SaveKeybinds()
    SaveSettings()
  end
end))

-- Global teleport hook: save data and queue script re-execution on ANY teleport
local function OnTeleport()
  SaveKeybinds()
  SaveSettings()
  if typeof(queue_on_teleport) == "function" then
    queue_on_teleport("if isfile and isfile('UniMenu_autorun.lua') then loadfile('UniMenu_autorun.lua')() end")
  end
end

pcall(function()
  TeleportService.TeleportInitiate:Connect(OnTeleport)
end)
pcall(function()
  if TeleportService.LocalPlayerTeleporting then
    TeleportService.LocalPlayerTeleporting:Connect(OnTeleport)
  end
end)

RestoreCollision()
GuiModule.BuildHUD()

-- ==================== EXPORT BRIDGE API ====================
return {
  S = S,
  MM2 = MM2,
  gameConfig = gameConfig,
  Music = Music,
  Themes = Themes,
  GuiModule = GuiModule,
  MM2Module = MM2Module,
  deps = deps,
}
