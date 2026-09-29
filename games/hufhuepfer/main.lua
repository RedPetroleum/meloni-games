-- Huf-Hüpfer: ein kleines Pferde-Jump-and-Run für die Meloni-API v1.
-- Hoch: springen, runter: unter Ästen durchrutschen, A: Bretterwände kaputt treten, START: Pause.
-- Sammle Möhren und Äpfel: Je drei Snacks geben ein zusätzliches Leben.

local S = require("sprites")

local GROUND = 193
local HORSE_X = 44
local HORSE_H = 25
local SLIDE_H = 13
local BRANCH_BOTTOM = GROUND - 18
local KICK_TIME = 26    -- Frames bis zum nächsten Tritt
local KICK_ACTIVE = 10  -- davon trifft der Tritt in den ersten Frames
local MAX_LIVES = 5
local state = "title"
local horse_y, velocity, sliding, kick_timer, jump_buffer, over_timer
local particles
local seen = {}
local hint_text, hint_timer = nil, 0
local obstacles, food
local spawn_timer, food_timer, air_food_timer, last_gap_short
local speed, play_frames, level, scroll
local score, best, lives, snacks, bonus_timer, invulnerable

local C = {
  sky_top = rgb(106, 164, 190),
  sky = rgb(174, 207, 208),
  sky_light = rgb(216, 226, 211),
  cloud = rgb(245, 235, 208),
  sun = rgb(239, 183, 111),
  far_hill = rgb(125, 160, 135),
  hill = rgb(89, 132, 104),
  field = rgb(83, 125, 76),
  field_light = rgb(133, 158, 88),
  grass = rgb(175, 177, 112),
  shadow = rgb(155, 158, 100),
  dirt = rgb(124, 91, 69),
  dirt_light = rgb(158, 119, 82),
  wood = rgb(106, 67, 53),
  wood_light = rgb(185, 125, 77),
  hay_light = rgb(241, 199, 119),
  mane = rgb(65, 49, 48),
  saddle = rgb(54, 99, 103),
  cream = rgb(248, 231, 187),
  panel = rgb(42, 57, 65),
  white = rgb(246, 238, 216),
  gold = rgb(241, 192, 103),
  green = rgb(168, 194, 124),
  red = rgb(213, 119, 94),
  leaf_dark = rgb(72, 108, 70),
}

-- Hindernisarten: h = Höhe am Boden, overhead = hängt von oben (drunter rutschen),
-- breakable = mit A kaputt treten. hint erscheint beim ersten Auftauchen.
-- dx, dy: where the sprite (same name as the kind) sits relative to x and the ground.
local KINDS = {
  fence = {w = 17, h = 27, dx = -1, dy = -27},
  hay = {w = 21, h = 18, dx = 0, dy = -18},
  puddle = {w = 31, h = 10, dx = 0, dy = -10},
  logs = {w = 24, h = 22, dx = 0, dy = -17},
  branch = {w = 30, overhead = true, dx = -4, dy = -48, hint = "RUNTER: DRUNTER RUTSCHEN!"},
  crate = {w = 18, h = 18, dx = 0, dy = -18},
  wall = {w = 16, h = 68, dx = -1, dy = -68, breakable = true, hint = "ZU HOCH! A: TRETEN!"},
}
local LOW = {fence = true, hay = true, crate = true}
local POOLS = {
  {"fence", "hay", "branch", "crate"},
  {"fence", "hay", "branch", "crate", "puddle", "wall"},
  {"fence", "hay", "branch", "crate", "puddle", "wall", "logs", "branch"},
}

-- Speed per level: level 1 as before, level 5 clearly faster, linear in between.
local LEVEL_SPEED = {}
for i = 1, 5 do LEVEL_SPEED[i] = 3.2 + (i - 1) * (8 - 3.2) / 4 end

local function reset()
  horse_y = GROUND - HORSE_H
  velocity = 0
  sliding = false
  kick_timer = 0
  jump_buffer = 0
  over_timer = 0
  particles = {}
  obstacles = {}
  food = nil
  spawn_timer = 68
  food_timer = 480
  air_food_timer = 0
  last_gap_short = false
  speed = LEVEL_SPEED[1]
  play_frames = 0
  scroll = 0
  level = 1
  score = 0
  lives = 3
  snacks = 0
  bonus_timer = 0
  invulnerable = 0
end

function _init()
  local save = loaddata()
  best = save and (save.best or 0) or 0
  reset()
end

local function start()
  reset()
  state = "play"
  tone(note("C5"), 0.08, "triangle", 0.3)
end

local function end_game()
  state = "over"
  over_timer = 45
  if score > best then
    best = score
    savedata({best = best})
    tune("C5 E5 G5:2", 170, "triangle", 0.3)
  else
    tone(note("C3"), 0.18, "triangle", 0.25)
  end
end

local function add_snack()
  snacks = snacks + 1
  score = score + 1
  tone(note("E5"), 0.08, "triangle", 0.25)
  if snacks >= 3 then
    snacks = 0
    if lives < MAX_LIVES then
      lives = lives + 1
      bonus_timer = 90
      tune("G4 B4 D5:1.5", 150, "triangle", 0.22)
    end
  end
end

local function make_obstacle(kind, x)
  -- New shapes enter gradually: puddles and walls at level 2, log piles at level 3.
  kind = kind or rnd(POOLS[min(level, #POOLS)])
  local k = KINDS[kind]
  local o = {
    x = x or SCREEN_W + 8,
    w = k.w,
    h = k.h or 0,
    kind = kind,
    overhead = k.overhead,
    breakable = k.breakable,
    passed = false,
  }
  obstacles[#obstacles + 1] = o
  if k.hint and not seen[kind] then
    seen[kind] = true
    hint_text = k.hint
    hint_timer = 150
  end
  return o
end

-- Frames until the next obstacle: sometimes two close together, sometimes a breather,
-- mostly something in between. The shortest gap still leaves time to land and jump again.
local function next_gap()
  local l = level - 1
  local r = rnd(1)
  if r < 0.3 and not last_gap_short then
    last_gap_short = true
    return 42 + rnd(8)
  end
  last_gap_short = false
  if r < 0.87 then
    return 48 - l * 2 + rnd(22 - l * 2)
  end
  return 80 - l * 4 + rnd(30)
end

-- A snack always needs a move: under a branch you have to slide, everywhere else it
-- floats too high to reach without jumping.
local function new_food(x, y)
  local kind = rnd(2) < 1 and "carrot" or "apple"
  local w, h = S.size(kind)
  food = {x = x, y = y, w = w, h = h, kind = kind}
end

-- Height for a snack in the air: how far the horse has to rise to touch it. A jump rises
-- about 73 pixels, so the high ones (most of them) only count near the top of the jump.
local function food_rise()
  if rnd(1) < 0.65 then return 56 + flr(rnd(15)) end
  return 30 + flr(rnd(26))
end

local function place_food(x, rise)
  new_food(x, 0)
  food.y = GROUND - HORSE_H - rise - food.h + 2
end

local function food_with(o)
  if o.breakable then return false end
  local w = S.size("carrot")
  if o.overhead then
    new_food(o.x + (o.w - w) // 2 + 2, GROUND - 17)
  else
    place_food(o.x + (o.w - w) // 2, food_rise())
  end
  return true
end

local function add_particle(x, y, vx, vy, c, life, size)
  if #particles >= 40 then return end
  particles[#particles + 1] = {x = x, y = y, vx = vx, vy = vy, c = c, life = life, size = size}
end

local function smash(o)
  local top = GROUND - o.h
  for i = 1, 12 do
    add_particle(o.x + rnd(o.w), top + rnd(o.h), rnd(4) - 1, -rnd(4) - 1,
      i % 3 == 0 and C.wood or C.wood_light, 30 + flr(rnd(20)), 2 + flr(rnd(2)))
  end
  score = score + 2
  tone(160, 0.14, "noise", 0.35)
  tone(note("G4"), 0.08, "square", 0.15)
end

-- START alone pauses; SELECT+START belongs to the console menu.
local function start_pressed()
  return btnp(BTN_START) and not btn(BTN_SELECT)
end

function _update()
  if state == "pause" then
    if start_pressed() or btnp(BTN_A) then
      state = "play"
      tone(note("E5"), 0.05, "triangle", 0.2)
    end
    return
  elseif state == "title" then
    if btnp(BTN_A) or btnp(BTN_START) then start() end
    return
  elseif state == "over" then
    -- Short pause, so kicking into the final crash doesn't restart right away.
    if over_timer > 0 then
      over_timer = over_timer - 1
    elseif btnp(BTN_A) or btnp(BTN_START) then
      start()
    end
    return
  end

  if start_pressed() then
    state = "pause"
    tone(note("C5"), 0.05, "triangle", 0.2)
    return
  end

  play_frames = play_frames + 1
  scroll = scroll + speed
  level = min(5, 1 + flr(play_frames / 600))
  -- Ease into the new level's speed over a few seconds instead of jumping.
  local target = LEVEL_SPEED[level]
  if speed < target then speed = min(target, speed + 0.004) end

  if invulnerable > 0 then invulnerable = invulnerable - 1 end
  if bonus_timer > 0 then bonus_timer = bonus_timer - 1 end
  if hint_timer > 0 then hint_timer = hint_timer - 1 end
  if kick_timer > 0 then kick_timer = kick_timer - 1 end

  -- Jump with UP only; a press shortly before landing still counts.
  if btnp(BTN_UP) then jump_buffer = 6 elseif jump_buffer > 0 then jump_buffer = jump_buffer - 1 end
  local on_ground = horse_y >= GROUND - HORSE_H
  if jump_buffer > 0 and on_ground then
    jump_buffer = 0
    velocity = -6.9
    on_ground = false
    tone(note("D5"), 0.06, "square", 0.18)
  end

  horse_y = horse_y + velocity
  velocity = velocity + 0.34
  -- DOWN in the air pulls the horse back to the ground faster.
  if not on_ground and btn(BTN_DOWN) and velocity > -2 then velocity = velocity + 0.5 end
  if horse_y >= GROUND - HORSE_H then
    horse_y = GROUND - HORSE_H
    velocity = 0
    on_ground = true
  end

  -- Slide while DOWN is held on the ground.
  local was_sliding = sliding
  sliding = on_ground and btn(BTN_DOWN)
  if sliding then
    kick_timer = 0
    if not was_sliding then tone(note("E3"), 0.12, "noise", 0.12) end
    if play_frames % 3 == 0 then
      add_particle(HORSE_X - 2, GROUND - 2, -speed * 0.5, -rnd(1), C.dirt_light, 14, 2)
    end
  elseif btnp(BTN_A) and kick_timer == 0 then
    kick_timer = KICK_TIME
    tone(note("A3"), 0.05, "noise", 0.12)
  end
  local kicking = kick_timer > KICK_TIME - KICK_ACTIVE

  local top = sliding and GROUND - SLIDE_H or horse_y
  local bottom = sliding and GROUND or horse_y + HORSE_H

  if not food and food_timer > 0 then food_timer = food_timer - 1 end
  spawn_timer = spawn_timer - 1
  if spawn_timer <= 0 then
    local o = make_obstacle()
    spawn_timer = next_gap()
    -- From level 2 on, low obstacles sometimes come as a pair for one long jump.
    if level >= 2 and LOW[o.kind] and rnd(1) < 0.3 then
      local kind = rnd({"fence", "hay", "crate"})
      local second = make_obstacle(kind, o.x + o.w + 14 + flr(rnd(10)))
      spawn_timer = spawn_timer + (second.x + second.w - o.x - o.w) / speed
    end
    if not food and food_timer <= 0 then
      -- Either with this obstacle or on its own in a long enough gap after it.
      if spawn_timer >= 80 and rnd(2) < 1 then
        air_food_timer = spawn_timer // 2
        food_timer = 480 + rnd(240)
      elseif food_with(o) then
        food_timer = 480 + rnd(240)
      end
    end
  end

  if air_food_timer > 0 then
    air_food_timer = air_food_timer - 1
    if air_food_timer == 0 then place_food(SCREEN_W + 8, food_rise()) end
  end

  if food then
    food.x = food.x - speed
    local overlaps_x = HORSE_X + 28 > food.x + 2 and HORSE_X + 2 < food.x + food.w - 2
    local overlaps_y = top < food.y + food.h - 2 and bottom > food.y + 2
    if overlaps_x and overlaps_y then
      add_snack()
      food = nil
    elseif food.x < -15 then
      food = nil
    end
  end

  for i = #obstacles, 1, -1 do
    local o = obstacles[i]
    o.x = o.x - speed
    if not o.passed and o.x + o.w < HORSE_X then
      o.passed = true
      score = score + 1
      if score % 5 == 0 then tone(note("E5"), 0.07, "triangle", 0.22) end
    end
    -- The kick reaches a bit in front of the nose.
    if kicking and o.breakable and not o.passed
        and HORSE_X + 48 > o.x and HORSE_X + 20 < o.x + o.w
        and horse_y + 4 < GROUND and horse_y + 22 > GROUND - o.h then
      smash(o)
      table.remove(obstacles, i)
    else
      local hit_x = HORSE_X + 26 > o.x and HORSE_X + 4 < o.x + o.w
      local hit_y
      if o.overhead then
        hit_y = top + 2 < BRANCH_BOTTOM
      else
        hit_y = bottom - 2 > GROUND - o.h
      end
      if hit_x and hit_y and invulnerable == 0 then
        lives = lives - 1
        invulnerable = 72
        tone(note("C3"), 0.12, "saw", 0.18)
        if lives <= 0 then end_game() end
      end
      if o.x < -50 then table.remove(obstacles, i) end
    end
  end

  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x = p.x + p.vx - speed * 0.3
    p.y = p.y + p.vy
    p.vy = p.vy + 0.25
    if p.y > GROUND then p.y = GROUND; p.vy = 0; p.vx = 0 end
    p.life = p.life - 1
    if p.life <= 0 then table.remove(particles, i) end
  end
end

local function draw_cloud(x, y)
  circfill(x, y + 4, 7, C.cloud)
  circfill(x + 8, y, 9, C.cloud)
  circfill(x + 18, y + 4, 7, C.cloud)
  rectfill(x - 1, y + 3, x + 19, y + 10, C.cloud)
  line(x + 2, y + 11, x + 17, y + 11, C.sky_light)
end

-- Flat oval on the grass, hw = half the width.
local function draw_shadow(cx, hw)
  rectfill(cx - hw + 4, GROUND + 1, cx + hw - 4, GROUND + 1, C.shadow)
  rectfill(cx - hw, GROUND + 2, cx + hw, GROUND + 3, C.shadow)
  rectfill(cx - hw + 3, GROUND + 4, cx + hw - 3, GROUND + 4, C.shadow)
end

-- Horse: sprite poses from sprites.txt; x, y is the top left of the standing horse.
-- The shadow stays on the ground and shrinks while the horse is in the air.
local function draw_horse(x, y, running, kicking, shadow)
  if shadow then
    draw_shadow(x + 14, 12 - flr((GROUND - HORSE_H - y) / 12))
  end
  if kicking then
    S.draw("horse_kick", x, y)
  elseif running and (play_frames // 4) % 2 == 1 then
    S.draw("horse_run2", x, y)
  else
    S.draw("horse_run1", x, y)
  end
end

-- Low, stretched-out horse sliding on its belly; y is the top, hooves at y + 12.
local function draw_horse_slide(x, y)
  draw_shadow(x + 12, 17)
  S.draw("horse_slide", x - 8, y - 1)
end

local function draw_obstacle(o)
  if o.kind == "branch" then
    -- The limb reaches up to the top, so the branch can't be jumped over.
    for i = 0, 3 do
      line(o.x + 34 + i, 34, o.x + 14 + i, BRANCH_BOTTOM - 26, i < 2 and C.wood or C.mane)
    end
    line(o.x + 30, 34, o.x + 44, 50, C.wood)
    circfill(o.x + 42, 52, 5, C.leaf_dark)
  end
  local k = KINDS[o.kind]
  S.draw(o.kind, o.x + k.dx, GROUND + k.dy)
end

local function draw_world(hide_horse)
  cls(C.sky)
  rectfill(0, 19, SCREEN_W - 1, 66, C.sky_top)
  rectfill(0, 67, SCREEN_W - 1, 111, C.sky)
  circfill(271, 57, 13, C.sun)
  circfill(267, 53, 3, C.hay_light)
  draw_cloud(34, 51)
  draw_cloud(168, 77)

  circfill(-8, 158, 48, C.far_hill)
  circfill(93, 166, 43, C.far_hill)
  circfill(221, 160, 49, C.far_hill)
  circfill(319, 165, 43, C.far_hill)
  circfill(41, 180, 33, C.hill)
  circfill(176, 178, 37, C.hill)
  circfill(292, 181, 32, C.hill)
  rectfill(0, 166, SCREEN_W - 1, GROUND - 1, C.field)
  rectfill(0, 182, SCREEN_W - 1, GROUND - 1, C.field_light)

  rectfill(0, GROUND, SCREEN_W - 1, GROUND + 8, C.grass)
  rectfill(0, GROUND + 9, SCREEN_W - 1, SCREEN_H - 1, C.dirt)
  line(0, GROUND, SCREEN_W - 1, GROUND, C.cream)
  line(0, GROUND + 8, SCREEN_W - 1, GROUND + 8, C.dirt_light)

  for x = -18, SCREEN_W, 38 do
    local gx = x - flr(scroll / 2) % 38
    line(gx, GROUND + 18, gx + 12, GROUND + 18, C.dirt_light)
    line(gx + 18, GROUND + 31, gx + 22, GROUND + 31, C.wood)
  end
  for x = 18, SCREEN_W, 57 do
    local gx = x - flr(scroll / 3) % 57
    pset(gx, 176, C.cream)
    pset(gx + 2, 178, C.gold)
    pset(gx + 1, 180, C.cream)
  end

  for _, o in ipairs(obstacles) do draw_obstacle(o) end
  if food then
    S.draw(food.kind, food.x, food.y - (play_frames // 10) % 2)
  end
  if not hide_horse and (invulnerable == 0 or play_frames % 8 < 4) then
    if sliding then
      draw_horse_slide(HORSE_X, GROUND - SLIDE_H)
    else
      draw_horse(HORSE_X, horse_y, horse_y == GROUND - HORSE_H,
        kick_timer > KICK_TIME - KICK_ACTIVE, true)
    end
  end
  for _, p in ipairs(particles) do
    rectfill(p.x, p.y, p.x + p.size - 1, p.y + p.size - 1, p.c)
  end

  rectfill(0, 0, SCREEN_W - 1, 31, C.panel)
  rectfill(0, 31, SCREEN_W - 1, 33, C.gold)
  print("HUF-HÜPFER", 8, 5, C.gold)
  print("PUNKTE " .. score, 134, 5, C.white)
  print("BEST " .. best, 250, 5, C.green)
  print("STUFE " .. level, 8, 19, C.sky_light)
  print("SNACKS " .. snacks .. "/3", 117, 19, C.hay_light)
  print("LEBEN " .. lives, 248, 19, lives == 1 and C.red or C.green)
end

function _draw()
  if state == "title" then
    draw_world(true)
    rectfill(40, 42, 280, 160, C.panel)
    rectfill(40, 42, 280, 45, C.gold)
    draw_horse(66, 89, false)
    print("HUF-HÜPFER", 110, 62, C.gold, 2)
    print("HOCH:   Springen", 126, 88, C.white)
    print("RUNTER: Rutschen", 126, 100, C.white)
    print("A:      Treten", 126, 112, C.white)
    print("START:  Pause", 126, 124, C.white)
    rectfill(125, 136, 255, 151, C.saddle)
    print("A: LOS", 164, 140, C.cream)
    return
  end

  draw_world(false)
  if hint_timer > 0 and state == "play" then
    local w = textw(hint_text)
    local x = (SCREEN_W - w) // 2
    rectfill(x - 8, 42, x + w + 7, 59, C.panel)
    print(hint_text, x, 47, frame() % 30 < 20 and C.gold or C.cream)
  end
  if bonus_timer > 0 then
    rectfill(91, 64, 229, 81, C.panel)
    print("EXTRA LEBEN!", 108, 69, C.gold)
  end
  if state == "pause" then
    rectfill(90, 80, 230, 133, C.panel)
    rectfill(90, 80, 230, 83, C.gold)
    print("PAUSE", (SCREEN_W - textw("PAUSE", 2)) // 2, 94, C.gold, 2)
    print("START: Weiter", (SCREEN_W - textw("START: Weiter")) // 2, 118, C.white)
  end
  if state == "over" then
    rectfill(60, 61, 260, 147, C.panel)
    rectfill(60, 61, 260, 64, C.gold)
    print("HOPPLA!", 111, 78, C.red, 2)
    print("Punkte: " .. score, 112, 111, C.white)
    print("Best: " .. best, 112, 124, C.gold)
    if over_timer == 0 then print("A: Nochmal", 112, 136, C.green) end
  end
end
