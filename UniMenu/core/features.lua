-- UniMenu Core Features Module
-- Universal feature definitions for all games (Combat, Movement, Visuals, Themes, Config, HUD, Keybinds, Music, Experience)

local ctx = ...

local S = ctx.State.S
local gameConfig = ctx.Config.gameConfig
local Music = ctx.State.Music
local XP = ctx.Config.XP

local function ResetCharacter()
  local char = ctx.Services.Players.LocalPlayer.Character
  if char then
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
  end
end

local builtInFeatures = {
  Combat = {
    { isSection = true, name = "Targeting & Aim" },
    {
      name = "Aimbot (Hold RMB)",
      desc = "Smooth lock to nearest target while holding RMB",
      isToggle = true,
      get = function() return S.aimbot end,
      toggle = function(state) S.aimbot = state end,
    },
    { name = "Cycle Target Part", desc = "Cycles between Head, Root, Torso", isCyclePart = true },
    {
      name = "Triggerbot",
      desc = "Auto-click when crosshair detects player",
      isToggle = true,
      get = function() return S.triggerbot end,
      toggle = function(state) S.triggerbot = state end,
    },
    {
      name = "Auto Clicker",
      desc = "Continuous rapid left mouse clicks",
      isToggle = true,
      get = function() return S.autoClicker end,
      toggle = function(state) S.autoClicker = state end,
    },
    { isSection = true, name = "Combat Actions" },
    { name = "Reset Character", desc = "Instant respawn character", isButton = true, action = ResetCharacter },
  },
  Movement = {
    { isSection = true, name = "CS2 Physics Engine" },
    {
      name = "CS2 Surfing",
      desc = "Ramp surf smoothly along angled walls",
      isToggle = true,
      get = function() return S.cs2Surf end,
      toggle = function(state) S.cs2Surf = state end,
    },
    {
      name = "CS2 Auto-Bhop",
      desc = "Perfect bunnyhopping on jump contact",
      isToggle = true,
      get = function() return S.cs2Bhop end,
      toggle = function(state) S.cs2Bhop = state end,
    },
    {
      name = "CS2 Long Jump",
      desc = "Extended jump distance with scroll",
      isToggle = true,
      get = function() return S.cs2LongJump end,
      toggle = function(state) S.cs2LongJump = state end,
    },
    { isSection = true, name = "Classic Movement" },
    {
      name = "WalkSpeed",
      desc = "Custom walk speed",
      isToggle = true,
      get = function() return S.speed end,
      toggle = function(state) S.speed = state end,
    },
    {
      name = "WalkSpeed Value",
      desc = "Speed multiplier",
      hasSlider = true,
      configKey = "walkSpeed",
      min = 16,
      max = 100,
      isDecimal = false,
    },
    {
      name = "JumpPower",
      desc = "Custom jump height",
      isToggle = true,
      get = function() return S.jump end,
      toggle = function(state) S.jump = state end,
    },
    {
      name = "JumpPower Value",
      desc = "Jump multiplier",
      hasSlider = true,
      configKey = "jumpPower",
      min = 50,
      max = 250,
      isDecimal = false,
    },
    {
      name = "Infinite Jump",
      desc = "Jump infinitely in air",
      isToggle = true,
      get = function() return S.infJump end,
      toggle = function(state) S.infJump = state end,
    },
    {
      name = "No Clip",
      desc = "Walk through walls",
      isToggle = true,
      get = function() return S.noclip end,
      toggle = function(state) S.noclip = state end,
    },
    {
      name = "Fly",
      desc = "Free flight movement",
      isToggle = true,
      get = function() return S.fly end,
      toggle = function(state) S.fly = state end,
    },
    {
      name = "Fly Speed",
      desc = "Flight speed multiplier",
      hasSlider = true,
      configKey = "flySpeed",
      min = 10,
      max = 200,
      isDecimal = false,
    },
  },
  Visuals = {
    { isSection = true, name = "ESP & Highlights" },
    {
      name = "Player ESP",
      desc = "Highlight all players with name tags",
      isToggle = true,
      get = function() return S.esp end,
      toggle = function(state) 
        S.esp = state
        if ctx.UI and ctx.UI.ToggleESP then ctx.UI.ToggleESP(state) end
      end,
    },
    {
      name = "ESP Fill Transparency",
      desc = "ESP highlight fill transparency",
      hasSlider = true,
      configKey = "espFillTrans",
      min = 0,
      max = 1,
      isDecimal = true,
      onChange = function(val)
        gameConfig.espFillTrans = val
        if ctx.UI and ctx.UI.UpdateESPTransparency then ctx.UI.UpdateESPTransparency() end
      end,
    },
    {
      name = "ESP Outline Transparency",
      desc = "ESP highlight outline transparency",
      hasSlider = true,
      configKey = "espOutlineTrans",
      min = 0,
      max = 1,
      isDecimal = true,
      onChange = function(val)
        gameConfig.espOutlineTrans = val
        if ctx.UI and ctx.UI.UpdateESPTransparency then ctx.UI.UpdateESPTransparency() end
      end,
    },
    {
      name = "Chams",
      desc = "X-ray style player outlines",
      isToggle = true,
      get = function() return S.chams end,
      toggle = function(state) 
        S.chams = state
        if ctx.UI and ctx.UI.ToggleChams then ctx.UI.ToggleChams(state) end
      end,
    },
    {
      name = "Chams Transparency",
      desc = "Chams visibility",
      hasSlider = true,
      configKey = "chamsTrans",
      min = 0,
      max = 1,
      isDecimal = true,
      onChange = function(val)
        gameConfig.chamsTrans = val
        if ctx.UI and ctx.UI.UpdateChamsTransparency then ctx.UI.UpdateChamsTransparency() end
      end,
    },
    { isSection = true, name = "World" },
    {
      name = "Full Bright",
      desc = "Remove darkness/lighting effects",
      isToggle = true,
      get = function() return S.fullBright end,
      toggle = function(state) S.fullBright = state end,
    },
    {
      name = "No Fog",
      desc = "Remove atmospheric fog",
      isToggle = true,
      get = function() return S.noFog end,
      toggle = function(state) S.noFog = state end,
    },
  },
  Server = {
    { isSection = true, name = "Server Actions" },
    { name = "Rejoin", desc = "Rejoin current server", isButton = true, action = function() ctx.Services.TeleportService:Teleport(game.PlaceId, ctx.Services.Players.LocalPlayer) end },
    { name = "Server Hop", desc = "Join a different server", isButton = true, action = function() ctx.Core.ServerHop() end },
    { name = "Copy Job ID", desc = "Copy current JobId to clipboard", isButton = true, action = function() if setclipboard then setclipboard(game.JobId) ctx.Core.ShowNotification("Job ID copied") end end },
    { isSection = true, name = "Utilities" },
    { name = "Anti-AFK", desc = "Prevent idle kick", isToggle = true, get = function() return S.antiAfk end, toggle = function(state) S.antiAfk = state end },
    { name = "Chat Spy", desc = "See all chat messages", isToggle = true, get = function() return S.chatSpy end, toggle = function(state) S.chatSpy = state end },
  },
  Themes = {
    { isSection = true, name = "Theme Selection (dynamic actions defined at runtime)" },
  },
  Config = {
    { isSection = true, name = "Configuration" },
    { name = "Save Settings", desc = "Save current config to file", isButton = true, action = function() ctx.Core.SaveSettings() ctx.Core.ShowNotification("Settings saved") end },
    { name = "Load Settings", desc = "Load config from file", isButton = true, action = function() ctx.Core.LoadSettings() ctx.Core.ShowNotification("Settings loaded") end },
    { name = "Reset to Defaults", desc = "Reset all settings", isButton = true, action = function() ctx.Core.ResetSettings() ctx.Core.ShowNotification("Settings reset") end },
  },
  HUD = {
    { isSection = true, name = "HUD Settings" },
    {
      name = "Enable HUD",
      desc = "Show/hide the HUD overlay",
      isToggle = true,
      get = function() return S.hudEnabled end,
      toggle = function(state) 
        S.hudEnabled = state
        if ctx.UI and ctx.UI.ToggleHUD then ctx.UI.ToggleHUD(state) end
      end,
    },
    {
      name = "Show Keybind Overlay",
      desc = "Display active keybinds on screen",
      isToggle = true,
      get = function() return S.showKeybindOverlay end,
      toggle = function(state) 
        S.showKeybindOverlay = state
        if ctx.UI and ctx.UI.ToggleKeybindOverlay then ctx.UI.ToggleKeybindOverlay(state) end
      end,
    },
  },
  Keybinds = {
    { isSection = true, name = "Keybind Management" },
    { name = "Reset All Keybinds", desc = "Clear all custom keybinds", isButton = true, action = function() ctx.Core.ResetKeybinds() ctx.Core.ShowNotification("Keybinds reset") end },
  },
  Music = {
    { isSection = true, name = "Music Player (handled by custom UI)" },
  },
  Experience = {
    { isSection = true, name = "Experience Info (handled by custom UI)" },
  },
}

-- Register all built-in features
for tabName, tabFeats in pairs(builtInFeatures) do
  ctx.Core.RegisterFeatures(tabName, tabFeats)
end

ctx.Modules.core_features = true
return builtInFeatures