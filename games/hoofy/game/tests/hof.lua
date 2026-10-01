-- Selbsttests für den Hof (Aufgabe A11): Plätze, Unterbringung, Tagesverluste.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local H = require("game.horse_model")
local C = require("game.tests.check")

local function setup()
  local ctx = Stage.build(1)
  local w = Wild.new(ctx, 3)
  w.count = 0
  return ctx, w
end

local function strong(h)
  for _, k in ipairs(H.STATS) do h.data.gen[k], h.data.pot[k] = 70, 100 end
  h.data.bindung = 80
end

return {
  {"Startweide: Zaun und Tor sind normale Bauteile, abreißbar ohne Erstattung; Weide lässt sich vergrößern (Rückmeldung 1.3.3)", function()
    Area.clear()
    local ctx = Stage.build(1, 31)
    local farm, map = ctx.area.farm, ctx.map
    ctx.inv, ctx.herd = {}, {}
    local w = farm.weide
    C.ok(w.umgebaut, "umgebaut")
    local n = 0
    for _, it in ipairs(farm.items) do if it.start then n = n + 1 end end
    C.eq(n, 2 * (w.x1 - w.x0 + 1) + 2 * (w.y1 - w.y0 - 1), "ganzer Ring als Bauteile")
    C.eq(Farm.item_at(farm, w.gate[1], w.gate[2]).id, "tor")
    local plaetze = Farm.pastures(map, farm)[1].plaetze
    C.eq(plaetze, 4, "wie vorher")
    -- rechte Seite abreißen und 4 Spalten weiter rechts neu ziehen: größere Weide
    ctx.money = 1000
    for y = w.y0, w.y1 do C.eq(Farm.remove(ctx, w.x1, y), 0, "Startzaun bringt nichts") end
    C.eq(ctx.money, 1000)
    C.eq(#Farm.pastures(map, farm), 0, "offen: keine Weide")
    for x = w.x1, w.x1 + 4 do C.ok(Farm.place(ctx, "zaun", x, w.y0)) C.ok(Farm.place(ctx, "zaun", x, w.y1)) end
    for y = w.y0 + 1, w.y1 - 1 do C.ok(Farm.place(ctx, "zaun", w.x1 + 4, y)) end
    local list = Farm.pastures(map, farm)
    C.eq(#list, 1)
    C.ok(list[1].plaetze > plaetze, "mehr Plätze: " .. list[1].plaetze)
  end},
  {"Alter Spielstand mit fester Startweide: wird beim Laden umgebaut, eigene Zäune bleiben", function()
    Area.clear()
    local plot = {x = 30, y = 30, w = 20, h = 20}
    local farm = Farm.default(plot)
    farm.items = {{id = "zaun", cx = plot.x + 14, cy = plot.y + 2}}
    local ctx = Stage.build(1, 31, farm)
    C.ok(ctx.area.farm.weide.umgebaut)
    C.eq(#ctx.area.farm.items, 1 + 2 * 10 + 2 * 5)
    C.eq(#Farm.pastures(ctx.map, ctx.area.farm), 1, "Weide funktioniert weiter")
  end},
  {"Startausstattung: Wohnwagen, Stall S, Weide mit Tor, keine Bürste", function()
    local ctx = Stage.build(1)
    local farm = ctx.area.farm
    local kinds = {}
    for _, b in ipairs(farm.buildings) do kinds[b.id] = true end
    C.ok(kinds.wohnwagen and kinds.stall_s, "Gebäude")
    C.ok(farm.weide.gate, "Tor")
    C.eq(ctx.inv.buerste, 0)
    local cap = Farm.capacity(farm)
    C.eq(cap.stall, 2, "Stall S: 2 Plätze")
    C.eq(cap.weide, 4, "Weide: Innenfläche 8 × 5 / 10")
    C.eq(cap.frei, 8, "frei: 400 Kacheln / 50")
    -- Startpunkt und Stalltür frei erreichbar, Tor begehbar
    C.ok(ctx.map:walkable(ctx.area.places.start[1], ctx.area.places.start[2]), "Start")
    local d = ctx.area.places.stalltuer
    C.ok(ctx.map:walkable(d[1], d[2]), "Stalltür")
    local g = farm.weide.gate
    C.ok(ctx.map:walkable(g[1], g[2]), "Tor offen")
  end},
  {"Plätze sind begrenzt: Stall 2, dritte Unterbringung geht nicht", function()
    local ctx, w = setup()
    local a, b, c = w:add_own(), w:add_own(), w:add_own()
    C.ok(w:house(a, "stall"), "1")
    C.ok(w:house(b, "stall"), "2")
    local ok, why = w:house(c, "stall")
    C.ok(not ok and why == "voll", "Stall voll")
    C.ok(w:house(c, "weide"), "Weide frei")
    C.eq(Farm.count(ctx.herd, "stall"), 2)
    C.ok(a.hidden and a.state == "stall", "Stallpferd unsichtbar")
    w:take_out(a)
    C.eq(a.data.ort, nil)
    C.ok(not a.hidden and (a.state == "led" or a.state == "follow"), "zurück an der Leine")
    C.ok(w:house(c, "stall"), "Platz wieder frei")
  end},
  {"Frei auf dem Grundstück nur mit Stärke ≥ 60 und Bindung ≥ 70", function()
    local _, w = setup()
    local h = w:add_own({bindung = 69})
    strong(h)
    h.data.bindung = 69
    C.ok(not w:house(h, "frei"), "Bindung 69")
    h.data.bindung = 70
    C.ok(w:house(h, "frei"), "Bindung 70")
    local s = w:add_own({bindung = 90})
    C.ok(not w:house(s, "frei"), "Haflinger zu schwach")
  end},
  {"Tagesverlust: Stall 0 / Sauberkeit −5, Weide 2 × (1 − Stärke/100) / −10, frei −20", function()
    local _, w = setup()
    local h = w:add_own()
    strong(h)
    for _, k in ipairs(H.STATS) do h.data.train[k] = 10 end
    h.data.sauberkeit = 60
    h.data.ort = "stall"
    C.eq(Farm.daily(h.data, H), 0)
    C.eq(h.data.train.tempo, 10)
    C.eq(h.data.sauberkeit, 55)
    h.data.ort = "weide"
    local loss = Farm.daily(h.data, H)
    C.near(loss, 2 * (1 - (70 + 10) / 100), 1e-6, "Weide, Gesamtstärke 80")
    C.near(h.data.train.tempo, 10 - loss, 1e-6)
    C.eq(h.data.sauberkeit, 45)
    h.data.ort = "frei"
    Farm.daily(h.data, H)
    C.eq(h.data.sauberkeit, 25)
    h.data.ort = nil
    C.eq(Farm.daily(h.data, H), 0, "an der Leine kein Verlust")
    h.data.ort = "weide"
    h.data.train.tempo = 0.1
    Farm.daily(h.data, H)
    C.eq(h.data.train.tempo, 0, "nie unter 0")
  end},
  {"Weidenpferde bleiben in der Weide (2000 Frames), Koordinaten innerhalb des Zauns", function()
    local ctx, w = setup()
    local hs = {}
    for i = 1, 3 do
      local h = w:add_own()
      w:house(h, "weide")
      hs[i] = h
    end
    local pasture = Farm.pastures(ctx.map, ctx.area.farm)[1]
    for _ = 1, 2000 do
      ctx.world:update()
      for _, h in ipairs(hs) do
        C.ok(Farm.in_pasture(pasture, h.x, h.y), "Pferd verlässt die Weide")
      end
    end
  end},
}
