-- Levi & Yrsa: Nachtschicht. Der Mensch schläft, die Katzen räumen die Regale ab.
-- Levi: dick, schwer, springt niedrig, landet laut. Schubst auch Vasen und Töpfe, drückt die
--       klemmende Küchentür auf und ist Yrsas Taxi: von seinem Rücken springt sie extra hoch.
-- Yrsa: klein, flink, springt hoch, landet leise. Zu leicht für schwere Sachen, passt aber als
--       Einzige durch die Katzenklappe ins Arbeitszimmer.
-- Räume: Arbeitszimmer | Wohnzimmer | Küche. Nacht 1 nur Wohnzimmer, Nacht 2 mit Küche, dann alle.
-- Steuerkreuz: laufen   A: springen   B: Tatze   unten: vom Brett runter   SELECT: Katze wechseln
-- START: los / Pause

local S = require("sprites")

local HUD_H = 16
local FLOOR = 224
local GRAV = 0.2
local NOISE_WAKE = 100
local NOISE_STIR = 70
local TAXI = 1.2 -- Sprungkraft von Levis Rücken

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
  dark = rgb(20, 18, 30),
  light = rgb(255, 224, 130),
  light_d = rgb(230, 180, 90),
  k_wall = rgb(52, 70, 74),
  k_tile = rgb(70, 92, 96),
  k_tile2 = rgb(62, 82, 86),
  k_floor = rgb(150, 150, 160),
  k_floor2 = rgb(110, 110, 124),
  k_front = rgb(190, 180, 160),
  k_front_d = rgb(150, 140, 124),
  k_top = rgb(90, 90, 100),
  fridge = rgb(206, 212, 220),
  fridge_d = rgb(150, 156, 168),
  s_wall = rgb(66, 50, 64),
  s_wall2 = rgb(72, 56, 70),
  s_floor = rgb(110, 58, 58),
  s_floor2 = rgb(92, 46, 48),
  rug = rgb(160, 120, 70),
  bean = rgb(206, 118, 60),
  bean_d = rgb(170, 90, 44),
  screen = rgb(40, 60, 90),
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

local KINDS = {
  cup = {sprite = "cup", noise = 20, pts = 50, word = "KLIRR!", shard = {rgb(246, 246, 242), rgb(208, 72, 72)}},
  glass = {sprite = "glass", noise = 24, pts = 60, word = "KLIRR!", shard = {rgb(224, 236, 244), rgb(140, 200, 240)}},
  plate = {sprite = "plate", noise = 24, pts = 60, word = "KLIRR!", shard = {rgb(246, 246, 242), rgb(208, 72, 72)}},
  egg = {sprite = "egg", noise = 8, pts = 40, word = "PLATSCH!", shard = {rgb(250, 250, 240), rgb(250, 200, 60)}},
  pens = {sprite = "pens", noise = 12, pts = 40, word = "KLAPPER!", shard = {rgb(208, 72, 72), rgb(140, 200, 240), rgb(255, 224, 122)}},
  frame = {sprite = "frame", noise = 18, pts = 50, word = "KLIRR!", shard = {rgb(200, 104, 58), rgb(140, 200, 240)}},
  vase = {sprite = "vase", heavy = true, noise = 36, pts = 150, word = "SCHEPPER!", shard = {rgb(78, 116, 200), rgb(154, 180, 238)}},
  plant = {sprite = "plant", heavy = true, noise = 30, pts = 120, word = "RUMMS!", shard = {rgb(200, 104, 58), rgb(58, 126, 54), rgb(96, 70, 50)}},
  pot = {sprite = "pot", heavy = true, noise = 34, pts = 150, word = "DONG!", shard = {rgb(154, 160, 168), rgb(212, 216, 222)}},
}

-- ---------- Räume ----------

local function plat(x0, x1, y, o)
  o = o or {}
  o.x0, o.x1, o.y = x0, x1, y
  return o
end

-- Wohnzimmer: Schlafzimmertür, Sofa, Kratzbaum, Bücherregal
local LP = {
  floor = plat(0, 320, FLOOR, {floor = true}),
  seat = plat(28, 100, 202, {soft = true}),
  arm_l = plat(14, 28, 192, {soft = true}),
  arm_r = plat(100, 114, 192, {soft = true}),
  back = plat(18, 110, 180),
  table = plat(146, 190, 204),
  tree1 = plat(212, 244, 190),
  tree2 = plat(192, 222, 152),
  tree3 = plat(212, 244, 114),
  tree4 = plat(198, 236, 80),
  sill = plat(14, 94, 100),
  shelf = plat(116, 176, 100),
  bs1 = plat(254, 306, 194, {rstop = 288}),
  bs2 = plat(254, 306, 166, {rstop = 288}),
  bs3 = plat(254, 306, 136, {rstop = 288}),
  bs4 = plat(254, 306, 106, {rstop = 288}),
  bs5 = plat(254, 306, 76, {rstop = 306}),
}

-- Küche: Fliesen, hohe Schränke. Hängeschrank, Kühlschrank und Gewürzregal nur mit Levi-Taxi
-- Levi muss für jeden hohen Platz woanders stehen: auf Stuhl oder Tisch fürs Gewürzregal, auf der
-- Arbeitsplatte für Hängeschrank und Kühlschrank. Von oben kommt Yrsa nicht allein zum anderen Platz.
local KP = {
  floor = plat(0, 320, FLOOR, {floor = true}),
  chair = plat(30, 56, 200),
  table = plat(64, 124, 196),
  counter = plat(140, 244, 176),
  spice = plat(18, 56, 120),
  cab = plat(164, 236, 100),
  fridge = plat(256, 294, 100),
}

-- Arbeitszimmer: Teppich, Sitzsack, Schreibtisch. Nur Yrsa kommt hier rein
local SP = {
  floor = plat(0, 320, FLOOR, {floor = true}),
  sh1 = plat(8, 70, 190, {lstop = 22}),
  sh2 = plat(8, 70, 154, {lstop = 22}),
  sh3 = plat(8, 70, 118, {lstop = 22}),
  sh4 = plat(8, 70, 82, {lstop = 8}),
  bean = plat(78, 126, 208, {soft = true}),
  wall = plat(86, 142, 124),
  chair = plat(150, 176, 196),
  desk = plat(184, 290, 178),
  hang = plat(200, 272, 132),
}

local function list(t, order)
  local l = {}
  for _, k in ipairs(order) do l[#l + 1] = t[k] end
  return l
end

local ROOMS = {
  living = {
    name = "Wohnzimmer", mult = 1,
    plats = list(LP, {"floor", "seat", "arm_l", "arm_r", "back", "table", "tree1", "tree2", "tree3", "tree4",
      "sill", "shelf", "bs1", "bs2", "bs3", "bs4", "bs5"}),
    -- {Brett, x, schwer erlaubt, nur mit Taxi}
    spots = {
      {LP.back, 34, true}, {LP.back, 78, true}, {LP.table, 154, true}, {LP.table, 174, true}, {LP.bs1, 262, true},
      {LP.bs2, 262}, {LP.bs2, 274}, {LP.bs3, 262}, {LP.bs3, 274}, {LP.bs4, 262}, {LP.bs4, 274}, {LP.bs5, 270},
      {LP.sill, 24}, {LP.sill, 60}, {LP.shelf, 128}, {LP.shelf, 156}, {LP.tree4, 210},
    },
    light = {"cup", "cup", "glass"}, heavy = {"vase", "plant"},
    left = {to = "study", kind = "flap"}, right = {to = "kitchen", kind = "stuck"},
  },
  kitchen = {
    name = "Küche", mult = 1.3,
    plats = list(KP, {"floor", "chair", "table", "counter", "spice", "cab", "fridge"}),
    spots = {
      {KP.chair, 38, true}, {KP.table, 72, true}, {KP.table, 104, true}, {KP.counter, 150, true},
      {KP.counter, 184}, {KP.counter, 206, true}, {KP.counter, 230},
      {KP.spice, 24, false, true}, {KP.spice, 42, false, true}, {KP.cab, 172, false, true},
      {KP.cab, 196, false, true}, {KP.cab, 220, false, true}, {KP.fridge, 270, false, true},
    },
    light = {"plate", "glass", "egg", "cup"}, heavy = {"pot", "pot", "vase"},
    left = {to = "living", kind = "door"},
    intro = {"Küche", {"Fliesen: alles", "ist lauter!", "Zu hoch? Yrsa", "springt von Levis", "Rücken ab!"}},
  },
  study = {
    name = "Arbeitszimmer", mult = 0.7,
    plats = list(SP, {"floor", "sh1", "sh2", "sh3", "sh4", "bean", "wall", "chair", "desk", "hang"}),
    spots = {
      {SP.sh1, 30}, {SP.sh1, 48}, {SP.sh2, 30}, {SP.sh2, 48}, {SP.sh3, 30}, {SP.sh3, 48}, {SP.sh4, 20}, {SP.sh4, 44},
      {SP.wall, 96}, {SP.wall, 124}, {SP.desk, 196}, {SP.desk, 220}, {SP.desk, 244},
      {SP.hang, 210}, {SP.hang, 234}, {SP.hang, 258},
    },
    light = {"pens", "frame", "cup", "glass"}, heavy = {},
    right = {to = "living", kind = "door"},
    intro = {"Arbeitszimmer", {"Teppich: hier ist", "es schön leise.", "Levi ist zu dick", "für die Klappe."}},
  },
}

-- Wie viele Sachen pro Raum: {leicht, schwer}
local function plan(n)
  if n == 1 then return {living = {4, 2}} end
  if n == 2 then return {living = {3, 2}, kitchen = {3, 3}} end
  local e = n - 3
  return {living = {3 + e // 3, 2 + e // 4}, kitchen = {3 + (e + 1) // 3, 3 + e // 4}, study = {5 + (e + 2) // 3, 0}}
end

-- Tafel zu Beginn der Nacht (Zeilen mit höchstens 18 Zeichen, große Schrift)
local NIGHT_INTRO = {
  [2] = {"Heute auch die", "Küche! Die Tür", "klemmt, nur Levi", "drückt sie auf."},
  [3] = {"Jetzt auch das", "Arbeitszimmer!", "Nur Yrsa passt", "durch die Klappe."},
}
local NEXT_ROOM = {[1] = "Morgen neu: die Küche!", [2] = "Morgen neu: das Arbeitszimmer!"}

local state, t
local save
local cats, active, other
local items, parts, debris, popups, moths, zs
local night, score, noise, clock, night_len, decay, left, combo_t, shake, end_t, reason, bonus
local card, card_t
local room_on, seen, door_open, door_push
local human -- wer heute Nacht im Schlafzimmer liegt: "human_lady" oder "human_guy"
local sel_down, sel_other

-- ---------- Helfer ----------

local function center(text, y, c, scale)
  print(text, (SCREEN_W - textw(text, scale)) // 2, y, c, scale)
end

-- Große Tafel mitten im Bild, das Spiel wartet, bis A gedrückt wird
local function show_card(title, lines)
  card, card_t, state = {title = title, lines = lines}, 0, "card"
end

local function popup(room, x, y, text, c)
  local scale = utf8.len(text) <= 10 and 2 or 1
  x = mid(2, x - (scale - 1) * textw(text) // 4, SCREEN_W - 2 - textw(text, scale))
  popups[#popups + 1] = {room = room, x = x, y = y - (scale - 1) * 8, text = text, c = c or C.text, scale = scale,
    life = 80}
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
function SFX.creak() tone(140 + rnd(60), 0.12, "saw", 0.12) end
function SFX.crash(kind)
  if KINDS[kind].heavy then
    tone(55, 0.35, "noise", 0.6) tone(70, 0.2, "square", 0.3)
  elseif kind == "egg" then
    tone(200, 0.08, "noise", 0.3)
    return
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

local function new_cat(name, x)
  local c = {name = name, room = "living", x = x, y = FLOOR, vx = 0, vy = 0, face = 1, on = LP.floor, anim = 0,
    tap_t = 0, drop_t = 0, top_y = FLOOR, idle = 0, hint_t = 0}
  if name == "levi" then
    c.w, c.h, c.speed, c.accel, c.jump, c.heavy = 26, 18, 1.15, 0.12, 3.3, true
  else
    c.w, c.h, c.speed, c.accel, c.jump, c.heavy = 22, 15, 1.9, 0.35, 4.6, false
  end
  return c
end

local function levi() return cats[1] end
local function yrsa() return cats[2] end

local function add_noise(n, room)
  noise = noise + n * ROOMS[room].mult
end

-- Levis Rücken als Brett für Yrsa
local function levi_plat()
  local l = levi()
  return {x0 = l.x + 3, x1 = l.x + l.w - 3, y = l.y - 14, levi = true}
end

local function riding()
  local y = yrsa()
  return y.on and y.on.levi and y.room == levi().room
end

local function on_plat(c, p)
  return c.x + c.w - 5 > p.x0 and c.x + 5 < p.x1
end

local function hint(c, text)
  if c.hint_t > 0 then return end
  c.hint_t = 90
  SFX.heavy_tap()
  popup(c.room, c.x - 10, c.y - c.h - 14, text, C.orange)
end

-- Schwerkraft und Landen. true, wenn die Katze in diesem Frame gelandet ist
local function physics(c)
  if c.on then
    if c.on.levi then
      local lp = levi_plat()
      if levi().room == c.room and on_plat(c, lp) then c.on, c.y = lp, lp.y return false end
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
  if c == yrsa() and levi().room == c.room then
    local lp = levi_plat()
    if prev <= lp.y and c.y >= lp.y and on_plat(c, lp) then
      c.y, c.vy, c.on = lp.y, 0, lp
      if c == active then popup(c.room, c.x - 4, c.y - 30, "Taxi!", C.yrsa) end
      return true
    end
  end
  for _, p in ipairs(ROOMS[c.room].plats) do
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
    if it.state == "rest" and it.room == c.room and it.plat == c.on then
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
    popup(c.room, best.x - 8, best.y - 26, "Zu schwer!", C.orange)
    if not best.told then
      best.told = true
      show_card("Zu schwer!", {"Das schafft nur", "Levi. Mit SELECT", "wechseln."})
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
    add_noise(8, c.room)
    shake = 4
    SFX.plumps()
    popup(c.room, c.x + 4, c.y - 24, "Plumps!", C.dim)
  elseif c.on.soft then
    tone(120, 0.05, "sine", 0.1)
  end
end

local function entered(room)
  if seen[room] then return end
  seen[room] = true
  local intro = ROOMS[room].intro
  if intro then show_card(intro[1], intro[2]) end
end

-- Durch die Tür am linken (side = -1) oder rechten Rand in den Nachbarraum
local function try_exit(c, side)
  local R = ROOMS[c.room]
  local e = R.right
  if side < 0 then e = R.left end
  if not e or not room_on[e.to] then return end
  if e.kind == "flap" and c.heavy then
    hint(c, "Levi passt nicht durch!")
    return
  end
  if e.kind == "stuck" and not door_open then
    if c.heavy then
      door_push = door_push + 1
      if door_push % 12 == 1 then SFX.creak() end
      if door_push >= 45 then
        door_open = true
        add_noise(5, c.room)
        popup(c.room, 250, 150, "Knarz!", C.text)
      end
    else
      hint(c, "Klemmt!")
      if not seen.door_hint then
        seen.door_hint = true
        show_card("Tür klemmt!", {"Nur Levi ist", "schwer genug, um", "sie aufzudrücken."})
      end
    end
    return
  end
  local take = c == levi() and riding()
  c.room = e.to
  c.x = side < 0 and SCREEN_W - 11 - c.w or 11
  c.vx = side * 0.5
  if take then
    local y = yrsa()
    y.room, y.x = e.to, c.x + 2
  end
  if c == active then entered(c.room) end
end

local function edges(c)
  return 10, SCREEN_W - 10 - c.w
end

local function control(c)
  local dir = 0
  if btn(BTN_LEFT) then dir = dir - 1 end
  if btn(BTN_RIGHT) then dir = dir + 1 end
  if dir ~= 0 then c.face = dir end
  local target = dir * c.speed
  if c.vx < target then c.vx = min(target, c.vx + c.accel) elseif c.vx > target then c.vx = max(target, c.vx - c.accel) end
  local lo, hi = edges(c)
  c.x = mid(lo, c.x + c.vx, hi)
  if c.on and c.on.floor then
    if dir < 0 and c.x <= lo then try_exit(c, -1)
    elseif dir > 0 and c.x >= hi then try_exit(c, 1) end
  end

  if c.on then
    if btnp(BTN_A) then
      c.vy = -c.jump * (c.on.levi and TAXI or 1)
      if c.on.levi then tune("C6:0.3 G6:0.6", 900, "triangle", 0.2, false, 6) else SFX.jump(c) end
      c.on = nil
      c.top_y = c.y
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
  if c.hint_t > 0 then c.hint_t = c.hint_t - 1 end
  if physics(c) then land(c) end
  if is_active then c.idle = 0 else c.idle = c.idle + 1 end
end

-- ---------- Sachen ----------

local function add_item(room, kind, s)
  local w, h = S.size(KINDS[kind].sprite)
  items[#items + 1] = {room = room, kind = kind, plat = s[1], x = s[2], y = s[1].y, w = w, h = h, vx = 0, vy = 0,
    state = "rest", wob = 0}
end

local function take(l)
  return table.remove(l, 1 + flr(rnd(#l)))
end

local function place_items()
  items = {}
  room_on = {}
  for _, room in ipairs({"living", "kitchen", "study"}) do
    local n = plan(night)[room]
    if n then
      room_on[room] = true
      local R = ROOMS[room]
      local heavy, taxi, normal = {}, {}, {}
      for _, s in ipairs(R.spots) do
        if s[3] then heavy[#heavy + 1] = s elseif s[4] then taxi[#taxi + 1] = s else normal[#normal + 1] = s end
      end
      for _ = 1, min(n[2], #heavy) do add_item(room, rnd(R.heavy), take(heavy)) end
      -- In der Küche stehen immer ein paar Sachen dort, wo nur das Levi-Taxi hinkommt
      local n_light = n[1]
      for _ = 1, min(#taxi, 3, n_light) do
        add_item(room, rnd(R.light), take(taxi))
        n_light = n_light - 1
      end
      for _, s in ipairs(heavy) do normal[#normal + 1] = s end
      for _, s in ipairs(taxi) do normal[#normal + 1] = s end
      for _ = 1, min(n_light, #normal) do add_item(room, rnd(R.light), take(normal)) end
    end
  end
  left = #items
end

local function shards(it, ground)
  local k = KINDS[it.kind]
  for _ = 1, 10 + (k.heavy and 8 or 0) do
    parts[#parts + 1] = {room = it.room, x = it.x + it.w / 2 + rnd(6) - 3, y = ground - 2, ground = ground,
      vx = rnd(3) - 1.5, vy = -1 - rnd(2.5), c = rnd(k.shard), s = rnd(1) < 0.3 and 2 or 1}
  end
end

local function knocked(it, soft, ground)
  local k = KINDS[it.kind]
  it.state = "gone"
  left = left - 1
  local pts = k.pts
  if combo_t > 0 then
    pts = pts * 2
    popup(it.room, it.x - 4, ground - 34, "Doppelt!", C.gold)
  end
  combo_t = 50
  score = score + pts
  if soft then
    add_noise(3, it.room)
    SFX.soft()
    popup(it.room, it.x - 10, ground - 20, "Plopp. +" .. pts, C.green)
  else
    add_noise(k.noise, it.room)
    shake = k.heavy and 8 or 4
    SFX.crash(it.kind)
    shards(it, ground)
    popup(it.room, it.x - 12, ground - 26, k.word, C.text)
    popup(it.room, it.x - 2, ground - 16, "+" .. pts, C.gold)
  end
  if left == 0 then
    bonus = flr((night_len - clock) / 60) * 3 + flr(max(0, NOISE_WAKE - noise)) * 2
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
        local hi = (it.plat.rstop or SCREEN_W - 10) - it.w
        local lo = it.plat.lstop or 10
        if it.x > hi then it.x, it.vx = hi, 0 end
        if it.x < lo then it.x, it.vx = lo, 0 end
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
      for _, p in ipairs(ROOMS[it.room].plats) do
        if p ~= it.plat and prev <= p.y and it.y >= p.y and cx > p.x0 and cx < p.x1 then
          it.y = p.y
          knocked(it, p.soft, p.y)
          break
        end
      end
    end
  end
end

-- ---------- Motten ----------

local function update_moths(room)
  if rnd(1) < 1 / 700 and #moths < 2 then
    moths[#moths + 1] = {room = room, x = 50, y = 60, tx = 60 + rnd(200), ty = 40 + rnd(150), life = 600 + flr(rnd(300))}
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
    if m.room == c.room and m.x + 6 > c.x and m.x < c.x + c.w and m.y + 4 > c.y - c.h and m.y < c.y then
      score = score + 100
      SFX.moth()
      popup(m.room, m.x - 8, m.y - 10, "Motte! +100", C.gold)
      table.remove(moths, i)
    elseif m.life < -200 or m.room ~= room then
      table.remove(moths, i)
    end
  end
end

-- ---------- Ablauf ----------

local function start_night()
  cats = {new_cat("levi", 50), new_cat("yrsa", 150)}
  cats[2].face = -1
  active, other = cats[1], cats[2]
  parts, debris, popups, moths, zs = {}, {}, {}, {}, {}
  noise, clock, combo_t, shake = 0, 0, 0, 0
  seen, door_open, door_push = {living = true}, false, 0
  human = rnd(1) < 0.5 and "human_lady" or "human_guy"
  place_items()
  local n_rooms = 0
  for _ in pairs(room_on) do n_rooms = n_rooms + 1 end
  night_len = 60 * max(45 + 30 * n_rooms - 5 * max(0, night - 3), 25 + 30 * n_rooms)
  decay = max(0.02, 0.045 - 0.003 * (night - 1))
  state, t = "play", 0
  if night == 1 then
    show_card("Nacht 1", {left .. " Sachen müssen", "runter. Vasen und", "Töpfe schafft", "nur Levi!"})
  else
    show_card("Nacht " .. night, NIGHT_INTRO[night] or {left .. " Sachen müssen", "runter!"})
  end
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
  popup(active.room, active.x + 2, active.y - active.h - 12, active.name == "levi" and "Levi" or "Yrsa",
    active.name == "levi" and C.levi or C.yrsa)
end

local function update_popups()
  for i = #popups, 1, -1 do
    local p = popups[i]
    p.y, p.life = p.y - 0.4, p.life - 1
    if p.life <= 0 then table.remove(popups, i) end
  end
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
  local lx, lroom = l.x, l.room
  local ride = active == l and riding()
  update_cat(active, true)
  if ride then
    if l.room == lroom then y.x = mid(10, y.x + (l.x - lx), SCREEN_W - 10 - y.w) end
    y.y, y.on, y.top_y = l.y - 14, levi_plat(), l.y - 14
    y.idle = y.idle + 1
  else
    update_cat(other, false)
  end

  update_items()
  if state ~= "play" then return end
  update_moths(active.room)

  noise = max(0, noise - decay)
  if combo_t > 0 then combo_t = combo_t - 1 end
  if shake > 0 then shake = shake - 1 end

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
    if p.y >= p.ground - 1 and p.vy > 0 then
      p.y = p.ground - 1 - flr(rnd(2))
      if #debris > 200 then table.remove(debris, 1) end
      debris[#debris + 1] = p
      table.remove(parts, i)
    end
  end
  update_popups()

  if noise >= NOISE_WAKE then
    SFX.wake()
    game_over("wake")
  elseif clock >= night_len then
    SFX.wake()
    game_over("morning")
  end
end

function _init()
  save = loaddata() or {}
  state, t = "title", 0
  night, score = 1, 0
  cats = {new_cat("levi", 60), new_cat("yrsa", 200)}
  items, parts, debris, popups, moths, zs = {}, {}, {}, {}, {}, {}
  noise, clock, night_len, shake = 0, 0, 1, 0
  room_on, seen, door_open, door_push = {living = true}, {}, false, 0
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
  elseif state == "card" then
    card_t = card_t + 1
    if card_t > 15 and (btnp(BTN_A) or btnp(BTN_START)) then state = "play" end
  elseif state == "clear" then
    end_t = end_t + 1
    update_popups()
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

local BOOK_COLS = {rgb(170, 60, 60), rgb(60, 110, 160), rgb(210, 170, 70), rgb(80, 140, 90), rgb(140, 90, 150),
  rgb(200, 120, 60), rgb(90, 90, 110)}
local function books(x0, x1, ys, seed)
  local l = {}
  local function r(n) seed = (seed * 1103 + 12345) % 30011 return seed % n end
  for _, y in ipairs(ys) do
    local x = x0
    while x < x1 do
      local w = 2 + r(3)
      local h = 16 + r(9)
      l[#l + 1] = {x, y - h, min(x + w - 1, x1), y - 1, BOOK_COLS[1 + r(#BOOK_COLS)]}
      x = x + w
    end
  end
  return l
end
local L_BOOKS = books(289, 304, {194, 166, 136, 106}, 7)
local S_BOOKS = books(9, 21, {190, 154, 118}, 11)
local STARS = {{28, 40}, {44, 34}, {70, 48}, {36, 66}, {80, 36}, {58, 74}, {82, 80}}

local function board(p, c, cl, h)
  rectfill(p.x0, p.y, p.x1, p.y + (h or 3), c)
  line(p.x0, p.y, p.x1, p.y, cl)
end

local function draw_books(l)
  for _, b in ipairs(l) do rectfill(b[1], b[2], b[3], b[4], b[5]) end
end

-- Tür am Rand: x0 ist 0 (links) oder 310 (rechts). kind: "flap", "stuck", "door"; on: Nachbarraum offen
local function side_door(x0, kind, on)
  local x1 = x0 + 9
  rectfill(x0, 118, x1, FLOOR - 1, C.door_d)
  if kind == "door" or (kind == "stuck" and door_open) then
    rectfill(x0 + 2, 122, x1 - 2, FLOOR - 1, C.dark)
    return
  end
  rectfill(x0 + 1, 120, x1 - 1, FLOOR - 1, C.door)
  if kind == "flap" and on then
    rectfill(x0 + 1, 206, x1 - 1, FLOOR - 2, C.door_d)
    rectfill(x0 + 2, 208, x1 - 2, FLOOR - 3, C.wood_l)
  end
  rectfill(x0 == 0 and x1 - 3 or x0 + 2, 172, x0 == 0 and x1 - 2 or x0 + 3, 176, C.gold)
end

local function draw_living(lit)
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
  board(LP.sill, C.wood, C.wood_l, 5)

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
  board(LP.shelf, C.wood, C.wood_l, 4)
  rectfill(122, 104, 124, 110, C.wood_d)
  rectfill(168, 104, 170, 110, C.wood_d)

  side_door(0, "flap", room_on.study)
  side_door(310, "stuck", room_on.kitchen)

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
  board(LP.table, C.wood, C.wood_l, 4)
  rectfill(150, 208, 153, FLOOR - 1, C.wood_d)
  rectfill(183, 208, 186, FLOOR - 1, C.wood_d)

  -- Kratzbaum
  rectfill(222, 80, 228, FLOOR - 1, C.sisal)
  for y = 86, FLOOR - 4, 6 do line(222, y, 228, y + 2, C.sisal_d) end
  rectfill(204, FLOOR - 5, 246, FLOOR - 1, C.carpet_d)
  for _, p in ipairs({LP.tree1, LP.tree2, LP.tree3, LP.tree4}) do
    rectfill(p.x0, p.y, p.x1, p.y + 5, C.carpet)
    line(p.x0, p.y + 5, p.x1, p.y + 5, C.carpet_d)
  end
  line(204, 158, 204, 170, C.dim)
  circfill(204, 172, 2, C.dim)

  -- Bücherregal
  rectfill(252, 72, 308, FLOOR - 1, C.wood_d)
  rectfill(255, 76, 305, 194, C.shadow)
  draw_books(L_BOOKS)
  for _, p in ipairs({LP.bs1, LP.bs2, LP.bs3, LP.bs4, LP.bs5}) do board(p, C.wood, C.wood_l, 3) end
  rectfill(255, 198, 305, FLOOR - 3, C.wood)
  line(280, 198, 280, FLOOR - 3, C.wood_d)
  rectfill(276, 208, 278, 210, C.gold)
  rectfill(282, 208, 284, 210, C.gold)
end

local function draw_kitchen()
  rectfill(0, HUD_H, 319, FLOOR - 1, C.k_wall)
  -- Fliesenspiegel hinter der Arbeitsplatte
  rectfill(140, 140, 244, 175, C.k_tile)
  for x = 140, 244, 13 do line(x, 140, x, 175, C.k_tile2) end
  for y = 140, 175, 12 do line(140, y, 244, y, C.k_tile2) end
  -- Boden: Fliesen
  for x = 0, 319, 16 do
    rectfill(x, FLOOR, x + 15, 231, (x // 16) % 2 == 0 and C.k_floor or C.k_floor2)
    rectfill(x, 232, x + 15, 239, (x // 16) % 2 == 1 and C.k_floor or C.k_floor2)
  end
  -- Fenster über dem Tisch
  rectfill(62, 30, 122, 96, C.frame)
  rectfill(66, 34, 118, 92, C.sky)
  circfill(104, 50, 5, C.moon)
  pset(76, 44, C.moon) pset(88, 70, C.moon) pset(110, 80, C.moon)
  line(92, 34, 92, 92, C.frame)
  -- Gewürzregal
  board(KP.spice, C.wood, C.wood_l, 3)
  rectfill(22, 124, 24, 130, C.wood_d)
  rectfill(50, 124, 52, 130, C.wood_d)
  -- Stuhl
  rectfill(30, 160, 33, 200, C.wood_d)
  rectfill(30, 160, 50, 164, C.wood_d)
  board(KP.chair, C.wood, C.wood_l, 3)
  rectfill(31, 204, 33, FLOOR - 1, C.wood_d)
  rectfill(52, 204, 54, FLOOR - 1, C.wood_d)
  -- Tisch
  board(KP.table, C.wood, C.wood_l, 4)
  rectfill(68, 201, 71, FLOOR - 1, C.wood_d)
  rectfill(117, 201, 120, FLOOR - 1, C.wood_d)
  -- Unterschrank mit Arbeitsplatte
  rectfill(140, 176, 244, FLOOR - 1, C.k_front)
  for x = 140, 208, 35 do rect(x + 2, 184, x + 33, FLOOR - 4, C.k_front_d) end
  for x = 140, 208, 35 do rectfill(x + 15, 188, x + 20, 189, C.fridge_d) end
  rectfill(138, 174, 246, 179, C.k_top)
  line(138, 174, 246, 174, C.fridge)
  -- Hängeschrank
  rectfill(164, 100, 236, 138, C.k_front)
  for x = 164, 212, 24 do rect(x + 2, 104, x + 21, 135, C.k_front_d) end
  for x = 164, 212, 24 do rectfill(x + 9, 130, x + 14, 131, C.fridge_d) end
  line(164, 100, 236, 100, C.fridge)
  -- Kühlschrank
  rectfill(256, 100, 294, FLOOR - 1, C.fridge)
  rect(256, 100, 294, FLOOR - 1, C.fridge_d)
  line(256, 140, 294, 140, C.fridge_d)
  rectfill(260, 110, 261, 132, C.fridge_d)
  rectfill(260, 148, 261, 176, C.fridge_d)
  circfill(282, 118, 3, C.red)
  rectfill(274, 152, 284, 160, C.gold)
  -- Mülleimer
  rectfill(300, 198, 314, FLOOR - 1, C.fridge_d)
  rectfill(298, 194, 316, 198, C.k_top)
  side_door(0, "door", true)
end

local function draw_study()
  rectfill(0, HUD_H, 319, FLOOR - 1, C.s_wall)
  for x = 0, 319, 20 do rectfill(x, HUD_H, x + 9, FLOOR - 7, C.s_wall2) end
  rectfill(0, FLOOR - 6, 319, FLOOR - 1, C.base)
  rectfill(0, FLOOR, 319, 239, C.s_floor)
  for x = 0, 319, 6 do pset(x + (x // 6) % 3, 230, C.s_floor2) end
  rectfill(90, 226, 230, 236, C.rug)
  rect(92, 227, 228, 235, C.bean_d)
  -- Bild an der Wand
  rectfill(96, 40, 140, 76, C.frame)
  rectfill(99, 43, 137, 73, C.sky)
  circfill(126, 54, 5, C.gold)
  rectfill(99, 64, 137, 73, rgb(58, 126, 54))
  -- Bücherregal links
  rectfill(4, 78, 74, FLOOR - 1, C.wood_d)
  rectfill(8, 82, 70, 190, C.shadow)
  draw_books(S_BOOKS)
  for _, p in ipairs({SP.sh1, SP.sh2, SP.sh3, SP.sh4}) do board(p, C.wood, C.wood_l, 3) end
  rectfill(8, 194, 70, FLOOR - 3, C.wood)
  -- Wandbrett
  board(SP.wall, C.wood, C.wood_l, 3)
  rectfill(92, 128, 94, 134, C.wood_d)
  rectfill(134, 128, 136, 134, C.wood_d)
  -- Sitzsack
  circfill(102, 216, 11, C.bean_d)
  rectfill(80, 210, 124, FLOOR - 1, C.bean)
  circfill(90, 214, 8, C.bean)
  circfill(114, 214, 8, C.bean)
  line(84, 210, 120, 210, rgb(230, 150, 90))
  -- Hängeregal
  board(SP.hang, C.wood, C.wood_l, 3)
  rectfill(206, 136, 208, 142, C.wood_d)
  rectfill(264, 136, 266, 142, C.wood_d)
  -- Bürostuhl
  rectfill(170, 158, 174, 196, C.shadow)
  board(SP.chair, C.shadow, C.dim, 4)
  rectfill(161, 201, 164, 214, C.shadow)
  rectfill(152, 214, 174, 216, C.shadow)
  -- Schreibtisch mit Lampe und Bildschirm
  board(SP.desk, C.wood, C.wood_l, 4)
  rectfill(188, 183, 192, FLOOR - 1, C.wood_d)
  rectfill(282, 183, 286, FLOOR - 1, C.wood_d)
  rectfill(262, 150, 288, 170, C.shadow)
  rectfill(264, 152, 286, 168, C.screen)
  rectfill(273, 171, 277, 177, C.shadow)
  side_door(310, "flap", true)
end

local DRAW = {living = draw_living, kitchen = draw_kitchen, study = draw_study}

local function draw_cat(c, is_active)
  local name
  -- Auf Levis Rücken schläft Yrsa nicht, sie fährt mit
  local sits = c.name == "yrsa" and riding()
  if not is_active then
    name = sits and "yrsa_sit" or c.name .. "_loaf"
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
  elseif not sits and flr(c.idle / 40) % 3 == 0 and c.idle > 30 then
    print("z", x + (c.face > 0 and w - 2 or -4), y - 6 - (c.idle % 40) // 8, C.dim)
  end
end

local function count_in(room)
  local n = 0
  for _, it in ipairs(items) do
    if it.room == room and it.state ~= "gone" then n = n + 1 end
  end
  return n
end

local function draw_hud()
  rectfill(0, 0, 319, HUD_H - 1, C.hud)
  print("Nacht " .. night, 4, 4, C.text)
  local mins = flr(clock * 360 / night_len)
  local tt = string.format("%d:%02d", mins // 60, mins % 60)
  print(tt, 74, 4, clock > night_len - 600 and C.orange or C.dim)
  S.draw("cup", 116, 4)
  print(tostring(left), 129, 4, C.text)
  print("Zzz", 154, 4, C.dim)
  rectfill(180, 4, 244, 11, C.shadow)
  local f = min(noise, NOISE_WAKE) / NOISE_WAKE
  local col = noise >= NOISE_STIR and C.red or (noise > 40 and C.orange or C.green)
  if f > 0 then rectfill(181, 5, 181 + flr(62 * f), 10, col) end
  local sx = 181 + flr(62 * NOISE_STIR / NOISE_WAKE)
  line(sx, 4, sx, 11, C.dim)
  local s = tostring(score)
  print(s, 316 - textw(s), 4, C.gold)
end

-- Unten auf dem Boden: Nachbarräume mit übrigen Sachen und wo die andere Katze ist
local function draw_floor_labels(view)
  local R = ROOMS[view]
  local col = rgb(236, 220, 200)
  for side = -1, 1, 2 do
    local e = R.right
    if side < 0 then e = R.left end
    if e and room_on[e.to] then
      local text = ROOMS[e.to].name .. " " .. count_in(e.to)
      if other.room == e.to then text = text .. (other.name == "levi" and " +Levi" or " +Yrsa") end
      if side < 0 then
        print("<" .. text, 3, 229, col)
      else
        text = text .. ">"
        print(text, 317 - textw(text), 229, col)
      end
    end
  end
end

local function draw_world(view, lit)
  local sx = shake > 0 and (rnd(1) < 0.5 and -1 or 1) or 0
  camera(sx, 0)
  DRAW[view](lit)
  for _, d in ipairs(debris) do
    if d.room == view then
      if d.s == 2 then rectfill(d.x, d.y - 1, d.x + 1, d.y, d.c) else pset(d.x, d.y, d.c) end
    end
  end
  if view == "living" then
    for _, z in ipairs(zs) do print("z", z.x, z.y, C.dim) end
  end
  for _, it in ipairs(items) do
    if it.state ~= "gone" and it.room == view then
      local ox = it.wob > 0 and (it.wob % 4 < 2 and 1 or -1) or 0
      S.draw(KINDS[it.kind].sprite, flr(it.x) + ox, flr(it.y) - it.h)
    end
  end
  if riding() then
    if levi().room == view then
      draw_cat(levi(), levi() == active)
      draw_cat(yrsa(), yrsa() == active)
    end
  else
    if other.room == view then draw_cat(other, false) end
    if active.room == view then draw_cat(active, true) end
  end
  for _, m in ipairs(moths) do
    if m.room == view then S.draw(flr(t / 5) % 2 == 0 and "moth1" or "moth2", flr(m.x), flr(m.y)) end
  end
  for _, p in ipairs(parts) do
    if p.room == view then pset(p.x, p.y, p.c) end
  end
  for _, p in ipairs(popups) do
    if p.room == view then
      print(p.text, flr(p.x) + 1, flr(p.y) + 1, C.shadow, p.scale)
      print(p.text, flr(p.x), flr(p.y), p.c, p.scale)
    end
  end
  camera()
end

local function panel(y0, y1)
  rectfill(16, y0, 303, y1, C.hud)
  rect(16, y0, 303, y1, C.dim)
end

local function draw_title()
  cls(C.wall)
  local keep = noise
  noise = 0
  draw_living(false)
  noise = keep
  rectfill(0, 0, 319, HUD_H - 1, C.hud)
  panel(20, 150)
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
  local over = state == "over"
  local view = over and "living" or active.room
  draw_world(view, over)
  if over then
    local r = S.rects[human]
    sspr(S.img, r[1], r[2], r[3], r[4], 116 + (31 - r[3] * 2) // 2, FLOOR - r[4] * 2, r[3] * 2, r[4] * 2)
  end
  draw_hud()
  if state == "play" then
    if night == 1 then
      print("A Sprung  B Tatze  SELECT Wechsel", 28, 229, rgb(200, 160, 130))
    else
      draw_floor_labels(view)
    end
  end
  if state == "card" then
    local h = 36 + #card.lines * 18
    local y0 = 120 - h // 2
    panel(y0, y0 + h + 14)
    center(card.title, y0 + 8, C.gold, 2)
    for i, l in ipairs(card.lines) do center(l, y0 + 12 + i * 18, C.text, 2) end
    if card_t > 15 and flr(card_t / 20) % 2 == 0 then center("A: weiter", y0 + h + 2, C.dim) end
  elseif state == "pause" then
    panel(96, 136)
    center("Pause", 104, C.text, 2)
    center("START: weiter", 124, C.dim)
  elseif state == "clear" then
    panel(56, 170)
    center("Nacht geschafft!", 66, C.gold, 2)
    center("Alles unten, der Mensch schläft.", 90, C.text)
    center("Bonus +" .. bonus, 104, C.green)
    center("Punkte " .. score, 118, C.text)
    if NEXT_ROOM[night] then center(NEXT_ROOM[night], 136, C.gold) end
    if end_t > 60 then center("A: nächste Nacht", 154, C.dim) end
  elseif over then
    panel(36, 134)
    if reason == "wake" then
      center("LEVI! YRSA!", 46, C.red, 2)
      center("Der Mensch ist aufgewacht.", 68, C.text)
    else
      center("6 Uhr!", 46, C.orange, 2)
      center("Der Wecker klingelt.", 64, C.text)
      center("Noch " .. left .. (left == 1 and " Sache oben." or " Sachen oben."), 75, C.text)
    end
    center("Nacht " .. night .. "   Punkte " .. score, 90, C.gold)
    center("Rekord " .. (save.best or 0), 104, C.dim)
    if end_t > 90 then center("A: nochmal", 120, C.dim) end
  end
end
