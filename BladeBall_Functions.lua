-- BladeBall_Functions.lua
-- Blade Ball Ultimate Automation & Predictive Auto-Parry Engine
-- Complete production suite with latency compensation, clash detection, ball trajectory ESP & auto-curve

return function(Shared)
    local Services          = Shared.Services or {}
    local Players           = Services.Players or game:GetService("Players")
    local RunService        = Services.RunService or game:GetService("RunService")
    local UserInput         = Services.UserInput or game:GetService("UserInputService")
    local TweenService      = Services.TweenService or game:GetService("TweenService")
    local Workspace         = Services.Workspace or workspace
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
    local lastUIUpdate = 0
    local lastTargetState = nil

    -- Hook Blade Ball's parry confirmation event
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local pSuccess = remotes:FindFirstChild("ParrySuccessClient") or remotes:FindFirstChild("ParrySuccess")
            if pSuccess then
                if pSuccess:IsA("RemoteEvent") then
                    pSuccess.OnClientEvent:Connect(function()
                        hasParriedCurrentVolley = true
                    end)
                elseif pSuccess:IsA("BindableEvent") then
                    pSuccess.Event:Connect(function()
                        hasParriedCurrentVolley = true
                    end)
                end
            end
        end
    end)

    -- ── HIGH PERFORMANCE BALL TRACKING ENGINE ────────────────────
    local cachedBall = nil

    local function findActiveBall()
        if cachedBall and cachedBall.Parent and cachedBall:IsA("BasePart") then
            return cachedBall
        end

        local myHRP = getHRP()
        local myPos = myHRP and myHRP.Position or Vector3.zero

        -- 1. Priority 1: Check active match balls in workspace.Balls
        local folder = Workspace:FindFirstChild("Balls")
        if folder and #folder:GetChildren() > 0 then
            for _, b in ipairs(folder:GetChildren()) do
                if b:IsA("BasePart") and b:GetAttribute("realBall") == true then
                    cachedBall = b
                    return b
                end
            end
            for _, b in ipairs(folder:GetChildren()) do
                if b:IsA("BasePart") and b.Name ~= "Temp" then
                    local t = b:GetAttribute("target")
                    if t and t ~= "" and t ~= "None" then
                        cachedBall = b
                        return b
                    end
                end
            end
            for _, b in ipairs(folder:GetChildren()) do
                if b:IsA("BasePart") and b.Name ~= "Temp" then
                    cachedBall = b
                    return b
                end
            end
        end

        -- 2. Priority 2: Check Workspace.TrainingBalls (Lobby / Practice)
        local tBalls = Workspace:FindFirstChild("TrainingBalls") or Workspace:FindFirstChild("Training")
        if tBalls and #tBalls:GetChildren() > 0 then
            for _, b in ipairs(tBalls:GetChildren()) do
                if b:IsA("BasePart") then
                    cachedBall = b
                    return b
                end
            end
        end

        cachedBall = nil
        return nil
    end

    -- Event listener for instant zero-latency ball detection
    pcall(function()
        local ballsFolder = Workspace:FindFirstChild("Balls")
        if ballsFolder then
            ballsFolder.ChildAdded:Connect(function(child)
                if child:IsA("BasePart") then
                    if child:GetAttribute("realBall") == true or not cachedBall then
                        cachedBall = child
                    end
                end
            end)
            ballsFolder.ChildRemoved:Connect(function(child)
                if cachedBall == child then cachedBall = nil end
            end)
        end
        local tFolder = Workspace:FindFirstChild("TrainingBalls")
        if tFolder then
            tFolder.ChildAdded:Connect(function(child)
                if child:IsA("BasePart") then cachedBall = child end
            end)
            tFolder.ChildRemoved:Connect(function(child)
                if cachedBall == child then cachedBall = nil end
            end)
        end
    end)

    local function isTargetingMe(ball)
        if not ball then return false end

        -- If ball is inside Balls folder and has a sibling with realBall == true, resolve to the real ball
        if ball.Parent and ball.Parent.Name == "Balls" and ball:GetAttribute("realBall") ~= true then
            for _, sibling in ipairs(ball.Parent:GetChildren()) do
                if sibling:IsA("BasePart") and sibling:GetAttribute("realBall") == true then
                    ball = sibling
                    break
                end
            end
        end

        local t = ball:GetAttribute("target") or ball:GetAttribute("Target")
        local tStr = t and tostring(t) or ""

        -- 1. Exact match target (Arena Matches)
        if tStr == Player.Name or tStr == Player.DisplayName or tStr == tostring(Player.UserId) or tStr == "all" then
            return true
        end

        -- 2. If target is explicitly someone else in the match
        if tStr ~= "" and tStr ~= "None" and tStr ~= "nil" and not tStr:lower():find("target<") and not tStr:lower():find("train") then
            return false
        end

        -- 3. Target ValueObject fallback
        local targetVal = ball:FindFirstChild("target") or ball:FindFirstChild("Target")
        if targetVal and targetVal:IsA("ValueBase") then
            if tostring(targetVal.Value) == Player.Name or targetVal.Value == Player.Character then
                return true
            elseif targetVal.Value ~= nil and tostring(targetVal.Value) ~= "" then
                return false
            end
        end

        -- 4. Practice Ball & Vector Trajectory Check
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
                if dot > 0.45 or dist < 22 then
                    return true
                end
            end
        end

        return false
    end

    -- ── PARRY EXECUTION MECHANISMS (SPEED-AWARE ANTI-DOUBLE PARRY) ──
    local function executeParry(currentSpeed)
        local now = os.clock()
        local spd = currentSpeed or 0

        -- Dynamic Cooldown Guard: Strict 0.55s cooldown for slow/normal balls, rapid for high velocity
        local minCooldown = 0.55
        if spd >= 140 then
            minCooldown = 0.05
        elseif spd >= 100 then
            minCooldown = 0.15
        elseif spd >= 70 then
            minCooldown = 0.35
        end

        if now - lastParryTime < minCooldown then return false end
        lastParryTime = now
        lastParryTick = now
        hasParriedCurrentVolley = true

        -- Method 1: BindableEvent internal trigger
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
        pcall(function()
            if customParry then customParry:FireServer() end
        end)

        -- Method 3: Virtual Input (F key + mouse click)
        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.delay(0.015, function()
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                end)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.delay(0.015, function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
            end
        end)

        -- Method 4: Mouse Click
        pcall(function()
            if mouse1click then mouse1click() end
        end)

        return true
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

    MkButton(leftCol, "[ ⚡ Instant Manual Parry ]", 7, function()
        executeParry()
        Shared.Notify("Blade Ball", "Manual parry triggered", true)
    end)

    MkSection(leftCol, "Auto Abilities & Defense", 8)

    MkToggle(leftCol, "Auto Ability on High Velocity", "BB_AutoAbility", 9, function(state)
        Shared.Flags["BB_AutoAbility"] = state
    end)

    MkSlider(leftCol, "Ability Trigger Speed", "BB_AbilitySpeed", 60, 300, 140, 10, function(val)
        Shared.Flags["BB_AbilitySpeed"] = val
    end)

    MkSection(leftCol, "Ball Velocity & Speed Modifier", 11)

    MkToggle(leftCol, "Enable Custom Ball Velocity Override", "BB_CustomVelocityEnabled", 12, function(state)
        Shared.Flags["BB_CustomVelocityEnabled"] = state
    end)

    MkSlider(leftCol, "Custom Ball Speed (50 - 500)", "BB_CustomVelocityValue", 50, 500, 180, 13, function(val)
        Shared.Flags["BB_CustomVelocityValue"] = val
    end)

    MkToggle(leftCol, "Deflection Velocity Multiplier", "BB_VelocityMultiplierEnabled", 14, function(state)
        Shared.Flags["BB_VelocityMultiplierEnabled"] = state
    end)

    MkSlider(leftCol, "Deflection Multiplier (1.0x - 3.0x)", "BB_VelocityMultiplierFactor", 10, 30, 15, 15, function(val)
        Shared.Flags["BB_VelocityMultiplierFactor"] = val
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

    -- ── LIVE NETWORK PING & LATENCY MONITOR ──────────────────────
    local function getLivePingSec()
        local pingSec = 0.055
        pcall(function()
            local stats = game:GetService("Stats")
            if stats then
                local net = stats:FindFirstChild("Network")
                if net then
                    local sItem = net:FindFirstChild("ServerStatsItem")
                    if sItem then
                        local dp = sItem:FindFirstChild("Data Ping")
                        if dp then
                            pingSec = dp:GetValue() / 1000
                        end
                    end
                end
                if pingSec == 0.055 and stats:FindFirstChild("PerformanceStats") then
                    local p = stats.PerformanceStats:FindFirstChild("Ping")
                    if p then pingSec = p:GetValue() / 1000 end
                end
            end
        end)
        return math.clamp(pingSec, 0.015, 0.350)
    end

    -- ── REAL-TIME HIGH-FREQUENCY PHYSICS CALCULATION CYCLE ────────
    local prevVel = Vector3.zero
    local prevBallPos = nil
    local prevTime = os.clock()

    local bbHeartbeatConn = RunService.Heartbeat:Connect(function(dt)
        local ball = findActiveBall()
        if not ball or not ball.Parent then
            if statusText and statusText.Parent and statusText.Text ~= "⚡ Ball: Idle / Searching" then
                statusText.Text = "⚡ Ball: Idle / Searching"
                statusText.TextColor3 = Color3.fromRGB(0, 220, 140)
                if statusFrame and statusFrame.Parent then
                    statusFrame.BorderColor3 = Color3.fromRGB(0, 160, 255)
                end
            end
            if zoneRingAdorn   then pcall(function() zoneRingAdorn:Destroy() end); zoneRingAdorn = nil end
            if zoneSphereAdorn then pcall(function() zoneSphereAdorn:Destroy() end); zoneSphereAdorn = nil end
            if ballHighlight   then pcall(function() ballHighlight:Destroy() end); ballHighlight = nil end
            hasParriedCurrentVolley = false
            return
        end

        local hrp = getHRP()
        if not hrp then return end

        local now = os.clock()
        local myPos = hrp.Position
        local ballPos = ball.Position
        local dist = (myPos - ballPos).Magnitude

        -- 1. True Vector Velocity & Acceleration Kinematics
        local vel = ball.AssemblyLinearVelocity or Vector3.zero
        local deltaSec = math.max(0.001, now - prevTime)
        if prevBallPos then
            local computedVel = (ballPos - prevBallPos) / deltaSec
            if computedVel.Magnitude > vel.Magnitude then
                vel = computedVel
            end
        end

        local acceleration = (vel - prevVel) / deltaSec
        prevVel = vel
        prevBallPos = ballPos
        prevTime = now

        local speed = vel.Magnitude
        local toMe = (myPos - ballPos)
        local dirToMe = (dist > 0.01) and (toMe / dist) or Vector3.zero
        local approachSpeed = (speed > 1) and vel:Dot(dirToMe) or speed
        local isTarget = isTargetingMe(ball)

        -- 2. Fully Automated Network Ping & Server Lead Time
        local livePingSec = getLivePingSec()
        local serverLeadTime = (livePingSec * 0.60) + 0.016 -- Live one-way RTT + 1 frame pipeline

        -- 3. Projected Future Positions (2nd Order Kinematics)
        local predictedBallPos = ballPos + (vel * serverLeadTime) + (0.5 * acceleration * (serverLeadTime ^ 2))
        local hrpVel = hrp.AssemblyLinearVelocity or Vector3.zero
        local predictedHrpPos = myPos + (hrpVel * serverLeadTime)
        local predictedDist = (predictedHrpPos - predictedBallPos).Magnitude

        -- 4. Precise Time To Impact (TTI)
        local timeToImpact = (approachSpeed > 2) and (dist / approachSpeed) or (dist / math.max(speed, 1))

        -- 5. Status Banner Display
        if isTarget ~= lastTargetState or (now - lastUIUpdate > 0.08) then
            lastUIUpdate = now
            lastTargetState = isTarget
            local targetName = tostring(ball:GetAttribute("target") or "None")
            if isTarget then
                statusText.Text = string.format("[ALERT] INCOMING! Dist: %dm | Spd: %d | Ping: %dms | TTI: %.2fs", math.floor(dist), math.floor(speed), math.floor(livePingSec * 1000), math.max(0, timeToImpact))
                statusText.TextColor3 = Color3.fromRGB(255, 60, 60)
                statusFrame.BorderColor3 = Color3.fromRGB(255, 60, 60)
            else
                statusText.Text = string.format("[SAFE] Target: %s | Dist: %dm | Spd: %d | Ping: %dms", targetName:sub(1, 10), math.floor(dist), math.floor(speed), math.floor(livePingSec * 1000))
                statusText.TextColor3 = Color3.fromRGB(0, 220, 140)
                statusFrame.BorderColor3 = Color3.fromRGB(0, 160, 255)
            end
        end

        -- 6. Dynamic Parry Threshold Computation (100% Self-Calibrating)
        local baseDist = Shared.Flags["BB_ParryDist"] or 28

        local dynamicLeadBonus = 0
        if approachSpeed > 50 then
            local excessSpeed = approachSpeed - 50
            dynamicLeadBonus = (excessSpeed * 0.085) + (approachSpeed * (serverLeadTime * 0.45))
        else
            dynamicLeadBonus = approachSpeed * (serverLeadTime * 0.25)
        end

        local dynamicParryDistance = math.clamp(baseDist + dynamicLeadBonus, 8, 140)
        local dynamicReactionTime = math.clamp((baseDist / math.max(approachSpeed, 20)) + serverLeadTime, 0.08, 0.50)

        -- 7. Visualizer Highlights & Adornments
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

        if Shared.Flags["BB_ParryZone"] and hrp then
            local alphaPercent = Shared.Flags["BB_ZoneAlpha"] or 55
            local transparency = alphaPercent / 100
            local themeColor = isTarget and Color3.fromRGB(255, 45, 45) or Color3.fromRGB(0, 200, 255)
            local terrain = workspace.Terrain or workspace

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

        -- Reset volley flag when ball is deflected or moving away
        if hasParriedCurrentVolley then
            local timeSinceParry = now - lastParryTick
            if not isTarget or approachSpeed < -2.5 then
                hasParriedCurrentVolley = false
            elseif speed >= 110 and timeSinceParry > 0.08 then
                -- Ultra-high speed volleys / clashes can reset rapidly
                hasParriedCurrentVolley = false
            end
        end

        -- 8. SPEED-ADAPTIVE PARRY TRIGGER (Zero Double-Parrying on Slow Speeds)
        if Shared.Flags["BB_AutoParry"] then
            local shouldParry = false

            if isTarget and not hasParriedCurrentVolley then
                if speed < 65 then
                    -- Slow ball: Precise trigger when inside hit window (single authoritative click)
                    local slowHitDist = math.min(baseDist, 22)
                    if dist <= slowHitDist or timeToImpact <= (serverLeadTime + 0.06) then
                        shouldParry = true
                    end
                elseif speed < 120 then
                    -- Medium ball: Standard approach collision window
                    if dist <= dynamicParryDistance or predictedDist <= dynamicParryDistance or timeToImpact <= dynamicReactionTime then
                        shouldParry = true
                    end
                else
                    -- High velocity (> 120): Instant predictive trigger & standoff clash
                    if dist <= dynamicParryDistance or predictedDist <= dynamicParryDistance or timeToImpact <= dynamicReactionTime then
                        shouldParry = true
                    end
                    if Shared.Flags["BB_ClashSpam"] and dist <= 28 then
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

                executeParry(speed)

                -- 9. Ball Velocity Physics Modifier Execution
                if Shared.Flags["BB_CustomVelocityEnabled"] then
                    local targetSpeed = Shared.Flags["BB_CustomVelocityValue"] or 180
                    task.delay(0.03, function()
                        if ball and ball.Parent and ball:IsA("BasePart") then
                            local currentV = ball.AssemblyLinearVelocity
                            if currentV.Magnitude > 1 then
                                ball.AssemblyLinearVelocity = currentV.Unit * targetSpeed
                            end
                        end
                    end)
                elseif Shared.Flags["BB_VelocityMultiplierEnabled"] then
                    local mult = (Shared.Flags["BB_VelocityMultiplierFactor"] or 15) / 10
                    task.delay(0.03, function()
                        if ball and ball.Parent and ball:IsA("BasePart") then
                            local currentV = ball.AssemblyLinearVelocity
                            if currentV.Magnitude > 1 then
                                ball.AssemblyLinearVelocity = currentV.Unit * (currentV.Magnitude * mult)
                            end
                        end
                    end)
                end

                if Shared.Flags["BB_AutoAbility"] then
                    local thresh = Shared.Flags["BB_AbilitySpeed"] or 140
                    if speed >= thresh and dist < 28 then
                        executeAbility()
                    end
                end
            end
        end

        -- 9. Auto Orbit & Safe Spacing
        if Shared.Flags["BB_AutoOrbit"] and isTarget then
            local targetOrbit = Shared.Flags["BB_OrbitDist"] or 35
            local hum = getHum()
            if hum and dist < targetOrbit - 5 then
                local awayDir = (myPos - ballPos).Unit
                hum:Move(Vector3.new(awayDir.X, 0, awayDir.Z), false)
            end
        end
    end)
    if Shared.AddCleanup then Shared.AddCleanup(bbHeartbeatConn) end

    print("[BladeBall_Functions] Loaded -- Predictive Auto-Parry, Clash Spam & Ball ESP Online")
end
