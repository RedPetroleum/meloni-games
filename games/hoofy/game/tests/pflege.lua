-- Selbsttests für Pflege und Training (Aufgabe A10): Trainingsformel, Futter, Bindungsregeln.
local Care = require("game.care")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function horse(zug, extra)
  local d = H.wild({rng = Rng.new(2), zug = zug or "eitel", rasse = "haflinger"})
  for _, k in ipairs(H.STATS) do d.gen[k], d.train[k], d.pot[k] = 40, 0, 60 end
  d.bindung, d.hunger, d.sauberkeit, d.gewicht, d.alter, d.energie = 50, 50, 60, 50, 1, 80
  d.gestreichelt, d.pot_bonus, d.boost = nil, nil, nil
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

return {
  {"Trainingsformel: Basis × Trainingstempo × Bonus, gleichmäßig bis zum Potenzial", function()
    local d = horse("nachteule")
    -- Bonus: 1 + 0,25 × 0,6 + 0,25 × 0,5 = 1,275
    C.near(Care.training_bonus(d), 1.275, 1e-6)
    -- Trainingstempo 3
    C.near(Care.training_gain(d, "tempo", 1), 3 * 1.275, 1e-6)
    d.train.tempo = 10                                -- Gesamt 50: gleicher Zuwachs
    C.near(Care.training_gain(d, "tempo", 1), 3 * 1.275, 1e-6)
    C.near(Care.train(d, "tempo", 1), 3 * 1.275, 1e-6)
    C.near(Care.train(d, "tempo", 5), 20 - 10 - 3 * 1.275, 1e-6, "kurz vor dem Potenzial nur der Rest")
    d.train.tempo = 20                                -- am Potenzial: nichts mehr
    C.eq(Care.training_gain(d, "tempo", 3), 0)
    local g = Care.train(d, "tempo", 5)
    C.eq(g, 0, "über das Potenzial hinaus gibt es nichts")
  end},
  {"Bonus bis ×1,5, nie mehr; Sauberkeit und Bindung wirken", function()
    local d = horse("nachteule", {sauberkeit = 100, bindung = 100})
    C.near(Care.training_bonus(d), 1.5, 1e-6)
    d.zug = "eitel"
    C.near(Care.training_bonus(d), 1.5, 1e-6, "gedeckelt")
    d.sauberkeit, d.bindung, d.zug = 0, 0, "nachteule"
    C.near(Care.training_bonus(d), 1, 1e-6)
  end},
  {"Charakter: faul −20 %, Drachenfrucht ×2, eitel verdoppelt Sauberkeit", function()
    local a, b = horse("nachteule"), horse("faul")
    C.near(Care.training_gain(b, "staerke", 2), Care.training_gain(a, "staerke", 2) * 0.8, 1e-6)
    a.boost = 1
    C.near(Care.training_gain(a, "staerke", 2), 3 * 2 * 2 * 1.275, 1e-6)
    local e = horse("eitel")
    C.near(Care.training_bonus(e), 1 + 0.25 * 0.6 * 2 + 0.125, 1e-6)
  end},
  {"Futter nach Katalog: Heu, Hafer, Karotte, Premium", function()
    local d = horse("faul", {hunger = 80, energie = 50})
    d.gen.ausdauer, d.pot.ausdauer = 90, 100
    Care.feed(d, "heu")
    C.eq(d.hunger, 50, "Heu −30")
    C.eq(d.bindung, 51, "Fütterung +1")
    Care.feed(d, "hafer")
    C.eq(d.hunger, 10, "Hafer −40")
    C.eq(d.energie, 65, "Hafer Energie +15")
    local _, bond = Care.feed(d, "karotte")
    C.eq(bond, 1, "Karotte wie jedes Futter +1, kein Bonus")
    C.eq(d.hunger, 5, "Karotte Hunger −5")
    Care.feed(d, "heu")
    C.eq(d.hunger, 0, "Hunger nicht unter 0")
    d.energie = 99
    Care.feed(d, "hafer")
    C.eq(d.energie, 90, "Energie höchstens Ausdauer (Gesamt 90)")
  end},
  {"Premiumfutter: Fohlen +2 Max-Potenzial bis +10, Erwachsene nicht", function()
    local f = horse("faul", {alter = 0.5})
    for i = 1, 8 do Care.feed(f, "premiumfutter") end
    C.eq(f.pot_bonus, 10, "insgesamt +10")
    C.eq(f.pot.tempo, 70)
    C.eq(f.pot.ausdauer, 70)
    local a = horse("faul")
    Care.feed(a, "premiumfutter")
    C.eq(a.pot.tempo, 60, "Erwachsene unverändert")
    local g = horse("faul", {alter = 0.2})
    g.pot.tempo = 99
    Care.feed(g, "premiumfutter")
    C.eq(g.pot.tempo, 100, "höchstens 100")
  end},
  {"Streicheln +2, zweites Mal am Tag +1, dann nichts; Striegeln +1 Bindung nur unter Sauberkeit 100", function()
    local d = horse("faul")
    C.eq(Care.stroke(d), 2)
    C.eq(d.bindung, 52)
    C.eq(Care.stroke(d), 1, "zweites Mal am selben Tag")
    C.eq(Care.stroke(d), 0, "drittes Mal")
    C.eq(d.bindung, 53)
    d.gestreichelt = nil
    C.eq(Care.stroke(d), 2, "nach dem Tageswechsel wieder")
    d.gestreichelt = true                             -- alter Spielstand: einmal gestreichelt
    C.eq(Care.stroke(d), 1, "alter Spielstand zählt als einmal")
    local e = horse("faul", {sauberkeit = 20, bindung = 50})
    C.eq(select(2, Care.brush(e)), 1)
    C.eq(e.sauberkeit, 60)
    C.eq(select(2, Care.brush(e)), 1, "60 → 100")
    C.eq(e.sauberkeit, 100, "höchstens 100")
    C.eq(select(2, Care.brush(e)), 0, "bei 100 keine Bindung mehr")
    C.eq(e.bindung, 52)
  end},
  {"Füttern: +1 je Futter, höchstens +5 am Tag, Tageswechsel setzt zurück", function()
    local d = horse("faul", {bindung = 50})
    local Days = require("game.days")
    for _ = 1, 7 do Care.feed(d, "karotte") end
    C.eq(d.bindung, 55, "7 Karotten, aber nur +5")
    local _, bond = Care.feed(d, "apfel")
    C.eq(bond, 0)
    Days.horse_day(d)
    C.eq(d.gefuettert, nil)
    local b0 = d.bindung
    Care.feed(d, "heu")
    C.eq(d.bindung, b0 + 1, "neuer Tag")
  end},
  {"Bindungsregeln pro Tag: Hunger > 70 −3, Sauberkeit < 30 −2 (eitel −4)", function()
    local d = horse("faul", {hunger = 71, sauberkeit = 29, bindung = 50})
    C.eq(Care.daily_bond(d), -5)
    C.eq(d.bindung, 45)
    local e = horse("eitel", {hunger = 70, sauberkeit = 29, bindung = 50})
    C.eq(Care.daily_bond(e), -4, "eitel doppelt")
    local ok = horse("faul", {hunger = 70, sauberkeit = 30})
    C.eq(Care.daily_bond(ok), 0, "Grenzwerte noch in Ordnung")
  end},
  {"Gewicht: Abweichung > 15 senkt Tempo und Stärke um 1 % je Punkt darüber", function()
    local d = horse("faul")
    d.gewicht = 65
    C.eq(Care.weight_factor(d), 1)
    d.gewicht = 75
    C.near(Care.weight_factor(d), 0.9, 1e-6)
    C.near(Care.effective(d, "tempo"), 36, 1e-6)
    C.eq(Care.effective(d, "spuer"), 40, "Spürsinn unberührt")
    d.gewicht = 20
    C.near(Care.weight_factor(d), 0.85, 1e-6)
  end},
  {"Füttern im Pferdemenü: Menü bleibt offen, Anzahl sinkt, Auswahl bleibt, mehrmals hintereinander", function()
    local Stage = require("game.stage")
    local Wild = require("game.wild")
    local HorseMenu = require("game.horse_menu")
    local ctx = Stage.build(1)
    local w = Wild.new(ctx, 3)
    w.count = 0
    local h = w:add_own({rasse = "haflinger", bindung = 50, name = "Moppel"})
    ctx.inv.heu, ctx.inv.karotte = 2, 1
    local menu = HorseMenu.open({ctx = ctx, wild = w, nav = {push = function() end}, say = function() end}, h)
    menu:act("feed")
    C.eq(menu.stage, "food")
    local function sel_id() return menu.m.items[menu.m.sel].id end
    for i, it in ipairs(menu.m.items) do if it.id == "heu" then menu.m.sel = i end end
    menu:act("heu")
    C.ok(not menu.closed, "Menü bleibt offen")
    C.eq(menu.stage, "food")
    C.eq(ctx.inv.heu, 1)
    C.eq(sel_id(), "heu", "Auswahl bleibt")
    menu:act("heu")
    C.eq(ctx.inv.heu, 0, "zweimal hintereinander")
    C.ok(menu.m.items[menu.m.sel].dim, "kein Heu mehr: ausgegraut")
    menu:act("close")
    C.eq(menu.stage, "main", "B/zurück führt ins Pferdemenü")
  end},
}
