-- Die Welt-Szene: herumlaufen im aktuellen Gebiet. Pferde, Tag/Nacht, Menüs kommen mit den
-- Aufgaben aus PLAN.md dazu.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Leash = require("game.leash")
local Ride = require("game.ride")
local Care = require("game.care")
local Menu = require("game.menu")
local K = require("game.katalog")
local H = require("game.horse_model")
local U = require("lib.util")

local WorldScene = {}

local ctx, paused, anim_frame, t, wild, toast, a_hold, a_free, mounted_hold, menu

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
  toast, a_hold, a_free, menu = nil, 0, false, nil
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


local FOODS = {"heu", "hafer", "karotte", "premiumfutter"}

local function say(text, frames)
  toast = {text = text, t = frames or 120}
end

-- Hauptmenü eines eigenen Pferds (E2).
local function open_menu(h)
  local led = h.state == "led" or h.state == "follow"
  menu = {
    horse = h, stage = "main",
    m = Menu.new({
      {label = "Streicheln", id = "stroke"},
      {label = "Füttern", id = "feed"},
      {label = "Striegeln", id = "brush", dim = (ctx.inv.buerste or 0) < 1},
      {label = led and "Leine lösen" or "Anleinen", id = "leash"},
      {label = "Aufsitzen", id = "mount"},
      {label = "Info", id = "info"},
    }, h.data.name),
  }
end

local function open_food(h)
  local items = {}
  for _, id in ipairs(FOODS) do
    local n = ctx.inv[id] or 0
    local name = K.futter.kaufen
    for _, f in ipairs(K.futter.kaufen) do if f.id == id then name = f.name end end
    items[#items + 1] = {label = name .. " x" .. n, id = id, dim = n < 1}
  end
  menu.stage, menu.m = "food", Menu.new(items, "Füttern")
end

local function do_action(id)
  local h = menu.horse
  local d = h.data
  if menu.stage == "food" then
    if id == "close" then return open_menu(h) end
    ctx.inv[id] = ctx.inv[id] - 1
    local name, bond = Care.feed(d, id)
    say(d.name .. " frisst " .. name .. ". Bindung +" .. bond .. ".")
    h.heart_t = 90
    menu = nil
    return
  end
  if id == "close" then menu = nil return end
  if id == "stroke" then
    local add = Care.stroke(d)
    h.heart_t = 120
    say(add > 0 and d.name .. " genießt das. Bindung +" .. add .. "." or d.name .. " hatte heute schon genug Streicheleinheiten.")
    menu = nil
  elseif id == "feed" then
    open_food(h)
  elseif id == "brush" then
    local add = Care.brush(d)
    say(d.name .. " glänzt. Sauberkeit +" .. add .. ".")
    menu = nil
  elseif id == "leash" then
    if h.state == "led" or h.state == "follow" then
      wild:release(h)
      say(d.name .. " ist frei.")
    else
      wild:attach(h)
      say(d.name .. (h.state == "follow" and " folgt dir." or " ist an der Leine."))
    end
    menu = nil
  elseif id == "mount" then
    if wild:mount(h) == "ok" then
      say(d.name .. ": aufgesessen!", 90)
      mounted_hold = true
    else
      say(d.name .. " verweigert das Reiten!")
    end
    menu = nil
  elseif id == "info" then
    say(string.format("%s, %s: Tempo %d Stärke %d Bindung %d. %s.", d.name, K.rasse(d.rasse).name,
      H.stat(d, "tempo"), H.stat(d, "staerke"), d.bindung, Care.describe(d)), 240)
    menu = nil
  end
end

function WorldScene.update()
  if btnp(BTN_START) and not btn(BTN_SELECT) then
    paused = not paused
    ctx.sfx.select()
  end
  if paused then return end
  if menu then
    local r = menu.m:update()
    if r then do_action(r) end
    if toast then toast.t = toast.t - 1; if toast.t <= 0 then toast = nil end end
    return
  end
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
      local own = wild:nearest_own()
      if own then
        open_menu(own)
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
  if menu then
    local h = menu.horse
    menu.m:draw(h.x - ctx.camera.x + 24, h.y - ctx.camera.y - 50)
  end
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
