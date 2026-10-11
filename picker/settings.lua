-- The gear's settings card, under the head on the right: the wallpaper folder, the transition, and
-- whether a chosen card grows into the wallpaper.
local theme = require("theme")
local P = require("picker.model")
local chrome = require("picker.chrome")

local settings, wallpaper, tint, C = P.settings, P.wallpaper, P.tint, chrome.C
local ERROR = "#ffb4ab"

-- "", "checking", "missing", "failed", "relative" or "saved".
local status = state("picker.folder.status", "")
local draft = state("picker.folder.draft", "")
local pending = "" -- the folder last asked for: a later Enter wins over an earlier answer

-- Each opening starts clean.
P.settings_open:on_change(function(on)
    if on then
        status:set("")
        draft:set("")
    end
end)

local function count_line(n) return (n == 1 and "1 wallpaper" or n .. " wallpapers") .. " here." end

local function use_folder(typed)
    if typed ~= pending then return end
    settings:set("dir", typed)
    status:set("saved")
end

local function apply_folder(text)
    local typed = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
    -- A submit empties the field: put the text back.
    focus_target("picker.folder"):set_text(typed ~= "" and typed or settings.dir:get())
    if typed == "" or typed == settings.dir:get() then return status:set("") end
    local abs = wallpaper.expand(typed)
    if abs:sub(1, 1) ~= "/" then return status:set("relative") end
    pending = typed
    status:set("checking")
    process.capture("test", { "-d", abs }, function(_, code)
        if typed ~= pending then return end
        if code == 0 then use_folder(typed) else status:set("missing") end
    end)
end

local function create_folder()
    local typed = pending
    status:set("checking")
    process.capture("mkdir", { "-p", wallpaper.expand(typed) }, function(_, code)
        if typed ~= pending then return end
        if code == 0 then use_folder(typed) else status:set("failed") end
    end)
end

local function label(content, u)
    return text {
        content = content,
        font_size = 11 * u,
        font_weight = 700,
        letter_spacing = 1.2 * u,
        foreground = C("muted"),
    }
end

local function note(content, color, u)
    return text {
        width = "fill",
        wrap = "word",
        content = content,
        font_size = 12 * u,
        foreground = color or C("muted"),
    }
end

-- `selected`: a boolean signal, or `true` for an action chip that always wears the accent.
local function chip(id, content, selected, u, on_click)
    if selected == true then selected = tint:map(function() return true end) end
    local hov = hover("picker.settings.chip:" .. id)
    return rect {
        height = 28 * u,
        padding = { left = 11 * u, right = 11 * u },
        radius = 14 * u,
        hover = hov,
        background = computed({ selected, hov, tint }, function(on, over, d)
            if on then return over and theme.lighter(d.accent, 1.08) or d.accent end
            return theme.alpha(d.ink, over and 0.12 or 0.06)
        end),
        on_click = on_click,
        children = {
            text {
                align_v = "center",
                content = content,
                font_size = 12 * u,
                font_weight = 600,
                foreground = computed({ selected, tint }, function(on, d) return on and d.accent_ink or d.ink end),
            },
        },
    }
end

local function folder_section(u)
    local edited = computed({ draft, settings.dir }, function(t, d) return t ~= "" and t:gsub("/+$", "") ~= d end)
    local field_focus = focused("picker.folder")
    return {
        label("WALLPAPER FOLDER", u),
        rect {
            width = "fill",
            height = 40 * u,
            radius = 12 * u,
            padding = { left = 14 * u, right = 14 * u },
            background = C("ink", 0.06),
            border_width = 1,
            border_color = computed({ field_focus, tint }, function(on, d) return on and d.accent or
                theme.alpha(d.ink, 0.12) end),
            children = {
                textfield {
                    focus_target = focus_target("picker.folder"),
                    focused = field_focus,
                    accessible_name = "Wallpaper folder",
                    autofocus = true,
                    width = "fill",
                    align_v = "center",
                    foreground = C("ink"),
                    placeholder = "~/Pictures/wallpapers",
                    placeholder_color = C("muted", 0.7),
                    selection = tint:map(function(d) return { background = theme.alpha(d.accent, 0.4) } end),
                    font_size = 13 * u,
                    initial_text = settings.dir:get(),
                    escape = "pass",
                    on_change = function(t)
                        draft:set(t)
                        status:set("")
                    end,
                    on_submit = apply_folder,
                },
            },
        },
        note(
            computed({ status, edited, P.listing }, function(s, e, all)
                if s == "checking" then return "Looking for it…" end
                if s == "missing" then return "There's no folder there yet." end
                if s == "failed" then return "Couldn't create that folder." end
                if s == "relative" then return "Use a full path, or one starting with ~/" end
                if e then return "Enter to use this folder" end
                return count_line(#all)
            end),
            computed({ status, tint }, function(s, d)
                return (s == "missing" or s == "failed" or s == "relative") and ERROR or d.muted
            end),
            u
        ),
        row {
            visible = status:map(function(s) return s == "missing" end),
            children = { chip("create", "Create it and use it", true, u, create_folder) },
        },
    }
end

local function transition_section(u)
    local options = { { "random", "Random" } }
    for _, name in ipairs(wallpaper.TRANSITIONS) do
        options[#options + 1] = { name, name:sub(1, 1):upper() .. name:sub(2) }
    end
    local chips = {}
    for _, o in ipairs(options) do
        local key = o[1]
        chips[#chips + 1] = chip(key, o[2], settings.transition:map(function(t) return t == key end), u, function()
            settings:set("transition", key)
        end)
    end
    return {
        label("TRANSITION", u),
        row { width = "fill", wrap = true, spacing = 6 * u, line_spacing = 6 * u, children = chips },
        note("How a new wallpaper replaces the one on screen; Random picks another look each time.", nil, u),
    }
end

local function choice_section(u)
    local on = settings.animate_choice
    local hov = hover("picker.settings.animate")
    local inset = 3 * u
    return {
        label("SETTING A WALLPAPER", u),
        rect {
            width = "fill",
            height = 40 * u,
            radius = 12 * u,
            hover = hov,
            background = computed({ hov, tint }, function(over, d) return theme.alpha(d.ink, over and 0.1 or 0.06) end),
            border_width = 1,
            border_color = C("ink", 0.12),
            on_click = function() settings:set("animate_choice", not on:get()) end,
            children = {
                text {
                    align_v = "center",
                    margin = { left = 14 * u, right = 62 * u },
                    width = "fill",
                    elide = "end",
                    content = "Grow the chosen card into the wallpaper",
                    font_size = 13 * u,
                    foreground = C("ink"),
                },
                rect {
                    align_h = "end",
                    align_v = "center",
                    margin = { right = 8 * u },
                    width = 42 * u,
                    height = 24 * u,
                    radius = 12 * u,
                    background = computed({ on, tint }, function(x, d) return x and d.accent or theme.alpha(d.ink, 0.16) end),
                    animate = { background = 160 },
                    children = {
                        rect {
                            align_v = "center",
                            margin = { left = inset },
                            width = 24 * u - inset * 2,
                            height = 24 * u - inset * 2,
                            radius = 12 * u - inset,
                            background = computed({ on, tint }, function(x, d) return x and d.accent_ink or d.ink end),
                            translate = on:map(function(x) return { x = x and 18 * u or 0, y = 0 } end),
                            animate = { translate = { duration = 160, easing = "out_cubic" } },
                        },
                    },
                },
            },
        },
        note(on:map(function(x)
            return x and
                "The card comes to the middle of the screen and grows into the wallpaper, then the picker closes."
                or "The wallpaper changes straight away and the deck stays open, for more browsing."
        end), nil, u),
    }
end

local function card(k)
    local u = k.u
    local close_hover = hover("picker.settings.close")
    local body = {
        row {
            width = "fill",
            height = 32 * u,
            spacing = 10 * u,
            children = {
                theme.glyph("settings", 20 * u, C("accent"), { filled = true }),
                text {
                    align_v = "center",
                    width = "fill",
                    content = "Picker settings",
                    font_size = 16 * u,
                    font_weight = 700,
                    foreground = C("ink"),
                },
                rect {
                    align_v = "center",
                    width = 32 * u,
                    height = 32 * u,
                    radius = 16 * u,
                    hover = close_hover,
                    background = computed({ close_hover, tint }, function(over, d)
                        return over and theme.alpha(d.ink, 0.1) or "#00000000"
                    end),
                    on_click = function() P.set_settings(false) end,
                    children = { theme.glyph("close", 18 * u, C("ink")) },
                },
            },
        },
        rect { height = 4 * u },
    }
    for i, section in ipairs({ folder_section(u), transition_section(u), choice_section(u) }) do
        if i > 1 then body[#body + 1] = rect { height = 8 * u } end
        table.move(section, 1, #section, #body + 1, body)
    end
    return column {
        id = "settings",
        align_h = "end",
        margin = { right = 40 * u, top = (28 + 44 + 12) * u },
        width = 460 * u,
        padding = 20 * u,
        spacing = 8 * u,
        radius = 20 * u,
        z = 10,
        hittable = true,
        background = C("low", 0.95),
        border_width = 1,
        border_color = C("ink", 0.12),
        -- Clicks and the wheel stay on the card.
        on_click = function() end,
        on_wheel = function() end,
        children = body,
    }
end

-- Built while open, so the field takes focus as it appears.
local function layer(k)
    return rect {
        width = "fill",
        height = "fill",
        hittable = false,
        -- Over the ribbon, as the card hangs across it.
        z = 10,
        children = computed({ P.settings_open, P.peeking, P.chosen }, function(on, p, c)
            if not on or p or c ~= "" then return {} end
            return { card(k) }
        end),
    }
end

return layer
