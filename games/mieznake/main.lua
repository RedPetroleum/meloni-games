-- Mieznake: Snake mit einer flauschigen Britisch Kurzhaar.
-- D-pad: steuern   A/START: starten   B: Pause

local S = require("sprites")

local CELL = 16
local TOP = 24
local COLS, ROWS = 20, 13

local DIRS = {
  [BTN_UP] = {0, -1},
  [BTN_DOWN] = {0, 1},
  [BTN_LEFT] = {-1, 0},
  [BTN_RIGHT] = {1, 0},
}

local state
local cat
local dir
local turns
local treat
local score
local best
local step_frames
local step_timer

local C = {
  bg = rgb(224, 226, 221),
  bg2 = rgb(214, 218, 213),
  grass = rgb(180, 190, 171),
  panel = rgb(45, 57, 62),
  white = rgb(246, 241, 228),
  silver = rgb(185, 194, 201),
  blue = rgb(97, 196, 194),
  brown = rgb(138, 90, 54),
}

local function occupied(x, y)
  for _, p in ipairs(cat) do
    if p.x == x and p.y == y then return true end
  end
  return false
end

local function place_treat()
  local free = {}
  for y = 0, ROWS - 1 do
    for x = 0, COLS - 1 do
      if not occupied(x, y) then
        free[#free + 1] = {x = x, y = y}
      end
    end
  end
  treat = rnd(free)
end

local function reset()
  cat = {
    {x = 7, y = 6},
    {x = 6, y = 6},
    {x = 5, y = 6},
  }
  dir = {1, 0}
  turns = {}
  score = 0
  step_frames = 10
  step_timer = 0
  place_treat()
end

function _init()
  local save = loaddata()
  best = save and (save.best or 0) or 0
  reset()
  state = "ready"
end

local function finish(won)
  state = won and "won" or "over"
  if score > best then
    best = score
    savedata({best = best})
  end
  if won then
    tune("C5 E5 G5 C6:2", 180, "triangle", 0.35)
  else
    tune("G3 E3 C3:2", 160, "triangle", 0.25)
  end
end

local function queue_turn(button)
  local d = DIRS[button]
  if not d or #turns >= 2 then return end
  local last = turns[#turns] or dir
  if d[1] == -last[1] and d[2] == -last[2] then return end
  if d[1] == last[1] and d[2] == last[2] then return end
  turns[#turns + 1] = d
end

local function step()
  if #turns > 0 then dir = table.remove(turns, 1) end

  local head = cat[1]
  local nx, ny = head.x + dir[1], head.y + dir[2]

  if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS then
    finish(false)
    return
  end

  local eating = treat and nx == treat.x and ny == treat.y
  if not eating then table.remove(cat) end

  if occupied(nx, ny) then
    finish(false)
    return
  end

  table.insert(cat, 1, {x = nx, y = ny})

  if eating then
    score = score + 1
    tone(note("E5"), 0.07, "triangle", 0.3)
    if score % 5 == 0 and step_frames > 4 then
      step_frames = step_frames - 1
    end
    place_treat()
    if not treat then finish(true) end
  end
end

local function centered(text, y, c, scale)
  scale = scale or 1
  print(text, (SCREEN_W - textw(text, scale)) // 2, y, c, scale)
end

local function draw_cat_segment(p, index)
  local x = p.x * CELL - 2
  local y = TOP + p.y * CELL - 2

  if index == 1 then
    if dir[1] == 1 then
      S.draw("cat_head_r", x, y)
    elseif dir[1] == -1 then
      S.draw("cat_head_r", x + 20, y, true)
    elseif dir[2] == -1 then
      S.draw("cat_head_u", x, y)
    else
      S.draw("cat_head_d", x, y)
    end
  elseif index == #cat then
    S.draw("cat_tail", x, y)
  else
    S.draw((index % 2 == 0) and "cat_body1" or "cat_body2", x, y)
  end
end

function _update()
  if state == "ready" or state == "over" or state == "won" then
    if btnp(BTN_A) or btnp(BTN_START) then
      if state ~= "ready" then reset() end
      state = "play"
      tone(note("C5"), 0.08, "triangle", 0.3)
    end
    return
  end

  if btnp(BTN_B) then
    state = state == "pause" and "play" or "pause"
    return
  end
  if state == "pause" then return end

  for button in pairs(DIRS) do
    if btnp(button) then queue_turn(button) end
  end

  step_timer = step_timer + 1
  if step_timer >= step_frames then
    step_timer = 0
    step()
  end
end

local function draw_background()
  cls(C.bg)

  -- Organische, ruhige Flächen statt eines geometrischen Rasters.
  for x = -20, SCREEN_W + 20, 54 do
    local wobble = flr((x / 54) % 3) * 7
    circfill(x, SCREEN_H - 2 + wobble, 28, C.bg2)
  end

  for x = 12, SCREEN_W, 41 do
    local y = 35 + (x * 7) % 170
    line(x, y, x + 3, y - 4, C.grass)
    line(x + 3, y - 4, x + 7, y, C.grass)
  end
end

function _draw()
  draw_background()

  rectfill(0, 0, SCREEN_W - 1, TOP - 1, C.panel)
  print("MIEZNAKE", 7, 7, C.silver)
  print("PUNKTE " .. score, 112, 7, C.white)
  print("BEST " .. best, 242, 7, C.blue)

  if treat then
    local tx = treat.x * CELL + 2
    local ty = TOP + treat.y * CELL + 2
    S.draw("treat", tx, ty + ((frame() // 12) % 2))
  end

  for i = #cat, 1, -1 do
    draw_cat_segment(cat[i], i)
  end

  if state == "ready" then
    rectfill(42, 70, 278, 169, C.panel)
    centered("MIEZNAKE", 83, C.silver, 3)
    centered("Leckerli sammeln", 116, C.white)
    centered("Steuern: Steuerkreuz", 132, C.white)
    centered("A / START: Los", 148, C.blue)
    centered("B: Pause", 162, C.white)
  elseif state == "pause" then
    rectfill(95, 94, 225, 139, C.panel)
    centered("PAUSE", 105, C.blue, 2)
    centered("B: Weiter", 129, C.white)
  elseif state == "over" or state == "won" then
    rectfill(52, 76, 268, 164, C.panel)
    centered(state == "won" and "ALLE LECKERLI!" or "MIAU. AUS.", 88,
      state == "won" and C.blue or C.silver, 2)
    centered("Punkte " .. score .. "   Best " .. best, 119, C.white)
    centered("A / START: Nochmal", 142, C.blue)
  end
end
