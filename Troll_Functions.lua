-- Troll_Functions.lua
-- Server-Replicated Physics Trolls: Push Booster, Platform Mode, Orbit Swarm, Path Blocker, Stalker

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

    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   return Shared.HumanoidRP or (getChar() and getChar():FindFirstChild("HumanoidRootPart")) end
    local function getHuman() return getChar() and getChar():FindFirstChildOfClass("Humanoid") end

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

    -- ── LEFT COLUMN: PHYSICS TROLLS & BOOSTERS ────────────────────
    MkSection(leftCol, "Physics Boosters & Interactions", 1)

    -- 1. Push Player (Physics Booster)
    -- Hits target from behind in their facing direction at high velocity, launching them forward
    local pushConn
    MkToggle(leftCol, "Push Player (Speed Booster)", "PushPlayer", 2, function(state)
        if pushConn then pushConn:Disconnect(); pushConn = nil end
        if state then
            pushConn = RunService.Heartbeat:Connect(function()
                local myHRP = getHRP()
                if not myHRP then return end
                local target = getNearestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    local look = tHRP.CFrame.LookVector
                    local power = Shared.Flags["PushForce"] or 160

                    -- Place our character right behind them and apply forward impulse
                    myHRP.CFrame = CFrame.new(tHRP.Position - look * 1.5, tHRP.Position + look)
                    myHRP.AssemblyLinearVelocity = look * power + Vector3.new(0, 25, 0)
                end
            end)
        else
            local myHRP = getHRP()
            if myHRP then myHRP.AssemblyLinearVelocity = Vector3.zero end
        end
    end)

    MkSlider(leftCol, "Push Force", "PushForce", 50, 350, 160, 3, function(val)
        Shared.Flags["PushForce"] = val
    end)

    -- 2. Platform Mode (Infinite Air Jump Pad)
    -- Positions your character directly under target's feet so they can walk/jump in mid-air
    local platformConn
    MkToggle(leftCol, "Platform Mode (Air Jump Pad)", "PlatformMode", 4, function(state)
        if platformConn then platformConn:Disconnect(); platformConn = nil end
        if state then
            platformConn = RunService.Heartbeat:Connect(function()
                local myHRP = getHRP()
                if not myHRP then return end
                local target = getNearestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    -- Position flat directly underneath target's feet (2.6 studs down)
                    myHRP.CFrame = CFrame.new(tHRP.Position - Vector3.new(0, 2.6, 0))
                    myHRP.AssemblyLinearVelocity = tHRP.AssemblyLinearVelocity
                end
            end)
        end
    end)

    -- 3. Path Blocker (Physics Wall)
    -- Plants your character right in front of target's moving path to block them
    local blockConn
    MkToggle(leftCol, "Path Blocker (Invisible Wall)", "PathBlocker", 5, function(state)
        if blockConn then blockConn:Disconnect(); blockConn = nil end
        if state then
            blockConn = RunService.Heartbeat:Connect(function()
                local myHRP = getHRP()
                if not myHRP then return end
                local target = getNearestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    local vel = tHRP.AssemblyLinearVelocity
                    local dir = vel.Magnitude > 2 and vel.Unit or tHRP.CFrame.LookVector
                    myHRP.CFrame = CFrame.new(tHRP.Position + dir * 2.2, tHRP.Position)
                    myHRP.AssemblyLinearVelocity = Vector3.zero
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
                local target = getNearestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    local speed  = Shared.Flags["OrbitSpeed"] or 15
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
                local target = getNearestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 3.3, 0)
                    myHRP.AssemblyLinearVelocity = tHRP.AssemblyLinearVelocity
                end
            end)
        end
    end)

    -- 6. Shadow Stalker / Follower
    local stalkerConn
    MkToggle(rightCol, "Shadow Leash (Follow Behind)", "ShadowLeash", 6, function(state)
        if stalkerConn then stalkerConn:Disconnect(); stalkerConn = nil end
        if state then
            stalkerConn = RunService.Heartbeat:Connect(function()
                local myHRP = getHRP()
                if not myHRP then return end
                local target = getNearestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tHRP = target.Character.HumanoidRootPart
                    myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3.5)
                end
            end)
        end
    end)

    print("[Troll_Functions] Loaded -- Physics Booster, Platform Mode, Orbit Swarm Online")
end
