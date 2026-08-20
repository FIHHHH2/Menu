local function execute(player)
    game.ReplicatedStorage.scriptUIEnabled = not game.ReplicatedStorage.scriptUIEnabled
    if not game.ReplicatedStorage.scriptUIEnabled then
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p.BillboardGUI then
                p.BillboardGUI.Parent = game.Lighting
                p.BillboardGUI = nil
            end
        end
    end
    player:SendNotification("Script UI " .. (game.ReplicatedStorage.scriptUIEnabled and "ON" or "OFF"))
end

return {
    Command = "togglescriptui",
    Execute = execute
}