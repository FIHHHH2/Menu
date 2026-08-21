-- UniMenu Main UI Module
-- Universal UI, tabs, settings, keybinds, music integration, ESP

local ctx = ...
local Players = ctx.Services.Players
local RunService = ctx.Services.RunService
local UserInputService = game:GetService("UserInputService")
local TweenService = ctx.Services.TweenService
local SoundService = ctx.Services.SoundService
local Lighting = ctx.Services.Lighting
local HttpService = ctx.Services.HttpService
local ReplicatedStorage = ctx.Services.ReplicatedStorage

local player = game:GetService("Players").LocalPlayer
if not player then
    error("Player not found")
    return
end
local PlayerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local S = ctx.State.S
local Music = ctx.State.Music
-- Game detection and dynamic tab loading
local function DetectGame()
    local placeId = game.PlaceId
    if placeId == 142823291 then -- MM2
        return "MM2"
    elseif placeId == 6872265036 then -- Example: Tower of Hell
        return "TowerOfHell"
    end
    return "Unknown"
end

local currentGame = DetectGame()
local gameConfig = ctx.Config.gameConfig or {}

-- Dynamically load game-specific UI
local function LoadGameTab()
    if currentGame == "MM2" then
        -- Load existing MM2 UI
        BuildMM2Tab()
    elseif currentGame == "TowerOfHell" then
        -- New tab implementation example
        local tab = {
            name = "Tower",
            features = {
                "AutoJump", "SpeedBoost", "AntiFall"
            }
        }
        AddDynamicTab(tab)
    end
end

-- Call during UI initialization
LoadGameTab()
local Themes = ctx.Config.Themes
local XP = ctx.Config.XP
local currentThemeName = ctx.Config.currentThemeName

local Utils = ctx.Modules and ctx.Modules.utils

-- ==================== GUI STATE ====================
local gui = nil
local isOpen = false
local currentTab = "Movement"
local contentContainerRef = nil
local isTransitioning = false
local selectedPlayer = ctx.Core.selectedPlayer
local playerList = ctx.Core.playerList

-- ==================== KEYBIND UI SYNC ====================
local keybindUIUpdaters = {}

local function RegisterKeybindUIUpdater(kbName, updateFn)
    keybindUIUpdaters[kbName] = updateFn
end

local function FindToggleButton(featName)
    if not contentContainerRef then return nil end
    local scroll = contentContainerRef:FindFirstChild("ContentScroll")
    if not scroll then return nil end
    for _, col in ipairs(scroll:GetChildren()) do
        if col:IsA("Frame") and (col.Name == "LeftColumn" or col.Name == "RightColumn") then
            for _, card in ipairs(col:GetChildren()) do
                if card:IsA("Frame") then
                    for _, child in ipairs(card:GetDescendants()) do
                        if child:IsA("TextButton") and child.Name == "Toggle_" .. featName then
                            return child
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- ==================== THEME SYSTEM ====================
local ThemeDefaults = {
    ["Windows XP Luna"] = {
        bg = Color3.fromRGB(10, 10, 15),
        windowBg = Color3.fromRGB(20, 20, 30),
        panel1 = Color3.fromRGB(30, 30, 40),
        panel2 = Color3.fromRGB(25, 25, 35),
        rowBg = Color3.fromRGB(35, 35, 45),
        accent = Color3.fromRGB(0, 120, 215),
        accentHover = Color3.fromRGB(0, 140, 235),
        accentPress = Color3.fromRGB(0, 100, 195),
        text = Color3.fromRGB(230, 230, 240),
        textDim = Color3.fromRGB(160, 160, 170),
        tabActive = Color3.fromRGB(40, 40, 55),
        tabInactive = Color3.fromRGB(20, 20, 30),
        tabActiveText = Color3.fromRGB(255, 255, 255),
        tabInactiveText = Color3.fromRGB(160, 160, 170),
        borderLight = Color3.fromRGB(60, 60, 80),
        borderDark = Color3.fromRGB(40, 40, 50),
        success = Color3.fromRGB(50, 220, 100),
        warning = Color3.fromRGB(255, 190, 30),
        error = Color3.fromRGB(255, 80, 80),
        sidebar1 = Color3.fromRGB(15, 15, 25),
        sidebar2 = Color3.fromRGB(10, 10, 20),
    },
    ["Dark Red"] = {
        bg = Color3.fromRGB(15, 5, 5),
        windowBg = Color3.fromRGB(25, 10, 10),
        panel1 = Color3.fromRGB(35, 15, 15),
        panel2 = Color3.fromRGB(30, 12, 12),
        rowBg = Color3.fromRGB(45, 18, 18),
        accent = Color3.fromRGB(200, 50, 50),
        accentHover = Color3.fromRGB(220, 70, 70),
        accentPress = Color3.fromRGB(180, 40, 40),
        text = Color3.fromRGB(255, 230, 230),
        textDim = Color3.fromRGB(180, 140, 140),
        tabActive = Color3.fromRGB(50, 20, 20),
        tabInactive = Color3.fromRGB(20, 10, 10),
        tabActiveText = Color3.fromRGB(255, 255, 255),
        tabInactiveText = Color3.fromRGB(180, 140, 140),
        borderLight = Color3.fromRGB(80, 30, 30),
        borderDark = Color3.fromRGB(50, 20, 20),
        success = Color3.fromRGB(100, 255, 120),
        warning = Color3.fromRGB(255, 200, 50),
        error = Color3.fromRGB(255, 100, 100),
        sidebar1 = Color3.fromRGB(20, 8, 8),
        sidebar2 = Color3.fromRGB(12, 5, 5),
    },
}

-- Cache theme colors to avoid recalculation
local function CacheTheme(theme)
    local cached = {}
    for k, v in pairs(theme) do
        if type(v) == "table" and v.R and v.G and v.B then
            cached[k] = Color3.new(v.R, v.G, v.B)
        else
            cached[k] = v
        end
    end
    return cached
end

ctx.Config.Themes = ThemeDefaults
ctx.Config.XP = CacheTheme(ThemeDefaults[currentThemeName])

-- ==================== UI HELPERS ====================
local function Lbl(parent, text, font, size, color, x, y)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, 200, 0, size + 2)
    l.Position = UDim2.new(0, x, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.Font = font or Enum.Font.Gotham
    l.TextSize = size
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function Btn(parent, text, x, y, w, h, color, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.Parent = parent
    
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.1)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = color}):Play()
    end)
    b.MouseButton1Click:Connect(callback)
    return b
end

local function ActionBtn(parent, text, x, y, w, color, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 28)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = parent
    
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.15)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = color}):Play()
    end)
    b.MouseButton1Click:Connect(callback)
    return b
end

local function ToggleBtn(parent, featName, x, y, labelText, initialState, callback)
    local S = ctx.State.S
    local state = initialState or S[featName] or false
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 200, 0, 32)
    container.Position = UDim2.new(0, x, 0, y)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText or featName
    lbl.TextColor3 = XP.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container
    
    local btn = Instance.new("TextButton")
    btn.Name = "Toggle_" .. featName
    btn.Size = UDim2.new(0, 44, 0, 22)
    btn.Position = UDim2.new(1, -44, 0.5, -11)
    btn.BackgroundColor3 = state and XP.accent or XP.borderDark
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = container
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = btn
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = btn
    
    local function UpdateVisual(newState)
        state = newState
        S[featName] = state
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        }):Play()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = state and XP.accent or XP.borderDark
        }):Play()
    end
    
    btn.MouseButton1Click:Connect(function()
        UpdateVisual(not state)
        if callback then callback(state) end
    end)
    
    RegisterKeybindUIUpdater(featName, UpdateVisual)
    
    return container
end

local function Slider(parent, featName, x, y, min, max, default, suffix, callback)
    local S = ctx.State.S
    local value = default or S[featName] or min
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 200, 0, 36)
    container.Position = UDim2.new(0, x, 0, y)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = featName .. ": " .. value .. (suffix or "")
    lbl.TextColor3 = XP.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container
    
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, 20)
    track.BackgroundColor3 = XP.borderDark
    track.BorderSizePixel = 0
    track.Parent = container
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value - min) / (max - min), 1, 0, 0)
    fill.BackgroundColor3 = XP.accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    
    local dragging = false
    
    local function UpdateValue(newValue)
        value = math.clamp(newValue, min, max)
        S[featName] = value
        fill.Size = UDim2.new((value - min) / (max - min), 1, 0, 0)
        lbl.Text = featName .. ": " .. value .. (suffix or "")
        if callback then callback(value) end
    end
    
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            UpdateValue(min + (max - min) * relX)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            UpdateValue(min + (max - min) * relX)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    return container
end

local function Card(h, order, bg)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, h)
    c.BackgroundColor3 = bg or XP.panel2
    c.BorderSizePixel = 1
    c.BorderColor3 = XP.borderDark
    c.ClipsDescendants = true
    c.LayoutOrder = order
    return c
end

local function Divider(parent, y)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, -20, 0, 1)
    d.Position = UDim2.new(0, 10, 0, y)
    d.BackgroundColor3 = XP.borderDark
    d.BorderSizePixel = 0
    d.Parent = parent
    return d
end

-- ==================== MUSIC UI ====================
local function BuildMusicCard(parent)
    local card = Card(220, 1)
    card.Parent = parent
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🎵 Music Integration"
    title.TextColor3 = XP.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card
    
    -- Last.fm Section
    local lfTitle = Instance.new("TextLabel")
    lfTitle.Size = UDim2.new(1, -20, 0, 18)
    lfTitle.Position = UDim2.new(0, 10, 0, 34)
    lfTitle.BackgroundTransparency = 1
    lfTitle.Text = "Last.fm"
    lfTitle.TextColor3 = XP.accent
    lfTitle.Font = Enum.Font.GothamBold
    lfTitle.TextSize = 12
    lfTitle.TextXAlignment = Enum.TextXAlignment.Left
    lfTitle.Parent = card
    
    local userBox = Instance.new("TextBox")
    userBox.Size = UDim2.new(0.5, -15, 0, 26)
    userBox.Position = UDim2.new(0, 10, 0, 54)
    userBox.BackgroundColor3 = XP.panel1
    userBox.BorderSizePixel = 1
    userBox.BorderColor3 = XP.borderDark
    userBox.Text = Music.user or ""
    userBox.PlaceholderText = "Last.fm Username"
    userBox.TextColor3 = XP.text
    userBox.PlaceholderColor3 = XP.textDim
    userBox.Font = Enum.Font.Gotham
    userBox.TextSize = 11
    userBox.ClearTextOnFocus = false
    userBox.Parent = card
    
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(0.5, -15, 0, 26)
    keyBox.Position = UDim2.new(0.5, 5, 0, 54)
    keyBox.BackgroundColor3 = XP.panel1
    keyBox.BorderSizePixel = 1
    keyBox.BorderColor3 = XP.borderDark
    keyBox.Text = Music.apiKey or ""
    keyBox.PlaceholderText = "API Key"
    keyBox.TextColor3 = XP.text
    keyBox.PlaceholderColor3 = XP.textDim
    keyBox.Font = Enum.Font.Gotham
    keyBox.TextSize = 11
    keyBox.ClearTextOnFocus = false
    keyBox.Parent = card
    
    local connectBtn = ActionBtn(card, "Connect", 10, 86, 180, XP.accent, function()
        if Music.user and Music.apiKey and Music.user ~= "" and Music.apiKey ~= "" then
            ctx.Core.ShowNotification("Last.fm: Connecting...")
            -- Polling will start automatically
        else
            ctx.Core.ShowNotification("Please enter username and API key")
        end
    end)
    
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -20, 0, 16)
    statusLbl.Position = UDim2.new(0, 10, 0, 120)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = Music.statusText or "Not connected"
    statusLbl.TextColor3 = XP.textDim
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 11
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = card
    
    -- Spotify Section
    Divider(card, 142)
    
    local spTitle = Instance.new("TextLabel")
    spTitle.Size = UDim2.new(1, -20, 0, 18)
    spTitle.Position = UDim2.new(0, 10, 0, 148)
    spTitle.BackgroundTransparency = 1
    spTitle.Text = "Spotify"
    spTitle.TextColor3 = Color3.fromRGB(30, 200, 80)
    spTitle.Font = Enum.Font.GothamBold
    spTitle.TextSize = 12
    spTitle.TextXAlignment = Enum.TextXAlignment.Left
    spTitle.Parent = card
    
    local clientIdBox = Instance.new("TextBox")
    clientIdBox.Size = UDim2.new(0.5, -15, 0, 26)
    clientIdBox.Position = UDim2.new(0, 10, 0, 170)
    clientIdBox.BackgroundColor3 = XP.panel1
    clientIdBox.BorderSizePixel = 1
    clientIdBox.BorderColor3 = XP.borderDark
    clientIdBox.Text = Music.spotify.clientId or ""
    clientIdBox.PlaceholderText = "Spotify Client ID"
    clientIdBox.TextColor3 = XP.text
    clientIdBox.PlaceholderColor3 = XP.textDim
    clientIdBox.Font = Enum.Font.Gotham
    clientIdBox.TextSize = 11
    clientIdBox.ClearTextOnFocus = false
    clientIdBox.Parent = card
    
    local spotifyBtn = ActionBtn(card, "Auth", 10, 202, 180, Color3.fromRGB(30, 200, 80), function()
        if Music.spotify.clientId and Music.spotify.clientId ~= "" then
            ctx.Core.ShowNotification("Spotify: Opening auth...")
            -- Spotify auth would go here
        else
            ctx.Core.ShowNotification("Please enter Client ID")
        end
    end)
    
    return card
end

-- ==================== THEME SELECTOR ====================
local function BuildThemeCard(parent)
    local card = Card(100, 2)
    card.Parent = parent
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🎨 Theme"
    title.TextColor3 = XP.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card
    
    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(1, -20, 0, 30)
    dropdown.Position = UDim2.new(0, 10, 0, 34)
    dropdown.BackgroundColor3 = XP.panel1
    dropdown.BorderSizePixel = 1
    dropdown.BorderColor3 = XP.borderDark
    dropdown.Text = currentThemeName
    dropdown.TextColor3 = XP.text
    dropdown.Font = Enum.Font.Gotham
    dropdown.TextSize = 12
    dropdown.AutoButtonColor = false
    dropdown.Parent = card
    
    local menuOpen = false
    local menu = Instance.new("Frame")
    menu.Size = UDim2.new(1, -20, 0, 0)
    menu.Position = UDim2.new(0, 10, 0, 68)
    menu.BackgroundColor3 = XP.panel1
    menu.BorderSizePixel = 1
    menu.BorderColor3 = XP.borderDark
    menu.Visible = false
    menu.ClipsDescendants = true
    menu.Parent = card
    
    local menuLayout = Instance.new("UIListLayout")
    menuLayout.Parent = menu
    
    for themeName, _ in pairs(ThemeDefaults) do
        local opt = Instance.new("TextButton")
        opt.Size = UDim2.new(1, 0, 0, 28)
        opt.BackgroundTransparency = 1
        opt.Text = themeName
        opt.TextColor3 = themeName == currentThemeName and XP.accent or XP.text
        opt.Font = Enum.Font.Gotham
        opt.TextSize = 12
        opt.AutoButtonColor = false
        opt.Parent = menu
        
        opt.MouseButton1Click:Connect(function()
            currentThemeName = themeName
            ctx.Config.currentThemeName = themeName
            ctx.Config.XP = ThemeDefaults[themeName]
            XP = ThemeDefaults[themeName]
            dropdown.Text = themeName
            menu.Visible = false
            menuOpen = false
            ctx.Core.ShowNotification("Theme changed to " .. themeName)
            
            -- Rebuild UI if open
            if isOpen then
                ctx.UI.BuildGUI()
            end
        end)
        
        opt.MouseEnter:Connect(function()
            TweenService:Create(opt, TweenInfo.new(0.1), {BackgroundTransparency = 0.9}):Play()
        end)
        opt.MouseLeave:Connect(function()
            TweenService:Create(opt, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
        end)
    end
    
    dropdown.MouseButton1Click:Connect(function()
        menuOpen = not menuOpen
        menu.Visible = menuOpen
        if menuOpen then
            local count = 0
            for _ in pairs(ThemeDefaults) do count = count + 1 end
            menu:TweenSize(UDim2.new(1, -20, 0, count * 28), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        else
            menu:TweenSize(UDim2.new(1, -20, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        end
    end)
    
    return card
end

-- ==================== KEYBIND MANAGEMENT ====================
local keybinds = {}

-- Centralized keybind storage with validation
local keybinds = {}

local function RegisterKeybind(name, defaultKey, callback)
    if keybinds[name] then
        Utils.Warn("Keybind conflict for", name, "- overwriting")
        return
    end
    if not Enum.KeyCode[defaultKey] then
        Utils.Error("Invalid default key for", name, "- using KEY_NONE")
        defaultKey = Enum.KeyCode.None
    end
    keybinds[name] = { key = defaultKey, callback = callback }
    return keybinds[name]
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    for _, kb in pairs(keybinds) do
        if input.KeyCode == kb.key then
            kb.callback()
        end
    end
end)

-- ==================== MAIN GUI BUILDER ====================
local function BuildGUI()
    -- Clean up existing
    if gui then
        gui:Destroy()
    end
    
    gui = Instance.new("ScreenGui")
    gui.Name = "UniMenu"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10
    gui.Parent = PlayerGui
    
    -- Main frame
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 520, 0, 380)
    main.Position = UDim2.new(0.5, -260, 0.5, -190)
    main.BackgroundColor3 = XP.bg
    main.BorderSizePixel = 1
    main.BorderColor3 = XP.borderLight
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = XP.sidebar1
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "UniMenu v10.0"
    title.TextColor3 = XP.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -30, 0, 2)
    closeBtn.BackgroundColor3 = XP.error
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        isOpen = false
        gui:Destroy()
    end)
    
    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 120, 1, -32)
    sidebar.Position = UDim2.new(0, 0, 0, 32)
    sidebar.BackgroundColor3 = XP.sidebar1
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    
    local tabs = {"Movement", "Combat", "Visuals", "Music", "Settings"}
    local tabButtons = {}
    
    for i, tabName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 36)
        btn.Position = UDim2.new(0, 5, 0, 10 + (i - 1) * 42)
        btn.BackgroundColor3 = tabName == currentTab and XP.tabActive or XP.tabInactive
        btn.BorderSizePixel = 0
        btn.Text = tabName
        btn.TextColor3 = tabName == currentTab and XP.tabActiveText or XP.tabInactiveText
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = false
        btn.Parent = sidebar
        
        btn.MouseButton1Click:Connect(function()
            currentTab = tabName
            -- Update tab visuals
            for name, b in pairs(tabButtons) do
                b.BackgroundColor3 = name == currentTab and XP.tabActive or XP.tabInactive
                b.TextColor3 = name == currentTab and XP.tabActiveText or XP.tabInactiveText
            end
            BuildContent()
        end)
        
        tabButtons[tabName] = btn
    end
    
    -- Content area
    local contentContainer = Instance.new("Frame")
    contentContainer.Size = UDim2.new(1, -120, 1, -42)
    contentContainer.Position = UDim2.new(0, 120, 0, 42)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = main
    contentContainerRef = contentContainer
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "ContentScroll"
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = XP.accent
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = contentContainer
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    
    local leftCol = Instance.new("Frame")
    leftCol.Name = "LeftColumn"
    leftCol.Size = UDim2.new(0.5, -4, 0, 0)
    leftCol.BackgroundTransparency = 1
    leftCol.Parent = scroll
    
    local leftLayout = Instance.new("UIListLayout")
    leftLayout.Padding = UDim.new(0, 8)
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Parent = leftCol
    
    local rightCol = Instance.new("Frame")
    rightCol.Name = "RightColumn"
    rightCol.Size = UDim2.new(0.5, -4, 0, 0)
    rightCol.BackgroundTransparency = 1
    rightCol.Parent = scroll
    
    local rightLayout = Instance.new("UIListLayout")
    rightLayout.Padding = UDim.new(0, 8)
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Parent = rightCol
    
    -- Auto canvas size
    local function UpdateCanvas()
        local maxHeight = math.max(
            leftLayout.AbsoluteContentSize.Y,
            rightLayout.AbsoluteContentSize.Y
        )
        scroll.CanvasSize = UDim2.new(0, 0, 0, maxHeight + 20)
    end
    
    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
    rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
    
    BuildContent()
end

local function BuildContent()
    if not contentContainerRef then return end
    local scroll = contentContainerRef:FindFirstChild("ContentScroll")
    if not scroll then return end
    
    local leftCol = scroll:FindFirstChild("LeftColumn")
    local rightCol = scroll:FindFirstChild("RightColumn")
    if not leftCol or not rightCol then return end
    
    -- Clear existing
    for _, child in ipairs(leftCol:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(rightCol:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    if currentTab == "Movement" then
        -- Movement features
        ToggleBtn(leftCol, "fly", 10, 10, "Fly", S.fly)
        Slider(leftCol, "speed", 10, 50, 16, 100, S.speed, " studs/s")
        Slider(leftCol, "jumpPower", 10, 90, 50, 200, S.jumpPower, " power")
        ToggleBtn(leftCol, "infJump", 10, 130, "Infinite Jump", S.infJump)
        ToggleBtn(leftCol, "noclip", 10, 170, "Noclip", S.noclip)
        
        -- Combat features
        ToggleBtn(rightCol, "triggerbot", 10, 10, "Triggerbot", S.triggerbot)
        
    elseif currentTab == "Combat" then
        ToggleBtn(leftCol, "triggerbot", 10, 10, "Triggerbot", S.triggerbot)
        Slider(leftCol, "triggerDelay", 10, 50, 0, 500, 0, " ms")
        
    elseif currentTab == "Visuals" then
        ToggleBtn(leftCol, "esp", 10, 10, "ESP", S.esp)
        ToggleBtn(leftCol, "fullbright", 10, 50, "Fullbright", S.fullbright)
        ToggleBtn(leftCol, "showPeerIcon", 10, 90, "Show Script Users", S.showPeerIcon)
        
    elseif currentTab == "Music" then
        BuildMusicCard(leftCol)
        BuildThemeCard(rightCol)
        
    elseif currentTab == "Settings" then
        BuildThemeCard(leftCol)
        
        -- Keybind editor
        local kbCard = Card(200, 2)
        kbCard.Parent = rightCol
        
        local kbTitle = Instance.new("TextLabel")
        kbTitle.Size = UDim2.new(1, -20, 0, 20)
        kbTitle.Position = UDim2.new(0, 10, 0, 8)
        kbTitle.BackgroundTransparency = 1
        kbTitle.Text = "⌨ Keybinds"
        kbTitle.TextColor3 = XP.text
        kbTitle.Font = Enum.Font.GothamBold
        kbTitle.TextSize = 14
        kbTitle.TextXAlignment = Enum.TextXAlignment.Left
        kbTitle.Parent = kbCard
        
        -- Keybind list would go here
        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -20, 1, -38)
        info.Position = UDim2.new(0, 10, 0, 38)
        info.BackgroundTransparency = 1
        info.Text = "Keybind editor coming soon..."
        info.TextColor3 = XP.textDim
        info.Font = Enum.Font.Gotham
        info.TextSize = 12
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextYAlignment = Enum.TextYAlignment.Top
        info.TextWrapped = true
        info.Parent = kbCard
    end
end

-- ==================== REGISTER DEFAULT KEYBINDS ====================
RegisterKeybind("ToggleMenu", Enum.KeyCode.RightBracket, function()
    isOpen = not isOpen
    if isOpen then
        BuildGUI()
    elseif gui then
        gui:Destroy()
    end
end)

RegisterKeybind("ToggleFly", Enum.KeyCode.F, function()
    local newState = not S.fly
    S.fly = newState
    if ctx.Core and ctx.Core.TrackConnection then
        -- Fly implementation would go here
    end
    ctx.Core.ShowNotification("Fly " .. (newState and "ON" or "OFF"))
end)

-- ==================== EXPORTS ====================
ctx.UI = {
    BuildGUI = BuildGUI,
    BuildContent = BuildContent,
    RegisterKeybindUIUpdater = RegisterKeybindUIUpdater,
    FindToggleButton = FindToggleButton,
    RegisterKeybind = RegisterKeybind,
    ToggleBtn = ToggleBtn,
    Slider = Slider,
    Card = Card,
    ActionBtn = ActionBtn,
    Lbl = Lbl,
}

return ctx.UI