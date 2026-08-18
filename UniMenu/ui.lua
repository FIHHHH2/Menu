-- UniMenu UI Module
-- BuildGUI, BuildContent, BuildHUD, themes, notifications, keybinds UI
-- Complete rewrite with scaling fixes, clipping, keybind sync, and notifications

local ctx = ...

local Players = ctx.Services.Players
local RunService = ctx.Services.RunService
local UserInputService = ctx.Services.UserInputService
local TweenService = ctx.Services.TweenService
local SoundService = ctx.Services.SoundService
local Lighting = ctx.Services.Lighting
local HttpService = ctx.Services.HttpService

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- State references
local S = ctx.State.S
local Music = ctx.State.Music
local gameConfig = ctx.Config.gameConfig
local Themes = ctx.Config.Themes
local XP = ctx.Config.XP
local currentThemeName = ctx.Config.currentThemeName

-- Theme accessor - always returns current theme
local function GetTheme()
  return ctx.Config.XP
end

-- GUI state (shared mutable references)
local gui = nil
local isOpen = false
local currentTab = "Movement"
local contentContainerRef = nil
local isTransitioning = false
local selectedPlayer = ctx.Core.selectedPlayer
local playerList = ctx.Core.playerList

-- ==================== KEYBIND UI SYNC ====================
local keybindUIUpdaters = {} -- kbName -> function(newState)

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

local function NotifyKeybindUIUpdate(kbName, newState)
  -- First try the callback approach (for current tab)
  if keybindUIUpdaters[kbName] then
    pcall(keybindUIUpdaters[kbName], newState)
  end
  -- Also search for button by name to handle tab switches
  local tabName, featName = kbName:match("(.+)::(.+)")
  if tabName and featName and tabName == currentTab then
    local btn = FindToggleButton(featName)
    if btn then
      btn.Text = newState and "ON" or "OFF"
      btn.BackgroundColor3 = newState and XP.green or Color3.fromRGB(150, 150, 150)
    end
  end
end

ctx.Core.RegisterKeybindUIUpdater = RegisterKeybindUIUpdater
ctx.Core.NotifyKeybindUIUpdate = NotifyKeybindUIUpdate

-- ==================== CLIP UTILITY ====================
local function ClampPosition(frame, parentFrame)
  local absPos = frame.AbsolutePosition
  local absSize = frame.AbsoluteSize
  local parentSize = parentFrame and parentFrame.AbsoluteSize or Vector2.new(workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y)
  
  local clampedX = math.clamp(absPos.X, 0, parentSize.X - absSize.X)
  local clampedY = math.clamp(absPos.Y, 0, parentSize.Y - absSize.Y)
  
  if absPos.X ~= clampedX or absPos.Y ~= clampedY then
    frame.Position = UDim2.new(0, clampedX, 0, clampedY)
  end
end

-- ==================== ESP SYSTEM ====================
local function GetESPFolder()
  local f = workspace:FindFirstChild("CheatMenu_ESP")
  if not f then
    f = Instance.new("Folder")
    f.Name = "CheatMenu_ESP"
    f.Parent = workspace
  end
  S.espFolder = f
  return f
end

local function ClearESP()
  if S.espFolder then S.espFolder:ClearAllChildren() end
  local existing = workspace:FindFirstChild("CheatMenu_ESP")
  if existing then existing:ClearAllChildren() end
end

local function AddESP(targetPlr)
  if targetPlr == player or (not S.esp and not (ctx.State.MM2 and ctx.State.MM2.roleESP)) then return end
  local char = targetPlr.Character
  if not char then return end

  local folder = GetESPFolder()
  local oldHL = folder:FindFirstChild(targetPlr.Name .. "_HL")
  if oldHL then oldHL:Destroy() end
  local oldBB = folder:FindFirstChild(targetPlr.Name .. "_Tag")
  if oldBB then oldBB:Destroy() end

  local fillColor = Color3.fromRGB(255, 50, 50)
  local headerColor = XP.tagHeader
  local rolePrefix = ""
  if ctx.State.MM2 and ctx.State.MM2.roleESP then
    local bp = targetPlr:FindFirstChild("Backpack")
    local hasKnife = (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
    local hasGun = (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun"))
    if hasKnife then
      fillColor = Color3.fromRGB(255, 30, 30)
      headerColor = Color3.fromRGB(210, 25, 25)
      rolePrefix = "[MURDERER] "
    elseif hasGun then
      fillColor = Color3.fromRGB(30, 140, 255)
      headerColor = Color3.fromRGB(20, 110, 225)
      rolePrefix = "[SHERIFF] "
    else
      fillColor = Color3.fromRGB(40, 215, 90)
      headerColor = Color3.fromRGB(25, 150, 65)
      rolePrefix = "[INNOCENT] "
    end
  end

  local hl = Instance.new("Highlight")
  hl.Name = targetPlr.Name .. "_HL"
  hl.FillColor = fillColor
  hl.FillTransparency = gameConfig.espFillTrans
  hl.OutlineColor = Color3.fromRGB(255, 255, 255)
  hl.OutlineTransparency = gameConfig.espOutlineTrans
  hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
  hl.Adornee = char
  hl.Parent = folder

  local head = char:FindFirstChild("Head")
  if head then
    local bb = Instance.new("BillboardGui")
    bb.Name = targetPlr.Name .. "_Tag"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 140, 0, 34)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 80
    bb.LightInfluence = 0
    bb.ClipsDescendants = false
    bb.Parent = folder

    local tagWindow = Instance.new("Frame")
    tagWindow.Name = "TagWindow"
    tagWindow.Size = UDim2.new(1, 0, 1, 0)
    tagWindow.BackgroundColor3 = XP.tagBg
    tagWindow.BackgroundTransparency = 0.35
    tagWindow.BorderSizePixel = 1
    tagWindow.BorderColor3 = XP.tagBorder
    tagWindow.Parent = bb

    local tagHeader = Instance.new("Frame")
    tagHeader.Name = "TagHeader"
    tagHeader.Size = UDim2.new(1, 0, 0, 16)
    tagHeader.BackgroundColor3 = headerColor
    tagHeader.BackgroundTransparency = 0.2
    tagHeader.BorderSizePixel = 0
    tagHeader.Parent = tagWindow

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -6, 1, 0)
    nameLabel.Position = UDim2.new(0, 3, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = rolePrefix .. targetPlr.DisplayName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = gameConfig.espTextSize
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = tagHeader

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, -6, 0, 18)
    infoLabel.Position = UDim2.new(0, 3, 0, 17)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "@" .. targetPlr.Name .. " | [0m]"
    infoLabel.TextColor3 = XP.tagText
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = math.max(gameConfig.espTextSize - 2, 8)
    infoLabel.TextTruncate = Enum.TextTruncate.AtEnd
    infoLabel.Parent = tagWindow
  end
end

local function UpdateESP()
  ClearESP()
  if not S.esp then return end
  for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then AddESP(plr) end
  end
end

local function UpdateESPTheme()
  XP = ctx.Config.XP
  if not S.espFolder then return end
  for _, tag in ipairs(S.espFolder:GetChildren()) do
    if tag:IsA("BillboardGui") and tag:FindFirstChild("TagWindow") then
      local win = tag.TagWindow
      win.BackgroundColor3 = XP.tagBg
      win.BorderColor3 = XP.tagBorder
      if win:FindFirstChild("TagHeader") then
        win.TagHeader.BackgroundColor3 = XP.tagHeader
      end
      if win:FindFirstChild("InfoLabel") then
        win.InfoLabel.TextColor3 = XP.tagText
      end
    end
  end
end

local function UpdateESPTransparency()
  if not S.espFolder then return end
  for _, child in ipairs(S.espFolder:GetChildren()) do
    if child:IsA("Highlight") then
      child.FillTransparency = gameConfig.espFillTrans
      child.OutlineTransparency = gameConfig.espOutlineTrans
    end
  end
end

local function ToggleESP(state)
  S.esp = state
  if state then UpdateESP() else ClearESP() end
end

local function UpdateChamsTransparency()
  if not S.chamsFolder then return end
  for _, child in ipairs(S.chamsFolder:GetChildren()) do
    if child:IsA("BoxHandleAdornment") then
      child.Transparency = gameConfig.chamsTrans
    end
  end
end

local function ToggleChams(state)
  S.chams = state
  if state then
    if not S.chamsFolder then
      S.chamsFolder = Instance.new("Folder")
      S.chamsFolder.Name = "CheatMenu_Chams"
      S.chamsFolder.Parent = workspace
    end
    S.chamsFolder:ClearAllChildren()
    for _, plr in ipairs(Players:GetPlayers()) do
      if plr ~= player and plr.Character then
        for _, part in ipairs(plr.Character:GetChildren()) do
          if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local bbg = Instance.new("BoxHandleAdornment")
            bbg.Name = "ChamBox"
            bbg.Adornee = part
            bbg.AlwaysOnTop = true
            bbg.ZIndex = 5
            bbg.Size = part.Size
            bbg.Color3 = Color3.fromRGB(0, 255, 200)
            bbg.Transparency = gameConfig.chamsTrans
            bbg.Parent = S.chamsFolder
          end
        end
      end
    end
  else
    if S.chamsFolder then
      S.chamsFolder:Destroy()
      S.chamsFolder = nil
    end
  end
end

local function ToggleHUD(state)
  S.hudEnabled = state
  BuildHUD()
end

ctx.UI.AddESP = AddESP
ctx.UI.UpdateESP = UpdateESP
ctx.UI.UpdateESPTheme = UpdateESPTheme
ctx.UI.UpdateESPTransparency = UpdateESPTransparency
ctx.UI.ToggleESP = ToggleESP
ctx.UI.UpdateChamsTransparency = UpdateChamsTransparency
ctx.UI.ToggleChams = ToggleChams
ctx.UI.ToggleHUD = ToggleHUD
ctx.UI.GetESPFolder = GetESPFolder
ctx.UI.ClearESP = ClearESP
ctx.UI.Animate = ctx.Core.Animate
ctx.UI.RegisterKeybindUIUpdater = RegisterKeybindUIUpdater

-- ==================== MUSIC UI UPDATE ====================
local function UpdateMusicUI()
  XP = ctx.Config.XP
  if Music.hudLabel and Music.hudLabel.Parent then
    if Music.song ~= "" then
      local prefix = Music.active and "♪ " or "⏸ "
      local txt = prefix .. Music.song
      if Music.artist ~= "" then txt = txt .. " - " .. Music.artist end
      Music.hudLabel.Text = txt
      Music.hudLabel.TextColor3 = Music.active and Color3.fromRGB(50, 255, 140) or Color3.fromRGB(240, 248, 255)
    else
      Music.hudLabel.Text = "♪ No music playing"
      Music.hudLabel.TextColor3 = Color3.fromRGB(200, 220, 245)
    end
  end
  if Music.hudCover and Music.hudCover.Parent then
    if Music.coverAsset ~= "" and not Music.coverIsProcedural then
      Music.hudCover.Image = Music.coverAsset
      Music.hudCover.Visible = true
    elseif Music.coverIsProcedural then
      Music.hudCover.Image = ""
      Music.hudCover.Visible = true
    else
      Music.hudCover.Visible = false
    end
  end
  if Music.menuSongLbl and Music.menuSongLbl.Parent then
    Music.menuSongLbl.Text = Music.song ~= "" and Music.song or "No track playing"
  end
  if Music.menuArtLbl and Music.menuArtLbl.Parent then
    Music.menuArtLbl.Text = Music.artist ~= "" and ("by " .. Music.artist) or ""
  end
  if Music.menuStatusLbl and Music.menuStatusLbl.Parent then
    Music.menuStatusLbl.Text = Music.statusText
    Music.menuStatusLbl.TextColor3 = Music.active and Color3.fromRGB(30, 215, 96) or
        (Music.song ~= "" and Color3.fromRGB(255, 200, 50) or XP.tabInactiveText)
  end
  if Music.menuCover and Music.menuCover.Parent then
    if Music.coverIsProcedural then
      Music.menuCover.Image = ""
    else
      Music.menuCover.Image = Music.coverAsset
    end
    local iconChild = Music.menuCover:FindFirstChildOfClass("TextLabel")
    if iconChild then
      iconChild.Visible = (Music.coverAsset == "")
    end
  end
  -- Update Spotify direct UI if present
  if Music.menuSpotifyStatus and Music.menuSpotifyStatus.Parent then
    Music.menuSpotifyStatus.Text = Music.spotify.connected and "Connected" or "Not Connected"
    Music.menuSpotifyStatus.TextColor3 = Music.spotify.connected and Color3.fromRGB(30, 215, 96) or XP.tabInactiveText
  end
end

ctx.UI.UpdateMusicUI = UpdateMusicUI

-- ==================== SLIDER COMPONENT ====================
local function CreateSlider(container, configKey, minVal, maxVal, isDecimal, onChange)
  local sliderTrack = Instance.new("Frame")
  sliderTrack.Size = UDim2.new(1, -12, 0, 6)
  sliderTrack.Position = UDim2.new(0, 6, 0, 18)
  sliderTrack.BackgroundColor3 = Color3.fromRGB(150, 155, 165)
  sliderTrack.BorderSizePixel = 1
  sliderTrack.BorderColor3 = XP.borderDark
  sliderTrack.ClipsDescendants = true
  sliderTrack.Parent = container

  local sliderFill = Instance.new("Frame")
  sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
  sliderFill.BackgroundColor3 = XP.accent
  sliderFill.BorderSizePixel = 0
  sliderFill.Parent = sliderTrack

  local knob = Instance.new("Frame")
  knob.Size = UDim2.new(0, 8, 0, 10)
  knob.Position = UDim2.new(0.5, -4, 0.5, -5)
  knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  knob.BorderSizePixel = 1
  knob.BorderColor3 = Color3.fromRGB(100, 100, 100)
  knob.Parent = sliderTrack

  local valLabel = Instance.new("TextLabel")
  valLabel.Size = UDim2.new(0.35, -6, 0, 14)
  valLabel.Position = UDim2.new(0.65, 0, 0, 2)
  valLabel.TextColor3 = XP.accent
  valLabel.BackgroundTransparency = 1
  valLabel.Font = Enum.Font.GothamBold
  valLabel.TextSize = 9
  valLabel.TextXAlignment = Enum.TextXAlignment.Right
  valLabel.Parent = container

  local function UpdateVisual(val)
    local pct = math.clamp((val - minVal) / (maxVal - minVal), 0, 1)
    sliderFill.Size = UDim2.new(pct, 0, 1, 0)
    knob.Position = UDim2.new(pct, -4, 0.5, -5)
    if isDecimal then
      valLabel.Text = string.format("%.2f", val)
    else
      valLabel.Text = tostring(math.floor(val + 0.5))
    end
  end

  local function GetValFromInput(input)
    local absX = input.Position.X
    local trackAbsPos = sliderTrack.AbsolutePosition.X
    local trackAbsSize = sliderTrack.AbsoluteSize.X
    local pct = math.clamp((absX - trackAbsPos) / trackAbsSize, 0, 1)
    local raw = minVal + pct * (maxVal - minVal)
    if isDecimal then
      return math.floor(raw * 100 + 0.5) / 100
    else
      return math.floor(raw + 0.5)
    end
  end

  -- Initialize with current value
  local currentVal = gameConfig[configKey] or ((minVal + maxVal) / 2)
  UpdateVisual(currentVal)

  local function StartDrag(input)
    local isDragging = true
    local connChange, connEnd
    local function ApplyInput(inp)
      if not isDragging then return end
      local val = GetValFromInput(inp)
      gameConfig[configKey] = val
      UpdateVisual(val)
      if onChange then onChange(val) end
    end
    ApplyInput(input)
    connChange = UserInputService.InputChanged:Connect(function(moveInput)
      if isDragging and moveInput.UserInputType == Enum.UserInputType.MouseMovement then
        ApplyInput(moveInput)
      end
    end)
    connEnd = UserInputService.InputEnded:Connect(function(endInput)
      if endInput.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = false
        if connChange then connChange:Disconnect(); connChange = nil end
        if connEnd then connEnd:Disconnect(); connEnd = nil end
      end
    end)
  end

  sliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then StartDrag(input) end
  end)
  knob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then StartDrag(input) end
  end)
end

ctx.UI.CreateSlider = CreateSlider

-- ==================== BUILD CONTENT ====================
local BuildContent
local BuildGUI
local BuildHUD

-- Track dropdown menus for cleanup
local activeDropdowns = {}

local function CleanupDropdowns()
  for _, dropdown in ipairs(activeDropdowns) do
    if dropdown and dropdown.Parent then
      dropdown:Destroy()
    end
  end
  activeDropdowns = {}
end

BuildContent = function(container)
  XP = ctx.Config.XP
  if not contentContainerRef then return end
  local contentScroll = contentContainerRef:FindFirstChildOfClass("ScrollingFrame")
  if not contentScroll then return end

  CleanupDropdowns()

  for _, child in ipairs(contentScroll:GetChildren()) do
    if child:IsA("Frame") or child:IsA("UIListLayout") or child:IsA("UIPadding") then
      child:Destroy()
    end
  end

  -- MUSIC TAB
  if currentTab == "Music" then
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = contentScroll

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 4)
    listPad.Parent = contentScroll

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
      contentScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 18)
    end)

    local function Card(h, order, bg)
      local c = Instance.new("Frame")
      c.Size = UDim2.new(1, 0, 0, h)
      c.BackgroundColor3 = bg or XP.panel2
      c.BorderSizePixel = 1
      c.BorderColor3 = XP.borderDark
      c.ClipsDescendants = true
      c.LayoutOrder = order
      c.Parent = contentScroll
      return c
    end

    local function Lbl(parent, txt, font, size, color, x, y, w, h, trunc)
      local l = Instance.new("TextLabel")
      l.Size = UDim2.new(w or 1, -10, 0, h or 16)
      l.Position = UDim2.new(0, x or 8, 0, y or 0)
      l.Text = txt; l.Font = font; l.TextSize = size
      l.TextColor3 = color; l.BackgroundTransparency = 1
      l.TextXAlignment = Enum.TextXAlignment.Left
      if trunc then l.TextTruncate = Enum.TextTruncate.AtEnd end
      l.Parent = parent; return l
    end

    local function ActionBtn(parent, lbl, x, y, w, clr, fn)
      local b = Instance.new("TextButton")
      b.Size = UDim2.new(0, w, 0, 26); b.Position = UDim2.new(0, x, 0, y)
      b.Text = lbl; b.Font = Enum.Font.GothamBold; b.TextSize = 10
      b.TextColor3 = Color3.fromRGB(255, 255, 255); b.BackgroundColor3 = clr
      b.BorderSizePixel = 1; b.BorderColor3 = XP.borderDark
      b.Parent = parent
      b.MouseEnter:Connect(function()
        ctx.Core.Animate(b, { BackgroundColor3 = Color3.new(
          math.min(clr.R + 0.1, 1), math.min(clr.G + 0.1, 1), math.min(clr.B + 0.1, 1)
        )}, 0.1)
      end)
      b.MouseLeave:Connect(function()
        ctx.Core.Animate(b, { BackgroundColor3 = clr }, 0.1)
      end)
      b.MouseButton1Click:Connect(function() task.spawn(fn) end)
      return b
    end

    -- Now Playing Card
    local npCard = Card(104, 1, Color3.fromRGB(12, 16, 24))
    npCard.BorderColor3 = Color3.fromRGB(30, 215, 96)

    local mCover = Instance.new("ImageLabel")
    mCover.Size = UDim2.new(0, 80, 0, 80)
    mCover.Position = UDim2.new(0, 12, 0, 12)
    mCover.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
    mCover.BorderSizePixel = 1
    mCover.BorderColor3 = Color3.fromRGB(30, 215, 96)
    mCover.ScaleType = Enum.ScaleType.Crop
    mCover.Image = Music.coverAsset
    mCover.ClipsDescendants = true
    mCover.Parent = npCard
    Music.menuCover = mCover

    local mIcon = Instance.new("TextLabel")
    mIcon.Size = UDim2.new(1, 0, 1, 0)
    mIcon.Text = "♪"
    mIcon.Font = Enum.Font.GothamBold
    mIcon.TextSize = 32
    mIcon.TextColor3 = Color3.fromRGB(40, 58, 80)
    mIcon.BackgroundTransparency = 1
    mIcon.TextXAlignment = Enum.TextXAlignment.Center
    mIcon.Visible = (Music.coverAsset == "")
    mIcon.Parent = mCover

    local TX = 104
    Lbl(npCard, "♪  Now Playing", Enum.Font.GothamBold, 11, Color3.fromRGB(30, 215, 96), TX, 10)
    local statusLbl2 = Lbl(npCard, Music.statusText, Enum.Font.Gotham, 9, XP.tabInactiveText, TX, 26, 1, 12, true)
    Music.menuStatusLbl = statusLbl2
    local songLbl2 = Lbl(npCard, Music.song ~= "" and Music.song or "No track playing",
      Enum.Font.GothamBold, 12, Color3.fromRGB(240, 248, 255), TX, 42, 1, 18, true)
    Music.menuSongLbl = songLbl2
    local artLbl2 = Lbl(npCard, Music.artist ~= "" and ("by " .. Music.artist) or "",
      Enum.Font.Gotham, 10, Color3.fromRGB(30, 215, 96), TX, 62, 1, 14, true)
    Music.menuArtLbl = artLbl2
    Lbl(npCard, Music.album ~= "" and ("💿 " .. Music.album) or "",
      Enum.Font.Gotham, 9, Color3.fromRGB(130, 160, 200), TX, 78, 1, 12, true)

    -- Source Toggle Card
    local sourceCard = Card(80, 10)
    Lbl(sourceCard, "Music Source", Enum.Font.GothamBold, 11, XP.text, 10, 8)
    
    local sourceToggle = Instance.new("TextButton")
    sourceToggle.Size = UDim2.new(0, 120, 0, 24)
    sourceToggle.Position = UDim2.new(0, 10, 0, 30)
    sourceToggle.Text = Music.useSpotifyDirect and "Spotify Direct" or "Last.fm"
    sourceToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    sourceToggle.BackgroundColor3 = Music.useSpotifyDirect and Color3.fromRGB(30, 170, 50) or XP.accent
    sourceToggle.Font = Enum.Font.GothamBold
    sourceToggle.TextSize = 10
    sourceToggle.BorderSizePixel = 1
    sourceToggle.BorderColor3 = XP.borderDark
    sourceToggle.Parent = sourceCard
    
    sourceToggle.MouseButton1Click:Connect(function()
      Music.useSpotifyDirect = not Music.useSpotifyDirect
      sourceToggle.Text = Music.useSpotifyDirect and "Spotify Direct" or "Last.fm"
      sourceToggle.BackgroundColor3 = Music.useSpotifyDirect and Color3.fromRGB(30, 170, 50) or XP.accent
      if Music.useSpotifyDirect then
        if ctx.Core.Spotify then ctx.Core.Spotify.StartPolling() end
      else
        if ctx.Core.StartLastfmPolling then ctx.Core.StartLastfmPolling() end
      end
      UpdateMusicUI()
    end)

    -- Spotify Direct Card
    if Music.useSpotifyDirect then
      local spotifyCard = Card(140, 11, Color3.fromRGB(18, 24, 18))
      spotifyCard.BorderColor3 = Color3.fromRGB(30, 200, 80)
      Lbl(spotifyCard, "⚡ Spotify Direct", Enum.Font.GothamBold, 11, Color3.fromRGB(30, 200, 80), 10, 8)
      
      local spotifyStatus = Lbl(spotifyCard, "Status: " .. (Music.spotify.connected and "Connected" or "Not Connected"),
        Enum.Font.Gotham, 9, Music.spotify.connected and Color3.fromRGB(30, 215, 96) or XP.tabInactiveText, 10, 24, 1, 12, true)
      Music.menuSpotifyStatus = spotifyStatus
      
      -- Client ID input
      Lbl(spotifyCard, "Client ID", Enum.Font.GothamBold, 9, XP.text, 10, 44)
      local clientIdBox = Instance.new("TextBox")
      clientIdBox.Size = UDim2.new(1, -20, 0, 22)
      clientIdBox.Position = UDim2.new(0, 10, 0, 56)
      clientIdBox.Text = Music.spotify.clientId or ""
      clientIdBox.PlaceholderText = "Your Spotify Client ID"
      clientIdBox.TextColor3 = XP.text
      clientIdBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 145)
      clientIdBox.BackgroundColor3 = XP.panel1
      clientIdBox.BorderSizePixel = 1; clientIdBox.BorderColor3 = XP.borderDark
      clientIdBox.Font = Enum.Font.Code; clientIdBox.TextSize = 9
      clientIdBox.TextXAlignment = Enum.TextXAlignment.Left
      clientIdBox.ClearTextOnFocus = false
      clientIdBox.ClipsDescendants = true
      clientIdBox.Parent = spotifyCard
      
      -- Connect button
      local connectBtn = Instance.new("TextButton")
      connectBtn.Size = UDim2.new(0, 80, 0, 22)
      connectBtn.Position = UDim2.new(0, 10, 0, 82)
      connectBtn.Text = "Connect"
      connectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
      connectBtn.BackgroundColor3 = Color3.fromRGB(30, 200, 80)
      connectBtn.Font = Enum.Font.GothamBold
      connectBtn.TextSize = 9
      connectBtn.BorderSizePixel = 1
      connectBtn.BorderColor3 = XP.borderDark
      connectBtn.Parent = spotifyCard
      
      connectBtn.MouseButton1Click:Connect(function()
        Music.spotify.clientId = clientIdBox.Text:gsub("%s+", "")
        if Music.spotify.clientId ~= "" and ctx.Core.Spotify then
          Music.spotify.accessToken = "" -- Force re-auth
          Music.spotify.refreshToken = ""
          Music.spotify.connected = false
          Music.spotify.expiresAt = 0
          ctx.Core.Spotify.SetConnected(true)
          ctx.Core.ShowNotification("Spotify: Starting authentication...")
          -- Show auth URL for manual copy
          local authUrl = ctx.Core.Spotify.BuildAuthUrl()
          if authUrl then
            if setclipboard then setclipboard(authUrl) end
            ctx.Core.ShowNotification("Auth URL copied to clipboard. Paste in browser.")
          end
        else
          ctx.Core.ShowNotification("Spotify: Enter a valid Client ID")
        end
      end)
      
      -- Disconnect button
      if Music.spotify.connected then
        local discBtn = Instance.new("TextButton")
        discBtn.Size = UDim2.new(0, 80, 0, 22)
        discBtn.Position = UDim2.new(0, 100, 0, 82)
        discBtn.Text = "Disconnect"
        discBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        discBtn.BackgroundColor3 = XP.red
        discBtn.Font = Enum.Font.GothamBold
        discBtn.TextSize = 9
        discBtn.BorderSizePixel = 1
        discBtn.BorderColor3 = XP.borderDark
        discBtn.Parent = spotifyCard
        
        discBtn.MouseButton1Click:Connect(function()
          if ctx.Core.Spotify then ctx.Core.Spotify.Disconnect() end
          BuildContent(container)
        end)
      end
    end

    -- Last.fm Setup Card
    local setupCard = Card(100, 20)
    Lbl(setupCard, "Last.fm Username", Enum.Font.GothamBold, 11, XP.text, 10, 8)

    local userBox = Instance.new("TextBox")
    userBox.Size = UDim2.new(1, -20, 0, 28)
    userBox.Position = UDim2.new(0, 10, 0, 28)
    userBox.Text = Music.user
    userBox.PlaceholderText = "your_lastfm_username"
    userBox.TextColor3 = XP.text
    userBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 145)
    userBox.BackgroundColor3 = XP.panel1
    userBox.BorderSizePixel = 1; userBox.BorderColor3 = XP.borderDark
    userBox.Font = Enum.Font.Code; userBox.TextSize = 11
    userBox.TextXAlignment = Enum.TextXAlignment.Left
    userBox.ClearTextOnFocus = false
    userBox.ClipsDescendants = true
    userBox.Parent = setupCard

    ActionBtn(setupCard, "⚡ Connect & Save", 10, 66, 145, Color3.fromRGB(22, 175, 76), function()
      Music.user = userBox.Text:gsub("%s+", ""):lower()
      userBox.Text = Music.user
      ctx.Core.SaveSettings()
      if ctx.Core.StartLastfmPolling then ctx.Core.StartLastfmPolling() end
      if ctx.Core.LastfmPoll then ctx.Core.LastfmPoll() end
      ctx.Core.ShowNotification("Last.fm connected: " .. Music.user)
    end)
    ActionBtn(setupCard, "↺ Refresh", 162, 66, 90, XP.accent, function()
      Music.user = userBox.Text:gsub("%s+", ""):lower()
      if ctx.Core.LastfmPoll then ctx.Core.LastfmPoll() end
    end)

    -- Peer Icon Card
    local iconCard = Card(100, 30)
    Lbl(iconCard, "Peer Icon (rbxassetid://...)", Enum.Font.GothamBold, 11, XP.text, 10, 8)
    local iconBox = Instance.new("TextBox")
    iconBox.Size = UDim2.new(1, -20, 0, 28)
    iconBox.Position = UDim2.new(0, 10, 0, 28)
    iconBox.Text = Music.peerIcon or "rbxassetid://6274377121"
    iconBox.PlaceholderText = "rbxassetid://6274377121"
    iconBox.TextColor3 = XP.text
    iconBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 145)
    iconBox.BackgroundColor3 = XP.panel1
    iconBox.BorderSizePixel = 1; iconBox.BorderColor3 = XP.borderDark
    iconBox.Font = Enum.Font.Code; iconBox.TextSize = 11
    iconBox.TextXAlignment = Enum.TextXAlignment.Left
    iconBox.ClearTextOnFocus = false
    iconBox.ClipsDescendants = true
    iconBox.Parent = iconCard

    ActionBtn(iconCard, "💾 Save Icon", 10, 66, 130, Color3.fromRGB(22, 175, 76), function()
      local raw = iconBox.Text:gsub("%s+", "")
      if raw == "" then raw = "rbxassetid://6274377121" end
      Music.peerIcon = raw
      iconBox.Text = raw
      ctx.Core.SaveSettings()
      ctx.Core.BroadcastPeerData()
    end)
    ActionBtn(iconCard, "↺ Reset", 150, 66, 100, XP.accent, function()
      iconBox.Text = "rbxassetid://6274377121"
      Music.peerIcon = "rbxassetid://6274377121"
      ctx.Core.SaveSettings()
      ctx.Core.BroadcastPeerData()
    end)

    -- Guide Card
    local guideCard = Card(112, 40)
    local steps = {
      { "♪ Link Spotify → Last.fm (free, 30 sec):", true },
      { "1. Create a free account at last.fm", false },
      { "2. Go to last.fm/settings/applications", false },
      { "3. Click Connect next to Spotify Scrobbling", false },
      { "4. Enter your username above & click Connect", false },
      { "Any Spotify track will now appear live on your HUD!", false },
    }
    for i, s in ipairs(steps) do
      Lbl(guideCard, s[1],
        s[2] and Enum.Font.GothamBold or Enum.Font.Gotham,
        s[2] and 10 or 9,
        s[2] and Color3.fromRGB(30, 215, 96) or XP.text,
        10, 4 + (i - 1) * 18, 1, 14, true)
    end

    UpdateMusicUI()
    return
  end

  -- EXPERIENCE TAB
  if currentTab == "Experience" then
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = contentScroll

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 4)
    listPad.Parent = contentScroll

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
      contentScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 18)
    end)

    local function Card(h, order, bg)
      local c = Instance.new("Frame")
      c.Size = UDim2.new(1, 0, 0, h)
      c.BackgroundColor3 = bg or XP.panel2
      c.BorderSizePixel = 1
      c.BorderColor3 = XP.borderDark
      c.ClipsDescendants = true
      c.LayoutOrder = order
      c.Parent = contentScroll
      return c
    end

    local function Lbl(parent, txt, font, size, color, x, y, w, h, trunc)
      local l = Instance.new("TextLabel")
      l.Size = UDim2.new(w or 1, -10, 0, h or 16)
      l.Position = UDim2.new(0, x or 8, 0, y or 0)
      l.Text = txt; l.Font = font; l.TextSize = size
      l.TextColor3 = color; l.BackgroundTransparency = 1
      l.TextXAlignment = Enum.TextXAlignment.Left
      if trunc then l.TextTruncate = Enum.TextTruncate.AtEnd end
      l.Parent = parent; return l
    end

    local function ActionBtn(parent, lbl, x, y, w, clr, fn)
      local b = Instance.new("TextButton")
      b.Size = UDim2.new(0, w, 0, 26); b.Position = UDim2.new(0, x, 0, y)
      b.Text = lbl; b.Font = Enum.Font.GothamBold; b.TextSize = 10
      b.TextColor3 = Color3.fromRGB(255, 255, 255); b.BackgroundColor3 = clr
      b.BorderSizePixel = 1; b.BorderColor3 = XP.borderDark
      b.Parent = parent
      b.MouseEnter:Connect(function()
        ctx.Core.Animate(b, { BackgroundColor3 = Color3.new(
          math.min(clr.R + 0.1, 1), math.min(clr.G + 0.1, 1), math.min(clr.B + 0.1, 1)
        )}, 0.1)
      end)
      b.MouseLeave:Connect(function()
        ctx.Core.Animate(b, { BackgroundColor3 = clr }, 0.1)
      end)
      b.MouseButton1Click:Connect(function() task.spawn(fn) end)
      return b
    end

    -- Experience Cover Card
    local expCoverCard = Card(180, 1, Color3.fromRGB(12, 16, 24))
    expCoverCard.BorderColor3 = XP.accent

    local expCover = Instance.new("ImageLabel")
    expCover.Size = UDim2.new(0, 140, 0, 140)
    expCover.Position = UDim2.new(0, 16, 0, 20)
    expCover.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
    expCover.BorderSizePixel = 1
    expCover.BorderColor3 = XP.accent
    expCover.ScaleType = Enum.ScaleType.Crop
    expCover.Image = ""
    expCover.ClipsDescendants = true
    expCover.Parent = expCoverCard

    local expName = Lbl(expCoverCard, "Loading...", Enum.Font.GothamBold, 15, XP.text, 168, 24, 0.65, 22, true)
    local expId = Lbl(expCoverCard, "Place ID: " .. tostring(game.PlaceId), Enum.Font.Code, 10, XP.tabInactiveText, 168, 50, 0.65, 16, true)
    local expPlayers = Lbl(expCoverCard, "Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers, Enum.Font.GothamBold, 12, XP.accent, 168, 72, 0.65, 18, true)
    local expJobId = Lbl(expCoverCard, "Job ID: " .. tostring(game.JobId):sub(1, 36) .. "...", Enum.Font.Code, 9, XP.tabInactiveText, 168, 94, 0.65, 16, true)
    local expCreator = Lbl(expCoverCard, "Creator: Loading...", Enum.Font.Gotham, 9, XP.tabInactiveText, 168, 116, 0.65, 16, true)

    -- Action buttons
    ActionBtn(expCoverCard, "🔄 Refresh", 16, 148, 110, XP.accent, function()
      RefreshExperienceInfo()
    end)
    ActionBtn(expCoverCard, "📋 Copy Place ID", 134, 148, 110, Color3.fromRGB(30, 200, 80), function()
      if setclipboard then setclipboard(tostring(game.PlaceId)) end
      ctx.Core.ShowNotification("Place ID copied to clipboard")
    end)
    ActionBtn(expCoverCard, "📋 Copy Job ID", 250, 148, 110, Color3.fromRGB(30, 200, 80), function()
      if setclipboard then setclipboard(tostring(game.JobId)) end
      ctx.Core.ShowNotification("Job ID copied to clipboard")
    end)

    -- Server Info Card
    local serverCard = Card(80, 2)
    Lbl(serverCard, "Server Information", Enum.Font.GothamBold, 12, XP.text, 10, 8)
    local serverPlayers = Lbl(serverCard, "Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers, Enum.Font.GothamBold, 11, XP.accent, 10, 28, 1, 18)
    local serverPing = Lbl(serverCard, "Ping: -- ms", Enum.Font.Code, 10, XP.tabInactiveText, 10, 48, 0.5, 16)
    local serverFps = Lbl(serverCard, "FPS: --", Enum.Font.Code, 10, XP.tabInactiveText, 10, 64, 0.5, 16)

    -- Game Info Card
    local gameCard = Card(100, 3)
    Lbl(gameCard, "Game Details", Enum.Font.GothamBold, 12, XP.text, 10, 8)
    local gameDesc = Instance.new("TextLabel")
    gameDesc.Size = UDim2.new(1, -20, 0, 70)
    gameDesc.Position = UDim2.new(0, 10, 0, 28)
    gameDesc.Text = "Loading game description..."
    gameDesc.TextColor3 = XP.text
    gameDesc.BackgroundTransparency = 1
    gameDesc.Font = Enum.Font.Gotham
    gameDesc.TextSize = 9
    gameDesc.TextXAlignment = Enum.TextXAlignment.Left
    gameDesc.TextYAlignment = Enum.TextYAlignment.Top
    gameDesc.TextWrapped = true
    gameDesc.ClipsDescendants = true
    gameDesc.Parent = gameCard

    -- Refresh experience info function
    local function RefreshExperienceInfo()
      expName.Text = "Loading..."
      expCreator.Text = "Creator: Loading..."
      gameDesc.Text = "Loading game description..."

      -- Fetch place info
      pcall(function()
        local MarketplaceService = game:GetService("MarketplaceService")
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info then
          expName.Text = info.Name or "Unknown"
          expCreator.Text = "Creator: " .. (info.Creator and info.Creator.Name or "Unknown")
          gameDesc.Text = info.Description or "No description available."
        end
      end)

      -- Fetch experience thumbnail
      pcall(function()
        local HttpService = game:GetService("HttpService")
        local url = "https://thumbnails.roblox.com/v1/places/gameicons?placeIds=" .. game.PlaceId .. "&size=512x512&format=Png&isCircular=false"
        local response = HttpService:GetAsync(url)
        local data = HttpService:JSONDecode(response)
        if data and data.data and data.data[1] and data.data[1].imageUrl then
          expCover.Image = data.data[1].imageUrl
        end
      end)

      expPlayers.Text = "Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers
      expJobId.Text = "Job ID: " .. tostring(game.JobId):sub(1, 36) .. "..."
    end

    -- Store refresh function for updates
    _G.RefreshExperienceInfo = RefreshExperienceInfo

    -- Initial refresh
    RefreshExperienceInfo()

    -- Update loop for player count, ping, FPS
    task.spawn(function()
      while currentTab == "Experience" and task.wait(2) do
        if serverPlayers then
          serverPlayers.Text = "Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers
          expPlayers.Text = "Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers
        end
        if serverPing then
          pcall(function()
            local ping = math.floor(ctx.Services.Players.LocalPlayer:GetNetworkPing() * 1000)
            serverPing.Text = "Ping: " .. ping .. " ms"
          end)
        end
        if serverFps then
          local fps = math.floor(1 / ctx.Services.RunService.Heartbeat:Wait() + 0.5)
          serverFps.Text = "FPS: " .. fps
        end
      end
    end)

    return
  end

  -- KEYBINDS TAB
  if currentTab == "Keybinds" then
    local features = ctx.Core.features
    local keybinds = ctx.Core.keybinds
    local keybindRegistry = ctx.Core.keybindRegistry

    local leftCol = Instance.new("Frame")
    leftCol.Name = "LeftColumn"
    leftCol.Size = UDim2.new(0.49, 0, 1, 0)
    leftCol.BackgroundTransparency = 1
    leftCol.BorderSizePixel = 0
    leftCol.ClipsDescendants = true
    leftCol.Parent = contentScroll

    local rightCol = Instance.new("Frame")
    rightCol.Name = "RightColumn"
    rightCol.Size = UDim2.new(0.49, 0, 1, 0)
    rightCol.Position = UDim2.new(0.51, 0, 0, 0)
    rightCol.BackgroundTransparency = 1
    rightCol.BorderSizePixel = 0
    rightCol.ClipsDescendants = true
    rightCol.Parent = contentScroll

    local leftLayout = Instance.new("UIListLayout")
    leftLayout.FillDirection = Enum.FillDirection.Vertical
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Padding = UDim.new(0, 6)
    leftLayout.Parent = leftCol

    local rightLayout = Instance.new("UIListLayout")
    rightLayout.FillDirection = Enum.FillDirection.Vertical
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Padding = UDim.new(0, 6)
    rightLayout.Parent = rightCol

    local function UpdateCanvas()
      local maxH = math.max(leftLayout.AbsoluteContentSize.Y, rightLayout.AbsoluteContentSize.Y)
      contentScroll.CanvasSize = UDim2.new(0, 0, 0, maxH + 16)
    end
    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
    rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)

    local grouped = {}
    for tabName, tabFeats in pairs(features) do
      local sectionName = "General"
      local toggles = {}
      for _, feat in ipairs(tabFeats) do
        if feat.isSection then sectionName = feat.name end
        if feat.isToggle and feat.toggle then
          table.insert(toggles, { section = sectionName, feat = feat })
        end
      end
      if #toggles > 0 then grouped[tabName] = toggles end
    end

    local sortedTabs = {}
    for tabName, _ in pairs(grouped) do table.insert(sortedTabs, tabName) end
    table.sort(sortedTabs)

    local function getKbName(tabName, featName)
      return tabName .. "::" .. featName
    end

    for tabName, toggles in pairs(grouped) do
      for _, entry in ipairs(toggles) do
        local kbName = getKbName(tabName, entry.feat.name)
        if not keybindRegistry[kbName] then
          keybindRegistry[kbName] = {
            get = entry.feat.get,
            toggle = entry.feat.toggle,
            tab = tabName,
            featName = entry.feat.name,
          }
        end
      end
    end
    ctx.Core.RebuildKeybindMap()

    local function keyCodeName(kc)
      if not kc then return "None" end
      local n = tostring(kc.Name or kc)
      if n:match("^Enum.KeyCode%.") then n = n:sub(17) end
      return n
    end

    local layoutOrder = 0
    local function makeKeybindRow(entry, tabName, parentCard)
      local kbName = getKbName(tabName, entry.feat.name)
      local row = Instance.new("Frame")
      row.Name = "KbRow_" .. entry.feat.name
      row.Size = UDim2.new(1, 0, 0, 32)
      row.BackgroundColor3 = XP.rowBg
      row.BackgroundTransparency = 0.35
      row.BorderSizePixel = 0
      row.LayoutOrder = layoutOrder
      layoutOrder = layoutOrder + 1
      row.ClipsDescendants = true
      row.Parent = parentCard

      local nameLbl = Instance.new("TextLabel")
      nameLbl.Size = UDim2.new(1, -120, 1, 0)
      nameLbl.Position = UDim2.new(0, 10, 0, 0)
      nameLbl.Text = entry.feat.name
      nameLbl.TextColor3 = XP.text
      nameLbl.BackgroundTransparency = 1
      nameLbl.Font = Enum.Font.Gotham
      nameLbl.TextSize = 10
      nameLbl.TextXAlignment = Enum.TextXAlignment.Left
      nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
      nameLbl.Parent = row

      local keyLbl = Instance.new("TextLabel")
      keyLbl.Name = "KeyLabel"
      keyLbl.Size = UDim2.new(0, 70, 0, 20)
      keyLbl.Position = UDim2.new(1, -102, 0.5, -10)
      keyLbl.Text = keyCodeName(keybinds[kbName])
      keyLbl.TextColor3 = keybinds[kbName] and XP.accent or Color3.fromRGB(150, 150, 150)
      keyLbl.BackgroundColor3 = XP.panel1
      keyLbl.BackgroundTransparency = 0.2
      keyLbl.BorderSizePixel = 1
      keyLbl.BorderColor3 = XP.borderDark
      keyLbl.Font = Enum.Font.Code
      keyLbl.TextSize = 9
      keyLbl.TextXAlignment = Enum.TextXAlignment.Center
      keyLbl.Parent = row

      local setBtn = Instance.new("TextButton")
      setBtn.Size = UDim2.new(0, 36, 0, 20)
      setBtn.Position = UDim2.new(1, -36, 0.5, -10)
      setBtn.Text = "Set"
      setBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
      setBtn.BackgroundColor3 = XP.titleBar
      setBtn.BorderSizePixel = 1
      setBtn.BorderColor3 = XP.borderDark
      setBtn.Font = Enum.Font.GothamBold
      setBtn.TextSize = 8
      setBtn.ClipsDescendants = true
      setBtn.Parent = row

      local setGrad = Instance.new("UIGradient")
      setGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
        ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
      })
      setGrad.Parent = setBtn

      local clrBtn = Instance.new("TextButton")
      clrBtn.Size = UDim2.new(0, 36, 0, 20)
      clrBtn.Position = UDim2.new(1, -74, 0.5, -10)
      clrBtn.Text = "Clr"
      clrBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
      clrBtn.BackgroundColor3 = Color3.fromRGB(140, 45, 45)
      clrBtn.BorderSizePixel = 1
      clrBtn.BorderColor3 = XP.borderDark
      clrBtn.Font = Enum.Font.GothamBold
      clrBtn.TextSize = 8
      clrBtn.ClipsDescendants = true
      clrBtn.Parent = row

      clrBtn.MouseButton1Click:Connect(function()
        keybinds[kbName] = nil
        keyLbl.Text = "None"
        keyLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        ctx.Core.RebuildKeybindMap()
        ctx.Core.SaveKeybinds()
        if ctx.UI and ctx.UI.UpdateKeybindOverlay then ctx.UI.UpdateKeybindOverlay() end
        ctx.Core.ShowNotification("Keybind cleared: " .. entry.feat.name)
      end)

      setBtn.MouseButton1Click:Connect(function()
        setBtn.Text = "[..]"
        local capturing = true
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
          if not capturing then return end
          capturing = false
          if conn then conn:Disconnect() end
          if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode ~= Enum.KeyCode.Escape then
            if keybinds[kbName] then ctx.Core.activeKeybindMap[keybinds[kbName]] = nil end
            keybinds[kbName] = input.KeyCode
            keyLbl.Text = keyCodeName(input.KeyCode)
            keyLbl.TextColor3 = XP.accent
            ctx.Core.RebuildKeybindMap()
            ctx.Core.SaveKeybinds()
            if ctx.UI and ctx.UI.UpdateKeybindOverlay then ctx.UI.UpdateKeybindOverlay() end
            ctx.Core.ShowNotification("Keybind set: " .. entry.feat.name .. " → " .. keyCodeName(input.KeyCode))
          end
          setBtn.Text = "Set"
        end)
        task.delay(3, function()
          if capturing then
            capturing = false
            if conn then conn:Disconnect() end
            setBtn.Text = "Set"
          end
        end)
      end)

      -- Register UI updater for this keybind
      RegisterKeybindUIUpdater(kbName, function(newState)
        -- This keybind row doesn't have a toggle button, but if the feature
        -- has a UI button elsewhere, it would update via that mechanism
      end)
    end

    -- Build keybind rows
    local colIndex = 0
    for _, tabName in ipairs(sortedTabs) do
      local toggles = grouped[tabName]
      local targetCol = (colIndex % 2 == 0) and leftCol or rightCol
      colIndex = colIndex + 1

      local card = Instance.new("Frame")
      card.Name = "KbCard_" .. tabName
      card.Size = UDim2.new(1, 0, 0, 0)
      card.BackgroundColor3 = XP.panel2
      card.BackgroundTransparency = 0.05
      card.BorderSizePixel = 1
      card.BorderColor3 = XP.borderDark
      card.ClipsDescendants = true
      card.Parent = targetCol

      local cardLayout = Instance.new("UIListLayout")
      cardLayout.FillDirection = Enum.FillDirection.Vertical
      cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
      cardLayout.Padding = UDim.new(0, 2)
      cardLayout.Parent = card

      local cardHead = Instance.new("Frame")
      cardHead.Size = UDim2.new(1, 0, 0, 20)
      cardHead.BackgroundColor3 = XP.titleBar
      cardHead.BorderSizePixel = 0
      cardHead.LayoutOrder = 0
      cardHead.Parent = card

      local chGrad = Instance.new("UIGradient")
      chGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
        ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
      })
      chGrad.Parent = cardHead

      local chLabel = Instance.new("TextLabel")
      chLabel.Size = UDim2.new(1, -8, 1, 0)
      chLabel.Position = UDim2.new(0, 6, 0, 0)
      chLabel.Text = string.upper(tabName)
      chLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
      chLabel.BackgroundTransparency = 1
      chLabel.TextXAlignment = Enum.TextXAlignment.Left
      chLabel.Font = Enum.Font.GothamBold
      chLabel.TextSize = 8
      chLabel.Parent = cardHead

      for _, entry in ipairs(toggles) do
        makeKeybindRow(entry, tabName, card)
      end

      cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 4)
      end)
      card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 4)
    end
    return
  end

  -- TROLLING TAB - TARGET PLAYER SELECTION
  if currentTab == "Trolling" then
    local dropCard = Instance.new("Frame")
    dropCard.Size = UDim2.new(1, 0, 0, 56)
    dropCard.BackgroundColor3 = XP.panel2
    dropCard.BorderSizePixel = 1
    dropCard.BorderColor3 = XP.borderDark
    dropCard.LayoutOrder = 0
    dropCard.ZIndex = 5
    dropCard.ClipsDescendants = true
    dropCard.Parent = contentScroll

    local dropHead = Instance.new("Frame")
    dropHead.Size = UDim2.new(1, 0, 0, 20)
    dropHead.BackgroundColor3 = XP.titleBar
    dropHead.BorderSizePixel = 0
    dropHead.ZIndex = 6
    dropHead.Parent = dropCard

    local dropHeadGrad = Instance.new("UIGradient")
    dropHeadGrad.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
      ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
    })
    dropHeadGrad.Parent = dropHead

    local dropLabel = Instance.new("TextLabel")
    dropLabel.Size = UDim2.new(1, -8, 1, 0)
    dropLabel.Position = UDim2.new(0, 6, 0, 0)
    dropLabel.Text = "TARGET PLAYER SELECTION"
    dropLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropLabel.BackgroundTransparency = 1
    dropLabel.TextXAlignment = Enum.TextXAlignment.Left
    dropLabel.Font = Enum.Font.GothamBold
    dropLabel.TextSize = 8
    dropLabel.ZIndex = 6
    dropLabel.Parent = dropHead

    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(1, -12, 0, 24)
    dropdown.Position = UDim2.new(0, 6, 0, 24)
    dropdown.Text = selectedPlayer and (selectedPlayer.DisplayName .. " (@" .. selectedPlayer.Name .. ")") or
        "Select Target Player..."
    dropdown.TextColor3 = XP.text
    dropdown.BackgroundColor3 = XP.panel1
    dropdown.BackgroundTransparency = 0
    dropdown.BorderSizePixel = 1
    dropdown.BorderColor3 = XP.borderDark
    dropdown.Font = Enum.Font.Gotham
    dropdown.TextSize = 10
    dropdown.TextXAlignment = Enum.TextXAlignment.Left
    dropdown.ZIndex = 6
    dropdown.ClipsDescendants = true
    dropdown.Parent = dropCard

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 16, 1, 0)
    arrow.Position = UDim2.new(1, -18, 0, 0)
    arrow.Text = "v"
    arrow.TextColor3 = XP.text
    arrow.BackgroundTransparency = 1
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 9
    arrow.ZIndex = 6
    arrow.Parent = dropdown

    local dropdownOpen = false
    local dropdownMenu = nil

    dropdown.MouseButton1Click:Connect(function()
      dropdownOpen = not dropdownOpen
      if dropdownOpen then
        if dropdownMenu then dropdownMenu:Destroy() end
        dropdownMenu = Instance.new("Frame")
        dropdownMenu.Size = UDim2.new(0, dropdown.AbsoluteSize.X, 0, math.min(#playerList * 22 + 4, 140))
        dropdownMenu.BackgroundColor3 = XP.panel1
        dropdownMenu.BackgroundTransparency = 0
        dropdownMenu.BorderSizePixel = 1
        dropdownMenu.BorderColor3 = XP.accent
        dropdownMenu.ZIndex = 200
        dropdownMenu.ClipsDescendants = true
        
        -- Position absolutely relative to the main GUI frame
        local dropdownAbsPos = dropdown.AbsolutePosition
        local frameAbsPos = frame.AbsolutePosition
        dropdownMenu.Position = UDim2.new(0, dropdownAbsPos.X - frameAbsPos.X, 0, dropdownAbsPos.Y - frameAbsPos.Y + dropdown.AbsoluteSize.Y + 2)
        dropdownMenu.Parent = frame -- Parent to main frame to avoid clipping
        table.insert(activeDropdowns, dropdownMenu)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -4, 1, -4)
        scroll.Position = UDim2.new(0, 2, 0, 2)
        scroll.BackgroundTransparency = 1
        scroll.ScrollBarThickness = 0
        scroll.CanvasSize = UDim2.new(0, 0, 0, #playerList * 22)
        scroll.ZIndex = 101
        scroll.ClipsDescendants = true
        scroll.Parent = dropdownMenu

        local scrollLayout = Instance.new("UIListLayout")
        scrollLayout.Padding = UDim.new(0, 1)
        scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
        scrollLayout.Parent = scroll

        for idx, plr in ipairs(playerList) do
          local opt = Instance.new("TextButton")
          opt.Size = UDim2.new(1, 0, 0, 20)
          opt.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
          opt.TextColor3 = XP.text
          opt.BackgroundColor3 = XP.panel2
          opt.BackgroundTransparency = 0
          opt.BorderSizePixel = 0
          opt.Font = Enum.Font.Gotham
          opt.TextSize = 9
          opt.TextXAlignment = Enum.TextXAlignment.Left
          opt.LayoutOrder = idx
          opt.ZIndex = 102
          opt.ClipsDescendants = true
          opt.Parent = scroll

          opt.MouseEnter:Connect(function()
            ctx.Core.Animate(opt, { BackgroundColor3 = XP.accent, TextColor3 = Color3.fromRGB(255, 255, 255) }, 0.1)
          end)
          opt.MouseLeave:Connect(function()
            ctx.Core.Animate(opt, { BackgroundColor3 = XP.panel2, TextColor3 = XP.text }, 0.1)
          end)
          opt.MouseButton1Click:Connect(function()
            selectedPlayer = plr
            ctx.Core.selectedPlayer = plr
            dropdown.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
            dropdownOpen = false
            if dropdownMenu then
              dropdownMenu:Destroy(); dropdownMenu = nil
            end
          end)
        end
      else
        if dropdownMenu then
          dropdownMenu:Destroy(); dropdownMenu = nil
        end
      end
    end)
  end

  -- DEFAULT: Render feature sections (for tabs without custom UI)
  -- Create left/right column containers for quadrant layout
  local leftCol = Instance.new("Frame")
  leftCol.Name = "LeftColumn"
  leftCol.Size = UDim2.new(0.49, 0, 1, 0)
  leftCol.BackgroundTransparency = 1
  leftCol.BorderSizePixel = 0
  leftCol.ClipsDescendants = true
  leftCol.Parent = contentScroll

  local rightCol = Instance.new("Frame")
  rightCol.Name = "RightColumn"
  rightCol.Size = UDim2.new(0.49, 0, 1, 0)
  rightCol.Position = UDim2.new(0.51, 0, 0, 0)
  rightCol.BackgroundTransparency = 1
  rightCol.BorderSizePixel = 0
  rightCol.ClipsDescendants = true
  rightCol.Parent = contentScroll

  local leftLayout = Instance.new("UIListLayout")
  leftLayout.FillDirection = Enum.FillDirection.Vertical
  leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
  leftLayout.Padding = UDim.new(0, 6)
  leftLayout.Parent = leftCol

  local rightLayout = Instance.new("UIListLayout")
  rightLayout.FillDirection = Enum.FillDirection.Vertical
  rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
  rightLayout.Padding = UDim.new(0, 6)
  rightLayout.Parent = rightCol

  local function UpdateCanvas()
    local maxH = math.max(leftLayout.AbsoluteContentSize.Y, rightLayout.AbsoluteContentSize.Y)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, maxH + 16)
  end
  leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
  rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)

  -- DEFAULT: Render feature sections
  local features = ctx.Core.features
  local tabFeatures = features[currentTab] or {}
  local sections = {}
  local currentSec = { name = "General", items = {} }
  table.insert(sections, currentSec)
  for _, feat in ipairs(tabFeatures) do
    if feat.isSection then
      currentSec = { name = feat.name, items = {} }
      table.insert(sections, currentSec)
    else
      table.insert(currentSec.items, feat)
    end
  end

  local validSections = {}
  for _, s in ipairs(sections) do
    if #s.items > 0 then table.insert(validSections, s) end
  end

  for secIdx, sec in ipairs(validSections) do
    local targetCol = (secIdx % 2 == 1) and leftCol or rightCol
    local card = Instance.new("Frame")
    card.Name = "Quadrant_" .. secIdx
    card.Size = UDim2.new(1, 0, 0, 0)
    card.BackgroundColor3 = XP.panel2
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 1
    card.BorderColor3 = XP.borderDark
    card.LayoutOrder = secIdx
    card.ClipsDescendants = true
    card.Parent = targetCol

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.FillDirection = Enum.FillDirection.Vertical
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Padding = UDim.new(0, 2)
    cardLayout.Parent = card

    local cardHead = Instance.new("Frame")
    cardHead.Size = UDim2.new(1, 0, 0, 20)
    cardHead.BackgroundColor3 = XP.titleBar
    cardHead.BorderSizePixel = 0
    cardHead.LayoutOrder = 0
    cardHead.Parent = card

    local chGrad = Instance.new("UIGradient")
    chGrad.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
      ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
    })
    chGrad.Parent = cardHead

    local chLabel = Instance.new("TextLabel")
    chLabel.Size = UDim2.new(1, -8, 1, 0)
    chLabel.Position = UDim2.new(0, 6, 0, 0)
    chLabel.Text = string.upper(sec.name)
    chLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    chLabel.BackgroundTransparency = 1
    chLabel.TextXAlignment = Enum.TextXAlignment.Left
    chLabel.Font = Enum.Font.GothamBold
    chLabel.TextSize = 8
    chLabel.Parent = cardHead

    for itemIdx, feat in ipairs(sec.items) do
      if feat.hasSlider then
        local sRow = Instance.new("Frame")
        sRow.Size = UDim2.new(1, 0, 0, 28)
        sRow.BackgroundColor3 = XP.rowBg
        sRow.BackgroundTransparency = 0.4
        sRow.BorderSizePixel = 0
        sRow.LayoutOrder = itemIdx
        sRow.ClipsDescendants = true
        sRow.Parent = card

        local sLbl = Instance.new("TextLabel")
        sLbl.Size = UDim2.new(0.65, -6, 0, 14)
        sLbl.Position = UDim2.new(0, 6, 0, 1)
        sLbl.Text = feat.name
        sLbl.TextColor3 = XP.text
        sLbl.BackgroundTransparency = 1
        sLbl.Font = Enum.Font.GothamBold
        sLbl.TextSize = 9
        sLbl.TextXAlignment = Enum.TextXAlignment.Left
        sLbl.TextTruncate = Enum.TextTruncate.AtEnd
        sLbl.Parent = sRow

        CreateSlider(sRow, feat.configKey, feat.min, feat.max, feat.isDecimal, function(val)
          if feat.onChange then feat.onChange(val) end
        end)
      else
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundColor3 = XP.rowBg
        row.BackgroundTransparency = 0.4
        row.BorderSizePixel = 0
        row.LayoutOrder = itemIdx
        row.ClipsDescendants = true
        row.Parent = card

        local rLbl = Instance.new("TextLabel")
        rLbl.Size = UDim2.new(1, -54, 1, 0)
        rLbl.Position = UDim2.new(0, 6, 0, 0)
        rLbl.Text = feat.name
        rLbl.TextColor3 = XP.text
        rLbl.BackgroundTransparency = 1
        rLbl.Font = Enum.Font.GothamBold
        rLbl.TextSize = 9
        rLbl.TextXAlignment = Enum.TextXAlignment.Left
        rLbl.TextTruncate = Enum.TextTruncate.AtEnd
        rLbl.Parent = row

        if feat.isToggle then
          local tBtn = Instance.new("TextButton")
          tBtn.Name = "Toggle_" .. feat.name
          tBtn.Size = UDim2.new(0, 42, 0, 16)
          tBtn.Position = UDim2.new(1, -48, 0.5, -8)
          local activeState = feat.get and feat.get() or false
          tBtn.Text = activeState and "ON" or "OFF"
          tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
          tBtn.BackgroundColor3 = activeState and XP.green or Color3.fromRGB(150, 150, 150)
          tBtn.BorderSizePixel = 1
          tBtn.BorderColor3 = XP.borderDark
          tBtn.Font = Enum.Font.GothamBold
          tBtn.TextSize = 8
          tBtn.ClipsDescendants = true
          tBtn.Parent = row

          tBtn.MouseButton1Click:Connect(function()
            local newState = not (feat.get and feat.get() or false)
            tBtn.Text = newState and "ON" or "OFF"
            tBtn.BackgroundColor3 = newState and XP.green or Color3.fromRGB(150, 150, 150)
            if feat.toggle then feat.toggle(newState) end
            ctx.Core.ShowNotification(feat.name .. " " .. (newState and "enabled" or "disabled"))
          end)

          -- Register keybind UI sync
          local kbName = currentTab .. "::" .. feat.name
          RegisterKeybindUIUpdater(kbName, function(newState)
            tBtn.Text = newState and "ON" or "OFF"
            tBtn.BackgroundColor3 = newState and XP.green or Color3.fromRGB(150, 150, 150)
          end)

        elseif feat.isButton then
          local bBtn = Instance.new("TextButton")
          bBtn.Size = UDim2.new(0, 42, 0, 16)
          bBtn.Position = UDim2.new(1, -48, 0.5, -8)
          bBtn.Text = feat.buttonText or "RUN"
          bBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
          bBtn.BackgroundColor3 = XP.accent
          bBtn.BorderSizePixel = 1
          bBtn.BorderColor3 = XP.borderDark
          bBtn.Font = Enum.Font.GothamBold
          bBtn.TextSize = 8
          bBtn.ClipsDescendants = true
          bBtn.Parent = row

          bBtn.MouseButton1Click:Connect(function()
            if feat.condition and not feat.condition() then return end
            if feat.action then feat.action() end
          end)

        elseif feat.isCyclePart then
          local partOptions = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" }
          local currentPart = S.aimbotTargetPart or "Head"
          local currentIndex = table.find(partOptions, currentPart) or 1

          local leftBtn = Instance.new("TextButton")
          leftBtn.Size = UDim2.new(0, 20, 0, 16)
          leftBtn.Position = UDim2.new(1, -100, 0.5, -8)
          leftBtn.Text = "<"
          leftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
          leftBtn.BackgroundColor3 = XP.accent
          leftBtn.BorderSizePixel = 1
          leftBtn.BorderColor3 = XP.borderDark
          leftBtn.Font = Enum.Font.GothamBold
          leftBtn.TextSize = 8
          leftBtn.ClipsDescendants = true
          leftBtn.Parent = row

          local partLabel = Instance.new("TextLabel")
          partLabel.Size = UDim2.new(0, 60, 0, 16)
          partLabel.Position = UDim2.new(1, -80, 0.5, -8)
          partLabel.Text = currentPart
          partLabel.TextColor3 = XP.text
          partLabel.BackgroundTransparency = 1
          partLabel.Font = Enum.Font.GothamBold
          partLabel.TextSize = 8
          partLabel.TextXAlignment = Enum.TextXAlignment.Center
          partLabel.Parent = row

          local rightBtn = Instance.new("TextButton")
          rightBtn.Size = UDim2.new(0, 20, 0, 16)
          rightBtn.Position = UDim2.new(1, -20, 0.5, -8)
          rightBtn.Text = ">"
          rightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
          rightBtn.BackgroundColor3 = XP.accent
          rightBtn.BorderSizePixel = 1
          rightBtn.BorderColor3 = XP.borderDark
          rightBtn.Font = Enum.Font.GothamBold
          rightBtn.TextSize = 8
          rightBtn.ClipsDescendants = true
          rightBtn.Parent = row

          local function updatePartLabel()
            currentPart = S.aimbotTargetPart or "Head"
            partLabel.Text = currentPart
          end
          leftBtn.MouseButton1Click:Connect(function()
            currentIndex = currentIndex - 1
            if currentIndex < 1 then currentIndex = #partOptions end
            S.aimbotTargetPart = partOptions[currentIndex]
            updatePartLabel()
          end)
          rightBtn.MouseButton1Click:Connect(function()
            currentIndex = currentIndex + 1
            if currentIndex > #partOptions then currentIndex = 1 end
            S.aimbotTargetPart = partOptions[currentIndex]
            updatePartLabel()
          end)
        end
      end
    end

    cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
      card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 4)
    end)
    card.Size = UDim2.new(1, 0, 0, cardLayout.AbsoluteContentSize.Y + 4)
  end
end

ctx.UI.BuildContent = BuildContent

-- GUI toggle function
local function ToggleGUI()
  isOpen = not isOpen
  if isOpen then
    BuildGUI()
  else
    CleanupDropdowns()
    if gui then
      gui:Destroy(); gui = nil
    end
  end
end
ctx.UI.ToggleGUI = ToggleGUI

-- ==================== BUILD MAIN GUI ====================
BuildGUI = function()
  XP = ctx.Config.XP

  for _, g in ipairs(PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name == "CheatMenu" then g:Destroy() end
  end

  gui = Instance.new("ScreenGui")
  gui.Name = "CheatMenu"
  gui.ResetOnSpawn = false
  gui.Parent = PlayerGui
  gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

  local frame = Instance.new("Frame")
  frame.Name = "MainFrame"
  frame.Size = UDim2.new(0, 640, 0, 520)
  frame.Position = UDim2.new(0.5, -320, 0.5, -260)
  frame.BackgroundColor3 = XP.windowBg
  frame.BackgroundTransparency = 0.15
  frame.BorderSizePixel = 1
  frame.BorderColor3 = XP.borderLight
  frame.ClipsDescendants = true
  frame.Parent = gui

  local uiScale = Instance.new("UIScale")
  uiScale.Scale = 1
  uiScale.Parent = frame

  local winGrad = Instance.new("UIGradient")
  winGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.windowBgLight),
    ColorSequenceKeypoint.new(0.4, XP.windowBg),
    ColorSequenceKeypoint.new(1, XP.windowBgDark)
  })
  winGrad.Rotation = 90
  winGrad.Parent = frame

  local innerBorder = Instance.new("Frame")
  innerBorder.Size = UDim2.new(1, -4, 1, -4)
  innerBorder.Position = UDim2.new(0, 2, 0, 2)
  innerBorder.BackgroundTransparency = 1
  innerBorder.BorderSizePixel = 1
  innerBorder.BorderColor3 = Color3.fromRGB(168, 194, 223)
  innerBorder.Parent = frame

  local titleBar = Instance.new("Frame")
  titleBar.Name = "TitleBar"
  titleBar.Size = UDim2.new(1, 0, 0, 32)
  titleBar.BackgroundColor3 = XP.titleBar
  titleBar.BackgroundTransparency = 0.1
  titleBar.BorderSizePixel = 0
  titleBar.ZIndex = 10
  titleBar.Parent = frame

  local tbGrad = Instance.new("UIGradient")
  tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
    ColorSequenceKeypoint.new(0.5, XP.titleBarGrad2),
    ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
  })
  tbGrad.Rotation = 90
  tbGrad.Parent = titleBar

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(0.7, 0, 1, 0)
  title.Position = UDim2.new(0, 10, 0, 0)
  title.Text = "Universal Cheat Panel v11 • [" .. currentThemeName .. "]"
  title.TextColor3 = Color3.fromRGB(255, 255, 255)
  title.BackgroundTransparency = 1
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Font = Enum.Font.GothamBold
  title.TextSize = 12
  title.ZIndex = 11
  title.Parent = titleBar

  local closeBtn = Instance.new("TextButton")
  closeBtn.Size = UDim2.new(0, 22, 0, 22)
  closeBtn.Position = UDim2.new(1, -30, 0.5, -11)
  closeBtn.Text = "X"
  closeBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
  closeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  closeBtn.BackgroundTransparency = 0.9
  closeBtn.BorderSizePixel = 1
  closeBtn.BorderColor3 = Color3.fromRGB(160, 160, 160)
  closeBtn.Font = Enum.Font.GothamBold
  closeBtn.TextSize = 11
  closeBtn.ZIndex = 11
  closeBtn.Parent = titleBar

  closeBtn.MouseEnter:Connect(function()
    ctx.Core.Animate(closeBtn, { BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(200, 50, 50) }, 0.1)
  end)
  closeBtn.MouseLeave:Connect(function()
    ctx.Core.Animate(closeBtn, { BackgroundTransparency = 0.9, BackgroundColor3 = Color3.fromRGB(255, 255, 255) }, 0.1)
  end)
  closeBtn.MouseButton1Click:Connect(function()
    CleanupDropdowns()
    gui:Destroy(); gui = nil; isOpen = false
  end)

  local sidebar = Instance.new("Frame")
  sidebar.Name = "Sidebar"
  sidebar.Size = UDim2.new(0, 125, 1, -32)
  sidebar.Position = UDim2.new(0, 0, 0, 32)
  sidebar.BackgroundColor3 = XP.sidebar1
  sidebar.BackgroundTransparency = 0
  sidebar.BorderSizePixel = 0
  sidebar.ClipsDescendants = true
  sidebar.Parent = frame

  local sideGrad = Instance.new("UIGradient")
  sideGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.sidebar1),
    ColorSequenceKeypoint.new(1, XP.sidebar2)
  })
  sideGrad.Rotation = 90
  sideGrad.Parent = sidebar

  local sidebarLayout = Instance.new("UIListLayout")
  sidebarLayout.FillDirection = Enum.FillDirection.Vertical
  sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
  sidebarLayout.Padding = UDim.new(0, 3)
  sidebarLayout.Parent = sidebar

  local sidebarPadding = Instance.new("UIPadding")
  sidebarPadding.PaddingTop = UDim.new(0, 4)
  sidebarPadding.PaddingLeft = UDim.new(0, 4)
  sidebarPadding.PaddingRight = UDim.new(0, 4)
  sidebarPadding.Parent = sidebar

  local sidebarItems = {
    { isHeader = true, name = "MAIN GAMEPLAY" },
    { tab = "Combat" },
    { tab = "Movement" },
    { tab = "Visuals" },
    { isHeader = true, name = "GAME & EXPLOITS" },
    { tab = "MM2" },
    { tab = "Trolling" },
    { isHeader = true, name = "SYSTEM & UTILS" },
    { tab = "Server" },
    { tab = "Themes" },
    { tab = "Config" },
    { tab = "HUD" },
    { tab = "Keybinds" },
    { tab = "Music" },
    { tab = "Experience" }
  }
  local tabButtons = {}

  for i, item in ipairs(sidebarItems) do
    if item.isHeader then
      local groupH = i == 1 and 18 or 24
      local divContainer = Instance.new("Frame")
      divContainer.Size = UDim2.new(1, 0, 0, groupH)
      divContainer.BackgroundTransparency = 1
      divContainer.BorderSizePixel = 0
      divContainer.LayoutOrder = i
      divContainer.Parent = sidebar
      if i > 1 then
        local divLine = Instance.new("Frame")
        divLine.Size = UDim2.new(1, 4, 0, 1)
        divLine.Position = UDim2.new(0, -4, 0, 3)
        divLine.BackgroundColor3 = XP.borderDark
        divLine.BackgroundTransparency = 0.3
        divLine.BorderSizePixel = 0
        divLine.Parent = divContainer
      end
      local accentRail = Instance.new("Frame")
      accentRail.Size = UDim2.new(0, 3, 1, 0)
      accentRail.Position = UDim2.new(0, -4, 0, 0)
      accentRail.BackgroundColor3 = XP.accent
      accentRail.BackgroundTransparency = 0.25
      accentRail.BorderSizePixel = 0
      accentRail.Parent = divContainer
      local divLabel = Instance.new("TextLabel")
      divLabel.Size = UDim2.new(1, -6, 1, 0)
      divLabel.Position = UDim2.new(0, 4, 0, i == 1 and 3 or 8)
      divLabel.Text = item.name
      divLabel.TextColor3 = XP.accent
      divLabel.BackgroundTransparency = 1
      divLabel.TextXAlignment = Enum.TextXAlignment.Left
      divLabel.Font = Enum.Font.GothamBold
      divLabel.TextSize = 7
      divLabel.Parent = divContainer
    else
      local tabName = item.tab
      local isSelected = (tabName == currentTab)
      local btn = Instance.new("TextButton")
      btn.Size = UDim2.new(1, 0, 0, 25)
      btn.Text = "  " .. tabName
      btn.TextColor3 = isSelected and XP.tabActiveText or XP.tabInactiveText
      btn.BackgroundColor3 = isSelected and XP.tabActive or XP.tabInactive
      btn.BackgroundTransparency = isSelected and 0 or 0.2
      btn.BorderSizePixel = 1
      btn.BorderColor3 = isSelected and XP.accent or XP.borderDark
      btn.Font = Enum.Font.GothamBold
      btn.TextSize = 10
      btn.TextXAlignment = Enum.TextXAlignment.Left
      btn.LayoutOrder = i
      btn.ClipsDescendants = true
      btn.Parent = sidebar
      tabButtons[tabName] = btn

      local activeBar = Instance.new("Frame")
      activeBar.Name = "ActiveBar"
      activeBar.Size = UDim2.new(0, 4, 1, 0)
      activeBar.Position = UDim2.new(0, 0, 0, 0)
      activeBar.BackgroundColor3 = XP.accent
      activeBar.BorderSizePixel = 0
      activeBar.Visible = isSelected
      activeBar.Parent = btn

      btn.MouseEnter:Connect(function()
        if currentTab ~= tabName then
          ctx.Core.Animate(btn, { BackgroundTransparency = 0.05, BackgroundColor3 = Color3.fromRGB(245, 240, 230) }, 0.1)
        end
      end)
      btn.MouseLeave:Connect(function()
        if currentTab ~= tabName then
          ctx.Core.Animate(btn, { BackgroundTransparency = 0.2, BackgroundColor3 = XP.tabInactive }, 0.1)
        end
      end)
      btn.MouseButton1Click:Connect(function()
        if tabName == currentTab or isTransitioning then return end
        isTransitioning = true
        CleanupDropdowns()
        for name, b in pairs(tabButtons) do
          local sel = (name == tabName)
          b.TextColor3 = sel and XP.tabActiveText or XP.tabInactiveText
          b.BackgroundColor3 = sel and XP.tabActive or XP.tabInactive
          b.BackgroundTransparency = sel and 0 or 0.2
          b.BorderColor3 = sel and XP.accent or XP.borderDark
          local ab = b:FindFirstChild("ActiveBar")
          if ab then ab.Visible = sel end
        end
        currentTab = tabName
        ctx.Core.currentTab = tabName
        BuildContent(contentContainerRef)
        isTransitioning = false
      end)
    end
  end

  local contentPanel = Instance.new("Frame")
  contentPanel.Name = "ContentPanel"
  contentPanel.Size = UDim2.new(1, -135, 1, -40)
  contentPanel.Position = UDim2.new(0, 130, 0, 36)
  contentPanel.BackgroundColor3 = XP.panel1
  contentPanel.BackgroundTransparency = 0.2
  contentPanel.BorderSizePixel = 1
  contentPanel.BorderColor3 = XP.borderDark
  contentPanel.ClipsDescendants = true
  contentPanel.Parent = frame

  local cGrad = Instance.new("UIGradient")
  cGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.panel1),
    ColorSequenceKeypoint.new(1, XP.panel2)
  })
  cGrad.Rotation = 90
  cGrad.Parent = contentPanel

  contentContainerRef = Instance.new("Frame")
  contentContainerRef.Size = UDim2.new(1, -8, 1, -8)
  contentContainerRef.Position = UDim2.new(0, 4, 0, 4)
  contentContainerRef.BackgroundTransparency = 1
  contentContainerRef.BorderSizePixel = 0
  contentContainerRef.ClipsDescendants = true
  contentContainerRef.Parent = contentPanel

  local contentScroll = Instance.new("ScrollingFrame")
  contentScroll.Name = "ContentScroll"
  contentScroll.Size = UDim2.new(1, 0, 1, 0)
  contentScroll.BackgroundTransparency = 1
  contentScroll.ScrollBarThickness = 4
  contentScroll.ScrollBarImageColor3 = XP.accent
  contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
  contentScroll.ClipsDescendants = true
  contentScroll.Parent = contentContainerRef

  local layout = Instance.new("UIListLayout")
  layout.Padding = UDim.new(0, 4)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = contentScroll

  BuildContent(contentContainerRef)

  -- DRAG with bounds checking
  local dragging, dragStart, startPos
  titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = true
      dragStart = input.Position
      startPos = frame.Position
      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then dragging = false end
      end)
    end
  end)
  titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
      local delta = input.Position - dragStart
      local newX = startPos.X.Offset + delta.X
      local newY = startPos.Y.Offset + delta.Y
      -- Clamp to viewport
      local viewportSize = workspace.CurrentCamera.ViewportSize
      local frameSize = frame.AbsoluteSize
      newX = math.clamp(newX, -startPos.X.Scale * viewportSize.X, viewportSize.X - frameSize.X + (1 - startPos.X.Scale) * viewportSize.X)
      newY = math.clamp(newY, -startPos.Y.Scale * viewportSize.Y + 32, viewportSize.Y - frameSize.Y + (1 - startPos.Y.Scale) * viewportSize.Y)
      frame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    end
  end)

  -- RESIZE handle
  local resizeHandle = Instance.new("TextButton")
  resizeHandle.Name = "ResizeHandle"
  resizeHandle.Size = UDim2.new(0, 18, 0, 18)
  resizeHandle.Position = UDim2.new(1, -18, 1, -18)
  resizeHandle.BackgroundTransparency = 1
  resizeHandle.Text = "///"
  resizeHandle.TextColor3 = XP.borderDark
  resizeHandle.Font = Enum.Font.GothamBold
  resizeHandle.TextSize = 10
  resizeHandle.ZIndex = 50
  resizeHandle.Parent = frame

  local resizing, resizeStartPos, startSize
  resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      resizing = true
      resizeStartPos = input.Position
      startSize = frame.AbsoluteSize
      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then resizing = false end
      end)
    end
  end)
  UserInputService.InputChanged:Connect(function(input)
    if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
      local delta = input.Position - resizeStartPos
      local newWidth = math.clamp(startSize.X + delta.X, 420, 900)
      local newHeight = math.clamp(startSize.Y + delta.Y, 380, 800)
      frame.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
  end)
end

ctx.UI.BuildGUI = BuildGUI

-- ==================== HUD CONNECTIONS TRACKING ====================
local HUDConnections = {}

local function TrackHUDConnection(conn)
  table.insert(HUDConnections, conn)
  return conn
end

local function CleanupHUD()
  for _, conn in ipairs(HUDConnections) do
    pcall(function() conn:Disconnect() end)
  end
  HUDConnections = {}
end

-- ==================== BUILD HUD ====================
BuildHUD = function()
  XP = ctx.Config.XP
  CleanupHUD()
  for _, g in ipairs(PlayerGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name == "CheatHUD" then g:Destroy() end
  end
  if not S.hudEnabled then return end

  local hudGui = Instance.new("ScreenGui")
  hudGui.Name = "CheatHUD"
  hudGui.ResetOnSpawn = false
  hudGui.DisplayOrder = 999999
  hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  hudGui.Parent = PlayerGui

  local frame = Instance.new("Frame")
  frame.Name = "HUDFrame"
  frame.Size = UDim2.new(0, 350, 0, 145)
  frame.Position = UDim2.new(0, 8, 1, -153)
  frame.BackgroundColor3 = XP.windowBg
  frame.BackgroundTransparency = 0.12
  frame.BorderSizePixel = 0
  frame.ClipsDescendants = true
  frame.Parent = hudGui

  local grad = Instance.new("UIGradient")
  grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.windowBgLight),
    ColorSequenceKeypoint.new(0.5, XP.windowBg),
    ColorSequenceKeypoint.new(1, XP.windowBgDark)
  })
  grad.Rotation = 90; grad.Parent = frame

  local stripe = Instance.new("Frame")
  stripe.Size = UDim2.new(0, 3, 1, 0); stripe.BackgroundColor3 = XP.accent
  stripe.BorderSizePixel = 0; stripe.Parent = frame

  local titleBar = Instance.new("Frame")
  titleBar.Size = UDim2.new(1, 0, 0, 24); titleBar.BackgroundColor3 = XP.titleBar
  titleBar.BackgroundTransparency = 0.2; titleBar.BorderSizePixel = 0
  titleBar.Parent = frame

  local tbGrad = Instance.new("UIGradient")
  tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
    ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
  })
  tbGrad.Rotation = 90; tbGrad.Parent = titleBar

  local hudTitle = Instance.new("TextLabel")
  hudTitle.Size = UDim2.new(0.6, -8, 1, 0); hudTitle.Position = UDim2.new(0, 8, 0, 0)
  hudTitle.Text = player.DisplayName .. " (@" .. player.Name .. ")"
  hudTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
  hudTitle.BackgroundTransparency = 1; hudTitle.Font = Enum.Font.GothamBold
  hudTitle.TextSize = 10; hudTitle.TextXAlignment = Enum.TextXAlignment.Left
  hudTitle.TextTruncate = Enum.TextTruncate.AtEnd
  hudTitle.Parent = titleBar

  local hudFpsPing = Instance.new("TextLabel")
  hudFpsPing.Size = UDim2.new(0.4, -8, 1, 0); hudFpsPing.Position = UDim2.new(0.6, 0, 0, 0)
  hudFpsPing.Text = "FPS: -- | Ping: --ms"
  hudFpsPing.TextColor3 = Color3.fromRGB(50, 255, 140)
  hudFpsPing.BackgroundTransparency = 1; hudFpsPing.Font = Enum.Font.Code
  hudFpsPing.TextSize = 9; hudFpsPing.TextXAlignment = Enum.TextXAlignment.Right
  hudFpsPing.Parent = titleBar

  local content = Instance.new("Frame")
  content.Size = UDim2.new(1, -8, 1, -30); content.Position = UDim2.new(0, 4, 0, 26)
  content.BackgroundTransparency = 1; content.ClipsDescendants = true
  content.Parent = frame

  local contentLayout = Instance.new("UIListLayout")
  contentLayout.FillDirection = Enum.FillDirection.Vertical
  contentLayout.Padding = UDim.new(0, 3)
  contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
  contentLayout.Parent = content

  -- Music display
  local musicFrame = Instance.new("Frame")
  musicFrame.Size = UDim2.new(1, 0, 0, 56)
  musicFrame.BackgroundColor3 = XP.panel2
  musicFrame.BackgroundTransparency = 0.3
  musicFrame.BorderSizePixel = 0
  musicFrame.ClipsDescendants = true
  musicFrame.LayoutOrder = 1
  musicFrame.Parent = content

  local musicCover = Instance.new("ImageLabel")
  musicCover.Size = UDim2.new(0, 52, 0, 52)
  musicCover.Position = UDim2.new(0, 2, 0, 2)
  musicCover.BackgroundColor3 = XP.panel1
  musicCover.BorderSizePixel = 0
  musicCover.ScaleType = Enum.ScaleType.Crop
  musicCover.ClipsDescendants = true
  musicCover.Parent = musicFrame
  Music.hudCover = musicCover

  local musicCoverCorner = Instance.new("UICorner")
  musicCoverCorner.CornerRadius = UDim.new(0, 4)
  musicCoverCorner.Parent = musicCover

  local musicText = Instance.new("TextLabel")
  musicText.Size = UDim2.new(1, -60, 0, 20)
  musicText.Position = UDim2.new(0, 58, 0, 4)
  musicText.Text = "♪ No music playing"
  musicText.TextColor3 = Color3.fromRGB(200, 220, 245)
  musicText.BackgroundTransparency = 1
  musicText.Font = Enum.Font.GothamBold
  musicText.TextSize = 11
  musicText.TextXAlignment = Enum.TextXAlignment.Left
  musicText.TextTruncate = Enum.TextTruncate.AtEnd
  musicText.Parent = musicFrame
  Music.hudLabel = musicText

  local musicSubtext = Instance.new("TextLabel")
  musicSubtext.Size = UDim2.new(1, -60, 0, 18)
  musicSubtext.Position = UDim2.new(0, 58, 0, 24)
  musicSubtext.Text = Music.artist ~= "" and ("by " .. Music.artist) or ""
  musicSubtext.TextColor3 = Color3.fromRGB(130, 160, 200)
  musicSubtext.BackgroundTransparency = 1
  musicSubtext.Font = Enum.Font.Gotham
  musicSubtext.TextSize = 9
  musicSubtext.TextXAlignment = Enum.TextXAlignment.Left
  musicSubtext.TextTruncate = Enum.TextTruncate.AtEnd
  musicSubtext.Parent = musicFrame
  Music.hudArtistLabel = musicSubtext

  -- Info lines
  local function InfoLine(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -4, 0, 14)
    lbl.Text = text
    lbl.TextColor3 = XP.tabInactiveText
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order
    lbl.ClipsDescendants = true
    lbl.Parent = content
    return lbl
  end

  -- Place Info
  local placeFrame = Instance.new("Frame")
  placeFrame.Size = UDim2.new(1, 0, 0, 52)
  placeFrame.BackgroundColor3 = XP.panel2
  placeFrame.BackgroundTransparency = 0.3
  placeFrame.BorderSizePixel = 0
  placeFrame.LayoutOrder = 2
  placeFrame.ClipsDescendants = true
  placeFrame.Parent = content

  local placeName = Instance.new("TextLabel")
  placeName.Size = UDim2.new(1, -8, 0, 14)
  placeName.Position = UDim2.new(0, 4, 0, 0)
  placeName.Text = "Place: " .. (game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "Unknown")
  placeName.TextColor3 = XP.text
  placeName.BackgroundTransparency = 1
  placeName.Font = Enum.Font.Gotham
  placeName.TextSize = 9
  placeName.TextXAlignment = Enum.TextXAlignment.Left
  placeName.TextTruncate = Enum.TextTruncate.AtEnd
  placeName.Parent = placeFrame

  local placeId = Instance.new("TextLabel")
  placeId.Size = UDim2.new(1, -8, 0, 14)
  placeId.Position = UDim2.new(0, 4, 0, 14)
  placeId.Text = "Place ID: " .. tostring(game.PlaceId)
  placeId.TextColor3 = XP.tabInactiveText
  placeId.BackgroundTransparency = 1
  placeId.Font = Enum.Font.Code
  placeId.TextSize = 8
  placeId.TextXAlignment = Enum.TextXAlignment.Left
  placeId.Parent = placeFrame

  local jobId = Instance.new("TextLabel")
  jobId.Size = UDim2.new(1, -8, 0, 14)
  jobId.Position = UDim2.new(0, 4, 0, 28)
  jobId.Text = "Job ID: " .. tostring(game.JobId):sub(1, 36) .. "..."
  jobId.TextColor3 = XP.tabInactiveText
  jobId.BackgroundTransparency = 1
  jobId.Font = Enum.Font.Code
  jobId.TextSize = 8
  jobId.TextXAlignment = Enum.TextXAlignment.Left
  jobId.Parent = placeFrame

  local playersCount = Instance.new("TextLabel")
  playersCount.Size = UDim2.new(1, -8, 0, 14)
  playersCount.Position = UDim2.new(0, 4, 0, 42)
  playersCount.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
  playersCount.TextColor3 = XP.accent
  playersCount.BackgroundTransparency = 1
  playersCount.Font = Enum.Font.GothamBold
  playersCount.TextSize = 9
  playersCount.TextXAlignment = Enum.TextXAlignment.Left
  playersCount.Parent = placeFrame

  -- Update music UI
  if Music.hudCover and Music.hudCover.Parent then
    if Music.coverAsset ~= "" and not Music.coverIsProcedural then
      Music.hudCover.Image = Music.coverAsset
    end
  end
  if Music.song ~= "" then
    local prefix = Music.active and "♪ " or "⏸ "
    Music.hudLabel.Text = prefix .. Music.song .. (Music.artist ~= "" and (" - " .. Music.artist) or "")
    Music.hudLabel.TextColor3 = Music.active and Color3.fromRGB(50, 255, 140) or Color3.fromRGB(240, 248, 255)
  end

  -- HUD update loop
  local lastUpdate = 0
  TrackHUDConnection(RunService.Heartbeat:Connect(function(dt)
    lastUpdate = lastUpdate + dt
    if lastUpdate < 0.25 then return end
    lastUpdate = 0

    -- FPS
    local fps = math.floor(1 / dt + 0.5)
    local fpsColor = ctx.Core.GetFPSColor(fps)
    local pingText = ""
    pcall(function()
      local ping = math.floor(player:GetNetworkPing() * 1000)
      pingText = " | Ping: " .. ping .. "ms"
    end)
    hudFpsPing.Text = "FPS: " .. fps .. pingText
    hudFpsPing.TextColor3 = fpsColor

    -- Players (update in placeFrame)
    if playersCount then
      playersCount.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
    end
  end))
end

ctx.UI.BuildHUD = BuildHUD

-- ==================== KEYBIND OVERLAY ====================
local keybindOverlayRef = nil
local keybindOverlayDragging = false
local keybindOverlayDragStart = nil
local keybindOverlayStartPos = nil

local function CreateKeybindOverlay()
  if keybindOverlayRef and keybindOverlayRef.Parent then
    keybindOverlayRef:Destroy()
  end

  local overlayGui = Instance.new("ScreenGui")
  overlayGui.Name = "KeybindOverlay"
  overlayGui.ResetOnSpawn = false
  overlayGui.DisplayOrder = 999998
  overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  overlayGui.Parent = PlayerGui

  local frame = Instance.new("Frame")
  frame.Name = "OverlayFrame"
  frame.Size = UDim2.new(0, 250, 0, 30)
  frame.Position = UDim2.new(1, -258, 1, -38)
  frame.BackgroundColor3 = XP.windowBg
  frame.BackgroundTransparency = 0.15
  frame.BorderSizePixel = 1
  frame.BorderColor3 = XP.accent
  frame.ClipsDescendants = true
  frame.Parent = overlayGui
  frame.Active = true

  local grad = Instance.new("UIGradient")
  grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.windowBgLight),
    ColorSequenceKeypoint.new(0.5, XP.windowBg),
    ColorSequenceKeypoint.new(1, XP.windowBgDark)
  })
  grad.Rotation = 90; grad.Parent = frame

  local titleBar = Instance.new("Frame")
  titleBar.Size = UDim2.new(1, 0, 0, 22)
  titleBar.BackgroundColor3 = XP.titleBar
  titleBar.BackgroundTransparency = 0.2
  titleBar.BorderSizePixel = 0
  titleBar.Parent = frame

  local tbGrad = Instance.new("UIGradient")
  tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, XP.titleBarGrad1),
    ColorSequenceKeypoint.new(1, XP.titleBarGrad3)
  })
  tbGrad.Rotation = 90; tbGrad.Parent = titleBar

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -10, 1, 0)
  title.Position = UDim2.new(0, 8, 0, 0)
  title.Text = "Active Keybinds"
  title.TextColor3 = Color3.fromRGB(255, 255, 255)
  title.BackgroundTransparency = 1
  title.Font = Enum.Font.GothamBold
  title.TextSize = 9
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Parent = titleBar

  local content = Instance.new("Frame")
  content.Size = UDim2.new(1, -8, 1, -28)
  content.Position = UDim2.new(0, 4, 0, 24)
  content.BackgroundTransparency = 1
  content.ClipsDescendants = true
  content.Parent = frame

  local layout = Instance.new("UIListLayout")
  layout.FillDirection = Enum.FillDirection.Vertical
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Padding = UDim.new(0, 2)
  layout.Parent = content

  local padding = Instance.new("UIPadding")
  padding.PaddingBottom = UDim.new(0, 4)
  padding.Parent = content

  -- Draggable
  titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      keybindOverlayDragging = true
      keybindOverlayDragStart = input.Position
      keybindOverlayStartPos = frame.Position
    end
  end)

  titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and keybindOverlayDragging then
      local delta = input.Position - keybindOverlayDragStart
      frame.Position = UDim2.new(
        keybindOverlayStartPos.X.Scale,
        keybindOverlayStartPos.X.Offset + delta.X,
        keybindOverlayStartPos.Y.Scale,
        keybindOverlayStartPos.Y.Offset + delta.Y
      )
    end
  end)

  titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      keybindOverlayDragging = false
    end
  end)

  -- Update keybinds
  local function UpdateKeybinds()
    for _, child in ipairs(content:GetChildren()) do
      if child:IsA("TextLabel") then child:Destroy() end
    end

    local keybinds = ctx.Core.keybinds
    local keybindRegistry = ctx.Core.keybindRegistry
    local rowOrder = 0

    for kbName, reg in pairs(keybindRegistry) do
      local keyCode = keybinds[kbName]
      if keyCode and reg.get then
        local isActive = reg.get()
        local displayName = reg.featName or kbName
        local keyName = ""
        if typeof(keyCode) == "EnumItem" then
          keyName = keyCode.Name
        elseif typeof(keyCode) == "string" then
          keyName = keyCode
        end
        if keyName == "" then keyName = "None" end

        rowOrder = rowOrder + 1
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Text = "[" .. keyName .. "] " .. displayName .. " - " .. (isActive and "ON" or "OFF")
        lbl.TextColor3 = isActive and Color3.fromRGB(50, 255, 140) or XP.tabInactiveText
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 9
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = rowOrder
        lbl.Parent = content
      end
    end

    -- Resize frame based on content
    frame.Size = UDim2.new(0, 250, 0, math.max(30, 28 + rowOrder * 18))
  end

  UpdateKeybinds()

  -- Store update function
  keybindOverlayRef = overlayGui
  overlayGui.UpdateKeybinds = UpdateKeybinds

  return overlayGui
end

local function ToggleKeybindOverlay(state)
  if state then
    CreateKeybindOverlay()
  else
    if keybindOverlayRef and keybindOverlayRef.Parent then
      keybindOverlayRef:Destroy()
      keybindOverlayRef = nil
    end
  end
end

ctx.UI.ToggleKeybindOverlay = ToggleKeybindOverlay

-- Update keybind overlay when keybinds change
local function UpdateKeybindOverlay()
  if keybindOverlayRef and keybindOverlayRef.Parent then
    if keybindOverlayRef.UpdateKeybinds then
      keybindOverlayRef.UpdateKeybinds()
    end
  end
end

ctx.UI.UpdateKeybindOverlay = UpdateKeybindOverlay

-- ==================== APPLY THEME (LIVE UPDATE) ====================
local function ApplyTheme()
  XP = ctx.Config.XP
  -- Rebuild GUI if open to apply theme changes
  if isOpen and gui and gui.Parent then
    BuildGUI()
  end
  -- Rebuild HUD
  BuildHUD()
  -- Update ESP
  if ctx.UI.UpdateESPTheme then ctx.UI.UpdateESPTheme() end
end

ctx.UI.ApplyTheme = ApplyTheme

-- ==================== ANIMATE ====================
ctx.UI.Animate = ctx.Core.Animate

return ctx.UI