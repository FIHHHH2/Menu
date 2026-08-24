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
    local parryRemote = nil
    local abilityRemote = nil

    local function findParryRemotes()
        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
            parryRemote = remotes:FindFirstChild("ParryButtonPress")
                       or remotes:FindFirstChild("CustomParry")
                       or remotes:FindFirstChild("ParryAttempt")
                       or remotes:FindFirstChild("Parry")
                       or (remotes:FindFirstChild("PlrParry") and remotes.PlrParry)

            abilityRemote = remotes:FindFirstChild("UseAbility")
                         or remotes:FindFirstChild("AbilityButtonPress")
                         or remotes:FindFirstChild("Ability")
        end)
    end
    findParryRemotes()

    -- ── BALL TRACKING ENGINE ──────────────────────────────────────
    local activeBall = nil
    local lastParryTime = 0

    local function getBallsFolder()
        return Workspace:FindFirstChild("Balls") or Workspace:FindFirstChild("Ball") or Workspace
    end

    local function findActiveBall()
        local folder = getBallsFolder()
        if folder ~= Workspace then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("BasePart") or obj:FindFirstChildOfClass("BasePart") or obj:GetAttribute("realBall") then
                    return obj:IsA("BasePart") and obj or obj:FindFirstChildOfClass("BasePart")
                end
            end
        end
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj.Name == "Ball" or obj.Name:find("Ball") or obj:GetAttribute("target") then
                if obj:IsA("BasePart") then return obj end
                local p = obj:FindFirstChildOfClass("BasePart")
                if p then return p end
            end
        end
        return nil
    end

    local function isTargetingMe(ball)
        if not ball then return false end
        local targetAttr = ball:GetAttribute("target") or ball:GetAttribute("Target")
        if targetAttr then
            return tostring(targetAttr) == Player.Name or tostring(targetAttr) == tostring(Player.UserId)
        end

        local targetVal = ball:FindFirstChild("target") or ball:FindFirstChild("Target")
        if targetVal and targetVal:IsA("ValueBase") then
            return tostring(targetVal.Value) == Player.Name or targetVal.Value == Player.Character
        end

        local hrp = getHRP()
        if hrp and ball.AssemblyLinearVelocity then
            local toMe = (hrp.Position - ball.Position)
            local dist = toMe.Magnitude
            if dist < 60 and toMe.Unit:Dot(ball.AssemblyLinearVelocity.Unit) > 0.85 then
                return true
            end
        end
        return false
    end

    -- ── PARRY EXECUTION MECHANISMS ────────────────────────────────
    local function executeParry()
        local now = os.clock()
        if now - lastParryTime < 0.02 then return end
        lastParryTime = now

        -- Method 1: Remote Trigger
        if parryRemote then
            pcall(function()
                if parryRemote:IsA("RemoteEvent") then
                    parryRemote:FireServer(0.5, CFrame.new(), {}, Vector2.new())
                elseif parryRemote:IsA("RemoteFunction") then
                    parryRemote:InvokeServer(0.5, CFrame.new(), {}, Vector2.new())
                end
            end)
        end

        -- Method 2: Virtual Input Simulation (KeyCode.F & Mouse1)
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

        -- Method 3: Mouse click executor fallback
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
        local myChar = getChar()

        if not ball or not hrp then
            statusText.Text = "⚡ Ball: Waiting for round..."
            statusText.TextColor3 = Color3.fromRGB(140, 160, 190)
            statusFrame.BorderColor3 = Color3.fromRGB(0, 160, 255)
            clearBallVisuals()
            return
        end

        local ballPos = ball.Position
        local myPos   = hrp.Position
        local dist    = (ballPos - myPos).Magnitude
        local vel     = ball.AssemblyLinearVelocity or Vector3.zero
        local speed   = vel.Magnitude

        -- Trajectory calculation: dot product towards local player
        local dirToMe = (myPos - ballPos).Unit
        local approachSpeed = (speed > 1) and vel:Dot(dirToMe) or speed
        local isTarget = isTargetingMe(ball)

        -- Dynamic ping offset calculation (seconds)
        local pingMs = Shared.Flags["BB_PingOffset"] or 45
        local pingOffsetSec = pingMs / 1000

        -- Time to Impact (seconds)
        local timeToImpact = (approachSpeed > 1) and (dist / approachSpeed) or 999

        -- Configured threshold
        local customDist = Shared.Flags["BB_ParryDist"] or 28
        local dynamicParryDistance = customDist + math.clamp(speed * (pingOffsetSec + 0.05), 0, 45)

        -- Update Status Banner
        if isTarget then
            statusText.Text = string.format("🔴 INCOMING! Dist: %dm | Spd: %d | Time: %.2fs", math.floor(dist), math.floor(speed), math.max(0, timeToImpact))
            statusText.TextColor3 = Color3.fromRGB(255, 60, 60)
            statusFrame.BorderColor3 = Color3.fromRGB(255, 60, 60)
        else
            statusText.Text = string.format("🟢 Safe | Dist: %dm | Speed: %d", math.floor(dist), math.floor(speed))
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

        -- 2. AUTO PARRY ENGINE (Predictive + Clash Logic)
        if Shared.Flags["BB_AutoParry"] then
            local shouldParry = false

            if isTarget then
                if dist <= dynamicParryDistance or timeToImpact <= (0.12 + pingOffsetSec) then
                    shouldParry = true
                end
            end

            -- Clash Standoff Mode: If very close (< 14 studs) and high speed or spam active
            if Shared.Flags["BB_ClashSpam"] and dist <= 14 then
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
                    if speed >= thresh and dist < 22 then
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
