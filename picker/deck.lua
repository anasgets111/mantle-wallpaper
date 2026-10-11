-- The hand: cards on arms turning round a pivot far below the screen.
local cards = require("picker.card")
local colours = require("colours")
local P = require("picker.model")
local settings = P.settings
local SIDE = P.SIDE
local open = P.open
local index = P.index
local shift = P.shift
local peek = P.peek
local dealt = P.dealt
local chosen = P.chosen
local dealing = P.dealing
local drag = P.drag
local base_name = P.base_name
local has = P.has
local entries = P.entries
local theta = P.theta
local go = P.go
local pick = P.pick

-- One card in the hand, on an arm that turns round the pivot far below the screen.
-- `at`: what the hand is doing this pass (idx, moved, open, dealt, picked, dealing, known, desk).
local function arm(k, e, i, at)
    local idx, moved, is_open, is_dealt, picked, is_dealing = at.idx, at.moved, at.open, at.dealt, at.picked, at.dealing
    local u, m = k.u, k.m
    local d = i - idx
    local ad = math.abs(d)
    local s = d < 0 and -1 or 1
    local near = d == 0 and 1 or 0
    local down = not is_open or not is_dealt or picked ~= ""
    local deal_tilt = s * 0.1 * 180 / math.pi
    local timing
    if not is_open then
        timing = { duration = 220, easing = "in_cubic", delay = (SIDE - ad) * 12 }
    elseif picked ~= "" then
        timing = { duration = 560, easing = "in_cubic" }
    elseif not is_dealt then
        timing = { duration = 170, easing = "in_quad" }
    else
        timing = { duration = 600, easing = "out_cubic", delay = math.floor(45 * ad) }
    end
    local hov = hover("picker.card:" .. e.path)
    local entering = moved ~= 0
    local rotate = {
        duration = 380,
        easing = "out_cubic",
        from = entering and theta(k, d + moved) or theta(k, d) + deal_tilt,
    }
    if is_dealing then
        rotate = { duration = timing.duration, easing = timing.easing, delay = timing.delay, from = rotate.from }
    end
    timing.from = { x = 0, y = entering and 0 or k.lowered }
    return rect {
        id = e.path,
        width = m.width,
        height = k.r + m.height / 2,
        margin = { left = k.pivot_x - m.width / 2, top = k.pivot_y - k.r - m.height / 2 },
        origin = { x = 0.5, y = 1 },
        z = 100 - ad,
        rotate = theta(k, d) + (down and deal_tilt or 0),
        translate = { x = 0, y = down and k.lowered or 0 },
        opacity = e.path == picked and 0 or 1,
        animate = {
            rotate = rotate,
            translate = timing,
            opacity = { duration = entering and 200 or 1, from = entering and 0 or 1 },
            exit = { duration = 380, easing = "out_cubic", opacity = 0, rotate = theta(k, s * (SIDE + 1)) },
        },
        children = {
            -- Hovered, a card further back lifts.
            rect {
                translate = hov:map(function(on) return { x = 0, y = (on and near < 0.5) and -20 * u or 0 } end),
                animate = { translate = { duration = 170, easing = "out_cubic" } },
                children = {
                    rect {
                        scale = 1 + (k.front_scale - 1) * near,
                        translate = { x = 0, y = -k.lift * near },
                        animate = {
                            scale = { duration = 380, easing = "out_cubic" },
                            translate = { duration = 380, easing = "out_cubic" },
                        },
                        children = {
                            cards.card {
                                m = m,
                                hover = hov,
                                picture = e.path,
                                scheme = colours.scheme(at.known, e.name),
                                dress = at.desk,
                                title = base_name(e.name),
                                meta = (e.name:match("%.([^.]+)$") or ""):upper(),
                                front = near,
                                dim = hov:map(function(on) return on and 0 or math.min(0.3, math.max(0, ad - 0.6) * 0.065) end),
                                current = settings.current:map(function(c) return c == e.path end),
                                favourite = settings.favorites:map(function(f) return has(f, e.name) end),
                                on_click = function()
                                    if drag.moved then return end
                                    if i == index:get() then pick() else go(i) end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
end

local function deck(k)
    return rect {
        width = "fill",
        height = "fill",
        translate = peek:map(function(on) return { x = 0, y = on and k.peek_drop or 0 } end),
        animate = { translate = { duration = 300, easing = "out_cubic" } },
        children = computed(
            { entries, index, shift, open, dealt, chosen, dealing, colours.known, colours.desktop_dress },
            function(list, idx, moved, is_open, is_dealt, picked, is_dealing, known, desk)
                local at = {
                    idx = idx, moved = moved, open = is_open, dealt = is_dealt, picked = picked,
                    dealing = is_dealing, known = known, desk = desk,
                }
                local out = {}
                for i = math.max(1, idx - SIDE), math.min(#list, idx + SIDE) do
                    out[#out + 1] = arm(k, list[i], i, at)
                end
                return out
            end
        ),
    }
end

return deck
