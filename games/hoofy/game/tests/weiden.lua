-- Selbsttests für Zäune und Weiden (Aufgabe C2): geschlossene Flächen, Tor, Plätze, Umbau.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local C = require("game.tests.check")

local function setup(money)
  Area.clear()
  local ctx = Stage.build(1, 6)
  ctx.money = money or 5000
  local p = ctx.area.plot
  ctx.player.x, ctx.player.y = (p.x + 1) * 16, (p.y + 1) * 16
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  return ctx, p
end

local function pastures(ctx) return Farm.pastures(ctx.map, ctx.area.farm) end

return {
  {"Startweide: 40 Kacheln, 4 Plätze, der offene Hof ist keine Weide", function()
    local ctx = setup()
    local list = pastures(ctx)
    C.eq(#list, 1)
    C.eq(list[1].n, 40)
    C.eq(list[1].plaetze, 4)
    C.eq(Farm.capacity(ctx.area.farm).weide, 4)
  end},
  {"Geschlossener Zaunring mit Tor = Weide, ohne Tor nicht, Plätze = Fläche / 10", function()
    local ctx, p = setup()
    Farm.fence_rect(ctx, p.x + 14, p.y + 10, p.x + 19, p.y + 15, {p.x + 16, p.y + 10})      -- innen 4 × 4 = 16
    Farm.fence_rect(ctx, p.x + 14, p.y + 2, p.x + 18, p.y + 6, nil)                           -- ohne Tor
    local list = pastures(ctx)
    C.eq(#list, 2, "Startweide + neue, die Koppel ohne Tor zählt nicht")
    local neu
    for _, w in ipairs(list) do if w.n == 16 then neu = w end end
    C.ok(neu, "neue Weide mit 16 Kacheln")
    C.eq(neu.plaetze, 1)
    C.eq(Farm.capacity(ctx.area.farm).weide, 5)
    -- Tor in die Koppel: jetzt zählt sie (innen 3 × 3 = 9 Kacheln, 0 Plätze)
    Farm.remove(ctx, p.x + 16, p.y + 2)
    C.ok(Farm.place(ctx, "tor", p.x + 16, p.y + 2))
    local list2 = pastures(ctx)
    C.eq(#list2, 3)
    local klein
    for _, w in ipairs(list2) do if w.n == 9 then klein = w end end
    C.ok(klein and klein.plaetze == 0, "9 Kacheln = 0 Plätze")
    C.eq(Farm.capacity(ctx.area.farm).weide, 5)
  end},
  {"Lücke im Zaun öffnet die Weide, Schließen macht sie wieder zu; Tor in der Lücke genügt nicht ohne Zaun", function()
    local ctx, p = setup()
    Farm.fence_rect(ctx, p.x + 14, p.y + 10, p.x + 19, p.y + 15, {p.x + 16, p.y + 10})
    C.eq(#pastures(ctx), 2)
    C.ok(Farm.remove(ctx, p.x + 19, p.y + 13))
    C.eq(#pastures(ctx), 1, "Lücke rechts: offen")
    C.ok(Farm.place(ctx, "zaun", p.x + 19, p.y + 13))
    C.eq(#pastures(ctx), 2, "wieder geschlossen")
    local base = string.byte("A")
    C.eq(ctx.map.coll[p.y + 14]:sub(p.x + 20, p.x + 20), string.char(base + 4 + 8), "Zaunform wieder mit oberem und unterem Nachbarn")
  end},
  {"Hindernisse in der Weide zählen nicht zur Fläche", function()
    local ctx, p = setup()
    Farm.fence_rect(ctx, p.x + 14, p.y + 10, p.x + 19, p.y + 15, {p.x + 16, p.y + 10})
    Farm.place(ctx, "bank", p.x + 16, p.y + 12)
    Farm.place(ctx, "busch", p.x + 17, p.y + 13)
    local list = pastures(ctx)
    local neu
    for _, w in ipairs(list) do if w.n ~= 40 then neu = w end end
    C.eq(neu.n, 14, "16 − Bank − Busch")
  end},
  {"Ganzes Grundstück einzäunen: der Hof wird zur großen Weide", function()
    local ctx, p = setup(20000)
    local before = pastures(ctx)
    C.eq(#before, 1)
    ctx.player.x, ctx.player.y = (p.x + 10) * 16 + 8, (p.y + 8) * 16 + 8        -- mitten im Hof
    Farm.fence_rect(ctx, p.x, p.y, p.x + p.w - 1, p.y + p.h - 1, {p.x + 10, p.y})
    local list = pastures(ctx)
    C.ok(#list >= 1)
    local big
    for _, w in ipairs(list) do if w.n > 100 then big = w end end
    C.ok(big, "große Weide")
    C.ok(big.plaetze >= 10, "viele Plätze: " .. tostring(big and big.plaetze))
  end},
  {"Unterbringen auf der zweiten Weide: Plätze je Weide, voll, Pferde bleiben drin", function()
    local ctx, p = setup()
    local w = ctx.wild
    Farm.fence_rect(ctx, p.x + 14, p.y + 10, p.x + 19, p.y + 15, {p.x + 16, p.y + 10})
    local hs = {}
    for i = 1, 6 do hs[i] = w:add_own({name = "P" .. i}) end
    for i = 1, 5 do C.ok(w:house(hs[i], "weide"), "Pferd " .. i) end
    C.eq(Farm.capacity(ctx.area.farm).weide, 5)
    local ok, why = w:house(hs[6], "weide")
    C.ok(not ok and why == "voll", "sechstes Pferd")
    local on_new, on_base = 0, 0
    for i = 1, 5 do
      if hs[i].data.weide_id == pastures(ctx)[1].id then on_base = on_base + 1 else on_new = on_new + 1 end
    end
    C.eq(on_base, 4)
    C.eq(on_new, 1)
    local ps = pastures(ctx)
    for _ = 1, 1500 do
      ctx.world:update()
      for i = 1, 5 do
        local ok2 = false
        for _, pa in ipairs(ps) do if Farm.in_pasture(pa, hs[i].x, hs[i].y) then ok2 = true end end
        C.ok(ok2, "Pferd " .. i .. " verlässt seine Weide")
      end
    end
  end},
  {"Weide abreißen: Pferde ziehen um oder kommen an die Leine", function()
    local ctx, p = setup()
    local w = ctx.wild
    Farm.fence_rect(ctx, p.x + 14, p.y + 10, p.x + 19, p.y + 15, {p.x + 16, p.y + 10})
    local hs = {}
    for i = 1, 5 do hs[i] = w:add_own({name = "P" .. i}); w:house(hs[i], "weide") end
    local neue
    for _, pa in ipairs(pastures(ctx)) do if pa.n == 16 then neue = pa end end
    C.eq(Farm.count_pasture(ctx.herd, neue.id), 1)
    Farm.remove(ctx, p.x + 19, p.y + 13)                     -- Lücke: neue Weide fällt weg
    local lost = w:rehome()
    C.eq(#lost, 1, "ein Pferd verliert die Weide")
    local leashed = 0
    for _, h in ipairs(hs) do if not h.data.ort then leashed = leashed + 1 end end
    C.eq(leashed, 1)
    C.eq(Farm.count(ctx.herd, "weide"), 4)
    C.eq(Farm.capacity(ctx.area.farm).weide, 4)
  end},
  {"Spielstand: Weiden aus den Bauten wieder erkannt, Pferd weiß seine Weide", function()
    local Save = require("game.save")
    local Clock = require("game.clock")
    local ctx, p = setup()
    Farm.fence_rect(ctx, p.x + 14, p.y + 10, p.x + 19, p.y + 15, {p.x + 16, p.y + 10})
    local h = ctx.wild:add_own({name = "Hilde"})
    ctx.wild:house(h, "weide")
    local snap = Save.snapshot(ctx, Clock.new(1, 0), 6)
    local back = load("return " .. Save.encode(snap), "=x", "t", {})()
    Area.clear()
    local ctx2 = Stage.build(1, 6, back.hof)
    ctx2.wild = Wild.new(ctx2, 3)
    ctx2.wild.count = 0
    C.eq(#Farm.pastures(ctx2.map, ctx2.area.farm), #pastures(ctx), "gleiche Weiden")
    C.eq(Farm.capacity(ctx2.area.farm).weide, 5)
    local d = back.herd[1]
    local hh = ctx2.wild:adopt(d)
    C.eq(d.ort, "weide")
    C.ok(hh.allow, "Pferd wieder auf der Weide eingegrenzt")
  end},
  {"Weidetor: allein kommt kein Pferd durch, an der Leine schon", function()
    local ctx = setup()
    local g = ctx.area.farm.weide.gate
    local h = ctx.wild:add_own({rasse = "haflinger", bindung = 40})
    ctx.wild:house(h, "weide")
    h.x, h.y = g[1] * 16 + 8, (g[2] + 1) * 16 + 14          -- in der Weide direkt unter dem Tor
    for _ = 1, 60 do h:step(0, -1) end
    C.ok(h.y > (g[2] + 1) * 16, "Weidepferd bleibt drin")
    ctx.wild:release(h)
    h.data.ort, h.allow = nil, nil                            -- lose, ohne Weidengrenze
    for _ = 1, 60 do h:step(0, -1) end
    C.ok(h.y > (g[2] + 1) * 16, "loses Pferd geht nicht durchs Tor")
    h.state = "led"
    for _ = 1, 60 do h:step(0, -1) end
    C.ok(h.y < g[2] * 16, "an der Leine durchs Tor")
  end},
}
