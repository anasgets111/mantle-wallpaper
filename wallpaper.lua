-- The wallpaper on every output, and the commands that change it:
--   mantle call wallpaper.set <file>   absolute, ~/, file:// or a name inside the folder
--   mantle call wallpaper.current
local theme = require("theme")
local colours = require("colours")

local M = {}

local HOME = os.getenv("HOME") or ""

-- The `mode` uniform in shaders/transition.frag, by name.
M.TRANSITIONS = {
    "grow", "tiles", "scan", "warp", "fade", "ink", "glitch", "fusuma",
    "fan", "glass", "press", "dust", "rule", "tide", "lotus", "fire",
}
local MODE = {}
for i, name in ipairs(M.TRANSITIONS) do
    MODE[name] = i - 1
end
-- ms; the slower looks need longer to read.
local DURATION = {
    tiles = 1300, fade = 1500, glitch = 950, fusuma = 1400, fan = 1400, glass = 1500, press = 1600,
    dust = 1500, rule = 1500, tide = 1600, lotus = 1500, fire = 1600,
}

M.settings = persistent_table {
    path = "~/.local/state/mantle-wallpaper/settings.json",
    defaults = {
        dir = "~/Pictures/wallpapers",
        current = "",
        transition = "random", -- a name from TRANSITIONS, or "random"
        favorites = {}, -- file names
        animate_choice = true, -- a chosen card grows into the wallpaper, then the picker closes
        -- matugen-style templates rendered with the wallpaper's colours on each change:
        -- { { input = "~/x.tpl", output = "~/.config/x", hook = "shell command" }, ... }
        templates = {},
    },
}

function M.expand(path)
    return (path:gsub("^~/", HOME .. "/"))
end

local mode = state("wallpaper.mode", MODE.grow)
-- True while the picker covers the screen: the change goes in at once, under it.
M.instant = state("wallpaper.instant", false)

local function pick_mode()
    local name = M.settings.transition:get()
    if MODE[name] then
        return MODE[name]
    end
    -- "random", or an unknown name: any look but the last one.
    local next_mode = math.random(0, #M.TRANSITIONS - 2)
    return next_mode >= mode:get() and next_mode + 1 or next_mode
end

function M.set(path, instant)
    path = tostring(path or ""):gsub("^file://", "")
    if path == "" then
        return nil
    end
    if not path:find("^[/~]") then
        path = M.settings.dir:get() .. "/" .. path
    end
    path = M.expand(path)
    if path ~= M.settings.current:get() then
        M.instant:set(instant == true)
        mode:set(pick_mode())
        M.settings:set("current", path)
    end
    return path
end

action("wallpaper.set", function(path) return M.set(path) end)
action("wallpaper.current", function() return M.settings.current:get() end)

M.panel = panel {
    id = "wallpaper",
    layer = "background",
    anchor = { top = true, bottom = true, left = true, right = true },
    exclusive_zone = "ignore",
    width = "fill",
    height = "fill",
    child = image {
        id = "wallpaper_image",
        width = "fill",
        height = "fill",
        async = true,
        source = M.settings.current,
        transition = computed({ mode, M.instant, colours.desktop_dress }, function(m, instant, dress)
            local name = M.TRANSITIONS[m + 1]
            return {
                duration = instant and 1 or DURATION[name] or 1100,
                easing = "in_out_cubic",
                shader = mantle.config_dir .. "/shaders/transition.frag",
                params = { mode = m, edge_color = theme.rgb(dress.accent) },
            }
        end),
    },
}

return M
