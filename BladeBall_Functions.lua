-- BladeBall_Functions.lua
-- Blade Ball Ultimate Automation & Predictive Auto-Parry Engine
-- Complete production suite with latency compensation, clash detection, ball trajectory ESP & auto-curve

return function(Shared)
    local Players           = Shared.Services.Players
    local RunService        = Shared.Services.RunService
    local UserInput         = Shared.Services.UserInput
    local TweenService      = Shared.Services.TweenService
    local Workspace         = Shared.Services.Workspace
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local Player    = Shared.Player
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider  = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab  = Tabs["Blade Ball"] or Tabs["BladeBall"]
    local cols = QuadCols["Blade Ball"] or QuadCols["BladeBall"]
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
    local function getHum()   local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

    -- ── CACHED GAME REMOTES ───────────────────────────────────────
    local parryButtonPress = nil
    local parryTester      = nil
    local parryAttempt     = nil
    local customParry      = nil
    local abilityRemote    = nil

    local function findParryRemotes()
        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
            parryButtonPress = remotes:FindFirstChild("ParryButtonPress")
            parryTester      = remotes:FindFirstChild("ParryTester")
            parryAttempt     = remotes:FindFirstChild("ParryAttempt")
            customParry      = remotes:FindFirstChild("CustomParry")
            abilityRemote    = remotes:FindFirstChild("UseAbility") or remotes:FindFirstChild("AbilityButtonPress")
        end)
    end
    findParryRemotes()

    -- ── BALL TRACKING ENGINE ──────────────────────────────────────
    local lastParryTime = 0
    local lastBallPos = nil
    local lastBallTime = os.clock()

    local function findActiveBall()
        local myHRP = getHRP()
        local candidateBalls = {}

        -- 1. Check workspace.Balls folder
        local folder = Workspace:FindFirstChild("Balls")
        if folder then
            for _, b in ipairs(folder:GetChildren()) do
                if b:IsA("BasePart") then
                    table.insert(candidateBalls, b)
                end
            end
        end

        -- 2. Check TrainingBalls or LobbyTraining folders
        local tBalls = Workspace:FindFirstChild("TrainingBalls") or Workspace:FindFirstChild("Training")
        if tBalls then
            for _, b in ipairs(tBalls:GetChildren()) do
                if b:IsA("BasePart") then table.insert(candidateBalls, b) end
            end
        end

        local lTraining = Workspace:FindFirstChild("Spawn") and Workspace.Spawn:FindFirstChild("LobbyTraining")
        if lTraining then
            for _, d in ipairs(lTraining:GetDescendants()) do
                if d:IsA("BasePart") and (d.Name:lower():find("ball") or d:GetAttribute("realBall") ~= nil or d:GetAttribute("Training") ~= nil or d.Shape == Enum.PartType.Ball) then
                    table.insert(candidateBalls, d)
                end
            end
        end

        -- 3. Check Workspace direct children
        for _, b in ipairs(Workspace:GetChildren()) do
            if (b.Name == "Ball" or b.Name:find("Ball") or b.Name:find("Training")) and b:IsA("BasePart") then
                table.insert(candidateBalls, b)
            end
        end

        if #candidateBalls == 0 then return nil end

        -- If only 1 ball, return it
        if #candidateBalls == 1 then return candidateBalls[1] end

        -- Prioritize realBall == true, or closest active ball to player
        local bestBall = nil
        local bestDist = math.huge

        for _, b in ipairs(candidateBalls) do
            if b:GetAttribute("realBall") == true and isTargetingMe(b) then
                return b
            end
            if myHRP then
                local d = (b.Position - myHRP.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestBall = b
                end
            end
        end

        return bestBall or candidateBalls[1]
    end

    local function isTargetingMe(ball)
        if not ball then return false end
        local t = ball:GetAttribute("target") or ball:GetAttribute("Target")
        if t then
            local tStr = tostring(t)
            if tStr == Player.Name or tStr == Player.DisplayName or tStr == tostring(Player.UserId) or tStr == "all" or tStr:lower():find("training") then
                return true
            end
        end

        local targetVal = ball:FindFirstChild("target") or ball:FindFirstChild("Target")
        if targetVal and targetVal:IsA("ValueBase") then
            if tostring(targetVal.Value) == Player.Name or targetVal.Value == Player.Character then
                return true
            end
        end

        -- Check if it's a Training Ball near the player
        local pName = ball.Parent and ball.Parent.Name:lower() or ""
        local bName = ball.Name:lower()
        if pName:find("train") or bName:find("train") or ball:GetAttribute("Training") or ball:GetAttribute("practice") then
            local hrp = getHRP()
            if hrp then
                local dist = (ball.Position - hrp.Position).Magnitude
                if dist < 65 then return true end
            end
        end

        -- Proximity & Velocity fallback
        local hrp = getHRP()
        if hrp then
            local dist = (ball.Position - hrp.Position).Magnitude
            if dist < 24 then return true end
            if dist < 50 and ball.AssemblyLinearVelocity then
                local toMe = (hrp.Position - ball.Position).Unit
                if toMe:Dot(ball.AssemblyLinearVelocity.Unit) > 0.75 then
                    return true
                end
            end
        end
        return false
    end

    -- ── PARRY EXECUTION MECHANISMS ────────────────────────────────
    local function executeParry()
        local now = os.clock()
        if now - lastParryTime < 0.015 then return end
        lastParryTime = now

        -- Method 1: BindableEvent internal parry & training tester triggers
        pcall(function()
            if parryButtonPress then parryButtonPress:Fire() end
        end)
        pcall(function()
            if parryTester then parryTester:Fire() end
        end)

        -- Method 2: RemoteEvent server parry attempt
        pcall(function()
            if parryAttempt then parryAttempt:FireServer(0.5, CFrame.new(), {}, Vector2.new()) end
        end)

        -- Method 3: CustomParry remote fallback
        pcall(function()
            if customParry then customParry:FireServer() end
        end)

        -- Method 4: Virtual Input Simulation (F key + mouse click)
        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.delay(0.01, function()
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                end)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.delay(0.01, function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
            end
        end)

        -- Method 5: Executor mouse click
        pcall(function()
            if mouse1click then mouse1click() end
        end)
    end

    local function executeAbility()
        if abilityRemote then
            pcall(function()
                if abilityRemote:IsA("RemoteEvent") then
                    abilityRemote:FireServer()
                elseif abilityRemote:IsA("RemoteFunction") then
                    abilityRemote:InvokeServer()
                end
            end)
        end
        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                task.delay(0.02, function()
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                end)
            end
        end)
    end

    -- ── LEFT COLUMN: AUTO PARRY & COMBAT SETTINGS ──────────────────
    MkSection(leftCol, "Predictive Auto Parry Engine", 1)

    -- Status Banner
    local statusFrame = Instance.new("Frame")
    statusFrame.Name                  = "BB_StatusBanner"
    statusFrame.Size                  = UDim2.new(1, 0, 0, 26)
    statusFrame.BackgroundColor3      = Color3.fromRGB(24, 28, 38)
    statusFrame.BorderSizePixel       = 1
    statusFrame.BorderColor3          = Color3.fromRGB(0, 160, 255)
    statusFrame.LayoutOrder           = 2
    statusFrame.Parent                = leftCol

    local statusText = Instance.new("TextLabel")
    statusText.Size                   = UDim2.new(1, 0, 1, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text                   = "⚡ Ball: Idle / Safe"
    statusText.TextColor3             = Color3.fromRGB(0, 220, 140)
    statusText.Font                   = Enum.Font.Code
    statusText.TextSize               = 11
    statusText.Parent                 = statusFrame

    MkToggle(leftCol, "Enable Auto Parry", "BB_AutoParry", 3, function(state)
        Shared.Flags["BB_AutoParry"] = state
    end)

    MkToggle(leftCol, "Clash Spam Mode (Standoff Rapid-Parry)", "BB_ClashSpam", 4, function(state)
        Shared.Flags["BB_ClashSpam"] = state
    end)

    MkToggle(leftCol, "Curve-Ball Trajectory Correction", "BB_CurveCorrection", 5, function(state)
        Shared.Flags["BB_CurveCorrection"] = state
    end)

    MkSlider(leftCol, "Parry Distance (Studs)", "BB_ParryDist", 10, 70, 28, 6, function(val)
        Shared.Flags["BB_ParryDist"] = val
    end)

    MkSlider(leftCol, "Ping Compensation (ms)", "BB_PingOffset", 0, 200, 45, 7, function(val)
        Shared.Flags["BB_PingOffset"] = val
    end)

    MkButton(leftCol, "[ ⚡ Instant Manual Parry ]", 8, function()
        executeParry()
        Shared.Notify("Blade Ball", "Manual parry triggered", true)
    end)

    MkSection(leftCol, "Auto Abilities & Defense", 10)

    MkToggle(leftCol, "Auto Ability on High Velocity", "BB_AutoAbility", 11, function(state)
        Shared.Flags["BB_AutoAbility"] = state
    end)

    MkSlider(leftCol, "Ability Trigger Speed", "BB_AbilitySpeed", 60, 300, 140, 12, function(val)
        Shared.Flags["BB_AbilitySpeed"] = val
    end)

    -- ── RIGHT COLUMN: VISUALS, AIM ASSIST & POSITIONING ───────────
    MkSection(rightCol, "Aim Assist & Deflection", 20)

    MkToggle(rightCol, "Auto-Aim Deflection (Look at Target)", "BB_AutoAim", 21, function(state)
        Shared.Flags["BB_AutoAim"] = state
    end)

    MkToggle(rightCol, "Prioritize Closest Opponent", "BB_PrioritizeClosest", 22, function(state)
        Shared.Flags["BB_PrioritizeClosest"] = state
    end)

    local function getBestEnemyTarget()
        local myHRP = getHRP()
        if not myHRP then return nil end
        local bestPlr, minDist = nil, math.huge

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local d = (plr.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                    if d < minDist then
                        minDist = d
                        bestPlr = plr
                    end
                end
            end
        end
        return bestPlr
    end

    MkSection(rightCol, "Visualizer & Ball Radar", 30)

    local ballHighlight = nil

    local function clearBallVisuals()
        if ballHighlight then pcall(function() ballHighlight:Destroy() end); ballHighlight = nil end
    end

    MkToggle(rightCol, "Ball ESP Highlight & Status", "BB_BallESP", 31, function(state)
        Shared.Flags["BB_BallESP"] = state
        if not state then clearBallVisuals() end
    end)

    MkSection(rightCol, "Movement & Spacing", 40)

    MkToggle(rightCol, "Auto Safe Orbit Spacing", "BB_AutoOrbit", 41, function(state)
        Shared.Flags["BB_AutoOrbit"] = state
    end)

    MkSlider(rightCol, "Orbit Distance", "BB_OrbitDist", 15, 80, 35, 42, function(val)
        Shared.Flags["BB_OrbitDist"] = val
    end)

    -- ── HIGH-FREQUENCY RUNSERVICE PREDICTION & PARRY LOOP ──────────
    RunService.RenderStepped:Connect(function(dt)
        local ball = findActiveBall()
        local hrp  = getHRP()

        if not ball or not hrp then
            statusText.Text = "⚡ Ball: Waiting for round..."
            statusText.TextColor3 = Color3.fromRGB(140, 160, 190)
            statusFrame.BorderColor3 = Color3.fromRGB(0, 160, 255)
            clearBallVisuals()
            lastBallPos = nil
            return
        end

        local now = os.clock()
        local ballPos = ball.Position
        local myPos   = hrp.Position
        local dist    = (ballPos - myPos).Magnitude

        -- Calculate instantaneous velocity from frame-to-frame position delta
        local vel = ball.AssemblyLinearVelocity or Vector3.zero
        if lastBallPos then
            local timeDelta = math.clamp(now - lastBallTime, 0.001, 0.1)
            local calcVel = (ballPos - lastBallPos) / timeDelta
            if calcVel.Magnitude > vel.Magnitude then
                vel = calcVel
            end
        end
        lastBallPos = ballPos
        lastBallTime = now

        local speed = vel.Magnitude
        local dirToMe = (myPos - ballPos).Unit
        local approachSpeed = (speed > 1) and vel:Dot(dirToMe) or speed
        local isTarget = isTargetingMe(ball)

        -- Dynamic ping offset
        local pingMs = Shared.Flags["BB_PingOffset"] or 45
        local pingOffsetSec = pingMs / 1000

        -- Time to Impact
        local timeToImpact = (approachSpeed > 1) and (dist / approachSpeed) or (dist / math.max(speed, 1))

        -- Configured parry threshold
        local customDist = Shared.Flags["BB_ParryDist"] or 30
        local dynamicParryDistance = customDist + math.clamp(speed * (0.35 + pingOffsetSec), 0, 55)

        -- Status Banner update
        local targetName = tostring(ball:GetAttribute("target") or "None")
        if isTarget then
            statusText.Text = string.format("🔴 INCOMING! Dist: %dm | Spd: %d | Time: %.2fs", math.floor(dist), math.floor(speed), math.max(0, timeToImpact))
            statusText.TextColor3 = Color3.fromRGB(255, 60, 60)
            statusFrame.BorderColor3 = Color3.fromRGB(255, 60, 60)
        else
            statusText.Text = string.format("🟢 Target: %s | Dist: %dm | Spd: %d", targetName:sub(1, 10), math.floor(dist), math.floor(speed))
            statusText.TextColor3 = Color3.fromRGB(0, 220, 140)
            statusFrame.BorderColor3 = Color3.fromRGB(0, 160, 255)
        end

        -- 1. Ball Visualizer ESP & Highlight
        if Shared.Flags["BB_BallESP"] then
            if not ballHighlight or ballHighlight.Adornee ~= ball then
                if ballHighlight then pcall(function() ballHighlight:Destroy() end) end
                ballHighlight = Instance.new("Highlight")
                ballHighlight.Name = "BB_BallHighlight"
                ballHighlight.FillTransparency = 0.35
                ballHighlight.OutlineTransparency = 0
                ballHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                ballHighlight.Adornee = ball
                ballHighlight.Parent = Shared.GUI or Workspace
            end
            ballHighlight.FillColor    = isTarget and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(0, 230, 140)
            ballHighlight.OutlineColor = isTarget and Color3.fromRGB(255, 255, 100) or Color3.fromRGB(255, 255, 255)
        else
            if ballHighlight then pcall(function() ballHighlight:Destroy() end); ballHighlight = nil end
        end

        -- 2. AUTO PARRY ENGINE
        if Shared.Flags["BB_AutoParry"] then
            local shouldParry = false

            if isTarget then
                if dist <= dynamicParryDistance or timeToImpact <= (0.42 + pingOffsetSec) then
                    shouldParry = true
                end
            end

            -- Clash Standoff Mode
            if Shared.Flags["BB_ClashSpam"] and dist <= 16 then
                shouldParry = true
            end

            if shouldParry then
                if Shared.Flags["BB_AutoAim"] then
                    local enemy = getBestEnemyTarget()
                    if enemy and enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart") then
                        local lookAt = enemy.Character.HumanoidRootPart.Position
                        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(lookAt.X, hrp.Position.Y, lookAt.Z))
                    end
                end

                executeParry()

                if Shared.Flags["BB_AutoAbility"] then
                    local thresh = Shared.Flags["BB_AbilitySpeed"] or 140
                    if speed >= thresh and dist < 25 then
                        executeAbility()
                    end
                end
            end
        end

        -- 3. Auto Orbit & Safe Spacing
        if Shared.Flags["BB_AutoOrbit"] and isTarget then
            local targetOrbit = Shared.Flags["BB_OrbitDist"] or 35
            local hum = getHum()
            if hum and dist < targetOrbit - 5 then
                local awayDir = (myPos - ballPos).Unit
                hum:Move(Vector3.new(awayDir.X, 0, awayDir.Z), false)
            end
        end
    end)

    print("[BladeBall_Functions] Loaded -- Predictive Auto-Parry, Clash Spam & Ball ESP Online")
end
