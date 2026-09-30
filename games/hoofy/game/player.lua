-- Die Spielfigur: läuft mit dem Steuerkreuz, rennt mit B (E1, mit Staubwölkchen), hinterlässt eine
-- Spur für die Leine.
local Body = require("lib.body")
local U = require("lib.util")

local Player = {}
Player.__index = Player

local WALK, RUN = 1.2, 2.1
local SPRITES = {
  down = {"player_down", "player_down_walk"},
  up = {"player_up", "player_up_walk"},
  side = {"player_side", "player_side_walk"},
}
local XRAY = {}
for dir, list in pairs(SPRITES) do
  XRAY[dir] = {(list[1]:gsub("^player", "xray")), (list[2]:gsub("^player", "xray"))}
end

function Player.new(ctx, x, y)
  return setmetatable({
    ctx = ctx, x = x, y = y, fw = 8, fh = 4, reach = 24,
    dir = "down", anim = 0, moving = false, running = false, frozen = false, dust_t = 0,
    knock_t = 0, kvx = 0, kvy = 0,
  }, Player)
end

function Player:update()
  self.moving = false
  if self.frozen then return end
  if self.knock_t > 0 then
    -- Weggestoßen (z. B. von einer Zicke): kurz keine Steuerung.
    self.knock_t = self.knock_t - 1
    Body.move(self, self.kvx, self.kvy, self.ctx.map)
    self.kvx, self.kvy = self.kvx * 0.85, self.kvy * 0.85
    self.ctx.trail:push(self.x, self.y)
    return
  end
  local dx, dy = 0, 0
  if btn(BTN_LEFT) then dx = dx - 1 end
  if btn(BTN_RIGHT) then dx = dx + 1 end
  if btn(BTN_UP) then dy = dy - 1 end
  if btn(BTN_DOWN) then dy = dy + 1 end
  self.running = btn(BTN_B)
  if dx == 0 and dy == 0 then return end
  local speed = self.running and RUN or WALK
  if dx ~= 0 and dy ~= 0 then speed = speed * 0.7071 end
  local ok_x, ok_y = Body.move(self, dx * speed, dy * speed, self.ctx.map)
  self.dir = U.facing(dx, dy, self.dir)
  self.moving = (ok_x and dx ~= 0) or (ok_y and dy ~= 0)
  if self.moving then
    self.anim = self.anim + (self.running and 0.18 or 0.12)
    self.ctx.trail:push(self.x, self.y)
    if self.running then
      self.dust_t = self.dust_t - 1
      if self.dust_t <= 0 then
        self.dust_t = 9
        self.ctx.fx:spawn(self.x - dx * 5, self.y - 1, {sprite = "dust", vx = -dx * 0.3, vy = -0.25, life = 16})
      end
    end
  end
end

-- Wegstoßen: frames lang mit vx, vy (bremst ab), ohne Steuerung.
function Player:knock(vx, vy, frames)
  self.kvx, self.kvy, self.knock_t = vx, vy, frames
end

-- Hand, an der der Strick hängt.
function Player:hand()
  if self.dir == "right" then return self.x + 2, self.y - 8 end
  if self.dir == "left" then return self.x - 2, self.y - 8 end
  if self.dir == "up" then return self.x + 4, self.y - 9 end
  return self.x - 4, self.y - 8
end

function Player:draw_shadow()
  local c = self.ctx.map:ground_at(self.x, self.y)
  c = c and c.shadow or 0
  local x, y = flr(self.x), flr(self.y)
  rectfill(x - 5, y - 1, x + 5, y, c)
  rectfill(x - 3, y - 2, x + 3, y + 1, c)
end

-- prefix: "player" (normal) oder "xray" (Umriss, wenn die Figur verdeckt ist)
function Player:draw(prefix)
  local S = self.ctx.S
  local names = prefix == "xray" and XRAY or SPRITES
  local phase = self.moving and flr(self.anim) % 4 or 0
  local step = (phase == 1 or phase == 3) and 2 or 1
  local x, y = flr(self.x), flr(self.y)
  if self.dir == "left" or self.dir == "right" then
    S.draw(names.side[step], x - 6, y - 19, self.dir == "left")
  else
    S.draw(names[self.dir][step], x - 6, y - 19, phase == 3)
  end
end

-- Verdeckt ein Baum oder Haus die Figur, zeichnet die Welt danach den Umriss (lib/world.lua).
function Player:xray_box()
  return self.x - 6, self.y - 19, self.x + 6, self.y
end

function Player:draw_xray()
  self:draw("xray")
end

return Player
