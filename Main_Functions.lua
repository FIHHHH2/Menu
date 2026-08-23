-- Main_Functions.lua
-- Movement, Stat Multipliers, World Modifiers, and Performance & FPS Boost Suite

return function(Shared)
    local Players      = Shared.Services.Players
    local RunService   = Shared.Services.RunService
    local UserInput    = Shared.Services.UserInput
    local TweenService = Shared.Services.TweenService
    local Lighting     = game:GetService("Lighting")

    local Player    = Shared.Player
    local Tabs      = Shared.Tabs or {}
    local QuadCols  = Shared.QuadCols or {}
    local MkSection = Shared.MakeSection or function() end
    local MkToggle  = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider  = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton  = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab  = Tabs["Main"]
    local cols = QuadCols["Main"]
    if not tab or not cols then return end

    local leftCol  = cols.Left
    local rightCol = cols.Right

    local function getChar()  return Shared.Character or Player.Character end
    local function getHRP()   return Shared.HumanoidRP or (getChar() and getChar():FindFirstChild("HumanoidRootPart")) end
    local function getHuman() return getChar() and getChar():FindFirstChildOfClass("Humanoid") end

    local function restoreDefaultCollisions(char)
        if Shared.Flags["FragilePlayer"] then setupFragileCharacter(char) end
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "HumanoidRootPart" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" or part.Name == "Head" then
                    part.CanCollide = true
                else
                    -- Limbs (arms, legs, hands, feet) and accessory handles MUST be CanCollide = false
                    part.CanCollide = false
                end
            end
        end
    end

    -- ── LEFT COLUMN: MOVEMENT & PHYSICS ──────────────────────────
    MkSection(leftCol, "Movement & Physics", 1)

    local infJumpConn
    MkToggle(leftCol, "Infinite Jump", "InfiniteJump", 2, function(state)
        if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
        if state then
            infJumpConn = UserInput.JumpRequest:Connect(function()
                local hum = getHuman(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        end
    end)

    local flightBV, flightConn
    MkToggle(leftCol, "Flight", "Flight", 3, function(state)
        local hrp = getHRP(); if not hrp then return end
        if state then
            hrp.Velocity = Vector3.zero
            flightBV = Instance.new("BodyVelocity")
            flightBV.MaxForce = Vector3.new(1e5,1e5,1e5); flightBV.Velocity = Vector3.zero; flightBV.Parent = hrp
            local cam = workspace.CurrentCamera
            flightConn = RunService.Heartbeat:Connect(function()
                if not Shared.Flags["Flight"] then return end
                local speed = Shared.Flags["FlightSpeed"] or 65; local dir = Vector3.zero
                if UserInput:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInput:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInput:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInput:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInput:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                if UserInput:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
                flightBV.Velocity = dir.Magnitude > 0 and (dir.Unit * speed) or Vector3.zero
            end)
        else
            if flightConn then flightConn:Disconnect(); flightConn = nil end
            if flightBV   then flightBV:Destroy();     flightBV   = nil end
        end
    end)

    MkSlider(leftCol, "Flight Speed", "FlightSpeed", 20, 300, 65, 4, function(val) Shared.Flags["FlightSpeed"] = val end)

    local noclipConn
    MkToggle(leftCol, "Noclip", "Noclip", 5, function(state)
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        if state then
            noclipConn = RunService.Stepped:Connect(function()
                local char = getChar(); if not char then return end
                for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
            end)
        else
            local char = getChar()
            if char then restoreDefaultCollisions(char)
        if Shared.Flags["FragilePlayer"] then setupFragileCharacter(char) end end
        end
    end)

    local clickTPConn
    MkToggle(leftCol, "Click TP (Mouse Click)", "ClickTP", 6, function(state)
        if clickTPConn then clickTPConn:Disconnect(); clickTPConn = nil end
        if state then
            clickTPConn = UserInput.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local hrp = getHRP(); if not hrp then return end
                    local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = {getChar()}; params.FilterType = Enum.RaycastFilterType.Exclude
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
                    if result then hrp.CFrame = CFrame.new(result.Position + Vector3.new(0,3,0)) end
                end
            end)
        end
    end)

    MkToggle(leftCol, "Anti-Ragdoll", "AntiRagdoll", 7, function(state)
        local char = getChar(); if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BallSocketConstraint") or obj:IsA("HingeConstraint") then
                obj.Enabled = not state
            end
        end
    end)

    -- ── Fragile Player (Glass Character / Shatter on Impact) ──────
    local fragileConns = {}
    local fragileCooldown = false

    local function setupFragileCharacter(char)
        for _, conn in ipairs(fragileConns) do pcall(function() conn:Disconnect() end) end
        fragileConns = {}

        if not char then return end
        local hum = char:WaitForChild("Humanoid", 3)
        local hrp = char:WaitForChild("HumanoidRootPart", 3)
        if not hum or not hrp then return end

        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                local conn = part.Touched:Connect(function(hit)
                    if not Shared.Flags["FragilePlayer"] or fragileCooldown then return end
                    if not hit or not hit.Parent or hit:IsDescendantOf(char) then return end

                    -- Check if touched by another player or moving object/floor with momentum
                    local hitHum = hit.Parent:FindFirstChildOfClass("Humanoid") or (hit.Parent.Parent and hit.Parent.Parent:FindFirstChildOfClass("Humanoid"))
                    local isFast = hrp.AssemblyLinearVelocity.Magnitude > 12 or hit.AssemblyLinearVelocity.Magnitude > 8

                    if hitHum or isFast then
                        fragileCooldown = true
                        local force = Shared.Flags["FragileForce"] or 85
                        local hitDir = (hrp.Position - hit.Position).Magnitude > 0.1 and (hrp.Position - hit.Position).Unit or Vector3.new(0, 1, 0)

                        -- Ragdoll collapse
                        hum.PlatformStand = true
                        hum:ChangeState(Enum.HumanoidStateType.FallingDown)
                        hrp.AssemblyLinearVelocity = hitDir * force + Vector3.new(0, force * 0.6, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))

                        -- Auto recover after short comedic delay
                        task.delay(1.6, function()
                            if hum and hum.Parent then
                                hum.PlatformStand = false
                                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                            end
                            task.wait(0.3)
                            fragileCooldown = false
                        end)
                    end
                end)
                table.insert(fragileConns, conn)
            end
        end
    end

    MkToggle(leftCol, "Fragile Player (Glass Mode)", "FragilePlayer", 8, function(state)
        if state then
            setupFragileCharacter(getChar())
            Shared.Notify("Fragile Player", "Glass Physics Enabled -- Ragdoll on Contact", true)
        else
            for _, conn in ipairs(fragileConns) do pcall(function() conn:Disconnect() end) end
            fragileConns = {}
            local hum = getHuman()
            if hum then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            Shared.Notify("Fragile Player", "Glass Mode Disabled", false)
        end
    end)

    MkSlider(leftCol, "Fragile Knockback Force", "FragileForce", 20, 250, 85, 9, function(val)
        Shared.Flags["FragileForce"] = val
    end)

    MkButton(leftCol, "[ Force Respawn ]", 10, function()
        Player:LoadCharacter()
    end)

    -- ── LEFT COLUMN: PERFORMANCE & FPS BOOST SUITE ──────────────
    MkSection(leftCol, "Performance & FPS Boost", 20)

    -- 1. Low Graphics / FPS Booster
    local originalMaterials = {}
    MkToggle(leftCol, "FPS Boost (Low Graphics)", "FPSBoost", 21, function(state)
        if state then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            pcall(function()
                workspace.Terrain.WaterWaveSize = 0
                workspace.Terrain.WaterWaveSpeed = 0
                workspace.Terrain.WaterReflectance = 0
                workspace.Terrain.WaterTransparency = 0
            end)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if not originalMaterials[obj] then originalMaterials[obj] = { mat = obj.Material, shadow = obj.CastShadow } end
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.CastShadow = false
                end
            end
            Shared.Notify("Performance", "Low Graphics Mode Enabled", true)
        else
            Lighting.GlobalShadows = true
            for obj, info in pairs(originalMaterials) do
                if obj and obj.Parent then
                    pcall(function()
                        obj.Material = info.mat
                        obj.CastShadow = info.shadow
                    end)
                end
            end
            originalMaterials = {}
            Shared.Notify("Performance", "Low Graphics Mode Disabled", false)
        end
    end)

    -- 2. Disable Particles, Trails & Beams
    local disabledEmitters = {}
    MkToggle(leftCol, "Disable Particles & Trails", "NoParticles", 22, function(state)
        if state then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    if obj.Enabled then
                        disabledEmitters[obj] = true
                        obj.Enabled = false
                    end
                end
            end
        else
            for obj in pairs(disabledEmitters) do
                if obj and obj.Parent then pcall(function() obj.Enabled = true end) end
            end
            disabledEmitters = {}
        end
    end)

    -- 3. Disable Post-Processing
    local disabledEffects = {}
    MkToggle(leftCol, "Disable Post-Processing (Bloom/Blur)", "NoPostProcessing", 23, function(state)
        if state then
            for _, obj in ipairs(Lighting:GetChildren()) do
                if obj:IsA("PostProcessEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
                    if obj.Enabled then
                        disabledEffects[obj] = true
                        obj.Enabled = false
                    end
                end
            end
        else
            for obj in pairs(disabledEffects) do
                if obj and obj.Parent then pcall(function() obj.Enabled = true end) end
            end
            disabledEffects = {}
        end
    end)

    -- 4. Disable 3D Textures & Decals
    local disabledTextures = {}
    MkToggle(leftCol, "Disable 3D Textures & Decals", "NoTextures", 24, function(state)
        if state then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    if obj.Transparency < 1 then
                        disabledTextures[obj] = obj.Transparency
                        obj.Transparency = 1
                    end
                end
            end
        else
            for obj, orig in pairs(disabledTextures) do
                if obj and obj.Parent then pcall(function() obj.Transparency = orig end) end
            end
            disabledTextures = {}
        end
    end)

    -- 5. Unlock / Custom FPS Cap
    local setfpscap = setfpscap or (getgenv and getgenv().setfpscap)
    if setfpscap then
        MkSlider(leftCol, "FPS Cap (Max FPS)", "FPSCap", 30, 360, 144, 25, function(val)
            pcall(function() setfpscap(val) end)
        end)
    end

    -- ── RIGHT COLUMN: STAT MULTIPLIERS & WORLD ───────────────────
    MkSection(rightCol, "Stat Multipliers", 10)

    MkSlider(rightCol, "Walk Speed", "WalkSpeed", 16, 250, 16, 11, function(val)
        local hum = getHuman(); if hum then hum.WalkSpeed = val end
    end)
    MkSlider(rightCol, "Jump Height", "JumpHeight", 7, 250, 7, 12, function(val)
        local hum = getHuman(); if hum then hum.JumpHeight = val end
    end)

    Player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid"); task.wait(0.1)
        hum.WalkSpeed  = Shared.Flags["WalkSpeed"]  or 16
        hum.JumpHeight = Shared.Flags["JumpHeight"] or 7
        restoreDefaultCollisions(char)
        if Shared.Flags["FragilePlayer"] then setupFragileCharacter(char) end
    end)

    MkSection(rightCol, "World Modifiers", 20)

    MkSlider(rightCol, "Gravity", "Gravity", 10, 200, 196, 21, function(val)
        workspace.Gravity = val
    end)

    MkSlider(rightCol, "Reach Extender", "Reach", 2, 40, 2, 22, function(val)
        local hrp = getHRP()
        if hrp then
            if val <= 2 then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.CanCollide = true
            else
                hrp.Size = Vector3.new(val, 2, val)
                -- Keep enlarged root part non-collidable so player can fit through tight spaces and doors
                hrp.CanCollide = false
            end
        end
    end)

    local antiAimConn
    MkToggle(rightCol, "Anti-Aim (Spin HRP)", "AntiAim", 23, function(state)
        if antiAimConn then antiAimConn:Disconnect(); antiAimConn = nil end
        if state then
            local t = 0
            antiAimConn = RunService.RenderStepped:Connect(function(dt)
                t = t + dt * 10
                local hrp = getHRP(); if not hrp then return end
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(t*15), 0)
            end)
        end
    end)

    MkSection(rightCol, "Camera & View", 30)

    MkSlider(rightCol, "FOV", "FOV", 70, 120, 70, 31, function(val)
        if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = val end
    end)

    MkToggle(rightCol, "Full Bright", "FullBright", 32, function(state)
        if state then
            Lighting.Brightness = 2; Lighting.ClockTime = 14
            Lighting.FogEnd = 1e6; Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 1; Lighting.ClockTime = 14
            Lighting.FogEnd = 1e6; Lighting.GlobalShadows = true
        end
    end)

    print("[Main_Functions] Loaded -- Performance Suite & Stat Multipliers Active")
end
