-- Hoofy: Pferde finden, pflegen, züchten und verkaufen, den Hof ausbauen (README_HOOFY.md).
-- Werte aus KATALOG.md, Bau-Regeln in LOOP.md, Stand in PLAN.md.
--
-- Aufbau wie Ausgebüxt:
--   lib/    spielunabhängig: Kachelkarte, Welt mit Tiefensortierung, Kamera, Spur, Bewegung, Effekte
--   game/   Hoofy: Szenen, Spieler, Pferde, Regeln
local scenes = {
  title = require("game.title"),
  world = require("game.world"),
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
