-- MM2_Functions.lua
-- Silent Aim, Knife Prediction, Role ESP, Grab Gun, Auto Kill

return function(Shared)
    local Players    = Shared.Services.Players
    local RunService = Shared.Services.RunService
    local UserInput  = Shared.Services.UserInput
    local TweenSvc   = Shared.Services.TweenService

    local Player     = Shared.Player
    local Tabs       = Shared.Tabs or {}
    local MkSection  = Shared.MakeSection or function() end
    local MkToggle   = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkButton   = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab = Tabs["MM2"]
    if not tab then
        warn("[MM2_Functions] Tab 'MM2' not found -- UI_Handler may have failed to load")
        return
    end

    -- HELPERS
    local function getRole(plr)
        local roleVal = plr:FindFirstChild("Role")
            or (plr.Character and plr.Character:FindFirstChild("Role"))
        return roleVal and roleVal.Value or "Innocent"
    end

    local function getMurderer()
        for _, plr in ipairs(Players:GetPlayers()) do
            local r = getRole(plr)
            if r == "Murderer" or r == "Murder" then
                return plr
            end
        end
    end

    local function getSheriff()
        for _, plr in ipairs(Players:GetPlayers()) do
            if getRole(plr) == "Sheriff" then return plr end
        end
    end

    local function getCharacterHRP(plr)
        return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    end

    local function getGun()
        local char = Shared.Character
        if not char then return end
        return char:FindFirstChild("Gun")
            or char:FindFirstChild("Revolver")
            or Player.Backpack:FindFirstChild("Gun")
            or Player.Backpack:FindFirstChild("Revolver")
    end

    -- SHERIFF / AIM
    MkSection(tab, "Sheriff / Aim", 1)

    local oldIndex
    MkToggle(tab, "Silent Aim (Sheriff)", "SilentAim", 2, function(state)
        if state then
            local mt = getmetatable(workspace) or {}
            oldIndex = mt.__index
            mt.__index = function(self, key)
                if key == "FindPartOnRayWithIgnoreList" or key == "FindPartOnRay" then
                    return function(ws, ray, ignore, ...)
                        local murderer = getMurderer()
                        if murderer and murderer ~= Player then
                            local hrp = getCharacterHRP(murderer)
                            if hrp then
                                local dist = (hrp.Position - ray.Origin).Magnitude
                                if dist < 500 then
                                    return hrp, hrp.Position, Vector3.new(0,1,0), Enum.Material.SmoothPlastic
                                end
                            end
                        end
                        return oldIndex(ws, key)(ws, ray, ignore, ...)
                    end
                end
                return oldIndex(self, key)
            end
        else
            local mt = getmetatable(workspace)
            if mt and oldIndex then mt.__index = oldIndex end
        end
    end)

    -- MURDERER
    MkSection(tab, "Murderer", 10)

    local knifeHighlight
    MkToggle(tab, "Knife Prediction", "KnifePred", 11, function(state)
        if knifeHighlight then knifeHighlight:Destroy(); knifeHighlight = nil end
        if state then
            RunService.Heartbeat:Connect(function()
                if not Shared.Flags["KnifePred"] then return end
                local murderer = getMurderer()
                if not murderer or not murderer.Character then return end
                local knife = murderer.Character:FindFirstChild("Knife")
                    or murderer.Character:FindFirstChildWhichIsA("Tool")
                if knife then
                    if not knifeHighlight or not knifeHighlight.Parent then
                        knifeHighlight = Instance.new("SelectionBox")
                        knifeHighlight.Color3          = Color3.fromRGB(255, 50, 50)
                        knifeHighlight.LineThickness   = 0.05
                        knifeHighlight.SurfaceTransparency = 0.5
                        knifeHighlight.SurfaceColor3   = Color3.fromRGB(255, 0, 0)
                        knifeHighlight.Adornee         = murderer.Character
                        knifeHighlight.Parent          = Shared.GUI
                    end
                end
            end)
        end
    end)

    MkToggle(tab, "Auto Kill Murderer", "AutoKillMurd", 12, function(state)
        RunService.Heartbeat:Connect(function()
            if not Shared.Flags["AutoKillMurd"] then return end
            local murd = getMurderer()
            if not murd or murd == Player then return end
            local mHRP = getCharacterHRP(murd)
            local myHRP = Shared.HumanoidRP
            if not mHRP or not myHRP then return end
            local gun = getGun()
            if gun then
                local fireRemote = gun:FindFirstChild("Fire")
                    or gun:FindFirstChildWhichIsA("RemoteEvent")
                    or gun:FindFirstChildWhichIsA("RemoteFunction")
                if fireRemote and fireRemote:IsA("RemoteEvent") then
                    fireRemote:FireServer(mHRP.Position)
                end
            end
        end)
    end)

    MkToggle(tab, "Auto Kill All (Murder)", "AutoKillAll", 13, function(state)
        RunService.Heartbeat:Connect(function()
            if not Shared.Flags["AutoKillAll"] then return end
            local myRole = getRole(Player)
            if myRole ~= "Murderer" and myRole ~= "Murder" then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player and plr.Character then
                    local myChar = Shared.Character
                    if not myChar then return end
                    local knife = myChar:FindFirstChild("Knife")
                        or myChar:FindFirstChildWhichIsA("Tool")
                    if knife then
                        local killRemote = knife:FindFirstChildWhichIsA("RemoteEvent")
                        if killRemote then
                            local targetHRP = getCharacterHRP(plr)
                            if targetHRP then
                                killRemote:FireServer(targetHRP)
                            end
                        end
                    end
                end
            end
        end)
    end)

    -- GUN
    MkSection(tab, "Gun", 20)

    MkToggle(tab, "Grab Gun (Innocent)", "GrabGun", 21, function(state)
        if not state then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj.Name == "Gun" or obj.Name == "Revolver") and obj:IsA("Tool") then
                if obj.Parent ~= Shared.Character then
                    local pickupRemote = obj:FindFirstChildWhichIsA("RemoteEvent")
                    if pickupRemote then
                        pickupRemote:FireServer()
                    else
                        local hrp = Shared.HumanoidRP
                        if hrp then
                            local pivot = obj:GetPivot()
                            hrp.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 3, 0))
                        end
                    end
                end
            end
        end
    end)

    local autoGrabConn
    MkToggle(tab, "Auto Grab Gun", "AutoGrabGun", 22, function(state)
        if autoGrabConn then autoGrabConn:Disconnect(); autoGrabConn = nil end
        if state then
            autoGrabConn = RunService.Heartbeat:Connect(function()
                if not Shared.Flags["AutoGrabGun"] then return end
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if (obj.Name == "Gun" or obj.Name == "Revolver") and obj:IsA("Tool") then
                        local remote = obj:FindFirstChildWhichIsA("RemoteEvent")
                        if remote then remote:FireServer() end
                    end
                end
            end)
        end
    end)

    -- ESP
    MkSection(tab, "ESP", 30)

    local espObjects = {}

    local function clearESP()
        for _, h in pairs(espObjects) do
            if h and h.Parent then h:Destroy() end
        end
        espObjects = {}
    end

    local roleColors = {
        Murderer = Color3.fromRGB(255, 50, 50),
        Murder   = Color3.fromRGB(255, 50, 50),
        Sheriff  = Color3.fromRGB(50, 150, 255),
        Innocent = Color3.fromRGB(50, 255, 100),
    }

    MkToggle(tab, "Role ESP", "RoleESP", 31, function(state)
        clearESP()
        if not state then return end
        RunService.Heartbeat:Connect(function()
            if not Shared.Flags["RoleESP"] then
                clearESP()
                return
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player and plr.Character then
                    local hrp = getCharacterHRP(plr)
                    if hrp then
                        if not espObjects[plr.Name] or not espObjects[plr.Name].Parent then
                            local h = Instance.new("Highlight")
                            h.Name            = "ESP_" .. plr.Name
                            local role        = getRole(plr)
                            h.FillColor       = roleColors[role] or roleColors["Innocent"]
                            h.OutlineColor    = h.FillColor
                            h.FillTransparency    = 0.5
                            h.OutlineTransparency = 0
                            h.Adornee         = plr.Character
                            h.Parent          = Shared.GUI
                            espObjects[plr.Name] = h
                        else
                            local role = getRole(plr)
                            espObjects[plr.Name].FillColor = roleColors[role] or roleColors["Innocent"]
                        end
                    end
                end
            end
        end)
    end)

    print("[MM2_Functions] Loaded")
end
