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
}
