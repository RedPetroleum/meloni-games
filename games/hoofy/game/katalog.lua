-- Zugriff auf die Werte aus KATALOG.md (erzeugt nach data/*.lua von tools/hoofy_katalog.py).
-- Listen bleiben in Katalog-Reihenfolge, dazu Nachschlagen per id: K.rasse("mustang").
local K = {
  zeit = require("data.zeit"),
  stats = require("data.stats"),
  rassen = require("data.rassen"),
  farben = require("data.farben"),
  charakter = require("data.charakter"),
  wert = require("data.wert"),
  futter = require("data.futter"),
  ausruestung = require("data.ausruestung"),
  bau = require("data.bau"),
  welt = require("data.welt"),
  schaetze = require("data.schaetze"),
  jobs = require("data.jobs"),
  turniere = require("data.turniere"),
  reformen = require("data.reformen"),
  wirtschaft = require("data.wirtschaft"),
}

local function index(list)
  local by = {}
  for _, e in ipairs(list) do by[e.id] = e end
  return function(id)
    local e = by[id]
    if not e then error("Katalog: unbekannte id " .. tostring(id), 2) end
    return e
  end
end

K.rasse = index(K.rassen.liste)
K.farbe = index(K.farben.liste)
K.bauteil = index(K.bau.liste)
K.artikel = index(K.ausruestung.liste)
K.fahrzeug = index(K.welt.fahrzeuge)

return K
