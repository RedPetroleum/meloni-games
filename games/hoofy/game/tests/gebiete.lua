-- Selbsttests für die Gebiete 2–6 (Aufgabe D2): Größe, Palette, Wildpferde, Rassen.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local K = require("game.katalog")
local Tiles = require("game.tiles")
local C = require("game.tests.check")

return {
  {"Jedes Gebiet: Größe, Wildpferde und Palette nach Katalog; Hof nur im Heimattal", function()
    for nr, info in ipairs(K.welt.gebiete) do
      Area.clear()
      collectgarbage()
      local before = collectgarbage("count")
      local ctx = Stage.build(nr, 5)
      collectgarbage()
      log(string.format("GEBIET %d %s %dx%d: %.0f KB", nr, info.name, ctx.map.w, ctx.map.h, collectgarbage("count") - before))
      C.eq(ctx.map.w, info.w)
      C.eq(ctx.map.h, info.h)
      C.eq(Wild.new(ctx, 3).count, info.wildpferde)
      C.eq(Tiles.COLORS.grass, Tiles.PALETTES[info.palette][1], "Palette " .. info.palette)
      C.eq(ctx.area.farm ~= nil, nr == 1)
      C.ok(ctx.area.places.start and ctx.area.places.laden, "Start und Laden")
    end
    Area.clear()
    Stage.build(1, 1)
  end},
  {"Wildpferde: nur Rassen bis zum Gebiet, die neuen häufiger als frühere", function()
    local count = {}
    local rng = Rng.new(9)
    for _ = 1, 600 do
      local d = H.wild({gebiet = 4, rng = rng})
      count[d.rasse] = (count[d.rasse] or 0) + 1
    end
    local new, old = 0, 0
    for _, r in ipairs(K.rassen.liste) do
      local n = count[r.id] or 0
      if r.gebiet > 4 then C.eq(n, 0, r.id .. " kommt erst später") end
      if r.gebiet == 4 then new = new + n / 2 elseif r.gebiet < 4 then old = old + n / 7 end
    end
    C.ok(new > old * 1.5, "neue Rassen häufiger: " .. new .. " gegen " .. old)
  end},
}
