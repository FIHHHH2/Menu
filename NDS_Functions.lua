-- NDS_Functions.lua
-- Natural Disaster Survival Feature Suite for Antigravity Menu

return function(Shared)
    local Player      = Shared.Player
    local Services    = Shared.Services
    local TweenSvc    = Services.TweenService
    local RunSvc      = Services.RunService
    local Workspace   = Services.Workspace
    local Http        = Services.Http
    local CoreGui     = Services.CoreGui

    local Tab = Shared.Tabs and Shared.Tabs["NDS"]
    if not Tab then return end

    local leftCol  = Tab:FindFirstChild("LeftColumn")  or Tab
    local rightCol = Tab:FindFirstChild("RightColumn") or Tab

    local MkSection = Shared.MkSection or function(p, t, o) end
    local MkToggle  = Shared.MkToggle  or function(p, t, f, o, cb) end
    local MkButton  = Shared.MkButton  or function(p, t, o, cb) end
    local MkSlider  = Shared.MkSlider  or function(p, t, c, mi, ma, d, o, cb) end

    local function getHRP()
        return Shared.HumanoidRP or (Player.Character and Player.Character:FindFirstChild("HumanoidRootPart"))
    end

    local function getHum()
        return Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    end

    -- ── DISASTER DETECTOR & NOTIFIER ──────────────────────────────
    MkSection(leftCol, "Disaster Radar & Tracker", 1)

    local activeDisaster = "Scanning..."
    local disasterLabel = Instance.new("TextLabel")
    disasterLabel.Name                  = "NDS_DisasterBanner"
    disasterLabel.Size                  = UDim2.new(1, 0, 0, 28)
    disasterLabel.BackgroundColor3      = Color3.fromRGB(24, 28, 38)
    disasterLabel.BorderSizePixel       = 1
    disasterLabel.BorderColor3          = Color3.fromRGB(0, 160, 255)
    disasterLabel.Text                  = "⚠ Active: Scanning..."
    disasterLabel.TextColor3            = Color3.fromRGB(0, 220, 140)
    disasterLabel.Font                  = Enum.Font.GothamBold
    disasterLabel.TextSize              = 11
    disasterLabel.LayoutOrder           = 2
    disasterLabel.Parent                = leftCol

    local function scanDisaster()
        local detected = nil
        -- Check PlayerGui PrintAnnounce
        local pgui = Player:FindFirstChild("PlayerGui")
        if pgui then
            for _, g in ipairs(pgui:GetDescendants()) do
                if g:IsA("TextLabel") and g.Visible and g.Text ~= "" then
                    local t = g.Text:lower()
                    if t:find("meteor") then detected = "Meteor Shower"
                    elseif t:find("acid rain") then detected = "Acid Rain"
                    elseif t:find("tsunami") or t:find("wave") then detected = "Tsunami"
                    elseif t:find("tornado") or t:find("twister") then detected = "Tornado"
                    elseif t:find("earthquake") then detected = "Earthquake"
                    elseif t:find("flash flood") or t:find("flood") then detected = "Flash Flood"
                    elseif t:find("blizzard") or t:find("snow") then detected = "Blizzard"
                    elseif t:find("volcano") or t:find("lava") then detected = "Volcanic Eruption"
                    elseif t:find("sandstorm") then detected = "Sandstorm"
                    elseif t:find("fire") then detected = "Fire"
                    elseif t:find("thunderstorm") or t:find("lightning") then detected = "Thunderstorm"
                    elseif t:find("virus") or t:find("deadly") then detected = "Deadly Virus"
                    end
                end
            end
        end

        -- Check workspace items
        if not detected then
            for _, obj in ipairs(Workspace:GetChildren()) do
                local n = obj.Name:lower()
                if n:find("meteor") then detected = "Meteor Shower"
                elseif n:find("acid") then detected = "Acid Rain"
                elseif n:find("wave") or n:find("tsunami") then detected = "Tsunami"
                elseif n:find("tornado") then detected = "Tornado"
                elseif n:find("volcano") or n:find("lava") then detected = "Volcanic Eruption"
                end
            end
        end

        return detected or "Intermission / Safe"
    end

    task.spawn(function()
        while true do
            task.wait(2.5)
            local d = scanDisaster()
            if d ~= activeDisaster then
                activeDisaster = d
                disasterLabel.Text = "⚠ Active: " .. d
                if d ~= "Intermission / Safe" then
                    disasterLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
                    Shared.Notify("NDS Disaster", "Disaster Alert: " .. d, false)
                else
                    disasterLabel.TextColor3 = Color3.fromRGB(0, 220, 140)
                end
            end
        end
    end)

    -- ── FLOATING SKY SANCTUARY (GOD PLATFORM) ──────────────────────
    MkSection(leftCol, "Survival Automation", 10)

    local godPlat = nil
    local function setGodPlatform(enable)
        if enable then
            if not godPlat or not godPlat.Parent then
                godPlat = Instance.new("Part")
                godPlat.Name = "NDS_SkySanctuary"
                godPlat.Size = Vector3.new(45, 2, 45)
                godPlat.Position = Vector3.new(-85, 185, 12)
                godPlat.Anchored = true
                godPlat.CanCollide = true
                godPlat.Material = Enum.Material.Forcefield
                godPlat.BrickColor = BrickColor.new("Cyan")
                godPlat.Transparency = 0.4
                godPlat.Parent = Workspace

                -- Safety rail
                for _, offset in ipairs({ Vector3.new(0, 3, 22), Vector3.new(0, 3, -22), Vector3.new(22, 3, 0), Vector3.new(-22, 3, 0) }) do
                    local r = Instance.new("Part")
                    r.Size = (offset.X == 0) and Vector3.new(45, 6, 1) or Vector3.new(1, 6, 45)
                    r.Position = godPlat.Position + offset
                    r.Anchored = true
                    r.CanCollide = true
                    r.Transparency = 0.6
                    r.Material = Enum.Material.Forcefield
                    r.BrickColor = BrickColor.new("Cyan")
                    r.Parent = godPlat
                end
            end
            local hrp = getHRP()
            if hrp then hrp.CFrame = CFrame.new(-85, 188, 12) end
            Shared.Notify("NDS Survival", "Teleported to Sky Sanctuary (Safe from all disasters)", true)
        else
            if godPlat then godPlat:Destroy(); godPlat = nil end
        end
    end

    MkToggle(leftCol, "Sky Sanctuary Platform", "NDS_GodPlat", 11, function(state)
        setGodPlatform(state)
    end)

    -- NO FALL DAMAGE
    local noFallConn = nil
    MkToggle(leftCol, "No Fall Damage", "NDS_NoFall", 12, function(state)
        if state then
            noFallConn = RunSvc.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp and hrp.AssemblyLinearVelocity.Y < -55 then
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -30, hrp.AssemblyLinearVelocity.Z)
                end
            end)
        else
            if noFallConn then noFallConn:Disconnect(); noFallConn = nil end
        end
    end)

    -- AUTO RESCUE (FALL CATCH)
    local autoRescueConn = nil
    MkToggle(leftCol, "Auto-Rescue (Fall Catch)", "NDS_AutoRescue", 13, function(state)
        if state then
            autoRescueConn = RunSvc.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp and hrp.Position.Y < 38 then
                    hrp.CFrame = CFrame.new(-85, 60, 12)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    Shared.Notify("NDS Rescue", "Saved from void / drowning!", true)
                end
            end)
        else
            if autoRescueConn then autoRescueConn:Disconnect(); autoRescueConn = nil end
        end
    end)

    -- WALK ON WATER / ACID
    local waterWalkPart = nil
    MkToggle(leftCol, "Walk on Water / Ocean", "NDS_WaterWalk", 14, function(state)
        if state then
            if not waterWalkPart or not waterWalkPart.Parent then
                waterWalkPart = Instance.new("Part")
                waterWalkPart.Name = "NDS_WaterPlatform"
                waterWalkPart.Size = Vector3.new(900, 1, 900)
                waterWalkPart.Position = Vector3.new(-85, 46, 12)
                waterWalkPart.Anchored = true
                waterWalkPart.CanCollide = true
                waterWalkPart.Transparency = 0.85
                waterWalkPart.BrickColor = BrickColor.new("Cyan")
                waterWalkPart.Parent = Workspace
            end
        else
            if waterWalkPart then waterWalkPart:Destroy(); waterWalkPart = nil end
        end
    end)

    -- ── RIGHT COLUMN: TELEPORTS & WORLD MODS ───────────────────────
    MkSection(rightCol, "Instant Teleports", 1)

    MkButton(rightCol, "[ 🏝 Teleport to Island ]", 2, function()
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-85, 52, 12)
            Shared.Notify("NDS TP", "Teleported to Island Center", true)
        end
    end)

    MkButton(rightCol, "[ 🛡 Teleport to Sky Safe Spot ]", 3, function()
        local hrp = getHRP()
        if hrp then
            if not godPlat or not godPlat.Parent then setGodPlatform(true) end
            hrp.CFrame = CFrame.new(-85, 188, 12)
            Shared.Notify("NDS TP", "Teleported to Sky Sanctuary", true)
        end
    end)

    MkButton(rightCol, "[ 🏰 Teleport to Spawn Tower ]", 4, function()
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-275, 180, 380)
            Shared.Notify("NDS TP", "Teleported to Spawn Tower", true)
        end
    end)

    MkSection(rightCol, "Visual & Threat Modifiers", 10)

    -- STORM & BLIZZARD DEFOGGER
    MkToggle(rightCol, "Clear Blizzard / Sandstorm Fog", "NDS_Defog", 11, function(state)
        local lighting = Services.Workspace.Parent:GetService("Lighting")
        if state then
            lighting.FogEnd = 100000
            for _, cc in ipairs(lighting:GetChildren()) do
                if cc:IsA("ColorCorrectionEffect") or cc:IsA("Atmosphere") or cc:IsA("BlurEffect") then
                    pcall(function() cc.Enabled = false end)
                end
            end
        else
            lighting.FogEnd = 1000
        end
    end)

    -- DISASTER HIGHLIGHT CHAMS
    local disasterHL = nil
    MkToggle(rightCol, "Highlight Falling Disasters", "NDS_HighlightThreats", 12, function(state)
        if state then
            task.spawn(function()
                while Shared.Flags["NDS_HighlightThreats"] do
                    for _, obj in ipairs(Workspace:GetChildren()) do
                        local n = obj.Name:lower()
                        if (n:find("meteor") or n:find("lava") or n:find("rock") or n:find("debris")) and obj:IsA("BasePart") then
                            if not obj:FindFirstChild("ThreatHL") then
                                local hl = Instance.new("Highlight")
                                hl.Name = "ThreatHL"
                                hl.FillColor = Color3.fromRGB(255, 30, 30)
                                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                                hl.FillTransparency = 0.3
                                hl.Adornee = obj
                                hl.Parent = obj
                            end
                        end
                    end
                    task.wait(1.5)
                end
            end)
        else
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "ThreatHL" then obj:Destroy() end
            end
        end
    end)
end
