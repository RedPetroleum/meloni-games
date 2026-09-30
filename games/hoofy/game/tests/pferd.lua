-- Selbsttests für das Pferdemodell und Wildpferde (Aufgabe A4), je 10 000 Würfe.
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local N = 10000

local function stats(list)
  local sum, sq = 0, 0
  for _, v in ipairs(list) do sum = sum + v end
  local mean = sum / #list
  for _, v in ipairs(list) do sq = sq + (v - mean) ^ 2 end
  return mean, math.sqrt(sq / #list)
end

return {
  {"Gen-Stats: Mittel ≈ Rassenwert, σ ≈ 8 (Haflinger, 10 000)", function()
    local rng = Rng.new(5)
    local r = K.rasse("haflinger")
    local vals = {tempo = {}, staerke = {}, spuer = {}, ausdauer = {}}
    for _ = 1, N do
      local h = H.wild({rasse = "haflinger", rng = rng})
      for k, list in pairs(vals) do list[#list + 1] = h.gen[k] end
    end
    for k, list in pairs(vals) do
      local mean, sd = stats(list)
      C.near(mean, r[k], 0.6, k .. " Mittel")
      if k ~= "ausdauer" then C.near(sd, K.stats.gen_sigma, 0.4, k .. " σ") end
      log(string.format("PFERD haflinger %s Mittel %.2f σ %.2f", k, mean, sd))
    end
  end},
  {"Max-Potenzial ≤ 100 und ≥ Gen, Ausdauer 50–100, Stats 1–100 (alle Gebiete)", function()
    local rng = Rng.new(6)
    for i = 1, N do
      local h = H.wild({gebiet = 1 + i % 6, rng = rng})
      for _, k in ipairs(H.STATS) do
        C.ok(h.pot[k] <= 100, "Potenzial über 100")
        C.ok(h.pot[k] >= h.gen[k], "Potenzial unter Gen")
        C.between(h.gen[k], k == "ausdauer" and 50 or 1, 100, k)
      end
      C.between(h.energie, 50, 100, "Energie = Ausdauer")
      C.between(h.bindung, 0, 100, "Bindung")
    end
  end},
  {"Farbstufen ≈ 40/30/18/9/3 % (Shetlandpony hat alle Stufen)", function()
    local rng = Rng.new(7)
    local count = {0, 0, 0, 0, 0}
    for _ = 1, N do
      local h = H.wild({rasse = "shetlandpony", rng = rng})
      local s = K.farbe(h.farbe).stufe
      count[s] = count[s] + 1
    end
    for i, st in ipairs(K.farben.stufen) do
      C.near(count[i] * 100 / N, st.anteil, 2, st.name)
    end
    log("PFERD Farbstufen Shetlandpony " .. table.concat(count, "/"))
  end},
  {"Farben nur aus der Matrix, versteckte gleich selten oder seltener, fehlende Stufe verteilt", function()
    local rng = Rng.new(8)
    local count = {0, 0, 0, 0, 0}
    for _ = 1, N do
      local h = H.wild({rasse = "haflinger", rng = rng})
      local s, s2 = K.farbe(h.farbe).stufe, K.farbe(h.farbe2).stufe
      C.ok(s2 >= s, "versteckte häufiger als sichtbare")
      local found = false
      for _, f in ipairs(K.farben.matrix.haflinger[s]) do found = found or f == h.farbe end
      C.ok(found, "Farbe nicht in der Matrix: " .. h.farbe)
      count[s] = count[s] + 1
    end
    C.eq(count[3], 0, "Haflinger hat keine seltene Farbe")
    -- 18 % der fehlenden Stufe verteilen sich: häufig 40/82 ≈ 48,8 %
    C.near(count[1] * 100 / N, 40 / 82 * 100, 2, "häufig")
  end},
  {"Gebietsstufen verschieben Anteile, Rassen je Gebiet", function()
    local s1, s4 = H.tier_shares(1), H.tier_shares(4)
    C.near(s4[1], 40 - 9, 0.01, "häufig in Gebiet 4")
    local sum = 0
    for _, v in ipairs(s4) do sum = sum + v end
    C.near(sum, 100, 0.01, "Summe")
    C.ok(s4[5] > s1[5], "legendär häufiger")
    local rng = Rng.new(9)
    local seen = {}
    for _ = 1, 2000 do
      local r = H.wild_breed(1, rng)
      C.eq(K.rasse(r).gebiet, 1, "Gebiet 1 nur eigene Rassen")
      seen[H.wild_breed(3, rng)] = true
    end
    C.ok(seen.friese and seen.haflinger, "Gebiet 3: neue und alte Rassen")
    C.ok(not seen.araber, "Gebiet 3: keine späteren Rassen")
  end},
  {"Geschlecht 50:50, Charakter gleich verteilt, Zustände nach Katalog", function()
    local rng = Rng.new(10)
    local m, zug = 0, {}
    for _ = 1, N do
      local h = H.wild({rng = rng})
      if h.sex == "m" then m = m + 1 end
      zug[h.zug] = (zug[h.zug] or 0) + 1
      C.eq(h.hunger, 30)
      C.eq(h.sauberkeit, 60)
      C.ok(#h.name > 0, "Name")
    end
    C.near(m / N, 0.5, 0.02, "Hengste")
    for id in pairs(K.charakter) do C.near(zug[id] / N, 0.2, 0.02, id) end
  end},
}
