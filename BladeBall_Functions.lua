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

    -- ── BALL TRACKING & ANTI-DOUBLE PARRY ENGINE ─────────────────
    local lastParryTime = 0
    local lastBallPos = nil
    local lastBallTime = os.clock()
    local hasParriedCurrentVolley = false
    local lastParryTick = 0

    -- Hook Blade Ball's parry confirmation events to acknowledge deflected state
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            for _, rName in ipairs({"ParrySuccess", "ParrySuccessClient", "ParrySuccessAll", "VisualCD", "VisualBindableCD"}) do
                local rObj = remotes:FindFirstChild(rName)
                if rObj then
                    if rObj:IsA("RemoteEvent") then
                        rObj.OnClientEvent:Connect(function()
                            hasParriedCurrentVolley = true
                        end)
                    elseif rObj:IsA("BindableEvent") then
                        rObj.Event:Connect(function()
                            hasParriedCurrentVolley = true
                        end)
                    end
                end
            end
        end
    end)

    local function findActiveBall()
        local myHRP = getHRP()
        local myPos = myHRP and myHRP.Position or Vector3.zero

        -- 1. Priority 1: Check active match balls in workspace.Balls
        local folder = Workspace:FindFirstChild("Balls")
        if folder and #folder:GetChildren() > 0 then
            -- Pass A: Look for child with realBall == true
            for _, b in ipairs(folder:GetChildren()) do
                if b:IsA("BasePart") and b:GetAttribute("realBall") == true then
                    return b
                end
            end
            -- Pass B: Look for child with a non-empty target attribute
            for _, b in ipairs(folder:GetChildren()) do
                if b:IsA("BasePart") and b.Name ~= "Temp" then
                    local t = b:GetAttribute("target")
                    if t and t ~= "" and t ~= "None" then
                        return b
                    end
                end
            end
            -- Pass C: Any BasePart in Balls folder
            for _, b in ipairs(folder:GetChildren()) do
                if b:IsA("BasePart") and b.Name ~= "Temp" then
                    return b
                end
            end
        end

        -- 2. Priority 2: Check Workspace.TrainingBalls (if in training area)
        local tBalls = Workspace:FindFirstChild("TrainingBalls") or Workspace:FindFirstChild("Training")
        if tBalls and #tBalls:GetChildren() > 0 then
            for _, b in ipairs(tBalls:GetChildren()) do
                if b:IsA("BasePart") and (b:GetAttribute("realBall") == true or b:GetAttribute("target") ~= nil) then
                    local d = (b.Position - myPos).Magnitude
                    if d < 120 then return b end
                end
            end
            for _, b in ipairs(tBalls:GetChildren()) do
                if b:IsA("BasePart") then
                    local d = (b.Position - myPos).Magnitude
                    if d < 120 then return b end
                end
            end
        end

        -- 3. Priority 3: Check LobbyTraining descendants
        local lTraining = Workspace:FindFirstChild("Spawn") and Workspace.Spawn:FindFirstChild("LobbyTraining")
        if lTraining then
            for _, d in ipairs(lTraining:GetDescendants()) do
                if d:IsA("BasePart") and (d.Name:lower():find("ball") or d:GetAttribute("Training") ~= nil) then
                    local dist = (d.Position - myPos).Magnitude
                    if dist < 90 then return d end
                end
            end
        end

        -- 4. Fallback: Any ball in Workspace
        for _, b in ipairs(Workspace:GetChildren()) do
            if (b.Name == "Ball" or b.Name:find("Ball") or b.Name:find("Training")) and b:IsA("BasePart") then
                return b
            end
        end

        return nil
    end

    local function isTargetingMe(ball)
        if not ball then return false end

        -- If ball is inside a folder and has a sibling with realBall == true, resolve to the real ball
        if ball.Parent and ball:GetAttribute("realBall") ~= true then
            for _, sibling in ipairs(ball.Parent:GetChildren()) do
                if sibling:IsA("BasePart") and sibling:GetAttribute("realBall") == true then
                    ball = sibling
                    break
                end
            end
        end

        -- 1. Check exact match target attributes (Arena Match Balls)
        local t = ball:GetAttribute("target") or ball:GetAttribute("Target")
        if t then
            local tStr = tostring(t)
            if tStr == Player.Name or tStr == Player.DisplayName or tStr == tostring(Player.UserId) or tStr == "all" then
                return true
            end
            -- If target is another player in the arena, definitely not targeting us
            if tStr ~= "" and tStr ~= "None" and tStr ~= "nil" and not tStr:lower():find("target<") and not tStr:lower():find("train") then
                return false
            end
        end

        -- 2. Check target ValueObject
        local targetVal = ball:FindFirstChild("target") or ball:FindFirstChild("Target")
        if targetVal and targetVal:IsA("ValueBase") then
            if tostring(targetVal.Value) == Player.Name or targetVal.Value == Player.Character then
                return true
            elseif targetVal.Value ~= nil and tostring(targetVal.Value) ~= "" then
                return false
            end
        end

        -- 3. Check Practice / Training Ball (Workspace.TrainingBalls or LobbyTraining)
        local isTraining = (ball.Parent and (ball.Parent.Name == "TrainingBalls" or ball.Parent.Name == "Training"))
                        or ball.Name:lower():find("train")
                        or ball:GetAttribute("Training") ~= nil
                        or (t and tostring(t):lower():find("target<"))

        if isTraining then
            local hrp = getHRP()
            if hrp then
                local toMe = (hrp.Position - ball.Position)
                local dist = toMe.Magnitude
                if dist < 85 then
                    local vel = ball.AssemblyLinearVelocity or Vector3.zero
                    if vel.Magnitude < 2 then
                        return true
                    end
                    local dot = toMe.Unit:Dot(vel.Unit)
                    if dot > 0.35 or dist < 24 then
                        return true
                    end
                end
            end
            return false
        end

        return false
    end

    -- ── PARRY EXECUTION MECHANISMS ────────────────────────────────
    local function executeParry()
        local now = os.clock()
        if now - lastParryTime < 0.05 or hasParriedCurrentVolley then return end
        lastParryTime = now
        lastParryTick = now
        hasParriedCurrentVolley = true

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

    MkSlider(leftCol, "Parry Distance (Studs)", "BB_ParryDist", 5, 100, 28, 6, function(val)
        Shared.Flags["BB_ParryDist"] = val
    end)

    MkSlider(leftCol, "Ping Compensation (ms)", "BB_PingOffset", 0, 200, 45, 7, function(val)
        Shared.Flags["BB_PingOffset"] = val
    end)

    MkToggle(leftCol, "Dynamic Velocity Distance Scaling", "BB_VelScaling", 8, function(state)
        Shared.Flags["BB_VelScaling"] = state
    end)

    MkSlider(leftCol, "Velocity Scale Threshold", "BB_VelThreshold", 30, 200, 70, 9, function(val)
        Shared.Flags["BB_VelThreshold"] = val
    end)

    MkButton(leftCol, "[ ⚡ Instant Manual Parry ]", 10, function()
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
    local zoneRingAdorn  = nil
    local zoneSphereAdorn = nil

    local function clearBallVisuals()
        if ballHighlight then pcall(function() ballHighlight:Destroy() end); ballHighlight = nil end
        if zoneRingAdorn then pcall(function() zoneRingAdorn:Destroy() end); zoneRingAdorn = nil end
        if zoneSphereAdorn then pcall(function() zoneSphereAdorn:Destroy() end); zoneSphereAdorn = nil end
    end

    MkToggle(rightCol, "Ball ESP Highlight & Status", "BB_BallESP", 31, function(state)
        Shared.Flags["BB_BallESP"] = state
        if not state and ballHighlight then
            pcall(function() ballHighlight:Destroy() end)
            ballHighlight = nil
        end
    end)

    MkToggle(rightCol, "Parry Hit-Zone Area Visualizer", "BB_ParryZone", 32, function(state)
        Shared.Flags["BB_ParryZone"] = state
        if not state then
            if zoneRingAdorn then pcall(function() zoneRingAdorn:Destroy() end); zoneRingAdorn = nil end
            if zoneSphereAdorn then pcall(function() zoneSphereAdorn:Destroy() end); zoneSphereAdorn = nil end
        end
    end)

    MkSlider(rightCol, "Hit-Zone Transparency (%)", "BB_ZoneAlpha", 20, 90, 55, 33, function(val)
        Shared.Flags["BB_ZoneAlpha"] = val
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

        -- Dynamic hit-zone radius: base distance + dynamic velocity scaling above threshold
        local baseDist = Shared.Flags["BB_ParryDist"] or 28
        local velScaling = Shared.Flags["BB_VelScaling"] ~= false
        local velThreshold = Shared.Flags["BB_VelThreshold"] or 70

        local velocityBonus = 0
        local reactionWindow = 0.12 + pingOffsetSec

        if velScaling and approachSpeed > velThreshold then
            local excessSpeed = approachSpeed - velThreshold
            -- Scale extra distance linearly with speed excess to give reaction room at high velocity
            velocityBonus = (excessSpeed * 0.16) + math.clamp(approachSpeed * (pingOffsetSec * 0.4), 0, 15)
            -- Expand the reaction time-to-impact window slightly at extreme speeds
            reactionWindow = reactionWindow + math.clamp(excessSpeed / 1200, 0, 0.07)
        else
            velocityBonus = math.clamp(approachSpeed * (pingOffsetSec * 0.2), 0, 4)
        end

        local dynamicParryDistance = math.clamp(baseDist + velocityBonus, 5, 100)

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

        -- 2. Dynamic Parry Hit-Zone Area 3D Visualizer (Ground Disc + 3D Hitbox Box)
        if Shared.Flags["BB_ParryZone"] and hrp then
            local alphaPercent = Shared.Flags["BB_ZoneAlpha"] or 55
            local transparency = alphaPercent / 100
            local themeColor = isTarget and Color3.fromRGB(255, 45, 45) or Color3.fromRGB(0, 200, 255)
            local terrain = workspace.Terrain or workspace

            -- Ground Disc / Ring
            if not zoneRingAdorn or zoneRingAdorn.Adornee ~= hrp or not zoneRingAdorn.Parent then
                if zoneRingAdorn then pcall(function() zoneRingAdorn:Destroy() end) end
                zoneRingAdorn = Instance.new("CylinderHandleAdornment")
                zoneRingAdorn.Name = "BB_HitZoneRing"
                zoneRingAdorn.Adornee = hrp
                zoneRingAdorn.AlwaysOnTop = true
                zoneRingAdorn.ZIndex = 10
                zoneRingAdorn.Parent = terrain
            end
            zoneRingAdorn.Radius = dynamicParryDistance
            zoneRingAdorn.Height = 0.5
            zoneRingAdorn.CFrame = CFrame.new(0, -2.8, 0) * CFrame.Angles(math.rad(90), 0, 0)
            zoneRingAdorn.Color3 = themeColor
            zoneRingAdorn.Transparency = math.clamp(transparency * 0.7, 0.1, 0.9)

            -- 3D Volumetric Hitbox Box
            if not zoneSphereAdorn or zoneSphereAdorn.Adornee ~= hrp or not zoneSphereAdorn.Parent then
                if zoneSphereAdorn then pcall(function() zoneSphereAdorn:Destroy() end) end
                zoneSphereAdorn = Instance.new("BoxHandleAdornment")
                zoneSphereAdorn.Name = "BB_HitZoneBox"
                zoneSphereAdorn.Adornee = hrp
                zoneSphereAdorn.AlwaysOnTop = true
                zoneSphereAdorn.ZIndex = 8
                zoneSphereAdorn.Parent = terrain
            end
            local boxDim = dynamicParryDistance * 2
            zoneSphereAdorn.Size = Vector3.new(boxDim, boxDim, boxDim)
            zoneSphereAdorn.Color3 = themeColor
            zoneSphereAdorn.Transparency = math.clamp(transparency * 0.9, 0.4, 0.95)
        else
            if zoneRingAdorn then pcall(function() zoneRingAdorn:Destroy() end); zoneRingAdorn = nil end
            if zoneSphereAdorn then pcall(function() zoneSphereAdorn:Destroy() end); zoneSphereAdorn = nil end
        end

        -- Reset parried volley flag when ball leaves or deflects away
        if hasParriedCurrentVolley then
            local timeSinceParry = now - lastParryTick
            if not isTarget or approachSpeed < -2 or timeSinceParry > 0.45 then
                hasParriedCurrentVolley = false
            end
        end

        -- 3. AUTO PARRY ENGINE (Velocity & Physics-Driven)
        if Shared.Flags["BB_AutoParry"] then
            local shouldParry = false

            -- STRICT RULE: ONLY parry if the ball is actually targeted on local player AND not already parried in this volley
            if isTarget and not hasParriedCurrentVolley then
                -- If ball is traveling towards the player
                if approachSpeed > 0 or speed < 5 then
                    -- Trigger parry based on calculated time to impact or velocity-scaled distance window
                    if dist <= dynamicParryDistance or timeToImpact <= reactionWindow then
                        shouldParry = true
                    end

                    -- Clash / Standoff close-range trigger (only when targeted)
                    if Shared.Flags["BB_ClashSpam"] and dist <= 16 then
                        shouldParry = true
                    end
                end
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
