-- Troll_Functions.lua
-- Server-Replicated Physics Trolls: Player Selector, Solid Anchored Air Platform, Immovable Path Blocker Wall,
-- PreSimulation Physics Push Booster, Orbit Swarm, Head Stand, and Shadow Leash

return function(Shared)
    local Players      = Shared.Services.Players
    local RunService   = Shared.Services.RunService
    local UserInput    = Shared.Services.UserInput
    local Workspace    = Shared.Services.Workspace

    local Player       = Shared.Player
    local Tabs         = Shared.Tabs or {}
    local QuadCols     = Shared.QuadCols or {}
    local MkSection    = Shared.MakeSection or function() end
    local MkToggle     = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider     = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton     = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab = Tabs["Troll"]
    local cols = QuadCols["Troll"]
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    -- ── State & Target Selection ─────────────────────────────────
    local selectedTargetPlr = nil
    local targetDisplayLbl  = nil

    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
    local function getHuman() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

    local function getNearestPlayer()
        local myHRP = getHRP()
        if not myHRP then return nil end
        local best, minDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local d = (plr.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                    if d < minDist then minDist = d; best = plr end
                end
            end
        end
        return best
    end

    local function getActiveTarget()
        if selectedTargetPlr and selectedTargetPlr.Parent == Players and selectedTargetPlr.Character then
            local hum = selectedTargetPlr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and selectedTargetPlr.Character:FindFirstChild("HumanoidRootPart") then
                return selectedTargetPlr
            end
        end
        return getNearestPlayer()
    end

    local function enableAllCollisions()
        local char = getChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end

    -- ── TARGET SELECTION CONTROLS ────────────────────────────────
    MkSection(leftCol, "Troll Target Selector", 1)

    local selectorRow = Instance.new("Frame")
    selectorRow.Name             = "SelectorRow"
    selectorRow.Size             = UDim2.new(1, 0, 0, 28)
    selectorRow.BackgroundColor3 = Color3.fromRGB(248, 248, 252)
    selectorRow.BorderSizePixel  = 1
    selectorRow.BorderColor3     = Color3.fromRGB(190, 195, 210)
    selectorRow.LayoutOrder      = 2
    selectorRow.Parent           = leftCol

    local prevBtn = Instance.new("TextButton")
    prevBtn.Size             = UDim2.new(0, 26, 1, 0)
    prevBtn.Position         = UDim2.new(0, 0, 0, 0)
    prevBtn.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
    prevBtn.BorderSizePixel  = 1
    prevBtn.BorderColor3     = Color3.fromRGB(140, 150, 170)
    prevBtn.Text             = "<"
    prevBtn.TextColor3       = Color3.fromRGB(0, 0, 0)
    prevBtn.Font             = Enum.Font.Code
    prevBtn.TextSize         = 12
    prevBtn.Parent           = selectorRow

    local nextBtn = Instance.new("TextButton")
    nextBtn.Size             = UDim2.new(0, 26, 1, 0)
    nextBtn.Position         = UDim2.new(1, -26, 0, 0)
    nextBtn.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
    nextBtn.BorderSizePixel  = 1
    nextBtn.BorderColor3     = Color3.fromRGB(140, 150, 170)
    nextBtn.Text             = ">"
    nextBtn.TextColor3       = Color3.fromRGB(0, 0, 0)
    nextBtn.Font             = Enum.Font.Code
    nextBtn.TextSize         = 12
    nextBtn.Parent           = selectorRow

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size                  = UDim2.new(1, -56, 1, 0)
    nameLbl.Position              = UDim2.new(0, 28, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                  = "[ Closest Player ]"
    nameLbl.TextColor3            = Color3.fromRGB(0, 60, 180)
    nameLbl.Font                  = Enum.Font.ArimoBold
    nameLbl.TextSize              = 11
    nameLbl.TextTruncate          = Enum.TextTruncate.AtEnd
    nameLbl.Parent                = selectorRow
    targetDisplayLbl              = nameLbl

    local function updateTargetDisplay()
        if selectedTargetPlr then
            nameLbl.Text = selectedTargetPlr.DisplayName .. " (@" .. selectedTargetPlr.Name .. ")"
            nameLbl.TextColor3 = Color3.fromRGB(180, 50, 0)
        else
            nameLbl.Text = "[ Closest Player ]"
            nameLbl.TextColor3 = Color3.fromRGB(0, 60, 180)
        end
    end

    local function cycleTarget(direction)
        local plrs = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player then table.insert(plrs, p) end
        end
        if #plrs == 0 then
            selectedTargetPlr = nil
            updateTargetDisplay()
            return
        end

        if not selectedTargetPlr then
            selectedTargetPlr = (direction > 0) and plrs[1] or plrs[#plrs]
        else
            local currIdx = table.find(plrs, selectedTargetPlr)
            if not currIdx then
                selectedTargetPlr = nil
            else
                local nextIdx = currIdx + direction
                if nextIdx > #plrs then
                    selectedTargetPlr = nil
                elseif nextIdx < 1 then
                    selectedTargetPlr = nil
                else
                    selectedTargetPlr = plrs[nextIdx]
                end
            end
        end
        updateTargetDisplay()
    end

    prevBtn.MouseButton1Click:Connect(function() cycleTarget(-1) end)
    nextBtn.MouseButton1Click:Connect(function() cycleTarget(1) end)

    MkButton(leftCol, "[ Reset to Closest Player ]", 3, function()
        selectedTargetPlr = nil
        updateTargetDisplay()
        Shared.Notify("Target Reset", "Now targeting closest player", true)
    end)

    -- ── LEFT COLUMN: PHYSICS BOOSTERS & INTERACTIONS ─────────────
    MkSection(leftCol, "Physics & Collisions", 10)

    -- 1. Push Player (Physics Booster)
    -- Hits target from behind in their facing direction at high velocity, launching them forward
    local pushConn
    local pushBV
    MkToggle(leftCol, "Push Player (Speed Booster)", "PushPlayer", 11, function(state)
        if pushConn then pushConn:Disconnect(); pushConn = nil end
        if pushBV then pushBV:Destroy(); pushBV = nil end
        if state then
            enableAllCollisions()
            local hrp = getHRP()
            if hrp then
                pushBV = Instance.new("BodyVelocity")
                pushBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                pushBV.Velocity = Vector3.zero
                pushBV.Parent   = hrp
            end

            pushConn = RunService.Stepped:Connect(function()
                local myHRP = getHRP()
                if not myHRP then return end
                local target = getActiveTarget()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    local look = tHRP.CFrame.LookVector
                    local power = Shared.Flags["PushForce"] or 200

                    enableAllCollisions()
                    myHRP.CFrame = CFrame.new(tHRP.Position - look * 0.8, tHRP.Position + look)
                    if pushBV then
                        pushBV.Velocity = look * power + Vector3.new(0, 20, 0)
                    else
                        myHRP.AssemblyLinearVelocity = look * power + Vector3.new(0, 20, 0)
                    end
                end
            end)
        else
            if pushBV then pushBV:Destroy(); pushBV = nil end
            local myHRP = getHRP()
            if myHRP then myHRP.AssemblyLinearVelocity = Vector3.zero end
        end
    end)

    MkSlider(leftCol, "Push Force", "PushForce", 50, 450, 200, 12, function(val)
        Shared.Flags["PushForce"] = val
    end)

    -- 2. Solid Platform Mode (Infinite Air Jump Pad)
    -- Creates a solid anchored platform under target feet that stays locked to their horizontal movement
    local platformPart = nil
    local platformConn = nil

    MkToggle(leftCol, "Platform Mode (Air Jump Pad)", "PlatformMode", 13, function(state)
        if platformConn then platformConn:Disconnect(); platformConn = nil end
        if platformPart then platformPart:Destroy(); platformPart = nil end

        if state then
            -- Solid physics platform part
            platformPart = Instance.new("Part")
            platformPart.Name         = "Fih_AirPlatform"
            platformPart.Size         = Vector3.new(7, 1, 7)
            platformPart.Anchored     = true
            platformPart.CanCollide   = true
            platformPart.Transparency = 0.4
            platformPart.Material     = Enum.Material.Neon
            platformPart.BrickColor   = BrickColor.new("Cyan")
            platformPart.TopSurface   = Enum.SurfaceType.Smooth
            platformPart.BottomSurface= Enum.SurfaceType.Smooth
            platformPart.CustomPhysicalProperties = PhysicalProperties.new(0.7, 2.0, 0.0, 1.0, 1.0)
            platformPart.Parent       = Workspace

            enableAllCollisions()

            platformConn = RunService.Stepped:Connect(function()
                local target = getActiveTarget()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    local feetPos = tHRP.Position - Vector3.new(0, 3.1, 0)
                    if platformPart then
                        platformPart.CFrame = CFrame.new(feetPos)
                    end

                    -- Also position our character directly underneath to carry
                    local myHRP = getHRP()
                    if myHRP then
                        enableAllCollisions()
                        myHRP.CFrame = CFrame.new(feetPos - Vector3.new(0, 1.2, 0))
                        myHRP.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end)
        end
    end)

    -- 3. Immovable Path Blocker (Physics Wall)
    -- Spawns an anchored solid barrier right in target walking path
    local blockerPart = nil
    local blockConn   = nil

    MkToggle(leftCol, "Path Blocker (Invisible Wall)", "PathBlocker", 14, function(state)
        if blockConn then blockConn:Disconnect(); blockConn = nil end
        if blockerPart then blockerPart:Destroy(); blockerPart = nil end

        if state then
            blockerPart = Instance.new("Part")
            blockerPart.Name         = "Fih_BlockerWall"
            blockerPart.Size         = Vector3.new(6, 8, 2)
            blockerPart.Anchored     = true
            blockerPart.CanCollide   = true
            blockerPart.Transparency = 0.5
            blockerPart.Material     = Enum.Material.ForceField
            blockerPart.BrickColor   = BrickColor.new("Bright red")
            blockerPart.Parent       = Workspace

            enableAllCollisions()

            blockConn = RunService.Stepped:Connect(function()
                local target = getActiveTarget()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    local vel = tHRP.AssemblyLinearVelocity
                    local dir = vel.Magnitude > 1.5 and vel.Unit or tHRP.CFrame.LookVector
                    local wallPos = tHRP.Position + (dir * 2.2)

                    if blockerPart then
                        blockerPart.CFrame = CFrame.new(wallPos, wallPos + dir)
                    end

                    local myHRP = getHRP()
                    if myHRP then
                        enableAllCollisions()
                        myHRP.CFrame = CFrame.new(wallPos, tHRP.Position)
                        myHRP.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end)
        end
    end)

    -- ── RIGHT COLUMN: SWARM, ORBIT & ATTACHMENTS ─────────────────
    MkSection(rightCol, "Swarm & Orbit Trolls", 1)

    -- 4. Orbit Swarm / Tornado Shield
    local orbitConn
    local orbitAngle = 0
    MkToggle(rightCol, "Orbit Swarm (Tornado)", "OrbitSwarm", 2, function(state)
        if orbitConn then orbitConn:Disconnect(); orbitConn = nil end
        if state then
            orbitConn = RunService.RenderStepped:Connect(function(dt)
                local myHRP = getHRP()
                if not myHRP then return end
                local target = getActiveTarget()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    local speed  = Shared.Flags["OrbitSpeed"] or 18
                    local radius = Shared.Flags["OrbitRadius"] or 5

                    orbitAngle = orbitAngle + dt * speed
                    local x = math.cos(orbitAngle) * radius
                    local z = math.sin(orbitAngle) * radius
                    local pos = tHRP.Position + Vector3.new(x, math.sin(orbitAngle * 2) * 1.5, z)

                    myHRP.CFrame = CFrame.new(pos, tHRP.Position)
                end
            end)
        end
    end)

    MkSlider(rightCol, "Orbit Speed", "OrbitSpeed", 5, 40, 18, 3, function(val)
        Shared.Flags["OrbitSpeed"] = val
    end)

    MkSlider(rightCol, "Orbit Radius", "OrbitRadius", 3, 20, 5, 4, function(val)
        Shared.Flags["OrbitRadius"] = val
    end)

    -- 5. Head Stand / Hat Mode
    local headStandConn
    MkToggle(rightCol, "Head Stand (Hat Mode)", "HeadStand", 5, function(state)
        if headStandConn then headStandConn:Disconnect(); headStandConn = nil end
        if state then
            headStandConn = RunService.Heartbeat:Connect(function()
                local myHRP = getHRP()
                if not myHRP then return end
                local target = getActiveTarget()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 3.3, 0)
                    myHRP.AssemblyLinearVelocity = tHRP.AssemblyLinearVelocity
                end
            end)
        end
    end)

    -- 6. Shadow Leash (Follow Behind)
    local stalkerConn
    MkToggle(rightCol, "Shadow Leash (Follow Behind)", "ShadowLeash", 6, function(state)
        if stalkerConn then stalkerConn:Disconnect(); stalkerConn = nil end
        if state then
            stalkerConn = RunService.Heartbeat:Connect(function()
                local myHRP = getHRP()
                if not myHRP then return end
                local target = getActiveTarget()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3.5)
                end
            end)
        end
    end)

    print("[Troll_Functions] Loaded -- Target Selector, Solid Platform Mode, Physics Booster Online")
end
