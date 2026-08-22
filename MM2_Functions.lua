-- MM2_Functions.lua
-- Murder Mystery 2 Combat & ESP formatted into Quad Side-by-Side Columns

return function(Shared)
    local Players      = Shared.Services.Players
    local RunService   = Shared.Services.RunService
    local UserInput    = Shared.Services.UserInput
    local TweenSvc     = Shared.Services.TweenService
    local Workspace    = Shared.Services.Workspace

    local Player       = Shared.Player
    local Tabs         = Shared.Tabs or {}
    local QuadCols     = Shared.QuadCols or {}
    local MkSection    = Shared.MakeSection or function() end
    local MkToggle     = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkButton     = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab = Tabs["MM2"]
    local cols = QuadCols["MM2"]
    if not tab or not cols then
        warn("[MM2_Functions] Quad columns not found")
        return
    end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    local function getRole(plr)
        if not plr then return "Innocent" end
        local bp = plr:FindFirstChild("Backpack")
        local char = plr.Character
        local hasKnife = (bp and bp:FindFirstChild("Knife")) or (char and char:FindFirstChild("Knife"))
        local hasGun = (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver"))) or (char and (char:FindFirstChild("Gun") or char:FindFirstChild("Revolver")))
        if hasKnife then return "Murderer" end
        if hasGun then return "Sheriff" end
        return "Innocent"
    end

    local function getMurderer()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and getRole(plr) == "Murderer" then return plr end
        end
        return nil
    end

    local function getSheriff()
        for _, plr in ipairs(Players:GetPlayers()) do
            if getRole(plr) == "Sheriff" then return plr end
        end
        return nil
    end

    local function getHRP(plr)
        local c = (plr and plr.Character) or (plr == nil and Shared.Character)
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function getMyGun()
        local c = Shared.Character
        local bp = Player:FindFirstChild("Backpack")
        return (c and (c:FindFirstChild("Gun") or c:FindFirstChild("Revolver"))) or (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")))
    end

    local function getMyKnife()
        local c = Shared.Character
        local bp = Player:FindFirstChild("Backpack")
        return (c and c:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
    end

    -- ============================================================
    -- LEFT COLUMN: SHERIFF COMBAT & GUN GRABBER
    -- ============================================================
    MkSection(leftCol, "Sheriff Weaponry", 1)

    local hookedOldNamecall = nil
    MkToggle(leftCol, "Silent Aim (Sheriff)", "SilentAim", 2, function(state)
        if state then
            pcall(function()
                local mt = getrawmetatable(game)
                if mt and setreadonly then
                    setreadonly(mt, false)
                    hookedOldNamecall = mt.__namecall
                    mt.__namecall = newcclosure(function(self, ...)
                        local method = getnamecallmethod()
                        local args = {...}
                        if (method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList") and Shared.Flags["SilentAim"] then
                            local murd = getMurderer()
                            if murd and murd.Character then
                                local targetPart = murd.Character:FindFirstChild("HumanoidRootPart") or murd.Character:FindFirstChild("Head")
                                if targetPart then
                                    if method == "Raycast" then
                                        local origin = args[1]
                                        args[2] = (targetPart.Position - origin).Unit * 1000
                                        return hookedOldNamecall(self, unpack(args))
                                    elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
                                        return targetPart, targetPart.Position, Vector3.new(0, 1, 0), Enum.Material.Plastic
                                    end
                                end
                            end
                        end
                        return hookedOldNamecall(self, ...)
                    end)
                    setreadonly(mt, true)
                end
            end)
        else
            pcall(function()
                local mt = getrawmetatable(game)
                if mt and setreadonly and hookedOldNamecall then
                    setreadonly(mt, false)
                    mt.__namecall = hookedOldNamecall
                    setreadonly(mt, true)
                end
            end)
        end
    end)

    MkToggle(leftCol, "Auto Shoot Murderer", "AutoKillMurd", 3, function(state) end)

    RunService.Heartbeat:Connect(function()
        if not Shared.Flags["AutoKillMurd"] then return end
        local gun = getMyGun()
        if not gun then return end
        local murd = getMurderer()
        if not murd or not murd.Character then return end
        local mHRP = getHRP(murd)
        if not mHRP then return end

        if gun.Parent ~= Shared.Character then
            local hum = Shared.Character and Shared.Character:FindFirstChild("Humanoid")
            if hum then hum:EquipTool(gun) end
        end

        local shootRemote = gun:FindFirstChildWhichIsA("RemoteEvent")
        if shootRemote then
            shootRemote:FireServer(mHRP.Position)
        else
            gun:Activate()
        end
    end)

    MkSection(leftCol, "Dropped Gun", 10)

    local function findGunDrop()
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj.Name == "GunDrop" or (obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name == "Revolver")) then
                return obj
            end
        end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "GunDrop" then return obj end
        end
        return nil
    end

    local function grabGunNow()
        local drop = findGunDrop()
        local myHRP = getHRP()
        if not drop or not myHRP then return false end
        local targetPart = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart") or drop.PrimaryPart
        if targetPart then
            myHRP.CFrame = targetPart.CFrame
            task.wait(0.08)
            pcall(function()
                if firetouchinterest then
                    firetouchinterest(myHRP, targetPart, 0)
                    firetouchinterest(myHRP, targetPart, 1)
                end
            end)
            return true
        end
        return false
    end

    MkButton(leftCol, "[ Instant Grab Gun ]", 11, function()
        grabGunNow()
    end)

    MkToggle(leftCol, "Auto Grab Gun", "AutoGrabGun", 12, function(state) end)
    RunService.Heartbeat:Connect(function()
        if not Shared.Flags["AutoGrabGun"] then return end
        if getRole(Player) == "Innocent" then grabGunNow() end
    end)

    -- ============================================================
    -- RIGHT COLUMN: MURDERER COMBAT & ROLE ESP
    -- ============================================================
    MkSection(rightCol, "Murderer Combat", 1)

    -- Knife Prediction
    local predBeam, predAttachment0, predAttachment1
    MkToggle(rightCol, "Knife Trajectory Prediction", "KnifePred", 2, function(state)
        if not state then
            if predBeam then predBeam:Destroy(); predBeam = nil end
            if predAttachment0 then predAttachment0:Destroy(); predAttachment0 = nil end
            if predAttachment1 then predAttachment1:Destroy(); predAttachment1 = nil end
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not Shared.Flags["KnifePred"] then return end
        local murd = getMurderer()
        if not murd or not murd.Character then
            if predBeam then predBeam.Enabled = false end
            return
        end
        local mHRP = getHRP(murd)
        if not mHRP then return end

        if not predBeam or not predBeam.Parent then
            local p0 = Instance.new("Part")
            p0.Size = Vector3.new(0.2, 0.2, 0.2)
            p0.Transparency = 1; p0.Anchored = true; p0.CanCollide = false
            p0.Parent = Workspace

            local p1 = Instance.new("Part")
            p1.Size = Vector3.new(0.2, 0.2, 0.2)
            p1.Transparency = 1; p1.Anchored = true; p1.CanCollide = false
            p1.Parent = Workspace

            predAttachment0 = Instance.new("Attachment", p0)
            predAttachment1 = Instance.new("Attachment", p1)

            predBeam = Instance.new("Beam")
            predBeam.Color = ColorSequence.new(Color3.fromRGB(255, 30, 30))
            predBeam.Width0 = 0.4
            predBeam.Width1 = 0.1
            predBeam.Attachment0 = predAttachment0
            predBeam.Attachment1 = predAttachment1
            predBeam.FaceCamera = true
            predBeam.Parent = Workspace
        end

        predBeam.Enabled = true
        local vel = mHRP.Velocity
        local look = mHRP.CFrame.LookVector
        predAttachment0.Parent.Position = mHRP.Position
        predAttachment1.Parent.Position = mHRP.Position + (look * 25) + (vel * 0.3)
    end)

    -- Auto Kill All
    local autoKillLoop = false
    MkToggle(rightCol, "Auto Kill All (Murderer)", "AutoKillAll", 3, function(state)
        autoKillLoop = state
        if state then
            task.spawn(function()
                while autoKillLoop and Shared.Flags["AutoKillAll"] do
                    local knife = getMyKnife()
                    if knife then
                        if knife.Parent ~= Shared.Character then
                            local hum = Shared.Character and Shared.Character:FindFirstChild("Humanoid")
                            if hum then hum:EquipTool(knife) end
                            task.wait(0.1)
                        end
                        local myHRP = getHRP()
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if not autoKillLoop then break end
                            if plr ~= Player and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
                                local targetHRP = getHRP(plr)
                                if targetHRP and myHRP then
                                    myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 1.2)
                                    knife:Activate()
                                    local stabRemote = knife:FindFirstChildWhichIsA("RemoteEvent")
                                    if stabRemote then stabRemote:FireServer(targetHRP) end
                                    task.wait(0.12)
                                end
                            end
                        end
                    end
                    task.wait(0.3)
                end
            end)
        end
    end)

    MkSection(rightCol, "Visual ESP", 10)

    local espFolder = Instance.new("Folder")
    espFolder.Name   = "MM2_ESP_Holder"
    espFolder.Parent = Shared.GUI or CoreGui

    local espCache = {}
    local roleTheme = {
        Murderer = { Color = Color3.fromRGB(255, 35, 35),  Tag = "[MURDERER]" },
        Sheriff  = { Color = Color3.fromRGB(0, 150, 255),  Tag = "[SHERIFF]" },
        Innocent = { Color = Color3.fromRGB(40, 220, 40),  Tag = "[INNOCENT]" },
    }

    local function clearESP()
        for _, item in pairs(espCache) do
            if item.Highlight and item.Highlight.Parent then item.Highlight:Destroy() end
            if item.Billboard and item.Billboard.Parent then item.Billboard:Destroy() end
        end
        espCache = {}
    end

    MkToggle(rightCol, "Role ESP", "RoleESP", 11, function(state)
        if not state then clearESP() end
    end)

    RunService.RenderStepped:Connect(function()
        if not Shared.Flags["RoleESP"] then return end
        local myHRP = getHRP()

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player then
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")

                if char and hrp and hum and hum.Health > 0 then
                    local role = getRole(plr)
                    local theme = roleTheme[role] or roleTheme["Innocent"]
                    local dist = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0

                    local data = espCache[plr.Name]
                    if not data then
                        local h = Instance.new("Highlight")
                        h.Name = "HL_" .. plr.Name
                        h.FillTransparency = 0.5
                        h.OutlineTransparency = 0
                        h.Adornee = char
                        h.Parent = espFolder

                        local bb = Instance.new("BillboardGui")
                        bb.Name = "BB_" .. plr.Name
                        bb.Size = UDim2.new(0, 140, 0, 36)
                        bb.StudsOffset = Vector3.new(0, 3.2, 0)
                        bb.AlwaysOnTop = true
                        bb.Adornee = hrp
                        bb.Parent = espFolder

                        local tagFrame = Instance.new("Frame")
                        tagFrame.Size = UDim2.new(1, 0, 1, 0)
                        tagFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
                        tagFrame.BackgroundTransparency = 0.3
                        tagFrame.BorderSizePixel = 1
                        tagFrame.BorderColor3 = theme.Color
                        tagFrame.Parent = bb

                        local nameLbl = Instance.new("TextLabel")
                        nameLbl.Size                  = UDim2.new(1, 0, 0, 18)
                        nameLbl.Position              = UDim2.new(0, 0, 0, 2)
                        nameLbl.BackgroundTransparency = 1
                        nameLbl.Text                  = plr.DisplayName .. " (@" .. plr.Name .. ")"
                        nameLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
                        nameLbl.Font                  = Enum.Font.Code
                        nameLbl.TextSize              = 10
                        nameLbl.Parent                = tagFrame

                        local roleLbl = Instance.new("TextLabel")
                        roleLbl.Size                  = UDim2.new(1, 0, 0, 14)
                        roleLbl.Position              = UDim2.new(0, 0, 0, 18)
                        roleLbl.BackgroundTransparency = 1
                        roleLbl.Text                  = theme.Tag .. " [" .. tostring(dist) .. "m]"
                        roleLbl.TextColor3            = theme.Color
                        roleLbl.Font                  = Enum.Font.Code
                        roleLbl.TextSize              = 10
                        roleLbl.Parent                = tagFrame

                        data = { Highlight = h, Billboard = bb, NameLabel = nameLbl, RoleLabel = roleLbl, Frame = tagFrame }
                        espCache[plr.Name] = data
                    end

                    data.Highlight.Adornee = char
                    data.Highlight.FillColor = theme.Color
                    data.Highlight.OutlineColor = theme.Color
                    data.Billboard.Adornee = hrp
                    data.Frame.BorderColor3 = theme.Color
                    data.RoleLabel.TextColor3 = theme.Color
                    data.RoleLabel.Text = theme.Tag .. " [" .. tostring(dist) .. "m]"
                else
                    if espCache[plr.Name] then
                        if espCache[plr.Name].Highlight then espCache[plr.Name].Highlight:Destroy() end
                        if espCache[plr.Name].Billboard then espCache[plr.Name].Billboard:Destroy() end
                        espCache[plr.Name] = nil
                    end
                end
            end
        end

        for name, item in pairs(espCache) do
            if not Players:FindFirstChild(name) then
                if item.Highlight then item.Highlight:Destroy() end
                if item.Billboard then item.Billboard:Destroy() end
                espCache[name] = nil
            end
        end
    end)

    print("[MM2_Functions] Loaded -- Quad layout combat active")
end
