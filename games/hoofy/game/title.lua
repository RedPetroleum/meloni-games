-- Titelbild: der Hof im Hintergrund, START oder A: los.
local Stage = require("game.stage")
local Maps = require("game.maps")

local Title = {}

local ctx, t

function Title.enter()
  ctx = Stage.build(Maps.start)
  ctx.player.frozen = true
  t = 0
end

function Title.update()
  t = t + 1
  ctx.world:update()
  if btnp(BTN_START) or btnp(BTN_A) then
    ctx.sfx.start()
    return "world"
  end
end

function Title.draw()
  Stage.draw_world(ctx)
  local C = ctx.colors
  local title = "Hoofy"
  local x = (SCREEN_W - textw(title, 4)) // 2
  for dy = 1, 3 do print(title, x + 2, 20 + dy, C.panel, 4) end
  print(title, x, 20, C.gold, 4)
  Stage.panel(40, 170, 279, 225)
  Stage.center("Pferdezüchter im Jahr 2040", 180, C.dim)
  if (t // 30) % 2 == 0 then Stage.center("START oder A: los!", 204, C.gold) end
end

return Title
