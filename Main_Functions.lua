-- Main_Functions.lua
-- Infinite Jump, Flight, Noclip, Speed, ClickTP, Volume, NoVFX, ForceClose

return function(Shared)
    local Players    = Shared.Services.Players
    local RunService = Shared.Services.RunService
    local UserInput  = Shared.Services.UserInput
    local TweenSvc   = Shared.Services.TweenService
    local SoundSvc   = Shared.Services.SoundService

    local Player     = Shared.Player
    local Tabs       = Shared.Tabs or {}
    local MkSection  = Shared.MakeSection or function() end
    local MkToggle   = Shared.MakeToggle  or function() return Instance.new("Frame"), function() end end
    local MkSlider   = Shared.MakeSlider  or function() return Instance.new("Frame") end
    local MkButton   = Shared.MakeButton  or function() return Instance.new("TextButton") end

    local tab = Tabs["Main"]
    if not tab then
        warn("[Main_Functions] Tab 'Main' not found -- UI_Handler may have failed to load")
        return
    end

    local function getChar()    return Shared.Character end
    local function getHRP()     return Shared.HumanoidRP end
    local function getHuman()
        local c = getChar()
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    -- MOVEMENT
    MkSection(tab, "Movement", 1)

    -- Infinite Jump
    local infJumpConn
    MkToggle(tab, "Infinite Jump", "InfiniteJump", 2, function(state)
        if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
        if state then
            infJumpConn = UserInput.JumpRequest:Connect(function()
                local hum = getHuman()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        end
    end)

    -- Flight
    local flightBV, flightConn
    local FLIGHT_SPEED = 60
    MkToggle(tab, "Flight", "Flight", 3, function(state)
        local hrp = getHRP()
        if not hrp then return end
        if state then
            hrp.Velocity = Vector3.zero
            flightBV = Instance.new("BodyVelocity")
            flightBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flightBV.Velocity = Vector3.zero
            flightBV.Parent   = hrp

            local cam = workspace.CurrentCamera
            flightConn = RunService.Heartbeat:Connect(function()
                if not Shared.Flags["Flight"] then return end
                local dir = Vector3.zero
                if UserInput:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInput:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInput:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInput:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInput:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
                if UserInput:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
                flightBV.Velocity = dir.Magnitude > 0 and (dir.Unit * FLIGHT_SPEED) or Vector3.zero
            end)
        else
            if flightConn then flightConn:Disconnect(); flightConn = nil end
            if flightBV then flightBV:Destroy(); flightBV = nil end
        end
    end)

    -- Noclip
    local noclipConn
    MkToggle(tab, "Noclip", "Noclip", 4, function(state)
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        if state then
            noclipConn = RunService.Stepped:Connect(function()
                local char = getChar()
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end)
        else
            local char = getChar()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
    end)

    -- STATS
    MkSection(tab, "Stats", 10)

    MkSlider(tab, "Walk Speed", "WalkSpeed", 1, 300, 16, 11, function(val)
        local hum = getHuman()
        if hum then hum.WalkSpeed = val end
    end)

    MkSlider(tab, "Jump Height", "JumpHeight", 0, 300, 7, 12, function(val)
        local hum = getHuman()
        if hum then hum.JumpHeight = val end
    end)

    Player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        task.wait(0.1)
        hum.WalkSpeed  = Shared.Flags["WalkSpeed"]  or 16
        hum.JumpHeight = Shared.Flags["JumpHeight"] or 7
    end)

    -- TELEPORT
    MkSection(tab, "Teleport", 20)

    local clickTPConn
    MkToggle(tab, "Click TP", "ClickTP", 21, function(state)
        if clickTPConn then clickTPConn:Disconnect(); clickTPConn = nil end
        if state then
            clickTPConn = UserInput.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local hrp = getHRP()
                    if not hrp then return end
                    local ray    = workspace.CurrentCamera:ScreenPointToRay(
                        input.Position.X, input.Position.Y
                    )
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = { Shared.Character }
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
                    if result then
                        hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
                    end
                end
            end)
        end
    end)

    -- AUDIO & VISUALS
    MkSection(tab, "Audio & Visuals", 30)

    MkSlider(tab, "Game Volume", "GameVolume", 0, 100, 50, 31, function(val)
        for _, s in ipairs(workspace:GetDescendants()) do
            if s:IsA("Sound") then s.Volume = val / 100 end
        end
    end)

    MkToggle(tab, "No VFX (FPS Boost)", "NoVFX", 32, function(state)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail")
            or obj:IsA("Beam") or obj:IsA("Smoke")
            or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = not state
            end
        end
        workspace.Terrain.Decoration = not state
    end)

    MkToggle(tab, "No Textures", "NoTextures", 33, function(state)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = state and 1 or 0
            end
        end
    end)

    -- UTILITY
    MkSection(tab, "Utility", 40)

    MkButton(tab, "Force Close Menu", 41, function()
        if Shared.GUI then
            Shared.GUI:Destroy()
        end
        for k in pairs(Shared.Flags) do
            Shared.Flags[k] = false
        end
        print("[Menu] Force closed.")
    end)

    print("[Main_Functions] Loaded")
end
