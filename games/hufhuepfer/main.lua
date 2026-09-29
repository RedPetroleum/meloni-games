-- Huf-Hüpfer: ein kleines Ein-Knopf-Spiel für die Meloni-API v1.
-- A oder hoch drücken, um über Hindernisse zu springen.

local GROUND = 193
local HORSE_X = 44
local HORSE_H = 25
local state = "title"
local horse_y, velocity
local obstacles
local spawn_timer
local speed
local score, best

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
  outline = rgb(50, 54, 53),
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
}

local function reset()
  horse_y = GROUND - HORSE_H
  velocity = 0
  obstacles = {}
  spawn_timer = 68
  speed = 2.55
  score = 0
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

function _update()
  if state == "title" then
    if btnp(BTN_A) or btnp(BTN_START) then start() end
    return
  elseif state == "over" then
    if btnp(BTN_A) or btnp(BTN_START) then start() end
    return
  end

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

  speed = min(5.1, speed + 0.0018)
  spawn_timer = spawn_timer - 1
  if spawn_timer <= 0 then
    local fence = rnd(2) < 1
    obstacles[#obstacles + 1] = {
      x = SCREEN_W + 8,
      w = fence and 17 or 21,
      h = fence and 27 or 18,
      kind = fence and 1 or 2,
      passed = false,
    }
    spawn_timer = 94 + rnd(35) - flr(score / 5) * 2
    if spawn_timer < 64 then spawn_timer = 64 end
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
    if hit_x and hit_y then end_game() end
    if o.x < -32 then table.remove(obstacles, i) end
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
  -- Ground shadow stays on the track while the pony jumps.
  if y > 100 then
    rectfill(cx - 9, GROUND + 1, cx + 8, GROUND + 2, C.dirt)
    circfill(cx - 7, GROUND + 1, 2, C.dirt)
    circfill(cx + 7, GROUND + 1, 2, C.dirt)
  end

  -- Tail, rounded body, neck and head.
  line(x + 7, y + 10, x + 3, y + 6, C.mane)
  line(x + 3, y + 6, x, y + 9, C.horse_light)
  circfill(cx - 3, y + 13, 7, C.horse)
  rectfill(x + 7, y + 7, x + 20, y + 18, C.horse)
  rectfill(x + 8, y + 8, x + 17, y + 10, C.horse_light)
  rectfill(x + 17, y + 5, x + 23, y + 14, C.horse)
  circfill(x + 21, y + 7, 4, C.horse_light)
  rectfill(x + 21, y + 5, x + 28, y + 9, C.horse_light)
  rectfill(x + 25, y + 7, x + 29, y + 10, C.muzzle)

  -- Dark mane, ears, eye and the little white face mark.
  line(x + 16, y + 7, x + 18, y + 2, C.mane)
  line(x + 18, y + 2, x + 21, y + 4, C.mane)
  line(x + 21, y + 4, x + 23, y + 1, C.mane)
  line(x + 18, y + 5, x + 21, y + 4, C.cream)
  pset(x + 24, y + 6, C.ink)
  pset(x + 27, y + 8, C.horse)

  -- Teal saddle with a gold blanket edge.
  rectfill(x + 9, y + 9, x + 16, y + 14, C.saddle)
  line(x + 9, y + 14, x + 17, y + 14, C.gold)

  -- Four simple legs with a small gallop animation.
  line(x + 8, y + 17, x + 7 + stride, y + 23, C.horse)
  line(x + 12, y + 17, x + 12 - stride, y + 23, C.horse)
  line(x + 18, y + 16, x + 19 - stride, y + 23, C.horse)
  line(x + 21, y + 13, x + 22 + stride, y + 22, C.horse)
  line(x + 6 + stride, y + 23, x + 9 + stride, y + 23, C.mane)
  line(x + 11 - stride, y + 23, x + 14 - stride, y + 23, C.mane)
  line(x + 18 - stride, y + 23, x + 21 - stride, y + 23, C.mane)
  line(x + 21 + stride, y + 22, x + 24 + stride, y + 22, C.mane)
end

local function draw_obstacle(o)
  if o.kind == 1 then
    -- Painted wooden jump fence.
    rectfill(o.x + 2, GROUND - o.h + 4, o.x + 5, GROUND - 1, C.wood)
    rectfill(o.x + o.w - 5, GROUND - o.h + 4, o.x + o.w - 2, GROUND - 1, C.wood)
    rectfill(o.x - 1, GROUND - o.h + 7, o.x + o.w + 1, GROUND - o.h + 11, C.cream)
    rectfill(o.x - 1, GROUND - 12, o.x + o.w + 1, GROUND - 8, C.wood_light)
    line(o.x + 2, GROUND - o.h + 8, o.x + o.w - 2, GROUND - o.h + 8, C.red)
    line(o.x + 2, GROUND - 10, o.x + o.w - 2, GROUND - 10, C.gold)
  else
    -- A golden hay bale with tidy twine.
    rectfill(o.x + 2, GROUND - o.h + 2, o.x + o.w - 2, GROUND - 1, C.hay)
    rectfill(o.x + 4, GROUND - o.h + 1, o.x + o.w - 4, GROUND - o.h + 3, C.hay_light)
    rect(o.x + 2, GROUND - o.h + 2, o.x + o.w - 2, GROUND - 1, C.wood)
    line(o.x + 6, GROUND - o.h + 4, o.x + 6, GROUND - 3, C.hay_light)
    line(o.x + o.w - 7, GROUND - o.h + 4, o.x + o.w - 7, GROUND - 3, C.hay_light)
  end
end

local function draw_world(hide_horse)
  cls(C.sky)
  -- A quiet blue-green sky with a small, warm sun.
  rectfill(0, 19, SCREEN_W - 1, 66, C.sky_top)
  rectfill(0, 67, SCREEN_W - 1, 111, C.sky)
  circfill(271, 57, 13, C.sun)
  circfill(267, 53, 3, C.hay_light)
  draw_cloud(34, 51)
  draw_cloud(168, 77)

  -- Low rolling hills leave open sky around the horse.
  circfill(-8, 158, 48, C.far_hill)
  circfill(93, 166, 43, C.far_hill)
  circfill(221, 160, 49, C.far_hill)
  circfill(319, 165, 43, C.far_hill)
  circfill(41, 180, 33, C.hill)
  circfill(176, 178, 37, C.hill)
  circfill(292, 181, 32, C.hill)
  rectfill(0, 166, SCREEN_W - 1, GROUND - 1, C.field)
  rectfill(0, 182, SCREEN_W - 1, GROUND - 1, C.field_light)

  -- Track and foreground dirt give the running lane a clear silhouette.
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
  if not hide_horse then draw_horse(HORSE_X, horse_y, horse_y == GROUND - HORSE_H) end

  -- Compact, dark HUD with clear spacing.
  rectfill(0, 0, SCREEN_W - 1, 21, C.panel)
  rectfill(0, 21, SCREEN_W - 1, 23, C.gold)
  print("HUF-HÜPFER", 8, 7, C.gold)
  print("PUNKTE  " .. score, 134, 7, C.white)
  print("BEST  " .. best, 250, 7, C.green)
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

  draw_world()
  if state == "over" then
    rectfill(60, 61, 260, 147, C.panel)
    rectfill(60, 61, 260, 64, C.gold)
    print("AUSGERUTSCHT!", 95, 78, C.red, 2)
    print("Punkte: " .. score, 112, 111, C.white)
    print("Best: " .. best, 112, 124, C.gold)
    print("A: Nochmal", 112, 136, C.green)
  end
end
