-- Schnösel-Sprint: Fake-3D-Laufstrecke mit drei Spuren.
-- Links/rechts: Spur wechseln, A: springen, B: sprinten.

local S = require("sprites")
local IMG, RECTS = S.img, S.rects

local W, H = SCREEN_W, SCREEN_H
local HW = W / 2
local HORIZON = 73
local GROUND = 205
local MAX_Z = 1000
local FITNESS_GOAL = 6
local LANES = {-1, 0, 1}

local state = "title"
local lane_target, lane_x, jump_h, jump_v, jump_lock
local fitness, lives, score, bonus_score, best, distance, frame_count
local spawn_timer, spawn_count, objects
local invulnerable, monster_timer, sprint_energy, scenery, life_four_given, life_flash

local C = {
  sky = {rgb(36, 50, 73), rgb(54, 72, 91), rgb(92, 113, 119), rgb(166, 152, 127)},
  sun = rgb(250, 203, 133),
  skyline1 = rgb(45, 58, 66),
  skyline2 = rgb(63, 76, 79),
  window = rgb(229, 184, 114),
  grass1 = rgb(71, 96, 76),
  grass2 = rgb(89, 110, 82),
  curb1 = rgb(230, 205, 156),
  curb2 = rgb(151, 88, 77),
  road1 = rgb(72, 78, 84),
  road2 = rgb(60, 68, 75),
  lane = rgb(235, 218, 183),
  cream = rgb(246, 234, 205),
  gold = rgb(239, 193, 104),
  green = rgb(98, 203, 56),
  red = rgb(216, 86, 80),
  ink = rgb(25, 33, 39),
  shadow = rgb(33, 38, 41),
}

local function reset_run()
  lane_target, lane_x = 0, 0
  jump_h, jump_v, jump_lock = 0, 0, false
  fitness, lives, score, bonus_score = 0, 3, 0, 0
  distance, frame_count, scenery = 0, 0, 0
  spawn_timer, spawn_count, objects = 72, 0, {}
  invulnerable, monster_timer = 0, 0
  sprint_energy = 100
  life_four_given, life_flash = false, 0
end

function _init()
  local save = loaddata()
  best = save and (save.best or 0) or 0
  reset_run()
end

local function start_run()
  reset_run()
  state = "play"
  tone(note("C5"), 0.1, "triangle", 0.3)
end

local function finish_run(won)
  state = won and "win" or "over"
  if score > best then
    best = score
    savedata({best = best})
  end
  if won then
    tune("C5 E5 G5 C6:2", 170, "triangle", 0.32)
  else
    tone(note("C3"), 0.22, "triangle", 0.28)
  end
end

local function speed_now()
  local speed = 7.0 + min(2.1, distance / 9000)
  if monster_timer > 0 then speed = speed + 2.4 end
  if btn(BTN_B) and sprint_energy > 0 then speed = speed + 1.7 end
  return speed
end

local function add_object(kind)
  spawn_count = spawn_count + 1
  local lane = flr(rnd(3)) - 1
  -- Keep the first Hantel close to the middle so the controls are easy to learn.
  if spawn_count == 1 then lane = 0 end
  objects[#objects + 1] = {kind = kind, lane = lane, z = MAX_Z, resolved = false, passed = false}
end

local function player_sprite()
  if fitness >= FITNESS_GOAL then return "snoesel_fit" end
  if fitness >= 3 then return "snoesel_mid" end
  return "snoesel_fat"
end

function _update()
  if state == "title" then
    if btnp(BTN_START) or btnp(BTN_A) then start_run() end
    return
  elseif state == "over" or state == "win" then
    if btnp(BTN_START) or btnp(BTN_A) then start_run() end
    return
  end

  frame_count = frame_count + 1
  if btnp(BTN_LEFT) then lane_target = max(-1, lane_target - 1) end
  if btnp(BTN_RIGHT) then lane_target = min(1, lane_target + 1) end
  lane_x = lane_x + (lane_target - lane_x) * 0.22

  if btnp(BTN_A) and jump_h == 0 and not jump_lock then
    jump_v = 7.25
    jump_lock = true
    tone(note("C5"), 0.06, "square", 0.16)
  end
  if not btn(BTN_A) then jump_lock = false end
  if jump_h > 0 or jump_v > 0 then
    jump_h = jump_h + jump_v
    jump_v = jump_v - 0.34
    if jump_h < 0 then jump_h, jump_v = 0, 0 end
  end

  if invulnerable > 0 then invulnerable = invulnerable - 1 end
  if monster_timer > 0 then monster_timer = monster_timer - 1 end
  if life_flash > 0 then life_flash = life_flash - 1 end
  if btn(BTN_B) and sprint_energy > 0 then
    sprint_energy = max(0, sprint_energy - 1.25)
  else
    sprint_energy = min(100, sprint_energy + 0.38)
  end

  local speed = speed_now()
  distance = distance + speed
  scenery = scenery + speed
  score = flr(distance / 30) + bonus_score

  spawn_timer = spawn_timer - 1
  if spawn_timer <= 0 then
    local pattern = (spawn_count % 4) + 1
    if pattern == 1 then add_object("dumbbell")
    elseif pattern == 2 then add_object("snack")
    elseif pattern == 3 then add_object("monster")
    else add_object("water") end
    spawn_timer = max(66, 91 - flr(distance / 11000))
  end

  for i = #objects, 1, -1 do
    local o = objects[i]
    o.z = o.z - speed
    if o.z <= 75 and not o.resolved then
      o.resolved = true
      if abs(o.lane - lane_x) < 0.42 then
        if o.kind == "dumbbell" then
          fitness = min(FITNESS_GOAL, fitness + 1)
          bonus_score = bonus_score + 35
          o.collected = true
          tone(note("E5"), 0.09, "triangle", 0.25)
          if fitness >= 4 and not life_four_given then
            life_four_given = true
            lives = min(5, lives + 1)
            life_flash = 100
            tune("G4 C5 E5", 155, "triangle", 0.22)
          end
        elseif o.kind == "monster" then
          monster_timer = 155
          bonus_score = bonus_score + 15
          o.collected = true
          tune("G4 B4 D5", 185, "square", 0.15)
        elseif o.kind == "water" then
          sprint_energy = min(100, sprint_energy + 45)
          bonus_score = bonus_score + 10
          o.collected = true
          tone(note("G5"), 0.08, "triangle", 0.21)
        elseif jump_h < 22 and invulnerable == 0 then
          lives = lives - 1
          invulnerable = 65
          tone(note("C3"), 0.12, "noise", 0.25)
          if lives <= 0 then finish_run(false) end
        end
      elseif o.kind == "snack" then
        bonus_score = bonus_score + 8
      end
    end
    if o.z < -100 then table.remove(objects, i) end
  end

  score = flr(distance / 30) + bonus_score
  if fitness >= FITNESS_GOAL and state == "play" then finish_run(true) end
end

-- Fake-3D-Projektion: z=MAX_Z liegt am Horizont, z=0 direkt vor dem Läufer.
local function project(z)
  local p = mid(0, 1, 1 - z / MAX_Z)
  local y = HORIZON + p * (GROUND - HORIZON)
  local half = 19 + p * 130
  local scale = 0.4 + p * 1.65
  local center = HW + math.sin(distance / 2100) * (1 - p) * 38
  return p, y, half, scale, center
end

local function draw_sky()
  local band = 19
  for i, color in ipairs(C.sky) do
    rectfill(0, (i - 1) * band, W - 1, i * band + 1, color)
  end
  circfill(W - 76, 46, 13, C.sun)
  -- Eine kleine Stadtkante macht den Laufweg lesbar, ohne die Figur zu überdecken.
  local shift = flr(scenery / 72) % 12
  for i = -1, 10 do
    local x = i * 35 - shift
    local h1 = 15 + ((i * 17 + 80) % 31)
    local h2 = 16 + ((i * 11 + 31) % 25)
    rectfill(x, HORIZON - h1, x + 24, HORIZON, C.skyline1)
    rectfill(x + 19, HORIZON - h2, x + 41, HORIZON, C.skyline2)
    for wy = HORIZON - h1 + 5, HORIZON - 3, 8 do
      rectfill(x + 4, wy, x + 6, wy + 2, C.window)
      rectfill(x + 13, wy, x + 15, wy + 2, C.window)
    end
  end
  rectfill(133, HORIZON - 13, 187, HORIZON - 1, C.ink)
  print("GYM", 145, HORIZON - 10, C.gold)
end

local function draw_track()
  rectfill(0, HORIZON, W - 1, H - 1, C.grass1)
  local phase = flr(distance / 50)
  for y = HORIZON, H - 1, 2 do
    local p = mid(0, 1, (y - HORIZON) / (GROUND - HORIZON))
    local half = 19 + p * 130
    local center = HW + math.sin(distance / 2100) * (1 - p) * 38
    local outer = half + 10 + p * 7
    local grass = (flr((y - HORIZON) / 12) + phase) % 2 == 0 and C.grass1 or C.grass2
    rectfill(0, y, center - outer, y + 1, grass)
    rectfill(center + outer, y, W - 1, y + 1, grass)
    local curb = (flr((y - HORIZON) / 10) + phase) % 2 == 0 and C.curb1 or C.curb2
    rectfill(center - outer, y, center - half, y + 1, curb)
    rectfill(center + half, y, center + outer, y + 1, curb)
    local road = (flr((y - HORIZON) / 20) + phase) % 2 == 0 and C.road1 or C.road2
    rectfill(center - half, y, center + half, y + 1, road)
    local dash_period = max(5, 7 + flr(p * 10))
    if (flr((y - HORIZON) / dash_period) + phase) % 3 ~= 1 then
      local lw = 1 + flr(p * 2)
      local left = center - half / 3
      local right = center + half / 3
      rectfill(left - lw, y, left + lw, y + 1, C.lane)
      rectfill(right - lw, y, right + lw, y + 1, C.lane)
    end
  end
  -- Receding lamp posts provide scale cues at both sides of the road.
  for i = 0, 5 do
    local z = (i * 205 - (scenery % 205) + 205) % MAX_Z
    local p, y, half, f, center = project(z)
    if p > 0.035 then
      local pole_h = 39 * f
      local post_y = flr(y - pole_h)
      local post_w = max(1, flr(2 * f))
      for side = -1, 1, 2 do
        local x = flr(center + side * (half + 14 * f))
        rectfill(x - post_w, post_y, x + post_w, flr(y), C.ink)
        circfill(x, post_y, max(1, flr(3 * f)), C.gold)
      end
    end
  end
end

local function draw_scaled(name, cx, by, scale, flip)
  local r = RECTS[name]
  local dw, dh = r[3] * scale, r[4] * scale
  if dw < 1 or dw > 900 then return end
  sspr(IMG, r[1], r[2], r[3], r[4], flr(cx - dw / 2), flr(by - dh), flr(dw + 0.5), flr(dh + 0.5), flip)
end

local function lane_center(lane, half, center)
  return (center or HW) + lane * half * 0.62
end

local function draw_objects()
  table.sort(objects, function(a, b) return a.z > b.z end)
  for _, o in ipairs(objects) do
    if not o.collected and o.z <= MAX_Z + 70 and o.z >= -10 then
      local _, y, half, scale, center = project(o.z)
      local cx = lane_center(o.lane, half, center)
      local sprite = o.kind == "snack" and "burger" or o.kind == "dumbbell" and "dumbbell" or o.kind == "monster" and "monster_can" or "water"
      draw_scaled(sprite, cx, y, scale, false)
      if o.kind == "monster" and scale > 0.9 then
        print("M", flr(cx - 3), flr(y - 13 * scale), C.green)
      end
    end
  end
end

local function draw_character(name, cx, bottom, scale, flash)
  local r = RECTS[name]
  local width = r[3] * scale
  local shadow_w = max(8, 25 - jump_h * 0.18)
  rectfill(cx - shadow_w, GROUND, cx + shadow_w, GROUND + 3, C.shadow)
  if not flash or frame_count % 8 < 4 then
    draw_scaled(name, cx, bottom, scale, false)
  end
  return width
end

local function draw_player()
  local _, _, half, _, center = project(0)
  local cx = lane_center(lane_x, half, center)
  local name = player_sprite()
  local bottom = GROUND + 1 - jump_h
  local bob = jump_h == 0 and (frame_count % 10 < 5 and 0 or 2) or 0
  local width = draw_character(name, cx, bottom + bob, 2.05, invulnerable > 0)
  if monster_timer > 0 then
    draw_scaled("monster_can", cx + width * 0.34, bottom - 22, 1.8, false)
  end
end

local function draw_hud()
  rectfill(0, 0, W - 1, 34, C.ink)
  print("FITNESS", 8, 5, C.cream)
  for i = 1, FITNESS_GOAL do
    local x = 75 + (i - 1) * 19
    local col = i <= fitness and C.green or rgb(69, 79, 82)
    rectfill(x, 6, x + 13, 15, col)
    rect(x, 6, x + 13, 15, rgb(20, 26, 28))
  end
  print(tostring(fitness) .. "/" .. tostring(FITNESS_GOAL), 198, 5, C.cream)
  print("LEBEN " .. tostring(lives), 8, 21, C.cream)
  local lane_name = lane_target < 0 and "LINKS" or lane_target > 0 and "RECHTS" or "MITTE"
  print(lane_name, 91, 21, C.gold)
  print("BEST " .. tostring(best), 223, 21, C.cream)
  rectfill(8, 30, 62, 33, rgb(39, 48, 52))
  rectfill(8, 30, 8 + flr(54 * sprint_energy / 100), 33, C.green)
  if life_flash > 0 then print("+1 LEBEN!", 222, 37, C.green) end
  if monster_timer > 0 then print("M-TURBO", 258, 37, C.green) end
end

local function draw_world()
  draw_sky()
  draw_track()
  draw_objects()
  draw_player()
end

local function draw_title()
  draw_sky()
  draw_track()
  rectfill(19, 12, 301, 65, C.ink)
  rect(19, 12, 301, 65, C.green)
  print("SCHNÖSEL-SPRINT", 94, 23, C.cream)
  print("MONSTER ENERGY. PERSOL. GYM.", 48, 41, C.gold)
  print("VOM SCHNOESEL ZUM ATHLETEN", 52, 53, C.green)
  local _, _, half, _, center = project(0)
  draw_character("snoesel_fat", lane_center(0, half, center), GROUND + 1, 2.35, false)
  draw_scaled("monster_can", HW + 61, GROUND - 20, 2.0, false)
  rectfill(12, 216, 308, 239, C.ink)
  print("LEFT/RIGHT: SPUR   A: SPRINGEN", 51, 219, C.cream)
  print("B: SPRINTEN   /   START: LOS", 48, 230, C.green)
end

local function draw_end(won)
  draw_sky()
  draw_track()
  local _, _, half, _, center = project(0)
  draw_character(won and "snoesel_fit" or player_sprite(), lane_center(0, half, center), GROUND + 1, 2.05, false)
  rectfill(24, 22, 296, 87, C.ink)
  rect(24, 22, 296, 87, won and C.green or C.red)
  if won then
    print("FITNESSLEVEL: SCHNOESEL", 63, 34, C.cream)
    print("Persol sitzt. Er ist fit!", 75, 52, C.cream)
  else
    print("PUSTENPAUSE!", 102, 34, C.cream, 2)
    print("Ein Burger war schneller als du!", 40, 61, C.cream)
  end
  print("FITNESS " .. tostring(fitness) .. "/" .. tostring(FITNESS_GOAL) .. "   BEST " .. tostring(best), 78, 185, C.gold)
  print("A ODER START: NOCH EINE RUNDE", 63, 218, C.green)
end

function _draw()
  if state == "title" then
    draw_title()
    return
  elseif state == "over" or state == "win" then
    draw_end(state == "win")
    return
  end
  draw_world()
  draw_hud()
end
