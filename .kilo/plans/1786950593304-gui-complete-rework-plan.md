# UniMenu Complete GUI Rework Plan

## Overview
Complete overhaul of the GUI system addressing scaling, clipping, keybind sync, notifications, Last.fm/Spotify integration, and general UI stability.

---

## Issues to Address

### 1. Scaling & Layout Issues
- **Problem**: Fixed pixel sizes don't scale on different resolutions
- **Root cause**: Hardcoded `UDim2.new(0, 640, 0, 520)` etc. without responsive constraints
- **Solution**: Use `UIScale`, relative sizing, and `UIAspectRatioConstraint`

### 2. Drag Clipping
- **Problem**: Child elements clip outside window when dragging
- **Root cause**: No `ClipsDescendants = true` on main frame; drag uses Position instead of proper bounds
- **Solution**: Enable clipping, add drag bounds checking

### 3. Keybind ↔ UI Button Sync
- **Problem**: Toggling via keybind doesn't update UI button state
- **Root cause**: Keybind listener calls `feat.toggle()` but doesn't refresh UI
- **Solution**: Add callback registry to notify UI of state changes; rebuild affected rows

### 4. Notification Expiration
- **Problem**: Notifications don't auto-expire after 1 second
- **Root cause**: `task.delay(0.75, ...)` exists but cleanup is unreliable; `RemoveNotification` not always called
- **Solution**: Robust timer with guaranteed cleanup; queue system for multiple notifications

### 5. Last.fm System Issues
- **Problem**: Song cover/names don't update when track changes/ends
- **Root causes**:
  - Polling doesn't detect track end properly
  - `Music.active` detection unreliable
  - Cover download race conditions
  - No fallback when API fails
- **Solution**: 
  - Better track change detection (compare song+artist+timestamp)
  - Proper cover download with retries
  - Fallback to procedural covers immediately

### 6. Spotify Direct Integration (New Feature)
- **Requirement**: Connect via Spotify Dashboard using Client ID + Client Secret
- **Implementation**: OAuth 2.0 Authorization Code Flow with PKCE
- **Scope**: `user-read-currently-playing user-read-playback-state user-modify-playback-state`
- **Storage**: Secure token storage (encrypted or obfuscated)

### 7. Missing/Broken UI Elements
- **Issues found**:
  - Dropdown menus not properly destroyed on tab switch
  - Slider knob position not clamped
  - Tab transition race conditions
  - HUD rebuild leaks connections
  - Keybind registry duplicates on rebuild

---

## Technical Architecture

### File Structure
```
UniMenu/
├── core.lua          # Core logic, state, connections, features
├── ui.lua            # All GUI construction (main, content, HUD)
├── mm2.lua           # Game-specific features
├── loader.lua        # Entry point
├── lib/
│   ├── utils.lua     # Utility functions
│   └── http.lua      # HTTP wrapper
└── music/
    ├── lastfm.lua    # Last.fm polling & API
    ├── spotify.lua   # NEW: Spotify OAuth & Web API
    └── covers.lua    # Cover download & procedural generation
```

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| GUI Framework | Native Roblox UI + `UIScale` | Lightweight, no external deps |
| State Management | Centralized in `core.lua` with reactive updates | Single source of truth |
| Notification System | Queue-based with guaranteed cleanup | Prevents stacking/leaks |
| Music Sync | Event-driven + polling fallback | Real-time feel with reliability |
| Spotify Auth | PKCE flow (no client secret in code) | Security best practice |
| Theme System | Live reload without GUI rebuild | Smooth transitions |

---

## Implementation Tasks

### Phase 1: Core Infrastructure (Foundation)
- [ ] **1.1** Add `UIScale` to main GUI with responsive breakpoints
- [ ] **1.2** Enable `ClipsDescendants = true` on all container frames
- [ ] **1.3** Create `GuiUtils` module for common UI patterns
- [ ] **1.4** Fix connection tracking - add `CleanupAll()` function
- [ ] **1.5** Add `ClampPosition()` for drag bounds

### Phase 2: Notification System Rewrite
- [ ] **2.1** Create `NotificationQueue` class with max 3 concurrent
- [ ] **2.2** Implement guaranteed 1-second auto-expire with fade
- [ ] **2.3** Add notification stacking (vertical offset)
- [ ] **2.4** Expose `ShowNotification(message, duration?, type?)` API

### Phase 3: Keybind ↔ UI Bidirectional Sync
- [ ] **3.1** Add `RegisterUIUpdater(kbName, updateFn)` in core
- [ ] **3.2** Call updater from keybind listener after toggle
- [ ] **3.3** Update keybind row UI to reflect current state
- [ ] **3.4** Prevent duplicate registry entries on rebuild

### Phase 4: Last.fm System Fix
- [ ] **4.1** Track `lastPolledTrack = {song, artist, timestamp, nowplaying}`
- [ ] **4.2** On poll: compare with last; only update UI if changed
- [ ] **4.3** Fix cover download: add retry logic + timeout
- [ ] **4.4** Immediate procedural cover while downloading
- [ ] **4.5** Handle "track ended" - show last played with ⏸ prefix

### Phase 5: Spotify Direct Integration (New Module)
- [ ] **5.1** Create `music/spotify.lua` with OAuth PKCE flow
- [ ] **5.2** Add Client ID / Client Secret input in Music tab
- [ ] **5.3** Implement token refresh (access tokens expire in 1hr)
- [ ] **5.4** Add WebSocket or polling for real-time playback
- [ ] **5.5** UI: "Connect Spotify" button → browser auth → callback
- [ ] **5.6** Toggle: "Use Spotify (direct) vs Last.fm (scrobble)"

### Phase 6: Music Tab UI Overhaul
- [ ] **6.1** Split into: "Last.fm", "Spotify Direct", "Covers & Theme"
- [ ] **6.2** Show connection status for each
- [ ] **6.3** Live preview of current track in settings
- [ ] **6.4** Cover art download progress indicator

### Phase 7: General UI Fixes
- [ ] **7.1** Fix slider: clamp knob position, fix value display
- [ ] **7.2** Fix dropdown: destroy on tab switch, proper ZIndex
- [ ] **7.3** Fix tab transition: debounce, prevent race conditions
- [ ] **7.4** Fix HUD: clean up connections on rebuild
- [ ] **7.5** Fix resize handle: maintain aspect ratio option
- [ ] **7.6** Add missing `ClipsDescendants` to scroll frames

### Phase 8: Polish & Testing
- [ ] **8.1** Test on multiple resolutions (1080p, 1440p, 4K)
- [ ] **8.2** Verify keybind sync works for all toggles
- [ ] **8.3** Test notification queue under load
- [ ] **8.4** Test Last.fm → Spotify fallback
- [ ] **8.5** Verify Spotify OAuth works end-to-end

---

## Data Structures

### Music State (core.lua)
```lua
Music = {
  -- Last.fm
  user = "",
  song = "",
  artist = "",
  album = "",
  active = false,
  coverAsset = "",
  coverIsProcedural = false,
  lastCoverUrl = "",
  statusText = "",
  
  -- Spotify Direct (NEW)
  spotify = {
    clientId = "",
    clientSecret = "", -- obfuscated
    accessToken = "",
    refreshToken = "",
    expiresAt = 0,
    deviceId = "",
    connected = false,
    song = "",
    artist = "",
    isPlaying = false,
    progressMs = 0,
    durationMs = 0,
  },
  
  -- Settings
  dynamicColorEnabled = false,
  useSpotifyDirect = false, -- toggle between sources
  peerIcon = "rbxassetid://6274377121",
}
```

### Notification Queue
```lua
NotificationQueue = {
  maxConcurrent = 3,
  items = {}, -- { gui, frame, message, expiresAt }
  Add(message, duration) -> notification
  Remove(notification)
  Cleanup() -- called every frame
}
```

### Keybind Registry Entry (Extended)
```lua
keybindRegistry[kbName] = {
  get = function() return bool end,
  toggle = function(state) end,
  tab = "MM2",
  featName = "Boost Mode",
  uiUpdaters = { function(newState) ... end } -- NEW: callbacks
}
```

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Spotify OAuth requires external browser | Medium | Use `game:OpenBrowser()` with redirect to local callback |
| Token storage security | High | Obfuscate client secret; never log tokens |
| Last.fm API rate limits | Low | 4s polling is well within limits |
| GUI rebuild on theme change | Medium | Use live theme update without full rebuild |
| Drag bounds on small screens | Medium | Clamp to viewport with safe insets |

---

## Validation Checklist

- [ ] GUI scales correctly at 1080p, 1440p, 4K
- [ ] Drag doesn't clip elements outside window
- [ ] Keybind toggle → UI button updates instantly
- [ ] UI button toggle → keybind state updates
- [ ] Notifications expire after 1s with fade
- [ ] Multiple notifications stack vertically
- [ ] Last.fm updates cover/song within 4s of change
- [ ] Spotify direct connects and shows real-time track
- [ ] Switch between Last.fm/Spotify sources works
- [ ] No memory leaks (connections cleaned up)
- [ ] Theme change applies without GUI flicker

---

## Open Questions

1. **Spotify Client Secret storage**: Should we require user to input both ID and Secret, or use a pre-configured app?
   - *Recommended*: User inputs both; we obfuscate secret in storage

2. **Redirect URI for OAuth**: Need a valid redirect. Options:
   - `http://localhost:8888/callback` (requires local server)
   - Custom URL scheme (not possible on Roblox)
   - *Recommended*: Use `https://github.com/login/oauth/authorize` pattern with GitHub Pages callback

3. **Procedural cover animation**: Keep the animated gradient or static?
   - *Recommended*: Static for performance; animate only on hover

4. **Notification sound**: Add optional sound on notification?
   - *Recommended*: Optional, off by default

5. **HUD position persistence**: Save/restore HUD position?
   - *Recommended*: Yes, save to settings

---

## Migration Notes

- Existing `UniMenu_keybinds.json` and `UniMenu_settings.json` compatible
- Last.fm username preserved
- Theme preference preserved
- New Spotify fields added on first setup