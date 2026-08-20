-- UniMenu Music Covers Module
-- Handles album cover download, caching, and procedural generation

local ctx = ...
local HttpService = ctx.Services.HttpService

local Music = ctx.State.Music
local XP = ctx.Config.XP

-- Cover cache to avoid re-downloading
local coverCache = {}

-- ==================== UTILITY: Write File & Set Cover ====================
local function WriteAndSetCover(imgData)
  if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then return end
  local fileName = "unimenu_cover_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999) .. ".jpg"
  writefile(fileName, imgData)
  local asset = getcustomasset(fileName)
  Music.coverAsset = asset
  Music.coverIsProcedural = false
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
  -- Apply dynamic theme if enabled
  if Music.dynamicColorEnabled then
    ctx.Core.ApplyCoverTheme(imgData)
  end
  return asset
end

-- ==================== PROCEDURAL COVER GENERATION ====================
local function BuildProceduralCover(song, artist)
  local label = (song or "♪"):sub(1, 1):upper()
  local seedStr = (song or "") .. (artist or "")
  local hash = 0
  for i = 1, #seedStr do
    hash = (hash * 31 + string.byte(seedStr, i)) % 0x7FFFFFFF
  end
  local hue1 = hash % 360
  local hue2 = (hue1 + 80 + (hash % 120)) % 360
  local gen = hash % 4

  local success = pcall(function()
    local coverGui = Instance.new("ScreenGui")
    coverGui.Name = "ProceduralCover_" .. tostring(os.time())
    coverGui.ResetOnSpawn = false
    coverGui.IgnoreGuiInset = true
    coverGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    coverGui.DisplayOrder = -1 -- Behind everything

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = Color3.fromHSV(hue1 / 360, 0.7, 0.25)
    frame.Parent = coverGui

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, Color3.fromHSV(hue1 / 360, 0.85, 0.55)),
      ColorSequenceKeypoint.new(1, Color3.fromHSV(hue2 / 360, 0.85, 0.35)),
    })
    grad.Rotation = gen * 45
    grad.Parent = frame

    -- Decorative shapes
    for i = 1, 3 do
      local shape = Instance.new("Frame")
      shape.Size = UDim2.new(0, 60 + i * 40, 0, 60 + i * 40)
      shape.Position = UDim2.new(0.5, -30 - i * 20, 0.5, -30 - i * 20)
      shape.BackgroundTransparency = 0.7 + i * 0.1
      shape.BackgroundColor3 = Color3.fromHSV((hue1 + i * 40) % 360 / 360, 0.6, 0.8)
      shape.Parent = frame
    end

    -- Song initial
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, -20)
    textLabel.Position = UDim2.new(0, 10, 0, 10)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = label
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextTransparency = 0.3
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 48
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.Parent = frame

    coverGui.Parent = game:GetService("CoreGui")
    -- Render to texture via draw (not directly supported, so we use the GUI as-is)
    -- For procedural, we just mark it as procedural and use the asset ID
    Music.coverAsset = "rbxasset://ProceduralCover"
    Music.coverIsProcedural = true
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
  end)

  if not success then
    -- Ultimate fallback
    Music.coverAsset = ""
    Music.coverIsProcedural = false
    if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
  end
end

-- ==================== iTunes SEARCH FALLBACK ====================
local function FetchCoverFromiTunes(song, artist)
  local query = ctx.Core.UrlEncode(artist .. " " .. song)
  local url = "https://itunes.apple.com/search?term=" .. query .. "&media=music&entity=song&limit=1"
  local res = ctx.Core.MusicHTTP(url)
  if not res or not res.Body or #res.Body < 10 then return end
  local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
  if not ok or not data or not data.results or #data.results == 0 then return end
  local artUrl = data.results[1].artworkUrl100
  if not artUrl or artUrl == "" then return end
  -- Upgrade to higher resolution (600x600)
  artUrl = artUrl:gsub("100x100bb", "600x600bb")
  local imgRes = ctx.Core.MusicHTTP(artUrl)
  if imgRes and imgRes.Body and #imgRes.Body > 1000 then
    pcall(WriteAndSetCover, imgRes.Body)
  end
end

-- ==================== MAIN COVER DOWNLOAD ====================
local function DownloadAlbumCover(lastfmImgUrl, song, artist)
  local cacheKey = (lastfmImgUrl or "") .. "|" .. (song or "") .. "|" .. (artist or "")
  if cacheKey == Music.lastCoverUrl and Music.coverAsset ~= "" then
    return -- already showing the right art
  end
  Music.lastCoverUrl = cacheKey
  Music.coverAsset = ""
  Music.coverIsProcedural = false
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end

  task.spawn(function()
    -- 1. Try Last.fm provided image (works for popular albums)
    local lastfmHasImage = lastfmImgUrl and lastfmImgUrl ~= "" and
        not lastfmImgUrl:find("2a96cbd8b46e442fc41c2b86b821562f")
    if lastfmHasImage then
      local res = ctx.Core.MusicHTTP(lastfmImgUrl)
      if res and res.Body and #res.Body > 1000 then
        pcall(WriteAndSetCover, res.Body)
        return -- success, done
      end
    end

    -- 2. Fallback: iTunes Search API (covers singles & less popular artists)
    if song and song ~= "" and artist and artist ~= "" then
      pcall(FetchCoverFromiTunes, song, artist)
    end

    -- 3. Final fallback: procedural cover
    task.wait(0.5)
    if Music.coverAsset == "" and Music.song ~= "" then
      pcall(BuildProceduralCover, song, artist)
    end
  end)
end

-- ==================== DYNAMIC THEME FROM COVER ====================
local function ApplyCoverTheme(imgData)
  if not Music.dynamicColorEnabled then return end
  local hash = 0
  for i = 1, math.min(#imgData, 1024) do
    hash = (hash * 31 + string.byte(imgData, i)) % 0x7FFFFFFF
  end

  local hue1 = hash % 360
  local hue2 = (hue1 + 100 + (hash % 80)) % 360
  local sat1 = 0.45 + (hash % 30) / 100
  local sat2 = 0.45 + (math.floor(hash / 30) % 30) / 100
  local val1 = 0.25 + (hash % 25) / 100
  local val2 = 0.5 + (math.floor(hash / 25) % 30) / 100

  local theme = {
    windowBg = Color3.fromHSV(hue1 / 360, sat1, val1),
    windowBgLight = Color3.fromHSV(hue1 / 360, math.max(sat1 - 0.15, 0.1), math.min(val1 + 0.25, 0.9)),
    windowBgDark = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.1, 0.85), math.max(val1 - 0.1, 0.1)),
    titleBar = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.15, 0.9), math.max(val1 - 0.05, 0.08)),
    titleBarGrad1 = Color3.fromHSV(hue2 / 360, sat2, val2),
    titleBarGrad2 = Color3.fromHSV((hue1 + hue2) / 720, (sat1 + sat2) / 2, (val1 + val2) / 2),
    titleBarGrad3 = Color3.fromHSV(hue1 / 360, math.min(sat1 + 0.1, 0.9), math.max(val1 - 0.08, 0.05)),
    sidebar1 = Color3.fromHSV(hue1 / 360, 0.12, 0.95),
    sidebar2 = Color3.fromHSV(hue1 / 360, 0.15, 0.88),
    panel1 = Color3.fromHSV(hue1 / 360, 0.08, 0.98),
    panel2 = Color3.fromHSV(hue1 / 360, 0.1, 0.92),
    rowBg = Color3.fromHSV(hue1 / 360, 0.05, 1.0),
    borderLight = Color3.fromHSV(hue1 / 360, 0.05, 0.95),
    borderDark = Color3.fromHSV(hue1 / 360, 0.3, 0.4),
    tabActive = Color3.fromHSV(hue1 / 360, 0.02, 0.98),
    tabInactive = Color3.fromHSV(hue1 / 360, 0.08, 0.85),
    tabActiveText = Color3.fromHSV(hue1 / 360, 0.9, 0.3),
    tabInactiveText = Color3.fromHSV(hue1 / 360, 0.3, 0.5),
    text = Color3.fromHSV(hue1 / 360, 0.1, 0.15),
    accent = Color3.fromHSV(hue2 / 360, 0.8, 0.55),
    green = Color3.fromHSV(140 / 360, 0.8, 0.5),
    red = Color3.fromHSV(0 / 360, 0.8, 0.5),
    tagBg = Color3.fromHSV(hue1 / 360, 0.08, 0.98),
    tagHeader = Color3.fromHSV(hue1 / 360, 0.6, 0.4),
    tagText = Color3.fromHSV(hue1 / 360, 0.1, 0.15),
    tagBorder = Color3.fromHSV(hue1 / 360, 0.3, 0.4),
  }

  Music.dynamicTheme = theme
  Music.usingDynamicTheme = true
  -- Apply theme live without full GUI rebuild
  ctx.Config.XP = theme
  ctx.Core.ApplyTheme()
end

local function RevertToDefaultTheme()
  if not Music.usingDynamicTheme then return end
  local defaultTheme = ctx.Config.Themes[ctx.Config.currentThemeName] or ctx.Config.Themes["Windows XP Luna"]
  ctx.Config.XP = defaultTheme
  Music.usingDynamicTheme = false
  Music.dynamicTheme = nil
  ctx.Core.ApplyTheme()
  if ctx.UI and ctx.UI.UpdateMusicUI then ctx.UI.UpdateMusicUI() end
end

-- Exports
ctx.Core.DownloadAlbumCover = DownloadAlbumCover
ctx.Core.BuildProceduralCover = BuildProceduralCover
ctx.Core.ApplyCoverTheme = ApplyCoverTheme
ctx.Core.RevertToDefaultTheme = RevertToDefaultTheme
ctx.Core.FetchCoverFromiTunes = FetchCoverFromiTunes
ctx.Core.WriteAndSetCover = WriteAndSetCover

return {
  DownloadAlbumCover = DownloadAlbumCover,
  BuildProceduralCover = BuildProceduralCover,
  ApplyCoverTheme = ApplyCoverTheme,
  RevertToDefaultTheme = RevertToDefaultTheme,
  FetchCoverFromiTunes = FetchCoverFromiTunes,
  WriteAndSetCover = WriteAndSetCover,
}