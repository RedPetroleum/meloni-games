-- Das Pferd als Daten (README_HOOFY §2, KATALOG §2–5): nur Zahlen und Strings, damit es sich
-- direkt speichern lässt. Regeln, die ein Pferd verändern (Training, Tageswechsel …), kommen mit
-- den späteren Aufgaben dazu.
--
--   h = {
--     name, rasse (id), sex ("m"/"w"), zug (Charakterzug-id), farbe, farbe2 (versteckt),
--     gen = {tempo, staerke, spuer, ausdauer}, train = {…}, pot = {…},   -- Gen, Training, Max-Potenzial
--     bindung, hunger, gewicht, sauberkeit, energie,
--     alter = 1 (ausgewachsen) oder 0 … < 1 (Fohlen, Anteil bis ausgewachsen), wild = true/nil,
--   }
local K = require("game.katalog")

local H = {}

H.STATS = {"tempo", "staerke", "spuer", "ausdauer"}

-- Namen für Wildpferde (E27), gemischt für Stuten und Hengste.
H.NAMES = {
  "Blitz", "Luna", "Karamell", "Sternchen", "Wolke", "Pünktchen", "Keks", "Nebel", "Toffee", "Zimt",
  "Schoko", "Paule", "Lotte", "Klecks", "Dörte", "Günther", "Horst", "Bruno", "Rosi", "Ferdinand",
  "Apfelstrudel", "Wuschel", "Donner", "Minze", "Pepper", "Gustav", "Kasimir", "Lilly", "Nala",
  "Pixel", "Quark", "Rudi", "Tinka", "Uschi", "Vroni", "Willi", "Yuki", "Zottel", "Hafermotte",
  "Brezel", "Mäxchen", "Frieda", "Socke", "Krümel", "Wirbel", "Honig", "Radieschen", "Fanta",
  "Bolle", "Gräfin", "Kekskrümel", "Momo", "Nugget", "Olga", "Piet", "Sprotte", "Tante Erna",
}

-- Zufall: rng mit rng:next() (0 <= r < 1), sonst rnd().
local function R(rng)
  if rng then return rng:next() end
  return rnd()
end

-- Normalverteilung (Box-Muller)
function H.gauss(rng, sigma)
  local u1 = max(R(rng), 1e-6)
  local u2 = R(rng)
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2) * sigma
end

local function round(x) return flr(x + 0.5) end

-- Gesamtwert eines Stats: Gen + Training, höchstens Max-Potenzial.
function H.stat(h, key)
  return min(h.gen[key] + h.train[key], h.pot[key])
end

-- Anteile der Farbstufen in Gebiet n (Prozent): pro Gebietsstufe gehen `gebiet_verschiebung` Punkte
-- von „häufig“ an die selteneren Stufen, im Verhältnis ihrer Anteile (E26).
function H.tier_shares(gebiet)
  local st, shift = K.farben.stufen, K.farben.gebiet_verschiebung * ((gebiet or 1) - 1)
  local rest = 0
  for i = 2, #st do rest = rest + st[i].anteil end
  local out = {st[1].anteil - shift}
  for i = 2, #st do out[i] = st[i].anteil + shift * st[i].anteil / rest end
  return out
end

-- Würfelt eine Stufe nach Anteilen; allowed[i] = false: Stufe fällt weg, ihr Anteil verteilt sich
-- auf die übrigen. from: nur Stufen ab dieser.
local function roll_tier(shares, allowed, rng, from)
  local total = 0
  for i = from or 1, #shares do
    if not allowed or allowed[i] then total = total + shares[i] end
  end
  local r = R(rng) * total
  for i = from or 1, #shares do
    if not allowed or allowed[i] then
      r = r - shares[i]
      if r < 0 then return i end
    end
  end
  for i = #shares, from or 1, -1 do
    if not allowed or allowed[i] then return i end
  end
end
H.roll_tier = roll_tier

local function pick(list, rng)
  return list[1 + flr(R(rng) * #list)]
end

-- Farbe eines Wildpferds: sichtbar nach Farbmatrix der Rasse, versteckt gleich selten oder seltener.
function H.wild_colors(rasse, gebiet, rng)
  local per = K.farben.matrix[rasse]
  local allowed = {}
  for i = 1, #per do allowed[i] = #per[i] > 0 end
  local shares = H.tier_shares(gebiet)
  local t = roll_tier(shares, allowed, rng)
  local t2 = roll_tier(shares, allowed, rng, t) or t
  return pick(per[t], rng), pick(per[t2], rng)
end

-- Rasse eines Wildpferds in Gebiet n: Rassen dieses Gebiets Gewicht 3, frühere Gebiete 1 (E25).
function H.wild_breed(gebiet, rng)
  local list, total = {}, 0
  for _, r in ipairs(K.rassen.liste) do
    if r.gebiet <= gebiet then
      local w = r.gebiet == gebiet and 3 or 1
      list[#list + 1] = {r.id, w}
      total = total + w
    end
  end
  local x = R(rng) * total
  for _, e in ipairs(list) do
    x = x - e[2]
    if x < 0 then return e[1] end
  end
  return list[#list][1]
end

local TRAITS = {"verfressen", "schreckhaft", "faul", "eitel", "nachteule"}
H.TRAITS = TRAITS
-- Bindung zum Start je Charakterzug (E15)
H.TRAIT_BOND = {schreckhaft = -10, faul = 5, verfressen = 5, eitel = 0, nachteule = 0}

-- Neues Wildpferd. opts: gebiet (Standard 1), rasse, sex, zug, rng.
function H.wild(opts)
  opts = opts or {}
  local rng = opts.rng
  local gebiet = opts.gebiet or 1
  local rasse = K.rasse(opts.rasse or H.wild_breed(gebiet, rng))
  local S = K.stats
  local h = {
    rasse = rasse.id, wild = true, alter = 1,
    sex = opts.sex or (R(rng) < 0.5 and "m" or "w"),
    zug = opts.zug or pick(TRAITS, rng),
    gen = {}, train = {}, pot = {},
  }
  for _, key in ipairs(H.STATS) do
    local lo, hi = S.gen_min, S.gen_max
    if key == "ausdauer" then lo, hi = S.ausdauer_min, S.ausdauer_max end
    local g = mid(lo, round(rasse[key] + H.gauss(rng, S.gen_sigma)), hi)
    local p = round(g + rasse.spanne + H.gauss(rng, S.potenzial_sigma))
    h.gen[key] = g
    h.train[key] = 0
    h.pot[key] = mid(g, p, S.potenzial_max)
  end
  h.farbe, h.farbe2 = H.wild_colors(rasse.id, gebiet, rng)
  h.bindung = mid(0, rasse.bindung + H.TRAIT_BOND[h.zug] + round((R(rng) * 2 - 1) * 5), 100)
  h.hunger = S.hunger.start
  h.gewicht = S.gewicht.start
  h.sauberkeit = S.sauberkeit.start
  h.energie = H.stat(h, "ausdauer")
  h.name = opts.name or pick(H.NAMES, rng)
  return h
end

-- Körperform für die Grafik (game/horse_gfx.lua)
function H.body(h)
  return K.rasse(h.rasse).koerper
end

return H
