-- NDS_Functions.lua
-- Natural Disaster Survival Ultimate Feature Suite (Aligned with Native Menu Styling)

return function(Shared)
    local Services     = Shared.Services or {}
    local Players      = Services.Players or game:GetService("Players")
    local RunService   = Services.RunService or game:GetService("RunService")
    local UserInput    = Services.UserInput or game:GetService("UserInputService")
    local TweenService = Services.TweenService or game:GetService("TweenService")
    local Workspace    = Services.Workspace or workspace
    local Lighting     = game:GetService("Lighting")

    local Player    = Shared.Player
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider  = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab  = Tabs["Disasters"] or Tabs["NDS"]
    local cols = QuadCols["Disasters"] or QuadCols["NDS"]
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
    local function getHum()   local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

    -- ── DISASTER RADAR BANNER ─────────────────────────────────────
    MkSection(leftCol, "Active Disaster Radar", 1)

    local bannerFrame = Instance.new("Frame")
    bannerFrame.Name                  = "NDS_DisasterBanner"
    bannerFrame.Size                  = UDim2.new(1, 0, 0, 26)
    bannerFrame.BackgroundColor3      = Color3.fromRGB(24, 28, 38)
    bannerFrame.BorderSizePixel       = 1
    bannerFrame.BorderColor3          = Color3.fromRGB(0, 160, 255)
    bannerFrame.LayoutOrder           = 2
    bannerFrame.Parent                = leftCol

    local bannerText = Instance.new("TextLabel")
    bannerText.Size                   = UDim2.new(1, 0, 1, 0)
    bannerText.BackgroundTransparency = 1
    bannerText.Text                   = "⚠ Active: Scanning..."
    bannerText.TextColor3             = Color3.fromRGB(0, 220, 140)
    bannerText.Font                   = Enum.Font.Code
    bannerText.TextSize               = 11
    bannerText.Parent                 = bannerFrame

    local activeDisaster = "Scanning..."
    local function scanDisaster()
        local detected = nil
        local p = Player or Players.LocalPlayer
        local pgui = p and (p:FindFirstChildOfClass("PlayerGui") or p:FindFirstChild("PlayerGui"))
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
            task.wait(2)
            local d = scanDisaster()
            if d ~= activeDisaster then
                activeDisaster = d
                bannerText.Text = "⚠ Active: " .. d
                if d ~= "Intermission / Safe" then
                    bannerText.TextColor3 = Color3.fromRGB(255, 80, 80)
                    Shared.Notify("Disaster Radar", "Alert: " .. d .. " has begun!", false)
                else
                    bannerText.TextColor3 = Color3.fromRGB(0, 220, 140)
                end
            end
        end
    end)

    -- ── LEFT COLUMN: DEFENSE & ANTI-FALL SUITE ────────────────────
    MkSection(leftCol, "Anti-Fall & Hazard Defense", 10)

    -- 1. Smart Anti-Fall (Step Guard)
    local antiFallPad = nil
    local antiFallConn = nil
    MkToggle(leftCol, "Smart Anti-Fall (Step Guard)", "NDS_SmartAntiFall", 11, function(state)
        if state then
            if not antiFallPad or not antiFallPad.Parent then
                antiFallPad = Instance.new("Part")
                antiFallPad.Name = "NDS_AntiFallStep"
                antiFallPad.Size = Vector3.new(14, 1, 14)
                antiFallPad.Anchored = true
                antiFallPad.CanCollide = true
                antiFallPad.Transparency = 0.7
                antiFallPad.BrickColor = BrickColor.new("Bright cyan")
                antiFallPad.Material = Enum.Material.Forcefield
                antiFallPad.Parent = Workspace
            end
            antiFallConn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP()
                local hum = getHum()
                if hrp and hum and antiFallPad and antiFallPad.Parent then
                    if hum.FloorMaterial == Enum.Material.Air and hrp.AssemblyLinearVelocity.Y < -20 then
                        antiFallPad.Position = Vector3.new(hrp.Position.X, hrp.Position.Y - 3.2, hrp.Position.Z)
                        antiFallPad.CanCollide = true
                    else
                        antiFallPad.Position = Vector3.new(0, -500, 0)
                    end
                end
            end)
            Shared.Notify("Anti-Fall", "Step Guard enabled: Spawns floor during falls", true)
        else
            if antiFallConn then antiFallConn:Disconnect(); antiFallConn = nil end
            if antiFallPad then antiFallPad:Destroy(); antiFallPad = nil end
        end
    end)

    -- 2. No Fall Damage
    local noFallConn = nil
    MkToggle(leftCol, "No Fall Damage (Dampener)", "NDS_NoFall", 12, function(state)
        if state then
            noFallConn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp and hrp.AssemblyLinearVelocity.Y < -48 then
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -25, hrp.AssemblyLinearVelocity.Z)
                end
            end)
        else
            if noFallConn then noFallConn:Disconnect(); noFallConn = nil end
        end
    end)

    -- 3. Auto-Rescue (Ocean / Void Catch)
    local autoRescueConn = nil
    MkToggle(leftCol, "Auto-Rescue (Ocean Catch)", "NDS_AutoRescue", 13, function(state)
        if state then
            autoRescueConn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp and hrp.Position.Y < 40 then
                    hrp.CFrame = CFrame.new(-85, 58, 12)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    Shared.Notify("Rescue", "Saved from ocean drowning / void!", true)
                end
            end)
        else
            if autoRescueConn then autoRescueConn:Disconnect(); autoRescueConn = nil end
        end
    end)

    -- 4. Anti-Fling & Tornado Stabilizer
    local antiFlingConn = nil
    MkToggle(leftCol, "Anti-Fling & Wind Stabilizer", "NDS_AntiFling", 14, function(state)
        if state then
            antiFlingConn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp then
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    if hrp.AssemblyLinearVelocity.Magnitude > 120 then
                        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity.Unit * 35
                    end
                end
            end)
            Shared.Notify("Defense", "Anti-Fling active: Immune to wind & explosion fling", true)
        else
            if antiFlingConn then antiFlingConn:Disconnect(); antiFlingConn = nil end
        end
    end)

    -- 5. Acid Rain Forcefield Umbrella
    local acidUmbrella = nil
    local umbrellaConn = nil
    MkToggle(leftCol, "Acid Rain Umbrella Shield", "NDS_AcidShield", 15, function(state)
        if state then
            if not acidUmbrella or not acidUmbrella.Parent then
                acidUmbrella = Instance.new("Part")
                acidUmbrella.Name = "NDS_AcidUmbrella"
                acidUmbrella.Size = Vector3.new(10, 0.5, 10)
                acidUmbrella.Anchored = true
                acidUmbrella.CanCollide = true
                acidUmbrella.Transparency = 0.5
                acidUmbrella.BrickColor = BrickColor.new("Cyan")
                acidUmbrella.Material = Enum.Material.Forcefield
                acidUmbrella.Parent = Workspace
            end
            umbrellaConn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp and acidUmbrella and acidUmbrella.Parent then
                    acidUmbrella.CFrame = hrp.CFrame * CFrame.new(0, 4.4, 0)
                end
            end)
            Shared.Notify("Shield", "Forcefield Umbrella active: Deflects acid rain & debris", true)
        else
            if umbrellaConn then umbrellaConn:Disconnect(); umbrellaConn = nil end
            if acidUmbrella then acidUmbrella:Destroy(); acidUmbrella = nil end
        end
    end)

    -- 6. Green Balloon Glide
    local balloonConn = nil
    MkToggle(leftCol, "Green Balloon Float Physics", "NDS_BalloonGlide", 16, function(state)
        if state then
            balloonConn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP()
                local hum = getHum()
                if hrp and hum and hum.FloorMaterial == Enum.Material.Air and hrp.AssemblyLinearVelocity.Y < -8 then
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X * 1.01, -12, hrp.AssemblyLinearVelocity.Z * 1.01)
                end
            end)
            Shared.Notify("Physics", "Balloon Glide active: Low-gravity floating jumps", true)
        else
            if balloonConn then balloonConn:Disconnect(); balloonConn = nil end
        end
    end)

    -- ── RIGHT COLUMN: SANCTUARY & TELEPORTS ────────────────────────
    MkSection(rightCol, "Sanctuary & Auto-Win", 1)

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

                -- Safety barrier
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
            Shared.Notify("Survival", "Teleported to Sky Sanctuary (Safe from all disasters)", true)
        else
            if godPlat then godPlat:Destroy(); godPlat = nil end
        end
    end

    MkToggle(rightCol, "Sky Sanctuary Platform", "NDS_GodPlat", 2, function(state)
        setGodPlatform(state)
    end)

    local afkFarmConn = nil
    MkToggle(rightCol, "AFK Auto-Win Farm", "NDS_AutoWin", 3, function(state)
        if state then
            setGodPlatform(true)
            afkFarmConn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP()
                if hrp and (hrp.Position - Vector3.new(-85, 188, 12)).Magnitude > 30 then
                    hrp.CFrame = CFrame.new(-85, 188, 12)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end)
            Shared.Notify("Auto-Win", "AFK Farm Active: Stationed at Sky Sanctuary", true)
        else
            if afkFarmConn then afkFarmConn:Disconnect(); afkFarmConn = nil end
        end
    end)

    MkButton(rightCol, "🏝  Teleport to Island Center", 4, function()
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-85, 52, 12)
            Shared.Notify("Teleport", "Teleported to Island Center", true)
        end
    end)

    MkButton(rightCol, "🛡  Teleport to Sky Sanctuary", 5, function()
        local hrp = getHRP()
        if hrp then
            if not godPlat or not godPlat.Parent then setGodPlatform(true) end
            hrp.CFrame = CFrame.new(-85, 188, 12)
            Shared.Notify("Teleport", "Teleported to Sky Sanctuary", true)
        end
    end)

    MkButton(rightCol, "🏰  Teleport to Spawn Tower", 6, function()
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-275, 180, 380)
            Shared.Notify("Teleport", "Teleported to Spawn Tower", true)
        end
    end)

    MkSection(rightCol, "World & Visual Modifiers", 10)

    -- Walk on Ocean / Water
    local waterWalkPart = nil
    MkToggle(rightCol, "Walk on Ocean / Water", "NDS_WaterWalk", 11, function(state)
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
            Shared.Notify("World", "Walk on Ocean enabled", true)
        else
            if waterWalkPart then waterWalkPart:Destroy(); waterWalkPart = nil end
        end
    end)

    -- Clear Storm & Blizzard Fog
    MkToggle(rightCol, "Clear Blizzard & Storm Fog", "NDS_Defog", 12, function(state)
        if state then
            Lighting.FogEnd = 100000
            for _, cc in ipairs(Lighting:GetChildren()) do
                if cc:IsA("ColorCorrectionEffect") or cc:IsA("Atmosphere") or cc:IsA("BlurEffect") then
                    pcall(function() cc.Enabled = false end)
                end
            end
            Shared.Notify("Visual", "Storm fog and atmosphere blur cleared", true)
        else
            Lighting.FogEnd = 1000
        end
    end)

    -- Highlight Falling Threats
    MkToggle(rightCol, "Highlight Falling Threats", "NDS_HighlightThreats", 13, function(state)
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
