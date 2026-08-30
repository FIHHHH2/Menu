-- Combat_Handler.lua
-- Demise Gun Engine, Stamina Reduction & Combat Extension Module
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

    -- Internal Combat & Movement State
    local state = {
        -- Stamina & Movement
        InfiniteStamina  = false,
        StaminaReduction = 0, -- 0 = no reduction, 100 = 100% infinite stamina
        FastRegen        = false,
        SpeedBoost       = false,
        SpeedMultiplier  = 1.0,

        -- Weapon Mechanisms
        QuickReload      = false,
        AutoChamber      = false,
        CompleteAuto     = false,
        SemiAutoForce    = false,
        BurstMode        = false,
        NoRecoil         = false,
        FastFireRate     = false,
        CustomFireRate   = 0.05,
        BurstCount       = 3,
        BurstDelay       = 0.06,

        -- Active Runtime States
        IsShooting       = false,
        BurstActive      = false
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
                Muzzle.Play(tool.Name, localPlayer.Character)
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

    -- Input Listeners for Rapid Auto / Burst Actions
    local inputBeganConn = UserInput.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
    end

    -- UI Integration with Menu-Clean ("Run N Hide" Tab)
    local targetTab = (Shared.Tabs and Shared.Tabs["Run N Hide"]) or (Shared.Tabs and Shared.Tabs["Player"])
    if targetTab then
        local quad = targetTab:FindFirstChild("QuadGrid")
        local leftCol = (Shared.QuadCols and Shared.QuadCols["Run N Hide"] and Shared.QuadCols["Run N Hide"].Left) or (quad and quad:FindFirstChild("LeftCol")) or targetTab
        local rightCol = (Shared.QuadCols and Shared.QuadCols["Run N Hide"] and Shared.QuadCols["Run N Hide"].Right) or (quad and quad:FindFirstChild("RightCol")) or targetTab

        -- ── LEFT COLUMN: WEAPON MODS & STAMINA ─────────────────────
        if Shared.MakeSection then
            Shared.MakeSection(leftCol, "Stamina & Mobility", 1)
        end

        if Shared.MakeToggle then
            Shared.MakeToggle(leftCol, "Infinite Stamina (Zero Drain)", "InfiniteStamina", 2, function(val)
                state.InfiniteStamina = val
                applyStaminaState()
            end)

            Shared.MakeToggle(leftCol, "Fast Stamina Recovery", "FastStaminaRegen", 3, function(val)
                state.FastRegen = val
                applyStaminaState()
            end)

            Shared.MakeToggle(leftCol, "Sprint Speed Multiplier", "SpeedBoostToggle", 4, function(val)
                state.SpeedBoost = val
                applyStaminaState()
            end)
        end

        if Shared.MakeSlider then
            Shared.MakeSlider(leftCol, "Stamina Drain Reduction %", "StaminaReductionPct", 0, 100, 50, 5, function(val)
                state.StaminaReduction = val
                applyStaminaState()
            end)

            Shared.MakeSlider(leftCol, "Sprint Speed Factor", "SprintSpeedMult", 1, 3, 1, 6, function(val)
                state.SpeedMultiplier = val
                applyStaminaState()
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(leftCol, "Weapon Mechanisms", 10)
        end

        if Shared.MakeToggle then
            Shared.MakeToggle(leftCol, "Quick Reload & Instant Rack", "CombatQuickReload", 11, function(val)
                state.QuickReload = val
                state.AutoChamber = val
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Complete Auto (All Guns)", "CombatCompleteAuto", 12, function(val)
                state.CompleteAuto = val
                if val then
                    state.SemiAutoForce = false
                    state.BurstMode = false
                    if Shared.Toggles["CombatSemiAuto"] then Shared.Toggles["CombatSemiAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatBurstMode"] then Shared.Toggles["CombatBurstMode"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "The Semi-Auto Force", "CombatSemiAuto", 13, function(val)
                state.SemiAutoForce = val
                if val then
                    state.CompleteAuto = false
                    state.BurstMode = false
                    if Shared.Toggles["CombatCompleteAuto"] then Shared.Toggles["CombatCompleteAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatBurstMode"] then Shared.Toggles["CombatBurstMode"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "The Burst Rounds", "CombatBurstMode", 14, function(val)
                state.BurstMode = val
                if val then
                    state.CompleteAuto = false
                    state.SemiAutoForce = false
                    if Shared.Toggles["CombatCompleteAuto"] then Shared.Toggles["CombatCompleteAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatSemiAuto"] then Shared.Toggles["CombatSemiAuto"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Zero Recoil", "CombatNoRecoil", 15, function(val)
                state.NoRecoil = val
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Rapid Fire Rate Overclock", "CombatFastFire", 16, function(val)
                state.FastFireRate = val
                updateWeaponConfigs()
            end)
        end

        -- ── RIGHT COLUMN: TUNING & CONTROLS ────────────────────────
        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Firing Controls & Tuning", 1)
        end

        if Shared.MakeSlider then
            Shared.MakeSlider(rightCol, "Burst Shot Count", "CombatBurstCount", 2, 10, 3, 2, function(val)
                state.BurstCount = val
            end)

            Shared.MakeSlider(rightCol, "Burst Round Delay (ms)", "CombatBurstDelay", 20, 150, 60, 3, function(val)
                state.BurstDelay = val / 1000
            end)

            Shared.MakeSlider(rightCol, "Overclock Delay (ms)", "CombatFireDelay", 10, 250, 50, 4, function(val)
                state.CustomFireRate = val / 1000
                updateWeaponConfigs(true)
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Quick Actions", 10)
        end

        if Shared.MakeButton then
            Shared.MakeButton(rightCol, "Force Instant Reload", 11, function()
                local tool = getEquippedGun()
                if tool then
                    executeQuickReload(tool)
                    sendNotification("Run N Hide", "Weapon reloaded & chambered", true)
                else
                    sendNotification("Run N Hide", "No gun equipped", false)
                end
            end)

            Shared.MakeButton(rightCol, "Chamber Equipped Weapon", 12, function()
                local tool = getEquippedGun()
                if tool then
                    executeAutoChamber(tool)
                    sendNotification("Run N Hide", "Weapon chambered", true)
                else
                    sendNotification("Run N Hide", "No gun equipped", false)
                end
            end)

            Shared.MakeButton(rightCol, "Reset Stamina & Gun Configs", 13, function()
                state.InfiniteStamina = false
                state.StaminaReduction = 0
                state.SpeedBoost = false
                state.CompleteAuto = false
                state.SemiAutoForce = false
                state.BurstMode = false
                state.NoRecoil = false
                state.QuickReload = false
                state.FastFireRate = false

                for _, flag in ipairs({"InfiniteStamina", "FastStaminaRegen", "SpeedBoostToggle", "CombatQuickReload", "CombatCompleteAuto", "CombatSemiAuto", "CombatBurstMode", "CombatNoRecoil", "CombatFastFire"}) do
                    if Shared.Toggles[flag] then Shared.Toggles[flag].SetToggle(false, true) end
                end

                applyStaminaState()
                updateWeaponConfigs()
                sendNotification("Run N Hide", "All modifiers restored to default", true)
            end)
        end
    end

    updateWeaponConfigs(true)
    applyStaminaState()
    return state
end
