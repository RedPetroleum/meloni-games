-- Tauschcode (Aufgabe E6): Ein Pferd wird zu einem Code aus 28 Zeichen, den ein anderer Spieler eingibt (ohne Server).
-- Alphabet: 32 Zeichen, A–Z ohne I und O sowie 2–9 (5 Bit je Zeichen). Der Code trägt Rasse, Geschlecht, Charakter, beide
-- Farben, Gen, Training und Potenzial der vier Werte, Bindung und Alter, dazu eine 16-Bit-Kennung und eine 10-Bit-Prüfsumme.
-- Nicht dabei: Name (wird aus der Kennung gewählt, umbenennbar), Stammbaum, Ausrüstung (kommt zurück in den Vorrat),
-- Tageszustand (Hunger, Sauberkeit, Gewicht, Energie starten neu).
local K = require("game.katalog")
local H = require("game.horse_model")
local Economy = require("game.economy")

local T = {}

T.ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
T.LENGTH = 28

local FARBEN, FARB_IDX, RASSE_IDX = {}, {}, {}
for i, f in ipairs(K.farben.liste) do FARBEN[i] = f.id; FARB_IDX[f.id] = i - 1 end
for i, r in ipairs(K.rassen.liste) do RASSE_IDX[r.id] = i - 1 end
local TRAIT_IDX = {}
for i, t in ipairs(H.TRAITS) do TRAIT_IDX[t] = i - 1 end

local function put(bits, value, n)
  for i = n - 1, 0, -1 do bits[#bits + 1] = (value >> i) & 1 end
end

local function get(bits, pos, n)
  local v = 0
  for i = 0, n - 1 do v = (v << 1) | bits[pos + i] end
  return v, pos + n
end

-- Prüfsumme über die Nutzbits (Position fließt ein, Vertauschungen fallen auf).
local function check(bits, n)
  local h = 0
  for i = 1, n do h = (h * 31 + bits[i] * 7 + i) % 1021 end
  return h
end

-- Kennung 0–65535 aus der Pferde-ID (Ziffernfolge) bzw. dem Namen als Rückfall.
local function kennung(d)
  local n = tonumber((d.id or ""):sub(1, 6))
  if n then return n % 65536 end
  local h = 0
  for i = 1, #(d.name or "") do h = (h * 31 + d.name:byte(i)) % 65536 end
  return h
end

-- Pferd (Daten) → Code (28 Zeichen, ohne Trennstriche).
function T.encode(d)
  local bits = {}
  put(bits, RASSE_IDX[d.rasse], 4)
  put(bits, d.sex == "m" and 1 or 0, 1)
  put(bits, TRAIT_IDX[d.zug], 3)
  put(bits, FARB_IDX[d.farbe], 5)
  put(bits, FARB_IDX[d.farbe2 or d.farbe], 5)
  for _, k in ipairs(H.STATS) do put(bits, flr(d.gen[k] + 0.5), 7) end
  for _, k in ipairs(H.STATS) do put(bits, flr(d.train[k] + 0.5), 7) end
  for _, k in ipairs(H.STATS) do put(bits, flr(d.pot[k] + 0.5), 7) end
  put(bits, flr(d.bindung + 0.5), 7)
  put(bits, flr(math.min(1, d.alter) * 15 + 0.5), 4)
  put(bits, kennung(d), 16)
  put(bits, check(bits, #bits), 10)
  while #bits < T.LENGTH * 5 do bits[#bits + 1] = 0 end
  local out = {}
  for i = 0, T.LENGTH - 1 do
    local v = 0
    for j = 1, 5 do v = (v << 1) | bits[i * 5 + j] end
    out[#out + 1] = T.ALPHABET:sub(v + 1, v + 1)
  end
  return table.concat(out)
end

-- Eingabe säubern: Trennstriche/Leerzeichen weg, Großbuchstaben; O → 0 gibt es nicht, I und O sind keine Zeichen.
function T.clean(text)
  return (text:upper():gsub("[%s%-]", ""))
end

-- Code in Gruppen zu je 4 mit Strich: "ABCD-EFGH-…".
function T.format(code)
  local out = {}
  for i = 1, #code, 4 do out[#out + 1] = code:sub(i, i + 3) end
  return table.concat(out, "-")
end

-- Code → Pferd (Daten) oder nil und Grund ("Länge", "Zeichen", "Prüfsumme", "ungültig").
function T.decode(text)
  local code = T.clean(text)
  if #code ~= T.LENGTH then return nil, "Länge" end
  local bits = {}
  for i = 1, #code do
    local v = T.ALPHABET:find(code:sub(i, i), 1, true)
    if not v then return nil, "Zeichen" end
    put(bits, v - 1, 5)
  end
  local n = 4 + 1 + 3 + 5 + 5 + 84 + 7 + 4 + 16
  local stored = get(bits, n + 1, 10)
  if stored ~= check(bits, n) then return nil, "Prüfsumme" end
  local pos = 1
  local r, s, z, f1, f2
  r, pos = get(bits, pos, 4)
  s, pos = get(bits, pos, 1)
  z, pos = get(bits, pos, 3)
  f1, pos = get(bits, pos, 5)
  f2, pos = get(bits, pos, 5)
  local rasse, zug, farbe, farbe2 = K.rassen.liste[r + 1], H.TRAITS[z + 1], FARBEN[f1 + 1], FARBEN[f2 + 1]
  if not (rasse and zug and farbe and farbe2) then return nil, "ungültig" end
  local d = {rasse = rasse.id, sex = s == 1 and "m" or "w", zug = zug, farbe = farbe, farbe2 = farbe2, gen = {}, train = {}, pot = {}}
  for _, k in ipairs(H.STATS) do d.gen[k], pos = get(bits, pos, 7) end
  for _, k in ipairs(H.STATS) do d.train[k], pos = get(bits, pos, 7) end
  for _, k in ipairs(H.STATS) do d.pot[k], pos = get(bits, pos, 7) end
  for _, k in ipairs(H.STATS) do
    if d.gen[k] > 100 or d.pot[k] > 100 or d.pot[k] < d.gen[k] then return nil, "ungültig" end
    d.train[k] = math.min(d.train[k], d.pot[k] - d.gen[k])
  end
  d.bindung, pos = get(bits, pos, 7)
  local alter
  alter, pos = get(bits, pos, 4)
  d.kennung = get(bits, pos, 16)
  if d.bindung > 100 then return nil, "ungültig" end
  d.alter = alter / 15
  return d
end

-- Frisches Pferd aus den dekodierten Daten (Tageszustand neu, Name aus der Kennung, ID eindeutig).
function T.pferd(d)
  local S = K.stats
  d.name = H.NAMES[d.kennung % #H.NAMES + 1]
  d.id = string.format("%06d900", d.kennung * 15 % 1000000)
  d.hunger, d.gewicht, d.sauberkeit = S.hunger.start, S.gewicht.start, S.sauberkeit.start
  d.energie = H.stat(d, "ausdauer")
  d.kennung = nil
  return d
end

-- Pferd abgeben: Ausrüstung zurück in den Vorrat, Pferd aus Herde und Welt, Code zurück. Gibt Code oder nil, Grund.
function T.abgeben(ctx, d)
  local idx
  for i, e in ipairs(ctx.herd) do if e == d then idx = i end end
  if not idx then return nil, "nicht im Bestand" end
  for _, h in ipairs(ctx.herd_horses) do if h.data == d and h.state == "ridden" then return nil, "wird geritten" end end
  local code = T.encode(d)
  local worn = {}
  if d.taschen then worn[#worn + 1] = d.taschen end
  if d.sattel then worn[#worn + 1] = d.sattel end
  if d.lampe then worn[#worn + 1] = "sattellampe" end
  for _, j in ipairs(Economy.JEWELRY) do if d.schmuck and d.schmuck[j] then worn[#worn + 1] = j end end
  for _, id in ipairs(worn) do Economy.unequip(ctx, d, id) end
  for i, h in ipairs(ctx.herd_horses) do
    if h.data == d then h.dead = true table.remove(ctx.herd_horses, i) break end
  end
  for i, h in ipairs(ctx.lead) do if h.data == d then table.remove(ctx.lead, i) break end end
  table.remove(ctx.herd, idx)
  ctx.getauscht = ctx.getauscht or {}
  ctx.getauscht[code] = true
  return code
end

-- Code einlösen: Pferd kommt an die Leine. Gibt Pferd (Figur) oder nil, Grund. Dieselbe Eingabe zweimal in
-- einem Spielstand geht nicht (Grund "schon benutzt").
function T.annehmen(ctx, text)
  local d, why = T.decode(text)
  if not d then return nil, why end
  local code = T.clean(text)
  ctx.getauscht = ctx.getauscht or {}
  if ctx.getauscht[code] then return nil, "schon benutzt" end
  if #ctx.herd >= require("game.market").MAX_HERD then return nil, "voll" end
  local h = ctx.wild:adopt(T.pferd(d))
  ctx.getauscht[code] = true
  return h
end

return T
