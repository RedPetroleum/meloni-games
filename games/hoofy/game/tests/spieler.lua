-- Selbsttests für Bewegung und Kollision (Aufgabe A2).
local Stage = require("game.stage")
local Body = require("lib.body")
local C = require("game.tests.check")

-- Läuft n Schritte zu je (dx, dy) Pixeln, gibt zurück, wie weit die Figur gekommen ist.
local function walk(e, map, dx, dy, n)
  local x0, y0 = e.x, e.y
  for _ = 1, n do Body.move(e, dx, dy, map) end
  return abs(e.x - x0) + abs(e.y - y0)
end

return {
  {"über die Brücke ja, ins Wasser und in den Wald nein", function()
    local ctx = Stage.build(1)
    local map, br = ctx.map, ctx.area.places.bruecke
    C.ok(br, "keine Brücke")
    local horiz = map:code(br[1], br[2]) == "="
    local e = {x = br[1] * 16 + 8, y = br[2] * 16 + 10, fw = 8, fh = 4}
    -- längs der Brücke 3 Kacheln weit
    local along = horiz and walk(e, map, 1, 0, 48) or walk(e, map, 0, 1, 48)
    C.eq(along, 48, "längs über die Brücke")
    -- quer von der Brücke ins Wasser: höchstens bis zum Rand der Kachel
    e.x, e.y = br[1] * 16 + 8, br[2] * 16 + 10
    local across = horiz and walk(e, map, 0, 1, 40) or walk(e, map, 1, 0, 40)
    C.ok(across < 16, "quer ins Wasser " .. across)
    -- vom Hof nach Norden bis zum Wald oder Kartenrand: nie in eine Waldkachel
    local st = ctx.area.places.start
    e.x, e.y = st[1] * 16 + 8, st[2] * 16 + 14
    for _ = 1, 2000 do Body.move(e, 0, -1, map) end
    C.ok(not map:ground_at(e.x, e.y - 4).solid, "steht in festem Boden")
    C.ok(e.y > 0, "Rand")
  end},
}
