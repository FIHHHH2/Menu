-- MM2_Functions.lua
-- Optimized Zero-Lag Combat Engine: Unrestricted Kill Aura, Non-Intrusive Silent Aim,
-- Throttled Gun Drop Scanner, Knife Prediction, and Role ESP

return function(Shared)
    local Players    = Shared.Services.Players
    local RunService = Shared.Services.RunService
    local UserInput  = Shared.Services.UserInput
    local TweenSvc   = Shared.Services.TweenService
    local Workspace  = Shared.Services.Workspace

    local Player    = Shared.Player
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider  = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab  = Tabs["MM2"]
    local cols = QuadCols["MM2"]
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    -- ── Helpers ──────────────────────────────────────────────────
    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
    local function getHuman() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

    local function isAlive(plr)
        if not plr or not plr.Character then return false end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health > 0
    end

    local function selfAliveInRound()
        local c = getChar()
        if not c then return false end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local lobby = Workspace:FindFirstChild("Lobby")
        if lobby and c:IsDescendantOf(lobby) then return false end
        return true
    end

    local function getRole(plr)
        if not plr then return "Innocent" end
        local bp   = plr:FindFirstChild("Backpack")
        local char = plr.Character
        if (bp and bp:FindFirstChild("Knife")) or (char and char:FindFirstChild("Knife")) then return "Murderer" end
        if (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")))
        or (char and (char:FindFirstChild("Gun") or char:FindFirstChild("Revolver"))) then return "Sheriff" end
        return "Innocent"
    end

    local function getMurderer()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) and getRole(plr) == "Murderer" then
                return plr
            end
        end
        return nil
    end

    local function getSheriff()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) and getRole(plr) == "Sheriff" then
                return plr
            end
        end
        return nil
    end

    local function getMyKnife()
        local c = getChar(); local bp = Player:FindFirstChild("Backpack")
        return (c and c:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
    end
    local function getMyGun()
        local c = getChar(); local bp = Player:FindFirstChild("Backpack")
        return (c and (c:FindFirstChild("Gun") or c:FindFirstChild("Revolver")))
            or (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")))
    end

    local function getSilentAimTarget()
        local myHRP = getHRP()
        if not myHRP then return nil end

        local myRole = getRole(Player)
        if myRole ~= "Murderer" then
            local murd = getMurderer()
            if murd and murd.Character then
                local mHRP = murd.Character:FindFirstChild("HumanoidRootPart")
                if mHRP then return mHRP end
            end
        end

        local best, bestDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) then
                local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then
                    local d = (tHRP.Position - myHRP.Position).Magnitude
                    if d < bestDist then bestDist = d; best = tHRP end
                end
            end
        end
        return best
    end

    -- ── Cached Gun Drop Scanner (Zero Lag) ─────────────────────────
    local cachedGunDrop = nil
    task.spawn(function()
        while true do
            if Shared.Flags["AutoGrabGun"] or Shared.Flags["GunESP"] then
                local found = nil
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if (obj.Name == "GunDrop" or (obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name == "Revolver")))
                    and obj.Parent ~= Player.Backpack and (not getChar() or obj.Parent ~= getChar()) then
                        found = obj:FindFirstChildOfClass("BasePart") or (obj:IsA("BasePart") and obj)
                        if found then break end
                    end
                end
                if not found then
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj.Name == "GunDrop" then
                            found = obj:FindFirstChildOfClass("BasePart") or (obj:IsA("BasePart") and obj)
                            if found then break end
                        end
                    end
                end
                cachedGunDrop = found
            end
            task.wait(0.35)
        end
    end)

    -- ── LEFT COLUMN: KILL AURA & SILENT AIM ───────────────────────
    MkSection(leftCol, "Kill Aura Engine", 1)

    local auraBoxPart = nil

    local function updateVisualizer(hrp, radius)
        if not auraBoxPart then
            auraBoxPart = Instance.new("Part")
            auraBoxPart.Name          = "Fih_AuraBox"
            auraBoxPart.Anchored      = true
            auraBoxPart.CanCollide    = false
            auraBoxPart.CanTouch      = false
            auraBoxPart.CastShadow    = false
            auraBoxPart.Transparency  = 0.75
            auraBoxPart.Material      = Enum.Material.ForceField
            auraBoxPart.BrickColor    = BrickColor.new("Bright red")
            auraBoxPart.Parent        = Workspace

            local sel = Instance.new("SelectionBox")
            sel.Name          = "AuraSelection"
            sel.Adornee       = auraBoxPart
            sel.Color3        = Color3.fromRGB(255, 50, 50)
            sel.SurfaceColor3 = Color3.fromRGB(255, 30, 30)
            sel.SurfaceTransparency = 0.85
            sel.LineThickness = 0.05
            sel.Parent        = auraBoxPart
        end
        auraBoxPart.Size   = Vector3.new(radius * 2, radius * 2, radius * 2)
        auraBoxPart.CFrame = hrp.CFrame
    end

    local function clearVisualizer()
        if auraBoxPart then
            auraBoxPart:Destroy()
            auraBoxPart = nil
        end
    end

    MkToggle(leftCol, "Kill Aura Box Visualizer", "KillAuraBox", 2, function(state)
        if not state then
            clearVisualizer()
        end
    end)

    MkSlider(leftCol, "Aura Radius (studs)", "KillAuraRadius", 5, 80, 20, 3, function(val)
        Shared.Flags["KillAuraRadius"] = val
        if Shared.Flags["KillAuraBox"] then
            local hrp = getHRP()
            if hrp then updateVisualizer(hrp, val) end
        end
    end)

    MkToggle(leftCol, "Kill Aura (All Players)", "KillAura", 4, function(state)
    end)

    -- Dedicated Independent Visualizer Loop (Always works regardless of KillAura attack state)
    RunService.RenderStepped:Connect(function()
        if Shared.Flags["KillAuraBox"] then
            local hrp = getHRP()
            if hrp then
                local radius = Shared.Flags["KillAuraRadius"] or 20
                updateVisualizer(hrp, radius)
            else
                clearVisualizer()
            end
        else
            clearVisualizer()
        end
    end)

    -- Attack Loop
    RunService.Heartbeat:Connect(function()
        if not Shared.Flags["KillAura"] then return end
        if not selfAliveInRound() then return end

        local hrp = getHRP()
        if not hrp then return end
        local radius = Shared.Flags["KillAuraRadius"] or 20

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) then
                local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP and (tHRP.Position - hrp.Position).Magnitude <= radius then
                    local knife = getMyKnife()
                    if knife then
                        local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildOfClass("BasePart")
                        if handle then
                            pcall(function() firetouchinterest(tHRP, handle, 0) end)
                            pcall(function() firetouchinterest(tHRP, handle, 1) end)
                        end
                    end
                    local gun = getMyGun()
                    if gun then
                        local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart")
                        if handle then
                            pcall(function() firetouchinterest(tHRP, handle, 0) end)
                        end
                    end
                    pcall(function()
                        local kk = game:GetService("ReplicatedStorage").Remotes.Gameplay:FindFirstChild("KnifeKill")
                        if kk and getMyKnife() then kk:Fire() end
                        local gk = game:GetService("ReplicatedStorage").Remotes.Gameplay:FindFirstChild("GunKill")
                        if gk and getMyGun() then gk:Fire() end
                    end)
                end
            end
        end
    end)

    MkSection(leftCol, "Silent Aim (Direct Bullet Redirection)", 10)

    local hooksInstalled = false
    local function installSilentAimHooks()
        if hooksInstalled then return end
        hooksInstalled = true

        local mt = getrawmetatable and getrawmetatable(game)
        if not mt then return end

        local oldIndex    = rawget(mt, "__index")
        local oldNamecall = rawget(mt, "__namecall")

        setreadonly(mt, false)

        rawset(mt, "__index", function(self, key)
            if Shared.Flags["SilentAim"] and typeof(self) == "Instance" and self:IsA("Mouse") then
                local target = getSilentAimTarget()
                if target then
                    if key == "Hit" or key == "hit" then
                        return target.CFrame
                    elseif key == "Target" or key == "target" then
                        return target
                    elseif key == "UnitRay" then
                        local cam = Workspace.CurrentCamera
                        if cam then
                            local dir = (target.Position - cam.CFrame.Position).Unit
                            return Ray.new(cam.CFrame.Position, dir)
                        end
                    end
                end
            end
            return oldIndex(self, key)
        end)

        rawset(mt, "__namecall", function(self, ...)
            if Shared.Flags["SilentAim"] then
                local method = getnamecallmethod()
                local args   = {...}

                if method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "findPartOnRay" then
                    local target = getSilentAimTarget()
                    if target then
                        local origin = args[1]
                        if typeof(origin) == "Vector3" then
                            args[2] = (target.Position - origin).Unit * 1000
                        end
                    end
                    return oldNamecall(self, table.unpack(args))
                end

                if method == "FireServer" or method == "InvokeServer" then
                    local n = self.Name:lower()
                    if n:find("gun") or n:find("shoot") or n:find("bullet") or n:find("beam") then
                        local target = getSilentAimTarget()
                        if target then
                            for i, v in ipairs(args) do
                                if typeof(v) == "Vector3" then
                                    args[i] = target.Position
                                elseif typeof(v) == "CFrame" then
                                    args[i] = target.CFrame
                                end
                            end
                        end
                    end
                    return oldNamecall(self, table.unpack(args))
                end
            end
            return oldNamecall(self, ...)
        end)

        setreadonly(mt, true)
    end

    MkToggle(leftCol, "Silent Aim (Auto Hit Murderer)", "SilentAim", 11, function(state)
        if state then
            installSilentAimHooks()
        end
    end)

    MkSection(leftCol, "Auto Grab Gun (Dead Drop)", 20)

    local autoGrabConn
    MkToggle(leftCol, "Auto Grab Dropped Gun", "AutoGrabGun", 21, function(state)
        if autoGrabConn then autoGrabConn:Disconnect(); autoGrabConn = nil end
        if state then
            autoGrabConn = RunService.Heartbeat:Connect(function()
                if not selfAliveInRound() then return end
                if getMyGun() then return end
                local myHRP = getHRP(); if not myHRP then return end
                local part = cachedGunDrop
                if part and part.Parent then
                    local dist = (part.Position - myHRP.Position).Magnitude
                    if dist < 40 then
                        pcall(function() firetouchinterest(myHRP, part, 0) end)
                        pcall(function() firetouchinterest(myHRP, part, 1) end)
                    end
                end
            end)
        end
    end)

    -- ── RIGHT COLUMN: KNIFE, ESP & SHERIFF TOOLS ──────────────────
    MkSection(rightCol, "Knife Controls", 1)

    local knifeThrowConn
    MkToggle(rightCol, "Knife Velocity Prediction", "KnifePrediction", 2, function(state)
        if knifeThrowConn then knifeThrowConn:Disconnect(); knifeThrowConn = nil end
        if state then
            knifeThrowConn = Workspace.ChildAdded:Connect(function(obj)
                if not Shared.Flags["KnifePrediction"] then return end
                if obj.Name:find("Knife") or obj.Name:find("knife") then
                    task.wait()
                    local myHRP = getHRP(); if not myHRP then return end
                    local target, bestDist = nil, math.huge
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= Player and isAlive(plr) then
                            local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                            if tHRP then
                                local d = (tHRP.Position - myHRP.Position).Magnitude
                                if d < bestDist then bestDist = d; target = tHRP end
                            end
                        end
                    end
                    if not target then return end
                    local vel = target.AssemblyLinearVelocity
                    local dist = (target.Position - myHRP.Position).Magnitude
                    local travelTime = dist / 80
                    local predictedPos = target.Position + vel * travelTime
                    local knifeBase = obj:FindFirstChildOfClass("BasePart") or (obj:IsA("BasePart") and obj)
                    if knifeBase then
                        pcall(function()
                            local dir = (predictedPos - knifeBase.Position).Unit
                            knifeBase.CFrame = CFrame.new(knifeBase.Position, predictedPos)
                            if not knifeBase.Anchored then
                                knifeBase.AssemblyLinearVelocity = dir * 120
                            end
                        end)
                    end
                end
            end)
        end
    end)

    MkToggle(rightCol, "Auto Throw Knife at Nearest", "AutoThrow", 3, function(state) end)

    RunService.Heartbeat:Connect(function()
        if not Shared.Flags["AutoThrow"] then return end
        if not selfAliveInRound() then return end
        if getRole(Player) ~= "Murderer" then return end
        local myHRP = getHRP(); if not myHRP then return end
        local target, bestDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) then
                local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then
                    local d = (tHRP.Position - myHRP.Position).Magnitude
                    if d < bestDist then bestDist = d; target = tHRP end
                end
            end
        end
        if target and bestDist < 60 then
            local knife = getMyKnife()
            if knife then
                local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildOfClass("BasePart")
                if handle then
                    pcall(function()
                        firetouchinterest(target, handle, 0)
                        firetouchinterest(target, handle, 1)
                    end)
                end
            end
        end
    end)

    -- ── ESP SECTION (Role ESP + Dedicated Sheriff & Gun Drop ESP) ──
    MkSection(rightCol, "ESP & Visuals", 10)

    local espEntries = {}  -- [plr] = { gui = BillboardGui, hl = Highlight, lbl = TextLabel, lastChar = Character }
    local espConn

    local function cleanupPlayerESP(plr)
        local entry = espEntries[plr]
        if entry then
            pcall(function() if entry.gui then entry.gui:Destroy() end end)
            pcall(function() if entry.hl then entry.hl:Destroy() end end)
            espEntries[plr] = nil
        end
    end

    local function clearAllESP()
        for plr in pairs(espEntries) do
            cleanupPlayerESP(plr)
        end
        espEntries = {}
    end

    MkToggle(rightCol, "Role ESP & Highlight Chams", "RoleESP", 11, function(state)
        clearAllESP()
        if espConn then espConn:Disconnect(); espConn = nil end
        if not state then return end

        espConn = RunService.RenderStepped:Connect(function()
            local myHRP = getHRP()

            -- Cleanup leaving / removed players
            for plr, entry in pairs(espEntries) do
                if not plr.Parent or not plr.Character or not isAlive(plr) then
                    cleanupPlayerESP(plr)
                end
            end

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player and plr.Character and isAlive(plr) then
                    local char = plr.Character
                    local hrp  = char:FindFirstChild("HumanoidRootPart")
                    local hum  = char:FindFirstChildOfClass("Humanoid")

                    if hrp and hum and hum.Health > 0 then
                        local entry = espEntries[plr]

                        -- Re-create if character respawned
                        if not entry or entry.lastChar ~= char or not entry.hl.Parent or not entry.gui.Parent then
                            cleanupPlayerESP(plr)

                            -- 1. Highlight Outline Chams
                            local hl = Instance.new("Highlight")
                            hl.Name                = "Fih_Chams"
                            hl.Adornee             = char
                            hl.FillTransparency    = 0.55
                            hl.OutlineTransparency = 0
                            hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Parent              = char

                            -- 2. Billboard Info Tag
                            local bb = Instance.new("BillboardGui")
                            bb.Name         = "Fih_RoleTag"
                            bb.Size         = UDim2.new(0, 130, 0, 32)
                            bb.StudsOffset  = Vector3.new(0, 3.8, 0)
                            bb.AlwaysOnTop  = true
                            bb.Adornee      = hrp
                            bb.Parent       = Shared.GUI

                            local bg = Instance.new("Frame")
                            bg.Size                   = UDim2.new(1, 0, 1, 0)
                            bg.BackgroundColor3       = Color3.fromRGB(15, 18, 24)
                            bg.BackgroundTransparency = 0.25
                            bg.BorderSizePixel        = 1
                            bg.BorderColor3           = Color3.fromRGB(100, 120, 160)
                            bg.Parent                 = bb

                            local lbl = Instance.new("TextLabel")
                            lbl.Size                   = UDim2.new(1, 0, 1, 0)
                            lbl.BackgroundTransparency = 1
                            lbl.Font                   = Enum.Font.ArimoBold
                            lbl.TextSize               = 11
                            lbl.TextStrokeTransparency = 0
                            lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
                            lbl.Parent                 = bg

                            entry = { gui = bb, hl = hl, lbl = lbl, bg = bg, lastChar = char }
                            espEntries[plr] = entry
                        end

                        -- Dynamic Role Detection & Color Update
                        local role = getRole(plr)
                        local col, roleTag = Color3.fromRGB(80, 240, 120), "[INNOCENT]"
                        if role == "Murderer" then
                            col     = Color3.fromRGB(255, 45, 45)
                            roleTag = "[★ MURDERER]"
                        elseif role == "Sheriff" then
                            col     = Color3.fromRGB(0, 190, 255)
                            roleTag = "[✦ SHERIFF]"
                        end

                        local dist = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0

                        entry.hl.FillColor    = col
                        entry.hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        entry.bg.BorderColor3 = col
                        entry.lbl.TextColor3  = col
                        entry.lbl.Text        = roleTag .. " " .. plr.Name .. "\n" .. dist .. " studs"
                    end
                end
            end
        end)
    end)

    -- Dedicated Dropped Gun & Sheriff ESP
    local gunEspHL = nil
    local gunEspBB = nil
    local gunEspConn

    local function clearGunDropESP()
        if gunEspHL then gunEspHL:Destroy(); gunEspHL = nil end
        if gunEspBB then gunEspBB:Destroy(); gunEspBB = nil end
    end

    MkToggle(rightCol, "Dropped Gun Beacon ESP", "GunESP", 12, function(state)
        clearGunDropESP()
        if gunEspConn then gunEspConn:Disconnect(); gunEspConn = nil end
        if not state then return end

        gunEspConn = RunService.RenderStepped:Connect(function()
            local myHRP = getHRP()
            local foundDrop = cachedGunDrop

            if foundDrop and foundDrop.Parent then
                if not gunEspHL or not gunEspHL.Parent then
                    clearGunDropESP()

                    local hl = Instance.new("Highlight")
                    hl.Name                = "Fih_GunHL"
                    hl.Adornee             = foundDrop.Parent:IsA("Tool") and foundDrop.Parent or foundDrop
                    hl.FillColor           = Color3.fromRGB(255, 215, 0)
                    hl.OutlineColor        = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency    = 0.3
                    hl.OutlineTransparency = 0
                    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent              = foundDrop
                    gunEspHL = hl

                    local bb = Instance.new("BillboardGui")
                    bb.Name         = "Fih_GunDropTag"
                    bb.Size         = UDim2.new(0, 130, 0, 30)
                    bb.StudsOffset  = Vector3.new(0, 2.5, 0)
                    bb.AlwaysOnTop  = true
                    bb.Adornee      = foundDrop
                    bb.Parent       = Shared.GUI

                    local bg = Instance.new("Frame")
                    bg.Size                   = UDim2.new(1, 0, 1, 0)
                    bg.BackgroundColor3       = Color3.fromRGB(30, 25, 5)
                    bg.BackgroundTransparency = 0.15
                    bg.BorderSizePixel        = 1
                    bg.BorderColor3           = Color3.fromRGB(255, 215, 0)
                    bg.Parent                 = bb

                    local lbl = Instance.new("TextLabel")
                    lbl.Size                   = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Font                   = Enum.Font.ArimoBold
                    lbl.TextSize               = 11
                    lbl.TextColor3             = Color3.fromRGB(255, 220, 30)
                    lbl.TextStrokeTransparency = 0
                    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
                    lbl.Parent                 = bg
                    gunEspBB = bb
                else
                    gunEspHL.Adornee = foundDrop.Parent:IsA("Tool") and foundDrop.Parent or foundDrop
                    gunEspBB.Adornee = foundDrop
                end

                local dist = myHRP and math.floor((foundDrop.Position - myHRP.Position).Magnitude) or 0
                local lbl = gunEspBB:FindFirstChildOfClass("Frame") and gunEspBB.Frame:FindFirstChildOfClass("TextLabel")
                if lbl then
                    lbl.Text = "[⚠ DROPPED GUN]\n" .. dist .. " studs"
                end
            else
                clearGunDropESP()
            end
        end)
    end)

    MkSection(rightCol, "Sheriff Tools", 20)

    MkToggle(rightCol, "Auto Shoot Murderer", "AutoShoot", 21, function(state) end)
    RunService.Heartbeat:Connect(function()
        if not Shared.Flags["AutoShoot"] then return end
        if not selfAliveInRound() then return end
        if getRole(Player) ~= "Sheriff" then return end
        local gun = getMyGun(); if not gun then return end
        local myHRP = getHRP(); if not myHRP then return end
        local murd = getMurderer()
        if murd and murd.Character then
            local tHRP = murd.Character:FindFirstChild("HumanoidRootPart")
            if tHRP then
                local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildOfClass("BasePart")
                if handle then
                    pcall(function()
                        firetouchinterest(tHRP, handle, 0)
                        firetouchinterest(tHRP, handle, 1)
                    end)
                end
            end
        end
    end)

    MkToggle(rightCol, "Auto Kill All (Murderer)", "AutoKillAll", 22, function(state) end)
    RunService.Heartbeat:Connect(function()
        if not Shared.Flags["AutoKillAll"] then return end
        if not selfAliveInRound() then return end
        if getRole(Player) ~= "Murderer" then return end
        local knife = getMyKnife(); if not knife then return end
        local myHRP = getHRP(); if not myHRP then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and isAlive(plr) then
                local tHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then
                    local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildOfClass("BasePart")
                    if handle then
                        pcall(function() firetouchinterest(tHRP, handle, 0) end)
                        pcall(function() firetouchinterest(tHRP, handle, 1) end)
                    end
                end
            end
        end
    end)

    print("[MM2_Functions] Loaded -- Highlight Chams & Real-Time Role ESP Online")
end
