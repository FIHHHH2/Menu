-- Troll_Functions.lua
-- Working Physics Trolls: Anchored Platform Part, Anchored Blocker Wall, BodyVelocity Push Booster
-- Player Selector (< > arrows + dropdown popup), Orbit Swarm, Head Stand, Shadow Leash

return function(Shared)
    local Services     = Shared.Services or {}
    local Players      = Services.Players or game:GetService("Players")
    local RunService   = Services.RunService or game:GetService("RunService")
    local UserInput    = Services.UserInput or game:GetService("UserInputService")
    local Workspace    = Services.Workspace or workspace
    local TweenSvc     = Services.TweenService or game:GetService("TweenService")

    local Player    = Shared.Player
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider  = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab  = Tabs["Troll"]
    local cols = QuadCols["Troll"]
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    -- ── Helpers ─────────────────────────────────────────────────
    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

    local function getOtherPlayers()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player then table.insert(t, p) end
        end
        return t
    end

    local function getNearestPlayer()
        local myHRP = getHRP()
        if not myHRP then return nil end
        local best, minD = nil, math.huge
        for _, p in ipairs(getOtherPlayers()) do
            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local d = (p.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                    if d < minD then minD = d; best = p end
                end
            end
        end
        return best
    end

    -- ── State ───────────────────────────────────────────────────
    local selectedTarget = nil

    local function getActiveTarget()
        if selectedTarget and selectedTarget.Parent == Players and selectedTarget.Character then
            local hum = selectedTarget.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and selectedTarget.Character:FindFirstChild("HumanoidRootPart") then
                return selectedTarget
            end
        end
        return getNearestPlayer()
    end

    local function isDark()
        return Shared.IsDark and Shared.IsDark() or false
    end
    local function clrBg()    return isDark() and Color3.fromRGB(22,25,34)      or Color3.fromRGB(248,248,252) end
    local function clrBrd()   return isDark() and Color3.fromRGB(40,50,70)      or Color3.fromRGB(190,195,210) end
    local function clrBtn()   return isDark() and Color3.fromRGB(34,38,50)      or Color3.fromRGB(236,233,216) end
    local function clrTxt()   return isDark() and Color3.fromRGB(220,225,240)   or Color3.fromRGB(0,0,0) end
    local function clrAccent() return isDark() and Color3.fromRGB(60,145,255)   or Color3.fromRGB(0,60,180) end
    local function clrHover() return isDark() and Color3.fromRGB(48,58,78)      or Color3.fromRGB(220,230,248) end
    local function clrPopBg() return isDark() and Color3.fromRGB(20,23,32)      or Color3.fromRGB(255,255,255) end
    local function clrSelBg() return isDark() and Color3.fromRGB(28,40,60)      or Color3.fromRGB(220,232,255) end

    -- ── TARGET SELECTOR (arrows + dropdown) ─────────────────────
    MkSection(leftCol, "Troll Target Selector", 1)

    local selRow = Instance.new("Frame")
    selRow.Name             = "TargetSelRow"
    selRow.Size             = UDim2.new(1, 0, 0, 28)
    selRow.BackgroundColor3 = clrBg()
    selRow.BorderSizePixel  = 1
    selRow.BorderColor3     = clrBrd()
    selRow.LayoutOrder      = 2
    selRow.Parent           = leftCol

    -- < arrow
    local prevBtn = Instance.new("TextButton")
    prevBtn.Size             = UDim2.new(0, 26, 1, 0)
    prevBtn.BackgroundColor3 = clrBtn()
    prevBtn.BorderSizePixel  = 1
    prevBtn.BorderColor3     = clrBrd()
    prevBtn.Text             = "<"
    prevBtn.TextColor3       = clrTxt()
    prevBtn.Font             = Enum.Font.ArimoBold
    prevBtn.TextSize         = 12
    prevBtn.Parent           = selRow

    -- centre dropdown trigger
    local dropBtn = Instance.new("TextButton")
    dropBtn.Size             = UDim2.new(1, -54, 1, 0)
    dropBtn.Position         = UDim2.new(0, 27, 0, 0)
    dropBtn.BackgroundColor3 = clrBg()
    dropBtn.BorderSizePixel  = 0
    dropBtn.Text             = "v  Closest Player"
    dropBtn.TextColor3       = clrAccent()
    dropBtn.Font             = Enum.Font.ArimoBold
    dropBtn.TextSize         = 11
    dropBtn.TextTruncate     = Enum.TextTruncate.AtEnd
    dropBtn.Parent           = selRow

    -- > arrow
    local nextBtn = Instance.new("TextButton")
    nextBtn.Size             = UDim2.new(0, 26, 1, 0)
    nextBtn.Position         = UDim2.new(1, -26, 0, 0)
    nextBtn.BackgroundColor3 = clrBtn()
    nextBtn.BorderSizePixel  = 1
    nextBtn.BorderColor3     = clrBrd()
    nextBtn.Text             = ">"
    nextBtn.TextColor3       = clrTxt()
    nextBtn.Font             = Enum.Font.ArimoBold
    nextBtn.TextSize         = 12
    nextBtn.Parent           = selRow

    local function updateDisplay()
        if selectedTarget then
            dropBtn.Text       = "v  " .. selectedTarget.DisplayName .. " (@" .. selectedTarget.Name .. ")"
            dropBtn.TextColor3 = isDark() and Color3.fromRGB(255,120,80) or Color3.fromRGB(180,50,0)
        else
            dropBtn.Text       = "v  Closest Player"
            dropBtn.TextColor3 = clrAccent()
        end
    end

    local dropPanel = nil
    local dropOpen  = false

    local function closeDropdown()
        if dropPanel then dropPanel:Destroy(); dropPanel = nil end
        dropOpen = false
    end

    local function openDropdown()
        closeDropdown()
        dropOpen = true

        local plrs = getOtherPlayers()
        local rowH = 26
        local totalRows = math.min(#plrs + 1, 8)
        local absPos = selRow.AbsolutePosition
        local absSize = selRow.AbsoluteSize

        local rootPanel = Instance.new("Frame")
        rootPanel.Name             = "TrollDropdown"
        rootPanel.Size             = UDim2.new(0, absSize.X, 0, totalRows * rowH)
        rootPanel.Position         = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
        rootPanel.BackgroundColor3 = clrPopBg()
        rootPanel.BorderSizePixel  = 1
        rootPanel.BorderColor3     = isDark() and Color3.fromRGB(50,70,110) or Color3.fromRGB(140,160,200)
        rootPanel.ZIndex           = 250
        rootPanel.ClipsDescendants = true
        rootPanel.Parent           = Shared.GUI or selRow

        dropPanel = rootPanel

        local container = rootPanel
        if #plrs + 1 > 8 then
            local sf = Instance.new("ScrollingFrame")
            sf.Size = UDim2.new(1,0,1,0)
            sf.BackgroundTransparency = 1
            sf.BorderSizePixel = 0
            sf.ScrollBarThickness = 5
            sf.CanvasSize = UDim2.new(0,0,0,(#plrs+1)*rowH)
            sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
            sf.ZIndex = 250
            sf.Parent = rootPanel
            container = sf
        end

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent    = container

        local function makeRow(displayText, col, isSelected, onClick)
            local row = Instance.new("TextButton")
            row.Size             = UDim2.new(1, 0, 0, rowH)
            row.BackgroundColor3 = isSelected and clrSelBg() or clrPopBg()
            row.BorderSizePixel  = 0
            row.Text             = "  " .. displayText
            row.TextColor3       = col
            row.Font             = Enum.Font.Code
            row.TextSize         = 11
            row.TextXAlignment   = Enum.TextXAlignment.Left
            row.TextTruncate     = Enum.TextTruncate.AtEnd
            row.ZIndex           = 251
            row.Parent           = container
            row.MouseEnter:Connect(function()
                TweenSvc:Create(row, TweenInfo.new(0.08), {BackgroundColor3 = clrHover()}):Play()
            end)
            row.MouseLeave:Connect(function()
                TweenSvc:Create(row, TweenInfo.new(0.08), {BackgroundColor3 = isSelected and clrSelBg() or clrPopBg()}):Play()
            end)
            row.MouseButton1Click:Connect(onClick)
            return row
        end

        makeRow("[ Closest Player ]", clrAccent(), selectedTarget == nil, function()
            selectedTarget = nil; updateDisplay(); closeDropdown()
        end)

        for _, plr in ipairs(plrs) do
            local capPlr = plr
            makeRow(plr.DisplayName .. " (@" .. plr.Name .. ")", clrTxt(), selectedTarget == capPlr, function()
                selectedTarget = capPlr; updateDisplay(); closeDropdown()
            end)
        end

        -- Reposition if window moves
        local posConn = selRow:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            if rootPanel and rootPanel.Parent then
                local p = selRow.AbsolutePosition
                local s = selRow.AbsoluteSize
                rootPanel.Position = UDim2.new(0, p.X, 0, p.Y + s.Y + 2)
            end
        end)

        -- Close on outside click
        task.delay(0.08, function()
            local clickConn
            clickConn = UserInput.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    task.wait()
                    if rootPanel and rootPanel.Parent then
                        local mousePos = UserInput:GetMouseLocation()
                        local rPos = rootPanel.AbsolutePosition
                        local rSize = rootPanel.AbsoluteSize
                        if mousePos.X < rPos.X or mousePos.X > rPos.X + rSize.X or mousePos.Y < rPos.Y or mousePos.Y > rPos.Y + rSize.Y then
                            closeDropdown()
                            if posConn then posConn:Disconnect() end
                            if clickConn then clickConn:Disconnect() end
                        end
                    end
                end
            end)
        end)
    end

    dropBtn.MouseButton1Click:Connect(function()
        if dropOpen then closeDropdown() else openDropdown() end
    end)

    local function cycleTarget(dir)
        local plrs = getOtherPlayers()
        if #plrs == 0 then selectedTarget = nil; updateDisplay(); return end
        if not selectedTarget then
            selectedTarget = dir > 0 and plrs[1] or plrs[#plrs]
        else
            local idx = table.find(plrs, selectedTarget)
            if not idx then
                selectedTarget = nil
            else
                local nxt = idx + dir
                selectedTarget = (nxt < 1 or nxt > #plrs) and nil or plrs[nxt]
            end
        end
        updateDisplay()
    end

    prevBtn.MouseButton1Click:Connect(function() cycleTarget(-1) end)
    nextBtn.MouseButton1Click:Connect(function() cycleTarget(1) end)

    for _, b in ipairs({prevBtn, nextBtn}) do
        b.MouseEnter:Connect(function() TweenSvc:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = clrHover()}):Play() end)
        b.MouseLeave:Connect(function() TweenSvc:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = clrBtn()}):Play() end)
    end

    -- ── LEFT COLUMN: ZERO-JITTER PHYSICS TROLLS ──────────────────
    MkSection(leftCol, "Physics Interactions", 10)

    -- 0. STEALTH WALK FLING (No-Spin Collision Touch Fling)
    local walkFlingConn = nil
    MkToggle(leftCol, "Walk Touch Fling (No Spin)", "WalkFling", 10, function(state)
        if walkFlingConn then walkFlingConn:Disconnect(); walkFlingConn = nil end
        if not state then
            local myHRP = getHRP()
            if myHRP then
                myHRP.AssemblyLinearVelocity = Vector3.zero
                myHRP.AssemblyAngularVelocity = Vector3.zero
            end
            return
        end

        walkFlingConn = RunService.Heartbeat:Connect(function()
            local myHRP = getHRP()
            local char  = getChar()
            local myHum = char and char:FindFirstChildOfClass("Humanoid")
            if not myHRP or not myHum then return end

            myHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            myHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

            local touchingTarget = nil
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = p.Character.HumanoidRootPart
                    local dist = (tHRP.Position - myHRP.Position).Magnitude
                    if dist <= 5.4 then
                        touchingTarget = tHRP
                        break
                    end
                end
            end

            if touchingTarget then
                local dir = (touchingTarget.Position - myHRP.Position).Unit
                local power = Shared.Flags["WalkFlingPower"] or 65000
                myHRP.AssemblyLinearVelocity = dir * power + Vector3.new(0, power * 0.4, 0)
                myHRP.AssemblyAngularVelocity = Vector3.new(0, power, 0)
            else
                if myHRP.AssemblyAngularVelocity.Magnitude > 100 then
                    myHRP.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end)

        Shared.Notify("Walk Fling", "Stealth Touch Fling active: Walk into players to fling them!", true)
    end)

    MkSlider(leftCol, "Fling Power", "WalkFlingPower", 10000, 100000, 65000, 11, function(v)
        Shared.Flags["WalkFlingPower"] = v
    end)

    -- 1. PUSH PLAYER (Zero-Jitter Impulse Booster)
    -- Instead of locking CFrame every microsecond (which cancels physics and causes jitter),
    -- this applies clean physics collision thrust impulses that launch the target smoothly.
    local pushRunning = false

    MkToggle(leftCol, "Push Player (Ram Boost)", "PushPlayer", 11, function(state)
        pushRunning = state
        if not state then
            local myHRP = getHRP()
            if myHRP then myHRP.AssemblyLinearVelocity = Vector3.zero end
            return
        end

        task.spawn(function()
            while pushRunning and Shared.Flags["PushPlayer"] do
                local myHRP = getHRP()
                local target = getActiveTarget()
                if myHRP and target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP  = target.Character.HumanoidRootPart
                    local look  = tHRP.CFrame.LookVector
                    local power = Shared.Flags["PushForce"] or 240

                    -- Position 1.2 studs behind them with matching orientation
                    myHRP.CFrame = CFrame.new(tHRP.Position - look * 1.3, tHRP.Position + look)
                    -- Apply forward momentum thrust
                    myHRP.AssemblyLinearVelocity = look * power + Vector3.new(0, 25, 0)
                end
                -- Allow physics engine to simulate collision contact
                task.wait(0.08)
            end
        end)
    end)

    MkSlider(leftCol, "Push Force", "PushForce", 60, 500, 240, 12, function(v)
        Shared.Flags["PushForce"] = v
    end)

    -- 2. PLATFORM MODE (Zero-Jitter Stable Air Pad)
    -- Creates a stable horizontal plane under the target that stays at a solid floor height,
    -- allowing them to stand, walk, and jump up infinitely without vertical oscillation jitter.
    local platformPart = nil
    local platformConn = nil

    local function cleanPlatform()
        if platformConn then platformConn:Disconnect(); platformConn = nil end
        if platformPart and platformPart.Parent then platformPart:Destroy(); platformPart = nil end
    end

    MkToggle(leftCol, "Platform Mode (Air Pad)", "PlatformMode", 13, function(state)
        cleanPlatform()
        if not state then return end

        platformPart              = Instance.new("Part")
        platformPart.Name         = "Fih_Platform"
        platformPart.Size         = Vector3.new(10, 1, 10)
        platformPart.Anchored     = true
        platformPart.CanCollide   = true
        platformPart.Transparency = 0.35
        platformPart.Material     = Enum.Material.Neon
        platformPart.Color        = Color3.fromRGB(0, 210, 255)
        platformPart.TopSurface   = Enum.SurfaceType.Smooth
        platformPart.BottomSurface= Enum.SurfaceType.Smooth
        platformPart.CustomPhysicalProperties = PhysicalProperties.new(0.8, 2.5, 0.0, 1.0, 1.0)
        platformPart.Parent       = Workspace

        local currentPlatY = nil

        platformConn = RunService.Stepped:Connect(function()
            local target = getActiveTarget()
            if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end
            local tHRP = target.Character.HumanoidRootPart
            local feetY = tHRP.Position.Y - 3.1

            -- Initialize or smoothly adjust floor height without jittering into feet
            if not currentPlatY then
                currentPlatY = feetY
            else
                -- If target jumped higher or dropped below, adapt floor cleanly
                if feetY > currentPlatY + 1.2 or feetY < currentPlatY - 0.8 then
                    currentPlatY = feetY
                end
            end

            -- Match horizontal X/Z position with stable Y plane
            platformPart.CFrame = CFrame.new(tHRP.Position.X, currentPlatY, tHRP.Position.Z)
        end)
    end)

    -- 3. PATH BLOCKER (Stable Non-Jittering Barrier)
    local blockerPart = nil
    local blockerConn = nil

    local function cleanBlocker()
        if blockerConn then blockerConn:Disconnect(); blockerConn = nil end
        if blockerPart and blockerPart.Parent then blockerPart:Destroy(); blockerPart = nil end
    end

    MkToggle(leftCol, "Path Blocker (Solid Wall)", "PathBlocker", 14, function(state)
        cleanBlocker()
        if not state then return end

        blockerPart              = Instance.new("Part")
        blockerPart.Name         = "Fih_Blocker"
        blockerPart.Size         = Vector3.new(8, 9, 0.8)
        blockerPart.Anchored     = true
        blockerPart.CanCollide   = true
        blockerPart.Transparency = 0.45
        blockerPart.Material     = Enum.Material.ForceField
        blockerPart.Color        = Color3.fromRGB(255, 60, 60)
        blockerPart.Parent       = Workspace

        blockerConn = RunService.Stepped:Connect(function()
            local target = getActiveTarget()
            if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end
            local tHRP = target.Character.HumanoidRootPart
            local vel  = tHRP.AssemblyLinearVelocity
            local dir  = vel.Magnitude > 1.5 and vel.Unit or tHRP.CFrame.LookVector

            -- Pinned 2.6 studs ahead without colliding with their center root
            local targetPos = tHRP.Position + dir * 2.6
            blockerPart.CFrame = CFrame.new(targetPos, targetPos + dir)
        end)
    end)

    -- 4. BODY PLATFORM (Self as Air Pad / Infinite Stepping Stone)
    -- Moves YOUR character directly underneath the target player's feet so they can jump off you infinitely.
    local bodyPlatConn = nil

    MkToggle(leftCol, "Body Platform (Self as Pad)", "BodyPlatform", 15, function(state)
        if bodyPlatConn then bodyPlatConn:Disconnect(); bodyPlatConn = nil end
        if not state then
            local myHRP = getHRP()
            if myHRP then myHRP.AssemblyLinearVelocity = Vector3.zero end
            return
        end

        local currentBodyY = nil
        bodyPlatConn = RunService.Stepped:Connect(function()
            local target = getActiveTarget()
            local myHRP = getHRP()
            if not myHRP or not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then
                return
            end

            local tHRP = target.Character.HumanoidRootPart
            local feetY = tHRP.Position.Y - 3.2

            local char = getChar()
            if char then
                local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("Head")
                if torso then torso.CanCollide = true end
            end

            if not currentBodyY then
                currentBodyY = feetY
            else
                if feetY > currentBodyY + 1.0 or feetY < currentBodyY - 0.8 then
                    currentBodyY = feetY
                end
            end

            myHRP.CFrame = CFrame.new(tHRP.Position.X, currentBodyY, tHRP.Position.Z)
            myHRP.AssemblyLinearVelocity = Vector3.zero
        end)
    end)

    -- ── RIGHT COLUMN: SWARM, ORBIT, HATS ───────────────────────
    MkSection(rightCol, "Swarm & Orbit Trolls", 1)

    local orbitConn, orbitAngle = nil, 0
    MkToggle(rightCol, "Orbit Swarm (Tornado)", "OrbitSwarm", 2, function(state)
        if orbitConn then orbitConn:Disconnect(); orbitConn = nil end
        if not state then return end
        orbitConn = RunService.RenderStepped:Connect(function(dt)
            local myHRP = getHRP(); if not myHRP then return end
            local target = getActiveTarget()
            if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end
            local tHRP   = target.Character.HumanoidRootPart
            local speed  = Shared.Flags["OrbitSpeed"]  or 18
            local radius = Shared.Flags["OrbitRadius"] or 5
            orbitAngle   = orbitAngle + dt * speed
            local pos = tHRP.Position + Vector3.new(
                math.cos(orbitAngle) * radius,
                math.sin(orbitAngle * 2) * 1.5,
                math.sin(orbitAngle) * radius
            )
            myHRP.CFrame = CFrame.new(pos, tHRP.Position)
        end)
    end)

    MkSlider(rightCol, "Orbit Speed",  "OrbitSpeed",  5, 50, 18, 3, function(v) Shared.Flags["OrbitSpeed"]  = v end)
    MkSlider(rightCol, "Orbit Radius", "OrbitRadius", 2, 20,  5, 4, function(v) Shared.Flags["OrbitRadius"] = v end)

    local headConn
    MkToggle(rightCol, "Head Stand (Hat Mode)", "HeadStand", 5, function(state)
        if headConn then headConn:Disconnect(); headConn = nil end
        if not state then return end
        headConn = RunService.Heartbeat:Connect(function()
            local myHRP = getHRP(); if not myHRP then return end
            local target = getActiveTarget()
            if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end
            local tHRP = target.Character.HumanoidRootPart
            myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 3.4, 0)
            myHRP.AssemblyLinearVelocity = tHRP.AssemblyLinearVelocity
        end)
    end)

    local leashConn
    MkToggle(rightCol, "Shadow Leash (Follow)", "ShadowLeash", 6, function(state)
        if leashConn then leashConn:Disconnect(); leashConn = nil end
        if not state then return end
        leashConn = RunService.Heartbeat:Connect(function()
            local myHRP = getHRP(); if not myHRP then return end
            local target = getActiveTarget()
            if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end
            local tHRP = target.Character.HumanoidRootPart
            myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3.5)
        end)
    end)

    -- Cleanup world parts on exit
    Players.PlayerRemoving:Connect(function(plr)
        if plr == Player then
            cleanPlatform()
            cleanBlocker()
        end
    end)

    print("[Troll_Functions] Loaded -- Dropdown, Anchored Platform, Anchored Blocker, BodyVelocity Push Online")
end
