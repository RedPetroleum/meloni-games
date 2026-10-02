-- Roller-Rowdy: Mit dem Leih-E-Scooter durch den Feierabendverkehr, die Polizei im Nacken.
-- Fake-3D wie bei den alten Automaten-Rennspielen: die Straße besteht aus Segmenten, die
-- Zeile für Zeile als Trapeze gezeichnet werden, Autos und Häuser sind skalierte Sprites.
--
-- A: Gas   B: Bremse   links/rechts: lenken   START: Pause
-- In der Luft (nach einer Rampe): A Tailwhip, B No-Hander, links/rechts 360
-- Der Akku ist die Zeit: an Ladestationen gibt es neue Sekunden. Holt die Polizei dich ein: vorbei.

local S = require("sprites")
local RECTS, IMG = S.rects, S.img

local W, H = SCREEN_W, SCREEN_H
local HW, HH = W / 2, H / 2

-- Welt
local SEG = 200                 -- Länge eines Straßensegments
local ROAD_W = 1000             -- halbe Straßenbreite
local CAM_H = 700
local DEPTH = 0.84              -- 1 / tan(Blickwinkel / 2), etwa 100 Grad
local PLAYER_Z = CAM_H * DEPTH  -- so weit vor der Kamera steht der Roller
local DRAW = 80                 -- sichtbare Segmente
local K = 12                    -- Weltgröße eines Sprite-Pixels
local LANES = {-2 / 3, 0, 2 / 3}
local MAXSPEED = SEG            -- Einheiten pro Frame
local BOOSTSPEED = MAXSPEED * 1.32
local KMH = 86                  -- Anzeige bei MAXSPEED (passt zu M_PER_UNIT)
local CENTRIFUGAL = 0.18
local GRAV = 0.16
local CHECK_EVERY = 800         -- Segmente zwischen Ladestationen
local M_PER_UNIT = 0.002        -- für die Kilometeranzeige

local C = {
  sky = {rgb(34, 22, 58), rgb(58, 30, 86), rgb(92, 38, 104), rgb(140, 50, 112), rgb(196, 70, 108),
    rgb(236, 110, 96), rgb(250, 160, 90), rgb(255, 205, 120)},
  city1 = rgb(40, 28, 62), city2 = rgb(56, 38, 80), window = rgb(255, 214, 110),
  ground1 = rgb(58, 66, 70), ground2 = rgb(52, 60, 64),
  walk1 = rgb(150, 146, 150), walk2 = rgb(136, 132, 138),
  curb1 = rgb(220, 220, 226), curb2 = rgb(170, 60, 70),
  road1 = rgb(74, 72, 82), road2 = rgb(68, 66, 76),
  lane = rgb(236, 236, 230), check = rgb(94, 194, 74),
  white = rgb(255, 255, 255), black = rgb(16, 12, 24), shadow = rgb(30, 26, 36),
  yellow = rgb(255, 216, 74), red = rgb(255, 58, 74), blue = rgb(63, 160, 255),
  green = rgb(94, 194, 74), orange = rgb(255, 130, 40), dim = rgb(170, 160, 190),
  panel = rgb(22, 16, 34),
}

local CAR_KINDS = {
  {name = "car_rear", hw = 0.19}, {name = "blue_rear", hw = 0.19}, {name = "taxi_rear", hw = 0.19},
  {name = "white_rear", hw = 0.19}, {name = "green_rear", hw = 0.19}, {name = "violet_rear", hw = 0.19},
  {name = "bus", hw = 0.24, bus = true},
}

-- Zustand
local segments, N, L = {}, 0, 0
local cars = {}
local state, t
local position, speed, player_x, player_y, distance
local ghost = 0
local steer, crash_t, air, jump_h, jump_v, trick, tricks_done, boost
local battery, gap, score, near_misses, tricks_total, next_check, checks, race_t, reason
local popups, sparks = {}, {}
local sky_off = 0
local save
local vis = {}
local bucket, bcount = {}, {}
for i = 0, DRAW do bucket[i] = {} bcount[i] = 0 end

-- ---------- Strecke ----------

local function last_y()
  local n = #segments
  return n == 0 and 0 or segments[n].p2.y
end

local function add_segment(curve, y)
  local n = #segments
  segments[n + 1] = {
    index = n, curve = curve, color = (n // 3) % 2, lanes = (n // 2) % 2 == 0,
    p1 = {z = n * SEG, y = last_y()}, p2 = {z = (n + 1) * SEG, y = y}, sprites = {},
  }
end

local function ease_in(a, b, p) return a + (b - a) * p * p end
local function ease_inout(a, b, p) return a + (b - a) * (-math.cos(p * math.pi) / 2 + 0.5) end

local function add_road(enter, hold, leave, curve, height)
  local sy = last_y()
  local ey = sy + height * SEG
  local total = enter + hold + leave
  for n = 0, enter - 1 do add_segment(ease_in(0, curve, n / enter), ease_inout(sy, ey, n / total)) end
  for n = 0, hold - 1 do add_segment(curve, ease_inout(sy, ey, (enter + n) / total)) end
  for n = 0, leave - 1 do add_segment(ease_inout(curve, 0, n / leave), ease_inout(sy, ey, (enter + hold + n) / total)) end
end

local function add_sprite(i, name, x, solid, w)
  local seg = segments[i]
  if seg then seg.sprites[#seg.sprites + 1] = {name = name, x = x, solid = solid, w = w or 0.1, flip = x < 0} end
end

local function build_track()
  segments = {}
  add_road(10, 60, 10, 0, 0)
  while #segments < 1500 do
    local h = 0
    local alt = last_y() / SEG
    if rnd(1) < 0.45 then
      h = (10 + rnd(30)) * (alt > 30 and -1 or alt < -30 and 1 or (rnd(1) < 0.5 and -1 or 1))
    end
    local r = rnd(1)
    if r < 0.3 then
      add_road(20, 20 + flr(rnd(40)), 20, 0, h)
    elseif r < 0.8 then
      local dir = rnd(1) < 0.5 and -1 or 1
      add_road(20, 20 + flr(rnd(40)), 20, dir * (1.5 + rnd(3.5)), h)
    else
      local dir = rnd(1) < 0.5 and -1 or 1
      add_road(15, 15, 15, dir * 2.5, h / 2)
      add_road(15, 15, 15, -dir * 2.5, h / 2)
    end
  end
  add_road(30, 40, 30, 0, -last_y() / SEG)
  N = #segments
  L = N * SEG

  -- Straßenrand: Laternen, Bäume, Häuser
  for i = 1, N do
    if i % 8 == 0 then
      add_sprite(i, "lamp", -1.45, true, 0.08)
      add_sprite(i, "lamp", 1.45, true, 0.08)
    end
    if i % 6 == 3 then
      local side = (i // 6) % 2 == 0 and -1 or 1
      local r = rnd(1)
      if r < 0.3 then
        add_sprite(i, "tree", side * (1.75 + rnd(0.3)), true, 0.12)
      else
        local names = {"house_a", "house_b", "b_a", "b_b"}
        add_sprite(i, names[1 + flr(rnd(4))], side * (2.6 + rnd(0.6)), false)
      end
    end
  end
  -- Rampen und Pylonen, nicht direkt am Start
  local i = 120
  while i < N - 40 do
    if rnd(1) < 0.65 then
      local seg = segments[i]
      seg.ramp = LANES[1 + flr(rnd(3))]
      add_sprite(i, "ramp", seg.ramp, false)
      seg.sprites[#seg.sprites].flip = false
    else
      local lane = LANES[1 + flr(rnd(3))]
      for k = 0, 2 do add_sprite(i + k * 3, "cone", lane + (rnd(0.1) - 0.05), true, 0.07) end
      for k = 0, 2 do segments[i + k * 3].sprites[#segments[i + k * 3].sprites].flip = false end
    end
    i = i + 45 + flr(rnd(60))
  end
  -- Ladestationen
  for c = CHECK_EVERY, N - 1, CHECK_EVERY do
    local seg = segments[c]
    seg.check = true
    add_sprite(c, "charger", -1.2, true, 0.1)
    add_sprite(c, "charger", 1.2, true, 0.1)
  end
end

local function seg_of(z)
  return segments[flr(z / SEG) % N + 1]
end

-- ---------- Verkehr ----------

local function spawn_cars(count)
  cars = {}
  for i = 1, count do
    local kind = CAR_KINDS[1 + flr(rnd(#CAR_KINDS))]
    local lane = LANES[1 + flr(rnd(3))]
    cars[i] = {
      z = (80 + rnd(N - 100)) * SEG, x = lane, tx = lane, name = kind.name, hw = kind.hw,
      speed = MAXSPEED * (kind.bus and (0.22 + rnd(0.1)) or (0.28 + rnd(0.32))), ahead = true, blink = 0,
    }
  end
end

local function update_cars()
  for _, c in ipairs(cars) do
    c.z = (c.z + c.speed) % L
    if c.x == c.tx and rnd(1) < 0.0015 then
      local choices = {}
      for _, l in ipairs(LANES) do
        if math.abs(l - c.x) < 0.7 and l ~= c.x then choices[#choices + 1] = l end
      end
      c.tx = choices[1 + flr(rnd(#choices))]
    end
    if c.x ~= c.tx then
      local d = c.tx - c.x
      if math.abs(d) < 0.012 then c.x = c.tx else c.x = c.x + sgn(d) * 0.012 end
      c.blink = c.blink + 1
    end
  end
end

-- ---------- Effekte und Töne ----------

local function popup(text, color, scale, frames)
  popups[#popups + 1] = {text = text, c = color or C.white, scale = scale or 2, t = frames or 70, max = frames or 70}
end

local function spark(x, y, n, color)
  for _ = 1, n do
    if #sparks > 80 then table.remove(sparks, 1) end
    sparks[#sparks + 1] = {x = x, y = y, vx = rnd(6) - 3, vy = -rnd(4) - 1, t = 20 + flr(rnd(20)), c = color or C.yellow}
  end
end

local SFX = {}
function SFX.music() tune("C3:0.5 C3:0.5 C4:0.5 C3:0.5 Bb2:0.5 Bb2:0.5 Bb3:0.5 Bb2:0.5 Ab2:0.5 Ab2:0.5 Ab3:0.5 Ab2:0.5 G2:0.5 G2:0.5 B2:0.5 D3:0.5", 150, "square", 0.08, true, 7) end
function SFX.crash() tone(80, 0.35, "noise", 0.6) tune("E3:0.5 C3:1", 500, "saw", 0.2, false, 6) end
function SFX.honk() tune("A4:0.4 - A4:0.8", 400, "square", 0.18, false, 3) end
function SFX.jump() tune("C4:0.25 G4:0.25 C5:0.5", 700, "triangle", 0.3, false, 6) end
function SFX.land() tune("G5:0.25 C6:0.25 E6:0.25 G6:0.75", 700, "square", 0.22, false, 6) end
function SFX.near() tone(note("E6"), 0.06, "square", 0.2) end
function SFX.check() tune("C5:0.5 E5:0.5 G5:0.5 C6:1 G5:0.5 C6:1.5", 500, "square", 0.25, false, 6) end
function SFX.tick() tone(note("A5"), 0.03, "square", 0.15) end
function SFX.caught() tune("G4:1 F#4:1 F4:1 E4:3", 180, "saw", 0.25, false, 6) end
function SFX.trick() tone(note("C6"), 0.05, "triangle", 0.25) end

-- Frisch gedrückt? (btnp wiederholt bei gehaltener Taste, Gas halten soll keinen Trick auslösen)
local prev_btn, cur_btn = 0, 0
local function pressed(b)
  return (cur_btn >> b) & 1 == 1 and (prev_btn >> b) & 1 == 0
end


-- ---------- Rennen ----------

local function reset_race()
  build_track()
  spawn_cars(26)
  position, speed, player_x, player_y, distance = 0, 0, 0, 0, 0
  steer, crash_t, air, jump_h, jump_v, trick, tricks_done, boost = 0, 0, false, 0, 0, nil, {}, 0
  ghost = 0
  battery, gap, score, near_misses, tricks_total = 35 * 60, 60, 0, 0, 0
  next_check, checks, race_t, reason = CHECK_EVERY, 0, 0, nil
  popups, sparks = {}, {}
end

local function crash(text)
  if crash_t > 0 then return end
  crash_t = 60
  speed = speed * 0.25
  air, jump_h, trick, tricks_done, boost = false, 0, nil, {}, 0
  SFX.crash()
  spark(HW, H - 30, 20)
  popup(text or "AUTSCH!", C.red, 3, 60)
end

local TRICKS = {
  tailwhip = {dur = 26, pts = 300, label = "TAILWHIP"},
  nohand = {dur = 30, pts = 250, label = "NO-HANDER"},
  spin = {dur = 34, pts = 400, label = "360"},
}

local function start_trick(kind, dir)
  trick = {kind = kind, t = 0, dur = TRICKS[kind].dur, dir = dir or 1}
  SFX.trick()
end

local function land()
  air, jump_h, jump_v = false, 0, 0
  if trick and trick.t < trick.dur - 3 then
    crash("BRUCHLANDUNG!")
    return
  end
  trick = nil
  if #tricks_done > 0 then
    local sum, names = 0, {}
    for _, k in ipairs(tricks_done) do
      sum = sum + TRICKS[k].pts
      names[#names + 1] = TRICKS[k].label
    end
    local pts = sum * #tricks_done
    score = score + pts
    tricks_total = tricks_total + #tricks_done
    boost = 50 + 30 * #tricks_done
    popup(table.concat(names, " + ") .. "  +" .. pts, C.yellow, #tricks_done > 2 and 1 or 2, 90)
    SFX.land()
    tricks_done = {}
  else
    spark(HW, H - 8, 6, C.white)
  end
end

local function check_collisions(pz)
  local low = jump_h < 14
  for _, c in ipairs(cars) do
    local dz = (c.z - pz) % L
    if dz > L / 2 then dz = dz - L end
    local dx = math.abs(c.x - player_x)
    if crash_t == 0 and ghost == 0 and low and dz > -SEG * 0.3 and dz < SEG * 0.5 and dx < c.hw + 0.1 then
      crash(c.name == "bus" and "BUS!" or "AUTSCH!")
      SFX.honk()
      return
    end
    local ahead = dz > 0
    if c.ahead and not ahead and dz > -SEG * 2 and crash_t == 0 then
      if not low and dx < c.hw + 0.12 then
        score = score + 300
        popup("DRÜBER! +300", C.green, 2, 60)
      elseif dx < c.hw + 0.38 and speed > MAXSPEED * 0.5 then
        score = score + 100
        near_misses = near_misses + 1
        boost = max(boost, 20)
        gap = gap + 1
        popup("KNAPP! +100", C.orange, 2, 40)
        SFX.near()
      end
    end
    c.ahead = ahead
  end
  -- Pylonen, Laternen, Bäume, Ladesäulen
  if low and crash_t == 0 and ghost == 0 then
    local seg = seg_of(pz)
    for i, s in ipairs(seg.sprites) do
      if s.solid and math.abs(s.x - player_x) < s.w + 0.1 then
        if s.name == "cone" then
          table.remove(seg.sprites, i)   -- weggekickt
          crash("PYLONE!")
        else
          crash("AUTSCH!")
          player_x = sgn(player_x) * 1.0
        end
        return
      end
    end
  end
end

local function update_race()
  race_t = race_t + 1
  local pct = speed / MAXSPEED
  local pz = position + PLAYER_Z
  local pseg = seg_of(pz)

  if ghost > 0 then ghost = ghost - 1 end
  if crash_t > 0 then
    crash_t = crash_t - 1
    speed = max(0, speed - MAXSPEED / 50)
    if crash_t == 0 then
      player_x = mid(-0.9, player_x, 0.9)
      ghost = 60   -- kurz unverwundbar, damit man nicht sofort wieder hängen bleibt
    end
  elseif air then
    jump_h = jump_h + jump_v
    jump_v = jump_v - GRAV
    if trick then
      trick.t = trick.t + 1
      if trick.t >= trick.dur then
        tricks_done[#tricks_done + 1] = trick.kind
        trick = nil
      end
    elseif pressed(BTN_A) then start_trick("tailwhip")
    elseif pressed(BTN_B) then start_trick("nohand")
    elseif pressed(BTN_LEFT) then start_trick("spin", -1)
    elseif pressed(BTN_RIGHT) then start_trick("spin", 1)
    end
    if jump_h <= 0 then land() end
  else
    local limit = boost > 0 and BOOSTSPEED or MAXSPEED
    if battery <= 0 then limit = 0 end
    if boost > 0 then
      boost = boost - 1
      speed = speed + MAXSPEED / 40
    elseif btn(BTN_A) then
      speed = speed + MAXSPEED / 110
    elseif btn(BTN_B) then
      speed = speed - MAXSPEED / 35
    else
      speed = speed - MAXSPEED / 300
    end
    if speed > limit then speed = max(limit, speed - MAXSPEED / 60) end
    speed = max(0, speed)
    local dx = (0.3 + 0.7 * min(pct, 1)) * 0.032
    steer = 0
    if btn(BTN_LEFT) then player_x = player_x - dx steer = -1 end
    if btn(BTN_RIGHT) then player_x = player_x + dx steer = 1 end
    player_x = player_x - dx * pct * pseg.curve * CENTRIFUGAL
    if math.abs(player_x) > 1.05 then
      -- Gehweg: holprig und langsam
      if speed > MAXSPEED * 0.45 then speed = speed - MAXSPEED / 25 end
      if race_t % 4 == 0 and speed > 20 then spark(HW + rnd(30) - 15, H - 6, 1, C.dim) end
    end
    player_x = mid(-2.1, player_x, 2.1)
    -- Rampe
    if pseg.ramp and math.abs(pseg.ramp - player_x) < 0.24 and pct > 0.25 then
      air = true
      jump_h, jump_v = 1, 2.4 + pct * 3.4
      tricks_done = {}
      SFX.jump()
      popup("TRICKS: A / B / < >", C.white, 1, 50)
    end
  end

  check_collisions(position + PLAYER_Z)
  position = (position + speed) % L
  distance = distance + speed
  sky_off = sky_off + pseg.curve * pct * 0.6

  update_cars()

  -- Akku
  if battery > 0 then
    battery = battery - 1
    if battery <= 600 and battery % 60 == 0 and battery > 0 then SFX.tick() end
    if battery == 0 then
      popup("AKKU LEER!", C.red, 3, 120)
      reason = "Akku leer."
    end
  end
  -- Ladestation
  if distance / SEG >= next_check then
    next_check = next_check + CHECK_EVERY
    checks = checks + 1
    local bonus = max(9, 16 - checks)
    battery = battery + bonus * 60
    score = score + 500
    popup("LADESTATION +" .. bonus .. " s", C.green, 2, 90)
    SFX.check()
    if checks % 2 == 0 then
      -- mehr Verkehr
      for _ = 1, 4 do
        local kind = CAR_KINDS[1 + flr(rnd(#CAR_KINDS))]
        local lane = LANES[1 + flr(rnd(3))]
        cars[#cars + 1] = {z = (position + SEG * (60 + rnd(300))) % L, x = lane, tx = lane, name = kind.name,
          hw = kind.hw, speed = MAXSPEED * (kind.bus and 0.25 or (0.28 + rnd(0.32))), ahead = true, blink = 0}
      end
    end
  end
  -- Polizei
  local pol = MAXSPEED * (0.74 + min(0.18, race_t / (60 * 300)))
  gap = min(120, gap + (speed - pol) * 0.0015)
  score = score + flr(speed * M_PER_UNIT * 5 + 0.5) // 1
  if gap <= 0 then
    gap = 0
    state, t = "caught", 0
    reason = reason or (crash_t > 0 and "Nach einem Sturz eingeholt." or "Zu langsam.")
    stoptune(7)
    SFX.caught()
    local km = distance * M_PER_UNIT / 1000
    if score > (save.best or 0) then save.best = score save.new_best = true else save.new_best = false end
    if km > (save.km or 0) then save.km = km end
    savedata({best = save.best, km = save.km})
  end
  -- Motorgeräusch und Sirene
  if race_t % 3 == 0 and speed > 5 then tone(180 + pct * 900, 0.06, "triangle", 0.07 + pct * 0.05, 5) end
  if gap < 50 and race_t % 30 == 0 then
    tone((race_t // 30) % 2 == 0 and note("A5") or note("E5"), 0.28, "saw", 0.06 + (50 - gap) / 50 * 0.12, 4)
  end
end

-- ---------- Zeichnen ----------

local skyline = {}
local function build_skyline()
  skyline = {}
  local x = 0
  while x < 640 do
    local w = 14 + flr(rnd(28))
    local b = {x = x, w = w, h = 12 + flr(rnd(42)), c = rnd(1) < 0.5 and C.city1 or C.city2, win = {}}
    for _ = 1, flr(rnd(4)) do
      b.win[#b.win + 1] = {3 + flr(rnd(w - 6)), 4 + flr(rnd(b.h - 6))}
    end
    skyline[#skyline + 1] = b
    x = x + w + flr(rnd(3))
  end
end

local function draw_sky()
  local band = 124 // #C.sky
  for i, col in ipairs(C.sky) do
    rectfill(0, (i - 1) * band, W - 1, i * band + 1, col)
  end
  circfill(HW + 60, HH - 8, 22, rgb(255, 226, 150))
  local base = HH + 6
  for _, b in ipairs(skyline) do
    local bx = flr((b.x - sky_off) % 640)
    for pass = 1, 2 do
      local x0 = pass == 1 and bx or bx - 640
      if x0 < W and x0 + b.w > 0 then
        rectfill(x0, base - b.h, x0 + b.w - 1, base, b.c)
        for _, w in ipairs(b.win) do
          rectfill(x0 + w[1], base - b.h + w[2], x0 + w[1] + 1, base - b.h + w[2] + 1, C.window)
        end
      end
    end
  end
end

local function project(p, camx, camy, camz)
  local z = p.z - camz
  p.cz = z
  if z < 1 then z = 1 end
  local sc = DEPTH / z
  p.scale = sc
  p.sx = HW + sc * (-camx) * HW
  p.sy = HH - sc * (p.y - camy) * HH
  p.sw = sc * ROAD_W * HW
end

local function draw_segment(seg, maxy)
  local p1, p2 = seg.p1, seg.p2
  local x1, y1, w1 = p1.sx, p1.sy, p1.sw
  local x2, y2, w2 = p2.sx, p2.sy, p2.sw
  local ytop = max(flr(y2), 0)
  local ybot = flr(min(y1, maxy - 1, H - 1))
  if ybot < ytop then return end
  local alt = seg.color == 1
  rectfill(0, ytop, W - 1, ybot, alt and C.ground1 or C.ground2)
  local walk = alt and C.walk1 or C.walk2
  local curb = alt and C.curb1 or C.curb2
  local road = seg.check and C.check or (alt and C.road1 or C.road2)
  local lanes = seg.lanes and not seg.check
  local dy = y1 - y2
  for y = ytop, ybot do
    local f = (y1 - y) / dy
    local x = x1 + (x2 - x1) * f
    local w = w1 + (w2 - w1) * f
    rectfill(x - w * 1.34, y, x + w * 1.34, y, walk)
    rectfill(x - w * 1.07, y, x + w * 1.07, y, curb)
    rectfill(x - w, y, x + w, y, road)
    if lanes then
      local lw = w * 0.022 + 0.5
      local a, b = x - w / 3, x + w / 3
      rectfill(a - lw, y, a + lw, y, C.lane)
      rectfill(b - lw, y, b + lw, y, C.lane)
    end
  end
end

local function draw_scaled(name, cx, by, f, flip)
  local r = RECTS[name]
  local dw, dh = r[3] * f, r[4] * f
  if dw < 1 or dw > 900 then return end
  sspr(IMG, r[1], r[2], r[3], r[4], flr(cx - dw / 2), flr(by - dh), flr(dw + 0.5), flr(dh + 0.5), flip)
end

local function draw_banner(seg)
  local p = seg.p1
  local sc = p.scale
  local xl = p.sx - sc * 1.2 * ROAD_W * HW
  local xr = p.sx + sc * 1.2 * ROAD_W * HW
  local f = sc * K * HW
  local top = p.sy - 28 * f
  local bh = max(2, 12 * f)
  rectfill(xl, top - bh, xr, top, C.green)
  rectfill(xl, top - bh, xr, top - bh + max(1, f), C.black)
  if xr - xl > 110 and bh > 9 then
    local text = "LADESTATION"
    local s = (xr - xl > 260 and bh > 18) and 2 or 1
    print(text, flr((xl + xr - textw(text, s)) / 2), flr(top - bh / 2 - 4 * s), C.black, s)
  end
end

local function render()
  local base = seg_of(position)
  local bi = base.index
  local base_pct = (position % SEG) / SEG
  local pz = position + PLAYER_Z
  local pseg = seg_of(pz)
  local ppct = (pz % SEG) / SEG
  player_y = pseg.p1.y + (pseg.p2.y - pseg.p1.y) * ppct

  draw_sky()

  local maxy = H
  local x, dx = 0, -(base.curve * base_pct)
  local camx, camy = player_x * ROAD_W, player_y + CAM_H
  for n = 0, DRAW - 1 do
    local seg = segments[(bi + n) % N + 1]
    local camz = position - (seg.index < bi and L or 0)
    project(seg.p1, camx - x, camy, camz)
    project(seg.p2, camx - x - dx, camy, camz)
    x = x + dx
    dx = dx + seg.curve
    seg.clip = maxy
    vis[n] = seg
    if seg.p1.cz > DEPTH and seg.p2.sy < seg.p1.sy and seg.p2.sy < maxy then
      draw_segment(seg, maxy)
      maxy = seg.p2.sy
    end
  end

  -- Autos den Segmenten zuordnen
  for n = 0, DRAW - 1 do bcount[n] = 0 end
  for _, c in ipairs(cars) do
    local n = (flr(c.z / SEG) - bi) % N
    if n < DRAW then
      bcount[n] = bcount[n] + 1
      bucket[n][bcount[n]] = c
    end
  end

  -- Sprites von hinten nach vorne
  for n = DRAW - 1, 1, -1 do
    local seg = vis[n]
    if seg.p1.cz > DEPTH and seg.clip > 0 then
      clip(0, 0, W, flr(seg.clip))
      local p1, p2 = seg.p1, seg.p2
      local f = p1.scale * K * HW
      for _, s in ipairs(seg.sprites) do
        draw_scaled(s.name, p1.sx + p1.scale * s.x * ROAD_W * HW, p1.sy, f, s.flip)
      end
      if seg.check then draw_banner(seg) end
      for i = 1, bcount[n] do
        local c = bucket[n][i]
        local pc = (c.z % SEG) / SEG
        local sc = p1.scale + (p2.scale - p1.scale) * pc
        local cx = p1.sx + (p2.sx - p1.sx) * pc + sc * c.x * ROAD_W * HW
        local cy = p1.sy + (p2.sy - p1.sy) * pc
        local cf = sc * K * HW
        draw_scaled(c.name, cx, cy, cf, false)
        if c.x ~= c.tx and (c.blink // 10) % 2 == 0 then
          -- Blinker
          local r = RECTS[c.name]
          local bx = cx + (c.tx > c.x and 1 or -1) * (r[3] / 2 - 2) * cf
          local s = max(1, 2 * cf)
          rectfill(bx - s, cy - 9 * cf, bx + s, cy - 9 * cf + s, C.orange)
        end
      end
      clip()
    end
  end
end

local function draw_player()
  local by = H - 4
  local x = HW
  if math.abs(player_x) > 1.05 and not air and speed > 10 then by = by + flr(rnd(2)) end
  if crash_t > 0 then
    local ct = 60 - crash_t
    local hy = ct < 30 and flr(math.sin(ct / 30 * math.pi) * 40) or 0
    draw_scaled("deck_side", x + 30, by, 2, false)
    local r = RECTS.rider
    sspr(IMG, r[1], r[2], r[3], r[4], x - 40, by - 44 - hy + (ct >= 30 and 26 or 0), 60, 44, (ct // 6) % 2 == 0, ct < 30 and (ct // 8) % 2 == 1)
    return
  end
  if ghost > 0 and (ghost // 4) % 2 == 0 then return end
  -- Schatten
  local sw = air and max(10, 26 - jump_h / 3) or 26
  rectfill(x - sw, by - 3, x + sw, by, C.shadow)
  local y = by - flr(jump_h)
  local rider = steer < 0 and "rider_l" or steer > 0 and "rider_r" or "rider"
  local deck, dflip, wscale = "deck", false, 1
  if boost > 0 and not air then
    for i = 1, 3 do
      rectfill(x - 6 + rnd(12), y - 2, x - 4 + rnd(8), y + 2 + rnd(6), (race_t + i) % 2 == 0 and C.orange or C.yellow)
    end
  end
  if trick then
    local p = trick.t / trick.dur
    if trick.kind == "tailwhip" then
      local ph = flr(p * 4) % 4
      if ph == 1 or ph == 3 then deck, dflip = "deck_side", ph == 3 end
    elseif trick.kind == "nohand" then
      rider = "rider_nohand"
    elseif trick.kind == "spin" then
      local c = math.cos(p * math.pi * 2)
      wscale = max(0.2, math.abs(c))
      if c < 0 then rider = "rider_front" end
    end
  end
  local rr = RECTS[rider]
  local rw = flr(rr[3] * 2 * wscale)
  sspr(IMG, rr[1], rr[2], rr[3], rr[4], x - rw // 2, y - 16 - rr[4] * 2, rw, rr[4] * 2)
  local dr = RECTS[deck]
  local dw = flr(dr[3] * 2 * (deck == "deck" and wscale or 1))
  sspr(IMG, dr[1], dr[2], dr[3], dr[4], x - dw // 2, y - dr[4] * 2, dw, dr[4] * 2, dflip)
end

local function draw_police()
  -- Streifenwagen im Rücken, taucht unten auf, wenn er nah ist
  if gap < 50 and (t // 10) % 2 == 0 then
    local col = (t // 20) % 2 == 0 and C.red or C.blue
    rectfill(0, 30, 3, H - 1, col)
    rectfill(W - 4, 30, W - 1, H - 1, col == C.red and C.blue or C.red)
  end
  if gap < 22 then
    local k = 1 - gap / 22
    local name = (t // 8) % 2 == 0 and "police1" or "police2"
    draw_scaled(name, HW + 70 - k * 40, H + 50 - k * 44, 3.2, false)
  end
end

local function shadow_print(text, x, y, c, s)
  print(text, x + 1, y + 1, C.black, s)
  print(text, x, y, c, s)
end

local function center(text, y, c, s)
  shadow_print(text, (W - textw(text, s)) // 2, y, c, s)
end

local function draw_hud()
  -- Akku
  local secs = ceil(battery / 60)
  local col = battery > 600 and C.green or battery > 300 and C.yellow or C.red
  rect(6, 6, 30, 16, C.white)
  rectfill(31, 9, 32, 13, C.white)
  local fillw = flr(22 * min(1, battery / (35 * 60)))
  if fillw > 0 then rectfill(8, 8, 8 + fillw - 1, 14, col) end
  shadow_print(secs .. " s", 38, 8, battery > 300 and C.white or C.red)
  -- Polizei
  local pw = 64
  local px = W - pw - 8
  shadow_print("POLIZEI", px, 4, C.dim)
  rect(px, 14, px + pw, 20, C.white)
  local g = flr(pw * min(1, gap / 120))
  if g > 1 then rectfill(px + 1, 15, px + g - 1, 19, gap < 25 and C.red or C.blue) end
  shadow_print(flr(gap) .. " m", px - 34, 13, gap < 25 and C.red or C.white)
  -- Punkte
  center(tostring(score), 6, C.yellow, 1)
  -- Tempo
  local kmh = flr(speed / MAXSPEED * KMH)
  shadow_print(tostring(kmh), 8, H - 30, boost > 0 and C.orange or C.white, 3)
  shadow_print("km/h", 12 + textw(tostring(kmh), 3), H - 16, C.dim)
  local km = distance * M_PER_UNIT / 1000
  local kt = string.format("%.1f km", km)
  shadow_print(kt, W - textw(kt) - 8, H - 14, C.white)
  -- Meldungen
  local y = 44
  for i = #popups, 1, -1 do
    local p = popups[i]
    local s = p.scale
    if textw(p.text, s) > W - 8 then s = 1 end
    center(p.text, y, p.c, s)
    y = y + 10 * s + 4
  end
end

local function draw_sparks()
  for i = #sparks, 1, -1 do
    local s = sparks[i]
    rectfill(s.x, s.y, s.x + 1, s.y + 1, s.c)
  end
end

local function speed_lines()
  if boost > 0 or speed > MAXSPEED * 0.95 then
    for _ = 1, 4 do
      local side = rnd(1) < 0.5 and rnd(60) or W - rnd(60)
      local y = 40 + rnd(H - 80)
      line(side, y, side + (side < HW and -14 or 14), y + 6, C.white)
    end
  end
end

-- ---------- Titel und Ende ----------

local function autopilot()
  speed = MAXSPEED * 0.75
  player_x = player_x * 0.9
  position = (position + speed) % L
  sky_off = sky_off + seg_of(position + PLAYER_Z).curve * 0.45
  update_cars()
end

local function draw_title()
  render()
  draw_player()
  local title = "ROLLER-ROWDY"
  local x = (W - textw(title, 3)) // 2
  for d = 1, 3 do print(title, x + d, 30 + d, C.black, 3) end
  print(title, x, 30, C.yellow, 3)
  center("Gedrosselt? Nö.", 60, C.white, 1)
  rectfill(30, 150, 289, 226, C.panel)
  rect(31, 151, 288, 225, C.orange)
  if (t // 30) % 2 == 0 then center("START oder A: los!", 158, C.yellow, 1) end
  center("A Gas  B Bremse  < > lenken", 176, C.white, 1)
  center("Rampe: A / B / < > für Tricks", 188, C.white, 1)
  center("Akku laden, Polizei abhängen", 200, C.dim, 1)
  if save.best then
    center(string.format("Rekord %d   Weiteste Fahrt %.1f km", save.best, save.km or 0), 213, C.orange, 1)
  end
end

local function draw_caught()
  render()
  draw_player()
  local k = min(1, t / 40)
  draw_scaled((t // 8) % 2 == 0 and "police1" or "police2", HW + 20, H + 40 - k * 60, 3.4, false)
  if (t // 10) % 2 == 0 then
    rectfill(0, 0, 5, H - 1, C.red)
    rectfill(W - 6, 0, W - 1, H - 1, C.blue)
  end
  if t < 30 then return end
  rectfill(30, 40, 289, 170, C.panel)
  rect(31, 41, 288, 169, C.red)
  center("ERWISCHT!", 50, C.red, 3)
  center(reason or "", 80, C.white, 1)
  center("Punkte " .. score, 98, C.yellow, 2)
  center(string.format("%.1f km  %d Tricks  %d x knapp", distance * M_PER_UNIT / 1000, tricks_total, near_misses), 122, C.white, 1)
  if save.new_best then center("Neuer Rekord!", 138, C.orange, 1)
  else center("Rekord " .. (save.best or 0), 138, C.dim, 1) end
  if t > 90 then center("A: nochmal   B: Titel", 154, C.white, 1) end
end

local function start_race()
  reset_race()
  state, t = "countdown", 0
  SFX.music()
  popup("DIE POLIZEI WILL DEINEN ROLLER SEHEN!", C.white, 1, 150)
end

local function to_title()
  reset_race()
  state, t = "title", 0
  stoptune()
end

-- ---------- Ablauf ----------

function _init()
  local d = loaddata() or {}
  save = {best = d.best, km = d.km}
  build_skyline()
  to_title()
end

-- Meldungen und Funken laufen hier weiter, nicht in _draw: Die Konsole lässt _draw aus, wenn sie nicht
-- hinterherkommt. Wie vorher nur, solange das Rennen zu sehen ist (nicht im Titel und beim Erwischtwerden).
local function update_effects()
  for i = #popups, 1, -1 do
    local p = popups[i]
    p.t = p.t - 1
    if p.t <= 0 then table.remove(popups, i) end
  end
  for i = #sparks, 1, -1 do
    local s = sparks[i]
    s.x, s.y, s.vy, s.t = s.x + s.vx, s.y + s.vy, s.vy + 0.3, s.t - 1
    if s.t <= 0 then table.remove(sparks, i) end
  end
end

local function update_state()
  t = t + 1
  prev_btn, cur_btn = cur_btn, btn()
  if state == "title" then
    autopilot()
    if btnp(BTN_START) or btnp(BTN_A) then start_race() end
  elseif state == "countdown" then
    update_cars()
    if t % 60 == 0 and t < 180 then tone(note("C5"), 0.15, "square", 0.3) end
    if t == 180 then
      tone(note("C6"), 0.3, "square", 0.3)
      popup("LOS!", C.green, 3, 50)
      state = "race"
    end
  elseif state == "race" then
    if btnp(BTN_START) then state = "pause" return end
    update_race()
  elseif state == "pause" then
    if btnp(BTN_START) then state = "race" end
  elseif state == "caught" then
    update_cars()
    speed = max(0, speed - MAXSPEED / 40)
    position = (position + speed) % L
    if t > 90 then
      if btnp(BTN_A) or btnp(BTN_START) then start_race()
      elseif btnp(BTN_B) then to_title() end
    end
  end
end

function _update()
  update_state()
  if state ~= "title" and state ~= "caught" then update_effects() end
end

function _draw()
  if state == "title" then
    draw_title()
    return
  end
  if state == "caught" then
    draw_caught()
    return
  end
  render()
  speed_lines()
  draw_player()
  draw_police()
  draw_sparks()
  draw_hud()
  if state == "countdown" then
    local n = 3 - t // 60
    if n > 0 then center(tostring(n), 104, C.yellow, 4) end
  elseif state == "pause" then
    rectfill(100, 96, 219, 140, C.panel)
    center("Pause", 104, C.yellow, 2)
    center("START: weiter", 126, C.white, 1)
  end
end
