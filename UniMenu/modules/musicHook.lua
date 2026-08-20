local uiManager = require(script.Parent.billboardPool)
local lastUpdate = tick()

if not _G.MusicPlayer then
    warn("MusicPlayer module not found - disabling song updates")
    return
end

_G.MusicPlayer.songChanged:Connect(function(songData)
    if not game.ReplicatedStorage.scriptUIEnabled then return end
    
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.scriptUserFlag and player.BillboardGUI then
            if tick() - lastUpdate > 1 then -- 1Hz update
                player.BillboardGUI.SongTitle.Text = songData.title
                lastUpdate = tick()
            end
        end
    end
end)