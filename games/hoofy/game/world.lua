-- Die Welt-Szene: herumlaufen im aktuellen Gebiet. Pferde, Tag/Nacht, Menüs kommen mit den
-- Aufgaben aus PLAN.md dazu.
local Stage = require("game.stage")
local Wild = require("game.wild")

local WorldScene = {}

local ctx, paused, anim_frame, t, wild

-- arg (optional): {ort = Name aus area.places} oder {cx, cy}: dort starten statt am Hof.
function WorldScene.enter(arg)
  ctx = Stage.build(1)
  if arg then
    local p = arg.ort and ctx.area.places[arg.ort] or (arg.cx and {arg.cx, arg.cy})
    if not p then error("unbekannter Ort " .. tostring(arg.ort)) end
    ctx.player.x, ctx.player.y = p[1] * 16 + 8, p[2] * 16 + 14
    ctx.trail:reset(ctx.player.x, ctx.player.y)
    ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
  end
  paused, anim_frame, t = false, 1, 0
  wild = Wild.new(ctx, ctx.area.seed, arg and arg.wild_nah)
  wild:fill()
  ctx.wild = wild
end

function WorldScene.update()
  if btnp(BTN_START) and not btn(BTN_SELECT) then
    paused = not paused
    ctx.sfx.select()
  end
  if paused then return end
  t = t + 1
  ctx.world:update()
  ctx.fx:update()
  local p = ctx.player
  ctx.camera:follow(p.x, p.y - 10)
  local frame_no = (t // 40) % 2 + 1
  if frame_no ~= anim_frame then
    anim_frame = frame_no
    ctx.map:set_anim_frame(frame_no)
  end
end

local function draw_hud()
  local C = ctx.colors
  rectfill(0, 0, SCREEN_W - 1, Stage.HUD_H - 1, C.panel)
  print("Tag 1", 4, 3, C.text)
  local name = ctx.area.name
  print(name, (SCREEN_W - textw(name)) // 2, 3, C.dim)
end

function WorldScene.draw()
  Stage.draw_world(ctx)
  draw_hud()
  if paused then
    local C = ctx.colors
    Stage.panel(90, 90, 230, 140)
    Stage.center("Pause", 100, C.gold, 2)
    Stage.center("START: weiter", 124, C.text)
  end
end

return WorldScene
