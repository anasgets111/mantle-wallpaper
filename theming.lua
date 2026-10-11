-- The wallpaper on screen colours the desktop: its scheme is read on each change, written to
-- ~/.cache/mantle-wallpaper/colors.json (every role, dark and light), and rendered into the
-- settings' matugen-style templates, each followed by its hook.
local colours = require("colours")
local wallpaper = require("wallpaper")

local settings = wallpaper.settings
local COLORS = "~/.cache/mantle-wallpaper/colors.json"

-- `{{colors.<role>.<default|dark|light>.<hex|hex_stripped|rgb|rgba>}}`; anything else stays.
local function format(hex, how)
    local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
    if how == "hex" then return hex end
    if how == "hex_stripped" then return hex:sub(2) end
    if how == "rgb" then return string.format("rgb(%d, %d, %d)", r, g, b) end
    if how == "rgba" then return string.format("rgba(%d, %d, %d, 1.0)", r, g, b) end
end

local function render(template, schemes)
    return (template:gsub("{{%s*colors%.([%w_]+)%.(%w+)%.([%w_]+)%s*}}", function(role, which, how)
        local scheme = schemes[which == "default" and "dark" or which]
        local hex = scheme and scheme[role]
        return hex and format(hex, how) or nil
    end))
end

local function apply(seed, dark)
    local schemes = { dark = dark, light = palette.scheme(seed, { dark = false }) }
    file.write(COLORS, json.encode({ seed = seed, dark = dark, light = schemes.light }))
    for _, t in ipairs(settings.templates:get() or {}) do
        file.read(t.input, function(text, err)
            if not text then return log.warn("template " .. t.input .. ": " .. err) end
            file.write(t.output, render(text, schemes), function(changed)
                if changed and t.hook then process.detach("sh", { "-c", t.hook }) end
            end)
        end)
    end
end

local shown = nil
local function follow()
    local path = settings.current:get()
    if path == shown or path == "" then return end
    shown = path
    colours.read(path, function(seed, dark)
        if shown ~= path or not dark then return end
        colours.desktop:set(dark)
        apply(seed, dark)
    end)
end
follow()
mantle.storage:on_change(follow)
