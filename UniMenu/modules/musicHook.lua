local ctx = ...

local lastSong = ""
local lastArtist = ""

-- Heartbeat to detect music state changes
task.spawn(function()
    while task.wait(1) do  -- 1Hz check
        if ctx.State.Music.song ~= lastSong or ctx.State.Music.artist ~= lastArtist then
            lastSong = ctx.State.Music.song
            lastArtist = ctx.State.Music.artist
            
            -- Trigger peer billboard update
            if ctx.Core.BroadcastPeerData then
                ctx.Core.BroadcastPeerData()
            end
        end
    end
end)

return {}  -- No module exports needed
