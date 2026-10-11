-- The wallpaper on every output, and the commands that change it:
--   mantle call wallpaper.set <file>   absolute, ~/, file:// or a name inside the folder
--   mantle call wallpaper.current
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
    },
}

function M.expand(path)
    return (path:gsub("^~/", HOME .. "/"))
end

local mode = state("wallpaper.mode", MODE.grow)

local function pick_mode()
    local name = M.settings.transition:get()
    if MODE[name] then
        return MODE[name]
    end
    -- "random", or an unknown name: any look but the last one.
    local next_mode = math.random(0, #M.TRANSITIONS - 2)
    return next_mode >= mode:get() and next_mode + 1 or next_mode
end

function M.set(path)
    path = tostring(path or ""):gsub("^file://", "")
    if path == "" then
        return nil
    end
    if not path:find("^[/~]") then
        path = M.settings.dir:get() .. "/" .. path
    end
    path = M.expand(path)
    if path ~= M.settings.current:get() then
        mode:set(pick_mode())
        M.settings:set("current", path)
    end
    return path
end

action("wallpaper.set", M.set)
action("wallpaper.current", function() return M.settings.current:get() end)

-- ponytail: a fixed accent until the palette slice derives one from the wallpaper.
local ACCENT = { 0.80, 0.65, 0.97 }

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
        transition = mode:map(function(m)
            local name = M.TRANSITIONS[m + 1]
            return {
                duration = DURATION[name] or 1100,
                easing = "in_out_cubic",
                shader = mantle.config_dir .. "/shaders/transition.frag",
                params = { mode = m, edge_color = ACCENT },
            }
        end),
    },
}

return M
