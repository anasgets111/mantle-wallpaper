-- The hand: cards on arms turning round a pivot far below the screen.
--
-- Each card is built once, when it comes into the hand, and kept while it stays there; where it
-- sits follows signals. Rebuilding the hand on every step costs more than one evaluation's Lua
-- budget.
local cards = require("picker.card")
local colours = require("colours")
local P = require("picker.model")
local settings = P.settings
local SIDE = P.SIDE

-- What every arm reads: one table, recomputed once per change.
local hand_state = computed({ P.index, P.open, P.dealt, P.chosen, P.dealing }, function(idx, on, d, c, dl)
    return { idx = idx, open = on, dealt = d, picked = c, dealing = dl }
end)
local positions = P.entries:map(function(list)
    local at = {}
    for i, e in ipairs(list) do at[e.path] = i end
    return at
end)

-- One card in the hand. `moved` is how far the deck last moved, so a card coming in starts where
-- it was; 0 when the hand is dealt.
local function arm(k, e, moved, scheme, desk)
    local u, m = k.u, k.m
    local place = computed({ positions, hand_state }, function(pos, h)
        local d = (pos[e.path] or h.idx) - h.idx
        local ad = math.abs(d)
        return {
            d = d,
            ad = ad,
            s = d < 0 and -1 or 1,
            near = d == 0 and 1 or 0,
            down = not h.open or not h.dealt or h.picked ~= "",
            open = h.open,
            dealt = h.dealt,
            picked = h.picked,
            dealing = h.dealing,
        }
    end)
    local function tilt(p) return p.s * 0.1 * 180 / math.pi end
    local first = place:get()
    local entering = moved ~= 0
    local rotate_from = entering and P.theta(k, first.d + moved) or P.theta(k, first.d) + tilt(first)
    local hov = hover("picker.card:" .. e.path)
    local status = image_status("picker.card:" .. e.path)
    return rect {
        width = m.width,
        height = k.r + m.height / 2,
        -- The arm reaches far below the screen; only its card takes the pointer.
        hittable = false,
        origin = { x = 0.5, y = 1 },
        z = place:map(function(p) return 100 - p.ad end),
        rotate = place:map(function(p) return P.theta(k, p.d) + (p.down and tilt(p) or 0) end),
        translate = place:map(function(p) return { x = 0, y = p.down and k.lowered or 0 } end),
        opacity = place:map(function(p) return p.picked == e.path and 0 or 1 end),
        animate = place:map(function(p)
            local timing
            if not p.open then
                timing = { duration = 220, easing = "in_cubic", delay = (SIDE - p.ad) * 12 }
            elseif p.picked ~= "" then
                timing = { duration = 560, easing = "in_cubic" }
            elseif not p.dealt then
                timing = { duration = 170, easing = "in_quad" }
            else
                timing = { duration = 600, easing = "out_cubic", delay = math.floor(45 * p.ad) }
            end
            local rotate = { duration = 380, easing = "out_cubic", from = rotate_from }
            if p.dealing then
                rotate = { duration = timing.duration, easing = timing.easing, delay = timing.delay, from = rotate_from }
            end
            timing.from = { x = 0, y = entering and 0 or k.lowered }
            return {
                rotate = rotate,
                translate = timing,
                opacity = { duration = entering and 200 or 1, from = entering and 0 or 1 },
                exit = { duration = 380, easing = "out_cubic", opacity = 0, rotate = P.theta(k, p.s * (SIDE + 1)) },
            }
        end),
        children = {
            rect {
                translate = computed({ hov, place }, function(on, p)
                    return { x = 0, y = (on and p.near < 0.5) and -20 * u or 0 }
                end),
                animate = { translate = { duration = 170, easing = "out_cubic" } },
                children = {
                    rect {
                        scale = place:map(function(p) return 1 + (k.front_scale - 1) * p.near end),
                        translate = place:map(function(p) return { x = 0, y = -k.lift * p.near } end),
                        animate = {
                            scale = { duration = 380, easing = "out_cubic" },
                            translate = { duration = 380, easing = "out_cubic" },
                        },
                        children = {
                            cards.card {
                                m = m,
                                hover = hov,
                                picture = e.path,
                                scheme = scheme,
                                dress = desk,
                                title = P.base_name(e.name),
                                meta = status:map(function(s) return cards.meta(e, s) end),
                                status = status,
                                playing = computed({ place, P.live_playing }, function(p, live)
                                    return live and p.near == 1
                                end),
                                front = place:map(function(p) return p.near end),
                                dim = computed({ hov, place }, function(on, p)
                                    return on and 0 or math.min(0.3, math.max(0, p.ad - 0.6) * 0.065)
                                end),
                                current = settings.current:map(function(c) return c == e.path end),
                                favourite = settings.favorites:map(function(f) return P.has(f, e.name) end),
                                on_click = function()
                                    if P.drag.moved then return end
                                    local i = positions:get()[e.path]
                                    if not i then return end
                                    if i == P.index:get() then P.pick() else P.go(i) end
                                end,
                                on_double_click = function()
                                    local i = positions:get()[e.path]
                                    if not i then return end
                                    P.go(i)
                                    P.pick()
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
    local m = k.m
    -- path -> { node, look }: a card is rebuilt only when its colours change. `each` builds them:
    -- it runs outside the Lua budget a map has, and building a whole hand takes longer than that.
    local built = {}
    local window = computed({ P.entries, P.index }, function(list, idx)
        local out = {}
        for i = math.max(1, idx - SIDE), math.min(#list, idx + SIDE) do out[#out + 1] = list[i] end
        return out
    end, {})
    return rect {
        width = "fill",
        height = "fill",
        hittable = false,
        translate = P.peeking:map(function(on) return { x = 0, y = on and k.peek_drop or 0 } end),
        animate = { translate = { duration = 300, easing = "out_cubic" } },
        children = {
            -- The arms all stand on the same spot: each one's width is taken back by the spacing.
            list {
                direction = "horizontal",
                spacing = -m.width,
                margin = { left = k.pivot_x - m.width / 2, top = k.pivot_y - k.r - m.height / 2 },
                items = window,
                key = function(e) return e.path end,
                each = function(e)
                    local scheme = colours.scheme(colours.known:get(), e.name)
                    local desk = colours.desktop_dress:get()
                    -- Each opening deals a new hand.
                    local deal = P.deal:get()
                    local look = deal .. (scheme and scheme.source or "") .. desk.accent .. desk.surface
                    local have = built[e.path]
                    if not have or have.look ~= look then
                        local fresh = not have or have.deal ~= deal
                        have = { node = arm(k, e, fresh and P.shift:get() or 0, scheme, desk), look = look, deal = deal }
                        built[e.path] = have
                        -- Cards that left the hand start fresh when they come back.
                        local keep = {}
                        for _, w in ipairs(window:get()) do keep[w.path] = true end
                        for path in pairs(built) do
                            if not keep[path] then built[path] = nil end
                        end
                    end
                    return have.node
                end,
            },
        },
    }
end

return deck
