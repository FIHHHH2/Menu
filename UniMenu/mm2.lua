-- UniMenu MM2 Module
-- MM2-specific features, hooks, ESP, auto-farm, magic bullet

local ctx = ...

-- Detection: check for essential MM2 Remotes
local isMM2 = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") 
              and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Gameplay")
if not isMM2 then return end

-- Services
local Players = ctx.Services.Players
local RunService = ctx.Services.RunService
local UserInputService = ctx.Services.UserInputService
local TweenService = ctx.Services.TweenService
local HttpService = ctx.Services.HttpService
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Core helpers
local player = Players.LocalPlayer
local TweenService_GS = TweenService
local camera = workspace.CurrentCamera

-- State refs
local S = ctx.State.S
local MM2 = ctx.State.MM2
local gameConfig = ctx.Config.gameConfig
local XP = ctx.Config.XP

local GetCharacter = ctx.Core.GetCharacter
local GetHumanoid = ctx.Core.GetHumanoid
local GetRoot = ctx.Core.GetRoot
local IsPlayerActive = ctx.Core.IsPlayerActive
local RestoreCollision = ctx.Core.RestoreCollision
local TrackConnection = ctx.Core.TrackConnection
local originalWalkSpeed = ctx.Core.originalWalkSpeed
local originalJumpPower = ctx.Core.originalJumpPower

-- Namespace
ctx.Game.MM2 = {}
local MM2M = ctx.Game.MM2

-- ==================== ROLE DETECTION ====================
local function UpdateRoleESP()
  if not MM2.roleESP then return end
  for _, player in ipairs(Players:GetPlayers()) do
    if player ~= Players.LocalPlayer and player.Character then
      local hasKnife = player.Character:FindFirstChild("Knife") or player.Backpack:FindFirstChild("Knife")
      local hasGun = player.Character:FindFirstChild("Gun") or player.Backpack:FindFirstChild("Gun")
      if hasKnife then
        AddESP(player, "[MURDERER]")
      elseif hasGun then
        AddESP(player, "[SHERIFF]")
      else
        AddESP(player, "[INNOCENT]")
      end
    end
  end
end

task.spawn(function()
  while task.wait(0.5) do
    if MM2.roleESP then
      UpdateRoleESP()
    end
  end
end)

local function GetMM2Sheriff()
  for _, p in ipairs(Players:GetPlayers()) do
    local char = p.Character
    local bp = p:FindFirstChild("Backpack")
    local charTool = char and char:FindFirstChildWhichIsA("Tool")
    local bpTool = bp and bp:FindFirstChildWhichIsA("Tool")
    local hasG = (char and (char:FindFirstChild("Gun")
        or (charTool and (charTool.Name:lower():find("gun")
          or charTool:FindFirstChild("GunServer")))))
        or (bp and (bp:FindFirstChild("Gun")
          or (bpTool and (bpTool.Name:lower():find("gun")
            or bpTool:FindFirstChild("GunServer")))))
    if hasG then return p end
  end
  return nil
end

MM2M.GetMM2Murderer = GetMM2Murderer
MM2M.GetMM2Sheriff = GetMM2Sheriff

-- ==================== MAGIC BULLET HOOK ====================
local magicBulletHook = nil
local function SetupMagicBulletHook()
  if magicBulletHook then return end
  local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
  local gameplay = remotes and remotes:WaitForChild("Gameplay", 5)
  local shootRemote = gameplay and gameplay:FindFirstChild("Shoot")
  if not shootRemote then return end

  local oldNamecall
  oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if self == shootRemote and method == "FireServer" then
      local args = {...}
      if typeof(args[1]) == "table" then
        local target = MM2M.GetMM2Murderer() or MM2M.GetMM2Sheriff()
        if target and target.Character and target.Character:FindFirstChild("Head") then
          args[1].Origin = camera.CFrame.Position
          args[1].Direction = (target.Character.Head.Position - camera.CFrame.Position).Unit
          args[1].Hit = target.Character.Head
          args[1].Distance = (target.Character.Head.Position - camera.CFrame.Position).Magnitude
        end
      end
    end
    return oldNamecall(self, unpack({...}))
  end)

  magicBulletHook = oldNamecall
end

MM2M.RemoveMagicBulletHook = function()
  if magicBulletHook then
    hookmetamethod(game, "__namecall", magicBulletHook)
    magicBulletHook = nil
  end
end

-- ==================== AUTO FARM ====================
local function CoinAutoFarm()
  if not MM2.coinAutoFarm or os.clock() - MM2.lastCoinFarmTime < MM2.coinFarmDelay then return end
  MM2.lastCoinFarmTime = os.clock()
  
  local coins = workspace:GetChildren()
  local closestCoin = nil
  local closestDistance = math.huge
  local myChar = GetCharacter()
  if not myChar then return end
  local myRoot = GetRoot(myChar)
  if not myRoot then return end
  
  for _, coin in ipairs(coins) do
    if coin.Name:find("Coin") and coin:IsA("Part") then
      local distance = (coin.Position - myRoot.Position).Magnitude
      if distance < closestDistance then
        closestDistance = distance
        closestCoin = coin
      end
    end
  end
  
  if closestCoin then
    myRoot.CFrame = closestCoin.CFrame * CFrame.new(0, 5, 0)
  end
end

task.spawn(function()
  while task.wait(0.5) do
    if MM2.coinAutoFarm then
      CoinAutoFarm()
    end
  end
end)

-- ==================== MM2 FEATURE LIST ====================
local SRef = S

local mm2FeatureList = {
  { isSection = true, name = "MM2 Automation" },
  {
    name = "Auto Farm (TP to Roles)",
    desc = "Teleport to Murderer/Sheriff automatically",
    isToggle = true,
    get = function() return SRef.mm2AutoFarm end,
    toggle = function(state) SRef.mm2AutoFarm = state end,
  },
  {
    name = "Magic Bullet (Silent Aim)",
    desc = "Redirect bullets to Murderer/Sheriff",
    isToggle = true,
    get = function() return SRef.mm2MagicBullet end,
    toggle = function(state)
      SRef.mm2MagicBullet = state
      if state then SetupMagicBulletHook() else MM2M.RemoveMagicBulletHook() end
    end,
  },
  { isSection = true, name = "Teleports" },
  { name = "TP to Murderer", desc = "Teleport behind active Murderer", isButton = true, action = function() 
    local m = MM2M.GetMM2Murderer()
    if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") then
      local myRoot = GetRoot()
      if myRoot then myRoot.CFrame = m.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 5) end
    end
  end },
  { name = "TP to Sheriff", desc = "Teleport behind active Sheriff / Hero", isButton = true, action = function()
    local s = MM2M.GetMM2Sheriff()
    if s and s.Character and s.Character:FindFirstChild("HumanoidRootPart") then
      local myRoot = GetRoot()
      if myRoot then myRoot.CFrame = s.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 5) end
    end
  end },
  { name = "TP to Lobby", desc = "Safely return to game lobby", isButton = true, action = function()
    local myChar = GetCharacter()
    if myChar then
      local myRoot = GetRoot(myChar)
      if myRoot then myRoot.CFrame = CFrame.new(0, 50, 0) end
    end
  end },
}

-- Register MM2 features into the registry (only if in MM2)
if isMM2 then
  ctx.Core.RegisterFeatures("MM2", mm2FeatureList)
end

-- Peer icon toggle (added to Config tab)
local peerIconFeature = {
  name = "Show Peer Icons",
  desc = "Show music peer icons above other UniMenu users",
  isToggle = true,
  get = function() return SRef.showPeerIcon end,
  toggle = function(state) ctx.Core.TogglePeerIcon(state) end,
}
ctx.Core.RegisterFeatures("Config", ctx.Core.features["Config"] or {})
table.insert(ctx.Core.features["Config"], peerIconFeature)

ctx.Modules.mm2 = true