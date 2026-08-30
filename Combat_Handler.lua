-- Combat_Handler.lua
-- Demise Gun Engine & Combat Extension Module
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

    -- Resolve Demise Gun System Modules & Packets
    local gunSystemFolder = ReplicatedStorage:WaitForChild("GunSystem", 5)
    local modulesFolder = ReplicatedStorage:WaitForChild("Modules", 5)

    local gunsDataModule = gunSystemFolder and gunSystemFolder:FindFirstChild("Data") and gunSystemFolder.Data:FindFirstChild("Guns")
    local packetsModule = modulesFolder and modulesFolder:FindFirstChild("Data") and modulesFolder.Data:FindFirstChild("Packets")

    local Guns = gunsDataModule and require(gunsDataModule) or nil
    local Packets = packetsModule and require(packetsModule) or nil

    if not Guns or not Packets then
        warn("[Combat_Handler] Failed to locate Demise GunSystem modules or Packets.")
        return
    end

    -- Backup original weapon configs for clean restore
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

    -- Internal Combat State
    local state = {
        QuickReload    = false,
        AutoChamber    = false,
        CompleteAuto   = false,
        SemiAutoForce  = false,
        BurstMode      = false,
        NoRecoil       = false,
        FastFireRate   = false,
        CustomFireRate = 0.05,
        BurstCount     = 3,
        BurstDelay     = 0.06,
        IsShooting     = false,
        BurstActive    = false
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

    -- Apply modifications to the live Guns table
    local function updateWeaponConfigs()
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
    end

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

    -- Core Manual / Burst Firing Loop
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
            if state.AutoChamber or state.QuickReload then
                executeAutoChamber(tool)
                task.wait(0.05)
            else
                return false
            end
        end

        Packets.GunFireHit:Fire({
            Tool = tool,
            Origin = cam.CFrame.Position,
            Direction = cam.CFrame.LookVector
        })
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
            if state.AutoChamber and tool.Parent == localPlayer.Character and not tool:GetAttribute("Chambered") then
                task.wait(0.05)
                executeAutoChamber(tool)
            end
        end)

        local ammoConn = tool:GetAttributeChangedSignal("CurrentAmmo"):Connect(function()
            local ammo = tool:GetAttribute("CurrentAmmo")
            if typeof(ammo) == "number" and ammo <= 0 and state.QuickReload and tool.Parent == localPlayer.Character then
                task.wait(0.05)
                executeQuickReload(tool)
            end
        end)

        tool.AncestryChanged:Connect(function(_, parent)
            if parent == localPlayer.Character then
                if state.AutoChamber then
                    task.wait(0.1)
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
    end

    -- UI Integration with Menu-Clean ("Run N Hide" Tab)
    local targetTab = (Shared.Tabs and Shared.Tabs["Run N Hide"]) or (Shared.Tabs and Shared.Tabs["Player"])
    if targetTab then
        local quad = targetTab:FindFirstChild("QuadGrid")
        local leftCol = (Shared.QuadCols and Shared.QuadCols["Run N Hide"] and Shared.QuadCols["Run N Hide"].Left) or (quad and quad:FindFirstChild("LeftCol")) or targetTab
        local rightCol = (Shared.QuadCols and Shared.QuadCols["Run N Hide"] and Shared.QuadCols["Run N Hide"].Right) or (quad and quad:FindFirstChild("RightCol")) or targetTab

        if Shared.MakeSection then
            Shared.MakeSection(leftCol, "Weapon Mechanisms", 1)
        end

        if Shared.MakeToggle then
            Shared.MakeToggle(leftCol, "Quick Reload & Instant Rack", "CombatQuickReload", 2, function(val)
                state.QuickReload = val
                state.AutoChamber = val
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Complete Auto (All Guns)", "CombatCompleteAuto", 3, function(val)
                state.CompleteAuto = val
                if val then
                    state.SemiAutoForce = false
                    state.BurstMode = false
                    if Shared.Toggles["CombatSemiAuto"] then Shared.Toggles["CombatSemiAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatBurstMode"] then Shared.Toggles["CombatBurstMode"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "The Semi-Auto Force", "CombatSemiAuto", 4, function(val)
                state.SemiAutoForce = val
                if val then
                    state.CompleteAuto = false
                    state.BurstMode = false
                    if Shared.Toggles["CombatCompleteAuto"] then Shared.Toggles["CombatCompleteAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatBurstMode"] then Shared.Toggles["CombatBurstMode"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "The Burst Rounds", "CombatBurstMode", 5, function(val)
                state.BurstMode = val
                if val then
                    state.CompleteAuto = false
                    state.SemiAutoForce = false
                    if Shared.Toggles["CombatCompleteAuto"] then Shared.Toggles["CombatCompleteAuto"].SetToggle(false, true) end
                    if Shared.Toggles["CombatSemiAuto"] then Shared.Toggles["CombatSemiAuto"].SetToggle(false, true) end
                end
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Zero Recoil", "CombatNoRecoil", 6, function(val)
                state.NoRecoil = val
                updateWeaponConfigs()
            end)

            Shared.MakeToggle(leftCol, "Rapid Fire Rate Overclock", "CombatFastFire", 7, function(val)
                state.FastFireRate = val
                updateWeaponConfigs()
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Firing Controls & Tuning", 1)
        end

        if Shared.MakeSlider then
            Shared.MakeSlider(rightCol, "Burst Shot Count", "CombatBurstCount", 2, 10, 3, 2, function(val)
                state.BurstCount = val
            end)

            Shared.MakeSlider(rightCol, "Overclock Delay (ms)", "CombatFireDelay", 10, 250, 50, 3, function(val)
                state.CustomFireRate = val / 1000
                updateWeaponConfigs()
            end)
        end

        if Shared.MakeSection then
            Shared.MakeSection(rightCol, "Quick Actions", 4)
        end

        if Shared.MakeButton then
            Shared.MakeButton(rightCol, "Force Instant Reload", 5, function()
                local tool = getEquippedGun()
                if tool then
                    executeQuickReload(tool)
                    sendNotification("Run N Hide", "Weapon reloaded & chambered", true)
                else
                    sendNotification("Run N Hide", "No gun equipped", false)
                end
            end)

            Shared.MakeButton(rightCol, "Chamber Equipped Weapon", 6, function()
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

    updateWeaponConfigs()
    return state
end
