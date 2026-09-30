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
  {"Trainingsformel: Basis × (1 − Gesamt/Potenzial) × Bonus", function()
    local d = horse("nachteule")
    -- Bonus: 1 + 0,25 × 0,6 + 0,25 × 0,5 = 1,275; (1 − 40/60) = 1/3
    C.near(Care.training_bonus(d), 1.275, 1e-6)
    C.near(Care.training_gain(d, "tempo", 3), 3 * (1 / 3) * 1.275, 1e-6)
    d.train.tempo = 10                                -- Gesamt 50: Faktor 1/6
    C.near(Care.training_gain(d, "tempo", 3), 3 * (1 / 6) * 1.275, 1e-6)
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
    C.near(Care.training_gain(a, "staerke", 2), 2 * 2 * (1 / 3) * 1.275, 1e-6)
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
    C.eq(bond, 4, "Karotte +3 und Fütterung +1")
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
  {"Streicheln +2 einmal am Tag, Striegeln Sauberkeit +40 und Bindung +1", function()
    local d = horse("faul")
    C.eq(Care.stroke(d), 2)
    C.eq(d.bindung, 52)
    C.eq(Care.stroke(d), 0, "zweites Mal am selben Tag")
    d.gestreichelt = nil
    C.eq(Care.stroke(d), 2, "nach dem Tageswechsel wieder")
    d.sauberkeit = 70
    Care.brush(d)
    C.eq(d.sauberkeit, 100, "höchstens 100")
    d.sauberkeit = 10
    Care.brush(d)
    C.eq(d.sauberkeit, 50)
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
}
