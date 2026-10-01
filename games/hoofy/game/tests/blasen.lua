-- Selbsttests für Sprechblasen (Aufgabe A6): Vorrang (E10) und Schwellen (E11).
local B = require("game.bubbles")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function horse(zug)
  local d = H.wild({rng = Rng.new(2), zug = zug})
  d.hunger, d.sauberkeit, d.energie, d.bindung = 30, 60, 80, 30
  return {data = d}
end

return {
  {"ruhiges Pferd ohne Charakter-Phase: keine Blase", function()
    local h = horse("faul")
    for now = 0, 719, 7 do
      local b = B.choose(h, now)
      C.ok(b == nil or b == "emo_zzz", "unerwartet " .. tostring(b))
    end
  end},
  {"Schwellen: Hunger > 60, Sauberkeit < 40, Energie < 15", function()
    local h = horse("eitel")
    h.data.hunger = 60
    C.ok(B.choose(h, 400) ~= "emo_carrot", "Hunger 60 noch keine Blase")
    h.data.hunger = 61
    C.eq(B.choose(h, 0), "emo_carrot")
    h.data.hunger = 30
    h.data.sauberkeit = 40
    C.ok(B.choose(h, 400) ~= "emo_dirty")
    h.data.sauberkeit = 39
    C.eq(B.choose(h, 0), "emo_dirty")
    h.data.sauberkeit = 60
    h.data.energie = 15
    C.ok(B.choose(h, 400) ~= "emo_zzz")
    h.data.energie = 14
    C.eq(B.choose(h, 0), "emo_zzz")
  end},
  {"Vorrang: Schatz > Angst > Hunger > schmutzig > müde", function()
    local h = horse("verfressen")
    h.data.hunger, h.data.sauberkeit, h.data.energie = 90, 10, 5
    h.schatz, h.scared = true, true
    C.eq(B.choose(h, 0), "emo_nose")
    h.schatz = false
    C.eq(B.choose(h, 0), "emo_storm")
    h.scared = false
    C.eq(B.choose(h, 0), "emo_carrot")
    h.data.hunger = 30
    C.eq(B.choose(h, 0), "emo_dirty")
    h.data.sauberkeit = 60
    C.eq(B.choose(h, 0), "emo_zzz")
  end},
  {"Charakter-Blase erscheint zeitweise, Herz nur ab Bindung 70", function()
    for _, zug in ipairs({"verfressen", "schreckhaft", "faul", "eitel", "nachteule"}) do
      local h, n = horse(zug), 0
      for now = 0, 719 do if B.choose(h, now) then n = n + 1 end end
      C.eq(n, 120, zug .. ": 2 s von 12 s")
    end
    local h = horse("eitel")
    h.heart_t = 50
    h.data.bindung = 69
    C.ok(B.choose(h, 400) ~= "emo_heart")
    h.data.bindung = 70
    C.eq(B.choose(h, 400), "emo_heart")
  end},
  {"Reaktion zweimal hintereinander (Kraulen, dann Füttern): Blase zeigt die letzte", function()
    local Wild = require("game.wild")
    local d = H.wild({rng = Rng.new(2)})
    local h = Wild.Horse.new({}, d, 0, 0)
    h:react("emo_heart", 120)
    h:react("emo_apple", 120)
    C.eq(B.choose(h, frame()), "emo_apple")
  end},
}
