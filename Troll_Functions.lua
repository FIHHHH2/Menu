-- Troll_Functions.lua
-- Working Physics Trolls: Anchored Platform Part, Anchored Blocker Wall, BodyVelocity Push Booster
-- Player Selector (< > arrows + dropdown popup), Orbit Swarm, Head Stand, Shadow Leash

return function(Shared)
    local Players      = Shared.Services.Players
    local RunService   = Shared.Services.RunService
    local UserInput    = Shared.Services.UserInput
    local Workspace    = Shared.Services.Workspace
    local TweenSvc     = Shared.Services.TweenService

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

        dropPanel = Instance.new("Frame")
        dropPanel.Name             = "TrollDropdown"
        dropPanel.Size             = UDim2.new(1, 0, 0, totalRows * rowH)
        dropPanel.Position         = UDim2.new(0, 0, 0, 28)
        dropPanel.BackgroundColor3 = clrPopBg()
        dropPanel.BorderSizePixel  = 1
        dropPanel.BorderColor3     = isDark() and Color3.fromRGB(50,70,110) or Color3.fromRGB(140,160,200)
        dropPanel.ZIndex           = 60
        dropPanel.ClipsDescendants = true
        dropPanel.Parent           = selRow

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent    = dropPanel

        -- scroll if needed
        if #plrs + 1 > 8 then
            local sf = Instance.new("ScrollingFrame")
            sf.Size = UDim2.new(1,0,1,0)
            sf.BackgroundTransparency = 1
            sf.BorderSizePixel = 0
            sf.ScrollBarThickness = 5
            sf.CanvasSize = UDim2.new(0,0,0,(#plrs+1)*rowH)
            sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
            sf.ZIndex = 60
            sf.Parent = dropPanel
            layout.Parent = sf
            dropPanel = sf  -- redirect inserts
        end

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
            row.ZIndex           = 61
            row.Parent           = dropPanel
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

        -- close on outside click
        task.delay(0.08, function()
            local conn
            conn = UserInput.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    task.wait()
                    if dropPanel and dropPanel.Parent then closeDropdown() end
                    conn:Disconnect()
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

    -- ── LEFT COLUMN: PHYSICS ────────────────────────────────────
    MkSection(leftCol, "Physics Interactions", 10)

    -- 1. PUSH PLAYER
    -- Positions our character behind target (we own our char = server-acknowledged),
    -- then fires a BodyVelocity slam so we physically collide into them.
    local pushConn, pushBV

    MkToggle(leftCol, "Push Player (Ram Boost)", "PushPlayer", 11, function(state)
        if pushConn then pushConn:Disconnect(); pushConn = nil end
        if pushBV and pushBV.Parent then pushBV:Destroy(); pushBV = nil end
        if not state then
            local myHRP = getHRP()
            if myHRP then myHRP.AssemblyLinearVelocity = Vector3.zero end
            return
        end

        pushConn = RunService.Stepped:Connect(function()
            local myHRP = getHRP(); if not myHRP then return end
            local target = getActiveTarget()
            if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end
            local tHRP  = target.Character.HumanoidRootPart
            local look  = tHRP.CFrame.LookVector
            local power = Shared.Flags["PushForce"] or 220

            -- Enable collision only on main torso/HRP for momentum transfer
            myHRP.CanCollide = true
            local char = getChar()
            if char then
                local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                if torso then torso.CanCollide = true end
            end

            -- Plant behind target
            myHRP.CFrame = CFrame.new(tHRP.Position - look * 0.6, tHRP.Position + look)

            -- BodyVelocity slam forward
            if not (pushBV and pushBV.Parent) then
                pushBV = Instance.new("BodyVelocity")
                pushBV.MaxForce = Vector3.new(1e8, 1e8, 1e8)
                pushBV.Parent   = myHRP
            end
            pushBV.Velocity = look * power + Vector3.new(0, 18, 0)
        end)
    end)

    MkSlider(leftCol, "Push Force", "PushForce", 60, 500, 220, 12, function(v)
        Shared.Flags["PushForce"] = v
    end)

    -- 2. PLATFORM MODE
    -- An ANCHORED Part (server-visible, no network ownership needed) is pinned
    -- under the target's feet every physics step. They can stand and jump on it in mid-air.
    local platformPart, platformConn

    local function cleanPlatform()
        if platformConn then platformConn:Disconnect(); platformConn = nil end
        if platformPart and platformPart.Parent then platformPart:Destroy(); platformPart = nil end
    end

    MkToggle(leftCol, "Platform Mode (Air Pad)", "PlatformMode", 13, function(state)
        cleanPlatform()
        if not state then return end

        platformPart              = Instance.new("Part")
        platformPart.Name         = "Fih_Platform"
        platformPart.Size         = Vector3.new(8, 0.6, 8)
        platformPart.Anchored     = true
        platformPart.CanCollide   = true
        platformPart.Transparency = 0.35
        platformPart.Material     = Enum.Material.Neon
        platformPart.Color        = Color3.fromRGB(0, 200, 255)
        platformPart.TopSurface   = Enum.SurfaceType.Smooth
        platformPart.BottomSurface= Enum.SurfaceType.Smooth
        platformPart.CustomPhysicalProperties = PhysicalProperties.new(0.9, 3.0, 0.0)
        platformPart.Parent       = Workspace

        platformConn = RunService.Stepped:Connect(function()
            local target = getActiveTarget()
            if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end
            local tHRP   = target.Character.HumanoidRootPart
            local tHum   = target.Character:FindFirstChildOfClass("Humanoid")
            local legLen = tHum and (tHum.HipHeight + 1.1) or 2.5
            platformPart.CFrame = CFrame.new(tHRP.Position - Vector3.new(0, legLen, 0))
        end)
    end)

    -- 3. PATH BLOCKER
    -- Real ANCHORED wall that follows and plants right in front of wherever the target walks.
    local blockerPart, blockerConn

    local function cleanBlocker()
        if blockerConn then blockerConn:Disconnect(); blockerConn = nil end
        if blockerPart and blockerPart.Parent then blockerPart:Destroy(); blockerPart = nil end
    end

    MkToggle(leftCol, "Path Blocker (Solid Wall)", "PathBlocker", 14, function(state)
        cleanBlocker()
        if not state then return end

        blockerPart              = Instance.new("Part")
        blockerPart.Name         = "Fih_Blocker"
        blockerPart.Size         = Vector3.new(8, 9, 0.4)
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
            local dir  = vel.Magnitude > 1.2 and vel.Unit or tHRP.CFrame.LookVector
            blockerPart.CFrame = CFrame.new(tHRP.Position + dir * 2.2, tHRP.Position + dir * 3)
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
