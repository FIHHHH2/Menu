-- Main_Functions.lua
-- General Movement, Teleports, and Utility
-- Infinite Jump, WASD Flight, Noclip, Speed/Jump Height, Click TP, Volume

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
        warn("[Main_Functions] Tab 'Main' not found")
        return
    end

    local function getChar()  return Shared.Character or (Player and Player.Character) end
    local function getHRP()   return Shared.HumanoidRP or (getChar() and getChar():FindFirstChild("HumanoidRootPart")) end
    local function getHuman() return getChar() and getChar():FindFirstChildOfClass("Humanoid") end

    -- ============================================================
    -- MOVEMENT
    -- ============================================================
    MkSection(tab, "Player Movement", 1)

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
    local FLIGHT_SPEED = 65
    MkToggle(tab, "Flight (WASD + Space / Ctrl)", "Flight", 3, function(state)
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

    -- ============================================================
    -- STATS & SPEED
    -- ============================================================
    MkSection(tab, "Stat Multipliers", 10)

    MkSlider(tab, "Walk Speed", "WalkSpeed", 16, 250, 16, 11, function(val)
        local hum = getHuman()
        if hum then hum.WalkSpeed = val end
    end)

    MkSlider(tab, "Jump Height", "JumpHeight", 7, 250, 7, 12, function(val)
        local hum = getHuman()
        if hum then hum.JumpHeight = val end
    end)

    Player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        task.wait(0.1)
        hum.WalkSpeed  = Shared.Flags["WalkSpeed"]  or 16
        hum.JumpHeight = Shared.Flags["JumpHeight"] or 7
    end)

    -- ============================================================
    -- TELEPORT
    -- ============================================================
    MkSection(tab, "Teleportation", 20)

    local clickTPConn
    MkToggle(tab, "Click TP (Mouse Click)", "ClickTP", 21, function(state)
        if clickTPConn then clickTPConn:Disconnect(); clickTPConn = nil end
        if state then
            clickTPConn = UserInput.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local hrp = getHRP()
                    if not hrp then return end
                    local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = { getChar() }
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
                    if result then
                        hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
                    end
                end
            end)
        end
    end)

    print("[Main_Functions] Loaded -- General movement & utility online")
end
