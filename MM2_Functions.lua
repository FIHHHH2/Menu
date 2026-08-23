-- MM2_Functions.lua
-- Unrestricted Kill Aura, Non-Intrusive Silent Aim Targeting Murderer, Knife Prediction, Lobby-Safe Auto Grab, Role ESP

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

    local function getMyKnife()
        local c = getChar(); local bp = Player:FindFirstChild("Backpack")
        return (c and c:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
    end
    local function getMyGun()
        local c = getChar(); local bp = Player:FindFirstChild("Backpack")
        return (c and (c:FindFirstChild("Gun") or c:FindFirstChild("Revolver")))
            or (bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")))
    end

    -- Target resolver for Silent Aim:
    -- If Sheriff / Innocent -> prioritize Murderer
    -- If Murderer -> prioritize closest living innocent/sheriff
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

        -- Fallback to nearest living enemy
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

    -- ── LEFT COLUMN: KILL AURA & SILENT AIM ───────────────────────
    MkSection(leftCol, "Kill Aura Engine", 1)

    local auraBoxPart = nil
    MkToggle(leftCol, "Kill Aura Box Visualizer", "KillAuraBox", 2, function(state)
        if not state and auraBoxPart then
            auraBoxPart:Destroy(); auraBoxPart = nil
        end
    end)

    MkSlider(leftCol, "Aura Radius (studs)", "KillAuraRadius", 5, 80, 20, 3, nil)

    MkToggle(leftCol, "Kill Aura (All Players)", "KillAura", 4, function(state)
        if not state and auraBoxPart then
            auraBoxPart:Destroy(); auraBoxPart = nil
        end
    end)

    -- Aura heartbeat
    RunService.Heartbeat:Connect(function()
        if not Shared.Flags["KillAura"] then return end
        if not selfAliveInRound() then return end

        local hrp = getHRP()
        if not hrp then return end
        local radius = Shared.Flags["KillAuraRadius"] or 20

        if Shared.Flags["KillAuraBox"] then
            if not auraBoxPart then
                auraBoxPart = Instance.new("Part")
                auraBoxPart.Name          = "AuraBox"
                auraBoxPart.Anchored      = true
                auraBoxPart.CanCollide    = false
                auraBoxPart.CanTouch      = false
                auraBoxPart.Transparency  = 0.7
                auraBoxPart.Material      = Enum.Material.Neon
                auraBoxPart.BrickColor    = BrickColor.new("Bright red")
                auraBoxPart.Parent        = Workspace
                local sel = Instance.new("SelectionBox")
                sel.Adornee = auraBoxPart; sel.Color3 = Color3.fromRGB(255,50,50); sel.LineThickness = 0.06
                sel.Parent = auraBoxPart
            end
            auraBoxPart.Size   = Vector3.new(radius*2, radius*2, radius*2)
            auraBoxPart.CFrame = hrp.CFrame
        elseif auraBoxPart then
            auraBoxPart:Destroy(); auraBoxPart = nil
        end

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

    -- ── NON-INTRUSIVE SILENT AIM ───────────────────────────────────
    -- Hooks Mouse.Hit / Mouse.Target and Raycast/FireServer without touching camera or player orientation.
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

        -- Hook Mouse.Hit & Mouse.Target
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

        -- Hook Raycasts & Remote Events
        rawset(mt, "__namecall", function(self, ...)
            if Shared.Flags["SilentAim"] then
                local method = getnamecallmethod()
                local args   = {...}

                -- Redirect raycast bullets straight to target
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

                -- Redirect MM2 gun remotes
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
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if (obj.Name == "GunDrop" or (obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name == "Revolver")))
                    and obj.Parent ~= Player.Backpack and obj.Parent ~= (getChar()) then
                        local part = obj:FindFirstChildOfClass("BasePart") or obj
                        if part and part:IsA("BasePart") then
                            local dist = (part.Position - myHRP.Position).Magnitude
                            if dist < 40 then
                                pcall(function() firetouchinterest(myHRP, part, 0) end)
                                pcall(function() firetouchinterest(myHRP, part, 1) end)
                            end
                        end
                    end
                end
            end)
        end
    end)

    -- ── RIGHT COLUMN: KNIFE & COMBAT TOOLS ────────────────────────
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

    -- Auto Throw: uses firetouchinterest WITHOUT rotating player CFrame/Camera
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

    MkSection(rightCol, "Role ESP", 20)

    local espHighlights = {}
    local espConn
    MkToggle(rightCol, "Role ESP (Billboard)", "RoleESP", 21, function(state)
        for _, h in pairs(espHighlights) do pcall(function() h.gui:Destroy() end) end
        espHighlights = {}
        if espConn then espConn:Disconnect(); espConn = nil end
        if not state then return end
        espConn = RunService.Heartbeat:Connect(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        if not espHighlights[plr] then
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "FihESP"; bb.Size = UDim2.new(0,70,0,22)
                            bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true
                            bb.Adornee = hrp; bb.Parent = Shared.GUI
                            local lbl = Instance.new("TextLabel")
                            lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 0.3
                            lbl.BackgroundColor3 = Color3.fromRGB(20,20,20); lbl.Font = Enum.Font.Code
                            lbl.TextSize = 11; lbl.TextStrokeTransparency = 0; lbl.Parent = bb
                            espHighlights[plr] = {gui = bb, lbl = lbl}
                        end
                        local role = getRole(plr)
                        local col  = role == "Murderer" and Color3.fromRGB(255,60,60) or (role == "Sheriff" and Color3.fromRGB(60,180,255) or Color3.fromRGB(180,255,180))
                        local info = espHighlights[plr]
                        info.lbl.Text = plr.Name .. "\n" .. role
                        info.lbl.TextColor3 = col
                    elseif espHighlights[plr] then
                        pcall(function() espHighlights[plr].gui:Destroy() end)
                        espHighlights[plr] = nil
                    end
                end
            end
        end)
    end)

    MkSection(rightCol, "Sheriff Tools", 30)

    -- Auto Shoot Murderer WITHOUT rotating camera
    MkToggle(rightCol, "Auto Shoot Murderer", "AutoShoot", 31, function(state) end)
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

    MkToggle(rightCol, "Auto Kill All (Murderer)", "AutoKillAll", 32, function(state) end)
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

    print("[MM2_Functions] Loaded -- Non-Intrusive Silent Aim & Combat Online")
end
