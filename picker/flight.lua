local theme = require("theme")
local cards = require("picker.card")
local colours = require("colours")
local P = require("picker.model")
local settings = P.settings
local peek = P.peek
local base_name = P.base_name
local has = P.has
local SHINE = mantle.config_dir .. "/shaders/shine.frag"

-- The chosen card, from its place in the hand to the middle of the screen; once set (`st` is
-- "bloom"), a ring goes out, light crosses it, and its picture grows into the wallpaper. The
-- bloom's nodes are built when it starts, so their entry animations play then.
local function flight(k, path, st)
    local u, m = k.u, k.m
    local blooming = st == "bloom"
    local name = path:match("[^/]*$")
    local scheme = colours.scheme(colours.known:get(), name)
    local D = scheme and colours.dress_of(scheme) or colours.desktop_dress:get()
    local front_y = k.pivot_y - k.r - k.lift - k.h / 2 + (peek:get() and k.peek_drop or 0)
    local k_mid = k.mid_scale
    local ring_r = 64 * u
    local on_card = {
        cards.card {
            m = m,
            picture = path,
            scheme = scheme,
            dress = D,
            title = base_name(name),
            meta = (name:match("%.([^.]+)$") or ""):upper(),
            front = 1,
            current = blooming,
            pop = blooming,
            favourite = settings.favorites:map(function(f) return has(f, name) end),
        },
    }
    local around = {
        -- The glow behind it.
        rect {
            id = "glow",
            width = "fill",
            height = "fill",
            radius = m.radius,
            shadows = { { color = theme.alpha(D.accent, 0.6), blur = 34 * u } },
            opacity = blooming and 0 or 1,
            animate = {
                opacity = blooming and { duration = 380, easing = "out_quad", delay = 900 }
                    or { duration = 1250, easing = "in_quad", from = 0 },
            },
        },
    }
    if blooming then
        -- A ring goes out from the card as it's set.
        around[#around + 1] = rect {
            id = "ring",
            align_h = "center",
            align_v = "center",
            width = m.width + 2 * ring_r,
            height = m.height + 2 * ring_r,
            radius = m.radius + ring_r,
            border_width = 0.96 * u,
            border_color = D.accent,
            opacity = 0,
            animate = {
                width = { duration = 800, easing = "out_cubic", from = m.width },
                height = { duration = 800, easing = "out_cubic", from = m.height },
                radius = { duration = 800, easing = "out_cubic", from = m.radius },
                border_width = { duration = 800, easing = "out_cubic", from = 2.4 * u },
                opacity = { duration = 800, easing = "out_quart", from = 1 },
            },
        }
        -- Light crosses the picture.
        on_card[#on_card + 1] = rect {
            id = "shine",
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
                    progress = 1.35,
                    animate = { progress = { duration = 820, easing = "in_out_sine", from = -0.35 } },
                },
            },
        }
    end
    around[#around + 1] = rect {
        id = "card",
        scale = 1,
        opacity = blooming and 0 or 1,
        animate = blooming and {
            -- It pulses as it's set, then falls away from round its picture.
            opacity = { duration = 320, easing = "out_quad", delay = 900 },
            scale = { duration = 170, keyframes = {
                1,
                { value = 1.035, duration = 170, easing = "out_cubic" },
                { value = 1, duration = 480, easing = "in_out_quad" },
            } },
        } or {},
        children = on_card,
    }
    local out = {
        rect {
            id = "flight",
            align_h = "center",
            align_v = "center",
            width = m.width,
            height = m.height,
            scale = k_mid,
            translate = { x = 0, y = 0 },
            animate = {
                scale = { duration = 1250, easing = "in_out_cubic", from = k.front_scale },
                translate = { duration = 1250, easing = "in_out_cubic", from = { x = 0, y = front_y } },
            },
            children = around,
        },
    }
    if blooming then
        -- The picture, from its place on the card to the whole screen: the wallpaper.
        local delay_ms = 900
        out[#out + 1] = rect {
            id = "bloom",
            align_h = "center",
            align_v = "center",
            width = k.w,
            height = k.h,
            radius = 0,
            clip = "rounded",
            translate = { x = 0, y = 0 },
            opacity = 1,
            animate = {
                width = { duration = 1000, easing = "in_out_cubic", delay = delay_ms, from = m.thumb.width * k_mid },
                height = { duration = 1000, easing = "in_out_cubic", delay = delay_ms, from = m.thumb.height * k_mid },
                radius = { duration = 1000, easing = "in_out_cubic", delay = delay_ms, from = m.thumb_radius * k_mid },
                translate = {
                    duration = 1000,
                    easing = "in_out_cubic",
                    delay = delay_ms,
                    from = { x = 0, y = (m.thumb.y + m.thumb.height / 2 - m.height / 2) * k_mid },
                },
                opacity = { duration = 1, delay = delay_ms, from = 0 },
            },
            children = {
                image {
                    align_h = "center",
                    align_v = "center",
                    width = k.w,
                    height = k.h,
                    source = path,
                    async = true,
                    scale = 1,
                    animate = {
                        scale = {
                            duration = 1000,
                            easing = "in_out_cubic",
                            delay = delay_ms,
                            from = math.max(m.thumb.width * k_mid / k.w, m.thumb.height * k_mid / k.h),
                        },
                    },
                },
            },
        }
    end
    return out
end

return flight
