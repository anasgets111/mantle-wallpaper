-- The picker's state and what changes it: the deck's list, its position, opening, choosing.
local wallpaper = require("wallpaper")
local cards = require("picker.card")
local colours = require("colours")

local settings = wallpaper.settings
local u_of = function(g) return math.max(0.6, math.min(g.width / 1920, g.height / 1200)) end

local EXTENSIONS = { "jpg", "jpeg", "png", "webp", "gif" }
local SIDE = 7 -- cards shown each side of the one in front
local SOURCES = { "local", "favorites" }
local SORTS = { "name", "colour", "newest" }
local SORT_LABEL = { name = "by name", colour = "by colour", newest = "newest first" }

local open = state("picker.open", false)
local mapped = computed({ open, delay(open, 360) }, function(now, was) return now or was end)
local index = state("picker.index", 1)
-- How far the deck last moved, so cards coming into the hand start where they were.
local shift = state("picker.shift", 0)
local source = state("picker.source", "local")
local sort = state("picker.sort", "name")
local peek = state("picker.peek", false)
-- False while the hand is put away for a new source or order.
local dealt = state("picker.dealt", true)
local chosen = state("picker.chosen", "")
local stage = state("picker.stage", "") -- "", "rise", "bloom"
local settings_open = state("picker.settings_open", false)
local geo = geometry("picker.root")
-- The colour sort's keys, taken when it's chosen and when a scan finishes, so the deck doesn't
-- reshuffle as each colour is read.
local hues = state("picker.hues", {})
local dealing = computed({ pulse(open, 800), pulse(dealt, 800) }, function(a, b) return a or b end)

local function dir() return wallpaper.expand(settings.dir:get()) end
local function watch() mantle.folders:watch(dir(), EXTENSIONS) end
watch()
mantle.storage:on_change(watch)

local function base_name(name) return (name:gsub("%.[^.]*$", "")) end
local function has(list, name)
    for _, v in ipairs(list or {}) do
        if v == name then return true end
    end
    return false
end

-- Every local wallpaper as listed: { name, path, modified }.
local listing = computed({ mantle.folders, settings.dir }, function(folders, d)
    local folder = folders and folders.watched[wallpaper.expand(d)]
    return folder and folder.entries or {}
end, {})

-- The deck: { name, path, modified, at }, filtered by source and in the chosen order.
local entries = computed({ listing, settings.favorites, source, sort, hues }, function(all, favs, src, order, keys)
    local list = {}
    for i, e in ipairs(all) do
        if src ~= "favorites" or has(favs, e.name) then
            list[#list + 1] = { name = e.name, path = e.path, modified = e.modified, at = i }
        end
    end
    local function by(key)
        table.sort(list, function(a, b)
            local ka, kb = key(a), key(b)
            if ka ~= kb then return ka < kb end
            return a.at < b.at
        end)
    end
    if order == "newest" then
        by(function(e) return -e.modified end)
    elseif order == "colour" then
        by(function(e) return keys[e.name] or 3 end)
    end
    return list
end, {})

local function front_entry() return entries:get()[index:get()] end

-- The deck's geometry for a screen `g`, in pixels (QML design units scaled by `u`).
local function hand(g)
    local u = u_of(g)
    local m = cards.measure(u)
    local pivot_y = g.height + 1650 * u
    local r = pivot_y - (g.height - 196 * u)
    local lift = 66 * u
    return {
        u = u, m = m, w = g.width, h = g.height,
        pivot_x = g.width / 2, pivot_y = pivot_y, r = r, lift = lift,
        step1 = 204 * u / r, step_n = 132 * u / r,
        front_scale = 1.22,
        -- Top of the card in front, at rest.
        front_top = pivot_y - r - lift - m.height * 1.22 / 2,
        lowered = m.height * 1.35 + 140 * u,
        peek_drop = m.height * 1.25 + 120 * u,
        mid_scale = math.max(1.4, math.min(2.4, 0.5 * g.height / m.height)),
    }
end

local function theta(k, d)
    local ad = math.abs(d)
    local t = math.min(ad, 1) * k.step1 + math.max(0, ad - 1) * k.step_n
    return (d < 0 and -t or t) * 180 / math.pi
end

-- ── Moving through the deck ──────────────────────────────────────────────
local function go(i)
    local count = #entries:get()
    if count == 0 or chosen:get() ~= "" then return end
    i = math.max(1, math.min(count, i))
    local delta = i - index:get()
    -- A long way is cut short.
    if math.abs(delta) > SIDE + 2 then delta = delta > 0 and 3 or -3 end
    shift:set(delta)
    index:set(i)
end

local function step(d) go(index:get() + d) end

-- The card in front stays in front across a new list, else the wallpaper on screen does.
local function refocus(prefer)
    local list = entries:get()
    local i
    for n, e in ipairs(list) do
        if e.path == prefer then i = n end
    end
    if not i then
        for n, e in ipairs(list) do
            if e.path == settings.current:get() then i = n end
        end
    end
    shift:set(0)
    index:set(i or 1)
end

-- A new source or order: the hand is put away, `change` made out of sight, and the new hand dealt.
local function reshuffle(change)
    local was = front_entry()
    dealt:set(false)
    timer(170, function()
        change()
        refocus(was and was.path)
        dealt:set(true)
    end)
end

local function snapshot_hues()
    local known, keys = colours.known:get(), {}
    for _, e in ipairs(listing:get()) do keys[e.name] = colours.hue_key(known, e.name) end
    return keys
end

local function set_sort(key)
    if key == sort:get() then return end
    reshuffle(function()
        if key == "colour" then hues:set(snapshot_hues()) end
        sort:set(key)
    end)
end

local function set_source(key)
    if key ~= source:get() then reshuffle(function() source:set(key) end) end
end

-- The colour sort, once every colour is in.
colours.on_finished(function()
    if sort:get() == "colour" and open:get() then reshuffle(function() hues:set(snapshot_hues()) end) end
end)

local function cycle(list, value, by)
    for n, v in ipairs(list) do
        if v == value then return list[(n - 1 + by) % #list + 1] end
    end
    return list[1]
end

local function toggle_favourite()
    local e = front_entry()
    if not e then return end
    local favs, out = settings.favorites:get() or {}, {}
    for _, v in ipairs(favs) do
        if v ~= e.name then out[#out + 1] = v end
    end
    if #out == #favs then out[#out + 1] = e.name end
    settings:set("favorites", out)
end

-- ── Opening, choosing, closing ───────────────────────────────────────────
local function close()
    open:set(false)
    timer(400, function()
        if open:get() then return end
        chosen:set("")
        stage:set("")
        wallpaper.instant:set(false)
    end)
end

-- Opens or closes the settings card; closed, the keys go back to the deck. Call from a click or
-- key handler: only those can move focus.
local function set_settings(on)
    settings_open:set(on)
    if not on then focus_target("picker.root"):request() end
end

local function show()
    settings_open:set(false)
    chosen:set("")
    stage:set("")
    peek:set(false)
    source:set("local")
    refocus(nil)
    open:set(true)
    -- Colours for the cards near the one in front first.
    colours.ensure(listing:get(), function()
        local e = front_entry()
        return e and e.at or 1
    end)
end

action("wallpaper.toggle", function()
    if open:get() then close() else show() end
end)

-- The card in front goes to the middle of the screen, the wallpaper is set under the picker, the
-- picture grows into it, and the picker goes.
local function pick()
    local e = front_entry()
    if not e or chosen:get() ~= "" or e.path == settings.current:get() then return end
    -- Turned off, it's set straight away and the deck stays open.
    if not settings.animate_choice:get() then
        wallpaper.set(e.path)
        return
    end
    if settings_open:get() then set_settings(false) end
    chosen:set(e.path)
    stage:set("rise")
    wallpaper.set(e.path, true)
    timer(1250, function()
        if chosen:get() == e.path then stage:set("bloom") end
    end)
    timer(1250 + 900 + 1000, function()
        if chosen:get() == e.path and open:get() then close() end
    end)
end

-- The colours the picker wears: the card in front's scheme, else the desktop's.
local tint = computed({ entries, index, colours.known, colours.desktop_dress }, function(list, i, known, desk)
    local e = list[i]
    local s = e and colours.scheme(known, e.name)
    return s and colours.dress_of(s) or desk
end)

-- A drag turning the deck is not a click.
local drag = { moved = false }

return {
    settings = settings,
    SIDE = SIDE,
    SOURCES = SOURCES,
    SORTS = SORTS,
    SORT_LABEL = SORT_LABEL,
    open = open,
    mapped = mapped,
    index = index,
    shift = shift,
    source = source,
    sort = sort,
    peek = peek,
    dealt = dealt,
    chosen = chosen,
    stage = stage,
    geo = geo,
    dealing = dealing,
    base_name = base_name,
    has = has,
    entries = entries,
    listing = listing,
    tint = tint,
    settings_open = settings_open,
    set_settings = set_settings,
    set_sort = set_sort,
    set_source = set_source,
    front_entry = front_entry,
    hand = hand,
    theta = theta,
    go = go,
    step = step,
    refocus = refocus,
    reshuffle = reshuffle,
    cycle = cycle,
    toggle_favourite = toggle_favourite,
    close = close,
    show = show,
    pick = pick,
    drag = drag,
    wallpaper = wallpaper,
}
