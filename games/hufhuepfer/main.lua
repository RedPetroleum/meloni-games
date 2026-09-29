-- Huf-Hüpfer: ein kleines Ein-Knopf-Spiel für die Meloni-API v1.
-- A oder hoch drücken, um über Hindernisse zu springen.

local GROUND = 198
local HORSE_X = 48
local state = "title"
local horse_y, velocity
local obstacles
local spawn_timer
local speed
local score, best

local function reset()
  horse_y = GROUND - 18
  velocity = 0
  obstacles = {}
  spawn_timer = 65
  speed = 2.6
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

  if (btnp(BTN_A) or btnp(BTN_UP)) and horse_y >= GROUND - 18 then
    velocity = -6.8
    tone(note("D5"), 0.06, "square", 0.18)
  end

  horse_y = horse_y + velocity
  velocity = velocity + 0.34
  if horse_y > GROUND - 18 then
    horse_y = GROUND - 18
    velocity = 0
  end

  speed = min(5.2, speed + 0.002)
  spawn_timer = spawn_timer - 1
  if spawn_timer <= 0 then
    local tall = rnd(2) < 1
    obstacles[#obstacles + 1] = {
      x = SCREEN_W + 4,
      w = tall and 13 or 22,
      h = tall and 25 or 17,
      kind = tall and 1 or 2,
      passed = false,
    }
    spawn_timer = 88 + rnd(34) - flr(score / 4) * 2
    if spawn_timer < 58 then spawn_timer = 58 end
  end

  for i = #obstacles, 1, -1 do
    local o = obstacles[i]
    o.x = o.x - speed
    if not o.passed and o.x + o.w < HORSE_X then
      o.passed = true
      score = score + 1
      if score % 5 == 0 then tone(note("E5"), 0.07, "triangle", 0.22) end
    end
    local hit_x = HORSE_X + 19 > o.x and HORSE_X + 5 < o.x + o.w
    local hit_y = horse_y + 16 > GROUND - o.h
    if hit_x and hit_y then end_game() end
    if o.x < -30 then table.remove(obstacles, i) end
  end
end

local function draw_horse(x, y, gallop)
  local step = gallop and ((frame() // 4) % 2) or 0
  -- A tiny side-view pony, assembled from simple shapes.
  circfill(x + 11, y + 11, 8, 4)
  rectfill(x + 4, y + 7, x + 18, y + 14, 4)
  circfill(x + 19, y + 6, 5, 4)
  line(x + 16, y + 3, x + 15, y, 5)
  line(x + 20, y + 2, x + 22, y, 5)
  pset(x + 21, y + 5, 0)
  line(x + 4, y + 9, x, y + 6, 5)
  rectfill(x + 8, y + 10, x + 14, y + 12, 9)
  line(x + 6, y + 14, x + 5 + step, y + 18, 5)
  line(x + 10, y + 14, x + 10 - step, y + 18, 5)
  line(x + 16, y + 13, x + 17 - step, y + 18, 5)
  line(x + 19, y + 11, x + 20 + step, y + 17, 5)
  line(x + 5 + step, y + 18, x + 8 + step, y + 18, 0)
  line(x + 10 - step, y + 18, x + 13 - step, y + 18, 0)
  line(x + 17 - step, y + 18, x + 20 - step, y + 18, 0)
end

local function draw_obstacle(o)
  if o.kind == 1 then
    -- A little jump fence.
    rectfill(o.x, GROUND - o.h, o.x + o.w, GROUND - 2, 4)
    rectfill(o.x - 2, GROUND - o.h + 4, o.x + o.w + 2, GROUND - o.h + 8, 9)
    rectfill(o.x - 2, GROUND - 12, o.x + o.w + 2, GROUND - 8, 9)
    line(o.x + 2, GROUND - o.h, o.x + 2, GROUND - 2, 10)
  else
    rectfill(o.x, GROUND - o.h, o.x + o.w, GROUND - 1, 9)
    rect(o.x, GROUND - o.h, o.x + o.w, GROUND - 1, 4)
    line(o.x + 4, GROUND - o.h + 5, o.x + o.w - 4, GROUND - o.h + 5, 10)
    line(o.x + 4, GROUND - 5, o.x + o.w - 4, GROUND - 5, 10)
  end
end

local function draw_world()
  cls(12)
  -- Sun and two soft hills.
  circfill(274, 40, 17, 10)
  circfill(43, 107, 44, 11)
  circfill(279, 112, 56, 11)
  circfill(154, 126, 39, 11)
  rectfill(0, GROUND, SCREEN_W - 1, SCREEN_H - 1, 3)
  line(0, GROUND, SCREEN_W - 1, GROUND, 11)
  for x = -20, SCREEN_W, 32 do
    local gx = (x - flr(frame() * speed / 2) % 32)
    line(gx, GROUND + 12, gx + 9, GROUND + 12, 11)
    line(gx + 12, GROUND + 28, gx + 17, GROUND + 28, 11)
  end

  for _, o in ipairs(obstacles) do draw_obstacle(o) end
  draw_horse(HORSE_X, horse_y, state == "play" and horse_y == GROUND - 18)
  rectfill(0, 0, SCREEN_W - 1, 18, 1)
  print("HUF-HUEPFER", 6, 5, 10)
  print("PUNKTE " .. score, 137, 5, 7)
  print("BEST " .. best, 253, 5, 11)
end

function _draw()
  if state == "title" then
    draw_world()
    rectfill(37, 47, 283, 161, 1)
    print("HUF-HUEPFER", 78, 66, 10, 3)
    print("Spring ueber die", 92, 111, 7, 1)
    print("Hindernisse!", 105, 125, 7, 1)
    print("A / START: Los", 98, 145, 11, 1)
    return
  end

  draw_world()
  if state == "over" then
    rectfill(45, 63, 275, 157, 1)
    print("HOPPLA!", 112, 79, 8, 2)
    print("Punkte: " .. score, 112, 111, 7)
    print("Best: " .. best, 112, 126, 10)
    print("A: nochmal", 112, 143, 11)
  end
end
