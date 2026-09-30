-- Selbsttests für Tag und Nacht (Aufgabe A12): Uhr, Nachtsicht, Tageswechsel.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Clock = require("game.clock")
local Days = require("game.days")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function horse(zug, extra)
  local d = H.wild({rng = Rng.new(2), zug = zug or "faul", rasse = "haflinger"})
  for _, k in ipairs(H.STATS) do d.gen[k], d.train[k], d.pot[k] = 50, 0, 80 end
  d.bindung, d.hunger, d.sauberkeit, d.gewicht, d.alter, d.energie = 50, 50, 60, 50, 1, 10
  d.satt_tage = nil
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

return {
  {"Ein Tag = 5 min (18 000 Frames), 3 min hell, 2 min dunkel", function()
    C.eq(Clock.DAY, 18000)
    C.eq(Clock.LIGHT, 10800)
    local c = Clock.new(1, 0)
    local dusk, days, dark = 0, 0, 0
    for _ = 1, Clock.DAY * 2 + 5 do
      local ev = c:update()
      if ev == "dusk" then dusk = dusk + 1 elseif ev == "day" then days = days + 1 end
      if c:is_night() then dark = dark + 1 end
    end
    C.eq(dusk, 2, "zweimal Dämmerung")
    C.eq(days, 2, "zwei Tageswechsel")
    C.eq(c.day, 3)
    C.between(dark / (Clock.DAY * 2), 0.39, 0.41, "40 % dunkel")
  end},
  {"Schlafen nur nachts, überspringt den Rest der Nacht", function()
    local c = Clock.new(4, 5000)
    C.ok(not c:sleep(), "tagsüber nicht")
    C.eq(c.day, 4)
    c.t = 12000
    C.ok(c:sleep(), "nachts")
    C.eq(c.day, 5)
    C.eq(c.t, 0)
  end},
  {"Sichtradius: tagsüber unbegrenzt, Dämmerung schrumpft, Nacht 70, Lampe größer", function()
    local c = Clock.new(1, 100)
    C.eq(c:sight(70), nil, "Tag")
    c.t = Clock.LIGHT - Clock.DUSK - 1
    C.eq(c:sight(70), nil)
    local last = 1e9
    for t = Clock.LIGHT - Clock.DUSK, Clock.LIGHT - 1, 60 do
      c.t = t
      local r = c:sight(70)
      C.ok(r <= last and r >= 70 and r <= 420, "monoton fallend")
      last = r
    end
    c.t = Clock.LIGHT + 1000
    C.eq(c:sight(70), 70)
    C.near(c:sight(70, true), 126, 0.01, "Lampe")
    c.woke, c.t = true, 0
    C.near(c:sight(70), 70, 0.01, "Sonnenaufgang beginnt dunkel")
    c.t = Clock.DAWN
    C.eq(c:sight(70), nil, "danach hell")
  end},
  {"Nachtbild: nur ein paar Dutzend rectfill-Streifen", function()
    local calls, old = 0, rectfill
    rectfill = function(...) calls = calls + 1 old(...) end
    Stage.draw_night(160, 120, 70)
    rectfill = old
    C.between(calls, 20, 130, "rectfill-Aufrufe")
    log("TAG Nachtbild: " .. calls .. " rectfill je Frame")
  end},
  {"Tageswechsel: Hunger +25 (verfressen +35), Energie zurück, Streicheln frei", function()
    local d = horse("faul", {hunger = 40, gestreichelt = true})
    Days.horse_day(d)
    C.eq(d.hunger, 65)
    C.eq(d.energie, 50, "= Ausdauer")
    C.eq(d.gestreichelt, nil)
    local v = horse("verfressen", {hunger = 40})
    Days.horse_day(v)
    C.eq(v.hunger, 75)
    local n = horse("nachteule", {})
    Days.horse_day(n)
    C.eq(n.energie, 40, "Nachteule morgens −10")
    local o = horse("faul", {hunger = 90})
    Days.horse_day(o)
    C.eq(o.hunger, 100, "höchstens 100")
  end},
  {"Gewicht: Hunger > 70 −3, zwei Tage Hunger < 10 +3 (überfüttert)", function()
    local d = horse("faul", {hunger = 80})
    Days.horse_day(d)
    C.eq(d.gewicht, 47, "Hunger > 70")
    local f = horse("faul", {hunger = 5})
    Days.horse_day(f)
    C.eq(f.gewicht, 50, "erster satter Tag")
    f.hunger = 5
    Days.horse_day(f)
    C.eq(f.gewicht, 53, "zweiter satter Tag: überfüttert")
    f.hunger = 5
    Days.horse_day(f)
    C.eq(f.gewicht, 56, "und weiter")
    f.hunger = 40
    Days.horse_day(f)
    C.eq(f.satt_tage, 0)
  end},
  {"Tageswechsel: Bindung, Unterbringung, Fohlenalter", function()
    local d = horse("faul", {hunger = 71, sauberkeit = 29, bindung = 50})
    d.ort = "weide"
    local r = Days.horse_day(d)
    C.eq(r.bindung, -5)
    C.eq(d.bindung, 45)
    C.eq(d.sauberkeit, 19, "Weide −10")
    local f = horse("faul", {alter = 0})
    for i = 1, 4 do Days.horse_day(f) end
    C.near(f.alter, 1, 1e-6, "nach 4 Tagen ausgewachsen")
    Days.horse_day(f)
    C.eq(f.alter, 1, "altert nicht weiter")
  end},
  {"Tageswechsel im Spiel: alle eigenen Pferde, Wildpferdwechsel an Tag 4", function()
    local ctx = Stage.build(1)
    local w = Wild.new(ctx, 3)
    w:fill()
    local h = w:add_own()
    h.data.hunger = 10
    local wild_before = {}
    for _, e in ipairs(w.list) do wild_before[e] = true end
    Days.new_day(ctx, 2)
    C.eq(h.data.hunger, 35)
    Days.new_day(ctx, 3)
    Days.new_day(ctx, 4)
    local fresh = 0
    for _, e in ipairs(w.list) do if not wild_before[e] then fresh = fresh + 1 end end
    C.between(fresh, 1, 2, "neue Wildpferde an Tag 4")
    C.eq(#w.list, 4)
  end},
}
