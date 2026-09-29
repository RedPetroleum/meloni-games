-- Snake for the HU-086 (Meloni API, see docs/API.md)
-- D-pad: steer   A/START: start   B: pause

local CELL = 16
local COLS, ROWS = 20, 14          -- playfield below a 16 px status bar
local TOP = 16
local DIRS = {
  [BTN_UP] = {0, -1}, [BTN_DOWN] = {0, 1}, [BTN_LEFT] = {-1, 0}, [BTN_RIGHT] = {1, 0},
}

local state        -- 'ready', 'play', 'pause', 'over', 'won'
local snake        -- list of {x, y}, head first
local dir, turns   -- current direction and queued turns (max 2)
local food
local score, best = 0, 0
local step_frames, step_timer

local function occupied(x, y)
  for _, s in ipairs(snake) do
    if s.x == x and s.y == y then return true end
  end
  return false
end

local function place_food()
  local free = {}
  for y = 0, ROWS - 1 do
    for x = 0, COLS - 1 do
      if not occupied(x, y) then free[#free + 1] = {x = x, y = y} end
    end
  end
  food = rnd(free)          -- nil when the board is full
end

local function reset()
  snake = {{x = 6, y = 7}, {x = 5, y = 7}, {x = 4, y = 7}}
  dir = {1, 0}
  turns = {}
  score = 0
  step_frames, step_timer = 9, 0
  place_food()
end

function _init()
  local save = loaddata()
  if save and save.best then best = save.best end
  reset()
  state = 'ready'
end

local function game_over(won)
  state = won and 'won' or 'over'
  if score > best then
    best = score
    savedata({best = best})
  end
  if won then
    tune('C5:0.5 E5:0.5 G5:0.5 C6:2', 180, 'triangle', 0.4)
  else
    tune('G3:0.5 E3:0.5 C3:2', 160, 'saw', 0.3)
  end
end

local function queue_turn(b)
  local last = turns[#turns] or dir
  local d = DIRS[b]
  -- ignore turns into the same axis (no reversing into yourself)
  if #turns < 2 and d[1] ~= -last[1] and d[2] ~= -last[2] and (d[1] ~= last[1] or d[2] ~= last[2]) then
    turns[#turns + 1] = d
  end
end

local function step()
  if #turns > 0 then dir = table.remove(turns, 1) end
  local head = snake[1]
  local nx, ny = head.x + dir[1], head.y + dir[2]
  if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS then return game_over(false) end

  local eating = food and nx == food.x and ny == food.y
  if not eating then table.remove(snake) end   -- the tail moves away first
  if occupied(nx, ny) then return game_over(false) end
  table.insert(snake, 1, {x = nx, y = ny})

  if eating then
    score = score + 1
    tone(note('E5'), 0.06, 'square', 0.4)
    if score % 5 == 0 and step_frames > 3 then step_frames = step_frames - 1 end
    place_food()
    if not food then return game_over(true) end
  end
end

function _update()
  if state == 'ready' or state == 'over' or state == 'won' then
    if btnp(BTN_A) or btnp(BTN_START) then
      if state ~= 'ready' then reset() end
      state = 'play'
      tone(note('C5'), 0.08, 'pulse', 0.4)
    end
    return
  end

  if btnp(BTN_B) then
    state = state == 'pause' and 'play' or 'pause'
    return
  end
  if state == 'pause' then return end

  for b in pairs(DIRS) do
    if btnp(b) then queue_turn(b) end
  end

  step_timer = step_timer + 1
  if step_timer >= step_frames then
    step_timer = 0
    step()
  end
end

local function centered(text, y, c, scale)
  scale = scale or 1
  print(text, (SCREEN_W - textw(text, scale)) // 2, y, c, scale)
end

function _draw()
  cls(1)
  -- status bar
  rectfill(0, 0, SCREEN_W - 1, TOP - 1, 0)
  print('SCORE ' .. score, 4, 4, 7)
  local best_text = 'BEST ' .. best
  print(best_text, SCREEN_W - 4 - textw(best_text), 4, 10)

  -- checkerboard playfield
  for y = 0, ROWS - 1 do
    for x = 0, COLS - 1 do
      if (x + y) % 2 == 0 then
        rectfill(x * CELL, TOP + y * CELL, x * CELL + CELL - 1, TOP + y * CELL + CELL - 1, 17)
      end
    end
  end

  if food then
    circfill(food.x * CELL + 7, TOP + food.y * CELL + 7, 6, 8)
    pset(food.x * CELL + 9, TOP + food.y * CELL + 3, 11)
  end

  for i = #snake, 1, -1 do
    local s = snake[i]
    local px, py = s.x * CELL, TOP + s.y * CELL
    rectfill(px + 1, py + 1, px + CELL - 2, py + CELL - 2, i == 1 and 11 or 3)
    if i == 1 then
      -- eyes look in the moving direction
      local ex, ey = 4 + dir[1] * 3, 4 + dir[2] * 3
      rectfill(px + ex + 1, py + ey + 1, px + ex + 2, py + ey + 2, 0)
      rectfill(px + ex + 7, py + ey + 1, px + ex + 8, py + ey + 2, 0)
    end
  end

  if state == 'ready' then
    rectfill(40, 80, 279, 170, 0)
    centered('SNAKE', 92, 11, 4)
    centered('Press A or START', 140, 7)
    centered('B pauses', 154, 6)
  elseif state == 'pause' then
    centered('PAUSE', 110, 7, 3)
  elseif state == 'over' or state == 'won' then
    rectfill(40, 80, 279, 170, 0)
    centered(state == 'won' and 'YOU WIN!' or 'GAME OVER', 96, state == 'won' and 10 or 8, 3)
    centered('Score ' .. score .. '   Best ' .. best, 130, 7)
    centered('A or START: play again', 150, 6)
  end
end
