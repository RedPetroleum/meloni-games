-- Huf-Hüpfer: ein kleines Ein-Knopf-Spiel für die Meloni-API v1.
-- A oder hoch drücken, um über Hindernisse zu springen.
-- Sammle Möhren und Äpfel: Je drei Snacks geben ein zusätzliches Leben.

local GROUND = 193
local HORSE_X = 44
local HORSE_H = 25
local MAX_LIVES = 5
local state = "title"
local horse_y, velocity
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
}

local function reset()
  horse_y = GROUND - HORSE_H
  velocity = 0
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
  -- New shapes enter gradually: puddles at level 2, log piles at level 3.
  local kinds = level >= 3 and 4 or level >= 2 and 3 or 2
  local kind = flr(rnd(kinds)) + 1
  local widths = {17, 21, 31, 24}
  local heights = {27, 18, 10, 22}
  obstacles[#obstacles + 1] = {
    x = SCREEN_W + 8,
    w = widths[kind],
    h = heights[kind],
    kind = kind,
    passed = false,
  }
end

function _update()
  if state == "title" then
    if btnp(BTN_A) or btnp(BTN_START) then start() end
    return
  elseif state == "over" then
    if btnp(BTN_A) or btnp(BTN_START) then start() end
    return
  end

  play_frames = play_frames + 1
  level = min(5, 1 + flr(play_frames / 600))
  speed = min(5.2, 2.55 + (level - 1) * 0.43 + play_frames / 2400 * 0.4)

  if invulnerable > 0 then invulnerable = invulnerable - 1 end
  if bonus_timer > 0 then bonus_timer = bonus_timer - 1 end

  if (btnp(BTN_A) or btnp(BTN_UP)) and horse_y >= GROUND - HORSE_H then
    velocity = -6.9
    tone(note("D5"), 0.06, "square", 0.18)
  end

  horse_y = horse_y + velocity
  velocity = velocity + 0.34
  if horse_y > GROUND - HORSE_H then
    horse_y = GROUND - HORSE_H
    velocity = 0
  end

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
    local overlaps_y = horse_y < food.y + 10 and horse_y + HORSE_H > food.y
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
    local hit_x = HORSE_X + 26 > o.x and HORSE_X + 4 < o.x + o.w
    local hit_y = horse_y + HORSE_H - 2 > GROUND - o.h
    if hit_x and hit_y and invulnerable == 0 then
      lives = lives - 1
      invulnerable = 72
      tone(note("C3"), 0.12, "saw", 0.18)
      if lives <= 0 then end_game() end
    end
    if o.x < -34 then table.remove(obstacles, i) end
  end
end

local function draw_cloud(x, y)
  circfill(x, y + 4, 7, C.cloud)
  circfill(x + 8, y, 9, C.cloud)
  circfill(x + 18, y + 4, 7, C.cloud)
  rectfill(x - 1, y + 3, x + 19, y + 10, C.cloud)
  line(x + 2, y + 11, x + 17, y + 11, C.sky_light)
end

local function draw_horse(x, y, running)
  local stride = running and ((frame() // 4) % 2) * 2 or 0
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
  line(x + 18, y + 16, x + 19 - stride, y + 23, C.horse)
  line(x + 21, y + 13, x + 22 + stride, y + 22, C.horse)
  line(x + 6 + stride, y + 23, x + 9 + stride, y + 23, C.mane)
  line(x + 11 - stride, y + 23, x + 14 - stride, y + 23, C.mane)
  line(x + 18 - stride, y + 23, x + 21 - stride, y + 23, C.mane)
  line(x + 21 + stride, y + 22, x + 24 + stride, y + 22, C.mane)
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
  if o.kind == 1 then
    rectfill(o.x + 2, GROUND - o.h + 4, o.x + 5, GROUND - 1, C.wood)
    rectfill(o.x + o.w - 5, GROUND - o.h + 4, o.x + o.w - 2, GROUND - 1, C.wood)
    rectfill(o.x - 1, GROUND - o.h + 7, o.x + o.w + 1, GROUND - o.h + 11, C.cream)
    rectfill(o.x - 1, GROUND - 12, o.x + o.w + 1, GROUND - 8, C.wood_light)
    line(o.x + 2, GROUND - o.h + 8, o.x + o.w - 2, GROUND - o.h + 8, C.red)
    line(o.x + 2, GROUND - 10, o.x + o.w - 2, GROUND - 10, C.gold)
  elseif o.kind == 2 then
    rectfill(o.x + 2, GROUND - o.h + 2, o.x + o.w - 2, GROUND - 1, C.hay)
    rectfill(o.x + 4, GROUND - o.h + 1, o.x + o.w - 4, GROUND - o.h + 3, C.hay_light)
    rect(o.x + 2, GROUND - o.h + 2, o.x + o.w - 2, GROUND - 1, C.wood)
    line(o.x + 6, GROUND - o.h + 4, o.x + 6, GROUND - 3, C.hay_light)
    line(o.x + o.w - 7, GROUND - o.h + 4, o.x + o.w - 7, GROUND - 3, C.hay_light)
  elseif o.kind == 3 then
    -- Wide, low puddle: jump over it.
    circfill(o.x + 8, GROUND - 3, 6, C.water)
    circfill(o.x + 20, GROUND - 3, 7, C.water)
    circfill(o.x + 26, GROUND - 3, 5, C.water)
    line(o.x + 8, GROUND - 4, o.x + 13, GROUND - 4, C.water_light)
    line(o.x + 21, GROUND - 2, o.x + 26, GROUND - 2, C.water_light)
  else
    -- A stack of two short logs.
    rectfill(o.x + 2, GROUND - 10, o.x + o.w - 2, GROUND - 1, C.wood)
    rectfill(o.x + 5, GROUND - 17, o.x + o.w - 5, GROUND - 9, C.wood_light)
    circfill(o.x + 6, GROUND - 13, 3, C.hay_light)
    circfill(o.x + o.w - 6, GROUND - 5, 3, C.hay_light)
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
    draw_horse(HORSE_X, horse_y, horse_y == GROUND - HORSE_H)
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
    rectfill(46, 42, 274, 151, C.panel)
    rectfill(46, 42, 274, 45, C.gold)
    draw_horse(72, 89, false)
    print("HUF-HÜPFER", 126, 62, C.gold, 2)
    print("Spring ueber Zaeune", 126, 94, C.white)
    print("und Heuballen.", 126, 108, C.white)
    rectfill(125, 128, 255, 145, C.saddle)
    print("A: LOS", 164, 133, C.cream)
    return
  end

  draw_world(false)
  if bonus_timer > 0 then
    rectfill(91, 42, 229, 59, C.panel)
    print("EXTRA LEBEN!", 108, 47, C.gold)
  end
  if state == "over" then
    rectfill(60, 61, 260, 147, C.panel)
    rectfill(60, 61, 260, 64, C.gold)
    print("HOPPLA!", 111, 78, C.red, 2)
    print("Punkte: " .. score, 112, 111, C.white)
    print("Best: " .. best, 112, 124, C.gold)
    print("A: Nochmal", 112, 136, C.green)
  end
end
