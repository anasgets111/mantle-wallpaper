-- Colours: "#rrggbb[aa]" helpers in the shape Qt's colour functions had, and the picker's dress.
local M = {}

local function parse(c)
    local r, g, b, a = c:match("^#(%x%x)(%x%x)(%x%x)(%x?%x?)$")
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, a == "" and 1 or tonumber(a, 16) / 255
end

local function hex(r, g, b, a)
    local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return string.format("#%02x%02x%02x%02x", byte(r), byte(g), byte(b), byte(a or 1))
end
M.hex = hex

-- `c` with alpha `a`.
function M.alpha(c, a)
    local r, g, b = parse(c)
    return hex(r, g, b, a)
end

-- `over` laid on `base` (Qt.tint).
function M.tint(base, over)
    local r1, g1, b1, a1 = parse(base)
    local r2, g2, b2, a2 = parse(over)
    return hex(r1 + (r2 - r1) * a2, g1 + (g2 - g1) * a2, b1 + (b2 - b1) * a2, a1)
end

-- Brighter by `f` (Qt.lighter scales HSV value).
function M.lighter(c, f)
    local r, g, b, a = parse(c)
    local v = math.max(r, g, b)
    local k = v > 0 and math.min(f, 1 / v) or 1
    return hex(r * k, g * k, b * k, a)
end

-- Ink that reads on `c`.
function M.ink_on(c)
    local r, g, b = parse(c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.5 and "#000000c7" or "#ffffffe6"
end

-- `c` as a shader `vec3`.
function M.rgb(c)
    local r, g, b = parse(c)
    return { r, g, b }
end

-- The dress when no wallpaper scheme is read: the Material defaults the QML fell back to.
M.DRESS = {
    surface = "#211f24",
    raised = "#2b292f",
    low = "#1d1b20",
    highest = "#36343a",
    ink = "#e6e0e9",
    muted = "#cac4cf",
    line = "#49454e",
    accent = "#d0bcfe",
    accent_ink = "#36265d",
}

M.ICONS = "Material Symbols Rounded"
M.MONO = "JetBrainsMono Nerd Font"

-- A Material Symbols glyph by ligature name.
function M.glyph(name, size, color, opts)
    opts = opts or {}
    return text {
        content = name,
        font = M.ICONS,
        font_size = size,
        foreground = color,
        font_variations = opts.variations or { FILL = opts.filled and 1 or 0, wght = opts.weight or 500 },
        align_h = opts.align_h or "center",
        align_v = opts.align_v or "center",
        translate = opts.translate,
    }
end

return M
