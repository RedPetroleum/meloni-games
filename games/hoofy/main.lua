-- Hoofy: Pferde finden, pflegen, züchten und verkaufen, den Hof ausbauen (README_HOOFY.md).
-- Werte aus KATALOG.md, Bau-Regeln in LOOP.md, Stand in PLAN.md.
--
-- Aufbau wie Ausgebüxt:
--   lib/    spielunabhängig: Kachelkarte, Welt mit Tiefensortierung, Kamera, Spur, Bewegung, Effekte
--   game/   Hoofy: Szenen, Spieler, Pferde, Regeln
local scenes = {
  title = require("game.title"),
  world = require("game.world"),
  overview = require("game.overview"),
  gallery = require("game.gallery"),
}

local current

local function go(name, ...)
  current = scenes[name]
  current.enter(...)
end

function _init()
  -- Test-Spielstand {scenario = "…"} (tools/hoofy-test.sh): direkt in diese Ausgangslage.
  local save = loaddata()
  if save and save.scenario then
    go(require("game.scenarios").start(save))
  else
    go("title")
  end
end

function _update()
  local next_scene, arg = current.update()
  if next_scene then go(next_scene, arg) end
end

function _draw()
  current.draw()
end
