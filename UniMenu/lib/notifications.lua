-- UniMenu Notification Module
-- Single notification, no stacking, auto-expires within 1 second

local ctx = ...
local TweenService = ctx.Services.TweenService

local XP = ctx.Config.XP

-- Current notification reference (only ONE at a time)
local currentNotification = nil

-- Helper to destroy a gui safely
local function DestroyGuiSafely(gui)
  if gui and gui.Parent then
    pcall(function() gui:Destroy() end)
  end
end

-- ==================== HELPER: Create Notification GUI ====================
local function CreateNotificationGui(message, notifType)
  notifType = notifType or "info"

  local notificationGui = Instance.new("ScreenGui")
  notificationGui.Name = "UniMenuNotification"
  notificationGui.ResetOnSpawn = false
  notificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  notificationGui.DisplayOrder = 2147483647
  notificationGui.IgnoreGuiInset = true
  notificationGui.Parent = game:GetService("CoreGui")

  local frame = Instance.new("Frame")
  frame.Name = "NotificationFrame"
  frame.Size = UDim2.new(0, 200, 0, 50)
  frame.Position = UDim2.new(1, -210, 1, -30)
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

-- ==================== REMOVE CURRENT NOTIFICATION (SYNC DESTROY) ====================
local function RemoveCurrentNotification()
  -- Destroy the previous GUI immediately, no fade wait (prevents stacking/leaks)
  if currentNotification then
    local gui = currentNotification.gui
    local frame = currentNotification.frame
    DestroyGuiSafely(gui)
    currentNotification = nil
  end
end

-- ==================== SHOW NOTIFICATION ====================
local function ShowNotification(message, duration, notifType)
  -- Enforce max 1 second
  duration = math.min(duration or 1.0, 1.0)
  notifType = notifType or "info"

  XP = ctx.Config.XP -- Refresh theme

  -- Destroy any existing notification FIRST (no stacking, no leftover GUI)
  RemoveCurrentNotification()

  local notificationGui, frame = CreateNotificationGui(message, notifType)

  currentNotification = {
    gui = notificationGui,
    frame = frame,
    message = message,
    type = notifType,
    createdAt = os.clock(),
    duration = duration,
  }

  -- Animate in
  local targetPos = UDim2.new(1, -220, 0, 8)
  TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
    { Position = targetPos }):Play()
  TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Linear),
    { BackgroundTransparency = 0 }):Play()

  -- Auto-expire (only the latest notification removes itself)
  task.delay(duration, function()
    if currentNotification and currentNotification.gui == notificationGui then
      DestroyGuiSafely(notificationGui)
      currentNotification = nil
    end
  end)

  return currentNotification
end

-- ==================== CLEAR ALL NOTIFICATIONS ====================
local function ClearAllNotifications()
  RemoveCurrentNotification()
end

-- ==================== EXPORTS ====================
ctx.Core.ShowNotification = ShowNotification
ctx.Core.RemoveNotification = RemoveCurrentNotification
ctx.Core.ClearAllNotifications = ClearAllNotifications
ctx.Core.NotificationQueue = {}

return {
  ShowNotification = ShowNotification,
  RemoveNotification = RemoveCurrentNotification,
  ClearAllNotifications = ClearAllNotifications,
}
