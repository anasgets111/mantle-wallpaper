-- One wallpaper as a paint-chip card in the picker's deck, dressed in the colour scheme the
-- wallpaper would give the desktop: the card is its surface, the text its on-surface, the strip
-- of chips its roles.
local theme = require("theme")
local colours = require("colours")

local M = {}

local POP = { scale = { duration = 200, keyframes = {
    0.4,
    { value = 1.12, duration = 200, easing = "out_cubic" },
    { value = 1, duration = 160, easing = "in_out_quad" },
} } }

-- The card's measures at `u` design pixels per pixel.
function M.measure(u)
    local pad = 9 * u
    local width = 212 * u
    local thumb_w = width - pad * 2
    local thumb_h = math.floor(thumb_w * 10 / 16 + 0.5)
    local chip_h = 22 * u
    -- Text boxes are font_size × line_height (1.2).
    local height = pad + thumb_h + 8 * u + chip_h * 5 + 9 * u + 13 * u * 1.2 + 2 * u + 10 * u * 1.2 + pad + 2 * u
    return {
        u = u, pad = pad, width = width, height = height, chip_h = chip_h,
        radius = 16 * u, thumb_radius = 10 * u,
        thumb = { x = pad, y = pad, width = thumb_w, height = thumb_h },
    }
end

-- Number `v` (or a signal of one) through `fn`.
local function each(v, fn)
    if type(v) == "number" or type(v) == "boolean" then
        return fn(v)
    end
    return v:map(fn)
end

-- The wallpaper on screen now. A plain `current = true` builds the tag, popping in when `pop` is
-- set: showing a hidden node would cancel its animation.
function M.tag(opts, dress, u)
    if opts.current == false or opts.current == nil then return nil end
    return row {
        id = "current",
        visible = type(opts.current) ~= "boolean" and opts.current or true,
        align_v = "end",
        margin = { left = 7 * u, bottom = 7 * u },
        height = 19 * u,
        padding = { left = 6 * u, right = 6 * u },
        spacing = 3 * u,
        radius = 9.5 * u,
        background = dress.accent,
        origin = { x = 0, y = 0.5 },
        scale = 1,
        animate = opts.pop and POP or nil,
        children = {
            theme.glyph("check", 12 * u, dress.accent_ink, { weight = 700 }),
            text {
                content = "current",
                align_v = "center",
                font_size = 10 * u,
                font_weight = 700,
                letter_spacing = 0.4 * u,
                foreground = dress.accent_ink,
            },
        },
    }
end

-- opts: m (measure), picture, title, meta, scheme (nil until read), dress (worn without a
-- scheme), front (0..1), dim, current, favourite, pop (the "current" tag pops in), on_click, hover.
function M.card(opts)
    local m, u = opts.m, opts.m.u
    local dress = opts.scheme and colours.dress_of(opts.scheme) or opts.dress or theme.DRESS
    local specs = opts.scheme and colours.chips(opts.scheme) or {}
    local front = opts.front or 0
    local chips = {}
    for i = 1, 5 do
        local r = m.thumb_radius * 0.7
        local spec = specs[i]
        -- Not read yet: a quiet ramp of the card's own colour.
        local fill = spec and spec.fill or theme.tint(dress.raised, theme.alpha("#ffffff", 0.02 + 0.025 * (5 - i)))
        local ink = theme.ink_on(fill)
        chips[i] = rect {
            width = m.thumb.width,
            height = m.chip_h,
            radius = i == 1 and { top_left = r, top_right = r } or i == 5 and { bottom_left = r, bottom_right = r } or 0,
            background = fill,
            children = spec and {
                text {
                    align_v = "center",
                    margin = { left = 8 * u },
                    content = spec.label:upper(),
                    font_size = 8.5 * u,
                    font_weight = 700,
                    letter_spacing = 1.1 * u,
                    foreground = ink,
                    opacity = 0.85,
                },
                text {
                    align_h = "end",
                    align_v = "center",
                    margin = { right = 8 * u },
                    content = spec.fill:upper(),
                    font = theme.MONO,
                    font_size = 9.5 * u,
                    font_weight = 500,
                    foreground = ink,
                },
            } or {},
        }
    end
    return rect {
        width = m.width,
        height = m.height,
        radius = m.radius,
        background = dress.surface,
        border_width = each(front, function(f) return math.max(1, u * (1 + f * 0.6)) end),
        border_color = each(front, function(f)
            return theme.tint(theme.alpha(dress.line, 0.85), theme.alpha(dress.accent, f * 0.85))
        end),
        shadows = each(front, function(f)
            return { {
                color = theme.alpha("#000000", 0.42 + 0.18 * f),
                blur = (22 + 18 * f) * u,
                offset = { x = 0, y = (8 + 10 * f) * u },
            } }
        end),
        hover = opts.hover,
        cursor = "pointer",
        on_click = opts.on_click,
        animate = { border_width = 380, border_color = 380, shadows = 380 },
        children = {
            column {
                padding = { top = m.pad, left = m.pad, right = m.pad },
                children = {
                    rect {
                        width = m.thumb.width,
                        height = m.thumb.height,
                        radius = m.thumb_radius,
                        background = dress.raised,
                        children = {
                            theme.glyph("image", 22 * u, theme.alpha(dress.muted, 0.5)),
                            image {
                                width = "fill",
                                height = "fill",
                                radius = m.thumb_radius,
                                source = opts.picture,
                                async = true,
                            },
                            rect {
                                id = "favourite",
                                visible = opts.favourite or false,
                                align_h = "end",
                                margin = { top = 6 * u, right = 6 * u },
                                width = 24 * u,
                                height = 24 * u,
                                radius = 12 * u,
                                background = "#0000006b",
                                children = {
                                    theme.glyph("favorite", 14 * u, "#ff5c7a", { filled = true, translate = { x = 0, y = 0.5 * u } }),
                                },
                            },
                            M.tag(opts, dress, u),
                        },
                    },
                    column { margin = { top = 8 * u }, children = chips },
                    text {
                        margin = { top = 9 * u, left = 2 * u },
                        width = m.thumb.width - 4 * u,
                        content = opts.title,
                        elide = "end",
                        font_size = 13 * u,
                        font_weight = 600,
                        foreground = dress.ink,
                    },
                    text {
                        margin = { top = 2 * u, left = 2 * u },
                        width = m.thumb.width - 4 * u,
                        content = opts.meta,
                        elide = "end",
                        font_size = 10 * u,
                        foreground = dress.muted,
                    },
                },
            },
            -- Shade over a card further back, lifted while hovered.
            rect {
                width = "fill",
                height = "fill",
                radius = m.radius,
                background = "#000000",
                opacity = opts.dim or 0,
            },
        },
    }
end

return M
