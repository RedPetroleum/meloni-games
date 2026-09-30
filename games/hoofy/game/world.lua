-- Die Welt-Szene: herumlaufen im aktuellen Gebiet. Pferde, Tag/Nacht, Menüs kommen mit den
-- Aufgaben aus PLAN.md dazu.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Leash = require("game.leash")
local U = require("lib.util")

local WorldScene = {}

local ctx, paused, anim_frame, t, wild, toast, a_hold, a_free

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
  toast, a_hold, a_free = nil, 0, false
  if arg and arg.zaehmen then
    -- ein einzelnes Pferd, 140 px rechts vom Spieler (Szenario zaehmen)
    wild.count = 0
    local h = wild:spawn_at(ctx.player.x + 140, ctx.player.y, {rasse = "haflinger", rng = wild.rng})
    h.data.bindung = arg.bindung or 35
    h.debug_log = true
  else
    wild:fill()
  end
  ctx.wild = wild
end

function WorldScene.update()
  if btnp(BTN_START) and not btn(BTN_SELECT) then
    paused = not paused
    ctx.sfx.select()
  end
  if paused then return end
  t = t + 1
  if btnp(BTN_A) then
    a_hold, a_free = 0, false
    local h = wild:try_tame()
    if h then
      local how = h.state == "follow" and "gezähmt, folgt dir." or "gezähmt, an der Leine."
      toast = {text = h.data.name .. " ist " .. how, t = 150}
      ctx.sfx.start()
      log("ZAEHMEN " .. frame() .. " gezähmt: " .. h.data.name)
    else
      h = wild:try_leash()
      if h then
        toast = {text = h.data.name .. (h.state == "follow" and " folgt dir." or " ist wieder an der Leine."), t = 120}
        ctx.sfx.select()
      else
        a_free = true
      end
    end
  elseif btn(BTN_A) and a_free then
    a_hold = a_hold + 1
    if a_hold == Leash.WHISTLE_FRAMES then
      ctx.sfx.start()
      local n = wild:whistle()
      toast = {text = n > 0 and "Pfiff! Sie kommen." or "Pfiff!", t = 90}
    end
  end
  if ctx.escaped then
    toast = {text = ctx.escaped.data.name .. " ist ausgerissen!", t = 150}
    ctx.escaped = nil
  end
  if toast then
    toast.t = toast.t - 1
    if toast.t <= 0 then toast = nil end
  end
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

-- Seil von der Hand des Spielers zum Kopf jedes geführten Pferds (nicht bei freiem Folgen).
local function draw_rope()
  local hx, hy = ctx.player:hand()
  for _, h in ipairs(ctx.lead) do
    if h.state == "led" then
      local ax, ay = h:head()
      local d = U.dist(hx, hy, ax, ay)
      local sag = max(0, 10 - d / 4)
      local mx, my = (hx + ax) / 2, (hy + ay) / 2 + sag
      line(hx, hy + 1, mx, my + 1, 4)
      line(mx, my + 1, ax, ay + 1, 4)
      line(hx, hy, mx, my, 15)
      line(mx, my, ax, ay, 15)
    end
  end
end

function WorldScene.draw()
  Stage.draw_world(ctx, draw_rope)
  draw_hud()
  if toast then
    local C = ctx.colors
    Stage.panel(40, 200, 279, 226)
    Stage.center(toast.text, 209, C.gold)
  end
  if paused then
    local C = ctx.colors
    Stage.panel(90, 90, 230, 140)
    Stage.center("Pause", 100, C.gold, 2)
    Stage.center("START: weiter", 124, C.text)
  end
end

return WorldScene
