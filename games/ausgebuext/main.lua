-- Ausgebüxt!: Das Gatter stand offen, die Pferde sind über den ganzen Hof verteilt.
-- Bring sie vor Sonnenuntergang zurück auf die Koppel.
-- A: Pferd nehmen / loslassen (auch: Möhre ernten, bockendem Pferd gut zureden), B halten: rennen.
--
-- Aufbau (auch als Grundlage für Hoofy gedacht):
--   lib/    spielunabhängig: Kachelkarte, Welt mit Tiefensortierung, Kamera, Spur, Bewegung, Effekte
--   game/   dieses Spiel: Legende, Pferde und Charakterzüge, Spieler, Level, Szenen, Töne
local scenes = {
  title = require("game.title"),
  play = require("game.play"),
}

local current

local function go(name, ...)
  current = scenes[name]
  current.enter(...)
end

function _init()
  go("title")
end

function _update()
  local next_scene, arg = current.update()
  if next_scene then go(next_scene, arg) end
end

function _draw()
  current.draw()
end
