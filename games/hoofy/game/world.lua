-- Die Welt-Szene: herumlaufen im aktuellen Gebiet. Pferde, Tag/Nacht, Menüs kommen mit den
-- Aufgaben aus PLAN.md dazu.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Leash = require("game.leash")
local Ride = require("game.ride")
local U = require("lib.util")

local WorldScene = {}

local ctx, paused, anim_frame, t, wild, toast, a_hold, a_free, mounted_hold

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
  if arg and arg.ritt then
    -- Ein zahmes Pferd (Bindung 80, Sattel) steht neben dem Spieler; eine Reihe Büsche 6 Kacheln rechts.
    wild.count = 0
    local h = wild:spawn_at(ctx.player.x + 18, ctx.player.y, {rasse = arg.rasse or "haflinger", rng = wild.rng})
    h.data.bindung, h.data.sattel = arg.bindung or 80, arg.sattel or "einfacher_sattel"
    if arg.staerke then h.data.gen.staerke, h.data.pot.staerke = arg.staerke, max(arg.staerke, h.data.pot.staerke) end
    h.wild, h.data.wild, h.tamed = false, nil, true
    table.remove(wild.list)
    ctx.herd[1], ctx.herd_horses[1] = h.data, h
    wild:attach(h)
    local cx, cy = ctx.player.x // 16 + 6, ctx.player.y // 16
    for dy = -2, 2 do
      ctx.map:set("coll", cx, cy + dy, arg.hindernis or "u")
      ctx.map:add_object(arg.hindernis == "o" and "rock" or "bush", cx, cy + dy)
    end
  elseif arg and arg.zaehmen then
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
  local p = ctx.player
  if p.riding then
    -- Reiten (E3): A antippen = springen, A lange halten = absteigen
    if mounted_hold then
      if not btn(BTN_A) then mounted_hold = false end
    elseif btn(BTN_A) then
      a_hold = a_hold + 1
      if a_hold == Ride.HOLD then
        Ride.dismount(ctx)
        a_free = false
        toast = {text = "Abgestiegen.", t = 60}
      end
    else
      if a_hold > 0 and a_hold < 20 and p.riding and Ride.jump(p) then ctx.sfx.select() end
      a_hold = 0
    end
  elseif btnp(BTN_A) then
    a_hold, a_free = 0, false
    local h = wild:try_tame()
    if h then
      local how = h.state == "follow" and "gezähmt, folgt dir." or "gezähmt, an der Leine."
      toast = {text = h.data.name .. " ist " .. how, t = 150}
      ctx.sfx.start()
      log("ZAEHMEN " .. frame() .. " gezähmt: " .. h.data.name)
    else
      local m, res = wild:try_mount()
      if m and res == "ok" then
        toast = {text = m.data.name .. ": aufgesessen!", t = 150}
        ctx.sfx.start()
        a_free = false
        a_hold = 0
        mounted_hold = true
      elseif m then
        toast = {text = m.data.name .. " verweigert das Reiten!", t = 120}
        ctx.sfx.select()
      else
        h = wild:try_leash()
        if h then
          toast = {text = h.data.name .. (h.state == "follow" and " folgt dir." or " ist wieder an der Leine."), t = 120}
          ctx.sfx.select()
        else
          a_free = true
        end
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
  -- Energie des Pferds beim Reiten (E9)
  local r = ctx.player.riding
  if r then
    local max_e = r.data.gen.ausdauer
    local e = r.data.energie
    local w = 70
    rectfill(4, SCREEN_H - 12, 4 + w + 1, SCREEN_H - 5, C.panel)
    rectfill(5, SCREEN_H - 11, 5 + flr(w * e / max_e), SCREEN_H - 6, e < 15 and C.red or C.gold)
    print("Energie", 80, SCREEN_H - 12, C.text)
  end
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
