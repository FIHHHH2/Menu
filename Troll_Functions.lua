-- Troll_Functions.lua
-- Trolling suite: Fling All, Spinbot, Attach/Piggyback, Teleport Loop, Fake Lag, Invisibility

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

    local function getChar()  return Shared.Character or (Player and Player.Character) end
    local function getHRP()   return Shared.HumanoidRP or (getChar() and getChar():FindFirstChild("HumanoidRootPart")) end
    local function getHuman() return getChar() and getChar():FindFirstChildOfClass("Humanoid") end

    -- LEFT COLUMN: FLINGS & PHYSICS TROLLS
    MkSection(leftCol, "Physics & Flings", 1)

    -- Fling All
    local flingLoop = false
    MkToggle(leftCol, "Fling All Players", "FlingAll", 2, function(state)
        flingLoop = state
        if state then
            task.spawn(function()
                local hrp = getHRP()
                local bAV = Instance.new("BodyAngularVelocity")
                bAV.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bAV.AngularVelocity = Vector3.new(0, 99999, 0)
                bAV.Parent = hrp

                while flingLoop and Shared.Flags["FlingAll"] do
                    for _, target in ipairs(Players:GetPlayers()) do
                        if not flingLoop then break end
                        if target ~= Player and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                            local tHRP = target.Character.HumanoidRootPart
                            local orig = hrp.CFrame
                            for _ = 1, 10 do
                                if not flingLoop then break end
                                hrp.CFrame = tHRP.CFrame * CFrame.new(0, 0.5, 0)
                                hrp.Velocity = Vector3.new(9999, 9999, 9999)
                                task.wait(0.03)
                            end
                        end
                    end
                    task.wait(0.1)
                end

                if bAV then bAV:Destroy() end
            end)
        end
    end)

    -- Spinbot
    local spinBAV
    MkToggle(leftCol, "Spinbot", "Spinbot", 3, function(state)
        local hrp = getHRP()
        if not hrp then return end
        if state then
            spinBAV = Instance.new("BodyAngularVelocity")
            spinBAV.MaxTorque = Vector3.new(0, math.huge, 0)
            spinBAV.AngularVelocity = Vector3.new(0, Shared.Flags["SpinSpeed"] or 50, 0)
            spinBAV.Parent = hrp
        else
            if spinBAV then spinBAV:Destroy(); spinBAV = nil end
        end
    end)

    MkSlider(leftCol, "Spin Speed", "SpinSpeed", 10, 150, 50, 4, function(val)
        Shared.Flags["SpinSpeed"] = val
        if spinBAV then spinBAV.AngularVelocity = Vector3.new(0, val, 0) end
    end)

    -- Fake Lag / Desync
    local fakeLagConn
    MkToggle(leftCol, "Fake Lag (Desync Spoof)", "FakeLag", 5, function(state)
        if fakeLagConn then fakeLagConn:Disconnect(); fakeLagConn = nil end
        if state then
            fakeLagConn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp then
                    hrp.CFrame = hrp.CFrame * CFrame.new(math.random(-1, 1) * 0.1, 0, math.random(-1, 1) * 0.1)
                end
            end)
        end
    end)

    -- RIGHT COLUMN: STEALTH & STALKER TROLLS
    MkSection(rightCol, "Stalker & Stealth", 1)

    -- Invisibility
    MkToggle(rightCol, "Client Ghost / Invisible", "ClientGhost", 2, function(state)
        local char = getChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.Transparency = state and 0.85 or 0
            end
        end
    end)

    -- Stalker Loop Teleport
    local stalkerLoop = false
    local stalkTarget = nil
    MkToggle(rightCol, "Stalk / Piggyback Closest", "StalkerMode", 3, function(state)
        stalkerLoop = state
        if state then
            task.spawn(function()
                while stalkerLoop and Shared.Flags["StalkerMode"] do
                    local myHRP = getHRP()
                    local closest = nil
                    local minDist = math.huge
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                            local d = (plr.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                            if d < minDist then minDist = d; closest = plr end
                        end
                    end
                    if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then
                        myHRP.CFrame = closest.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3.2, 1)
                    end
                    task.wait(0.05)
                end
            end)
        end
    end)

    -- Evade Murderer
    local evadeConn
    MkToggle(rightCol, "Auto Evade Murderer", "AutoEvade", 4, function(state)
        if evadeConn then evadeConn:Disconnect(); evadeConn = nil end
        if state then
            evadeConn = RunService.Heartbeat:Connect(function()
                local myHRP = getHRP()
                if not myHRP then return end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= Player and plr.Character then
                        local hasKnife = plr.Character:FindFirstChild("Knife") or (plr.Backpack and plr.Backpack:FindFirstChild("Knife"))
                        if hasKnife and plr.Character:FindFirstChild("HumanoidRootPart") then
                            local dist = (plr.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                            if dist < 25 then
                                local awayDir = (myHRP.Position - plr.Character.HumanoidRootPart.Position).Unit
                                myHRP.CFrame = myHRP.CFrame + (awayDir * 8)
                            end
                        end
                    end
                end
            end)
        end
    end)

    print("[Troll_Functions] Loaded -- Trolling & Fling suite online")
end
