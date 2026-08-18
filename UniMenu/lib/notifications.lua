-- UniMenu Notification Queue Module
-- Robust notification system with stacking, auto-expire, and guaranteed cleanup

local ctx = ...
local TweenService = ctx.Services.TweenService

local XP = ctx.Config.XP

-- Notification queue state
local notificationQueue = {}
local maxConcurrent = 3
local basePosition = UDim2.new(1, -220, 0, 8) -- Top-right anchored
local notificationHeight = 60
local notificationGap = 8

-- ==================== HELPER: Create Notification GUI ====================
local function CreateNotificationGui(message, notifType)
  notifType = notifType or "info"
  
  local notificationGui = Instance.new("ScreenGui")
  notificationGui.Name = "UniMenuNotification_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999)
  notificationGui.ResetOnSpawn = false
  notificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  notificationGui.DisplayOrder = 2147483647
  notificationGui.IgnoreGuiInset = true
  notificationGui.Parent = game:GetService("CoreGui")

  local frame = Instance.new("Frame")
  frame.Name = "NotificationFrame"
  frame.Size = UDim2.new(0, 200, 0, 50)
  frame.Position = UDim2.new(1, -210, 1, -30) -- Start off-screen
  frame.BackgroundColor3 = XP.panel1
  frame.BackgroundTransparency = 1
  frame.BorderSizePixel = 1
  frame.BorderColor3 = XP.borderDark
  frame.ZIndex = 2147483647
  frame.ClipsDescendants = true
  frame.Parent = notificationGui

  -- Type-based accent color
  local accentColor = XP.accent
  if notifType == "success" then accentColor = XP.green
  elseif notifType == "error" then accentColor = XP.red
  elseif notifType == "warning" then accentColor = Color3.fromRGB(255, 170, 0) end

  local titleBar = Instance.new("Frame")
  titleBar.Size = UDim2.new(1, 0, 0, 20)
  titleBar.BackgroundColor3 = accentColor
  titleBar.BorderSizePixel = 0
  titleBar.ZIndex = 2147483647
  titleBar.Parent = frame

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -40, 1, 0)
  title.Position = UDim2.new(0, 8, 0, 0)
  title.Text = notifType:sub(1,1):upper() .. notifType:sub(2)
  title.TextColor3 = Color3.fromRGB(255, 255, 255)
  title.BackgroundTransparency = 1
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Font = Enum.Font.GothamBold
  title.TextSize = 11
  title.ZIndex = 2147483647
  title.Parent = titleBar

  local messageLabel = Instance.new("TextLabel")
  messageLabel.Size = UDim2.new(1, -16, 1, -28)
  messageLabel.Position = UDim2.new(0, 8, 0, 24)
  messageLabel.Text = message
  messageLabel.TextColor3 = XP.text
  messageLabel.BackgroundTransparency = 1
  messageLabel.TextXAlignment = Enum.TextXAlignment.Center
  messageLabel.Font = Enum.Font.Gotham
  messageLabel.TextSize = 10
  messageLabel.TextWrapped = true
  messageLabel.ZIndex = 2147483647
  messageLabel.Parent = frame

  return notificationGui, frame
end

-- ==================== POSITION CALCULATION ====================
local function CalculatePosition(index)
  -- Stack from top down
  local yOffset = 8 + (index * (notificationHeight + notificationGap))
  return UDim2.new(1, -220, 0, yOffset)
end

local function CalculateStartPosition(index)
  return UDim2.new(1, -180, 0, 8 + (index * (notificationHeight + notificationGap)))
end

-- ==================== REPOSITION ALL NOTIFICATIONS ====================
local function RepositionNotifications()
  for i, notif in ipairs(notificationQueue) do
    if notif.gui and notif.gui.Parent and notif.frame then
      local targetPos = CalculatePosition(i - 1)
      TweenService:Create(notif.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = targetPos }):Play()
    end
  end
end

-- ==================== SHOW NOTIFICATION ====================
local function ShowNotification(message, duration, notifType)
  duration = duration or 1.0 -- Default 1 second as requested
  notifType = notifType or "info"
  
  XP = ctx.Config.XP -- Refresh theme
  
  -- Remove oldest if at max
  if #notificationQueue >= maxConcurrent then
    local oldest = table.remove(notificationQueue, 1)
    if oldest and oldest.gui and oldest.gui.Parent then
      pcall(function() oldest.gui:Destroy() end)
    end
  end
  
  -- Create new notification
  local notificationGui, frame = CreateNotificationGui(message, notifType)
  local index = #notificationQueue
  
  -- Start position (off-screen right)
  frame.Position = CalculateStartPosition(index)
  
  local notif = {
    gui = notificationGui,
    frame = frame,
    message = message,
    type = notifType,
    createdAt = os.clock(),
    duration = duration,
    index = index,
  }
  
  table.insert(notificationQueue, notif)
  
  -- Animate in
  local targetPos = CalculatePosition(index)
  TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
    { Position = targetPos }):Play()
  TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Linear),
    { BackgroundTransparency = 0 }):Play()
  
  -- Auto-expire
  task.delay(duration, function()
    RemoveNotification(notif)
  end)
  
  return notif
end

-- ==================== REMOVE NOTIFICATION ====================
local function RemoveNotification(notif)
  if not notif or not notif.gui or not notif.gui.Parent then
    -- Clean up from queue
    for i, n in ipairs(notificationQueue) do
      if n == notif then
        table.remove(notificationQueue, i)
        break
      end
    end
    RepositionNotifications()
    return
  end
  
  local frame = notif.frame
  local gui = notif.gui
  
  -- Fade out
  local fadeTween = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    { BackgroundTransparency = 1 })
  fadeTween:Play()
  
  fadeTween.Completed:Wait()
  
  -- Destroy GUI
  if gui and gui.Parent then
    pcall(function() gui:Destroy() end)
  end
  
  -- Remove from queue
  for i, n in ipairs(notificationQueue) do
    if n == notif then
      table.remove(notificationQueue, i)
      break
    end
  end
  
  -- Reposition remaining
  RepositionNotifications()
end

-- ==================== CLEAR ALL NOTIFICATIONS ====================
local function ClearAllNotifications()
  for _, notif in ipairs(notificationQueue) do
    if notif.gui and notif.gui.Parent then
      pcall(function() notif.gui:Destroy() end)
    end
  end
  notificationQueue = {}
end

-- ==================== EXPORTS ====================
ctx.Core.ShowNotification = ShowNotification
ctx.Core.RemoveNotification = RemoveNotification
ctx.Core.ClearAllNotifications = ClearAllNotifications
ctx.Core.NotificationQueue = notificationQueue

return {
  ShowNotification = ShowNotification,
  RemoveNotification = RemoveNotification,
  ClearAllNotifications = ClearAllNotifications,
}