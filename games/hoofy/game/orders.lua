-- Bestellungen (README §4, KATALOG §6/§13): alle 3 Tage gibt ein Käufer einen Auftrag wie
-- „braune Stute, Geschwindigkeit über 50, bis Tag 20“. Liefert man ein passendes Pferd, zahlt er
-- Wert × 1,5. Nach der Frist (5–10 Tage) verfällt die Bestellung.
local K = require("game.katalog")
local H = require("game.horse_model")
local V = require("game.value")
local Rng = require("lib.rng")

local O = {}

O.CLIENTS = {
  "Frau Schmitt", "Herr Meier", "Familie Kowalski", "Gräfin von Hufstein", "Bäcker Brandt", "Landwirt Fuhrmann",
  "Reitschule Sonnenhof", "Tante Gerda", "Zirkus Mirabelli", "Dr. Schimmel", "Bürgermeister Müller", "Die Zwillinge Lotte und Lene",
}

O.STATS = {
  tempo = {name = "Geschwindigkeit", key = "tempo"},
  staerke = {name = "Stärke", key = "staerke"},
  spuer = {name = "Aufspürung", key = "spuer"},
  ausdauer = {name = "Ausdauer", key = "ausdauer"},
}
local STAT_LIST = {"tempo", "staerke", "spuer", "ausdauer"}

-- Farbe als Adjektiv für den Text: aus dem Katalognamen (Brauner → braune Stute).
local ADJ = {
  Brauner = "braune", Fuchs = "Fuchs-", Dunkelbrauner = "dunkelbraune", Hellfuchs = "hellfuchsfarbene", Rappe = "schwarze",
  Grauschimmel = "graue", Falbe = "falbfarbene", Isabell = "isabellfarbene", Schimmel = "weiße", Dunkelfuchs = "dunkelfuchsfarbene",
  Mausfalbe = "mausfalbe", Rotschimmel = "rotschimmelfarbene", Braunschecke = "braun gescheckte", Palomino = "Palomino-",
  Rappschecke = "schwarz gescheckte", Fuchsschecke = "fuchs gescheckte", Apfelschimmel = "apfelgraue", Fliegenschimmel = "fliegenschimmelfarbene",
  Silberrappe = "silberschwarze", Windfarben = "windfarbene", Tigerschecke = "tigergescheckte", Cremello = "Cremello-", Perlino = "Perlino-",
  Champagner = "champagnerfarbene", Rosa = "rosa", ["Mintgrün"] = "mintgrüne", Gold = "goldene", Regenbogen = "Regenbogen-", Lila = "lila", Zebra = "Zebra-",
}

-- Text der Bestellung, z. B. „braune Stute, Geschwindigkeit über 50, bis Tag 20“.
function O.text(o)
  local f = K.farbe(o.farbe).name
  local adj = ADJ[f] or f
  local noun = o.sex == "m" and "Hengst" or "Stute"
  local prefix = adj:sub(-1) == "-" and (adj .. noun) or (adj .. " " .. noun)
  prefix = prefix:sub(1, 1):upper() .. prefix:sub(2)
  return string.format("%s, %s über %d, bis Tag %d", prefix, O.STATS[o.stat].name, o.min, o.frist)
end

-- Eine Bestellung aus Seed und Tag (deterministisch). max_gebiet bestimmt Farbauswahl und Anspruch.
function O.generate(seed, day, max_gebiet)
  local W = K.wert.kaeufer.bestellung
  local rng = Rng.new((seed or 1) * 613 + day * 29 + 11)
  local g = max_gebiet or 1
  -- Farbe: sichtbar in der Matrix einer erreichbaren Rasse, eher häufig (Stufe 1–3)
  local rasse
  for _ = 1, 20 do
    local r = K.rassen.liste[rng:int(1, #K.rassen.liste)]
    if r.gebiet <= g then rasse = r break end
  end
  rasse = rasse or K.rassen.liste[1]
  local per = K.farben.matrix[rasse.id]
  local farbe
  for _ = 1, 20 do
    local tier = rng:int(1, 3)
    if #per[tier] > 0 then farbe = per[tier][rng:int(1, #per[tier])] break end
  end
  farbe = farbe or per[1][1] or per[2][1]
  local stat = STAT_LIST[rng:int(1, 4)]
  local base = stat == "ausdauer" and 60 or 40
  local min = base + rng:int(0, 4) * 5 + (g - 1) * 5
  return {
    kunde = O.CLIENTS[rng:int(1, #O.CLIENTS)], farbe = farbe, sex = rng:next() < 0.5 and "m" or "w",
    stat = stat, min = min, erstellt = day, frist = day + rng:int(W.frist_min, W.frist_max),
  }
end

-- Bestellung, die das Pferd d genau erfüllt (für Szenarien und Tests).
function O.for_horse(d, day, kunde)
  local stat = "tempo"
  return {
    kunde = kunde or O.CLIENTS[1], farbe = d.farbe, sex = d.sex, stat = stat, min = max(1, flr(H.stat(d, stat)) - 2),
    erstellt = day or 1, frist = (day or 1) + 7,
  }
end

function O.matches(o, d)
  return d.farbe == o.farbe and d.sex == o.sex and H.stat(d, o.stat) >= o.min
end

-- Was die Lieferung von d einbringt: Wert × Bestellfaktor.
function O.reward(d)
  return flr(V.wert_roh(d) * K.wert.kaeufer.bestellung.faktor + 0.5)
end

-- Liefert Pferd d für Bestellung o (aus ctx.orders). Gibt Belohnung oder nil, Grund zurück.
function O.deliver(ctx, o, d)
  if not O.matches(o, d) then return nil, "passt nicht" end
  local idx
  for i, e in ipairs(ctx.herd) do if e == d then idx = i end end
  if not idx then return nil, "nicht im Bestand" end
  for i, h in ipairs(ctx.herd_horses) do
    if h.data == d then
      if h.state == "ridden" then return nil, "wird geritten" end
      h.dead = true
      table.remove(ctx.herd_horses, i)
      break
    end
  end
  for i, h in ipairs(ctx.lead) do if h.data == d then table.remove(ctx.lead, i) break end end
  table.remove(ctx.herd, idx)
  require("game.economy").strip(ctx, d)       -- Sattel, Schmuck … bleiben bei dir (Rückmeldung 1.3.1)
  local sum = O.reward(d)
  ctx.money = ctx.money + sum
  for i, e in ipairs(ctx.orders) do if e == o then table.remove(ctx.orders, i) break end end
  return sum
end

-- Tageswechsel (day = neuer Tag): verfallene Bestellungen entfernen, alle 3 Tage eine neue.
-- Gibt {neu = Bestellung oder nil, verfallen = Liste} zurück.
function O.tick(ctx, day)
  local W = K.wert.kaeufer.bestellung
  local out = {verfallen = {}}
  for i = #ctx.orders, 1, -1 do
    if day > ctx.orders[i].frist then
      out.verfallen[#out.verfallen + 1] = table.remove(ctx.orders, i)
    end
  end
  if (day - 1) % W.alle_tage == 0 and require("game.fortschritt").offen("bestellungen", day) then
    out.neu = O.generate(ctx.seed, day, ctx.max_gebiet)
    ctx.orders[#ctx.orders + 1] = out.neu
  end
  return out
end

return O
