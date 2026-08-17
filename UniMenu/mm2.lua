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
local function GetMM2Murderer()
  for _, p in ipairs(Players:GetPlayers()) do
    local char = p.Character
    local bp = p:FindFirstChild("Backpack")
    local charTool = char and char:FindFirstChildWhichIsA("Tool")
    local bpTool = bp and bp:FindFirstChildWhichIsA("Tool")
    local hasK = (char and (char:FindFirstChild("Knife")
        or (charTool and (charTool.Name:lower():find("knife")
          or charTool:FindFirstChild("KnifeServer")))))
        or (bp and (bp:FindFirstChild("Knife")
          or (bpTool and (bpTool.Name:lower():find("knife")
            or bpTool:FindFirstChild("KnifeServer")))))
    if hasK then return p end
  end
  return nil
end

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

-- ==================== DROPPED GUN ====================
local cachedDroppedGun = nil
local lastGunSearchTick = 0

local function GetMM2DroppedGun()
  if cachedDroppedGun and cachedDroppedGun.Parent and cachedDroppedGun:IsDescendantOf(workspace) then
    return cachedDroppedGun
  end
  cachedDroppedGun = nil
  local now = tick()
  if now - lastGunSearchTick < 0.4 then return nil end
  lastGunSearchTick = now

  local directGun = workspace:FindFirstChild("GunDrop")
  if directGun then
    local p = directGun:IsA("BasePart") and directGun or directGun:FindFirstChildWhichIsA("BasePart")
        or directGun:FindFirstChild("Handle")
    if p then cachedDroppedGun = p; return p end
  end
  for _, child in ipairs(workspace:GetChildren()) do
    if child:IsA("Model") and child.Name ~= "Lobby" and child.Name ~= "Terrain"
        and not Players:GetPlayerFromCharacter(child) then
      local mapGun = child:FindFirstChild("GunDrop")
      if mapGun then
        local p = mapGun:IsA("BasePart") and mapGun or mapGun:FindFirstChildWhichIsA("BasePart")
            or mapGun:FindFirstChild("Handle")
        if p then cachedDroppedGun = p; return p end
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
    if root and root.Parent then root.CFrame = savedPos end
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
    if root and root.Parent then root.CFrame = savedPos end
  end
end

MM2M.GetMM2DroppedGun = GetMM2DroppedGun
MM2M.GrabDroppedGun = GrabDroppedGun
MM2M.AutoGrabSheriffGun = AutoGrabSheriffGun

-- ==================== AUTO FOLLOW BEHIND ====================
local autoFollowConn = nil
local autoFollowTarget = nil
local pathWaypoints = {}
local currentWaypointIndex = 1
local lastTargetPos = Vector3.new()
local stuckTimer = 0
local lastPosition = Vector3.new()
local selectedPlayer = ctx.Core.selectedPlayer

local function SetAutoFollowTarget()
  if not selectedPlayer or not selectedPlayer.Character then return end
  autoFollowTarget = selectedPlayer
  pathWaypoints = {}
  currentWaypointIndex = 1
  stuckTimer = 0
  lastPosition = Vector3.new()
end

local function ComputePath(startPos, endPos)
  local path = PathfindingService:CreatePath({
    AgentRadius = 2, AgentHeight = 5,
    AgentCanJump = true, AgentCanClimb = true, AgentCanSwim = true,
    WaypointSpacing = 4,
    Costs = { Water = 10, Danger = math.huge },
  })
  local success = pcall(function() path:ComputeAsync(startPos, endPos) end)
  if success and path.Status == Enum.PathStatus.Success then
    return path:GetWaypoints()
  end
  return nil
end

local function GetTargetMovementState(targetHum, targetRoot)
  if not targetHum or not targetRoot then return "idle" end
  local velocity = targetRoot.AssemblyLinearVelocity
  local speed = velocity.Magnitude
  local state = targetHum:GetState()
  if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
    return "jumping"
  elseif state == Enum.HumanoidStateType.Climbing then return "climbing"
  elseif state == Enum.HumanoidStateType.Swimming then return "swimming"
  elseif speed > 2 then return "running"
  elseif speed > 0.5 then return "walking"
  else return "idle" end
end

local function MimicMovementState(myHum, targetState, targetMoveDir)
  if not myHum then return end
  if targetState == "jumping" then
    if myHum:GetState() ~= Enum.HumanoidStateType.Jumping
        and myHum:GetState() ~= Enum.HumanoidStateType.Freefall then
      myHum.Jump = true
    end
  end
  if targetMoveDir.Magnitude > 0 then
    myHum:Move(targetMoveDir, false)
  end
end

local function CheckStuck(myRoot, dt)
  if not myRoot then return false end
  local currentPos = myRoot.Position
  local moved = (currentPos - lastPosition).Magnitude
  if moved < 0.5 then stuckTimer = stuckTimer + dt else stuckTimer = 0 end
  lastPosition = currentPos
  return stuckTimer > 1.5
end

local function FindClearPositionAround(targetPos)
  local rayParams = RaycastParams.new()
  rayParams.FilterDescendantsInstances = { GetCharacter() }
  rayParams.FilterType = Enum.RaycastFilterType.Exclude
  local directions = {
    Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
    Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
    Vector3.new(1, 0, 1).Unit, Vector3.new(-1, 0, 1).Unit,
    Vector3.new(1, 0, -1).Unit, Vector3.new(-1, 0, -1).Unit,
  }
  for _, dir in ipairs(directions) do
    local testPos = targetPos + dir * 6
    local ray = workspace:Raycast(testPos + Vector3.new(0, 10, 0),
      Vector3.new(0, -20, 0), rayParams)
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

  autoFollowConn = ctx.Core.TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if not MM2.autoFollow or not autoFollowTarget or not autoFollowTarget.Character then
      if autoFollowConn then autoFollowConn:Disconnect(); autoFollowConn = nil end
      return
    end

    local myChar = GetCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local targetChar = autoFollowTarget.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or not targetRoot or not myHum or not targetHum then return end

    local behindOffset = targetRoot.CFrame.LookVector * -5
    local idealPos = targetRoot.Position + behindOffset
    local targetState = GetTargetMovementState(targetHum, targetRoot)
    local targetMoveDir = targetHum.MoveDirection
    MimicMovementState(myHum, targetState, targetMoveDir)
    local isStuck = CheckStuck(myRoot, dt)
    local distToIdeal = (idealPos - myRoot.Position).Magnitude
    local targetMoved = (targetRoot.Position - lastTargetPos).Magnitude > 3

    if targetMoved or isStuck or #pathWaypoints == 0 then
      lastTargetPos = targetRoot.Position
      if distToIdeal < 8 and not isStuck then
        pathWaypoints = {}
        currentWaypointIndex = 1
      else
        local waypoints = ComputePath(myRoot.Position, idealPos)
        if waypoints and #waypoints > 0 then
          pathWaypoints = waypoints; currentWaypointIndex = 1
        else
          local clearPos = FindClearPositionAround(idealPos)
          local fallback = ComputePath(myRoot.Position, clearPos)
          if fallback and #fallback > 0 then
            pathWaypoints = fallback; currentWaypointIndex = 1
          else pathWaypoints = {} end
        end
      end
    end

    if #pathWaypoints > 0 and currentWaypointIndex <= #pathWaypoints then
      local waypoint = pathWaypoints[currentWaypointIndex]
      local toWaypoint = waypoint.Position - myRoot.Position
      local waypointDist = toWaypoint.Magnitude
      if waypointDist < 3 then
        currentWaypointIndex = currentWaypointIndex + 1
      else
        local moveDir = toWaypoint.Unit
        myHum:Move(moveDir, false)
        if waypoint.Action == Enum.PathWaypointAction.Jump then
          if myHum:GetState() ~= Enum.HumanoidStateType.Jumping then
            myHum.Jump = true
          end
        end
      end
    else
      local toIdeal = idealPos - myRoot.Position
      if toIdeal.Magnitude > 2 then myHum:Move(toIdeal.Unit, false)
      else myHum:Move(Vector3.new(), false) end
    end

    myRoot.CFrame = CFrame.new(myRoot.Position,
      Vector3.new(targetRoot.Position.X, myRoot.Position.Y, targetRoot.Position.Z))
  end))
end

local function StopAutoFollow()
  if autoFollowConn then autoFollowConn:Disconnect(); autoFollowConn = nil end
  pathWaypoints = {}
  currentWaypointIndex = 1
  stuckTimer = 0
  lastPosition = Vector3.new()
  autoFollowTarget = nil
end

MM2M.SetAutoFollowTarget = SetAutoFollowTarget
MM2M.ComputePath = ComputePath
MM2M.GetTargetMovementState = GetTargetMovementState
MM2M.MimicMovementState = MimicMovementState
MM2M.CheckStuck = CheckStuck
MM2M.FindClearPositionAround = FindClearPositionAround
MM2M.StartAutoFollow = StartAutoFollow
MM2M.StopAutoFollow = StopAutoFollow

-- ==================== PLATFORM MODE ====================
local platformConn = nil
local platformTarget = nil

local function StartPlatformMode()
  if platformConn then return end
  if not selectedPlayer or not selectedPlayer.Character then return end
  platformTarget = selectedPlayer

  platformConn = ctx.Core.TrackConnection(RunService.Heartbeat:Connect(function()
    if not MM2.platformMode or not platformTarget or not platformTarget.Character then
      if platformConn then platformConn:Disconnect(); platformConn = nil end
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
  end))
end

local function StopPlatformMode()
  if platformConn then platformConn:Disconnect(); platformConn = nil end
  if platformTarget and platformTarget.Character then
    local myChar = GetCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then myRoot.Anchored = false end
  end
  platformTarget = nil
end

MM2M.StartPlatformMode = StartPlatformMode
MM2M.StopPlatformMode = StopPlatformMode

-- ==================== BOOST MODE ====================
local boostConn = nil
local boostTarget = nil

local function StartBoostMode()
  if boostConn then return end
  if not selectedPlayer or not selectedPlayer.Character then return end
  boostTarget = selectedPlayer

  boostConn = RunService.Heartbeat:Connect(function()
    if not MM2.boostMode or not boostTarget or not boostTarget.Character then
      if boostConn then boostConn:Disconnect(); boostConn = nil end
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
    
    if MM2.autoCoins and targetRoot then
      local lookDir = targetRoot.CFrame.LookVector
      targetRoot.AssemblyLinearVelocity = lookDir * 80 + Vector3.new(0, 20, 0)
    end
  end)
end

local function StopBoostMode()
  if boostConn then boostConn:Disconnect(); boostConn = nil end
  if boostTarget and boostTarget.Character then
    local myChar = GetCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then myRoot.Anchored = false end
  end
  boostTarget = nil
end

MM2M.StartBoostMode = StartBoostMode
MM2M.StopBoostMode = StopBoostMode

-- ==================== MAGIC BULLET ====================
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
    if mRoot and mHum and mHum.Health > 0 then return m.Character end
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

local magicProjectile = nil
local magicProjectileConn = nil

local function CalculateInterceptPoint(targetRoot, projectileSpeed)
  local myRoot = GetRoot()
  if not myRoot then return targetRoot.Position end
  local targetPos = targetRoot.Position
  local targetVel = targetRoot.AssemblyLinearVelocity or Vector3.zero
  local projectilePos = myRoot.Position
  local distance = (targetPos - projectilePos).Magnitude
  local flightTime = distance / projectileSpeed
  local predictedPos = targetPos + targetVel * flightTime
  for i = 1, 3 do
    local newDist = (predictedPos - projectilePos).Magnitude
    local newTime = newDist / projectileSpeed
    predictedPos = targetPos + targetVel * newTime
  end
  return predictedPos
end

local function CreateMagicProjectile()
  local myRoot = GetRoot()
  if not myRoot then return nil end
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

  local trail = Instance.new("Trail")
  trail.Color = ColorSequence.new(Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 60, 0))
  trail.Lifetime = 0.4
  trail.MinLength = 0.1
  trail.WidthScale = NumberSequence.new(0.5, 0)
  trail.Parent = proj

  local light = Instance.new("PointLight")
  light.Color = Color3.fromRGB(255, 120, 0)
  light.Brightness = 2
  light.Range = 15
  light.Parent = proj

  local align = Instance.new("AlignOrientation")
  align.Mode = Enum.OrientationAlignmentMode.OneAttachment
  align.RigidityEnabled = true
  align.Parent = proj
  local attach = Instance.new("Attachment")
  attach.Parent = proj
  align.Attachment0 = attach
  return proj
end

local function CleanupMagicProjectile()
  if magicProjectileConn then magicProjectileConn:Disconnect(); magicProjectileConn = nil end
  if magicProjectile then magicProjectile:Destroy(); magicProjectile = nil end
end

local function LaunchMagicProjectile(targetChar)
  if magicProjectileConn then return end
  local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
  local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
  if not targetRoot or not targetHum or targetHum.Health <= 0 then return end
  local myRoot = GetRoot()
  if not myRoot then return end

  local PROJECTILE_SPEED = 140
  local MAX_FLIGHT_TIME = 4.0
  local STEER_STRENGTH = 12
  local STEER_DAMPENING = 0.85

  magicProjectile = CreateMagicProjectile()
  if not magicProjectile then return end

  local startTime = tick()
  local lastVelocity = Vector3.zero
  local integralError = Vector3.zero

  magicProjectileConn = ctx.Core.TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if not magicProjectile or not magicProjectile.Parent or not MM2.magicBullet then
      if magicProjectileConn then magicProjectileConn:Disconnect(); magicProjectileConn = nil end
      if magicProjectile then magicProjectile:Destroy() end
      magicProjectile = nil
      return
    end
    if not targetRoot.Parent or not targetHum or targetHum.Health <= 0 then
      local newTarget = GetBestMagicBulletTarget()
      if newTarget then
        targetChar = newTarget
        targetRoot = newTarget:FindFirstChild("HumanoidRootPart")
        targetHum = newTarget:FindFirstChildOfClass("Humanoid")
      else
        magicProjectile:Destroy(); magicProjectile = nil
        return
      end
    end
    if tick() - startTime > MAX_FLIGHT_TIME then
      magicProjectile:Destroy(); magicProjectile = nil
      return
    end

    local interceptPos = CalculateInterceptPoint(targetRoot, PROJECTILE_SPEED)
    local currentPos = magicProjectile.Position
    local toTarget = interceptPos - currentPos
    local distance = toTarget.Magnitude
    local desiredDir = toTarget.Unit
    local currentVelDir = lastVelocity.Magnitude > 0 and lastVelocity.Unit or desiredDir
    local error = desiredDir - currentVelDir
    integralError = integralError + error * dt
    local derivative = error / dt
    local steerForce = error * STEER_STRENGTH + integralError * 2
    local newDir = (currentVelDir + steerForce).Unit
    local newVelocity = newDir * PROJECTILE_SPEED
    lastVelocity = lastVelocity * STEER_DAMPENING + newVelocity * (1 - STEER_DAMPENING)
    local newPos = currentPos + lastVelocity * dt
    magicProjectile.CFrame = CFrame.lookAt(newPos, newPos + lastVelocity.Unit)

    if distance < 4 then
      magicProjectile.CFrame = CFrame.lookAt(currentPos, targetRoot.Position)
      if typeof(firetouchinterest) == "function" then
        pcall(function()
          firetouchinterest(targetRoot, magicProjectile, 0)
          firetouchinterest(targetRoot, magicProjectile, 1)
        end)
      end
      if KillEventRemote and KillEventRemote:IsA("RemoteEvent") then
        KillEventRemote:FireServer(player, targetChar)
      end
      task.delay(0.1, function()
        if magicProjectile then magicProjectile:Destroy() end
      end)
      magicProjectile = nil
      if magicProjectileConn then
        magicProjectileConn:Disconnect(); magicProjectileConn = nil
      end
    end
  end))
end

local function ApplyMagicBulletHook()
  if magicBulletWeaponService then return end
  magicBulletOriginalGetMouseTargetCFrame = nil
  magicBulletOriginalGetTargetPosition = nil
  magicBulletOriginalThrowKnife = nil

  local ws = ReplicatedStorage
  local clientServices = ws:FindFirstChild("ClientServices")
  if not clientServices then return end
  local weaponService = clientServices:FindFirstChild("WeaponService")
  if not weaponService or not weaponService:IsA("ModuleScript") then return end

  local ok, mod = pcall(function() return require(weaponService) end)
  if not ok or type(mod) ~= "table" then return end

  magicBulletWeaponService = weaponService
  if not KillEventRemote then
    KillEventRemote = ws:FindFirstChild("Remotes") and ws.Remotes:FindFirstChild("Gameplay")
        and ws.Remotes.Gameplay:FindFirstChild("KillEvent")
  end
  if KillEventConn then KillEventConn:Disconnect(); KillEventConn = nil end
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

  if type(mod.GetMouseTargetCFrame) == "function" then
    magicBulletOriginalGetMouseTargetCFrame = mod.GetMouseTargetCFrame
    mod.GetMouseTargetCFrame = function(...)
      if MM2.magicBullet and magicBulletGetEquippedWeapon() == "gun" then
        local forced = magicBulletResolveCFrame()
        if forced then return forced end
      end
      return magicBulletOriginalGetMouseTargetCFrame(...)
    end
  end

  if type(mod.GetTargetPosition) == "function" then
    magicBulletOriginalGetTargetPosition = mod.GetTargetPosition
    mod.GetTargetPosition = function(...)
      if MM2.magicBullet and magicBulletGetEquippedWeapon() == "gun" then
        local forced = magicBulletResolveCFrame()
        if forced then return forced end
      end
      return magicBulletOriginalGetTargetPosition(...)
    end
  end

  if type(mod.ThrowKnife) == "function" then
    magicBulletOriginalThrowKnife = mod.ThrowKnife
    mod.ThrowKnife = function(...)
      if MM2.magicBullet and magicBulletGetEquippedWeapon() == "knife" then
        local targetChar = GetBestMagicBulletTarget()
        if targetChar then LaunchMagicProjectile(targetChar) end
      end
      return magicBulletOriginalThrowKnife(...)
    end
  end
end

local function RemoveMagicBulletHook()
  if KillEventConn then KillEventConn:Disconnect(); KillEventConn = nil end
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

local function UpdateMagicBullet()
  if MM2.magicBullet then ApplyMagicBulletHook() else RemoveMagicBulletHook() end
end

MM2M.GetBestMagicBulletTarget = GetBestMagicBulletTarget
MM2M.ApplyMagicBulletHook = ApplyMagicBulletHook
MM2M.RemoveMagicBulletHook = RemoveMagicBulletHook
MM2M.LaunchMagicProjectile = LaunchMagicProjectile
MM2M.CreateMagicProjectile = CreateMagicProjectile
MM2M.CalculateInterceptPoint = CalculateInterceptPoint
MM2M.CleanupMagicProjectile = CleanupMagicProjectile
MM2M.UpdateMagicBullet = UpdateMagicBullet

player.CharacterAdded:Connect(function()
  task.wait(0.5)
  UpdateMagicBullet()
end)

if isMM2 then
  TrackConnection(RunService.Heartbeat:Connect(function()
    if MM2.magicBullet then ApplyMagicBulletHook() end
  end))

  -- ==================== COIN SYSTEM ====================
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
      if (map:IsA("Model") or map:IsA("Folder")) and map.Name ~= "Lobby"
          and map.Name ~= "WeaponDisplays" and map.Name ~= "Terrain" and map.Name ~= "RCCars"
          and not Players:GetPlayerFromCharacter(map) then
        local cc = map:FindFirstChild("CoinContainer")
            or map:FindFirstChild("CoinAreas") or map:FindFirstChild("Coins")
        if cc then cachedCoinContainer = cc; break end
      end
    end
  end
  local coins = {}
  if cachedCoinContainer and cachedCoinContainer.Parent then
    for _, coin in ipairs(cachedCoinContainer:GetChildren()) do
      local coinKey = tostring(coin)
      if coin:IsA("BasePart") and not collectedCoinSet[coinKey] then
        if coin:FindFirstChild("CoinVisual") or coin.Name == "Coin_Server"
            or coin.Name:lower():find("coin") then
          table.insert(coins, coin)
        end
      end
    end
  end
  return coins
end

local function MarkCoinCollected(coin)
  if coin then collectedCoinSet[tostring(coin)] = true end
end

MM2M.GetMM2ActiveCoins = GetMM2ActiveCoins
MM2M.ResetCoinCache = ResetCoinCache
MM2M.MarkCoinCollected = MarkCoinCollected

-- ==================== TELEPORT & ACTIONS ====================
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
      local spawnPart = spawns:FindFirstChildWhichIsA("SpawnLocation")
          or spawns:FindFirstChildWhichIsA("BasePart")
      if spawnPart then
        root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
        return
      end
    end
    local spawnPart = lobby:FindFirstChildWhichIsA("SpawnLocation")
        or lobby:FindFirstChildWhichIsA("BasePart")
    if spawnPart then
      root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
      return
    end
  end
  root.CFrame = CFrame.new(Vector3.new(-108, 140, -11))
end

local function KillAllMurderer()
  local char = player.Character
  local knife = (char and char:FindFirstChild("Knife"))
      or (player.Backpack and player.Backpack:FindFirstChild("Knife"))
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
  local gun = (char and char:FindFirstChild("Gun"))
      or (player.Backpack and player.Backpack:FindFirstChild("Gun"))
  if not gun then return end
  if gun.Parent ~= char then gun.Parent = char end

  local m = GetMM2Murderer()
  if not m or not m.Character or not m.Character:FindFirstChild("HumanoidRootPart") then return end

  local targetRoot = m.Character.HumanoidRootPart
  local vel = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.zero
  local predPos = targetRoot.Position + vel * 0.12 + Vector3.new(0, 0.5, 0)

  local hrp = char:FindFirstChild("HumanoidRootPart")
  local attach = hrp and hrp:FindFirstChild("GunRaycastAttachment")
  local originCFrame = attach and attach.WorldCFrame or (hrp and hrp.CFrame) or nil

  local targetCFrame = CFrame.new(predPos)
  pcall(function()
    local WeaponService = require(game:GetService("ReplicatedStorage"):WaitForChild("ClientServices"):WaitForChild("WeaponService"))
    targetCFrame = WeaponService:GetMouseTargetCFrame()
  end)
  if not targetCFrame then targetCFrame = CFrame.new(predPos) end

  local shootRemote = gun:FindFirstChild("Shoot")
  if shootRemote and shootRemote:IsA("RemoteEvent") and originCFrame then
    pcall(function() shootRemote:FireServer(originCFrame, targetCFrame) end)
  end
  pcall(function() gun:Activate() end)
end

MM2M.TeleportToMurderer = TeleportToMurderer
MM2M.TeleportToSheriff = TeleportToSheriff
MM2M.TeleportToLobby = TeleportToLobby
MM2M.KillAllMurderer = KillAllMurderer
MM2M.ShootMurdererSheriff = ShootMurdererSheriff

-- ==================== TRAP ESP ====================
local function UpdateTrapESP()
  if not S.espFolder then return end
  for _, child in ipairs(workspace:GetDescendants()) do
    if child:IsA("BasePart") and (child.Name:lower():find("trap")
        or child.Name:lower():find("beartrap"))
        and not (player.Character and child:IsDescendantOf(player.Character)) then
      local tagId = "Trap_" .. tostring(child:GetFullName()):gsub("[^%w]", "_")
      local existing = S.espFolder:FindFirstChild(tagId)
      if MM2.trapESP then
        if not existing then
          local bb = Instance.new("BillboardGui")
          bb.Name = tagId; bb.Adornee = child
          bb.Size = UDim2.new(0, 100, 0, 30)
          bb.AlwaysOnTop = true
          bb.StudsOffset = Vector3.new(0, 1.5, 0)
          bb.Parent = S.espFolder
          local lbl = Instance.new("TextLabel")
          lbl.Size = UDim2.new(1, 0, 1, 0)
          lbl.Text = "[TRAP]"
          lbl.TextColor3 = Color3.fromRGB(255, 60, 0)
          lbl.BackgroundTransparency = 1
          lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
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

MM2M.UpdateTrapESP = UpdateTrapESP
MM2M.DodgeMurdererKnife = DodgeMurdererKnife

-- ==================== HEARTBEAT CALLBACK (MM2 runtime logic) ====================
ctx.Core.RegisterHeartbeat(function(dt)
  local root = ctx.Core.GetRoot()
  local MM2_espFolder = S.espFolder

  -- MM2 Role ESP color updates
  if MM2.roleESP and MM2_espFolder then
    for _, plr in ipairs(Players:GetPlayers()) do
      if plr ~= player and plr.Character then
        local char = plr.Character
        local hl = MM2_espFolder:FindFirstChild(plr.Name .. "_HL")
        if hl then
          local bp = plr:FindFirstChild("Backpack")
          local hasKnife = (char:FindFirstChild("Knife")
              or (char:FindFirstChildWhichIsA("Tool") and char:FindFirstChildWhichIsA("Tool").Name:lower():find("knife")))
              or (bp and (bp:FindFirstChild("Knife")
                or (bp:FindFirstChildWhichIsA("Tool") and bp:FindFirstChildWhichIsA("Tool").Name:lower():find("knife"))))
          local hasGun = (char:FindFirstChild("Gun")
              or (char:FindFirstChildWhichIsA("Tool") and char:FindFirstChildWhichIsA("Tool").Name:lower():find("gun")))
              or (bp and (bp:FindFirstChild("Gun")
                or (bp:FindFirstChildWhichIsA("Tool") and bp:FindFirstChildWhichIsA("Tool").Name:lower():find("gun"))))

          local targetColor = Color3.fromRGB(40, 215, 90)
          local headerColor = Color3.fromRGB(25, 150, 65)
          if hasKnife then
            targetColor = Color3.fromRGB(255, 30, 30)
            headerColor = Color3.fromRGB(210, 25, 25)
          elseif hasGun then
            targetColor = Color3.fromRGB(30, 140, 255)
            headerColor = Color3.fromRGB(20, 110, 225)
          end
          if hl.FillColor ~= targetColor then hl.FillColor = targetColor end

          local tag = MM2_espFolder:FindFirstChild(plr.Name .. "_Tag")
          if tag and tag:FindFirstChild("TagWindow") then
            local tagWin = tag.TagWindow
            if tagWin:FindFirstChild("TagHeader") then
              tagWin.TagHeader.BackgroundColor3 = headerColor
              local nameLbl = tagWin.TagHeader:FindFirstChild("NameLabel")
              if nameLbl then
                local roleText = "[INNOCENT]"
                if hasKnife then roleText = "[MURDERER]"
                elseif hasGun then roleText = "[SHERIFF]" end
                nameLbl.Text = roleText .. " " .. plr.DisplayName
              end
            end
          end
        end
      end
    end
  end

  -- MM2 Dropped Gun ESP
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
        hl.FillColor = Color3.fromRGB(255, 215, 0)
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

  -- MM2 Coin ESP
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

    for _, child in pairs(existingCoinTags) do
      child:Destroy()
    end
  else
    local coinFolder = workspace:FindFirstChild("CheatMenu_CoinESP")
    if coinFolder then coinFolder:ClearAllChildren() end
  end

  -- Auto-Shoot
  if MM2.autoShoot and tick() - MM2.lastShootTime >= 0.5 then
    local myChar = player.Character
    local hasGun = (myChar and myChar:FindFirstChild("Gun"))
        or (player.Backpack and player.Backpack:FindFirstChild("Gun"))
    local m = GetMM2Murderer()
    if hasGun and m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") then
      MM2.lastShootTime = tick()
      ShootMurdererSheriff()
    end
  end

  -- Anti-Stab dodge
  if MM2.antiStab and tick() - MM2.lastDodgeTime >= 0.8 then
    DodgeMurdererKnife()
  end

  -- Auto Grab Sheriff Gun
  if MM2.autoGrabGun and tick() - MM2.lastGrabTime >= 0.5 then
    if IsPlayerActive() then
      local gunPart = GetMM2DroppedGun()
      if gunPart then
        MM2.lastGrabTime = tick()
        AutoGrabSheriffGun()
      end
    end
  end

  -- Trap ESP update
  if MM2.trapESP then UpdateTrapESP() end

  -- Knife Aura
  if MM2.knifeAura and root then
    local myChar = player.Character
    local knife = (myChar and (myChar:FindFirstChild("Knife")
        or (myChar:FindFirstChildWhichIsA("Tool") and myChar:FindFirstChildWhichIsA("Tool").Name:lower():find("knife"))))
        or (player.Backpack and (player.Backpack:FindFirstChild("Knife")
          or (player.Backpack:FindFirstChildWhichIsA("Tool") and player.Backpack:FindFirstChildWhichIsA("Tool").Name:lower():find("knife"))))
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

  -- Auto-Collect Coins
  if MM2.autoCoins and root and not S.coinTweening then
    local hum = ctx.Core.GetHumanoid()
    if not hum or hum.Health <= 0 then return end
    local now = tick()
    if now - MM2.lastCoinTime < MM2.coinDelay then return end
    MM2.lastCoinTime = now

    local activeCoins = GetMM2ActiveCoins()
    if #activeCoins == 0 then return end

    local closestCoin, closestDist = nil, math.huge
    local rootPos = root.Position
    for _, coin in ipairs(activeCoins) do
      if coin and coin.Parent and coin:IsA("BasePart") and not collectedCoinSet[tostring(coin)] then
        local d = (coin.Position - rootPos).Magnitude
        if d < closestDist then closestDist = d; closestCoin = coin end
      end
    end
    if not closestCoin then ResetCoinCache(); return end

    S.coinTweening = true
    task.spawn(function()
      while MM2.autoCoins and S.coinTweening and not collectedCoinSet[tostring(closestCoin)] do
        local loopHum = ctx.Core.GetHumanoid()
        if not loopHum or loopHum.Health <= 0 then
          S.coinTweening = false; ResetCoinCache(); return
        end
        local char = GetCharacter()
        local tweenRoot = GetRoot()
        if not tweenRoot or not char then S.coinTweening = false; ResetCoinCache(); return end
        if not closestCoin.Parent or not closestCoin:IsDescendantOf(workspace) then
          MarkCoinCollected(closestCoin); S.coinTweening = false; ResetCoinCache(); return
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local originalPlatformStand = hum and hum.PlatformStand
        local originalCollide = {}
        for _, p in ipairs(char:GetDescendants()) do
          if p:IsA("BasePart") then
            originalCollide[p] = p.CanCollide
            p.CanCollide = false
            pcall(function() p.CollisionGroup = "CoinFarmGhost" end)
          end
        end
        if hum then hum.PlatformStand = true; task.wait(0.03) end

        local wasAnchored = tweenRoot.Anchored
        tweenRoot.Anchored = true
        tweenRoot.AssemblyLinearVelocity = Vector3.zero
        tweenRoot.AssemblyAngularVelocity = Vector3.zero

        local distance = (closestCoin.Position - tweenRoot.Position).Magnitude
        local speed = 300
        local tweenTime = math.clamp(distance / speed, 0.1, 2)
        local tween = TweenService_GS:Create(tweenRoot,
          TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
          { CFrame = closestCoin.CFrame * CFrame.new(0, -1, 0) })
        tween:Play()
        tween.Completed:Wait()

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

        tweenRoot.Anchored = wasAnchored
        if hum then hum.PlatformStand = originalPlatformStand end
        for p, wasCollide in pairs(originalCollide) do
          if p and p.Parent then p.CanCollide = wasCollide end
        end
        MarkCoinCollected(closestCoin)

        if not collectedHere then S.coinTweening = false; ResetCoinCache(); return end

        local activeCoins2 = GetMM2ActiveCoins()
        local nextCoin, nextDist = nil, math.huge
        local rPos = (GetRoot() and GetRoot().Position) or Vector3.new()
        for _, coin in ipairs(activeCoins2) do
          if coin and coin.Parent and coin:IsA("BasePart") and not collectedCoinSet[tostring(coin)] then
            local d = (coin.Position - rPos).Magnitude
            if d < nextDist then nextDist = d; nextCoin = coin end
          end
        end
        if not nextCoin then S.coinTweening = false; ResetCoinCache(); return end
        closestCoin = nextCoin
        task.wait(MM2.coinDelay)
      end
      S.coinTweening = false
      ResetCoinCache()
    end)
  end
end)

end -- close isMM2 block

-- ==================== MM2 FEATURES LIST ====================
local mm2FeatureList = {
  { isSection = true, name = "Role Radar & ESP" },
  {
    name = "MM2 Role ESP",
    desc = "Live Auto-Revealer: Murderer (Red), Sheriff (Blue), Innocents (Green)",
    isToggle = true,
    get = function() return MM2.roleESP end,
    toggle = function(state)
      MM2.roleESP = state
      if ctx.UI and ctx.UI.ToggleESP then ctx.UI.ToggleESP(state) end
    end,
  },
  {
    name = "Dropped Gun ESP",
    desc = "Gold 3D Box & Marker on dropped Sheriff gun",
    isToggle = true,
    get = function() return MM2.gunESP end,
    toggle = function(state) MM2.gunESP = state end,
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
    end,
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
    end,
  },
  { isSection = true, name = "Automation & Auras" },
  {
    name = "Auto Grab Sheriff Gun",
    desc = "Auto equip dropped Sheriff gun (Murderer only)",
    isToggle = true,
    get = function() return MM2.autoGrabGun end,
    toggle = function(state) MM2.autoGrabGun = state end,
  },
  {
    name = "Auto-Shoot Murderer",
    desc = "Auto equip gun and fire at Murderer when visible",
    isToggle = true,
    get = function() return MM2.autoShoot end,
    toggle = function(state) MM2.autoShoot = state end,
  },
  {
    name = "Magic Bullet",
    desc = "Auto-switch: gun=silent aim, knife=predicted throw",
    isToggle = true,
    get = function() return MM2.magicBullet end,
    toggle = function(state)
      MM2.magicBullet = state
      UpdateMagicBullet()
    end,
  },
  {
    name = "Knife Kill Aura",
    desc = "Auto-slash nearby innocents if you are Murderer",
    isToggle = true,
    get = function() return MM2.knifeAura end,
    toggle = function(state) MM2.knifeAura = state end,
  },
  {
    name = "Kill Aura Range",
    desc = "Radius for auto knife stabbing",
    hasSlider = true,
    configKey = "MM2.auraRadius",
    min = 5, max = 40,
    onChange = function(v) MM2.auraRadius = v end,
  },
  { isSection = true, name = "Survival & Defense" },
  {
    name = "Anti-Stab Ghost Dodge",
    desc = "Auto-teleport away if Murderer lunges with knife",
    isToggle = true,
    get = function() return MM2.antiStab end,
    toggle = function(state) MM2.antiStab = state end,
  },
  {
    name = "Auto-Collect Coins",
    desc = "Auto-farm all spawned coins across the active map",
    isToggle = true,
    get = function() return MM2.autoCoins end,
    toggle = function(state) MM2.autoCoins = state end,
  },
  {
    name = "Coin Farm Speed",
    desc = "Delay between collecting coin nodes",
    hasSlider = true,
    configKey = "MM2.coinDelay",
    min = 0.1, max = 1.0, isDecimal = true,
    onChange = function(v) MM2.coinDelay = v end,
  },
  { isSection = true, name = "Instant Actions" },
  { name = "Grab Dropped Gun",         desc = "Teleport directly to dropped gun",        isButton = true, action = GrabDroppedGun,      condition = IsPlayerActive },
  { name = "Shoot Murderer (Sheriff)", desc = "Equip gun and fire directly at Murderer", isButton = true, action = ShootMurdererSheriff },
  { name = "Kill All (Murderer)",      desc = "Auto-slash every innocent on the map",    isButton = true, action = KillAllMurderer },
  { name = "TP to Murderer",           desc = "Teleport behind active Murderer",         isButton = true, action = TeleportToMurderer },
  { name = "TP to Sheriff",            desc = "Teleport behind active Sheriff / Hero",   isButton = true, action = TeleportToSheriff },
  { name = "TP to Lobby",              desc = "Safely return to game lobby",             isButton = true, action = TeleportToLobby },
}

-- Register MM2 features into the registry (only if in MM2)
if isMM2 then
  ctx.Core.RegisterFeatures("MM2", mm2FeatureList)
end

-- ==================== BUILT-IN FEATURE LISTS (Combat/Movement/Visuals/Themes/Config/etc) ====================
local gameConfigRef = gameConfig
local SRef = S

local builtInFeatures = {
  Combat = {
    { isSection = true, name = "Targeting & Aim" },
    {
      name = "Aimbot (Hold RMB)",
      desc = "Smooth lock to nearest target while holding RMB",
      isToggle = true,
      get = function() return SRef.aimbot end,
      toggle = function(state) SRef.aimbot = state end,
    },
    { name = "Cycle Target Part", desc = "Cycles between Head, Root, Torso", isCyclePart = true },
    {
      name = "Triggerbot",
      desc = "Auto-click when crosshair detects player",
      isToggle = true,
      get = function() return SRef.triggerbot end,
      toggle = function(state) SRef.triggerbot = state end,
    },
    {
      name = "Auto Clicker",
      desc = "Continuous rapid left mouse clicks",
      isToggle = true,
      get = function() return SRef.autoClicker end,
      toggle = function(state) SRef.autoClicker = state end,
    },
    { isSection = true, name = "Combat Actions" },
    { name = "Reset Character", desc = "Instant respawn character", isButton = true, action = ctx.Core.ResetCharacter },
  },
  Movement = {
    { isSection = true, name = "CS2 Physics Engine" },
    {
      name = "CS2 Surfing",
      desc = "Ramp surf smoothly along angled walls",
      isToggle = true,
      get = function() return SRef.cs2Surf end,
      toggle = function(state) SRef.cs2Surf = state end,
    },
    {
      name = "CS2 Auto-Bhop",
      desc = "Perfect bunnyhopping on jump contact",
      isToggle = true,
      get = function() return SRef.cs2Bhop end,
      toggle = function(state) SRef.cs2Bhop = state end,
    },
    { name = "CS2 Surf Speed", desc = "Configure surf ramp velocity", hasSlider = true, configKey = "surfSpeed", min = 30, max = 200 },
    { name = "CS2 Bhop Accel", desc = "Air acceleration multiplier", hasSlider = true, configKey = "bhopAccel", min = 1.0, max = 3.5, isDecimal = true },
    { isSection = true, name = "Speed & Flight" },
    {
      name = "Speed Boost",
      desc = "Toggle customized walking velocity",
      isToggle = true,
      get = function() return SRef.speed end,
      toggle = function(state)
        SRef.speed = state
        local hum = ctx.Core.GetHumanoid()
        if hum then hum.WalkSpeed = state and gameConfigRef.walkSpeed or originalWalkSpeed end
      end,
    },
    { name = "Walk Speed Value", desc = "Configure walk speed amount",
      hasSlider = true, configKey = "walkSpeed", min = 16, max = 200,
      onChange = function(v) if SRef.speed then local hum = ctx.Core.GetHumanoid(); if hum then hum.WalkSpeed = v end end end },
    {
      name = "Fly Mode",
      desc = "Fly freely with WASD + Space/Shift",
      isToggle = true,
      get = function() return SRef.fly end,
      toggle = function(state)
        SRef.fly = state
        local hum = ctx.Core.GetHumanoid(); local root = ctx.Core.GetRoot()
        if hum then hum.PlatformStand = state end
        if state then
          if not SRef.flyBV and root then
            SRef.flyBV = Instance.new("BodyVelocity")
            SRef.flyBV.MaxForce = Vector3.new(40000, 40000, 40000)
            SRef.flyBV.Velocity = Vector3.new(0, 0, 0)
            SRef.flyBV.Parent = root
          end
        else
          if SRef.flyBV then SRef.flyBV:Destroy(); SRef.flyBV = nil end
        end
      end,
    },
    { name = "Fly Speed Value", desc = "Configure flight speed velocity", hasSlider = true, configKey = "flySpeed", min = 10, max = 200 },
    {
      name = "Jump Boost",
      desc = "Toggle customized jump power",
      isToggle = true,
      get = function() return SRef.jump end,
      toggle = function(state)
        SRef.jump = state
        local hum = ctx.Core.GetHumanoid()
        if hum then hum.JumpPower = state and gameConfigRef.jumpPower or originalJumpPower end
      end,
    },
    { name = "Jump Power Value", desc = "Configure jump power height",
      hasSlider = true, configKey = "jumpPower", min = 50, max = 300,
      onChange = function(v) if SRef.jump then local hum = ctx.Core.GetHumanoid(); if hum then hum.JumpPower = v end end end },
    {
      name = "Infinite Jump",
      desc = "Jump infinitely mid-air",
      isToggle = true,
      get = function() return SRef.infJump end,
      toggle = function(state) SRef.infJump = state end,
    },
    { isSection = true, name = "Physics & Traversal" },
    {
      name = "NoClip",
      desc = "Walk freely through walls",
      isToggle = true,
      get = function() return SRef.noclip end,
      toggle = function(state)
        SRef.noclip = state
        if not state then ctx.Core.RestoreCollision() end
      end,
    },
    {
      name = "Click Teleport",
      desc = "Ctrl + Click to teleport anywhere",
      isToggle = true,
      get = function() return SRef.clickTP end,
      toggle = function(state) SRef.clickTP = state end,
    },
    {
      name = "Low Gravity",
      desc = "Floaty moon physics",
      isToggle = true,
      get = function() return SRef.lowGravity end,
      toggle = function(state)
        SRef.lowGravity = state
        workspace.Gravity = state and 40 or ctx.Core.originalGravity
      end,
    },
    {
      name = "Hip Height Mod",
      desc = "Toggle elevated torso height",
      isToggle = true,
      get = function() return SRef.hipHeight end,
      toggle = function(state)
        SRef.hipHeight = state
        local hum = ctx.Core.GetHumanoid()
        if hum then hum.HipHeight = state and gameConfigRef.hipHeight or ctx.Core.originalHipHeight end
      end,
    },
    { name = "Hip Height Value", desc = "Configure character torso elevation",
      hasSlider = true, configKey = "hipHeight", min = 0, max = 20,
      onChange = function(v) if SRef.hipHeight then local hum = ctx.Core.GetHumanoid(); if hum then hum.HipHeight = v end end end },
    {
      name = "Spinbot",
      desc = "Rapidly spin character in place",
      isToggle = true,
      get = function() return SRef.spinbot end,
      toggle = function(state) SRef.spinbot = state end,
    },
    { name = "Spin Speed", desc = "Configure spinbot rotation velocity", hasSlider = true, configKey = "spinSpeed", min = 5, max = 100 },
    {
      name = "Anti-Fling",
      desc = "Prevent physics fling displacement",
      isToggle = true,
      get = function() return SRef.antiFling end,
      toggle = function(state) SRef.antiFling = state end,
    },
    { isSection = true, name = "Waypoints" },
    { name = "Save Position", desc = "Save current coordinates",         isButton = true, action = ctx.Core.SavePosition },
    { name = "Load Position", desc = "Teleport to saved coordinates",    isButton = true, action = ctx.Core.LoadPosition },
  },
  Visuals = {
    { isSection = true, name = "Player Visuals & ESP" },
    {
      name = "ESP Highlights",
      desc = "Highlight all players & distance",
      isToggle = true,
      get = function() return SRef.esp end,
      toggle = function(state)
        if ctx.UI and ctx.UI.ToggleESP then
          ctx.UI.ToggleESP(state)
        else
          SRef.esp = state
        end
      end,
    },
    { name = "ESP Fill Alpha",    desc = "Adjust highlight interior opacity", hasSlider = true, configKey = "espFillTrans", min = 0, max = 1, isDecimal = true, onChange = function() if ctx.UI and ctx.UI.UpdateESPTransparency then ctx.UI.UpdateESPTransparency() end end },
    { name = "ESP Outline Alpha", desc = "Adjust highlight outline opacity",  hasSlider = true, configKey = "espOutlineTrans", min = 0, max = 1, isDecimal = true, onChange = function() if ctx.UI and ctx.UI.UpdateESPTransparency then ctx.UI.UpdateESPTransparency() end end },
    {
      name = "Player Chams",
      desc = "3D Wall-penetrating body boxes",
      isToggle = true,
      get = function() return SRef.chams end,
      toggle = function(state)
        if ctx.UI and ctx.UI.ToggleChams then ctx.UI.ToggleChams(state) else SRef.chams = state end
      end,
    },
    { name = "Chams Alpha", desc = "Adjust 3D box opacity", hasSlider = true, configKey = "chamsTrans", min = 0, max = 1, isDecimal = true,
      onChange = function() if ctx.UI and ctx.UI.UpdateChamsTransparency then ctx.UI.UpdateChamsTransparency() end end },
    { isSection = true, name = "World & Lighting" },
    {
      name = "Fullbright",
      desc = "Max ambient light & clear visibility",
      isToggle = true,
      get = function() return SRef.fullbright end,
      toggle = function(state) ctx.Core.ToggleFullbright(state) end,
    },
    {
      name = "Night Mode (Eye Saver)",
      desc = "Dim world lighting & glare for night play",
      isToggle = true,
      get = function() return SRef.darkMode end,
      toggle = function(state) ctx.Core.ToggleDarkMode(state) end,
    },
    { name = "Night Dimness Level", desc = "Adjust how dark the world becomes",
      hasSlider = true, configKey = "nightDimness", min = 0.1, max = 0.8, isDecimal = true,
      onChange = function() if SRef.darkMode then ctx.Core.UpdateDarkMode() end end },
    {
      name = "No Fog", desc = "Remove all game atmosphere fog",
      isToggle = true,
      get = function() return SRef.noFog end,
      toggle = function(state) ctx.Core.ToggleNoFog(state) end,
    },
    {
      name = "No VFX", desc = "Kill particles, weather, bloom & screen FX",
      isToggle = true,
      get = function() return SRef.noVFX end,
      toggle = function(state) SRef.noVFX = state end,
    },
    {
      name = "FPS Boost",
      desc = "Strip textures, decals, shadows, Sky & post-FX for max framerate",
      isToggle = true,
      get = function() return SRef.fpsBoost end,
      toggle = function(state) ctx.Core.ToggleFPSBoost(state) end,
    },
    {
      name = "X-Ray Vision",
      desc = "Make world structures see-through",
      isToggle = true,
      get = function() return SRef.xRay end,
      toggle = function(state) ctx.Core.ToggleXRay(state) end,
    },
    {
      name = "Freecam Mode",
      desc = "Detached free spectator camera",
      isToggle = true,
      get = function() return SRef.freecam end,
      toggle = function(state) ctx.Core.ToggleFreecam(state) end,
    },
  },
  Trolling = {
    { isSection = true, name = "Direct Actions" },
    { name = "Teleport to Target", desc = "Teleport instantly to target player",        isButton = true, action = ctx.Core.TeleportToTarget },
    { name = "Fling Target",       desc = "Fling target player (self-fling protected)", isButton = true, action = ctx.Core.FlingTarget },
    { name = "Target Trap",        desc = "Trap player in forcefield cage",             isButton = true, action = ctx.Core.TargetTrap },
    { name = "Head Sit",           desc = "Sit on target player's head",                isButton = true, action = ctx.Core.HeadSitTarget },
    { isSection = true, name = "Persistent Toggles" },
    {
      name = "Spectate Target",
      desc = "Attach camera to follow target",
      isToggle = true,
      get = function() return SRef.spectate end,
      toggle = function(state)
        SRef.spectate = state
        if state and ctx.Core.selectedPlayer and ctx.Core.selectedPlayer.Character then
          local hum = ctx.Core.selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
          if hum then camera.CameraSubject = hum end
        else
          local myHum = ctx.Core.GetHumanoid()
          if myHum then camera.CameraSubject = myHum end
        end
      end,
    },
    {
      name = "Auto Follow Behind",
      desc = "Perfectly follow behind selected player",
      isToggle = true,
      get = function() return MM2.autoFollow end,
      toggle = function(state)
        MM2.autoFollow = state
        if state then StartAutoFollow() else StopAutoFollow() end
      end,
    },
    {
      name = "Platform Mode",
      desc = "Act as platform under selected player for infinite jumps",
      isToggle = true,
      get = function() return MM2.platformMode end,
      toggle = function(state)
        MM2.platformMode = state
        if state then StartPlatformMode() else StopPlatformMode() end
      end,
    },
    {
      name = "Boost Mode",
      desc = "Push selected player forward using your hitbox",
      isToggle = true,
      get = function() return MM2.boostMode end,
      toggle = function(state)
        MM2.boostMode = state
        if state then StartBoostMode() else StopBoostMode() end
      end,
    },
  },
  Server = {
    { isSection = true, name = "Server Navigation" },
    { name = "Rejoin Server", desc = "Re-connect to current server",        isButton = true, action = ctx.Core.Rejoin },
    { name = "Server Hop",    desc = "Hop to another active server instance", isButton = true, action = ctx.Core.ServerHop },
    { isSection = true, name = "Session & Utilities" },
    {
      name = "Anti-AFK Protection",
      desc = "Prevents 20-minute idle kick",
      isToggle = true,
      get = function() return ctx.Core.antiAFKActive and ctx.Core.antiAFKActive or false end,
      toggle = function(state) ctx.Core.ToggleAntiAFK(state) end,
    },
    { name = "Copy Server Job ID", desc = "Copy current JobId to clipboard",         isButton = true, action = ctx.Core.CopyJobId },
    { name = "Copy Place ID",      desc = "Copy active PlaceId to clipboard",        isButton = true, action = ctx.Core.CopyPlaceId },
    { name = "Copy Position",      desc = "Copy character coordinates to clipboard", isButton = true, action = ctx.Core.CopyPlayerPosition },
  },
  Config = {
    { isSection = true, name = "Camera Settings" },
    { name = "Camera FOV", desc = "Adjust field of view", hasSlider = true, configKey = "fov", min = 30, max = 120,
      onChange = function(v) camera.FieldOfView = v end },
    { isSection = true, name = "Aimbot Tuning" },
    { name = "Aimbot Smoothness",   desc = "Control aim lock speed",     hasSlider = true, configKey = "aimbotSmoothness", min = 0.05, max = 1.0, isDecimal = true },
    { name = "Aimbot FOV Radius",   desc = "Aimbot maximum search distance", hasSlider = true, configKey = "aimbotFOV", min = 50, max = 800 },
    { isSection = true, name = "Audio & Visuals" },
    { name = "Master Sound Volume", desc = "Adjust client game volume (ignoring VC)", hasSlider = true, configKey = "masterVolume", min = 0, max = 1, isDecimal = true, onChange = function(v) ctx.Core.SetMasterVolume(v) end },
    { name = "ESP Text Size", desc = "Adjust overhead name tag font size", hasSlider = true, configKey = "espTextSize", min = 8, max = 22 },
  },
  HUD = {
    { isSection = true, name = "Bottom HUD" },
    {
      name = "Show Bottom HUD",
      desc = "Toggle the bottom-left info HUD",
      isToggle = true,
      get = function() return SRef.hudEnabled end,
      toggle = function(state)
        if ctx.UI and ctx.UI.ToggleHUD then ctx.UI.ToggleHUD(state) end
      end,
    },
  },
  Music = {
    { isSection = true, name = "Music Colors" },
    {
      name = "Dynamic UI Colors from Cover",
      desc = "Auto-adapt GUI theme from song cover art palette",
      isToggle = true,
      get = function() return ctx.State.Music.dynamicColorEnabled end,
      toggle = function(state) ctx.State.Music.dynamicColorEnabled = state end,
    },
  },
}

-- Register each built-in tab
for tabName, tabFeats in pairs(builtInFeatures) do
  ctx.Core.RegisterFeatures(tabName, tabFeats)
end

-- Themes have dynamic action closures, so define here after ctx fully wired
local themesFeatures = {
  { isSection = true, name = "Aero & Retro Styles" },
  {
    name = "Windows Vista Aero",
    desc = "Authentic Glass & Slate Blue Theme",
    isButton = true,
    action = function()
      ctx.Config.currentThemeName = "Windows Vista Aero"
      ctx.Config.XP = ctx.Config.Themes[ctx.Config.currentThemeName]
      ctx.Core.SaveSettings()
      if ctx.UI and ctx.UI.BuildGUI then ctx.UI.BuildGUI() end
      if ctx.UI and ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
      if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end
    end,
  },
  {
    name = "Windows XP Luna",
    desc = "Classic Windows XP Luna Theme",
    isButton = true,
    action = function()
      ctx.Config.currentThemeName = "Windows XP Luna"
      ctx.Config.XP = ctx.Config.Themes[ctx.Config.currentThemeName]
      ctx.Core.SaveSettings()
      if ctx.UI and ctx.UI.BuildGUI then ctx.UI.BuildGUI() end
      if ctx.UI and ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
      if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end
    end,
  },
  { isSection = true, name = "Modern Colorways" },
  {
    name = "Dark Obsidian",
    desc = "Modern Matte Black & Cyan",
    isButton = true,
    action = function()
      ctx.Config.currentThemeName = "Dark Obsidian"
      ctx.Config.XP = ctx.Config.Themes[ctx.Config.currentThemeName]
      ctx.Core.SaveSettings()
      if ctx.UI and ctx.UI.BuildGUI then ctx.UI.BuildGUI() end
      if ctx.UI and ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
      if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end
    end,
  },
  {
    name = "Crimson Blood",
    desc = "Dark Ruby & Neon Red",
    isButton = true,
    action = function()
      ctx.Config.currentThemeName = "Crimson Blood"
      ctx.Config.XP = ctx.Config.Themes[ctx.Config.currentThemeName]
      ctx.Core.SaveSettings()
      if ctx.UI and ctx.UI.BuildGUI then ctx.UI.BuildGUI() end
      if ctx.UI and ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
      if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end
    end,
  },
  {
    name = "Emerald Cyber",
    desc = "Deep Forest & Neon Green",
    isButton = true,
    action = function()
      ctx.Config.currentThemeName = "Emerald Cyber"
      ctx.Config.XP = ctx.Config.Themes[ctx.Config.currentThemeName]
      ctx.Core.SaveSettings()
      if ctx.UI and ctx.UI.BuildGUI then ctx.UI.BuildGUI() end
      if ctx.UI and ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
      if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end
    end,
  },
  {
    name = "Royal Amethyst",
    desc = "Deep Purple & Gold",
    isButton = true,
    action = function()
      ctx.Config.currentThemeName = "Royal Amethyst"
      ctx.Config.XP = ctx.Config.Themes[ctx.Config.currentThemeName]
      ctx.Core.SaveSettings()
      if ctx.UI and ctx.UI.BuildGUI then ctx.UI.BuildGUI() end
      if ctx.UI and ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
      if ctx.UI and ctx.UI.BuildHUD then ctx.UI.BuildHUD() end
    end,
  },
}
ctx.Core.RegisterFeatures("Themes", themesFeatures)

-- Peer icon toggle (Trolling section extension? Put in Server as a quick toggle)
-- Stored as an additional feature for completeness
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
