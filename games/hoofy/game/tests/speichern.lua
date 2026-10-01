-- Selbsttests für den Spielstand (Aufgabe A14): Hin- und Rückweg, Größe mit 24 Pferden.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Clock = require("game.clock")
local Save = require("game.save")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function equal(a, b, path)
  if type(a) ~= type(b) then error((path or "?") .. ": Typ " .. type(a) .. " ≠ " .. type(b), 0) end
  if type(a) ~= "table" then
    if a ~= b then error((path or "?") .. ": " .. tostring(a) .. " ≠ " .. tostring(b), 0) end
    return
  end
  for k, v in pairs(a) do equal(v, b[k], (path or "") .. "." .. tostring(k)) end
  for k in pairs(b) do if a[k] == nil then error((path or "") .. "." .. tostring(k) .. " fehlt links", 0) end end
end

local function world(seed)
  local ctx = Stage.build(1, seed)
  local w = Wild.new(ctx, seed)
  w.count = 0
  return ctx, w
end

local function decode(text)
  local chunk = load("return " .. text, "=save", "t", {})
  return chunk()
end

return {
  {"Hin- und Rückweg: Tag, Geld, Vorrat, Pferde (Namen, Stats, Unterbringung) bleiben gleich", function()
    local ctx, w = world(77)
    local clock = Clock.new(5, 1234)
    ctx.money, ctx.inv.heu = 1234, 7
    local a = w:add_own({rasse = "noriker", name = "Hilde"})
    local b = w:add_own({rasse = "haflinger", name = "Bruno"})
    w:house(b, "stall")
    w:house(a, "weide")
    a.data.train.tempo = 3.25
    a.data.sattel = "sportsattel"
    local snap = Save.snapshot(ctx, clock, 77)
    local back = decode(Save.encode(snap))
    equal(snap, back, "Snapshot")
    -- in eine frische Welt laden
    local ctx2, w2 = world(back.seed)
    for _, d in ipairs(back.herd) do w2:adopt(d) end
    equal(ctx.herd[1], ctx2.herd[1], "Pferd 1")
    C.eq(ctx2.herd[1].name, "Hilde")
    C.eq(ctx2.herd[1].ort, "weide", "Unterbringung gemerkt")
    C.eq(ctx2.herd_horses[1].state, "free")
    C.eq(#ctx2.herd, 2)
  end},
  {"Gleicher Seed = gleiche Welt nach dem Laden, Hof aus dem Spielstand", function()
    local ctx = world(9)
    local snap = Save.snapshot(ctx, Clock.new(), 9)
    local ctx2 = Stage.build(1, snap.seed, snap.hof)
    for y = 1, ctx.map.h do C.ok(ctx.map.ground[y] == ctx2.map.ground[y], "Bodenzeile " .. y) end
    C.eq(#ctx2.area.farm.buildings, 2)
    C.eq(#snap.aenderungen, 0, "keine Änderungen gegenüber dem Seed")
  end},
  {"Ohne gültigen Spielstand kein Weiter: Test-Spielstände und falsche Version zählen nicht", function()
    local old = loaddata
    loaddata = function() return {scenario = "welt"} end
    C.eq(Save.read(), nil)
    loaddata = function() return {ver = 99} end
    C.eq(Save.read(), nil)
    loaddata = function() return {ver = Save.VERSION, seed = 1} end
    C.ok(Save.read(), "gültig")
    loaddata = old
  end},
  {"Größe des Spielstands mit 24 Pferden", function()
    local ctx, w = world(3)
    local rng = Rng.new(8)
    for i = 1, 24 do
      local data = H.wild({gebiet = 1 + i % 6, rng = rng})
      data.ort = i <= 2 and "stall" or nil
      local h = w:adopt(data)
    end
    C.eq(#ctx.herd, 24)
    local snap = Save.snapshot(ctx, Clock.new(12, 0), 3)
    local text = Save.encode(snap)
    log(string.format("SPEICHERN Spielstand mit 24 Pferden: %d Bytes (%.1f KB)", #text, #text / 1024))
    C.ok(#text < 30000, "Spielstand zu groß")
    equal(snap, decode(text), "Rundlauf")
  end},
  {"Laden: Pferde bleiben, wo sie gespeichert wurden (Weide, frei, Stall), auch wenn die Bedingungen nicht mehr passen", function()
    local Area = require("game.area")
    local Farm = require("game.farm")
    Area.clear()
    local ctx = Stage.build(1, 77)
    local w = Wild.new(ctx, 3) w.count = 0
    local list = {}
    for i, ort in ipairs({"weide", "weide", "stall", "frei"}) do
      local h = w:add_own({rasse = "noriker", name = "P" .. i})
      h.data.bindung = 100
      for _, k in ipairs(H.STATS) do h.data.gen[k], h.data.pot[k] = 90, 100 end
      C.ok(w:house(h, ort), ort)
      list[i] = h.data
    end
    list[4].bindung = 5                                         -- frei: heute nicht mehr erlaubt
    local text = Save.encode(Save.snapshot(ctx, Clock.new(3, 100), 77))
    local snap = load("return " .. text)()
    Area.clear()
    local ctx2 = Stage.build(1, 77, snap.hof)
    local w2 = Wild.new(ctx2, 3) w2.count = 0
    for _, d in ipairs(snap.herd) do w2:adopt(d) end
    local orte = {}
    for _, d in ipairs(ctx2.herd) do orte[#orte + 1] = tostring(d.ort) end
    C.eq(table.concat(orte, ","), "weide,weide,stall,frei")
    C.eq(#ctx2.lead, 0, "niemand an der Leine")
    for _, h in ipairs(ctx2.herd_horses) do
      if h.data.ort == "weide" then
        local inside = false
        for _, p in ipairs(Farm.pastures(ctx2.map, ctx2.area.farm)) do
          if Farm.in_pasture(p, h.x, h.y) then inside = true end
        end
        C.ok(inside, h.data.name .. " steht auf der Weide")
      end
    end
  end},  {"Laden: lose Pferde (in die Weide geführt, nicht untergebracht) bleiben an ihrem Platz, nicht an der Leine", function()
    local Area = require("game.area")
    Area.clear()
    local ctx = Stage.build(1, 77)
    local w = Wild.new(ctx, 3) w.count = 0
    local g = ctx.area.farm.weide
    local pos = {}
    for i = 1, 3 do
      local h = w:add_own({rasse = "noriker", name = "L" .. i, bindung = 40})
      h.x, h.y = (g.x0 + i) * 16 + 8, (g.y0 + 2) * 16 + 14
      pos[i] = {h.x, h.y}
    end
    local led = w:add_own({rasse = "haflinger", name = "Strick", bindung = 40})
    w:attach(led)
    local snap = load("return " .. Save.encode(Save.snapshot(ctx, Clock.new(3, 100), 77)))()
    Area.clear()
    local ctx2 = Stage.build(1, 77, snap.hof)
    local w2 = Wild.new(ctx2, 3) w2.count = 0
    for _, d in ipairs(snap.herd) do w2:adopt(d) end
    C.eq(#ctx2.lead, 1, "nur das Pferd am Strick ist an der Leine")
    C.eq(ctx2.lead[1].data.name, "Strick")
    for i = 1, 3 do
      local h = ctx2.herd_horses[i]
      C.eq(h.state, "free", h.data.name .. " lose")
      C.eq(h.x, pos[i][1], h.data.name .. " x") C.eq(h.y, pos[i][2], h.data.name .. " y")
      C.eq(h.data.lose, nil, "Platz nach dem Laden vergessen")
    end
  end},
}
