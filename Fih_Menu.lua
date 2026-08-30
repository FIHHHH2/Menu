--!strict
--[[
    FISH MENU (FIHMENU) — Modular Cubed-Style Universal GUI Architecture
    Engine: Luau / Roblox Client Environment
    Repository: FIHHHH2/Menu
    Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/FIHHHH2/Menu/main/Fih_Menu.lua?t=" .. tick()))()
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Mouse = LocalPlayer:GetMouse()

-- Safe GUI container resolution
local TargetParent: Instance = CoreGui
pcall(function()
    local test = Instance.new("Folder")
    test.Parent = CoreGui
    test:Destroy()
end)
if TargetParent ~= CoreGui or not pcall(function() return CoreGui.Name end) then
    TargetParent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Clean previous instance
if TargetParent:FindFirstChild("FishMenu_Host") then
    TargetParent.FishMenu_Host:Destroy()
end

local ScreenHost = Instance.new("ScreenGui")
ScreenHost.Name = "FishMenu_Host"
ScreenHost.ResetOnSpawn = false
ScreenHost.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenHost.DisplayOrder = 100
ScreenHost.Parent = TargetParent

--------------------------------------------------------------------------------
-- 1. FAST SIGNAL IMPLEMENTATION
--------------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ _bindable = Instance.new("BindableEvent") }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
    return self._bindable.Event:Connect(fn)
end

function Signal:Fire(...)
    self._bindable:Fire(...)
end

function Signal:Destroy()
    self._bindable:Destroy()
end

--------------------------------------------------------------------------------
-- 2. THEME ENGINE
--------------------------------------------------------------------------------
local Theme = {
    BackgroundPrimary   = Color3.fromRGB(18, 18, 22),
    BackgroundSecondary = Color3.fromRGB(26, 26, 32),
    Surface             = Color3.fromRGB(34, 34, 42),
    Border              = Color3.fromRGB(50, 50, 62),
    TextPrimary         = Color3.fromRGB(240, 240, 245),
    TextSecondary       = Color3.fromRGB(150, 150, 165),
    Accent              = Color3.fromRGB(85, 170, 255),
    AccentHover         = Color3.fromRGB(115, 185, 255),
    BorderActive        = Color3.fromRGB(85, 170, 255),
    Success             = Color3.fromRGB(75, 210, 140),
    Danger              = Color3.fromRGB(240, 70, 70),
}

local ThemeBindings = {}
local function RegisterThemeBinding(instance: Instance, property: string, tokenKey: string)
    table.insert(ThemeBindings, { Instance = instance, Property = property, Key = tokenKey })
    (instance :: any)[property] = (Theme :: any)[tokenKey]
end

local function SetThemeAccent(newAccent: Color3)
    Theme.Accent = newAccent
    Theme.BorderActive = newAccent
    for _, binding in ipairs(ThemeBindings) do
        if binding.Key == "Accent" or binding.Key == "BorderActive" then
            if binding.Instance and binding.Instance.Parent then
                TweenService:Create(binding.Instance, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    [binding.Property] = (Theme :: any)[binding.Key]
                }):Play()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 3. BASE WINDOW CLASS
--------------------------------------------------------------------------------
local TopZIndex = 10
local BaseWindow = {}
BaseWindow.__index = BaseWindow

function BaseWindow.new(titleText: string, defaultSize: UDim2, defaultPos: UDim2, minSize: Vector2?)
    local self = setmetatable({}, BaseWindow)
    self.MinSize = minSize or Vector2.new(240, 160)
    self.MaxSize = Vector2.new(1920, 1080)
    self.IsMinimized = false
    self.StoredSize = defaultSize
    self.OnClose = Signal.new()

    local Frame = Instance.new("Frame")
    Frame.Name = titleText .. "_Window"
    Frame.Size = defaultSize
    Frame.Position = defaultPos
    Frame.BackgroundColor3 = Theme.BackgroundPrimary
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.ClipsDescendants = false
    Frame.Parent = ScreenHost
    self.Frame = Frame

    local Stroke = Instance.new("UIStroke")
    Stroke.Thickness = 1
    Stroke.Color = Theme.Border
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Parent = Frame
    self.Stroke = Stroke

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 28)
    TopBar.BackgroundColor3 = Theme.BackgroundSecondary
    TopBar.BorderSizePixel = 0
    TopBar.Parent = Frame
    self.TopBar = TopBar

    local TopBarBottomLine = Instance.new("Frame")
    TopBarBottomLine.Size = UDim2.new(1, 0, 0, 1)
    TopBarBottomLine.Position = UDim2.new(0, 0, 1, -1)
    TopBarBottomLine.BackgroundColor3 = Theme.Border
    TopBarBottomLine.BorderSizePixel = 0
    TopBarBottomLine.Parent = TopBar
    RegisterThemeBinding(TopBarBottomLine, "BackgroundColor3", "Border")

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Size = UDim2.new(1, -100, 1, 0)
    TitleLabel.Position = UDim2.new(0, 8, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.Code
    TitleLabel.Text = string.upper(titleText)
    TitleLabel.TextColor3 = Theme.TextPrimary
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TopBar
    self.TitleLabel = TitleLabel

    local Controls = Instance.new("Frame")
    Controls.Name = "Controls"
    Controls.Size = UDim2.new(0, 60, 1, 0)
    Controls.Position = UDim2.new(1, -60, 0, 0)
    Controls.BackgroundTransparency = 1
    Controls.Parent = TopBar

    local Layout = Instance.new("UIListLayout")
    Layout.FillDirection = Enum.FillDirection.Horizontal
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    Layout.VerticalAlignment = Enum.VerticalAlignment.Center
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 2)
    Layout.Parent = Controls

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinBtn"
    MinBtn.Size = UDim2.new(0, 24, 0, 20)
    MinBtn.BackgroundColor3 = Theme.Surface
    MinBtn.BorderSizePixel = 0
    MinBtn.Font = Enum.Font.Code
    MinBtn.Text = "—"
    MinBtn.TextColor3 = Theme.TextSecondary
    MinBtn.TextSize = 11
    MinBtn.AutoButtonColor = false
    MinBtn.Parent = Controls

    local MinStroke = Instance.new("UIStroke")
    MinStroke.Thickness = 1
    MinStroke.Color = Theme.Border
    MinStroke.Parent = MinBtn

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 24, 0, 20)
    CloseBtn.BackgroundColor3 = Theme.Surface
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Font = Enum.Font.Code
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Theme.TextSecondary
    CloseBtn.TextSize = 11
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = Controls

    local CloseStroke = Instance.new("UIStroke")
    CloseStroke.Thickness = 1
    CloseStroke.Color = Theme.Border
    CloseStroke.Parent = CloseBtn

    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, 0, 1, -28)
    Content.Position = UDim2.new(0, 0, 0, 28)
    Content.BackgroundTransparency = 1
    Content.ClipsDescendants = true
    Content.Parent = Frame
    self.Content = Content

    local Grip = Instance.new("TextButton")
    Grip.Name = "ResizeGrip"
    Grip.Size = UDim2.new(0, 14, 0, 14)
    Grip.AnchorPoint = Vector2.new(1, 1)
    Grip.Position = UDim2.new(1, 0, 1, 0)
    Grip.BackgroundTransparency = 1
    Grip.Text = "◢"
    Grip.Font = Enum.Font.Code
    Grip.TextColor3 = Theme.TextSecondary
    Grip.TextSize = 12
    Grip.ZIndex = 5
    Grip.Parent = Frame
    self.Grip = Grip

    local function BringToFront()
        TopZIndex += 1
        Frame.ZIndex = TopZIndex
        Stroke.Color = Theme.BorderActive
    end
    Frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            BringToFront()
        end
    end)

    local Dragging = false
    local DragStart = Vector2.zero
    local StartPos = UDim2.new()

    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            DragStart = input.Position
            StartPos = Frame.Position
            BringToFront()

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    Dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - DragStart
            local vp = Workspace.CurrentCamera.ViewportSize
            local targetX = StartPos.X.Offset + delta.X
            local targetY = StartPos.Y.Offset + delta.Y

            if targetX < 12 then targetX = 0 end
            if targetY < 12 then targetY = 0 end
            if math.abs((targetX + Frame.AbsoluteSize.X) - vp.X) < 12 then
                targetX = vp.X - Frame.AbsoluteSize.X
            end
            if math.abs((targetY + Frame.AbsoluteSize.Y) - vp.Y) < 12 then
                targetY = vp.Y - Frame.AbsoluteSize.Y
            end

            Frame.Position = UDim2.new(StartPos.X.Scale, targetX, StartPos.Y.Scale, targetY)
        end
    end)

    local Resizing = false
    local ResizeStartMouse = Vector2.zero
    local ResizeStartSize = Vector2.zero

    Grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Resizing = true
            ResizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
            ResizeStartSize = Frame.AbsoluteSize
            BringToFront()

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    Resizing = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if Resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = Vector2.new(input.Position.X, input.Position.Y)
            local delta = mousePos - ResizeStartMouse
            local newW = math.clamp(ResizeStartSize.X + delta.X, self.MinSize.X, self.MaxSize.X)
            local newH = math.clamp(ResizeStartSize.Y + delta.Y, self.MinSize.Y, self.MaxSize.Y)
            Frame.Size = UDim2.new(0, newW, 0, newH)
        end
    end)

    MinBtn.MouseButton1Click:Connect(function()
        self.IsMinimized = not self.IsMinimized
        if self.IsMinimized then
            self.StoredSize = Frame.Size
            Content.Visible = false
            Grip.Visible = false
            Frame.Size = UDim2.new(0, Frame.AbsoluteSize.X, 0, 28)
            MinBtn.Text = "□"
        else
            Frame.Size = self.StoredSize
            Content.Visible = true
            Grip.Visible = true
            MinBtn.Text = "—"
        end
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        self.OnClose:Fire()
        Frame.Visible = false
    end)

    for _, btn in ipairs({ MinBtn, CloseBtn }) do
        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = Theme.Border
            btn.TextColor3 = Theme.TextPrimary
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = Theme.Surface
            btn.TextColor3 = Theme.TextSecondary
        end)
    end

    RegisterThemeBinding(Frame, "BackgroundColor3", "BackgroundPrimary")
    RegisterThemeBinding(TopBar, "BackgroundColor3", "BackgroundSecondary")
    RegisterThemeBinding(TitleLabel, "TextColor3", "TextPrimary")
    RegisterThemeBinding(Stroke, "Color", "Border")

    return self
end

--------------------------------------------------------------------------------
-- 4. MICRO-INTERACTION HELPERS
--------------------------------------------------------------------------------
local function AttachMicroInteractions(button: GuiButton)
    local scale = button:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Scale = 1.0
        scale.Parent = button
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.04 }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
    end)
    button.MouseButton1Down:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.94 }):Play()
    end)
    button.MouseButton1Up:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.04 }):Play()
    end)
end

--------------------------------------------------------------------------------
-- 5. ADVANTAGE ENGINE (PHYSICS & HOOKS)
--------------------------------------------------------------------------------
local Advantage = {
    FlyEnabled = false,
    FlySpeed = 50,
    PlatformEnabled = false,
    PlatformPart = nil :: BasePart?,
    PlatformStepConn = nil :: RBXScriptConnection?,
    PlatformY = 0,
    FlingEnabled = false,
    FlingConn = nil :: RBXScriptConnection?,
    NoclipEnabled = false,
    NoclipConn = nil :: RBXScriptConnection?,
    OriginalWalkSpeed = 16,
    OriginalJumpPower = 50,
    CustomWalkSpeed = 16,
    CustomJumpPower = 50,
    InfiniteJump = false,
}

local function GetRoot(char: Model?): BasePart?
    local character = char or LocalPlayer.Character
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")) :: BasePart?
end

local function GetHumanoid(char: Model?): Humanoid?
    local character = char or LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

function Advantage.SetPlatformFloater(enable: boolean)
    Advantage.PlatformEnabled = enable
    if enable then
        local root = GetRoot()
        if not root then return end
        Advantage.PlatformY = root.Position.Y - 3.6

        local part = Instance.new("Part")
        part.Name = "FishPlatform_Part"
        part.Size = Vector3.new(6, 1, 6)
        part.Anchored = true
        part.CanCollide = true
        part.Transparency = 0.4
        part.Material = Enum.Material.Neon
        part.Color = Theme.Accent
        part.CFrame = CFrame.new(root.Position.X, Advantage.PlatformY, root.Position.Z)
        part.Parent = Workspace
        Advantage.PlatformPart = part

        local stepTimer = 0
        Advantage.PlatformStepConn = RunService.Heartbeat:Connect(function(dt)
            local currentRoot = GetRoot()
            if not currentRoot or not Advantage.PlatformPart then return end

            stepTimer += dt
            if stepTimer >= 0.25 then
                stepTimer = 0
                Advantage.PlatformY -= 0.45
            end

            local hum = GetHumanoid()
            if hum and hum:GetState() == Enum.HumanoidStateType.Jumping then
                Advantage.PlatformY = currentRoot.Position.Y - 3.6
            end

            Advantage.PlatformPart.CFrame = CFrame.new(currentRoot.Position.X, Advantage.PlatformY, currentRoot.Position.Z)
        end)
    else
        if Advantage.PlatformStepConn then
            Advantage.PlatformStepConn:Disconnect()
            Advantage.PlatformStepConn = nil
        end
        if Advantage.PlatformPart then
            Advantage.PlatformPart:Destroy()
            Advantage.PlatformPart = nil
        end
    end
end

function Advantage.SetFling(enable: boolean)
    Advantage.FlingEnabled = enable
    if enable then
        Advantage.FlingConn = RunService.PostSimulation:Connect(function()
            local root = GetRoot()
            if root then
                root.AssemblyAngularVelocity = Vector3.new(0, 999999, 0)
            end
        end)
    else
        if Advantage.FlingConn then
            Advantage.FlingConn:Disconnect()
            Advantage.FlingConn = nil
        end
        local root = GetRoot()
        if root then
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local FlyLinearVelocity: LinearVelocity? = nil
local FlyAttachment: Attachment? = nil

function Advantage.SetFlight(enable: boolean)
    Advantage.FlyEnabled = enable
    local root = GetRoot()
    if not root then return end

    if enable then
        FlyAttachment = Instance.new("Attachment")
        FlyAttachment.Name = "FishFly_Att"
        FlyAttachment.Parent = root

        FlyLinearVelocity = Instance.new("LinearVelocity")
        FlyLinearVelocity.Name = "FishFly_LV"
        FlyLinearVelocity.Attachment0 = FlyAttachment
        FlyLinearVelocity.MaxForce = 1e6
        FlyLinearVelocity.VectorVelocity = Vector3.zero
        FlyLinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
        FlyLinearVelocity.Parent = root
    else
        if FlyLinearVelocity then FlyLinearVelocity:Destroy(); FlyLinearVelocity = nil end
        if FlyAttachment then FlyAttachment:Destroy(); FlyAttachment = nil end
    end
end

RunService.RenderStepped:Connect(function()
    if Advantage.FlyEnabled and FlyLinearVelocity then
        local cam = Workspace.CurrentCamera
        local moveDir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end

        if moveDir.Magnitude > 0 then
            FlyLinearVelocity.VectorVelocity = moveDir.Unit * Advantage.FlySpeed
        else
            FlyLinearVelocity.VectorVelocity = Vector3.zero
        end
    end
end)

function Advantage.SetNoclip(enable: boolean)
    Advantage.NoclipEnabled = enable
    if enable then
        Advantage.NoclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if Advantage.NoclipConn then
            Advantage.NoclipConn:Disconnect()
            Advantage.NoclipConn = nil
        end
    end
end

UserInputService.JumpRequest:Connect(function()
    if Advantage.InfiniteJump then
        local hum = GetHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

--------------------------------------------------------------------------------
-- 6. COREGUI REPLACEMENTS: CUSTOM CHAT & PLAYER LIST
--------------------------------------------------------------------------------
pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local ChatWindow = BaseWindow.new("Chat", UDim2.new(0, 320, 0, 240), UDim2.new(0, 20, 1, -260), Vector2.new(260, 180))

local ChatTopControls = Instance.new("Frame")
ChatTopControls.Size = UDim2.new(0, 70, 1, 0)
ChatTopControls.Position = UDim2.new(0, 50, 0, 0)
ChatTopControls.BackgroundTransparency = 1
ChatTopControls.Parent = ChatWindow.TopBar

local WaveformBar = Instance.new("Frame")
WaveformBar.Size = UDim2.new(0, 24, 0, 10)
WaveformBar.Position = UDim2.new(0, 0, 0.5, -5)
WaveformBar.BackgroundColor3 = Theme.Surface
WaveformBar.BorderSizePixel = 0
WaveformBar.Parent = ChatTopControls

local WaveStroke = Instance.new("UIStroke")
WaveStroke.Thickness = 1
WaveStroke.Color = Theme.Border
WaveStroke.Parent = WaveformBar

local WaveFill = Instance.new("Frame")
WaveFill.Size = UDim2.new(0.5, 0, 1, 0)
WaveFill.BackgroundColor3 = Theme.Accent
WaveFill.BorderSizePixel = 0
WaveFill.Parent = WaveformBar
RegisterThemeBinding(WaveFill, "BackgroundColor3", "Accent")

task.spawn(function()
    while true do
        task.wait(0.1)
        local amp = math.clamp(math.noise(tick() * 3, 0, 0) * 1.5, 0.1, 1.0)
        WaveFill.Size = UDim2.new(amp, 0, 1, 0)
    end
end)

local MessageScroll = Instance.new("ScrollingFrame")
MessageScroll.Name = "Messages"
MessageScroll.Size = UDim2.new(1, -8, 1, -34)
MessageScroll.Position = UDim2.new(0, 4, 0, 4)
MessageScroll.BackgroundTransparency = 1
MessageScroll.BorderSizePixel = 0
MessageScroll.ScrollBarThickness = 3
MessageScroll.ScrollBarImageColor3 = Theme.Border
MessageScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MessageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
MessageScroll.Parent = ChatWindow.Content

local MsgLayout = Instance.new("UIListLayout")
MsgLayout.SortOrder = Enum.SortOrder.LayoutOrder
MsgLayout.Padding = UDim.new(0, 4)
MsgLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
MsgLayout.Parent = MessageScroll

local function AddChatMessage(sender: string, text: string, colorHex: string?)
    local hex = colorHex or "55AAFF"
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -6, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.RichText = true
    lbl.Text = string.format("[USER] <font color="#%s"><b>%s</b></font>: %s", hex, sender, text)
    lbl.TextColor3 = Theme.TextPrimary
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = MessageScroll

    MessageScroll.CanvasPosition = Vector2.new(0, MessageScroll.AbsoluteCanvasSize.Y)
end

local ChatInputBar = Instance.new("Frame")
ChatInputBar.Size = UDim2.new(1, -8, 0, 24)
ChatInputBar.Position = UDim2.new(0, 4, 1, -26)
ChatInputBar.BackgroundColor3 = Theme.Surface
ChatInputBar.BorderSizePixel = 0
ChatInputBar.Parent = ChatWindow.Content

local ChatInputStroke = Instance.new("UIStroke")
ChatInputStroke.Thickness = 1
ChatInputStroke.Color = Theme.Border
ChatInputStroke.Parent = ChatInputBar

local QuickBtn = Instance.new("TextButton")
QuickBtn.Size = UDim2.new(0, 46, 1, 0)
QuickBtn.BackgroundColor3 = Theme.BackgroundSecondary
QuickBtn.BorderSizePixel = 0
QuickBtn.Font = Enum.Font.Code
QuickBtn.Text = "Quick"
QuickBtn.TextColor3 = Theme.TextSecondary
QuickBtn.TextSize = 10
QuickBtn.Parent = ChatInputBar

local ChatBox = Instance.new("TextBox")
ChatBox.Size = UDim2.new(1, -94, 1, 0)
ChatBox.Position = UDim2.new(0, 48, 0, 0)
ChatBox.BackgroundTransparency = 1
ChatBox.Font = Enum.Font.Code
ChatBox.PlaceholderText = "TYPE HERE..."
ChatBox.PlaceholderColor3 = Theme.TextSecondary
ChatBox.Text = ""
ChatBox.TextColor3 = Theme.TextPrimary
ChatBox.TextSize = 11
ChatBox.ClearTextOnFocus = false
ChatBox.TextXAlignment = Enum.TextXAlignment.Left
ChatBox.Parent = ChatInputBar

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(0, 44, 1, 0)
SendBtn.Position = UDim2.new(1, -44, 0, 0)
SendBtn.BackgroundColor3 = Theme.Accent
SendBtn.BorderSizePixel = 0
SendBtn.Font = Enum.Font.Code
SendBtn.Text = "Send"
SendBtn.TextColor3 = Color3.new(1, 1, 1)
SendBtn.TextSize = 10
SendBtn.Parent = ChatInputBar
RegisterThemeBinding(SendBtn, "BackgroundColor3", "Accent")

local function TransmitMessage(msg: string)
    if string.len(msg) == 0 then return end
    AddChatMessage(LocalPlayer.DisplayName, msg, "55AAFF")
    ChatBox.Text = ""

    task.spawn(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local general = TextChatService:WaitForChild("TextChannels", 2)
            if general and general:FindFirstChild("RBXGeneral") then
                (general.RBXGeneral :: any):SendAsync(msg)
            end
        else
            local sayEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            if sayEvent and sayEvent:FindFirstChild("SayMessageRequest") then
                sayEvent.SayMessageRequest:FireServer(msg, "All")
            end
        end
    end)
end

SendBtn.MouseButton1Click:Connect(function()
    TransmitMessage(ChatBox.Text)
end)
ChatBox.FocusLost:Connect(function(enter)
    if enter then
        TransmitMessage(ChatBox.Text)
    end
end)

local MacroFrame = Instance.new("Frame")
MacroFrame.Size = UDim2.new(0, 120, 0, 90)
MacroFrame.Position = UDim2.new(0, 4, 1, -120)
MacroFrame.BackgroundColor3 = Theme.BackgroundSecondary
MacroFrame.BorderSizePixel = 0
MacroFrame.Visible = false
MacroFrame.ZIndex = 8
MacroFrame.Parent = ChatWindow.Content

local MacroStroke = Instance.new("UIStroke")
MacroStroke.Thickness = 1
MacroStroke.Color = Theme.Border
MacroStroke.Parent = MacroFrame

local MacroLayout = Instance.new("UIListLayout")
MacroLayout.SortOrder = Enum.SortOrder.LayoutOrder
MacroLayout.Padding = UDim.new(0, 2)
MacroLayout.Parent = MacroFrame

local QuickMacros = { "gg", "nice shot!", "hello everyone", "lagging rn" }
for _, macro in ipairs(QuickMacros) do
    local mBtn = Instance.new("TextButton")
    mBtn.Size = UDim2.new(1, 0, 0, 20)
    mBtn.BackgroundColor3 = Theme.Surface
    mBtn.BorderSizePixel = 0
    mBtn.Font = Enum.Font.Code
    mBtn.Text = macro
    mBtn.TextColor3 = Theme.TextPrimary
    mBtn.TextSize = 10
    mBtn.ZIndex = 9
    mBtn.Parent = MacroFrame
    mBtn.MouseButton1Click:Connect(function()
        TransmitMessage(macro)
        MacroFrame.Visible = false
    end)
end
QuickBtn.MouseButton1Click:Connect(function()
    MacroFrame.Visible = not MacroFrame.Visible
end)

local PlayerListWindow = BaseWindow.new("Players : 0 online", UDim2.new(0, 220, 0, 260), UDim2.new(1, -240, 0, 30), Vector2.new(200, 180))

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size = UDim2.new(1, -8, 1, -8)
PlayerScroll.Position = UDim2.new(0, 4, 0, 4)
PlayerScroll.BackgroundTransparency = 1
PlayerScroll.BorderSizePixel = 0
PlayerScroll.ScrollBarThickness = 3
PlayerScroll.ScrollBarImageColor3 = Theme.Border
PlayerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerScroll.Parent = PlayerListWindow.Content

local PlrLayout = Instance.new("UIListLayout")
PlrLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlrLayout.Padding = UDim.new(0, 4)
PlrLayout.Parent = PlayerScroll

local DrawerWindow = BaseWindow.new("Select Plr", UDim2.new(0, 170, 0, 220), UDim2.new(1, -420, 0, 30), Vector2.new(160, 180))
DrawerWindow.Frame.Visible = false

local DrawerContent = DrawerWindow.Content
local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.new(0, 50, 0, 50)
AvatarImg.Position = UDim2.new(0, 6, 0, 6)
AvatarImg.BackgroundColor3 = Theme.Surface
AvatarImg.BorderSizePixel = 0
AvatarImg.Parent = DrawerContent

local AvatarStroke = Instance.new("UIStroke")
AvatarStroke.Thickness = 1
AvatarStroke.Color = Theme.Border
AvatarStroke.Parent = AvatarImg

local PlrNameLabel = Instance.new("TextLabel")
PlrNameLabel.Size = UDim2.new(1, -66, 0, 24)
PlrNameLabel.Position = UDim2.new(0, 62, 0, 6)
PlrNameLabel.BackgroundTransparency = 1
PlrNameLabel.Font = Enum.Font.Code
PlrNameLabel.Text = "Name"
PlrNameLabel.TextColor3 = Theme.TextPrimary
PlrNameLabel.TextSize = 11
PlrNameLabel.TextXAlignment = Enum.TextXAlignment.Left
PlrNameLabel.Parent = DrawerContent

local PlrIdLabel = Instance.new("TextLabel")
PlrIdLabel.Size = UDim2.new(1, -66, 0, 20)
PlrIdLabel.Position = UDim2.new(0, 62, 0, 30)
PlrIdLabel.BackgroundTransparency = 1
PlrIdLabel.Font = Enum.Font.Code
PlrIdLabel.Text = "ID: 0"
PlrIdLabel.TextColor3 = Theme.TextSecondary
PlrIdLabel.TextSize = 9
PlrIdLabel.TextXAlignment = Enum.TextXAlignment.Left
PlrIdLabel.Parent = DrawerContent

local DrawerActionContainer = Instance.new("Frame")
DrawerActionContainer.Size = UDim2.new(1, -12, 1, -64)
DrawerActionContainer.Position = UDim2.new(0, 6, 0, 60)
DrawerActionContainer.BackgroundTransparency = 1
DrawerActionContainer.Parent = DrawerContent

local DrawerActionLayout = Instance.new("UIListLayout")
DrawerActionLayout.SortOrder = Enum.SortOrder.LayoutOrder
DrawerActionLayout.Padding = UDim.new(0, 3)
DrawerActionLayout.Parent = DrawerActionContainer

local SelectedTargetPlayer: Player? = nil

local function CreateDrawerButton(label: string, onClick: () -> ())
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 22)
    btn.BackgroundColor3 = Theme.Surface
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Code
    btn.Text = label
    btn.TextColor3 = Theme.TextPrimary
    btn.TextSize = 10
    btn.Parent = DrawerActionContainer

    local s = Instance.new("UIStroke")
    s.Thickness = 1
    s.Color = Theme.Border
    s.Parent = btn

    AttachMicroInteractions(btn)
    btn.MouseButton1Click:Connect(onClick)
end

CreateDrawerButton("Add Friend", function()
    if SelectedTargetPlayer then
        pcall(function() StarterGui:SetCore("PromptSendFriendRequest", SelectedTargetPlayer) end)
    end
end)
CreateDrawerButton("Look At Avatar", function()
    if SelectedTargetPlayer then
        pcall(function() GuiService:InspectPlayerFromUserId(SelectedTargetPlayer.UserId) end)
    end
end)
CreateDrawerButton("Spectate", function()
    if SelectedTargetPlayer and SelectedTargetPlayer.Character then
        local hum = SelectedTargetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            Workspace.CurrentCamera.CameraSubject = hum
        end
    end
end)
CreateDrawerButton("Teleport To", function()
    if SelectedTargetPlayer and SelectedTargetPlayer.Character then
        local tRoot = GetRoot(SelectedTargetPlayer.Character)
        local myRoot = GetRoot()
        if tRoot and myRoot then
            myRoot.CFrame = tRoot.CFrame + Vector3.new(0, 2, 0)
        end
    end
end)
CreateDrawerButton("Fling Player", function()
    if SelectedTargetPlayer and SelectedTargetPlayer.Character then
        local tRoot = GetRoot(SelectedTargetPlayer.Character)
        local myRoot = GetRoot()
        if tRoot and myRoot then
            Advantage.SetFling(true)
            myRoot.CFrame = tRoot.CFrame
            task.wait(0.6)
            Advantage.SetFling(false)
        end
    end
end)

local function OpenDrawerForPlayer(target: Player)
    SelectedTargetPlayer = target
    DrawerWindow.TitleLabel.Text = string.upper(target.DisplayName)
    PlrNameLabel.Text = target.DisplayName
    PlrIdLabel.Text = "ID: " .. tostring(target.UserId)
    DrawerWindow.Frame.Visible = true

    task.spawn(function()
        local thumb, isReady = Players:GetUserThumbnailAsync(target.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        if isReady then
            AvatarImg.Image = thumb
        end
    end)
end

local PlayerRows = {}
local function RefreshPlayerList()
    local all = Players:GetPlayers()
    PlayerListWindow.TitleLabel.Text = string.format("PLAYERS : %d ONLINE", #all)

    for _, row in pairs(PlayerRows) do
        row:Destroy()
    end
    table.clear(PlayerRows)

    for i, plr in ipairs(all) do
        local row = Instance.new("TextButton")
        row.Name = "Row_" .. plr.Name
        row.Size = UDim2.new(1, 0, 0, 26)
        row.Position = UDim2.new(1.3, 0, 0, 0)
        row.BackgroundColor3 = Theme.Surface
        row.BorderSizePixel = 0
        row.AutoButtonColor = false
        row.Text = ""
        row.Parent = PlayerScroll
        PlayerRows[plr] = row

        local rowStroke = Instance.new("UIStroke")
        rowStroke.Thickness = 1
        rowStroke.Color = Theme.Border
        rowStroke.Parent = row

        local userIcon = Instance.new("TextLabel")
        userIcon.Size = UDim2.new(0, 20, 1, 0)
        userIcon.Position = UDim2.new(0, 4, 0, 0)
        userIcon.BackgroundTransparency = 1
        userIcon.Font = Enum.Font.Code
        userIcon.Text = "👤"
        userIcon.TextColor3 = Theme.TextSecondary
        userIcon.TextSize = 11
        userIcon.Parent = row

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -50, 1, 0)
        nameLbl.Position = UDim2.new(0, 26, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.Code
        nameLbl.Text = plr.DisplayName
        nameLbl.TextColor3 = Theme.TextPrimary
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = row

        local indexLbl = Instance.new("TextLabel")
        indexLbl.Size = UDim2.new(0, 20, 1, 0)
        indexLbl.Position = UDim2.new(1, -24, 0, 0)
        indexLbl.BackgroundTransparency = 1
        indexLbl.Font = Enum.Font.Code
        indexLbl.Text = tostring(i)
        indexLbl.TextColor3 = Theme.TextSecondary
        indexLbl.TextSize = 10
        indexLbl.Parent = row

        row.MouseButton1Click:Connect(function()
            OpenDrawerForPlayer(plr)
        end)

        task.delay((i - 1) * 0.035, function()
            if row and row.Parent then
                TweenService:Create(row, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0, 0, 0, 0)
                }):Play()
            end
        end)
    end
end

RefreshPlayerList()
Players.PlayerAdded:Connect(function() RefreshPlayerList() end)
Players.PlayerRemoving:Connect(function(plr)
    if PlayerRows[plr] then
        local row = PlayerRows[plr]
        local tw = TweenService:Create(row, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1.3, 0, 0, 0)
        })
        tw:Play()
        tw.Completed:Connect(function()
            row:Destroy()
            PlayerRows[plr] = nil
            PlayerListWindow.TitleLabel.Text = string.format("PLAYERS : %d ONLINE", #Players:GetPlayers())
        end)
    end
end)

--------------------------------------------------------------------------------
-- 7. MUSIC & MEDIA OVERLAY SUBSYSTEM
--------------------------------------------------------------------------------
local MusicWindow = BaseWindow.new("Music Player", UDim2.new(0, 360, 0, 160), UDim2.new(0, 20, 0, 30), Vector2.new(300, 140))

local MusicContent = MusicWindow.Content

local CoverArt = Instance.new("ImageLabel")
CoverArt.Name = "SongCover"
CoverArt.Size = UDim2.new(0, 90, 0, 90)
CoverArt.Position = UDim2.new(0, 8, 0, 8)
CoverArt.BackgroundColor3 = Theme.Surface
CoverArt.BorderSizePixel = 0
CoverArt.Image = "rbxassetid://10849911991"
CoverArt.Parent = MusicContent

local CoverStroke = Instance.new("UIStroke")
CoverStroke.Thickness = 1
CoverStroke.Color = Theme.Border
CoverStroke.Parent = CoverArt

local CoverLabel = Instance.new("TextLabel")
CoverLabel.Size = UDim2.new(1, 0, 1, 0)
CoverLabel.BackgroundTransparency = 1
CoverLabel.Font = Enum.Font.Code
CoverLabel.Text = "SONG
COVER"
CoverLabel.TextColor3 = Theme.TextSecondary
CoverLabel.TextSize = 11
CoverLabel.Parent = CoverArt

local SongDetails = Instance.new("Frame")
SongDetails.Size = UDim2.new(1, -114, 1, -16)
SongDetails.Position = UDim2.new(0, 106, 0, 8)
SongDetails.BackgroundTransparency = 1
SongDetails.Parent = MusicContent

local SongTitleLabel = Instance.new("TextLabel")
SongTitleLabel.Size = UDim2.new(1, 0, 0, 18)
SongTitleLabel.BackgroundTransparency = 1
SongTitleLabel.Font = Enum.Font.Code
SongTitleLabel.Text = "Song Title : Track 01"
SongTitleLabel.TextColor3 = Theme.Accent
SongTitleLabel.TextSize = 12
SongTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SongTitleLabel.Parent = SongDetails
RegisterThemeBinding(SongTitleLabel, "TextColor3", "Accent")

local LyricsBox = Instance.new("Frame")
LyricsBox.Size = UDim2.new(1, 0, 0, 40)
LyricsBox.Position = UDim2.new(0, 0, 0, 22)
LyricsBox.BackgroundColor3 = Theme.Surface
LyricsBox.BorderSizePixel = 0
LyricsBox.Parent = SongDetails

local LyricsStroke = Instance.new("UIStroke")
LyricsStroke.Thickness = 1
LyricsStroke.Color = Theme.Border
LyricsStroke.Parent = LyricsBox

local LyricsLabel = Instance.new("TextLabel")
LyricsLabel.Size = UDim2.new(1, -8, 1, 0)
LyricsLabel.Position = UDim2.new(0, 4, 0, 0)
LyricsLabel.BackgroundTransparency = 1
LyricsLabel.Font = Enum.Font.Code
LyricsLabel.Text = "♪ (Synced lyrics stream active...)"
LyricsLabel.TextColor3 = Theme.TextPrimary
LyricsLabel.TextSize = 10
LyricsLabel.TextWrapped = true
LyricsLabel.Parent = LyricsBox

local VisualizerFrame = Instance.new("Frame")
VisualizerFrame.Size = UDim2.new(1, 0, 0, 36)
VisualizerFrame.Position = UDim2.new(0, 0, 0, 68)
VisualizerFrame.BackgroundColor3 = Theme.BackgroundSecondary
VisualizerFrame.BorderSizePixel = 0
VisualizerFrame.Parent = SongDetails

local VisStroke = Instance.new("UIStroke")
VisStroke.Thickness = 1
VisStroke.Color = Theme.Border
VisStroke.Parent = VisualizerFrame

local VisLayout = Instance.new("UIListLayout")
VisLayout.FillDirection = Enum.FillDirection.Horizontal
VisLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
VisLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
VisLayout.Padding = UDim.new(0, 2)
VisLayout.Parent = VisualizerFrame

local VisualizerBars = {}
for i = 1, 16 do
    local bar = Instance.new("Frame")
    bar.Name = "Bar_" .. i
    bar.Size = UDim2.new(0, 8, 0, 6)
    bar.BackgroundColor3 = Theme.Accent
    bar.BorderSizePixel = 0
    bar.Parent = VisualizerFrame
    RegisterThemeBinding(bar, "BackgroundColor3", "Accent")
    table.insert(VisualizerBars, bar)
end

task.spawn(function()
    while true do
        task.wait(0.08)
        local t = tick()
        for idx, bar in ipairs(VisualizerBars) do
            local noiseVal = math.noise(idx * 0.35, t * 4, 0)
            local norm = math.clamp(math.abs(noiseVal) * 32, 4, 30)
            TweenService:Create(bar, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {
                Size = UDim2.new(0, 8, 0, norm)
            }):Play()
        end
    end
end)

--------------------------------------------------------------------------------
-- 8. MAIN MENU GUI (TAB REPOSITORY & CARD GRID)
--------------------------------------------------------------------------------
local MainMenu = BaseWindow.new("FIHMENU", UDim2.new(0, 520, 0, 340), UDim2.new(0.5, -260, 0.5, -170), Vector2.new(460, 280))

local TopSongBanner = Instance.new("TextLabel")
TopSongBanner.Size = UDim2.new(0, 180, 0, 18)
TopSongBanner.Position = UDim2.new(0, 90, 0, 5)
TopSongBanner.BackgroundColor3 = Theme.Surface
TopSongBanner.BorderSizePixel = 0
TopSongBanner.Font = Enum.Font.Code
TopSongBanner.Text = "♪ Song: Lo-Fi Study Beat"
TopSongBanner.TextColor3 = Theme.TextSecondary
TopSongBanner.TextSize = 10
TopSongBanner.Parent = MainMenu.TopBar

local BannerStroke = Instance.new("UIStroke")
BannerStroke.Thickness = 1
BannerStroke.Color = Theme.Border
BannerStroke.Parent = TopSongBanner

local NavRail = Instance.new("Frame")
NavRail.Name = "NavRail"
NavRail.Size = UDim2.new(0, 100, 1, 0)
NavRail.BackgroundColor3 = Theme.BackgroundSecondary
NavRail.BorderSizePixel = 0
NavRail.Parent = MainMenu.Content

local NavLine = Instance.new("Frame")
NavLine.Size = UDim2.new(0, 1, 1, 0)
NavLine.Position = UDim2.new(1, -1, 0, 0)
NavLine.BackgroundColor3 = Theme.Border
NavLine.BorderSizePixel = 0
NavLine.Parent = NavRail

local NavLayout = Instance.new("UIListLayout")
NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
NavLayout.Padding = UDim.new(0, 3)
NavLayout.Parent = NavRail

local NavPad = Instance.new("UIPadding")
NavPad.PaddingTop = UDim.new(0, 6)
NavPad.PaddingLeft = UDim.new(0, 6)
NavPad.PaddingRight = UDim.new(0, 6)
NavPad.Parent = NavRail

local TabContainer = Instance.new("Frame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, -100, 1, 0)
TabContainer.Position = UDim2.new(0, 100, 0, 0)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainMenu.Content

local VersionLabel = Instance.new("TextLabel")
VersionLabel.Size = UDim2.new(0, 80, 0, 16)
VersionLabel.Position = UDim2.new(1, -85, 1, -18)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Font = Enum.Font.Code
VersionLabel.Text = "Version 0.1"
VersionLabel.TextColor3 = Theme.TextSecondary
VersionLabel.TextSize = 10
VersionLabel.Parent = MainMenu.Content

local TabPages = {}
local TabButtons = {}
local CurrentActiveTab = ""

local function CreateTabPage(name: string)
    local Page = Instance.new("CanvasGroup")
    Page.Name = "Page_" .. name
    Page.Size = UDim2.new(1, 0, 1, -20)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.GroupTransparency = 1
    Page.Parent = TabContainer

    local LeftCol = Instance.new("ScrollingFrame")
    LeftCol.Name = "LeftCol"
    LeftCol.Size = UDim2.new(0.5, -6, 1, 0)
    LeftCol.Position = UDim2.new(0, 4, 0, 4)
    LeftCol.BackgroundTransparency = 1
    LeftCol.BorderSizePixel = 0
    LeftCol.ScrollBarThickness = 2
    LeftCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LeftCol.Parent = Page

    local LeftLayout = Instance.new("UIListLayout")
    LeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LeftLayout.Padding = UDim.new(0, 6)
    LeftLayout.Parent = LeftCol

    local RightCol = Instance.new("ScrollingFrame")
    RightCol.Name = "RightCol"
    RightCol.Size = UDim2.new(0.5, -6, 1, 0)
    RightCol.Position = UDim2.new(0.5, 2, 0, 4)
    RightCol.BackgroundTransparency = 1
    RightCol.BorderSizePixel = 0
    RightCol.ScrollBarThickness = 2
    RightCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
    RightCol.Parent = Page

    local RightLayout = Instance.new("UIListLayout")
    RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    RightLayout.Padding = UDim.new(0, 6)
    RightLayout.Parent = RightCol

    TabPages[name] = { Page = Page, Left = LeftCol, Right = RightCol }
    return TabPages[name]
end

local function SwitchTab(tabName: string)
    if CurrentActiveTab == tabName then return end

    for name, btn in pairs(TabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = Theme.Surface
            btn.TextColor3 = Theme.Accent
        else
            btn.BackgroundColor3 = Theme.BackgroundSecondary
            btn.TextColor3 = Theme.TextSecondary
        end
    end

    local oldPage = TabPages[CurrentActiveTab]
    local newPage = TabPages[tabName]

    if oldPage then
        local tw = TweenService:Create(oldPage.Page, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(-0.08, 0, 0, 0),
            GroupTransparency = 1
        })
        tw:Play()
        tw.Completed:Connect(function()
            oldPage.Page.Visible = false
        end)
    end

    if newPage then
        newPage.Page.Visible = true
        newPage.Page.Position = UDim2.new(0.08, 0, 0, 0)
        newPage.Page.GroupTransparency = 1
        TweenService:Create(newPage.Page, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0),
            GroupTransparency = 0
        }):Play()
    end

    CurrentActiveTab = tabName
end

local function RegisterNavTab(name: string)
    local btn = Instance.new("TextButton")
    btn.Name = "Nav_" .. name
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.BackgroundColor3 = Theme.BackgroundSecondary
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Code
    btn.Text = name
    btn.TextColor3 = Theme.TextSecondary
    btn.TextSize = 10
    btn.Parent = NavRail

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Theme.Border
    stroke.Parent = btn

    AttachMicroInteractions(btn)
    btn.MouseButton1Click:Connect(function()
        SwitchTab(name)
    end)

    TabButtons[name] = btn
    CreateTabPage(name)
end

local function CreateCard(parent: Instance, cardTitle: string)
    local card = Instance.new("Frame")
    card.Name = "Card_" .. cardTitle
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = Theme.Surface
    card.BorderSizePixel = 0
    card.Parent = parent

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Theme.Border
    stroke.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -12, 0, 20)
    titleLbl.Position = UDim2.new(0, 6, 0, 2)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.Code
    titleLbl.Text = string.upper(cardTitle)
    titleLbl.TextColor3 = Theme.Accent
    titleLbl.TextSize = 10
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card
    RegisterThemeBinding(titleLbl, "TextColor3", "Accent")

    local itemContainer = Instance.new("Frame")
    itemContainer.Size = UDim2.new(1, -12, 0, 0)
    itemContainer.Position = UDim2.new(0, 6, 0, 22)
    itemContainer.AutomaticSize = Enum.AutomaticSize.Y
    itemContainer.BackgroundTransparency = 1
    itemContainer.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = itemContainer

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 6)
    pad.Parent = itemContainer

    return itemContainer
end

local function AddToggle(cardContainer: Instance, labelText: string, default: boolean, callback: (boolean) -> ())
    local state = default
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundColor3 = Theme.BackgroundSecondary
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = cardContainer

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Theme.Border
    stroke.Parent = row

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 1, 0)
    title.Position = UDim2.new(0, 6, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.Code
    title.Text = labelText
    title.TextColor3 = Theme.TextPrimary
    title.TextSize = 10
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = row

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 14, 0, 14)
    box.Position = UDim2.new(1, -18, 0.5, -7)
    box.BackgroundColor3 = state and Theme.Accent or Theme.Surface
    box.BorderSizePixel = 0
    box.Parent = row

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1
    boxStroke.Color = Theme.Border
    boxStroke.Parent = box

    local checkMark = Instance.new("TextLabel")
    checkMark.Size = UDim2.new(1, 0, 1, 0)
    checkMark.BackgroundTransparency = 1
    checkMark.Font = Enum.Font.Code
    checkMark.Text = state and "✓" or ""
    checkMark.TextColor3 = Color3.new(1, 1, 1)
    checkMark.TextSize = 10
    checkMark.Parent = box

    row.MouseButton1Click:Connect(function()
        state = not state
        box.BackgroundColor3 = state and Theme.Accent or Theme.Surface
        checkMark.Text = state and "✓" or ""
        callback(state)
    end)
end

local function AddSlider(cardContainer: Instance, labelText: string, min: number, max: number, default: number, callback: (number) -> ())
    local currentVal = default
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundColor3 = Theme.BackgroundSecondary
    frame.BorderSizePixel = 0
    frame.Parent = cardContainer

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Theme.Border
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 14)
    title.Position = UDim2.new(0, 6, 0, 2)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.Code
    title.Text = labelText
    title.TextColor3 = Theme.TextPrimary
    title.TextSize = 9
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 34, 0, 14)
    valLbl.Position = UDim2.new(1, -38, 0, 2)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.Code
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = Theme.TextSecondary
    valLbl.TextSize = 9
    valLbl.Parent = frame

    local barBack = Instance.new("TextButton")
    barBack.Size = UDim2.new(1, -12, 0, 8)
    barBack.Position = UDim2.new(0, 6, 0, 18)
    barBack.BackgroundColor3 = Theme.Surface
    barBack.BorderSizePixel = 0
    barBack.Text = ""
    barBack.AutoButtonColor = false
    barBack.Parent = frame

    local fill = Instance.new("Frame")
    local initRatio = math.clamp((default - min) / (max - min), 0, 1)
    fill.Size = UDim2.new(initRatio, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = barBack
    RegisterThemeBinding(fill, "BackgroundColor3", "Accent")

    local sliding = false
    local function Update(input: InputObject)
        local posX = math.clamp((input.Position.X - barBack.AbsolutePosition.X) / barBack.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(posX, 0, 1, 0)
        currentVal = math.floor(min + (max - min) * posX)
        valLbl.Text = tostring(currentVal)
        callback(currentVal)
    end

    barBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            Update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            Update(input)
        end
    end)
end

--------------------------------------------------------------------------------
-- 9. POPULATE TABS & MODULES
--------------------------------------------------------------------------------
local NavItems = { "MAIN", "PLAYER", "TARGETS", "VISUALS", "MUSIC", "THEMES", "SCRIPTS" }
for _, nav in ipairs(NavItems) do
    RegisterNavTab(nav)
end

-- Tab: MAIN
local mainLeft = CreateCard(TabPages["MAIN"].Left, "System Status")
AddToggle(mainLeft, "Active Event Stream", true, function(s) end)
AddToggle(mainLeft, "Metatable Guard", true, function(s) end)

local mainRight = CreateCard(TabPages["MAIN"].Right, "Quick Windows")
AddToggle(mainRight, "Chat Overlay", true, function(s) ChatWindow.Frame.Visible = s end)
AddToggle(mainRight, "Player List Overlay", true, function(s) PlayerListWindow.Frame.Visible = s end)
AddToggle(mainRight, "Music Widget", true, function(s) MusicWindow.Frame.Visible = s end)

-- Tab: PLAYER
local pLeft = CreateCard(TabPages["PLAYER"].Left, "Locomotion")
AddToggle(pLeft, "Linear Flight", false, function(s) Advantage.SetFlight(s) end)
AddSlider(pLeft, "Flight Speed", 16, 200, 50, function(v) Advantage.FlySpeed = v end)
AddToggle(pLeft, "Stepped Floater", false, function(s) Advantage.SetPlatformFloater(s) end)
AddToggle(pLeft, "Noclip Stepped", false, function(s) Advantage.SetNoclip(s) end)

local pRight = CreateCard(TabPages["PLAYER"].Right, "Character Modifications")
AddSlider(pRight, "WalkSpeed", 16, 250, 16, function(v)
    Advantage.CustomWalkSpeed = v
    local hum = GetHumanoid()
    if hum then hum.WalkSpeed = v end
end)
AddSlider(pRight, "JumpPower", 50, 300, 50, function(v)
    Advantage.CustomJumpPower = v
    local hum = GetHumanoid()
    if hum then hum.JumpPower = v end
end)
AddToggle(pRight, "Infinite Jump", false, function(s) Advantage.InfiniteJump = s end)
AddToggle(pRight, "Walk Fling (Desync)", false, function(s) Advantage.SetFling(s) end)

-- Tab: TARGETS
local tLeft = CreateCard(TabPages["TARGETS"].Left, "Target Utilities")
AddToggle(tLeft, "Spectate Target", false, function(s)
    if not s then Workspace.CurrentCamera.CameraSubject = GetHumanoid() end
end)

-- Tab: MUSIC
local mLeft = CreateCard(TabPages["MUSIC"].Left, "Media Bridge")
AddToggle(mLeft, "Localhost Sync (9000)", false, function(s) end)
AddToggle(mLeft, "Simulate Audio Noise", true, function(s) end)

-- Tab: THEMES
local thLeft = CreateCard(TabPages["THEMES"].Left, "Presets")
local presets = {
    { Name = "Dark Cubed", Color = Color3.fromRGB(85, 170, 255) },
    { Name = "Cyberpunk Neon", Color = Color3.fromRGB(255, 0, 128) },
    { Name = "Acid Matrix", Color = Color3.fromRGB(0, 255, 128) },
    { Name = "Amber Sunset", Color = Color3.fromRGB(255, 160, 40) },
}
for _, p in ipairs(presets) do
    AddToggle(thLeft, p.Name, false, function(s)
        if s then SetThemeAccent(p.Color) end
    end)
end

SwitchTab("MAIN")
print("[Fish Menu]: Framework successfully booted.")
