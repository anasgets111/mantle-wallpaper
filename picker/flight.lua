-- The chosen card, from its place in the hand to the middle of the screen (1250 ms); then it's
-- set: a ring goes out, light crosses it, and its picture grows into the wallpaper. Everything is
-- built at the pick, each later move held by its `delay`, so no Lua runs while it plays.
local theme = require("theme")
local cards = require("picker.card")
local P = require("picker.model")
local SHINE = mantle.config_dir .. "/shaders/shine.frag"

local RISE = 1250      -- to the middle
local SET = RISE + 900 -- the card falls away and the picture grows

-- The ring and the growing picture each start from a size and ease out over one duration.
local function ring(from) return { duration = 800, easing = "out_cubic", delay = RISE, from = from } end
local function grow(from) return { duration = 1000, easing = "in_out_cubic", delay = SET, from = from } end

-- `f`: the chosen card as it was chosen, { path, scheme, dress, peek } (model.lua).
local function flight(k, f)
    local u, m, D = k.u, k.m, f.dress
    local name = f.path:match("[^/]*$")
    local front_y = k.pivot_y - k.r - k.lift - k.h / 2 + (f.peek and k.peek_drop or 0)
    local k_mid = k.mid_scale
    local ring_r = 64 * u
    return {
        rect {
            id = "flight",
            align_h = "center",
            align_v = "center",
            width = m.width,
            height = m.height,
            scale = k_mid,
            translate = { x = 0, y = 0 },
            animate = {
                scale = { duration = RISE, easing = "in_out_cubic", from = k.front_scale },
                translate = { duration = RISE, easing = "in_out_cubic", from = { x = 0, y = front_y } },
            },
            children = {
                rect {
                    width = "fill",
                    height = "fill",
                    radius = m.radius,
                    shadows = { { color = theme.alpha(D.accent, 0.6), blur = 34 * u } },
                    opacity = 0,
                    animate = { opacity = { duration = RISE, keyframes = {
                        0,
                        { value = 1, duration = RISE,      easing = "in_quad" },
                        { value = 1, duration = SET - RISE },
                        { value = 0, duration = 380,       easing = "out_quad" },
                    } } },
                },
                rect {
                    align_h = "center",
                    align_v = "center",
                    width = m.width + 2 * ring_r,
                    height = m.height + 2 * ring_r,
                    radius = m.radius + ring_r,
                    border_width = 0.96 * u,
                    border_color = D.accent,
                    opacity = 0,
                    animate = {
                        width = ring(m.width),
                        height = ring(m.height),
                        radius = ring(m.radius),
                        border_width = ring(2.4 * u),
                        opacity = { duration = 800, keyframes = {
                            0,
                            { value = 0, duration = RISE },
                            { value = 1, duration = 0 },
                            { value = 0, duration = 800, easing = "out_quart" },
                        } },
                    },
                },
                rect {
                    scale = 1,
                    opacity = 0,
                    animate = {
                        opacity = { duration = SET, keyframes = {
                            1,
                            { value = 1, duration = SET },
                            { value = 0, duration = 320, easing = "out_quad" },
                        } },
                        scale = { duration = RISE, keyframes = {
                            1,
                            { value = 1,     duration = RISE },
                            { value = 1.035, duration = 170, easing = "out_cubic" },
                            { value = 1,     duration = 480, easing = "in_out_quad" },
                        } },
                    },
                    children = {
                        cards.card {
                            m = m,
                            picture = f.path,
                            scheme = f.scheme,
                            dress = D,
                            title = P.base_name(name),
                            meta = f.meta,
                            front = 1,
                            current = true,
                            pop = RISE,
            playing = f.live,
                            favourite = P.settings.favorites:map(function(favs) return P.has(favs, name) end),
                        },
                        rect {
                            margin = { left = m.thumb.x, top = m.thumb.y },
                            width = m.thumb.width,
                            height = m.thumb.height,
                            radius = m.thumb_radius,
                            clip = "rounded",
                            children = {
                                shader {
                                    width = "fill",
                                    height = "fill",
                                    source = SHINE,
                                    blend = "plus_lighter",
                                    -- Off the picture (-1) until it's set.
                                    progress = 1.35,
                                    animate = { progress = { duration = 820, keyframes = {
                                        -1,
                                        { value = -1,    duration = RISE },
                                        { value = -0.35, duration = 0 },
                                        { value = 1.35,  duration = 820, easing = "in_out_sine" },
                                    } } },
                                },
                            },
                        },
                    },
                },
            },
        },
        rect {
            align_h = "center",
            align_v = "center",
            width = k.w,
            height = k.h,
            radius = 0,
            clip = "rounded",
            translate = { x = 0, y = 0 },
            opacity = 1,
            animate = {
                width = grow(m.thumb.width * k_mid),
                height = grow(m.thumb.height * k_mid),
                radius = grow(m.thumb_radius * k_mid),
                translate = grow({ x = 0, y = (m.thumb.y + m.thumb.height / 2 - m.height / 2) * k_mid }),
                opacity = { duration = 1, delay = SET, from = 0 },
            },
            children = {
                image {
                    align_h = "center",
                    align_v = "center",
                    width = k.w,
                    height = k.h,
                    source = f.path,
                    async = true,
                    playing = f.live,
                    scale = 1,
                    animate = {
                        scale = grow(math.max(m.thumb.width * k_mid / k.w, m.thumb.height * k_mid / k.h)),
                    },
                },
            },
        },
    }
end

return flight
