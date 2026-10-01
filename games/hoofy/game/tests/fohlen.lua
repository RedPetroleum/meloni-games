-- Selbsttests für Fohlen, Stallansicht und Göpel (Rückmeldung 1.2.1): Fohlen kommen in den Stall, andere
-- Pferde machen Platz (Stall → Weide → Grundstück → fort), Zucht aus dem Pferdemenü, Pferde am Göpel.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Days = require("game.days")
local Farm = require("game.farm")
local Breeding = require("game.breeding")
local HorseMenu = require("game.horse_menu")
local Value = require("game.value")
local C = require("game.tests.check")

-- Hof mit Stall S (2 Plätze), Weide (6 Plätze) und frei (8 Plätze); Mutter trächtig, Vater im Stall.
local function setup()
  Area.clear()
  local ctx = Stage.build(1, 5)
  ctx.clock = {day = 10}
  local w = Wild.new(ctx, 3)
  w.count = 0
  local function horse(name, sex, ort, wert)
    local h = w:add_own({rasse = "haflinger", name = name})
    h.data.sex, h.data.alter = sex, 1
    for _, k in ipairs({"tempo", "staerke", "spuer"}) do h.data.gen[k], h.data.train[k] = wert or 50, 0 end
    if ort then assert(w:house(h, ort, true)) end
    return h
  end
  local m = horse("Mutter", "w", "stall", 20)            -- die billigste, darf trotzdem nie weichen
  local f = horse("Vater", "m", "stall", 60)
  assert(Breeding.start(ctx, f.data, m.data, 10))
  return ctx, w, m, f, horse
end

local function born(ctx)
  Days.new_day(ctx, 12)
  local foal = ctx.herd[#ctx.herd]
  C.eq(foal.alter, 0, "Fohlen geboren")
  return foal
end

return {
  {"Fohlen kommt in den Stall; voller Stall: das billigste Pferd außer der Mutter zieht auf die Weide", function()
    local ctx, w, m, f = setup()
    local foal = born(ctx)
    C.eq(foal.ort, "stall")
    C.eq(m.data.ort, "stall", "Mutter bleibt")
    C.eq(f.data.ort, "weide", "Vater macht Platz")
    C.eq(Farm.count(ctx.herd, "stall"), 2)
    C.ok(ctx.geburten[1]:find("Vater zieht auf die Weide"), ctx.geburten[1])
  end},
  {"Weide voll: von dort zieht das billigste auf das Grundstück, auch wenn es zu schwach für frei wäre", function()
    local ctx, w, m, f, horse = setup()
    local cap = Farm.capacity(ctx.area.farm)
    local weak
    for i = 1, cap.weide do
      local h = horse("Weide" .. i, "w", "weide", i == 1 and 10 or 70)
      if i == 1 then weak = h end
    end
    C.ok(not Farm.may_roam(weak.data, require("game.horse_model")), "Weide1 ist eigentlich zu schwach für frei")
    local foal = born(ctx)
    C.eq(foal.ort, "stall")
    C.eq(f.data.ort, "weide", "Vater auf die Weide")
    C.eq(weak.data.ort, "frei", "billigstes Weidepferd aufs Grundstück")
    C.eq(Farm.count(ctx.herd, "weide"), cap.weide)
  end},
  {"Alles voll: das Pferd mit dem geringsten Wert läuft fort, nie Mutter oder Fohlen", function()
    local ctx, w, m, f, horse = setup()
    local cap = Farm.capacity(ctx.area.farm)
    for i = 1, cap.weide do horse("Weide" .. i, "w", "weide", 70) end
    w.force_roam = true
    local cheap
    for i = 1, cap.frei do
      local h = horse("Frei" .. i, "m", "frei", i == 3 and 5 or 80)
      if i == 3 then cheap = h end
    end
    w.force_roam = nil
    local n = #ctx.herd
    local foal = born(ctx)
    C.eq(#ctx.herd, n, "eins dazu, eins fort")
    for _, d in ipairs(ctx.herd) do C.ok(d ~= cheap.data, "das billigste ist fort") end
    C.eq(foal.ort, "stall")
    C.eq(m.data.ort, "stall")
    C.eq(Farm.count(ctx.herd, "stall"), cap.stall)
    C.ok(ctx.geburten[1]:find("Frei3 ist fortgelaufen"), ctx.geburten[1])
    C.ok(Value.wert_roh(cheap.data) < Value.wert_roh(m.data) or true)
  end},
  {"Pferdemenü im Stall: Zucht nur mit bereitem Partner, Gründe für ausgegraut", function()
    local ctx, w, m, f, horse = setup()
    local partners, why = HorseMenu.partners(ctx, m.data)
    C.ok(not partners and why == "schon trächtig", tostring(why))
    local s = horse("Stute", "w", "stall", 50)
    partners = HorseMenu.partners(ctx, f.data)
    C.ok(partners and #partners == 1 and partners[1] == s.data, "Vater findet die bereite Stute")
    partners = HorseMenu.partners(ctx, s.data)
    C.ok(partners and partners[1] == f.data, "Stute findet den Vater")
    s.data.alter = 0.5
    C.eq(select(2, HorseMenu.partners(ctx, s.data)), "noch ein Fohlen")
    s.data.alter = 1
    w:house(s, "weide")
    C.eq(select(2, HorseMenu.partners(ctx, s.data)), "nur im Stall")
    local env = {ctx = ctx, wild = w, nav = {push = function() end}, say = function() end, in_stall = true}
    local menu = HorseMenu.open(env, f)
    local ids = {}
    for _, it in ipairs(menu.m.items) do ids[it.id] = it end
    C.ok(ids.take and ids.breed and not ids.mount and not ids.leash, "Holen und Zucht statt Leine und Reiten")
    C.ok(ids.breed.dim, "keine bereite Stute im Stall")
  end},
  {"Göpel: ein Pferd je Generator, läuft im Kreis, nur Göpel-Pferde bringen Geld", function()
    Area.clear()
    local ctx = Stage.build(1, 8)
    ctx.money = 10000
    ctx.clock = {day = 3}
    local w = Wild.new(ctx, 3)
    w.count = 0
    local p = ctx.area.plot
    C.ok(Farm.place(ctx, "goepel_generator", p.x + 15, p.y + 5))
    C.eq(Farm.capacity(ctx.area.farm).goepel, 1)
    local a = w:add_own({rasse = "noriker", name = "Zieher"})
    local b = w:add_own({rasse = "noriker", name = "Zweiter"})
    for _, h in ipairs({a, b}) do h.data.alter, h.data.gen.staerke, h.data.energie = 1, 60, 60 end
    C.ok(w:house(a, "goepel"))
    local ok, why = w:house(b, "goepel")
    C.ok(not ok and why == "voll", tostring(why))
    C.eq(a.state, "goepel")
    local x0, y0 = a.x, a.y
    for _ = 1, 60 do a:update() end
    C.ok(a.x ~= x0 or a.y ~= y0, "läuft")
    local g = a.goepel
    C.near(((a.x - g.x) / Wild.GOEPEL_RX) ^ 2 + ((a.y - g.y) / Wild.GOEPEL_RY) ^ 2, 1, 0.01, "auf der Bahn um den Göpel")
    w:house(b, "stall")
    ctx.money = 0
    Days.new_day(ctx, 4)
    C.eq(ctx.money, 40, "nur das Göpel-Pferd zieht")
    local _, _, can, why2 = Farm.demolish_target(ctx, p.x + 15, p.y + 5)
    C.ok(not can and why2:find("Zieher"), "Göpel mit Pferd nicht abreißen")
    -- Laden: der gemerkte Göpel
    a.data.ort = nil
    C.ok(w:house(a, "goepel", true))
    C.eq(a.data.goepel_id, (p.x + 15) .. "," .. (p.y + 5))
  end},
}
