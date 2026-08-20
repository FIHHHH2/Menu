local pool = {}
local poolSize = 20

local function createPooledBillboard()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ScriptUserBillboard"
	billboard.Size = UDim2.new(0, 150, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
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

	return billboard
end

for i = 1, poolSize do
	table.insert(pool, createPooledBillboard())
end

local uiManager = {
	availableGUIs = pool,
	GetGUI = function()
		if #uiManager.availableGUIs == 0 then
			-- Auto-expand pool by creating a new billboard
			return createPooledBillboard()
		end
		return table.remove(uiManager.availableGUIs, 1)
	end,
	ReturnGUI = function(billboard)
		table.insert(uiManager.availableGUIs, billboard)
	end
}

return uiManager