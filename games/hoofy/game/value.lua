-- Pferdewert (KATALOG §6): Leistung, Wert, Kaufpreis beim Händler.
local K = require("game.katalog")
local H = require("game.horse_model")

local V = {}

-- Leistung = (Tempo + Stärke + Spür + (Ausdauer − 50) × 2) / 400 mit den Gesamtwerten.
function V.leistung(d)
  local W = K.wert
  local t, s, sp, a = H.stat(d, "tempo"), H.stat(d, "staerke"), H.stat(d, "spuer"), H.stat(d, "ausdauer")
  return (t + s + sp + (a - W.ausdauer_basis) * W.ausdauer_faktor) / W.leistung_teiler
end

-- Farbfaktor der sichtbaren Farbe (Stufe aus KATALOG §4).
function V.farbfaktor(d)
  return K.farben.stufen[K.farbe(d.farbe).stufe].faktor
end

-- Wert = Grundwert × Farbfaktor × (0,5 + Leistung) × Alter (Fohlen ×0,6). Nicht gerundet.
function V.wert_roh(d)
  local W = K.wert
  local alter = d.alter < 1 and W.fohlen_faktor or 1
  return K.rasse(d.rasse).grundwert * V.farbfaktor(d) * (W.leistung_basis + V.leistung(d)) * alter
end

function V.wert(d)
  return flr(V.wert_roh(d) + 0.5)
end

-- Kaufen beim Händler: Wert × 1,3.
function V.kaufpreis(d)
  return flr(V.wert_roh(d) * K.wert.kauf_faktor + 0.5)
end

return V
