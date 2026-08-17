-- MM2Module.lua - MM2 logic, getters/setters, heartbeat tick loop
-- Owned by Bridge.lua; receives deps containing shared state and GUI module reference

local require = require
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local deps = ...
local S = deps.state
local MM2 = deps.MM2
local gameConfig = deps.gameConfig
local Music = deps.Music
local Themes = deps.Themes
local XP = deps.XP
local currentThemeName = deps.currentThemeName
local keybinds = deps.keybinds
local keybindRegistry = deps.keybindRegistry
local activeKeybindMap = deps.activeKeybindMap
local Connections = deps.Connections
local TrackConnection = deps.TrackConnection

local gui = deps.gui
local player = deps.player
local PlayerGui = deps.PlayerGui
local camera = deps.camera
local GetCharacter = deps.GetCharacter
local GetHumanoid = deps.GetHumanoid
local GetRoot = deps.GetRoot
local IsPlayerActive = deps.IsPlayerActive
local GetMM2Murderer = deps.GetMM2Murderer
local GetMM2Sheriff = deps.GetMM2Sheriff
local GetMM2DroppedGun = deps.GetMM2DroppedGun
local GrabDroppedGun = deps.GrabDroppedGun
local AutoGrabSheriffGun = deps.AutoGrabSheriffGun
local ResetCoinCache = deps.ResetCoinCache
local selectedPlayer = deps.selectedPlayer

-- MM2 utilities
local function GetMM2Murderer()
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local bp = p:FindFirstChild("Backpack")
		local hasKnife = (char and (char:FindFirstChild("Knife") or char:FindFirstChildWhichIsA("Tool") and (char:FindFirstChildWhichIsA("Tool").Name:lower():find("knife") or char:FindFirstChildWhichIsA("Tool"):FindFirstChild("KnifeServer"))))
			or
			(bp and (bp:FindFirstChild("Knife") or bp:FindFirstChildWhichIsA("Tool") and (bp:FindFirstChildWhichIsA("Tool").Name:lower():find("knife") or bp:FindFirstChildWhichIsA("Tool"):FindFirstChild("KnifeServer"))))
		if hasKnife then return p end
	end
	return nil
end

local function GetMM2Sheriff()
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local bp = p:FindFirstChild("Backpack")
		local hasGun = (char and (char:FindFirstChild("Gun") or char:FindFirstChildWhichIsA("Tool") and (char:FindFirstChildWhichIsA("Tool").Name:lower():find("gun") or char:FindFirstChildWhichIsA("Tool"):FindFirstChild("GunServer"))))
			or
			(bp and (bp:FindFirstChild("Gun") or bp:FindFirstChildWhichIsA("Tool") and (bp:FindFirstChildWhichIsA("Tool").Name:lower():find("gun") or bp:FindFirstChildWhichIsA("Tool"):FindFirstChild("GunServer"))))
		if hasGun then return p end
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

	local directGun = workspace:FindFirstChild("GunDrop")
	if directGun then
		local p = directGun:IsA("BasePart") and directGun or directGun:FindFirstChildWhichIsA("BasePart") or directGun:FindFirstChild("Handle")
		if p then
			cachedDroppedGun = p
			return p
		end
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child.Name ~= "Lobby" and child.Name ~= "Terrain" and not Players:GetPlayerFromCharacter(child) then
			local mapGun = child:FindFirstChild("GunDrop")
			if mapGun then
				local p = mapGun:IsA("BasePart") and mapGun or mapGun:FindFirstChildWhichIsA("BasePart") or mapGun:FindFirstChild("Handle")
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

-- Auto Follow Behind
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
		if myHum:GetState() ~= Enum.HumanoidStateType.Jumping and myHum:GetState() ~= Enum.HumanoidStateType.Freefall then
			myHum.Jump = true
		end
	elseif targetState == "climbing" then
		-- Climbing is automatic when touching climbable surfaces
	elseif targetState == "swimming" then
		-- Swimming is automatic in water
	end

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
	return stuckTimer > 1.5
end

local function FindClearPositionAround(targetPos, myRoot)
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

		local behindOffset = targetRoot.CFrame.LookVector * -5 + Vector3.new(0, 0, 0)
		local idealPos = targetRoot.Position + behindOffset

		local targetState = GetTargetMovementState(targetChar, targetHum, targetRoot)
		local targetMoveDir = targetHum.MoveDirection

		MimicMovementState(myHum, myRoot, targetState, targetMoveDir)

		local isStuck = CheckStuck(myRoot, dt)

		local distToIdeal = (idealPos - myRoot.Position).Magnitude

		local targetMoved = (targetRoot.Position - lastTargetPos).Magnitude > 3

		if targetMoved or isStuck or #pathWaypoints == 0 then
			lastTargetPos = targetRoot.Position

			if distToIdeal < 8 and not isStuck then
				pathWaypoints = {}
				currentWaypointIndex = 1
			else
				local waypoints = ComputePath(myRoot.Position, idealPos, myChar)
				if waypoints and #waypoints > 0 then
					pathWaypoints = waypoints
					currentWaypointIndex = 1
				else
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

		if #pathWaypoints > 0 and currentWaypointIndex <= #pathWaypoints then
			local waypoint = pathWaypoints[currentWaypointIndex]
			local waypointPos = waypoint.Position

			local toWaypoint = waypointPos - myRoot.Position
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
			if toIdeal.Magnitude > 2 then
				myHum:Move(toIdeal.Unit, false)
			else
				myHum:Move(Vector3.new(), false)
			end
		end

		myRoot.CFrame = CFrame.new(myRoot.Position, Vector3.new(targetRoot.Position.X, myRoot.Position.Y, targetRoot.Position.Z))
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

-- Platform Mode
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

-- Boost Mode
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

-- Magic Bullet
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
	if magicBulletWeaponService then return end
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

local function UpdateMagicBullet()
	if MM2.magicBullet then
		ApplyMagicBulletHook()
	else
		RemoveMagicBulletHook()
	end
end

-- Magic Projectile: Homing Knife Throw
local magicProjectileConn = nil
local magicProjectile = nil

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

local function CreateMagicProjectile(targetChar)
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
	rail.Lifetime = 0.4
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

	magicProjectile = CreateMagicProjectile(targetChar)
	if not magicProjectile then return end

	local startTime = tick()
	local lastVelocity = Vector3.zero
	local integralError = Vector3.zero

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

		if not targetRoot.Parent or not targetHum or targetHum.Health <= 0 then
			local newTarget = GetBestMagicBulletTarget()
			if newTarget then
				targetChar = newTarget
				targetRoot = newTarget:FindFirstChild("HumanoidRootPart")
				targetHum = newTarget:FindFirstChildOfClass("Humanoid")
			else
				magicProjectile:Destroy()
				magicProjectile = nil
				return
			end
		end

		if tick() - startTime > MAX_FLIGHT_TIME then
			magicProjectile:Destroy()
			magicProjectile = nil
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

		local align = magicProjectile:FindFirstChild("AlignOrientation")
		if align then
			align.CFrame = CFrame.lookAt(Vector3.zero, lastVelocity.Unit)
		end

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

-- Coin/Teleport Utilities
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
	local knife = (char and char:FindFirstChild("Knife")) or (player.Backpack and player.Backpack:FindFirstChild("Knife"))
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

-- Per-frame MM2 tick logic
local mm2HeartbeatConn = nil

local function RunMM2Logic(dt)
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

	if MM2.knifeAura and GetRoot() then
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
					local dist = (targetRoot.Position - GetRoot().Position).Magnitude
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

	if MM2.autoCoins and GetRoot() and not S.coinTweening then
		local hum = GetHumanoid()
		if not hum or hum.Health <= 0 then return end
		local now = tick()
		if now - MM2.lastCoinTime < MM2.coinDelay then return end
		MM2.lastCoinTime = now

		local activeCoins = GetMM2ActiveCoins()
		if #activeCoins == 0 then return end

		local closestCoin, closestDist = nil, math.huge
		local rootPos = GetRoot().Position
		for _, coin in ipairs(activeCoins) do
			if coin and coin.Parent and coin:IsA("BasePart") and not collectedCoinSet[tostring(coin)] then
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
			while MM2.autoCoins and S.coinTweening and not collectedCoinSet[tostring(closestCoin)] do
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
						p.CanCollide = false
						pcall(function() p.CollisionGroup = "CoinFarmGhost" end)
					end
				end
				if hum then
						hum.PlatformStand = true
						task.wait(0.03)
				end

				local wasAnchored = tweenRoot.Anchored
				tweenRoot.Anchored = true
				tweenRoot.AssemblyLinearVelocity = Vector3.zero
				tweenRoot.AssemblyAngularVelocity = Vector3.zero

				local distance = (closestCoin.Position - tweenRoot.Position).Magnitude
				local speed = 300
				local tweenTime = math.clamp(distance / speed, 0.1, 2)
				local tween = TweenService:Create(tweenRoot, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
					{ CFrame = closestCoin.CFrame * CFrame.new(0, -1, 0) })
					ween:Play()
					ween.Completed:Wait()

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
							if p and p.Parent then
								p.CanCollide = wasCollide
							end
						end

						MarkCoinCollected(closestCoin)

						if not collectedHere then
							S.coinTweening = false
							ResetCoinCache()
							return
						end

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
end

-- MM2 heartbeat connection
function MM2Module_Init(_deps)
	deps = _deps
	local _S = deps.state
	local _MM2 = deps.MM2
	local _gameConfig = deps.gameConfig
	local _Music = deps.Music
	local _Themes = deps.Themes
	local _XP = deps.XP
	local _currentThemeName = deps.currentThemeName
	local _keybinds = deps.keybinds
	local _keybindRegistry = deps.keybindRegistry
	local _activeKeybindMap = deps.activeKeybindMap
	local _Connections = deps.Connections
	local _TrackConnection = deps.TrackConnection

	local _gui = deps.gui
	local _player = deps.player
	local _PlayerGui = deps.PlayerGui
	local _camera = deps.camera
	local _GetCharacter = deps.GetCharacter
	local _GetHumanoid = deps.GetHumanoid
	local _GetRoot = deps.GetRoot
	local _IsPlayerActive = deps.IsPlayerActive
	local _GetMM2Murderer = deps.GetMM2Murderer
	local _GetMM2Sheriff = deps.GetMM2Sheriff
	local _GetMM2DroppedGun = deps.GetMM2DroppedGun
	local _GrabDroppedGun = deps.GrabDroppedGun
	local _AutoGrabSheriffGun = deps.AutoGrabSheriffGun
	local _ResetCoinCache = deps.ResetCoinCache
	local _selectedPlayer = deps.selectedPlayer

	S = _S
	MM2 = _MM2
	gameConfig = _gameConfig
	Music = _Music
	Themes = _Themes
	XP = _XP
	currentThemeName = _currentThemeName
	keybinds = _keybinds
	keybindRegistry = _keybindRegistry
	activeKeybindMap = _activeKeybindMap
	Connections = _Connections
	TrackConnection = _TrackConnection

	gui = _gui
	player = _player
	PlayerGui = _PlayerGui
	camera = _camera
	GetCharacter = _GetCharacter
	GetHumanoid = _GetHumanoid
	GetRoot = _GetRoot
	IsPlayerActive = _IsPlayerActive
	GetMM2Murderer = _GetMM2Murderer
	GetMM2Sheriff = _GetMM2Sheriff
	GetMM2DroppedGun = _GetMM2DroppedGun
	GrabDroppedGun = _GrabDroppedGun
	AutoGrabSheriffGun = _AutoGrabSheriffGun
	ResetCoinCache = _ResetCoinCache
	selectedPlayer = _selectedPlayer

	-- Set global callback for Bridge to call
	_G.UniMenu_ResetCoinCache = ResetCoinCache

	-- MM2 heartbeat connection
	if mm2HeartbeatConn then
		mm2HeartbeatConn:Disconnect()
	end
	mm2HeartbeatConn = TrackConnection(RunService.Heartbeat:Connect(function(dt)
		RunMM2Logic(dt)
	end))
end

-- Getter/setter API for GUI features
function MM2Module.GetRoleESP() return MM2.roleESP end
function MM2Module.SetRoleESP(v) MM2.roleESP = v if v then gui.ToggleESP(true) else gui.UpdateESPTheme() end end
function MM2Module.GetGunESP() return MM2.gunESP end
function MM2Module.SetGunESP(v) MM2.gunESP = v end
function MM2Module.GetTrapESP() return MM2.trapESP end
function MM2Module.SetTrapESP(v) MM2.trapESP = v if not v and S.espFolder then for _, ch in ipairs(S.espFolder:GetChildren()) do if ch.Name:find("Trap_") then ch:Destroy() end end end end
function MM2Module.GetCoinESP() return MM2.coinESP end
function MM2Module.SetCoinESP(v) MM2.coinESP = v if not v then local coinFolder = workspace:FindFirstChild("CheatMenu_CoinESP") if coinFolder then coinFolder:ClearAllChildren() end end end
function MM2Module.GetAutoShoot() return MM2.autoShoot end
function MM2Module.SetAutoShoot(v) MM2.autoShoot = v end
function MM2Module.GetMagicBullet() return MM2.magicBullet end
function MM2Module.SetMagicBullet(v) MM2.magicBullet = v UpdateMagicBullet() end
function MM2Module.GetAntiStab() return MM2.antiStab end
function MM2Module.SetAntiStab(v) MM2.antiStab = v end
function MM2Module.GetAutoCoins() return MM2.autoCoins end
function MM2Module.SetAutoCoins(v) MM2.autoCoins = v end
function MM2Module.GetAutoGrabGun() return MM2.autoGrabGun end
function MM2Module.SetAutoGrabGun(v) MM2.autoGrabGun = v end
function MM2Module.GetKnifeAura() return MM2.knifeAura end
function MM2Module.SetKnifeAura(v) MM2.knifeAura = v end
function MM2Module.GetAutoFollow() return MM2.autoFollow end
function MM2Module.SetAutoFollow(v) MM2.autoFollow = v if v then StartAutoFollow() else StopAutoFollow() end end
function MM2Module.GetPlatformMode() return MM2.platformMode end
function MM2Module.SetPlatformMode(v) MM2.platformMode = v if v then StartPlatformMode() else StopPlatformMode() end end
function MM2Module.GetBoostMode() return MM2.boostMode end
function MM2Module.SetBoostMode(v) MM2.boostMode = v if v then StartBoostMode() else StopBoostMode() end end
function MM2Module.GetAuraRadius() return MM2.auraRadius end
function MM2Module.SetAuraRadius(v) MM2.auraRadius = v end
function MM2Module.GetCoinDelay() return MM2.coinDelay end
function MM2Module.SetCoinDelay(v) MM2.coinDelay = v end
function MM2Module.GrabDroppedGun() GrabDroppedGun() end
function MM2Module.AutoGrabSheriffGun() AutoGrabSheriffGun() end
function MM2Module.ResetCoinCache() ResetCoinCache() end
function MM2Module.TeleportToMurderer() TeleportToMurderer() end
function MM2Module.TeleportToSheriff() TeleportToSheriff() end
function MM2Module.TeleportToLobby() TeleportToLobby() end
function MM2Module.KillAllMurderer() KillAllMurderer() end
function MM2Module.ShootMurdererSheriff() ShootMurdererSheriff() end

return {
	Init = MM2Module_Init,
	GetRoleESP = MM2Module.GetRoleESP,
	SetRoleESP = MM2Module.SetRoleESP,
	GetGunESP = MM2Module.GetGunESP,
	SetGunESP = MM2Module.SetGunESP,
	GetTrapESP = MM2Module.GetTrapESP,
	SetTrapESP = MM2Module.SetTrapESP,
	GetCoinESP = MM2Module.GetCoinESP,
	SetCoinESP = MM2Module.SetCoinESP,
	GetAutoShoot = MM2Module.GetAutoShoot,
	SetAutoShoot = MM2Module.SetAutoShoot,
	GetMagicBullet = MM2Module.GetMagicBullet,
	SetMagicBullet = MM2Module.SetMagicBullet,
	GetAntiStab = MM2Module.GetAntiStab,
	SetAntiStab = MM2Module.SetAntiStab,
	GetAutoCoins = MM2Module.GetAutoCoins,
	SetAutoCoins = MM2Module.SetAutoCoins,
	GetAutoGrabGun = MM2Module.GetAutoGrabGun,
	SetAutoGrabGun = MM2Module.SetAutoGrabGun,
	GetKnifeAura = MM2Module.GetKnifeAura,
	SetKnifeAura = MM2Module.SetKnifeAura,
	GetAutoFollow = MM2Module.GetAutoFollow,
	SetAutoFollow = MM2Module.SetAutoFollow,
	GetPlatformMode = MM2Module.GetPlatformMode,
	SetPlatformMode = MM2Module.SetPlatformMode,
	GetBoostMode = MM2Module.GetBoostMode,
	SetBoostMode = MM2Module.SetBoostMode,
	GetAuraRadius = MM2Module.GetAuraRadius,
	SetAuraRadius = MM2Module.SetAuraRadius,
	GetCoinDelay = MM2Module.GetCoinDelay,
	SetCoinDelay = MM2Module.SetCoinDelay,
	GrabDroppedGun = MM2Module.GrabDroppedGun,
	AutoGrabSheriffGun = MM2Module.AutoGrabSheriffGun,
	ResetCoinCache = MM2Module.ResetCoinCache,
	TeleportToMurderer = MM2Module.TeleportToMurderer,
	TeleportToSheriff = MM2Module.TeleportToSheriff,
	TeleportToLobby = MM2Module.TeleportToLobby,
	KillAllMurderer = MM2Module.KillAllMurderer,
	ShootMurdererSheriff = MM2Module.ShootMurdererSheriff,
}