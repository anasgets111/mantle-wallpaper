-- The whole deck in one line under the head: a segment per wallpaper in its colour (sorted by
-- colour, a spectrum), a bracket round the cards in hand, ticks over the favourites and a dot under
-- the wallpaper on screen. Hover for a glimpse of any wallpaper; click or drag to go there.
local colours = require("colours")
local P = require("picker.model")

local SIDE = P.SIDE
local MOVE = { duration = 380, easing = "out_cubic" }
local UNREAD = "#ffffff24" -- a wallpaper whose colour isn't read yet
local scrubbing = state("picker.ribbon.scrubbing", false)

local function ribbon(k)
    local u = k.u
    local width = k.w - 80 * u
    local height = 26 * u
    local hov, ptr = hover("picker.ribbon"), pointer("picker.ribbon")
    local active = computed({ hov, scrubbing }, function(h, s) return h or s end)
    local track_h = active:map(function(on) return (on and 12 or 8) * u end)
    local function seg(n) return n > 0 and width / n or 0 end
    -- The track's top edge, from the middle of the ribbon.
    local function top(t) return (height - t) / 2 end

    -- The wallpaper under pointer offset `x`.
    local function at(x, n) return math.max(1, math.min(n, math.floor(x / seg(n)) + 1)) end
    -- The marker's width, and how many segments lie before the hand.
    local function marker_w(list) return math.max(3 * u, math.min(seg(#list), 6 * u)) end
    local function from(i) return math.max(0, i - 1 - SIDE) end

    -- One node for the whole track: a segment per wallpaper as hard gradient stops.
    local track_fill = computed({ P.entries, colours.known }, function(list, known)
        local n = #list
        if n == 0 then return "#00000000" end
        if n == 1 then return colours.swatch(known, list[1].name) or UNREAD end
        local stops = {}
        for i, e in ipairs(list) do
            local c = colours.swatch(known, e.name) or UNREAD
            stops[#stops + 1] = { (i - 1) / n, c }
            stops[#stops + 1] = { i / n, c }
        end
        return { gradient = "linear", angle = 90, stops = stops }
    end)

    local glimpse_index = computed({ ptr, P.entries }, function(p, list)
        if not p or #list == 0 then return 0 end
        return at(p.x, #list)
    end)
    local glimpse_path = delay(computed({ glimpse_index, P.entries }, function(i, list)
        return list[i] and list[i].path or ""
    end), 70)
    local gw = 176 * u
    local gi = gw - 12 * u

    return rect {
        margin = { left = 40 * u, top = (28 + 44 + 18 - 6) * u },
        width = width,
        height = height + 12 * u,
        z = 5,
        visible = P.entries:map(function(list) return #list > 0 end),
        opacity = P.uncovered,
        animate = { opacity = { duration = 300, easing = "out_cubic" } },
        hover = hov,
        pointer = ptr,
        cursor = "pointer",
        on_click = function() end,
        on_drag = function(_, p, phase)
            local n = #P.entries:get()
            if n == 0 then return end
            scrubbing:set(phase ~= "end")
            P.go(at(p.x, n))
        end,
        children = {
            rect {
                margin = { top = 6 * u },
                width = width,
                height = height,
                children = {
                    rect {
                        align_v = "center",
                        width = width,
                        height = track_h,
                        -- Rounded ends: a radius past half the height is shrunk to fit.
                        radius = 99 * u,
                        background = track_fill,
                        animate = { height = { duration = 160, easing = "out_cubic" } },
                    },
                    rect {
                        width = "fill",
                        height = "fill",
                        children = computed({ P.entries, P.settings.favorites, P.source, track_h }, function(list, favs,
                                                                                                             src, t)
                            if src == "favorites" then return {} end
                            local out, w = {}, seg(#list)
                            local tick = math.max(2, math.min(w - 1, 3 * u))
                            for i, e in ipairs(list) do
                                if P.has(favs, e.name) then
                                    out[#out + 1] = rect {
                                        margin = { left = (i - 0.5) * w - tick / 2, top = top(t) - 5 * u },
                                        width = tick,
                                        height = 3 * u,
                                        radius = tick / 2,
                                        background = "#ff7a93",
                                    }
                                end
                            end
                            return out
                        end),
                    },
                    rect {
                        width = 4 * u,
                        height = 4 * u,
                        radius = 2 * u,
                        background = "#ffffff",
                        margin = computed({ P.entries, P.settings.current, track_h }, function(list, cur, t)
                            for i, e in ipairs(list) do
                                if e.path == cur then
                                    return { left = (i - 0.5) * seg(#list) - 2 * u, top = top(t) + t + 3 * u }
                                end
                            end
                            return { left = -100 * u }
                        end),
                    },
                    rect {
                        radius = 5 * u,
                        border_width = math.max(1, 1.3 * u),
                        border_color = "#ffffff8c",
                        translate = computed({ P.entries, P.index, track_h }, function(list, i, t)
                            return { x = from(i) * seg(#list) - 3 * u, y = top(t) - 4 * u }
                        end),
                        width = computed({ P.entries, P.index }, function(list, i)
                            local to = math.min(#list, i + SIDE)
                            return math.max(6 * u, (to - from(i)) * seg(#list) + 6 * u)
                        end),
                        height = track_h:map(function(t) return t + 8 * u end),
                        animate = { translate = MOVE, width = MOVE, height = { duration = 160, easing = "out_cubic" } },
                    },
                    rect {
                        width = P.entries:map(marker_w),
                        height = track_h:map(function(t) return t + 12 * u end),
                        radius = 3 * u,
                        background = P.tint:map(function(d) return d.accent end),
                        border_width = 1,
                        border_color = "#00000059",
                        translate = computed({ P.entries, P.index, track_h }, function(list, i, t)
                            return { x = (i - 0.5) * seg(#list) - marker_w(list) / 2, y = top(t) - 6 * u }
                        end),
                        animate = { translate = MOVE, background = { duration = 420, easing = "out_cubic" } },
                    },
                },
            },
            column {
                visible = computed({ hov, scrubbing, glimpse_index }, function(h, s, i) return h and not s and i > 0 end),
                margin = ptr:map(function(p)
                    local x = p and p.x or 0
                    return { left = math.max(0, math.min(width - gw, x - gw / 2)), top = height + 12 * u + 8 * u }
                end),
                width = gw,
                padding = 6 * u,
                spacing = 5 * u,
                radius = 12 * u,
                background = colours.desktop_dress:map(function(d) return d.low end),
                border_width = 1,
                border_color = "#ffffff29",
                children = {
                    rect {
                        width = gi,
                        height = math.floor(gi * 10 / 16 + 0.5),
                        radius = 8 * u,
                        background = computed({ glimpse_index, P.entries, colours.known, colours.desktop_dress }, function(
                            i, list, known, d)
                            return list[i] and colours.swatch(known, list[i].name) or d.raised
                        end),
                        children = {
                            image {
                                width = "fill",
                                height = "fill",
                                radius = 8 * u,
                                async = true,
                                source = glimpse_path,
                            },
                        },
                    },
                    text {
                        width = gi,
                        text_align = "center",
                        elide = "middle",
                        content = computed({ glimpse_index, P.entries }, function(i, list)
                            return list[i] and (i .. "  ·  " .. list[i].name) or ""
                        end),
                        font_size = 11 * u,
                        foreground = colours.desktop_dress:map(function(d) return d.ink end),
                    },
                },
            },
        },
    }
end

return ribbon
