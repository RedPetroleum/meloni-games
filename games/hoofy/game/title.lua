-- Titelbild: der Hof im Hintergrund, START oder A: los.
local Stage = require("game.stage")
local Save = require("game.save")

local Title = {}

local ctx, t

local has_save, choice

function Title.enter()
  local snap = Save.read()
  has_save = snap ~= nil
  choice = has_save and 1 or 2      -- 1 = Weiter, 2 = Neues Spiel
  ctx = snap and Stage.build(1, snap.seed, snap.hof) or Stage.build(1)
  ctx.player.frozen = true
  t = 0
end

function Title.update()
  t = t + 1
  ctx.world:update()
  if has_save and (btnp(BTN_UP) or btnp(BTN_DOWN)) then
    choice = 3 - choice
    ctx.sfx.select()
  end
  if btnp(BTN_START) or btnp(BTN_A) then
    ctx.sfx.start()
    return "world", choice == 1 and {laden = true} or {neu = true}
  end
end

function Title.draw()
  Stage.draw_world(ctx)
  local C = ctx.colors
  local title = "Hoofy"
  local x = (SCREEN_W - textw(title, 4)) // 2
  for dy = 1, 3 do print(title, x + 2, 20 + dy, C.panel, 4) end
  print(title, x, 20, C.gold, 4)
  Stage.panel(40, 182, 279, 225)
  if has_save then
    Stage.center((choice == 1 and "> " or "  ") .. "Weiter", 192, choice == 1 and C.gold or C.dim)
    Stage.center((choice == 2 and "> " or "  ") .. "Neues Spiel", 206, choice == 2 and C.gold or C.dim)
  elseif (t // 30) % 2 == 0 then
    Stage.center("START oder A: los!", 204, C.gold)
  end
end

return Title
