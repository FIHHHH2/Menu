# Music State Integration Plan

## Goal
Wire `musicHook` directly to `ctx.State.Music` in `core.lua` to eliminate dependency on non-existent `_G.MusicPlayer`.

## Tasks

1. **Modify `musicHook.lua`**
   - **File Path**: `A:\Potassium\Generated\UniMenu\modules\musicHook.lua`
   - **Changes**:
     ```lua
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
     ```

2. **Remove Unused Code**
   - Delete references to `_G.MusicPlayer` and `songChanged` event in `musicHook.lua`.

## Validation Steps
1. Start the script and connect to Last.fm/Spotify.
2. Play a song and verify peer billboards update with current song/artist.
3. Confirm no `_G.MusicPlayer` errors in output.
4. Check that updates occur approximately every second.

## Dependencies
- Requires `ctx.Core.BroadcastPeerData` (already implemented in `core.lua`).

## Rollout
- Replace `musicHook.lua` with the new code.
- No changes needed to `core.lua` or other modules.
