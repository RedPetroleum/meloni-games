-- Selbsttests für Wildpferde in der Welt (Aufgabe A5).
local Stage = require("game.stage")
local Wild = require("game.wild")
local K = require("game.katalog")
local C = require("game.tests.check")

local function setup()
  local ctx = Stage.build(1)
  local w = Wild.new(ctx, 3)
  w:fill()
  return ctx, w
end

local function ids(w)
  local set = {}
  for _, h in ipairs(w.list) do set[h] = true end
  return set
end

return {
  {"Heimattal: 4 Wildpferde auf begehbaren Wiesen", function()
    local ctx, w = setup()
    C.eq(#w.list, K.welt.gebiete[1].wildpferde)
    for _, h in ipairs(w.list) do
      C.ok(ctx.map:walkable(h.x // 16, (h.y - 2) // 16), "Pferd auf unbegehbarer Kachel")
      C.ok(not ctx.map:blocked(h.x - 7, h.y - 6, h.x + 7, h.y), "Pferd steckt fest")
    end
  end},
  {"Wechsel nur alle 3 Tage, dann 1–2 neue, Anzahl bleibt", function()
    local _, w = setup()
    local before = ids(w)
    for day = 1, 3 do C.eq(w:new_day(day), 0, "Tag " .. day) end
    C.eq(#w.list, 4)
    local gone = w:new_day(4)
    C.between(gone, 1, 2, "Wechsel an Tag 4")
    C.eq(#w.list, 4, "Anzahl nach Wechsel")
    local fresh = 0
    for _, h in ipairs(w.list) do if not before[h] then fresh = fresh + 1 end end
    C.between(fresh, 1, 2, "neue Pferde")
    C.eq(fresh, gone, "so viele neue wie gegangene")
    for day = 5, 6 do C.eq(w:new_day(day), 0) end
    C.between(w:new_day(7), 1, 2, "nächster Wechsel an Tag 7")
  end},
  {"Pferde laufen 600 Frames ohne in Hindernisse zu geraten, in der Nähe bleibt es grasend stehen", function()
    local ctx, w = setup()
    local h = w.list[1]
    ctx.player.x, ctx.player.y = h.x + 30, h.y
    ctx.player.moving = false
    h.state, h.timer = "walk", 50
    local x0 = h.x
    for _ = 1, 100 do h:update() end
    C.eq(h.state, "graze", "steht in der Nähe und grast")
    C.eq(h.x, x0, "läuft nicht weg")
    ctx.player.running, ctx.player.moving = true, true
    h:update()
    C.eq(h.state, "flee", "Sprinten verscheucht es")
    ctx.player.running, ctx.player.moving = false, false
    for _ = 1, 600 do ctx.world:update() end
    for _, e in ipairs(w.list) do
      C.ok(require("lib.body").free(ctx.map, e.x, e.y, e.fw, e.fh), "Pferd steckt in Hindernis")
    end
  end},
  {"Fliehendes Pferd vor einer Wand weicht seitlich aus, statt hängen zu bleiben", function()
    local ctx, w = setup()
    local h = w.list[1]
    -- Mauer aus Steinen 2 Kacheln rechts vom Pferd, Spieler links: geradeaus geht es nicht weiter
    local cx, cy = h.x // 16 + 2, (h.y - 2) // 16
    for dy = -4, 4 do ctx.map:set("coll", cx, cy + dy, "o") end
    ctx.player.x, ctx.player.y = h.x - 40, h.y
    h:flee(ctx.player)
    local x0 = h.x
    local max_moved = 0
    for _ = 1, 80 do
      h:update()
      max_moved = math.max(max_moved, math.abs(h.y - ctx.player.y))
    end
    C.ok(max_moved > 40, "seitlich ausgewichen: " .. flr(max_moved))
    C.ok(require("game.wild").Horse.flee_dir ~= nil)
  end},
}
