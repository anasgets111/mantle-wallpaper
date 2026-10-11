-- The picker's chrome: the head, the keys, what Enter does, the empty and peeking hints.
local theme = require("theme")
local P = require("picker.model")
local settings = P.settings
local SORT_LABEL = P.SORT_LABEL
local open = P.open
local index = P.index
local source = P.source
local sort = P.sort
local peek = P.peek
local dealt = P.dealt
local chosen = P.chosen
local has = P.has
local entries = P.entries
local reshuffle = P.reshuffle
local toggle_favourite = P.toggle_favourite
local close = P.close
local pick = P.pick

local D = theme.DRESS

-- Fades with the picker: in over 380 ms, out over 240.
local SHOWN = computed({ open, chosen }, function(on, c)
    if on then return { duration = 380, easing = "out_cubic", from = 0 } end
    return { duration = c ~= "" and 340 or 240, easing = "in_cubic" }
end)

local function glass(props)
    props.background = props.background or theme.alpha(D.low, 0.8)
    props.border_width = 1
    props.border_color = theme.alpha(D.ink, 0.12)
    return row(props)
end

local function round_button(id, icon, u, on_click)
    local hov = hover("picker.button:" .. id)
    return rect {
        width = 40 * u,
        height = 40 * u,
        radius = 20 * u,
        hover = hov,
        background = hov:map(function(on) return theme.alpha(D.low, on and 0.95 or 0.8) end),
        border_width = 1,
        border_color = theme.alpha(D.ink, 0.12),
        on_click = on_click,
        children = { theme.glyph(icon, 19 * u, D.ink) },
    }
end

-- A row of choices in a glass pill.
local function segments(id, options, value, u, on_pick)
    local items = {}
    for _, o in ipairs(options) do
        local hov = hover("picker.seg:" .. id .. ":" .. o.key)
        local current = value:map(function(v) return v == o.key end)
        items[#items + 1] = row {
            height = 32 * u,
            padding = { left = 14 * u, right = 14 * u },
            spacing = 6 * u,
            radius = 16 * u,
            hover = hov,
            background = computed({ current, hov }, function(on, over)
                return on and D.accent or over and theme.alpha(D.ink, 0.08) or "#00000000"
            end),
            on_click = function() on_pick(o.key) end,
            children = {
                theme.glyph(o.icon, 17 * u, current:map(function(on) return on and D.accent_ink or D.muted end), {
                    variations = current:map(function(on) return { FILL = on and 1 or 0, wght = 500 } end),
                }),
                text {
                    content = o.label,
                    align_v = "center",
                    font_size = 13 * u,
                    font_weight = 600,
                    foreground = current:map(function(on) return on and D.accent_ink or D.ink end),
                },
            },
        }
    end
    return glass {
        height = 40 * u,
        padding = { left = 4 * u, right = 4 * u },
        spacing = 2 * u,
        radius = 20 * u,
        align_v = "center",
        children = items,
    }
end

local function head(k)
    local u = k.u
    local count_line = computed({ entries, index, sort }, function(list, i, order)
        if #list == 0 then return "" end
        return i .. " of " .. #list .. "  ·  " .. SORT_LABEL[order]
    end)
    local fav_label = settings.favorites:map(function(f) return "Favourites  " .. #(f or {}) end)
    return rect {
        width = k.w - 80 * u,
        height = 44 * u,
        margin = { left = 40 * u, top = 28 * u },
        opacity = computed({ peek, chosen }, function(p, c) return (p or c ~= "") and 0 or 1 end),
        translate = computed({ open, peek, chosen }, function(on, p, c)
            return { x = 0, y = -(on and 0 or 18 * u) - ((p or c ~= "") and 24 * u or 0) }
        end),
        animate = {
            opacity = { duration = 300, easing = "out_cubic" },
            translate = { duration = 380, easing = "out_cubic", from = { x = 0, y = -18 * u } },
        },
        children = {
            row {
                align_v = "center",
                spacing = 12 * u,
                children = {
                    theme.glyph("style", 28 * u, D.accent, { filled = true }),
                    column {
                        align_v = "center",
                        children = {
                            text { content = "Wallpapers", font_size = 21 * u, font_weight = 700, foreground = "#ffffff" },
                            text { content = count_line, font_size = 12 * u, foreground = "#ffffffb8" },
                        },
                    },
                },
            },
            rect {
                align_h = "center",
                align_v = "center",
                children = {
                    segments("source", {
                        { key = "local", label = "Local", icon = "photo_library" },
                        { key = "favorites", label = fav_label, icon = "favorite" },
                    }, source, u, function(key)
                        if key ~= source:get() then reshuffle(function() source:set(key) end) end
                    end),
                },
            },
            row {
                align_h = "end",
                align_v = "center",
                spacing = 8 * u,
                children = {
                    segments("sort", {
                        { key = "name", label = "Name", icon = "sort_by_alpha" },
                        { key = "newest", label = "Newest", icon = "schedule" },
                    }, sort, u, function(key)
                        if key ~= sort:get() then reshuffle(function() sort:set(key) end) end
                    end),
                    round_button("peek", "visibility", u, function() peek:set(not peek:get()) end),
                    round_button("close", "close", u, close),
                },
            },
        },
    }
end

-- Under the head: the keys.
local function hints(k)
    local u = k.u
    return glass {
        align_h = "center",
        margin = { top = (28 + 44 + 18 + 26 + 14) * u },
        height = 28 * u,
        padding = { left = 14 * u, right = 14 * u },
        radius = 20 * u,
        background = theme.alpha(D.low, 0.6),
        visible = entries:map(function(list) return #list > 0 end),
        opacity = computed({ peek, chosen }, function(p, c) return (p or c ~= "") and 0 or 1 end),
        animate = { opacity = { duration = 300, easing = "out_cubic" } },
        children = {
            text {
                align_v = "center",
                content = "←→ or wheel browse  ·  Enter set  ·  F favourite  ·  S sort  ·  R random  ·  Space peek  ·  Tab source  ·  Esc close",
                font_size = 12 * u,
                foreground = theme.alpha(D.ink, 0.78),
            },
        },
    }
end

-- Above the card in front: what Enter does.
local function actions(k)
    local u = k.u
    local e = computed({ entries, index }, function(list, i) return list[i] end)
    local active = computed({ e, settings.current }, function(x, cur) return x ~= nil and x.path == cur end)
    local fav = computed({ e, settings.favorites }, function(x, f) return x ~= nil and has(f, x.name) end)
    local fav_hover, set_hover = hover("picker.fav"), hover("picker.set")
    return row {
        align_h = "center",
        margin = { top = k.front_top - 40 * u - 20 * u },
        spacing = 8 * u,
        visible = entries:map(function(list) return #list > 0 end),
        opacity = computed({ open, dealt, peek, chosen }, function(on, d, p, c)
            return (on and d and not p and c == "") and 1 or 0
        end),
        translate = computed({ open, dealt, peek, chosen }, function(on, d, p, c)
            local down = not on or not d or c ~= ""
            return { x = 0, y = (down and 60 * u or 0) + (p and 40 * u or 0) }
        end),
        animate = {
            opacity = { duration = 380, easing = "out_cubic", from = 0 },
            translate = { duration = 500, easing = "out_cubic", from = { x = 0, y = 60 * u } },
        },
        children = {
            rect {
                width = 40 * u,
                height = 40 * u,
                radius = 20 * u,
                hover = fav_hover,
                background = fav_hover:map(function(on) return theme.alpha(D.low, on and 0.95 or 0.78) end),
                border_width = 1,
                border_color = theme.alpha(D.ink, 0.14),
                on_click = toggle_favourite,
                children = {
                    theme.glyph("favorite", 20 * u, fav:map(function(on) return on and "#ff5c7a" or D.ink end), {
                        variations = fav:map(function(on) return { FILL = on and 1 or 0, wght = 500 } end),
                        translate = { x = 0, y = 1 },
                    }),
                },
            },
            row {
                height = 40 * u,
                padding = { left = 16 * u, right = 16 * u },
                spacing = 8 * u,
                radius = 20 * u,
                hover = set_hover,
                background = computed({ active, set_hover }, function(on, over)
                    if on then return theme.alpha(D.low, 0.82) end
                    return over and theme.lighter(D.accent, 1.08) or D.accent
                end),
                border_width = active:map(function(on) return on and 1 or 0 end),
                border_color = theme.alpha(D.ink, 0.14),
                cursor = active:map(function(on) return on and "default" or "pointer" end),
                on_click = pick,
                children = {
                    theme.glyph(
                        active:map(function(on) return on and "check_circle" or "wallpaper" end),
                        19 * u,
                        active:map(function(on) return on and D.accent or D.accent_ink end),
                        { variations = active:map(function(on) return { FILL = on and 1 or 0, wght = 500 } end) }
                    ),
                    text {
                        align_v = "center",
                        content = active:map(function(on) return on and "On your desktop" or "Set wallpaper" end),
                        font_size = 14 * u,
                        font_weight = 600,
                        foreground = active:map(function(on) return on and D.ink or D.accent_ink end),
                    },
                    rect {
                        visible = active:map(function(on) return not on end),
                        align_v = "center",
                        height = 20 * u,
                        padding = { left = 5 * u, right = 5 * u },
                        radius = 6 * u,
                        background = theme.alpha(D.accent_ink, 0.14),
                        children = {
                            text {
                                align_h = "center",
                                align_v = "center",
                                content = "⏎",
                                font_size = 12 * u,
                                font_weight = 700,
                                foreground = D.accent_ink,
                            },
                        },
                    },
                },
            },
        },
    }
end

-- Nothing to deal.
local function empty(k)
    local u = k.u
    return column {
        align_h = "center",
        align_v = "center",
        spacing = 12 * u,
        visible = entries:map(function(list) return #list == 0 end),
        children = {
            text {
                align_h = "center",
                content = source:map(function(s) return s == "favorites" and "heart_plus" or "hide_image" end),
                font = theme.ICONS,
                font_size = 52 * u,
                foreground = "#ffffffd9",
            },
            text {
                align_h = "center",
                content = computed({ source, settings.dir }, function(s, d)
                    if s == "favorites" then return "No favourites yet: press F on a wallpaper you like" end
                    return "No wallpapers in " .. d
                end),
                font_size = 16 * u,
                foreground = "#ffffff",
            },
        },
    }
end

-- While peeking: how to get back.
local function peek_hint(k)
    local u = k.u
    return glass {
        align_h = "center",
        align_v = "end",
        margin = { bottom = 30 * u },
        height = 36 * u,
        padding = { left = 14 * u, right = 14 * u },
        spacing = 10 * u,
        radius = 20 * u,
        opacity = computed({ peek, chosen }, function(p, c) return (p and c == "") and 1 or 0 end),
        animate = { opacity = { duration = 300, easing = "out_cubic" } },
        children = {
            text {
                align_v = "center",
                content = computed({ entries, index }, function(list, i) return list[i] and list[i].name or "" end),
                font_size = 13 * u,
                font_weight = 600,
                foreground = D.ink,
            },
            text {
                align_v = "center",
                content = "←→ browse  ·  Space or Esc: back to the deck",
                font_size = 12 * u,
                foreground = D.muted,
            },
        },
    }
end

return { D = D, SHOWN = SHOWN, glass = glass, head = head, hints = hints, actions = actions, empty = empty, peek_hint = peek_hint }
