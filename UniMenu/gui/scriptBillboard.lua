local function createBillboardGUI(player)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ScriptUserBillboard"
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Adornee = player.Character.HumanoidRootPart
    billboard.Parent = game.Lighting

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundTransparency = 0.6
    mainFrame.Parent = billboard

    local songTitle = Instance.new("TextLabel")
    songTitle.Name = "SongTitle"
    songTitle.BackgroundTransparency = 1
    songTitle.TextColor3 = Color3.new(1, 1, 1)
    songTitle.TextSize = 18
    songTitle.Size = UDim2.new(1, 0, 0.7, 0)
    songTitle.Position = UDim2.new(0, 0, 0.3, 0)
    songTitle.Parent = mainFrame

    local scriptIcon = Instance.new("ImageLabel")
    scriptIcon.Name = "ScriptIcon"
    scriptIcon.Size = UDim2.new(0.3, 0, 0.3, 0)
    scriptIcon.Position = UDim2.new(0.35, 0, 0.1, 0)
    scriptIcon.Image = "rbxassetid://1234567890" -- Placeholder ID
    scriptIcon.Parent = mainFrame

    return billboard, songTitle
end

return {
    createBillboardGUI = createBillboardGUI
}