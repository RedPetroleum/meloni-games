-- Titelbild: der Hof im Hintergrund (die Pferde grasen auf der Koppel), Levelwahl mit
-- links/rechts, START oder A: los.
local Stage = require("game.stage")
local Levels = require("game.levels")
local Save = require("game.save")
local U = require("lib.util")

local Title = {}

local ctx, choice, t

-- Stellt die Pferde auf zufällige Felder der Koppel.
local function horses_home()
  local map, cells = ctx.map, {}
  for cy = 0, map.h - 1 do
    for cx = 0, map.w - 1 do
      if map.tags[cy * map.w + cx + 1] == "paddock" then cells[#cells + 1] = {cx, cy} end
    end
  end
  for _, h in ipairs(ctx.horses) do
    local c = table.remove(cells, 1 + flr(rnd(#cells)))
    h.x, h.y, h.home = c[1] * 16 + 8, c[2] * 16 + 14, true
  end
end

function Title.enter()
  ctx = Stage.build(Levels[1])
  horses_home()
  ctx.player.frozen = true
  ctx.camera:snap(176, 104)
  choice = Save.unlocked()
  t = 0
  ctx.sfx.music(false)
end

function Title.update()
  t = t + 1
  ctx.world:update()
  local unlocked = Save.unlocked()
  if btnp(BTN_LEFT) and choice > 1 then choice = choice - 1; ctx.sfx.select() end
  if btnp(BTN_RIGHT) and choice < unlocked then choice = choice + 1; ctx.sfx.select() end
  if btnp(BTN_START) or btnp(BTN_A) then return "play", choice end
end

local function center(text, y, c, scale)
  print(text, (SCREEN_W - textw(text, scale)) // 2, y, c, scale)
end

function Title.draw()
  Stage.draw_world(ctx)
  local C = ctx.colors
  local title = "Ausgebüxt!"
  local x = (SCREEN_W - textw(title, 3)) // 2
  for dy = 1, 3 do print(title, x + 2, 14 + dy, C.panel, 3) end
  print(title, x, 14, C.gold, 3)
  rectfill(24, 150, 295, 231, C.panel)
  rect(25, 151, 294, 230, C.panel_light)
  local lv = Levels[choice]
  local unlocked = Save.unlocked()
  local label = "Level " .. choice .. ": " .. lv.name
  center((choice > 1 and "< " or "  ") .. label .. (choice < unlocked and " >" or "  "), 158, C.gold)
  local best = Save.best(choice)
  center(best and ("Beste Restzeit " .. U.clock(best)) or "Das Gatter stand offen ...", 170, C.dim)
  center("A: Pferd nehmen / loslassen", 186, C.text)
  center("B halten: rennen", 197, C.text)
  if (t // 30) % 2 == 0 then center("START oder A: los!", 215, C.gold) end
end

return Title
