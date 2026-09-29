-- Neues Meloni-Spiel. API: docs/API.md
-- Spielen am Rechner: make run GAME=<name>

local player = {x = 152, y = 112, speed = 2}
local best = 0

function _init()
  local save = loaddata()
  if save then best = save.best or 0 end
end

function _update()
  if btn(BTN_LEFT) then player.x = player.x - player.speed end
  if btn(BTN_RIGHT) then player.x = player.x + player.speed end
  if btn(BTN_UP) then player.y = player.y - player.speed end
  if btn(BTN_DOWN) then player.y = player.y + player.speed end
  player.x = mid(0, player.x, SCREEN_W - 16)
  player.y = mid(16, player.y, SCREEN_H - 16)

  if btnp(BTN_A) then
    tone(note('C5'), 0.1, 'square', 0.4)
    best = best + 1
    savedata({best = best})
  end
end

function _draw()
  cls(1)
  print('A drücken: ' .. best, 4, 4, 7)
  rectfill(player.x, player.y, player.x + 15, player.y + 15, 11)
end
