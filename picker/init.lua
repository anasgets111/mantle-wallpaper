-- The wallpaper picker (`mantle call wallpaper.toggle`): a deck of swatch cards held fanned out
-- like a hand along the foot of the screen; behind them the whole screen previews the card in
-- front at full size.
--
-- Keys: ←→ browse, Home/End, PgUp/PgDn, R a random card, Enter set, F favourite, S sort,
-- Space peek, Tab next source, Esc close.
-- Mouse: wheel or drag anywhere to browse, click a card to bring it to the front, click the
-- front card to set it, click the picture itself to peek.
--
-- Choosing a card: it leaves the hand for the middle of the screen while the rest of the hand is
-- put away, lights up as it's set, then its picture grows into the wallpaper and the picker goes.
local chrome = require("picker.chrome")
local deck = require("picker.deck")
local flight = require("picker.flight")
local ribbon = require("picker.ribbon")
local settings_card = require("picker.settings")
local P = require("picker.model")
local SIDE = P.SIDE
local SOURCES = P.SOURCES
local SORTS = P.SORTS
local open = P.open
local mapped = P.mapped
local index = P.index
local source = P.source
local sort = P.sort
local peek = P.peek
local chosen = P.chosen
local stage = P.stage
local geo = P.geo
local entries = P.entries
local hand = P.hand
local go = P.go
local step = P.step
local cycle = P.cycle
local toggle_favourite = P.toggle_favourite
local close = P.close
local pick = P.pick
local drag = P.drag
local BACKDROP = mantle.config_dir .. "/shaders/backdrop.frag"

local function on_key(key)
    local name = key.name
    if chosen:get() ~= "" then
        if name == "Escape" and not key["repeat"] then close() end
        return true
    end
    local count = #entries:get()
    if name == "Escape" then
        if P.settings_open:get() then P.set_settings(false)
        elseif peek:get() then peek:set(false)
        else close() end
    elseif name == "Left" or name == "Up" then step(-1)
    elseif name == "Right" or name == "Down" then step(1)
    elseif name == "Home" then go(1)
    elseif name == "End" then go(count)
    elseif name == "Prior" or name == "Page_Up" then step(-SIDE)
    elseif name == "Next" or name == "Page_Down" then step(SIDE)
    elseif name == "Return" or name == "KP_Enter" then pick()
    elseif name == "space" then
        if not key["repeat"] then peek:set(not peek:get()) end
    elseif name == "f" or name == "F" then toggle_favourite()
    elseif name == "s" or name == "S" then
        P.set_sort(cycle(SORTS, sort:get(), 1))
    elseif name == "r" or name == "R" then
        if count > 1 then go((index:get() + math.random(1, count - 1) - 1) % count + 1) end
    elseif name == "Tab" or name == "ISO_Left_Tab" then
        P.set_source(cycle(SOURCES, source:get(), name == "Tab" and 1 or -1))
    else
        return false
    end
    return true
end

-- The wheel browses wherever it turns, in whole notches.
local wheel_acc, wheel_reset = 0, nil
local function on_wheel(_, steps)
    if chosen:get() ~= "" then return end
    if (steps > 0) ~= (wheel_acc > 0) then wheel_acc = 0 end
    wheel_acc = wheel_acc + steps
    while wheel_acc >= 1 do step(-1); wheel_acc = wheel_acc - 1 end
    while wheel_acc <= -1 do step(1); wheel_acc = wheel_acc + 1 end
    if wheel_reset then wheel_reset:cancel() end
    wheel_reset = timer(400, function() wheel_acc = 0 end)
end

-- Drag anywhere to turn the deck; a drag is not a click.
local drag_from = nil
local function on_drag(_, pointer, phase)
    local g = geo:get()
    if chosen:get() ~= "" or not g or g.width == 0 then return end
    if phase == "start" then
        drag_from = { x = pointer.x, index = index:get() }
        drag.moved = false
    elseif drag_from then
        local k = hand(g)
        local dx = pointer.x - drag_from.x
        if math.abs(dx) > 4 then drag.moved = true end
        if drag.moved then go(math.floor(drag_from.index - dx / (k.step_n * k.r) + 0.5)) end
        if phase == "end" then drag_from = nil end
    end
end

local choosing = chosen:map(function(c) return c ~= "" end)
local backdrop_source = delay(computed({ entries, index, chosen }, function(list, i, c)
    if c ~= "" then return c end
    return list[i] and list[i].path or ""
end), 110)

local function layers(g)
    if not g or g.width == 0 then return {} end
    local k = hand(g)
    return {
        -- The desktop dimmed, until the picture is in.
        rect {
            width = "fill",
            height = "fill",
            background = "#000000",
            opacity = choosing:map(function(c) return c and 0 or 0.55 end),
            animate = { opacity = { duration = 420, easing = "out_cubic" } },
        },
        -- The card in front at full size.
        image {
            id = "backdrop",
            width = "fill",
            height = "fill",
            async = true,
            source = backdrop_source,
            transition = { duration = 520, easing = "linear", shader = BACKDROP },
        },
        -- Shade at the head and the foot, so the header and the deck read on any picture.
        rect {
            width = "fill",
            height = "fill",
            background = {
                gradient = "linear",
                stops = {
                    { 0, "#000000a8" }, { 0.13, "#00000052" }, { 0.24, "#0000000f" },
                    { 0.5, "#00000000" }, { 0.78, "#0000002e" }, { 1, "#00000099" },
                },
            },
            opacity = computed({ peek, choosing }, function(p, c) return c and 0 or p and 0.15 or 1 end),
            animate = { opacity = { duration = 300, easing = "out_cubic" } },
        },
        -- Dimmed behind a chosen card.
        rect {
            width = "fill",
            height = "fill",
            background = "#000000",
            opacity = choosing:map(function(c) return c and 0.55 or 0 end),
            animate = { opacity = { duration = 1000, easing = "in_out_quad" } },
        },
        deck(k),
        chrome.actions(k),
        chrome.head(k),
        ribbon(k),
        chrome.hints(k),
        chrome.empty(k),
        chrome.peek_hint(k),
        settings_card(k),
        rect {
            width = "fill",
            height = "fill",
            -- The flight takes no pointer: the blocker below it does, while it flies.
            hittable = false,
            children = computed({ chosen, stage }, function(c, st)
                return c ~= "" and flight(k, c, st) or {}
            end),
        },
        -- Nothing under a chosen card takes the pointer.
        rect {
            visible = choosing,
            width = "fill",
            height = "fill",
            on_click = function() end,
            on_wheel = function() end,
        },
    }
end

return panel {
    id = "picker",
    layer = "overlay",
    output = "active",
    namespace = "mantle-wallpaperpicker",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = "ignore",
    keyboard_interactivity = "exclusive",
    visible = mapped,
    child = rect {
        geometry = geo,
        width = "fill",
        height = "fill",
        accessible_name = "Wallpapers",
        focus_target = focus_target("picker.root"),
        autofocus = true,
        focus_ring = false,
        cursor = "default",
        on_key = on_key,
        on_wheel = on_wheel,
        on_drag = on_drag,
        on_click = function()
            if not drag.moved and chosen:get() == "" then peek:set(not peek:get()) end
        end,
        opacity = open:map(function(on) return on and 1 or 0 end),
        animate = { opacity = chrome.SHOWN },
        children = geo:map(layers),
    },
}
