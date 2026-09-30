-- Schnösel-Sprint: A springt, B gibt einen kurzen Sprint.
-- Sammle Hanteln, um deine Fitness zu steigern. Monster gibt Extra-Tempo.

local S = require("sprites")

local GROUND = 194
local PLAYER_X = 48
local PLAYER_SCALE = 1.5
local PLAYER_H = 42
local FITNESS_GOAL = 6
local state = "title"
local player_y, velocity, fitness, lives, score, bonus_score, best, frame_count
local invulnerable, monster_timer, sprint_energy, jump_lock
local objects, spawn_timer, distance, scenery, spawn_count, life_four_given, life_flash

local C = {
  sky = rgb(33, 47, 56),
  sky_light = rgb(54, 74, 79),
  window = rgb(79, 112, 111),
  window_light = rgb(122, 159, 149),
  wall = rgb(83, 84, 80),
  wall_light = rgb(112, 106, 94),
  floor = rgb(50, 58, 57),
  floor_light = rgb(76, 84, 77),
  track = rgb(32, 38, 40),
  cream = rgb(243, 231, 205),
  gold = rgb(236, 189, 83),
  green = rgb(98, 203, 56),
  red = rgb(216, 86, 80),
  shadow = rgb(25, 29, 31),
}

local function restart()
  player_y = GROUND - PLAYER_H
  velocity = 0
  fitness = 0
  lives = 3
  score = 0
  bonus_score = 0
  frame_count = 0
  invulnerable = 0
  monster_timer = 0
  sprint_energy = 100
  jump_lock = false
  life_four_given = false
  life_flash = 0
  objects = {}
  spawn_timer = 75
  spawn_count = 0
  distance = 0
  scenery = 0
end

function _init()
  local save = loaddata()
  best = save and (save.best or 0) or 0
  restart()
end

local function start_run()
  restart()
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

local function spawn_object(kind)
  objects[#objects + 1] = {
    kind = kind,
    x = SCREEN_W + 12,
    y = GROUND - (kind == "water" and 24 or kind == "monster" and 22 or kind == "dumbbell" and 25 or 15),
    w = kind == "snack" and 22 or kind == "dumbbell" and 20 or 16,
    h = kind == "snack" and 16 or kind == "dumbbell" and 16 or 15,
  }
end

local function player_sprite()
  if fitness >= 6 then return "snoesel_fit"
  elseif fitness >= 3 then return "snoesel_mid"
  else return "snoesel_fat" end
end

local function speed_now()
  local speed = 3.0 + min(1.35, distance / 6000)
  if monster_timer > 0 then speed = speed + 1.55 end
  if btn(BTN_B) and sprint_energy > 0 then speed = speed + 1.25 end
  return speed
end

function _update()
  if state == "title" then
    if btnp(BTN_START) or btnp(BTN_A) then start_run() end
    return
  end
  if state == "over" or state == "win" then
    if btnp(BTN_START) or btnp(BTN_A) then start_run() end
    return
  end

  frame_count = frame_count + 1
  distance = distance + speed_now()
  score = flr(distance / 10) + bonus_score
  scenery = scenery + speed_now()

  if invulnerable > 0 then invulnerable = invulnerable - 1 end
  if monster_timer > 0 then monster_timer = monster_timer - 1 end
  if life_flash > 0 then life_flash = life_flash - 1 end
  if btn(BTN_B) and sprint_energy > 0 then
    sprint_energy = max(0, sprint_energy - 1.4)
  else
    sprint_energy = min(100, sprint_energy + 0.42)
  end

  if btnp(BTN_A) and player_y >= GROUND - PLAYER_H - 1 and not jump_lock then
    velocity = -7.15
    jump_lock = true
    tone(note("C5"), 0.06, "square", 0.16)
  end
  if not btn(BTN_A) then jump_lock = false end
  player_y = player_y + velocity
  velocity = velocity + 0.34
  if player_y > GROUND - PLAYER_H then
    player_y = GROUND - PLAYER_H
    velocity = 0
  end

  spawn_timer = spawn_timer - 1
  if spawn_timer <= 0 then
    -- Ein übersichtlicher Rhythmus: Hantel, Hindernis, dann Getränk oder Trinkflasche.
    spawn_count = spawn_count + 1
    if spawn_count % 4 == 1 then spawn_object("dumbbell")
    elseif spawn_count % 4 == 2 then spawn_object("snack")
    elseif spawn_count % 4 == 3 then spawn_object("monster")
    else spawn_object("water") end
    spawn_timer = max(64, 92 - flr(distance / 900))
  end

  local speed = speed_now()
  for i = #objects, 1, -1 do
    local o = objects[i]
    o.x = o.x - speed
        local player_w = S.size(player_sprite())
        player_w = flr(player_w * PLAYER_SCALE)
        local px0, px1 = PLAYER_X + 8, PLAYER_X + player_w - 6
        local py0, py1 = player_y + 12, player_y + PLAYER_H - 3
    local hit = px1 > o.x + 2 and px0 < o.x + o.w - 2 and py1 > o.y + 2 and py0 < o.y + o.h - 2
    if hit then
      if o.kind == "dumbbell" then
        fitness = min(FITNESS_GOAL, fitness + 1)
        bonus_score = bonus_score + 35
        tone(note("E5"), 0.09, "triangle", 0.26)
        if fitness >= 4 and not life_four_given then
          life_four_given = true
          lives = min(5, lives + 1)
          life_flash = 100
          tune("G4 C5 E5", 155, "triangle", 0.22)
        end
        table.remove(objects, i)
      elseif o.kind == "monster" then
        monster_timer = 155
        bonus_score = bonus_score + 15
        tune("G4 B4 D5", 185, "square", 0.15)
        table.remove(objects, i)
      elseif o.kind == "water" then
        sprint_energy = min(100, sprint_energy + 45)
        bonus_score = bonus_score + 10
        tone(note("G5"), 0.08, "triangle", 0.21)
        table.remove(objects, i)
      elseif invulnerable == 0 then
        lives = lives - 1
        invulnerable = 65
        tone(note("C3"), 0.12, "noise", 0.25)
        table.remove(objects, i)
        if lives <= 0 then finish_run(false) end
      end
    elseif o.x + o.w < PLAYER_X and not o.passed then
      o.passed = true
      if o.kind == "snack" then bonus_score = bonus_score + 8 end
    end
    if o.x < -30 then table.remove(objects, i) end
  end

  if fitness >= FITNESS_GOAL and state == "play" then finish_run(true) end
end

local function draw_background()
  cls(C.sky)
  -- Fenster und Geräte im Studio verschieben sich langsam nach links.
  rectfill(0, 42, SCREEN_W - 1, GROUND - 1, C.wall)
  rectfill(0, 42, SCREEN_W - 1, 45, C.wall_light)
  rectfill(101, 52, 220, 65, rgb(40, 51, 53))
  print("FITNESS CLUB", 117, 55, C.gold)
  local offset = flr(scenery / 2) % 96
  for x = -offset - 72, SCREEN_W, 96 do
    rectfill(x, 76, x + 55, 112, C.window)
    rect(x, 76, x + 55, 112, C.sky_light)
    rectfill(x + 4, 80, x + 50, 108, C.window_light)
    line(x + 27, 80, x + 27, 108, C.sky_light)
    line(x + 4, 94, x + 50, 94, C.sky_light)
  end
  -- Laufbandspur und helle Markierungen geben eine klare Laufrichtung.
  rectfill(0, GROUND, SCREEN_W - 1, SCREEN_H - 1, C.floor)
  rectfill(0, GROUND, SCREEN_W - 1, GROUND + 5, C.floor_light)
  rectfill(0, GROUND + 13, SCREEN_W - 1, SCREEN_H - 20, C.track)
  local stripe = flr(scenery) % 62
  for x = -stripe, SCREEN_W, 62 do
    rectfill(x, GROUND + 20, x + 24, GROUND + 22, C.floor_light)
  end
  rectfill(0, SCREEN_H - 19, SCREEN_W - 1, SCREEN_H - 1, C.sky)
end

local function draw_hud()
  rectfill(0, 0, SCREEN_W - 1, 35, rgb(25, 34, 38))
  print("FITNESS", 9, 5, C.cream)
  for i = 1, FITNESS_GOAL do
    local col = i <= fitness and C.green or rgb(65, 75, 73)
    rectfill(76 + (i - 1) * 20, 6, 89 + (i - 1) * 20, 15, col)
    rect(76 + (i - 1) * 20, 6, 89 + (i - 1) * 20, 15, rgb(20, 26, 28))
  end
  print(tostring(fitness) .. "/" .. tostring(FITNESS_GOAL), 244, 5, C.cream)
  print("LEBEN " .. tostring(lives), 10, 21, C.cream)
  print("M " .. tostring(flr(distance / 100)), 103, 21, C.gold)
  print("BEST " .. tostring(best), 210, 21, C.cream)
  if life_flash > 0 then print("+1 LEBEN!", 227, 37, C.green) end
end

local function draw_player()
  local name = player_sprite()
  local w, h = S.size(name)
  local bob = player_y >= GROUND - PLAYER_H and (frame_count % 12 < 6 and 0 or 1) or 0
  local draw_w, draw_h = flr(w * PLAYER_SCALE), flr(h * PLAYER_SCALE)
  rectfill(PLAYER_X + 8, GROUND - 1, PLAYER_X + draw_w - 8, GROUND + 2, C.shadow)
  if invulnerable == 0 or frame_count % 8 < 4 then
    local r = S.rects[name]
    sspr(S.img, r[1], r[2], r[3], r[4], PLAYER_X, flr(player_y) + bob, draw_w, draw_h)
  end
  -- Die schwarze Dose sitzt sichtbar in seiner Hand, solange der Monster-Schub läuft.
  if monster_timer > 0 then S.draw("monster_can", PLAYER_X + draw_w - 2, flr(player_y) + 22) end
end

local function draw_objects()
  for _, o in ipairs(objects) do
    if o.kind == "dumbbell" then
      S.draw("dumbbell", flr(o.x), flr(o.y))
    elseif o.kind == "snack" then
      S.draw("burger", flr(o.x), flr(o.y))
    elseif o.kind == "monster" then
      S.draw("monster_can", flr(o.x), flr(o.y))
      print("M", flr(o.x) + 5, flr(o.y) + 5, C.green, 1)
    else
      S.draw("water", flr(o.x), flr(o.y))
    end
  end
end

local function draw_title()
  draw_background()
  rectfill(19, 24, 301, 97, rgb(25, 34, 38))
  rect(19, 24, 301, 97, C.green)
  print("SCHNÖSEL-SPRINT", 100, 37, C.cream)
  print("Monster Energy. Hantel. Los!", 48, 57, C.cream)
  local r = S.rects.snoesel_fat
  sspr(S.img, r[1], r[2], r[3], r[4], 118, 108, flr(r[3] * PLAYER_SCALE), flr(r[4] * PLAYER_SCALE))
  S.draw("monster_can", 180, 137)
  print("A: SPRINGEN   B: SPRINTEN", 70, 177, C.cream)
  print("HANTELN SAMMELN / BURGER AUSWEICHEN", 17, 190, C.gold)
  print("START ODER A DRÜCKEN", 81, 218, C.green)
end

local function draw_end(won)
  draw_background()
  draw_objects()
  local name = won and "snoesel_fit" or player_sprite()
  local r = S.rects[name]
  sspr(S.img, r[1], r[2], r[3], r[4], 129, 111, flr(r[3] * PLAYER_SCALE), flr(r[4] * PLAYER_SCALE))
  rectfill(24, 24, 296, 89, rgb(25, 34, 38))
  rect(24, 24, 296, 89, won and C.green or C.red)
  if won then
    print("FITNESSLEVEL: SCHNOESEL", 63, 36, C.cream)
    print("Persol sitzt. Er ist fit!", 75, 54, C.cream)
  else
    print("PUSTENPAUSE!", 102, 38, C.cream, 2)
    print("Ein Burger war schneller als du!", 40, 64, C.cream)
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
  draw_background()
  draw_objects()
  draw_player()
  draw_hud()
  if monster_timer > 0 then
    rectfill(239, 211, 307, 228, rgb(25, 34, 38))
    print("M-TURBO", 247, 216, C.green)
  elseif btn(BTN_B) and sprint_energy > 0 then
    rectfill(244, 211, 308, 228, rgb(25, 34, 38))
    print("SPRINT", 255, 216, C.gold)
  end
end
