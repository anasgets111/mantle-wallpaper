-- The colour scheme each wallpaper would give the desktop: the picker's cards wear it, the colour
-- sort orders by it and the ribbon draws it. Read with the engine's palette (quantize, score, a
-- dark tonal-spot scheme, as matugen does), only when the picker asks, and cached by file name and
-- modification time in ~/.cache/mantle-wallpaper/palettes.json.
local theme = require("theme")

local M = {}

-- The roles a card or the picker's tint uses, plus the seed.
local ROLES = {
    "primary", "on_primary", "secondary", "tertiary", "primary_container",
    "surface_container_low", "surface_container", "surface_container_high", "surface_container_highest",
    "on_surface", "on_surface_variant", "outline_variant",
}
-- Score's seed when an image has no colour to give: a grey wallpaper, not a blue one.
local FALLBACK_SEED = "#4285F4"
local READERS = 3

local cache = persistent_table {
    path = "~/.cache/mantle-wallpaper/palettes.json",
    defaults = { entries = {} },
}

-- File name -> { m = mtime, c = roles } once read, { m = mtime, e = true } when it couldn't be.
M.known = state("colours.known", {})
-- Files in the running scan, and how many are read; `total` 0 when none runs.
M.progress = state("colours.progress", { read = 0, total = 0 })
-- The dark roles of the wallpaper on screen (every role), false until read.
M.desktop = state("colours.desktop", false)

-- Seed and dark roles of an image, or nil.
function M.read(path, on_done)
    palette.quantize(path, { depth = 7 }, function(found)
        if not found or #found == 0 then return on_done(nil) end
        local seed = palette.score(found)[1]
        on_done(seed, palette.scheme(seed, { dark = true }))
    end)
end

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

-- What's been read, kept here so results landing together don't race the store's push.
local memo = copy(cache.entries:get() or {})
mantle.storage:on_change(function()
    local stored, added = cache.entries:get() or {}, false
    for k, v in pairs(stored) do
        if memo[k] == nil then memo[k], added = v, true end
    end
    if added then M.known:set(copy(memo)) end
end)
M.known:set(copy(memo))

local pending, running, read, total = {}, 0, 0, 0
local center = function() return 1 end
local finished = {}
local flush_timer

local function flush()
    flush_timer = nil
    M.known:set(copy(memo))
    cache:set("entries", copy(memo))
    local done = #pending == 0 and running == 0
    M.progress:set({ read = read, total = done and 0 or total })
    if done then
        for _, fn in ipairs(finished) do fn() end
    end
end

local function pump()
    while running < READERS and #pending > 0 do
        -- Nearest the card in front first.
        local c, best = center(), 1
        for n, p in ipairs(pending) do
            if math.abs(p.at - c) < math.abs(pending[best].at - c) then best = n end
        end
        local e = table.remove(pending, best).e
        running = running + 1
        M.read(e.path, function(seed, roles)
            running = running - 1
            read = read + 1
            if roles then
                local c_ = { source = seed }
                for _, r in ipairs(ROLES) do c_[r] = roles[r] end
                memo[e.name] = { m = e.modified, c = c_ }
            else
                memo[e.name] = { m = e.modified, e = true }
            end
            if not flush_timer then flush_timer = timer(250, flush) end
            pump()
        end)
    end
end

-- Reads whatever isn't cached yet of `list` ({ name, path, modified }, every local wallpaper), the
-- ones nearest `near()` (an index into `list`) first. Entries for files that are gone are dropped.
function M.ensure(list, near)
    center = near
    local keep = {}
    for _, e in ipairs(list) do keep[e.name] = true end
    for k in pairs(memo) do
        if not keep[k] then memo[k] = nil end
    end
    local queued = {}
    for _, p in ipairs(pending) do queued[p.e.name] = true end
    local added = 0
    for i, e in ipairs(list) do
        local k = memo[e.name]
        if not queued[e.name] and (not k or k.m ~= e.modified) then
            pending[#pending + 1] = { e = e, at = i }
            added = added + 1
        end
    end
    if added == 0 and running == 0 then return end
    if running == 0 and #pending == added then read, total = 0, added else total = total + added end
    M.progress:set({ read = read, total = total })
    pump()
end

-- Runs `fn` each time a scan finishes.
function M.on_finished(fn) finished[#finished + 1] = fn end

-- The scheme for a file name, or nil until it's read.
function M.scheme(known, name)
    local e = known[name]
    return e and e.c or nil
end

-- The colour a wallpaper stands for (its seed; a grey for a colourless one), or nil until read.
function M.swatch(known, name)
    local s = M.scheme(known, name)
    if not s then return nil end
    return s.source:upper() == FALLBACK_SEED and s.surface_container_highest or s.source
end

-- Where a wallpaper goes in the colour sort: round the hue wheel from red, then the greys from
-- dark to light, then the ones not read yet.
function M.hue_key(known, name)
    local s = M.scheme(known, name)
    if not s then return 3 end
    local h, sat = theme.hsl(s.source)
    if s.source:upper() == FALLBACK_SEED or sat < 0.12 or h < 0 then
        local _, _, l = theme.hsl(s.surface_container_highest)
        return 1 + l
    end
    return (h + 0.035) % 1
end

-- A scheme's dress.
function M.dress_of(s)
    return {
        surface = s.surface_container,
        raised = s.surface_container_high,
        low = s.surface_container_low,
        highest = s.surface_container_highest,
        ink = s.on_surface,
        muted = s.on_surface_variant,
        line = s.outline_variant,
        accent = s.primary,
        accent_ink = s.on_primary,
    }
end

-- The desktop's dress: the wallpaper on screen's scheme, else the Material defaults.
M.desktop_dress = M.desktop:map(function(d) return d and M.dress_of(d) or theme.DRESS end)

-- The five chips on a card, top to bottom.
function M.chips(s)
    return {
        { label = "primary", fill = s.primary },
        { label = "secondary", fill = s.secondary },
        { label = "tertiary", fill = s.tertiary },
        { label = "container", fill = s.primary_container },
        { label = "surface", fill = s.surface_container_highest },
    }
end

return M
