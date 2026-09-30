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
  {"Pferde laufen 600 Frames ohne in Hindernisse zu geraten, Annäherung löst Zähmen-Ablauf aus", function()
    local ctx, w = setup()
    local h = w.list[1]
    ctx.player.x, ctx.player.y = h.x + 30, h.y
    h:update()
    C.eq(h.state, "away", "schaut bei Annäherung erst weg (E16)")
    h.state, h.timer = "look", 50
    ctx.player.moving = true
    h:update()
    C.eq(h.state, "flee", "flieht, wenn sich der Spieler beim Hinschauen bewegt")
    ctx.player.moving = false
    for _ = 1, 600 do ctx.world:update() end
    for _, e in ipairs(w.list) do
      C.ok(not ctx.map:blocked(e.x - 7, e.y - 6, e.x + 7, e.y), "Pferd steckt in Hindernis")
    end
  end},
}
