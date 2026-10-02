-- Pferdewert (KATALOG §6): Leistung, Stammbaum, Wert, Kaufpreis beim Händler.
local K = require("game.katalog")
local H = require("game.horse_model")

local V = {}

-- Leistung L = Potenzmittel der vier Gen-Stats und der Bindung (halb gewichtet), 0..1.
local function leistung(t, s, sp, a, b)
  local W = K.wert
  local x = W.exponent
  local sum = (t / 100) ^ x + (s / 100) ^ x + (sp / 100) ^ x + (a / 100) ^ x + W.bindung_gewicht * (b / 100) ^ x
  return (sum / W.leistung_teiler) ^ (1 / x)
end

-- bindung: statt d.bindung (für den neutralen Wert).
function V.leistung(d, bindung)
  return leistung(H.stat(d, "tempo"), H.stat(d, "staerke"), H.stat(d, "spuer"), H.stat(d, "ausdauer"), bindung or d.bindung)
end

-- L eines wilden Durchschnittspferds der Rasse (Stats und Bindung aus KATALOG §3).
local rasse_l = {}
function V.leistung_rasse(id)
  if not rasse_l[id] then
    local r = K.rasse(id)
    rasse_l[id] = leistung(r.tempo, r.staerke, r.spuer, r.ausdauer, r.bindung)
  end
  return rasse_l[id]
end

-- Leistungsfaktor = max(Min, 1 + Steigung × (L / L_Rasse − 1)); Durchschnittspferd der Rasse = 1.
function V.leistungsfaktor(d, bindung)
  local W = K.wert
  return max(W.faktor_min, 1 + W.steigung * (V.leistung(d, bindung) / V.leistung_rasse(d.rasse) - 1))
end

-- Farbfaktor der sichtbaren Farbe (Stufe aus KATALOG §4).
function V.farbfaktor(d)
  return K.farben.stufen[K.farbe(d.farbe).stufe].faktor
end

-- Stammbaum-Bonus in Prozent: je bekanntem Vorfahren nach Generation (Eltern, Großeltern, Urgroßeltern).
function V.stammbaum(d)
  local pro = K.wert.stammbaum
  local function sum(node, gen)
    if not node or not pro[gen] then return 0 end
    return pro[gen] + sum(node.v, gen + 1) + sum(node.m, gen + 1)
  end
  if not d.ahnen then return 0 end
  return sum(d.ahnen.v, 1) + sum(d.ahnen.m, 1)
end

-- Wert = Grundwert × Farbfaktor × Leistungsfaktor × Alter (Fohlen ×0,6) × (1 + Stammbaum). Nicht gerundet.
-- bindung: statt d.bindung.
function V.wert_roh(d, bindung)
  local W = K.wert
  local alter = d.alter < 1 and W.fohlen_faktor or 1
  return K.rasse(d.rasse).grundwert * V.farbfaktor(d) * V.leistungsfaktor(d, bindung) * alter * (1 + V.stammbaum(d) / 100)
end

-- Neutraler Wert (Käufer): mit der Start-Bindung der Rasse statt der eigenen Bindung.
function V.wert_neutral(d)
  return V.wert_roh(d, K.rasse(d.rasse).bindung)
end

function V.wert(d)
  return flr(V.wert_roh(d) + 0.5)
end

-- Kaufen beim Händler: Wert × 1,5.
function V.kaufpreis(d)
  return flr(V.wert_roh(d) * K.wert.kauf_faktor + 0.5)
end

return V
