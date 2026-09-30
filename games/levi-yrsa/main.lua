-- Levi & Yrsa: Nachtschicht. Der Mensch schläft, die Katzen räumen die Regale ab.
-- Levi: dick, schwer, springt niedrig, landet laut, schubst auch Vasen und Blumentöpfe.
-- Yrsa: klein, flink, springt hoch, landet leise, ist aber zu leicht für schwere Sachen.
-- Steuerkreuz: laufen   A: springen   B: Tatze   ↓: vom Brett runter   SELECT: Katze wechseln
-- START: los / Pause

local S = require("sprites")

local HUD_H = 16
local FLOOR = 224
local GRAV = 0.2
local NIGHT_LEN = 60 * 100 -- 0 bis 6 Uhr
local NOISE_WAKE = 100
local NOISE_STIR = 70

local C = {
  wall = rgb(46, 44, 78),
  wall2 = rgb(52, 50, 86),
  base = rgb(32, 30, 52),
  floor = rgb(84, 56, 44),
  floor2 = rgb(70, 46, 36),
  sky = rgb(20, 26, 60),
  moon = rgb(250, 240, 200),
  frame = rgb(150, 120, 100),
  wood = rgb(120, 78, 54),
  wood_d = rgb(86, 54, 38),
  wood_l = rgb(150, 102, 70),
  sofa = rgb(64, 102, 112),
  sofa_d = rgb(46, 78, 88),
  sofa_l = rgb(84, 128, 138),
  carpet = rgb(176, 160, 140),
  carpet_d = rgb(136, 120, 104),
  sisal = rgb(196, 172, 120),
  sisal_d = rgb(160, 136, 90),
  door = rgb(104, 72, 56),
  door_d = rgb(78, 52, 40),
  light = rgb(255, 224, 130),
  light_d = rgb(230, 180, 90),
  hud = rgb(24, 20, 36),
  text = rgb(236, 232, 244),
  dim = rgb(150, 144, 172),
  gold = rgb(255, 214, 90),
  green = rgb(120, 214, 110),
  red = rgb(236, 80, 80),
  orange = rgb(246, 160, 70),
  levi = rgb(200, 206, 216),
  yrsa = rgb(214, 180, 130),
  shadow = rgb(30, 28, 50),
}

-- Plattformen: Oberkante y, begehbar von x0 bis x1. stop: bis hierhin rutschen Sachen (Bücher im Weg)
local P = {
  floor = {x0 = 0, x1 = 320, y = FLOOR, floor = true},
  seat = {x0 = 28, x1 = 100, y = 202, soft = true},
  arm_l = {x0 = 14, x1 = 28, y = 192, soft = true},
  arm_r = {x0 = 100, x1 = 114, y = 192, soft = true},
  back = {x0 = 18, x1 = 110, y = 180},
  table = {x0 = 146, x1 = 190, y = 204},
  tree1 = {x0 = 214, x1 = 246, y = 190},
  tree2 = {x0 = 192, x1 = 224, y = 152},
  tree3 = {x0 = 214, x1 = 246, y = 114},
  tree4 = {x0 = 200, x1 = 238, y = 80},
  sill = {x0 = 14, x1 = 94, y = 100},
  shelf = {x0 = 116, x1 = 176, y = 100},
  bs1 = {x0 = 252, x1 = 316, y = 194, stop = 298},
  bs2 = {x0 = 252, x1 = 316, y = 166, stop = 298},
  bs3 = {x0 = 252, x1 = 316, y = 136, stop = 298},
  bs4 = {x0 = 252, x1 = 316, y = 106, stop = 298},
  bs5 = {x0 = 252, x1 = 316, y = 76, stop = 312},
}
local PLATS = {P.floor, P.seat, P.arm_l, P.arm_r, P.back, P.table, P.tree1, P.tree2, P.tree3, P.tree4,
  P.sill, P.shelf, P.bs1, P.bs2, P.bs3, P.bs4, P.bs5}

-- Wo Sachen stehen können. heavy: dort kommt Levi hin
local SPOTS = {
  {P.back, 34, true}, {P.back, 78, true}, {P.table, 156, true}, {P.table, 176, true},
  {P.bs1, 262, true}, {P.bs1, 282, true},
  {P.bs2, 262}, {P.bs2, 282}, {P.bs3, 262}, {P.bs3, 282}, {P.bs4, 262}, {P.bs4, 282}, {P.bs5, 280},
  {P.sill, 24}, {P.sill, 60}, {P.shelf, 128}, {P.shelf, 156}, {P.tree4, 212},
}

local KINDS = {
  cup = {sprite = "cup", heavy = false, noise = 20, pts = 50, word = "KLIRR!", shard = {rgb(246, 246, 242), rgb(208, 72, 72)}},
  glass = {sprite = "glass", heavy = false, noise = 24, pts = 60, word = "KLIRR!", shard = {rgb(224, 236, 244), rgb(140, 200, 240)}},
  vase = {sprite = "vase", heavy = true, noise = 38, pts = 150, word = "SCHEPPER!", shard = {rgb(78, 116, 200), rgb(154, 180, 238)}},
  plant = {sprite = "plant", heavy = true, noise = 32, pts = 120, word = "RUMMS!", shard = {rgb(200, 104, 58), rgb(58, 126, 54), rgb(96, 70, 50)}},
}
local LIGHT = {"cup", "cup", "glass"}
local HEAVY = {"vase", "plant"}

local state, t, pause_prev
local save
local cats, active, other
local items, parts, debris, popups, moths, zs
local night, score, noise, clock, left, combo_t, shake, msg, msg_t, end_t, reason, bonus
local sel_down, sel_other

-- ---------- Helfer ----------

local function center(text, y, c, scale)
  print(text, (SCREEN_W - textw(text, scale)) // 2, y, c, scale)
end

local function say(text, frames)
  msg, msg_t = text, frames or 150
end

local function popup(x, y, text, c)
  x = mid(2, x, SCREEN_W - 2 - textw(text))
  popups[#popups + 1] = {x = x, y = y, text = text, c = c or C.text, life = 50}
end

local function big(name, x, y, scale, flip)
  local r = S.rects[name]
  sspr(S.img, r[1], r[2], r[3], r[4], x, y, r[3] * scale, r[4] * scale, flip)
end

-- ---------- Töne ----------

local SFX = {}
function SFX.music() tune("E4:2 G4 A4:2 G4 E4:2 D4 C4:3 - D4:2 E4 G4:2 E4 D4:4 -", 84, "triangle", 0.07, true, 7) end
function SFX.jump(c) tone(c.name == "levi" and 330 or 660, 0.05, "sine", 0.12) end
function SFX.tap() tone(1200, 0.02, "triangle", 0.18) end
function SFX.heavy_tap() tone(180, 0.05, "square", 0.15) end
function SFX.soft() tone(90, 0.12, "sine", 0.35) end
function SFX.plumps() tone(60, 0.12, "square", 0.25) tone(80, 0.1, "noise", 0.2) end
function SFX.crash(kind)
  if KINDS[kind].heavy then
    tone(55, 0.35, "noise", 0.6) tone(70, 0.2, "square", 0.3)
  else
    tone(900, 0.12, "noise", 0.4)
  end
  tune("E7:0.2 B6:0.2 G7:0.2 C7:0.3", 700, "sine", 0.18, false, 6)
end
function SFX.meow(c)
  if c.name == "levi" then tune("A4:0.3 D5:0.4 A4:0.8", 420, "sine", 0.25, false, 6)
  else tune("E5:0.25 B5:0.35 G5:0.6", 520, "sine", 0.22, false, 6) end
end
function SFX.moth() tune("C6:0.25 E6:0.25 G6:0.25 C7:0.5", 900, "triangle", 0.25, false, 6) end
function SFX.snore() tone(48, 0.7, "noise", 0.05, 5) end
function SFX.stir() tune("C3:0.5 B2:1", 300, "saw", 0.15, false, 6) end
function SFX.wake() stoptune(7) tune("C5:0.5 C5:0.5 C5:0.5 - C5:0.5 C5:0.5 C5:0.5", 480, "square", 0.25, false, 6) end
function SFX.clear() stoptune(7) tune("C5 E5 G5 C6:2 G5 C6:3", 360, "triangle", 0.3, false, 6) end

-- ---------- Katzen ----------

local function new_cat(name, x, y)
  local c = {name = name, x = x, y = y, vx = 0, vy = 0, face = 1, on = P.floor, anim = 0, tap_t = 0,
    drop_t = 0, top_y = y, idle = 0}
  if name == "levi" then
    c.w, c.h, c.speed, c.accel, c.jump, c.heavy = 26, 18, 1.15, 0.12, 3.3, true
  else
    c.w, c.h, c.speed, c.accel, c.jump, c.heavy = 22, 15, 1.9, 0.35, 4.6, false
  end
  return c
end

local function levi() return cats[1] end
local function yrsa() return cats[2] end

-- Levis Rücken als Brett für Yrsa
local function levi_plat()
  local l = levi()
  return {x0 = l.x + 3, x1 = l.x + l.w - 3, y = l.y - 14, levi = true}
end

local function on_plat(c, p)
  return c.x + c.w - 5 > p.x0 and c.x + 5 < p.x1
end

-- Schwerkraft und Landen. true, wenn die Katze in diesem Frame gelandet ist
local function physics(c)
  if c.on then
    if c.on.levi then
      local lp = levi_plat()
      if on_plat(c, lp) then c.on, c.y = lp, lp.y return false end
      c.on = nil
    elseif not on_plat(c, c.on) then
      c.on = nil
    else
      return false
    end
    c.top_y = c.y
  end
  local prev = c.y
  c.vy = min(c.vy + GRAV, 5)
  c.y = c.y + c.vy
  if c.vy < 0 then c.top_y = min(c.top_y, c.y) return false end
  if c.drop_t > 0 then c.drop_t = c.drop_t - 1 end
  local cands = PLATS
  if c == yrsa() then
    local lp = levi_plat()
    if prev <= lp.y and c.y >= lp.y and on_plat(c, lp) then
      c.y, c.vy, c.on = lp.y, 0, lp
      return true
    end
  end
  for _, p in ipairs(cands) do
    if (p.floor or c.drop_t == 0) and prev <= p.y and c.y >= p.y and on_plat(c, p) then
      c.y, c.vy, c.on = p.y, 0, p
      return true
    end
  end
  return false
end

local function tap(c)
  c.tap_t = 12
  local best, bd
  for _, it in ipairs(items) do
    if it.state == "rest" and it.plat == c.on then
      local d
      if c.face > 0 then d = it.x - (c.x + c.w - 8) else d = (c.x + 8) - (it.x + it.w) end
      if d >= -10 and d <= 10 and (not bd or abs(d) < bd) then best, bd = it, abs(d) end
    end
  end
  if not best then tone(700, 0.02, "triangle", 0.08) return end
  local k = KINDS[best.kind]
  best.wob = 12
  if k.heavy and not c.heavy then
    SFX.heavy_tap()
    popup(best.x - 8, best.y - 26, "Zu schwer!", C.orange)
    if not best.told then
      best.told = true
      say("Das schafft nur Levi (SELECT)", 150)
    end
    return
  end
  if k.heavy then SFX.heavy_tap() else SFX.tap() end
  best.vx = c.face * (k.heavy and 1.1 or 1.8)
end

local function land(c)
  local fall = c.y - c.top_y
  c.top_y = c.y
  if c.name == "levi" and fall > 34 and not c.on.soft then
    noise = noise + 6
    shake = 4
    SFX.plumps()
    popup(c.x + 4, c.y - 24, "Plumps!", C.dim)
  elseif c.on.soft then
    tone(120, 0.05, "sine", 0.1)
  end
end

local function control(c)
  local dir = 0
  if btn(BTN_LEFT) then dir = dir - 1 end
  if btn(BTN_RIGHT) then dir = dir + 1 end
  if dir ~= 0 then c.face = dir end
  local target = dir * c.speed
  if c.vx < target then c.vx = min(target, c.vx + c.accel) elseif c.vx > target then c.vx = max(target, c.vx - c.accel) end
  c.x = mid(2, c.x + c.vx, SCREEN_W - 2 - c.w)

  if c.on then
    if btnp(BTN_A) then
      c.vy = -c.jump * (c.on.levi and 1.3 or 1)
      c.on = nil
      c.top_y = c.y
      SFX.jump(c)
    elseif btnp(BTN_DOWN) and not c.on.floor then
      c.drop_t, c.on, c.vy = 10, nil, 0.5
      c.top_y = c.y
    end
  elseif c.vy < 0 and not btn(BTN_A) then
    c.vy = c.vy + GRAV -- kurzer Druck: kleiner Sprung
  end

  if btnp(BTN_B) and c.tap_t == 0 then tap(c) end
  if c.tap_t > 0 then c.tap_t = c.tap_t - 1 end
  if dir ~= 0 and c.on then c.anim = c.anim + 1 else c.anim = 0 end
end

local function update_cat(c, is_active)
  if is_active then control(c) else c.vx, c.tap_t = 0, 0 end
  if physics(c) then land(c) end
  if is_active then c.idle = 0 else c.idle = c.idle + 1 end
end

-- ---------- Sachen ----------

local function place_items()
  items = {}
  local n_light = min(3 + night, 11)
  local n_heavy = min(1 + night // 2, 5)
  local heavy_spots, light_spots = {}, {}
  for _, s in ipairs(SPOTS) do
    if s[3] then heavy_spots[#heavy_spots + 1] = s else light_spots[#light_spots + 1] = s end
  end
  local function take(list)
    local i = 1 + flr(rnd(#list))
    return table.remove(list, i)
  end
  for _ = 1, n_heavy do
    local s = take(heavy_spots)
    local kind = rnd(HEAVY)
    local w, h = S.size(KINDS[kind].sprite)
    items[#items + 1] = {kind = kind, plat = s[1], x = s[2], y = s[1].y, w = w, h = h, vx = 0, vy = 0,
      state = "rest", wob = 0}
  end
  -- übrige Levi-Plätze dürfen auch leichte Sachen bekommen
  for _, s in ipairs(heavy_spots) do light_spots[#light_spots + 1] = s end
  for _ = 1, n_light do
    if #light_spots == 0 then break end
    local s = take(light_spots)
    local kind = rnd(LIGHT)
    local w, h = S.size(KINDS[kind].sprite)
    items[#items + 1] = {kind = kind, plat = s[1], x = s[2], y = s[1].y, w = w, h = h, vx = 0, vy = 0,
      state = "rest", wob = 0}
  end
  left = #items
end

local function shards(it)
  local k = KINDS[it.kind]
  for _ = 1, 10 + (k.heavy and 8 or 0) do
    parts[#parts + 1] = {x = it.x + it.w / 2 + rnd(6) - 3, y = FLOOR - 2, vx = rnd(3) - 1.5, vy = -1 - rnd(2.5),
      c = rnd(k.shard), s = rnd(1) < 0.3 and 2 or 1}
  end
end

local function knocked(it, soft)
  local k = KINDS[it.kind]
  it.state = "gone"
  left = left - 1
  local pts = k.pts
  if combo_t > 0 then
    pts = pts * 2
    popup(it.x - 4, it.y - 34, "Doppelt!", C.gold)
  end
  combo_t = 50
  score = score + pts
  if soft then
    noise = noise + 3
    SFX.soft()
    popup(it.x - 10, it.y - 20, "Plopp. +" .. pts, C.green)
  else
    noise = noise + k.noise
    shake = k.heavy and 8 or 4
    SFX.crash(it.kind)
    shards(it)
    popup(it.x - 12, FLOOR - 26, k.word, C.text)
    popup(it.x - 2, FLOOR - 16, "+" .. pts, C.gold)
  end
  if left == 0 then
    bonus = flr((NIGHT_LEN - clock) / 60) * 2 + flr(max(0, NOISE_WAKE - noise))
    score = score + bonus
    state, end_t, popups = "clear", 0, {}
    SFX.clear()
  end
end

local function update_items()
  for _, it in ipairs(items) do
    if it.wob > 0 then it.wob = it.wob - 1 end
    if it.state == "rest" then
      if it.vx ~= 0 then
        it.x = it.x + it.vx
        it.vx = it.vx * 0.86
        if abs(it.vx) < 0.05 then it.vx = 0 end
        local stop = (it.plat.stop or SCREEN_W - 2) - it.w
        if it.x > stop then it.x, it.vx = stop, 0 end
        if it.x < 2 then it.x, it.vx = 2, 0 end
      end
      local cx = it.x + it.w / 2
      if cx < it.plat.x0 or cx > it.plat.x1 then
        it.state, it.vy = "fall", -0.5
      end
    elseif it.state == "fall" then
      local prev = it.y
      it.vy = min(it.vy + GRAV, 6)
      it.y = it.y + it.vy
      it.x = it.x + it.vx * 0.6
      local cx = it.x + it.w / 2
      if prev <= P.seat.y and it.y >= P.seat.y and cx > P.seat.x0 and cx < P.seat.x1 and it.plat ~= P.seat then
        it.y = P.seat.y
        knocked(it, true)
      elseif it.y >= FLOOR then
        it.y = FLOOR
        knocked(it, false)
      end
    end
  end
end

-- ---------- Motten ----------

local function update_moths()
  if rnd(1) < 1 / 700 and #moths < 2 then
    moths[#moths + 1] = {x = 50, y = 60, tx = 60 + rnd(200), ty = 40 + rnd(150), life = 600 + flr(rnd(300))}
  end
  for i = #moths, 1, -1 do
    local m = moths[i]
    m.life = m.life - 1
    if m.life < 0 then m.tx, m.ty = 50, 40 end
    if (abs(m.tx - m.x) < 6 and abs(m.ty - m.y) < 6) or rnd(1) < 0.01 then
      m.tx, m.ty = 20 + rnd(280), 30 + rnd(180)
    end
    m.x = m.x + mid(-0.9, (m.tx - m.x) * 0.03, 0.9) + rnd(1) - 0.5
    m.y = m.y + mid(-0.9, (m.ty - m.y) * 0.03, 0.9) + math.sin(t * 0.2 + i) * 0.6
    local c = active
    if m.x + 6 > c.x and m.x < c.x + c.w and m.y + 4 > c.y - c.h and m.y < c.y then
      score = score + 100
      SFX.moth()
      popup(m.x - 8, m.y - 10, "Motte! +100", C.gold)
      table.remove(moths, i)
    elseif m.life < -200 then
      table.remove(moths, i)
    end
  end
end

-- ---------- Ablauf ----------

local function start_night()
  cats = {new_cat("levi", 50, FLOOR), new_cat("yrsa", 124, FLOOR)}
  cats[2].face = -1
  active, other = cats[1], cats[2]
  parts, debris, popups, moths, zs = {}, {}, {}, {}, {}
  noise, clock, combo_t, shake, msg_t = 0, 0, 0, 0, 0
  place_items()
  state, t = "play", 0
  say("Nacht " .. night .. ": " .. left .. " Sachen müssen runter!", 180)
  SFX.music()
end

local function new_game()
  night, score = 1, 0
  start_night()
end

local function game_over(why)
  state, end_t, reason, popups = "over", 0, why, {}
  if score > (save.best or 0) then save.best = score end
  if night > (save.night or 0) then save.night = night end
  savedata(save)
end

local function switch_cat()
  active, other = other, active
  active.idle = 0
  SFX.meow(active)
  popup(active.x + 2, active.y - active.h - 12, active.name == "levi" and "Levi" or "Yrsa",
    active.name == "levi" and C.levi or C.yrsa)
end

local function update_play()
  t = t + 1
  clock = clock + 1

  -- SELECT wechselt beim Loslassen, wenn dabei nichts anderes gedrückt wurde (SELECT+START ist das Menü)
  if btn(BTN_SELECT) then
    if not sel_down then sel_down, sel_other = true, false end
    if btn(BTN_START) or btn(BTN_A) or btn(BTN_B) then sel_other = true end
  elseif sel_down then
    sel_down = false
    if not sel_other then switch_cat() end
  end

  if btnp(BTN_START) and not btn(BTN_SELECT) then state = "pause" return end

  -- Yrsa reitet auf Levi mit, wenn sie auf ihm liegt und er läuft
  local l, y = levi(), yrsa()
  local lx = l.x
  update_cat(active, true)
  if active == l and y.on and y.on.levi then
    y.x = mid(2, y.x + (l.x - lx), SCREEN_W - 2 - y.w)
    y.y, y.on, y.top_y = l.y - 14, levi_plat(), l.y - 14
    y.idle = y.idle + 1
  else
    update_cat(other, false)
  end

  update_items()
  if state ~= "play" then return end
  update_moths()

  noise = max(0, noise - max(0.025, 0.055 - night * 0.004))
  if combo_t > 0 then combo_t = combo_t - 1 end
  if shake > 0 then shake = shake - 1 end
  if msg_t > 0 then msg_t = msg_t - 1 end

  if noise < NOISE_STIR then
    if t % 150 == 0 then SFX.snore() end
    if t % 70 == 0 then zs[#zs + 1] = {x = 128, y = 116, life = 40} end
  elseif t % 90 == 0 then
    SFX.stir()
  end
  for i = #zs, 1, -1 do
    local z = zs[i]
    z.y, z.x, z.life = z.y - 0.35, z.x + math.sin(z.life * 0.1) * 0.3, z.life - 1
    if z.life <= 0 then table.remove(zs, i) end
  end

  for i = #parts, 1, -1 do
    local p = parts[i]
    p.vy = p.vy + GRAV
    p.x, p.y = p.x + p.vx, p.y + p.vy
    if p.y >= FLOOR - 1 then
      p.y = FLOOR - 1 - flr(rnd(2))
      if #debris > 160 then table.remove(debris, 1) end
      debris[#debris + 1] = p
      table.remove(parts, i)
    end
  end
  for i = #popups, 1, -1 do
    local p = popups[i]
    p.y, p.life = p.y - 0.4, p.life - 1
    if p.life <= 0 then table.remove(popups, i) end
  end

  if noise >= NOISE_WAKE then
    SFX.wake()
    game_over("wake")
  elseif clock >= NIGHT_LEN then
    SFX.wake()
    game_over("morning")
  end
end

function _init()
  save = loaddata() or {}
  state, t = "title", 0
  night, score = 1, 0
  cats = {new_cat("levi", 60, FLOOR), new_cat("yrsa", 200, FLOOR)}
  items, parts, debris, popups, moths, zs = {}, {}, {}, {}, {}, {}
  noise, clock, shake, msg_t = 0, 0, 0, 0
  active, other = cats[1], cats[2]
end

function _update()
  if state == "title" then
    t = t + 1
    if btnp(BTN_START) or btnp(BTN_A) then new_game() end
  elseif state == "pause" then
    if btnp(BTN_START) then state = "play" end
  elseif state == "play" then
    update_play()
  elseif state == "clear" then
    end_t = end_t + 1
    for i = #popups, 1, -1 do
      local p = popups[i]
      p.y, p.life = p.y - 0.4, p.life - 1
      if p.life <= 0 then table.remove(popups, i) end
    end
    if end_t > 60 and (btnp(BTN_A) or btnp(BTN_START)) then
      night = night + 1
      if night > (save.night or 0) then save.night = night savedata(save) end
      start_night()
    end
  elseif state == "over" then
    end_t = end_t + 1
    if end_t > 90 and (btnp(BTN_A) or btnp(BTN_START)) then
      state, t = "title", 0
    end
  end
end

-- ---------- Zeichnen ----------

local BOOKS = {}
do
  local cols = {rgb(170, 60, 60), rgb(60, 110, 160), rgb(210, 170, 70), rgb(80, 140, 90), rgb(140, 90, 150),
    rgb(200, 120, 60), rgb(90, 90, 110)}
  local seed = 7
  local function r(n) seed = (seed * 1103 + 12345) % 30011 return seed % n end
  for _, y in ipairs({194, 166, 136, 106}) do
    local x = 299
    while x < 314 do
      local w = 2 + r(3)
      local h = 16 + r(9)
      BOOKS[#BOOKS + 1] = {x, y - h, min(x + w - 1, 313), y - 1, cols[1 + r(#cols)]}
      x = x + w
    end
  end
end
local STARS = {{28, 40}, {44, 34}, {70, 48}, {36, 66}, {80, 36}, {58, 74}, {82, 80}}

local function board(p, c, cl, h)
  rectfill(p.x0, p.y, p.x1, p.y + (h or 3), c)
  line(p.x0, p.y, p.x1, p.y, cl)
end

local function draw_room(lit)
  rectfill(0, HUD_H, 319, FLOOR - 1, C.wall)
  for x = 8, 319, 24 do rectfill(x, HUD_H, x + 3, FLOOR - 7, C.wall2) end
  rectfill(0, FLOOR - 6, 319, FLOOR - 1, C.base)
  rectfill(0, FLOOR, 319, 239, C.floor)
  for x = 0, 319, 40 do line(x, FLOOR, x, 239, C.floor2) end
  line(0, 232, 319, 232, C.floor2)

  -- Fenster mit Mond
  rectfill(18, 26, 90, 98, C.frame)
  rectfill(22, 30, 86, 96, C.sky)
  circfill(68, 52, 9, C.moon)
  circfill(72, 49, 8, C.sky)
  for _, s in ipairs(STARS) do pset(s[1], s[2], C.moon) end
  line(54, 30, 54, 96, C.frame)
  line(22, 62, 86, 62, C.frame)
  board(P.sill, C.wood, C.wood_l, 5)

  -- Tür zum Schlafzimmer
  if lit then
    rectfill(116, 120, 146, FLOOR - 1, C.light)
    rectfill(116, 120, 146, 124, C.light_d)
    rectfill(146, 120, 150, FLOOR - 1, C.door_d)
  else
    rectfill(116, 120, 146, FLOOR - 1, C.door)
    rect(116, 120, 146, FLOOR - 1, C.door_d)
    rect(120, 126, 142, 164, C.door_d)
    rect(120, 172, 142, 214, C.door_d)
    rectfill(140, 176, 142, 178, C.gold)
    if noise >= NOISE_STIR and flr(t / 8) % 2 == 0 then line(116, FLOOR - 1, 146, FLOOR - 1, C.light) end
  end

  -- Wandbrett über der Tür
  board(P.shelf, C.wood, C.wood_l, 4)
  rectfill(122, 104, 124, 110, C.wood_d)
  rectfill(168, 104, 170, 110, C.wood_d)

  -- Sofa
  rectfill(18, 180, 110, 204, C.sofa_d)
  rectfill(20, 182, 108, 202, C.sofa)
  line(64, 184, 64, 200, C.sofa_d)
  rectfill(28, 202, 100, 214, C.sofa_l)
  line(64, 203, 64, 213, C.sofa)
  rectfill(14, 192, 28, 216, C.sofa_d)
  rectfill(100, 192, 114, 216, C.sofa_d)
  line(14, 192, 28, 192, C.sofa_l)
  line(100, 192, 114, 192, C.sofa_l)
  rectfill(16, 216, 112, 218, C.sofa_d)
  rectfill(18, 218, 22, FLOOR - 1, C.wood_d)
  rectfill(106, 218, 110, FLOOR - 1, C.wood_d)

  -- Couchtisch
  board(P.table, C.wood, C.wood_l, 4)
  rectfill(150, 208, 153, FLOOR - 1, C.wood_d)
  rectfill(183, 208, 186, FLOOR - 1, C.wood_d)

  -- Kratzbaum
  rectfill(224, 80, 230, FLOOR - 1, C.sisal)
  for y = 86, FLOOR - 4, 6 do line(224, y, 230, y + 2, C.sisal_d) end
  rectfill(206, FLOOR - 5, 248, FLOOR - 1, C.carpet_d)
  for _, p in ipairs({P.tree1, P.tree2, P.tree3, P.tree4}) do
    rectfill(p.x0, p.y, p.x1, p.y + 5, C.carpet)
    line(p.x0, p.y + 5, p.x1, p.y + 5, C.carpet_d)
  end
  -- Spielmaus am Faden
  line(206, 158, 206, 170, C.dim)
  circfill(206, 172, 2, C.dim)

  -- Bücherregal
  rectfill(250, 72, 318, FLOOR - 1, C.wood_d)
  rectfill(254, 76, 314, 196, C.shadow)
  for _, b in ipairs(BOOKS) do rectfill(b[1], b[2], b[3], b[4], b[5]) end
  for _, p in ipairs({P.bs1, P.bs2, P.bs3, P.bs4, P.bs5}) do board(p, C.wood, C.wood_l, 3) end
  rectfill(254, 200, 314, FLOOR - 3, C.wood)
  line(284, 200, 284, FLOOR - 3, C.wood_d)
  rectfill(280, 210, 282, 212, C.gold)
  rectfill(286, 210, 288, 212, C.gold)
end

local function draw_cat(c, is_active)
  local name
  if not is_active then
    name = c.name .. "_loaf"
  elseif not c.on then
    name = c.name .. "_jump"
  elseif c.anim > 0 and flr(c.anim / (c.name == "levi" and 9 or 6)) % 2 == 1 then
    name = c.name .. "_walk2"
  else
    name = c.name .. "_walk1"
  end
  local w, h = S.size(name)
  local x, y = flr(c.x), flr(c.y) - h
  S.draw(name, x, y, c.face < 0)
  if c.tap_t > 4 then
    -- Tatze
    local px = c.face > 0 and x + w or x - 4
    local py = y + (c.name == "levi" and 9 or 7)
    rectfill(px, py, px + 3, py + 2, c.name == "levi" and rgb(246, 246, 242) or rgb(201, 184, 160))
  end
  if is_active then
    local ax = x + w // 2
    local ay = y - 8 + flr(math.sin(t * 0.15) * 1.5)
    local col = c.name == "levi" and C.levi or C.yrsa
    line(ax - 2, ay, ax + 2, ay, col)
    line(ax - 1, ay + 1, ax + 1, ay + 1, col)
    pset(ax, ay + 2, col)
  elseif flr(c.idle / 40) % 3 == 0 and c.idle > 30 then
    print("z", x + (c.face > 0 and w - 2 or -4), y - 6 - (c.idle % 40) // 8, C.dim)
  end
end

local function draw_items()
  for _, it in ipairs(items) do
    if it.state ~= "gone" then
      local k = KINDS[it.kind]
      local ox = it.wob > 0 and (it.wob % 4 < 2 and 1 or -1) or 0
      S.draw(k.sprite, flr(it.x) + ox, flr(it.y) - it.h)
    end
  end
end

local function draw_hud()
  rectfill(0, 0, 319, HUD_H - 1, C.hud)
  print("Nacht " .. night, 4, 4, C.text)
  local mins = flr(clock * 360 / NIGHT_LEN)
  local tt = string.format("%d:%02d", mins // 60, mins % 60)
  print(tt, 74, 4, clock > NIGHT_LEN - 600 and C.orange or C.dim)
  S.draw("cup", 116, 4)
  print(tostring(left), 129, 4, C.text)
  -- Lärm: wie tief der Mensch schläft
  print("Zzz", 154, 4, C.dim)
  rectfill(180, 4, 244, 11, C.shadow)
  local f = min(noise, NOISE_WAKE) / NOISE_WAKE
  local col = noise >= NOISE_STIR and C.red or (noise > 40 and C.orange or C.green)
  if f > 0 then rectfill(181, 5, 181 + flr(62 * f), 10, col) end
  line(181 + flr(62 * NOISE_STIR / NOISE_WAKE), 4, 181 + flr(62 * NOISE_STIR / NOISE_WAKE), 11, C.dim)
  local s = tostring(score)
  print(s, 316 - textw(s), 4, C.gold)
end

local function draw_world(lit)
  local sx = shake > 0 and (rnd(1) < 0.5 and -1 or 1) or 0
  camera(sx, 0)
  draw_room(lit)
  for _, d in ipairs(debris) do
    if d.s == 2 then rectfill(d.x, d.y - 1, d.x + 1, d.y, d.c) else pset(d.x, d.y, d.c) end
  end
  for _, z in ipairs(zs) do print("z", z.x, z.y, C.dim) end
  draw_items()
  local y = yrsa()
  local riding = y.on and y.on.levi
  if riding then
    draw_cat(levi(), levi() == active)
    draw_cat(y, y == active)
  else
    draw_cat(other, false)
    draw_cat(active, true)
  end
  for _, m in ipairs(moths) do
    S.draw(flr(t / 5) % 2 == 0 and "moth1" or "moth2", flr(m.x), flr(m.y))
  end
  for _, p in ipairs(parts) do pset(p.x, p.y, p.c) end
  for _, p in ipairs(popups) do
    print(p.text, flr(p.x) + 1, flr(p.y) + 1, C.shadow)
    print(p.text, flr(p.x), flr(p.y), p.c)
  end
  camera()
end

local function panel(y0, y1)
  rectfill(16, y0, 303, y1, C.hud)
  rect(16, y0, 303, y1, C.dim)
end

local function draw_title()
  cls(C.wall)
  local save_noise = noise
  noise = 0
  draw_room(false)
  noise = save_noise
  rectfill(0, 0, 319, HUD_H - 1, C.hud)
  rectfill(16, 20, 303, 150, C.hud)
  rect(16, 20, 303, 150, C.dim)
  center("Levi & Yrsa", 30, C.gold, 3)
  center("Nachtschicht", 58, C.text)
  big("levi_loaf", 58, 78, 3)
  big(flr(t / 12) % 2 == 0 and "yrsa_walk1" or "yrsa_walk2", 184, 88, 3, true)
  print("Levi", 86, 136, C.levi)
  print("Yrsa", 206, 136, C.yrsa)
  panel(158, 228)
  center("Alles muss runter, aber leise!", 164, C.text)
  center("A Sprung  B Tatze  unten: runter", 178, C.dim)
  center("SELECT: Katze wechseln", 190, C.dim)
  if (save.best or 0) > 0 then
    center("Rekord " .. save.best .. "  (Nacht " .. (save.night or 1) .. ")", 204, C.gold)
  end
  if flr(t / 30) % 2 == 0 then center("START", 216, C.text) end
end

function _draw()
  if state == "title" then
    draw_title()
    return
  end
  cls(C.wall)
  local lit = state == "over"
  draw_world(lit)
  if lit then
    local r = S.rects.human
    sspr(S.img, r[1], r[2], r[3], r[4], 119, FLOOR - r[4] * 2 + 2, r[3] * 2, r[4] * 2)
  end
  draw_hud()
  if msg_t > 0 and state == "play" then
    local w = textw(msg)
    rectfill((SCREEN_W - w) // 2 - 4, 22, (SCREEN_W + w) // 2 + 3, 33, C.hud)
    center(msg, 24, C.text)
  end
  if night == 1 and state == "play" then
    print("A Sprung  B Tatze  SELECT Wechsel", 28, 229, rgb(200, 160, 130))
  end
  if state == "pause" then
    panel(96, 136)
    center("Pause", 104, C.text, 2)
    center("START: weiter", 124, C.dim)
  elseif state == "clear" then
    panel(70, 150)
    center("Nacht geschafft!", 80, C.gold, 2)
    center("Alles unten, der Mensch schläft.", 102, C.text)
    center("Bonus +" .. bonus, 116, C.green)
    center("Punkte " .. score, 128, C.text)
    if end_t > 60 then center("A: nächste Nacht", 140, C.dim) end
  elseif state == "over" then
    panel(40, 130)
    if reason == "wake" then
      center("LEVI! YRSA!", 50, C.red, 2)
      center("Der Mensch ist aufgewacht.", 72, C.text)
    else
      center("Der Wecker!", 50, C.orange, 2)
      center("6 Uhr, und noch " .. left .. (left == 1 and " Sache oben." or " Sachen oben."), 72, C.text)
    end
    center("Nacht " .. night .. "   Punkte " .. score, 90, C.gold)
    center("Rekord " .. (save.best or 0), 104, C.dim)
    if end_t > 90 then center("A: nochmal", 118, C.dim) end
  end
end
