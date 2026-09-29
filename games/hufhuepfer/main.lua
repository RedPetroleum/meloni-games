-- Huf-Hüpfer: ein kleines Pferde-Jump-and-Run für die Meloni-API v1.
-- Hoch: springen, runter: unter Ästen durchrutschen, A: Kisten und Bretterwände kaputt treten.
-- Sammle Möhren und Äpfel: Je drei Snacks geben ein zusätzliches Leben.

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
local spawn_timer, food_timer
local speed, play_frames, level
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
  dirt = rgb(124, 91, 69),
  dirt_light = rgb(158, 119, 82),
  wood = rgb(106, 67, 53),
  wood_light = rgb(185, 125, 77),
  hay = rgb(215, 159, 83),
  hay_light = rgb(241, 199, 119),
  horse = rgb(149, 79, 54),
  horse_light = rgb(205, 124, 77),
  mane = rgb(65, 49, 48),
  muzzle = rgb(235, 188, 143),
  saddle = rgb(54, 99, 103),
  cream = rgb(248, 231, 187),
  ink = rgb(36, 46, 53),
  panel = rgb(42, 57, 65),
  white = rgb(246, 238, 216),
  gold = rgb(241, 192, 103),
  green = rgb(168, 194, 124),
  red = rgb(213, 119, 94),
  water = rgb(81, 138, 151),
  water_light = rgb(145, 195, 190),
  apple = rgb(185, 77, 68),
  leaf = rgb(115, 150, 78),
  leaf_dark = rgb(72, 108, 70),
}

-- Hindernisarten: h = Höhe am Boden, overhead = hängt von oben (drunter rutschen),
-- breakable = mit A kaputt treten. hint erscheint beim ersten Auftauchen.
local KINDS = {
  fence = {w = 17, h = 27},
  hay = {w = 21, h = 18},
  puddle = {w = 31, h = 10},
  logs = {w = 24, h = 22},
  branch = {w = 30, overhead = true, hint = "RUNTER: DRUNTER RUTSCHEN!"},
  crate = {w = 18, h = 18, breakable = true, hint = "A: KISTE KAPUTT TRETEN!"},
  wall = {w = 16, h = 68, breakable = true, hint = "ZU HOCH! A: TRETEN!"},
}
local POOLS = {
  {"fence", "hay", "branch", "crate"},
  {"fence", "hay", "branch", "crate", "puddle", "wall"},
  {"fence", "hay", "branch", "crate", "puddle", "wall", "logs", "branch"},
}

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
  food_timer = 110
  speed = 2.55
  play_frames = 0
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

local function make_obstacle()
  -- New shapes enter gradually: puddles and walls at level 2, log piles at level 3.
  local kind = rnd(POOLS[min(level, #POOLS)])
  local k = KINDS[kind]
  obstacles[#obstacles + 1] = {
    x = SCREEN_W + 8,
    w = k.w,
    h = k.h or 0,
    kind = kind,
    overhead = k.overhead,
    breakable = k.breakable,
    passed = false,
  }
  if k.hint and not seen[kind] then
    seen[kind] = true
    hint_text = k.hint
    hint_timer = 150
  end
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

function _update()
  if state == "title" then
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

  play_frames = play_frames + 1
  level = min(5, 1 + flr(play_frames / 600))
  speed = min(5.2, 2.55 + (level - 1) * 0.43 + play_frames / 2400 * 0.4)

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
    if frame() % 3 == 0 then
      add_particle(HORSE_X - 2, GROUND - 2, -speed * 0.5, -rnd(1), C.dirt_light, 14, 2)
    end
  elseif btnp(BTN_A) and kick_timer == 0 then
    kick_timer = KICK_TIME
    tone(note("A3"), 0.05, "noise", 0.12)
  end
  local kicking = kick_timer > KICK_TIME - KICK_ACTIVE

  local top = sliding and GROUND - SLIDE_H or horse_y
  local bottom = sliding and GROUND or horse_y + HORSE_H

  spawn_timer = spawn_timer - 1
  if spawn_timer <= 0 then
    make_obstacle()
    spawn_timer = 96 + rnd(30) - (level - 1) * 5 - min(10, flr(play_frames / 900)) * 2
    if spawn_timer < 65 then spawn_timer = 65 end
  end

  food_timer = food_timer - 1
  if not food and food_timer <= 0 then
    local high = level >= 3 and rnd(3) < 1
    food = {
      x = SCREEN_W + 10,
      y = GROUND - (high and 53 or 34),
      kind = rnd(2) < 1 and "carrot" or "apple",
    }
    food_timer = 154 + rnd(45)
  end

  if food then
    food.x = food.x - speed
    local overlaps_x = HORSE_X + 28 > food.x and HORSE_X + 2 < food.x + 10
    local overlaps_y = top < food.y + 10 and bottom > food.y
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

local function draw_horse(x, y, running, kicking)
  local stride = running and not kicking and ((frame() // 4) % 2) * 2 or 0
  local cx = x + 13
  if y > 100 then
    rectfill(cx - 9, GROUND + 1, cx + 8, GROUND + 2, C.dirt)
    circfill(cx - 7, GROUND + 1, 2, C.dirt)
    circfill(cx + 7, GROUND + 1, 2, C.dirt)
  end

  -- Tail, round chestnut body, neck and face.
  line(x + 7, y + 10, x + 3, y + 6, C.mane)
  line(x + 3, y + 6, x, y + 9, C.horse_light)
  circfill(cx - 3, y + 13, 7, C.horse)
  rectfill(x + 7, y + 7, x + 20, y + 18, C.horse)
  rectfill(x + 8, y + 8, x + 17, y + 10, C.horse_light)
  rectfill(x + 17, y + 5, x + 23, y + 14, C.horse)
  circfill(x + 21, y + 7, 4, C.horse_light)
  rectfill(x + 21, y + 5, x + 28, y + 9, C.horse_light)
  rectfill(x + 25, y + 7, x + 29, y + 10, C.muzzle)

  line(x + 16, y + 7, x + 18, y + 2, C.mane)
  line(x + 18, y + 2, x + 21, y + 4, C.mane)
  line(x + 21, y + 4, x + 23, y + 1, C.mane)
  line(x + 18, y + 5, x + 21, y + 4, C.cream)
  pset(x + 24, y + 6, C.ink)
  pset(x + 27, y + 8, C.horse)

  -- Teal saddle, gold edge and four animated legs.
  rectfill(x + 9, y + 9, x + 16, y + 14, C.saddle)
  line(x + 9, y + 14, x + 17, y + 14, C.gold)
  line(x + 8, y + 17, x + 7 + stride, y + 23, C.horse)
  line(x + 12, y + 17, x + 12 - stride, y + 23, C.horse)
  line(x + 6 + stride, y + 23, x + 9 + stride, y + 23, C.mane)
  line(x + 11 - stride, y + 23, x + 14 - stride, y + 23, C.mane)
  if kicking then
    -- Front legs thrust forward, with a little impact flash.
    line(x + 18, y + 16, x + 29, y + 18, C.horse)
    line(x + 21, y + 13, x + 32, y + 12, C.horse)
    rectfill(x + 29, y + 17, x + 31, y + 19, C.mane)
    rectfill(x + 32, y + 11, x + 34, y + 13, C.mane)
    line(x + 37, y + 7, x + 39, y + 10, C.cream)
    line(x + 38, y + 15, x + 42, y + 15, C.cream)
    line(x + 37, y + 20, x + 39, y + 23, C.cream)
  else
    line(x + 18, y + 16, x + 19 - stride, y + 23, C.horse)
    line(x + 21, y + 13, x + 22 + stride, y + 22, C.horse)
    line(x + 18 - stride, y + 23, x + 21 - stride, y + 23, C.mane)
    line(x + 21 + stride, y + 22, x + 24 + stride, y + 22, C.mane)
  end
end

-- Low, stretched-out horse sliding on its belly; y is the top, hooves at y + 12.
local function draw_horse_slide(x, y)
  rectfill(x - 2, GROUND + 1, x + 30, GROUND + 2, C.dirt)
  line(x + 1, y + 5, x - 5, y + 3, C.mane)
  line(x - 5, y + 3, x - 8, y + 6, C.horse_light)
  line(x + 6, y + 10, x - 2, y + 12, C.horse)
  line(x - 4, y + 12, x - 1, y + 12, C.mane)
  circfill(x + 6, y + 7, 4, C.horse)
  rectfill(x + 5, y + 3, x + 22, y + 10, C.horse)
  rectfill(x + 7, y + 3, x + 18, y + 4, C.horse_light)
  rectfill(x + 19, y + 2, x + 26, y + 8, C.horse)
  rectfill(x + 24, y + 1, x + 31, y + 5, C.horse_light)
  rectfill(x + 29, y + 3, x + 33, y + 6, C.muzzle)
  line(x + 18, y + 2, x + 24, y, C.mane)
  line(x + 22, y, x + 19, y - 1, C.mane)
  pset(x + 27, y + 2, C.ink)
  rectfill(x + 9, y + 2, x + 15, y + 6, C.saddle)
  line(x + 9, y + 6, x + 15, y + 6, C.gold)
  line(x + 20, y + 9, x + 30, y + 12, C.horse)
  line(x + 29, y + 12, x + 32, y + 12, C.mane)
end

local function draw_carrot(x, y)
  line(x + 3, y + 3, x + 1, y, C.leaf)
  line(x + 4, y + 3, x + 5, y - 1, C.leaf)
  line(x + 5, y + 3, x + 8, y + 1, C.leaf)
  line(x + 2, y + 3, x + 6, y + 3, C.hay)
  line(x + 2, y + 4, x + 5, y + 9, C.hay)
  line(x + 6, y + 4, x + 5, y + 9, C.hay)
  pset(x + 4, y + 6, C.hay_light)
end

local function draw_apple(x, y)
  circfill(x + 4, y + 5, 4, C.apple)
  rectfill(x + 1, y + 4, x + 8, y + 8, C.apple)
  line(x + 4, y + 1, x + 5, y - 1, C.wood)
  line(x + 5, y + 1, x + 8, y, C.leaf)
  pset(x + 2, y + 4, C.red)
end

local function draw_obstacle(o)
  if o.kind == "fence" then
    rectfill(o.x + 2, GROUND - o.h + 4, o.x + 5, GROUND - 1, C.wood)
    rectfill(o.x + o.w - 5, GROUND - o.h + 4, o.x + o.w - 2, GROUND - 1, C.wood)
    rectfill(o.x - 1, GROUND - o.h + 7, o.x + o.w + 1, GROUND - o.h + 11, C.cream)
    rectfill(o.x - 1, GROUND - 12, o.x + o.w + 1, GROUND - 8, C.wood_light)
    line(o.x + 2, GROUND - o.h + 8, o.x + o.w - 2, GROUND - o.h + 8, C.red)
    line(o.x + 2, GROUND - 10, o.x + o.w - 2, GROUND - 10, C.gold)
  elseif o.kind == "hay" then
    rectfill(o.x + 2, GROUND - o.h + 2, o.x + o.w - 2, GROUND - 1, C.hay)
    rectfill(o.x + 4, GROUND - o.h + 1, o.x + o.w - 4, GROUND - o.h + 3, C.hay_light)
    rect(o.x + 2, GROUND - o.h + 2, o.x + o.w - 2, GROUND - 1, C.wood)
    line(o.x + 6, GROUND - o.h + 4, o.x + 6, GROUND - 3, C.hay_light)
    line(o.x + o.w - 7, GROUND - o.h + 4, o.x + o.w - 7, GROUND - 3, C.hay_light)
  elseif o.kind == "puddle" then
    -- Wide, low puddle: jump over it.
    circfill(o.x + 8, GROUND - 3, 6, C.water)
    circfill(o.x + 20, GROUND - 3, 7, C.water)
    circfill(o.x + 26, GROUND - 3, 5, C.water)
    line(o.x + 8, GROUND - 4, o.x + 13, GROUND - 4, C.water_light)
    line(o.x + 21, GROUND - 2, o.x + 26, GROUND - 2, C.water_light)
  elseif o.kind == "logs" then
    -- A stack of two short logs.
    rectfill(o.x + 2, GROUND - 10, o.x + o.w - 2, GROUND - 1, C.wood)
    rectfill(o.x + 5, GROUND - 17, o.x + o.w - 5, GROUND - 9, C.wood_light)
    circfill(o.x + 6, GROUND - 13, 3, C.hay_light)
    circfill(o.x + o.w - 6, GROUND - 5, 3, C.hay_light)
  elseif o.kind == "branch" then
    -- Low branch hanging from above: slide under it.
    for i = 0, 3 do
      line(o.x + 34 + i, 34, o.x + 14 + i, BRANCH_BOTTOM - 26, i < 2 and C.wood or C.mane)
    end
    line(o.x + 30, 34, o.x + 44, 50, C.wood)
    circfill(o.x + 42, 52, 5, C.leaf_dark)
    circfill(o.x + 14, BRANCH_BOTTOM - 20, 9, C.leaf_dark)
    circfill(o.x + 6, BRANCH_BOTTOM - 10, 7, C.leaf_dark)
    circfill(o.x + 17, BRANCH_BOTTOM - 8, 8, C.leaf_dark)
    circfill(o.x + 26, BRANCH_BOTTOM - 11, 6, C.leaf_dark)
    circfill(o.x + 11, BRANCH_BOTTOM - 15, 5, C.leaf)
    circfill(o.x + 21, BRANCH_BOTTOM - 14, 4, C.leaf)
    line(o.x + 4, BRANCH_BOTTOM - 4, o.x + 4, BRANCH_BOTTOM, C.leaf_dark)
    line(o.x + 13, BRANCH_BOTTOM - 1, o.x + 13, BRANCH_BOTTOM + 1, C.leaf_dark)
    line(o.x + 22, BRANCH_BOTTOM - 3, o.x + 22, BRANCH_BOTTOM, C.leaf_dark)
    pset(o.x + 9, BRANCH_BOTTOM - 17, C.green)
    pset(o.x + 19, BRANCH_BOTTOM - 16, C.green)
    pset(o.x + 24, BRANCH_BOTTOM - 12, C.green)
  elseif o.kind == "crate" then
    -- Wooden crate: jump over it or kick it apart.
    local top = GROUND - o.h
    rectfill(o.x, top, o.x + o.w, GROUND - 1, C.wood_light)
    rect(o.x, top, o.x + o.w, GROUND - 1, C.wood)
    rect(o.x + 2, top + 2, o.x + o.w - 2, GROUND - 3, C.wood)
    line(o.x + 2, top + 2, o.x + o.w - 2, GROUND - 3, C.wood)
    line(o.x + o.w - 2, top + 2, o.x + 2, GROUND - 3, C.wood)
    line(o.x + 1, top + 1, o.x + o.w - 1, top + 1, C.hay_light)
  else
    -- Tall plank wall with a crack: too high to jump, kick it down.
    local top = GROUND - o.h
    rectfill(o.x, top + 3, o.x + o.w, GROUND - 1, C.wood_light)
    for p = 0, 2 do
      local px = o.x + p * 5 + 1
      line(px, top + 2, px + 3, top + 2, C.wood_light)
      line(px + 1, top, px + 2, top, C.wood_light)
      line(px + 1, top + 1, px + 2, top + 1, C.wood_light)
      if p > 0 then line(px - 1, top + 2, px - 1, GROUND - 1, C.wood) end
    end
    rectfill(o.x - 1, top + 9, o.x + o.w + 1, top + 12, C.wood)
    rectfill(o.x - 1, GROUND - 16, o.x + o.w + 1, GROUND - 13, C.wood)
    line(o.x + 7, top + 22, o.x + 10, top + 29, C.mane)
    line(o.x + 10, top + 29, o.x + 6, top + 36, C.mane)
    line(o.x + 6, top + 36, o.x + 9, top + 43, C.mane)
    pset(o.x + 2, top + 10, C.cream)
    pset(o.x + o.w - 2, GROUND - 15, C.cream)
  end
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
    local gx = x - flr(frame() * speed / 2) % 38
    line(gx, GROUND + 18, gx + 12, GROUND + 18, C.dirt_light)
    line(gx + 18, GROUND + 31, gx + 22, GROUND + 31, C.wood)
  end
  for x = 18, SCREEN_W, 57 do
    local gx = x - flr(frame() * speed / 3) % 57
    pset(gx, 176, C.cream)
    pset(gx + 2, 178, C.gold)
    pset(gx + 1, 180, C.cream)
  end

  for _, o in ipairs(obstacles) do draw_obstacle(o) end
  if food then
    if food.kind == "carrot" then draw_carrot(food.x, food.y)
    else draw_apple(food.x, food.y) end
  end
  if not hide_horse and (invulnerable == 0 or frame() % 8 < 4) then
    if sliding then
      draw_horse_slide(HORSE_X, GROUND - SLIDE_H)
    else
      draw_horse(HORSE_X, horse_y, horse_y == GROUND - HORSE_H,
        kick_timer > KICK_TIME - KICK_ACTIVE)
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
    rectfill(40, 42, 280, 151, C.panel)
    rectfill(40, 42, 280, 45, C.gold)
    draw_horse(66, 89, false)
    print("HUF-HÜPFER", 110, 62, C.gold, 2)
    print("HOCH:   Springen", 126, 88, C.white)
    print("RUNTER: Rutschen", 126, 100, C.white)
    print("A:      Treten", 126, 112, C.white)
    rectfill(125, 128, 255, 145, C.saddle)
    print("A: LOS", 164, 133, C.cream)
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
  if state == "over" then
    rectfill(60, 61, 260, 147, C.panel)
    rectfill(60, 61, 260, 64, C.gold)
    print("HOPPLA!", 111, 78, C.red, 2)
    print("Punkte: " .. score, 112, 111, C.white)
    print("Best: " .. best, 112, 124, C.gold)
    if over_timer == 0 then print("A: Nochmal", 112, 136, C.green) end
  end
end
