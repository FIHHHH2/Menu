-- Combat_Handler.lua
-- Demise Gun Engine, Aim Assist, Role Tracker, Boundary Breaker & Stamina Module
-- Compatible with Menu-Clean (Shared) and Standalone Execution

return function(Shared)
    Shared = Shared or {}
    local Services = Shared.Services or {}
    local Players = Services.Players or game:GetService("Players")
    local RunService = Services.RunService or game:GetService("RunService")
    local UserInput = Services.UserInput or game:GetService("UserInputService")
    local ReplicatedStorage = Services.Workspace and game:GetService("ReplicatedStorage") or game:GetService("ReplicatedStorage")

    local localPlayer = Shared.Player or Players.LocalPlayer
    local camera = workspace.CurrentCamera

    -- Resolve Demise Gun System & Movement Modules
    local gunSystemFolder = ReplicatedStorage:WaitForChild("GunSystem", 5)
    local modulesFolder = ReplicatedStorage:WaitForChild("Modules", 5)

    local gunsDataModule = gunSystemFolder and gunSystemFolder:FindFirstChild("Data") and gunSystemFolder.Data:FindFirstChild("Guns")
    local packetsModule = modulesFolder and modulesFolder:FindFirstChild("Data") and modulesFolder.Data:FindFirstChild("Packets")
    local configModule = modulesFolder and modulesFolder:FindFirstChild("Data") and modulesFolder.Data:FindFirstChild("Config")
    local muzzleLib = gunSystemFolder and gunSystemFolder:FindFirstChild("Libraries") and gunSystemFolder.Libraries:FindFirstChild("Muzzle")

    local Guns = gunsDataModule and require(gunsDataModule) or nil
    local Packets = packetsModule and require(packetsModule) or nil
    local Config = configModule and require(configModule) or nil
    local Muzzle = muzzleLib and require(muzzleLib) or nil

    if not Guns or not Packets then
        warn("[Combat_Handler] Failed to locate Demise GunSystem modules or Packets.")
        return
    end

    -- Backup original weapon and stamina configs for clean restoration
    local originalConfigs = {}
    for gunName, config in pairs(Guns) do
        originalConfigs[gunName] = {
            FireMode    = config.FireMode,
            FireRate    = config.FireRate,
            ReloadTime  = config.ReloadTime,
            ChamberTime = config.ChamberTime,
            Recoil      = config.Recoil,
            MaxAmmo     = config.MaxAmmo,
            Range       = config.Range
        }
    end

    local originalStamina = nil
    if Config and Config.Stamina then
        originalStamina = {
            Max        = Config.Stamina.Max,
            DrainRate  = Config.Stamina.DrainRate,
            RegenRate  = Config.Stamina.RegenRate,
            RegenDelay = Config.Stamina.RegenDelay
        }
    end

    -- Internal Combat, Aim Assist, Role Tracking, and Boundary Breaker State
    local state = {
        -- Stamina & Movement
        InfiniteStamina   = false,
        StaminaReduction  = 0, -- 0 to 100%
        FastRegen         = false,
        SpeedBoost        = false,
        SpeedMultiplier   = 1.0,

        -- Boundary & Barrier Breaker
        DisableBarriers   = false,
        DisableKillbricks = false,
        DoorPhase         = false,
        AntiVoidFloor     = false,
        DisabledParts     = {},
        VoidSafetyPlat    = nil,

        -- Weapon Mechanisms
        SilentGunAudio    = true,
        QuickReload       = false,
        AutoChamber       = false,
        CompleteAuto      = false,
        SemiAutoForce     = false,
        BurstMode         = false,
        NoRecoil          = false,
        FastFireRate      = false,
        CustomFireRate    = 0.05,
        BurstCount        = 3,
        BurstDelay        = 0.06,

        -- Aim Assist
        AimAssist         = false,
        AimAssistFOV      = false,
        AimRadius         = 140,
        AimSmoothing      = 5,
        AimTargetPart     = "Head", -- "Head" or "Torso"
        AimWallCheck      = true,
        AimPrioritizeThreat = true,
        AimKeyHeld        = false,

        -- Role Tracker
        RoleTracker       = false,
        RoleNotifier      = true,
        LastKnownRoles    = {},

        -- Active Runtime States
        IsShooting        = false,
        BurstActive       = false
    }

    local function sendNotification(title, msg, status)
        if Shared.Notify then
            Shared.Notify(title, msg, status)
        elseif Shared.SendNotification then
            Shared.SendNotification(title, msg, status)
        end
    end

    local function getEquippedGun()
        local char = localPlayer.Character
        if not char then return nil, nil end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and Guns[child.Name] then
                return child, Guns[child.Name]
            end
        end
        return nil, nil
    end

    -- Instant Re-equip helper so GunClient cleanly re-reads the modified Guns table
    local function refreshEquippedGun()
        local char = localPlayer.Character
        if not char then return end
        local tool = nil
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and Guns[child.Name] then
                tool = child
                break
            end
        end
        if tool then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:UnequipTools()
                task.wait(0.03)
                humanoid:EquipTool(tool)
            end
        end
    end

    -- Apply modifications to the live Guns table
    local function updateWeaponConfigs(skipRefresh)
        for gunName, config in pairs(Guns) do
            local original = originalConfigs[gunName]
            if not original then continue end

            -- Firemode handling
            if state.CompleteAuto then
                config.FireMode = "Auto"
            elseif state.SemiAutoForce then
                config.FireMode = "Semi"
            else
                config.FireMode = original.FireMode
            end

            -- Fire rate handling
            if state.FastFireRate then
                config.FireRate = state.CustomFireRate
            else
                config.FireRate = original.FireRate
            end

            -- Reload & Chamber times
            if state.QuickReload then
                config.ReloadTime = 0.05
                config.ChamberTime = 0.05
            else
                config.ReloadTime = original.ReloadTime
                config.ChamberTime = original.ChamberTime
            end

            -- Recoil handling
            if state.NoRecoil then
                config.Recoil = 0
            else
                config.Recoil = original.Recoil
            end
        end

        -- Mute or restore sound assets in ReplicatedStorage.Assets.Sounds.Firearms
        pcall(function()
            local soundFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Sounds") and ReplicatedStorage.Assets.Sounds:FindFirstChild("Firearms")
            if soundFolder then
                for _, gunFolder in ipairs(soundFolder:GetChildren()) do
                    for _, s in ipairs(gunFolder:GetDescendants()) do
                        if s:IsA("Sound") then
                            if state.SilentGunAudio then
                                if s:GetAttribute("OrigVol") == nil then
                                    s:SetAttribute("OrigVol", s.Volume)
                                end
                                s.Volume = 0
                            else
                                local orig = s:GetAttribute("OrigVol")
                                if orig ~= nil then
                                    s.Volume = orig
                                end
                            end
                        end
                    end
                end
            end
        end)

        if not skipRefresh then
            task.spawn(refreshEquippedGun)
        end
    end

    -- Apply Stamina & Movement Modifications
    local function applyStaminaState()
        local char = localPlayer.Character
        if char then
            if state.InfiniteStamina then
                char:SetAttribute("StamDrainMult", 0)
                char:SetAttribute("StamMult", 10)
            elseif state.StaminaReduction > 0 then
                local mult = math.clamp(1 - (state.StaminaReduction / 100), 0, 1)
                char:SetAttribute("StamDrainMult", mult)
                char:SetAttribute("StamMult", 1 + (state.StaminaReduction / 50))
            else
                char:SetAttribute("StamDrainMult", 1)
                char:SetAttribute("StamMult", 1)
            end

            if state.SpeedBoost and state.SpeedMultiplier > 1 then
                char:SetAttribute("SpeedMult", state.SpeedMultiplier)
            else
                char:SetAttribute("SpeedMult", 1)
            end
        end

        if Config and Config.Stamina and originalStamina then
            if state.InfiniteStamina then
                Config.Stamina.DrainRate = 0
                Config.Stamina.RegenRate = 100
                Config.Stamina.RegenDelay = 0
            elseif state.StaminaReduction > 0 then
                local factor = math.clamp(1 - (state.StaminaReduction / 100), 0, 1)
                Config.Stamina.DrainRate = originalStamina.DrainRate * factor
                if state.FastRegen then
                    Config.Stamina.RegenRate = originalStamina.RegenRate * 4
                    Config.Stamina.RegenDelay = 0.2
                end
            else
                Config.Stamina.DrainRate = originalStamina.DrainRate
                Config.Stamina.RegenRate = originalStamina.RegenRate
                Config.Stamina.RegenDelay = originalStamina.RegenDelay
            end
        end
    end

    -- Continuous Stamina & Character Watcher
    local staminaHeartbeatConn = RunService.Heartbeat:Connect(function()
        if state.InfiniteStamina or state.StaminaReduction > 0 or state.SpeedBoost then
            local char = localPlayer.Character
            if char then
                if state.InfiniteStamina and char:GetAttribute("StamDrainMult") ~= 0 then
                    char:SetAttribute("StamDrainMult", 0)
                    char:SetAttribute("StamMult", 10)
                end
                if state.SpeedBoost and char:GetAttribute("SpeedMult") ~= state.SpeedMultiplier then
                    char:SetAttribute("SpeedMult", state.SpeedMultiplier)
                end
            end
        end
    end)

    -- ── BOUNDARY & BARRIER BREAKER ENGINE ─────────────────────────
    local function neutralizeSinglePart(part)
        if not part:IsA("BasePart") then return end
        if part:IsDescendantOf(Players) then return end

        local name = part.Name:lower()
        local parentName = (part.Parent and part.Parent.Name or ""):lower()

        -- Killbricks / Death parts
        local isKill = name:find("kill") or parentName:find("kill") or name:find("death") or parentName:find("death") or name:find("lava") or name:find("hazard")
        if state.DisableKillbricks and isKill then
            part.CanTouch = false
            part.CanCollide = false
            pcall(function()
                for _, child in ipairs(part:GetDescendants()) do
                    if child:IsA("TouchTransmitter") or child:IsA("Script") or child:IsA("LocalScript") then
                        child:Destroy()
                    end
                end
            end)
            state.DisabledParts[part] = "Killbrick"
        end

        -- Invisible walls, bounds, clips, barriers
        local isBarrier = name:find("barrier") or name:find("bound") or name:find("border") or name:find("clip") or name:find("limit") or name:find("blocker") or name:find("invis")
        local isInvisWall = (part.Transparency >= 0.75 and part.CanCollide and not name:find("glass") and not name:find("window"))

        if state.DisableBarriers and (isBarrier or isInvisWall) and not isKill then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            state.DisabledParts[part] = "Barrier"
        end

        -- Door Hitboxes & Phase
        if state.DoorPhase and (name:find("doorhitbox") or (name:find("door") and part.Transparency >= 0.7)) then
            part.CanCollide = false
            state.DisabledParts[part] = "DoorHitbox"
        end
    end

    local function scanAndDisableBoundaries()
        local count = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                neutralizeSinglePart(obj)
                count = count + 1
            end
        end
        return count
    end

    -- Void Platform Safety
    local function updateVoidSafetyFloor()
        if state.AntiVoidFloor then
            if not state.VoidSafetyPlat or not state.VoidSafetyPlat.Parent then
                local plat = Instance.new("Part")
                plat.Name = "Fih_AntiVoidSafetyFloor"
                plat.Size = Vector3.new(4000, 10, 4000)
                plat.Position = Vector3.new(0, -60, 0)
                plat.Anchored = true
                plat.CanCollide = true
                plat.Transparency = 0.7
                plat.Material = Enum.Material.ForceField
                plat.Color = Color3.fromRGB(0, 180, 255)
                plat.Parent = workspace
                state.VoidSafetyPlat = plat
            end
        else
            if state.VoidSafetyPlat then
                pcall(function() state.VoidSafetyPlat:Destroy() end)
                state.VoidSafetyPlat = nil
            end
        end
    end

    -- Watch for newly spawned map parts or round changes
    local boundaryWatcherConn = workspace.DescendantAdded:Connect(function(child)
        if state.DisableBarriers or state.DisableKillbricks or state.DoorPhase then
            task.wait(0.05)
            neutralizeSinglePart(child)
        end
    end)

    local boundaryHeartbeat = RunService.Heartbeat:Connect(function()
        if state.DisableBarriers or state.DisableKillbricks or state.DoorPhase then
            for part, _ in pairs(state.DisabledParts) do
                if part and part.Parent then
                    if part.CanCollide then part.CanCollide = false end
                    if part.CanTouch then part.CanTouch = false end
                end
            end
        end
    end)

    -- Fast Reload and Auto-Chamber triggers
    local function executeQuickReload(tool)
        if not tool or not tool.Parent then return end
        Packets.GunReload:Fire({ Tool = tool })
        task.wait(0.08)
        Packets.GunChamber:Fire({ Tool = tool })
    end

    local function executeAutoChamber(tool)
        if not tool or not tool.Parent then return end
        if not tool:GetAttribute("Chambered") then
            Packets.GunChamber:Fire({ Tool = tool })
        end
    end

    -- Core Manual / Burst Firing Execution
    local function fireSingleRound(tool, config)
        if not tool or tool.Parent ~= localPlayer.Character then return false end
        local cam = workspace.CurrentCamera
        if not cam then return false end

        local ammo = tool:GetAttribute("CurrentAmmo")
        local currentAmmo = typeof(ammo) == "number" and ammo or (config.MaxAmmo or 0)
        if currentAmmo <= 0 then
            if state.QuickReload then
                executeQuickReload(tool)
            end
            return false
        end

        if not tool:GetAttribute("Chambered") then
            executeAutoChamber(tool)
            task.wait(0.05)
        end

        Packets.GunFireHit:Fire({
            Tool = tool,
            Origin = cam.CFrame.Position,
            Direction = cam.CFrame.LookVector
        })

        if Muzzle then
            pcall(function()
                if not state.SilentGunAudio then
                    Muzzle.Play(tool.Name, localPlayer.Character)
                else
                    Muzzle.PlayFlash(tool.Name, localPlayer.Character)
                end
            end)
        end

        return true
    end

    local function triggerBurst(tool, config)
        if state.BurstActive then return end
        state.BurstActive = true

        task.spawn(function()
            local shotsToFire = state.BurstCount or 3
            local delayTime = state.BurstDelay or 0.06

            for i = 1, shotsToFire do
                if not tool or tool.Parent ~= localPlayer.Character then break end
                local fired = fireSingleRound(tool, config)
                if not fired then break end
                task.wait(delayTime)
            end
            state.BurstActive = false
        end)
    end

    -- ── AIM ASSIST ENGINE ─────────────────────────────────────────
    local hasDrawing = (type(Drawing) == "table" and type(Drawing.new) == "function")
    local aimFovCircle = nil
    if hasDrawing then
        pcall(function()
            aimFovCircle = Drawing.new("Circle")
            aimFovCircle.Thickness = 1.5
            aimFovCircle.NumSides = 48
            aimFovCircle.Filled = false
            aimFovCircle.Transparency = 0.65
            aimFovCircle.Color = Color3.fromRGB(255, 60, 60)
            aimFovCircle.Visible = false
        end)
    end

    local function isPartVisible(origin, targetPart, ignoreList)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignoreList or {localPlayer.Character, targetPart.Parent}
        params.IgnoreWater = true

        local direction = targetPart.Position - origin
        local result = workspace:Raycast(origin, direction, params)
        return result == nil or result.Instance:IsDescendantOf(targetPart.Parent)
    end

    local function getPlayerRoleCategory(p)
        local role = p:GetAttribute("Role")
        local roleStr = tostring(role or ""):lower()
        if roleStr:find("murder") or roleStr:find("shoot") or roleStr:find("killer") then
            return "Threat", Color3.fromRGB(255, 45, 45)
        elseif roleStr:find("sheriff") or roleStr:find("armed") or roleStr:find("hero") then
            return "Sheriff", Color3.fromRGB(45, 140, 255)
        end
        local char = p.Character
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") and (item.Name:find("AK") or item.Name:find("AR") or item.Name:find("CZ") or item.Name:find("BLOCK") or item.Name:find("M249") or item.Name:find("UZI") or item.Name:find("Knife") or item.Name:find("Gun")) then
                    return "Armed", Color3.fromRGB(255, 100, 50)
                end
            end
        end
        return "Bystander", Color3.fromRGB(60, 220, 90)
    end

    local function getBestAimTarget()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local vp = cam.ViewportSize
        local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)
        local bestTarget = nil
        local shortestDist = state.AimRadius or 140
        local highestPriority = -1

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer and p.Character then
                local char = p.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                local targetPart = (state.AimTargetPart == "Head" and char:FindFirstChild("Head")) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")

                if hum and hum.Health > 0 and targetPart then
                    local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if screenDist <= (state.AimRadius or 140) then
                            local canSee = true
                            if state.AimWallCheck then
                                canSee = isPartVisible(cam.CFrame.Position, targetPart, {localPlayer.Character, char})
                            end

                            if canSee then
                                local roleCategory = getPlayerRoleCategory(p)
                                local priority = 0
                                if state.AimPrioritizeThreat and roleCategory == "Threat" then
                                    priority = 2
                                elseif state.AimPrioritizeThreat and (roleCategory == "Sheriff" or roleCategory == "Armed") then
                                    priority = 1
                                end

                                if priority > highestPriority or (priority == highestPriority and screenDist < shortestDist) then
                                    highestPriority = priority
                                    shortestDist = screenDist
                                    bestTarget = targetPart
                                end
                            end
                        end
                    end
                end
            end
        end

        return bestTarget
    end

    local aimRenderConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)

        if aimFovCircle then
            aimFovCircle.Position = screenCenter
            aimFovCircle.Radius = state.AimRadius or 140
            aimFovCircle.Visible = (state.AimAssist and state.AimAssistFOV) == true
        end

        if state.AimAssist and (state.AimKeyHeld or (state.IsShooting and state.CompleteAuto)) then
            local targetPart = getBestAimTarget()
            if targetPart then
                local targetCF = CFrame.lookAt(cam.CFrame.Position, targetPart.Position)
                local smoothness = math.max(1, state.AimSmoothing or 5)
                local lerpFactor = math.clamp(1 / smoothness, 0.05, 1)
                cam.CFrame = cam.CFrame:Lerp(targetCF, lerpFactor)
            end
        end
    end)

    -- ── ROLE TRACKER & REVEAL WATCHDOG ─────────────────────────────
    local function checkPlayerRoles()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                local role = p:GetAttribute("Role")
                local roleCategory, roleCol = getPlayerRoleCategory(p)
                local prevCategory = state.LastKnownRoles[p]

                if roleCategory ~= prevCategory then
                    state.LastKnownRoles[p] = roleCategory
                    if state.RoleNotifier and (roleCategory == "Threat" or roleCategory == "Armed") and prevCategory ~= nil then
                        sendNotification("ROLE ALERT", string.format("%s is %s!", p.DisplayName, roleCategory == "Threat" and "THE SHOOTER / KILLER" or "ARMED"), false)
                    end
                end
            end
        end
    end

    local roleWatcherConn = RunService.Heartbeat:Connect(function()
        if state.RoleTracker or state.RoleNotifier then
            checkPlayerRoles()
        end
    end)

    -- Input Listeners for Rapid Auto / Burst / Aim Assist Actions
    local inputBeganConn = UserInput.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            state.AimKeyHeld = true
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local tool, config = getEquippedGun()
            if not tool or not config then return end

            if state.BurstMode then
                triggerBurst(tool, config)
            elseif state.CompleteAuto and config.FireMode ~= "Minigun" then
                state.IsShooting = true
                task.spawn(function()
                    while state.IsShooting do
                        local currentTool, currentConfig = getEquippedGun()
                        if not currentTool or currentTool ~= tool then break end
                        local fired = fireSingleRound(currentTool, currentConfig)
                        if not fired then break end
                        local waitTime = state.FastFireRate and state.CustomFireRate or (currentConfig.FireRate or 0.1)
                        task.wait(math.max(0.03, waitTime))
                    end
                end)
            end
        elseif input.KeyCode == Enum.KeyCode.R then
            if state.QuickReload then
                local tool = getEquippedGun()
                if tool then
                    executeQuickReload(tool)
                end
            end
        end
    end)

    local inputEndedConn = UserInput.InputEnded:Connect(function(input, _)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            state.AimKeyHeld = false
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            state.IsShooting = false
        end
    end)

    -- Auto-chamber watcher on weapon equip / ammo change
    local function trackTool(tool)
        if not tool:IsA("Tool") or not Guns[tool.Name] then return end

        local chamberConn = tool:GetAttributeChangedSignal("Chambered"):Connect(function()
            if (state.AutoChamber or state.QuickReload) and tool.Parent == localPlayer.Character and not tool:GetAttribute("Chambered") then
                task.wait(0.04)
                executeAutoChamber(tool)
            end
        end)

        local ammoConn = tool:GetAttributeChangedSignal("CurrentAmmo"):Connect(function()
            local ammo = tool:GetAttribute("CurrentAmmo")
            if typeof(ammo) == "number" and ammo <= 0 and state.QuickReload and tool.Parent == localPlayer.Character then
                task.wait(0.04)
                executeQuickReload(tool)
            end
        end)

        tool.AncestryChanged:Connect(function(_, parent)
            if parent == localPlayer.Character then
                if state.AutoChamber or state.QuickReload then
                    task.wait(0.08)
                    executeAutoChamber(tool)
                end
            elseif not parent then
                chamberConn:Disconnect()
                ammoConn:Disconnect()
            end
        end)
    end

    local function scanBackpackAndChar()
        if localPlayer.Character then
            for _, item in ipairs(localPlayer.Character:GetChildren()) do
                trackTool(item)
            end
            localPlayer.Character.ChildAdded:Connect(trackTool)
            applyStaminaState()
        end
        local backpack = localPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                trackTool(item)
            end
            backpack.ChildAdded:Connect(trackTool)
        end
    end

    scanBackpackAndChar()
    local charAddedConn = localPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.3)
        scanBackpackAndChar()
    end)

    if Shared.AddCleanup then
        Shared.AddCleanup(inputBeganConn)
        Shared.AddCleanup(inputEndedConn)
        Shared.AddCleanup(charAddedConn)
        Shared.AddCleanup(staminaHeartbeatConn)
        Shared.AddCleanup(aimRenderConn)
        Shared.AddCleanup(roleWatcherConn)
        Shared.AddCleanup(boundaryWatcherConn)
        Shared.AddCleanup(boundaryHeartbeat)
        if state.VoidSafetyPlat then Shared.AddCleanup(function() pcall(function() state.VoidSafetyPlat:Destroy() end) end) end
        if aimFovCircle then Shared.AddCleanup(function() pcall(function() aimFovCircle:Remove() end) end) end
    end

    -- UI Integration with Menu-Clean ("Run N Hide" Tab)
    local targetTab = (Shared.Tabs and Shared.Tabs["Run N Hide"]) or (Shared.Tabs and Shared.Tabs["Player"])
    if targetTab then
        local quad = targetTab:FindFirstChild("QuadGrid")
        local leftCol = (Shared.QuadCols and Shared.QuadCols["Run N Hide"] and Shared.QuadCols["Run N Hide"].Left) or (quad and quad:FindFirstChild("LeftCol")) or targetTab
        local rightCol = (Shared.QuadCols and Shared.QuadCols["Run N Hide"] and Shared.QuadCols["Run N Hide"].Right) or (quad and quad:FindFirstChild("RightCol")) or targetTab

        -- ── LEFT COLUMN: AIM ASSIST & COMBAT ───────────────────────
        if Shared.MakeSection then
            Shared.MakeSection(leftCol, "Aim Assist Engine", 1)
        end

        if Shared.MakeToggle then
            Shared.MakeToggle(leftCol, "Aim Assist (Hold R-Click)", "CombatAimAssist", 2, function(val)
                state.AimAssist = val
            end)

            Shared.MakeToggle(leftCol, "Show Aim Assist FOV", "CombatAimFOV", 3, function(val)
                state.AimAssistFOV = val
            end)

            Shared.MakeToggle(leftCol, "Aim Wallcheck (Visible Only)", "CombatAimWallcheck", 4, function(val)
                state.AimWallCheck = val
            end)

            Shared.MakeToggle(leftCol, "Prioritize Threats / Shooters", "CombatAimThreats", 5, function(val)
                state.AimPrioritizeThreat = val
            end)

            Shared.MakeToggle(leftCol, "Target Head (Off = Torso)", "CombatAimHead", 6, function(val)
                state.AimTargetPart = val and "Head" or "Torso"
            end)
        end

        if Shared.MakeSlider then
            Shared.MakeSlider(leftCol, "Aim FOV Radius", "CombatAimRadius", 40, 350, 140, 7, function(val)
                state.AimRadius = val
            end)

            Shared.MakeSlider(leftCol, "Aim Smoothing (1=Snap)", "CombatAimSmooth", 1, 15, 5, 8, function(val)
                state.AimSmoothing = val
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(leftCol, "Weapon Mechanisms", 10)
        end

            Shared.MakeToggle(leftCol, "Silent Gun Audio (Mute Firing)", "CombatSilentAudio", 11, function(val)
                state.SilentGunAudio = val
                updateWeaponConfigs(true)
            end)

            Shared.MakeToggle(leftCol, "Quick Reload & Instant Rack", "CombatQuickReload", 12, function(val)
                state.QuickReload = val
                state.AutoChamber = val
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Complete Auto (All Guns)", "CombatCompleteAuto", 13, function(val)
                state.CompleteAuto = val
                if val then
                    state.SemiAutoForce = false
                    state.BurstMode = false
                    if Shared.Toggles["CombatSemiAuto"] then Shared.Toggles["CombatSemiAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatBurstMode"] then Shared.Toggles["CombatBurstMode"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "The Semi-Auto Force", "CombatSemiAuto", 14, function(val)
                state.SemiAutoForce = val
                if val then
                    state.CompleteAuto = false
                    state.BurstMode = false
                    if Shared.Toggles["CombatCompleteAuto"] then Shared.Toggles["CombatCompleteAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatBurstMode"] then Shared.Toggles["CombatBurstMode"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "The Burst Rounds", "CombatBurstMode", 15, function(val)
                state.BurstMode = val
                if val then
                    state.CompleteAuto = false
                    state.SemiAutoForce = false
                    if Shared.Toggles["CombatCompleteAuto"] then Shared.Toggles["CombatCompleteAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatSemiAuto"] then Shared.Toggles["CombatSemiAuto"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Zero Recoil", "CombatNoRecoil", 16, function(val)
                state.NoRecoil = val
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Rapid Fire Rate Overclock", "CombatFastFire", 17, function(val)
                state.FastFireRate = val
                updateWeaponConfigs()
            end)
        end

        -- ── RIGHT COLUMN: BOUNDS, ROLES, STAMINA & CONTROLS ────────
        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Map Bounds & Barrier Breaker", 1)
        end

        if Shared.MakeToggle then
            Shared.MakeToggle(rightCol, "Disable Map Bounds & Barriers", "DisableBarriers", 2, function(val)
                state.DisableBarriers = val
                if val then
                    local count = scanAndDisableBoundaries()
                    sendNotification("Bounds", string.format("Barriers & clips disabled (%d checked)", count), true)
                end
            end)

            Shared.MakeToggle(rightCol, "Disable Kill Bricks & Death Zones", "DisableKillbricks", 3, function(val)
                state.DisableKillbricks = val
                if val then
                    scanAndDisableBoundaries()
                    sendNotification("Bounds", "Killbricks & death zones neutralized", true)
                end
            end)

            Shared.MakeToggle(rightCol, "Door Phase (Pass Through Closed)", "DoorPhase", 4, function(val)
                state.DoorPhase = val
                if val then scanAndDisableBoundaries() end
            end)

            Shared.MakeToggle(rightCol, "Anti-Void Safety Floor", "AntiVoidFloor", 5, function(val)
                state.AntiVoidFloor = val
                updateVoidSafetyFloor()
            end)
        end

        if Shared.MakeButton then
            Shared.MakeButton(rightCol, "Audit & Disable All Bounds Now", 6, function()
                state.DisableBarriers = true
                state.DisableKillbricks = true
                state.DoorPhase = true
                if Shared.Toggles["DisableBarriers"] then Shared.Toggles["DisableBarriers"].SetToggle(true, true) end
                if Shared.Toggles["DisableKillbricks"] then Shared.Toggles["DisableKillbricks"].SetToggle(true, true) end
                if Shared.Toggles["DoorPhase"] then Shared.Toggles["DoorPhase"].SetToggle(true, true) end
                local count = scanAndDisableBoundaries()
                sendNotification("Boundary Audit", string.format("All invisible walls & killbricks purged (%d checked)", count), true)
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Role Tracker & Alerts", 10)
        end

        if Shared.MakeToggle then
            Shared.MakeToggle(rightCol, "Role Tracker Watcher", "CombatRoleTracker", 11, function(val)
                state.RoleTracker = val
                checkPlayerRoles()
            end)

            Shared.MakeToggle(rightCol, "Shooter / Killer Reveal Alert", "CombatRoleAlert", 12, function(val)
                state.RoleNotifier = val
            end)
        end

        if Shared.MakeButton then
            Shared.MakeButton(rightCol, "Scan All Player Roles Now", 13, function()
                checkPlayerRoles()
                local threats = {}
                local sheriffs = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= localPlayer then
                        local cat = getPlayerRoleCategory(p)
                        if cat == "Threat" or cat == "Armed" then
                            table.insert(threats, p.DisplayName)
                        elseif cat == "Sheriff" then
                            table.insert(sheriffs, p.DisplayName)
                        end
                    end
                end
                local summary = string.format("Threats: %s | Sheriffs: %s", #threats > 0 and table.concat(threats, ", ") or "None", #sheriffs > 0 and table.concat(sheriffs, ", ") or "None")
                sendNotification("Role Scan", summary, true)
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Stamina & Mobility", 20)
        end

        if Shared.MakeToggle then
            Shared.MakeToggle(rightCol, "Infinite Stamina (Zero Drain)", "InfiniteStamina", 21, function(val)
                state.InfiniteStamina = val
                applyStaminaState()
            end)

            Shared.MakeToggle(rightCol, "Fast Stamina Recovery", "FastStaminaRegen", 22, function(val)
                state.FastRegen = val
                applyStaminaState()
            end)

            Shared.MakeToggle(rightCol, "Sprint Speed Multiplier", "SpeedBoostToggle", 23, function(val)
                state.SpeedBoost = val
                applyStaminaState()
            end)
        end

        if Shared.MakeSlider then
            Shared.MakeSlider(rightCol, "Stamina Drain Reduction %", "StaminaReductionPct", 0, 100, 50, 24, function(val)
                state.StaminaReduction = val
                applyStaminaState()
            end)

            Shared.MakeSlider(rightCol, "Sprint Speed Factor", "SprintSpeedMult", 1, 3, 1, 25, function(val)
                state.SpeedMultiplier = val
                applyStaminaState()
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Firing Controls & Tuning", 30)
        end

        if Shared.MakeSlider then
            Shared.MakeSlider(rightCol, "Burst Shot Count", "CombatBurstCount", 2, 10, 3, 31, function(val)
                state.BurstCount = val
            end)

            Shared.MakeSlider(rightCol, "Burst Round Delay (ms)", "CombatBurstDelay", 20, 150, 60, 32, function(val)
                state.BurstDelay = val / 1000
            end)

            Shared.MakeSlider(rightCol, "Overclock Delay (ms)", "CombatFireDelay", 10, 250, 50, 33, function(val)
                state.CustomFireRate = val / 1000
                updateWeaponConfigs(true)
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Quick Actions", 40)
        end

        if Shared.MakeButton then
            Shared.MakeButton(rightCol, "Force Instant Reload", 41, function()
                local tool = getEquippedGun()
                if tool then
                    executeQuickReload(tool)
                    sendNotification("Run N Hide", "Weapon reloaded & chambered", true)
                else
                    sendNotification("Run N Hide", "No gun equipped", false)
                end
            end)

            Shared.MakeButton(rightCol, "Chamber Equipped Weapon", 42, function()
                local tool = getEquippedGun()
                if tool then
                    executeAutoChamber(tool)
                    sendNotification("Run N Hide", "Weapon chambered", true)
                else
                    sendNotification("Run N Hide", "No gun equipped", false)
                end
            end)
        end
    end

    updateWeaponConfigs(true)
    applyStaminaState()
    return state
end
