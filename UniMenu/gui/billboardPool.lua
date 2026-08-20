local pool = {}
local poolSize = 20

for i = 1, poolSize do
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ScriptUserBillboard"
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = game.Lighting
    table.insert(pool, billboard)
end

local uiManager = {
    availableGUIs = pool,
    GetGUI = function()
        return table.remove(uiManager.availableGUIs, 1)
    end,
    ReturnGUI = function(billboard)
        table.insert(uiManager.availableGUIs, billboard)
    end
}

return uiManager