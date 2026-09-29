-- Ein Pferd: läuft frei herum, folgt am Strick oder steht zu Hause auf der Koppel.
-- Was ein Pferd besonders macht, steht in seinem Charakterzug (game/traits.lua).
local Body = require("lib.body")
local U = require("lib.util")
local Traits = require("game.traits")

local Horse = {}
Horse.__index = Horse

local LEAD_SPEED = 2.4   -- so schnell holt ein geführtes Pferd höchstens auf
local POSES = {"side", "side_walk", "graze", "down", "down_walk", "up", "up_walk"}

-- Sprite-Namen je Fellfarbe einmal zusammensetzen statt in jedem Frame.
local names_cache = {}
local function names_for(coat)
  local n = names_cache[coat]
  if not n then
    n = {}
    for _, pose in ipairs(POSES) do n[pose] = coat .. "_" .. pose end
    names_cache[coat] = n
  end
  return n
end

-- def: {name, coat, trait} aus dem Level
function Horse.new(ctx, def, x, y)
  local trait = Traits[def.trait or "brav"]
  if not trait then error("unknown trait " .. tostring(def.trait)) end
  local h = setmetatable({
    ctx = ctx, name = def.name, coat = def.coat or "horse", trait = trait,
    names = names_for(def.coat or "horse"),
    x = x, y = y, fw = 14, fh = 6, reach = 40,
    dir = rnd(1) < 0.5 and "left" or "right",
    state = "idle", timer = flr(rnd(120)), grazing = rnd(1) < 0.5,
    home = false, led = false, stubborn = 0, stuck = 0, lead_dist = 20,
    anim = 0, moving = false, bubble = nil, bubble_t = 0, is_horse = true,
  }, Horse)
  local map = ctx.map
  -- Freie Pferde bleiben draußen, Pferde zu Hause bleiben auf der Koppel.
  h.allow = function(px, py)
    return (map:tag_at(px, py) == "paddock") == h.home
  end
  return h
end

function Horse:emote(name, frames)
  self.bubble, self.bubble_t = name, frames or 60
end

function Horse:head_x()
  if self.dir == "right" then return self.x + 11 end
  if self.dir == "left" then return self.x - 11 end
  return self.x
end

function Horse:head_y()
  if self.dir == "up" then return self.y - 21 end
  if self.dir == "down" then return self.y - 14 end
  return self.y - 16
end

-- Abstand von px, py zum Pferdekörper (nicht nur zu den Hufen: ein Pferd ist lang).
function Horse:distance_to(px, py)
  local side = self.dir == "left" or self.dir == "right"
  local cx = mid(self.x - (side and 11 or 5), px, self.x + (side and 11 or 5))
  local cy = mid(self.y - (side and 8 or 14), py, self.y)
  return U.dist(cx, cy, px, py)
end

function Horse:idle(frames)
  self.state = "idle"
  self.timer = frames or flr((60 + rnd(160)) * (self.trait.graze or 1))
  self.grazing = (self.dir == "left" or self.dir == "right") and rnd(1) < 0.6
end

-- Zufälliges freies Ziel in der Nähe suchen.
function Horse:wander()
  local map = self.ctx.map
  for _ = 1, 6 do
    local a = rnd(1) * math.pi * 2
    local d = 20 + rnd(60)
    local tx, ty = self.x + math.cos(a) * d, self.y + math.sin(a) * d
    if Body.free(map, tx, ty, self.fw, self.fh) and self.allow(tx, ty) then
      self.state, self.tx, self.ty, self.timer = "walk", tx, ty, 240
      self.grazing = false
      return
    end
  end
  self:idle(60)
end

function Horse:flee_from(px, py)
  local dx, dy = self.x - px, self.y - py
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1 then dx, dy, d = 1, 0, 1 end
  self.state = "flee"
  self.tx, self.ty = self.x + dx / d * 80, self.y + dy / d * 80
  self.timer = 70
  self.grazing = false
  self:emote("emo_bang", 50)
end

function Horse:walk_to(tx, ty, speed)
  local dx, dy = tx - self.x, ty - self.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < speed then return true end
  local mx, my = dx / d * speed, dy / d * speed
  local ok_x, ok_y = Body.move(self, mx, my, self.ctx.map, self.allow)
  self.dir = U.facing(mx, my, self.dir)
  self.moving = ok_x or ok_y
  return not self.moving
end

function Horse:update_loose()
  local t = self.trait
  if t.loose and not self.home then t.loose(self, self.ctx) end
  if self.state == "idle" then
    self.timer = self.timer - 1
    if self.timer <= 0 then self:wander() end
    return
  end
  local speed = self.state == "flee" and 2.2 or t.speed
  self.timer = self.timer - 1
  if self:walk_to(self.tx, self.ty, speed) or self.timer <= 0 then self:idle() end
end

function Horse:update_led()
  local ctx = self.ctx
  if self.trait.led and self.trait.led(self, ctx) then return end
  local p = ctx.player
  local tx, ty = ctx.trail:point_at(p.x, p.y, self.lead_dist)
  local dx, dy = tx - self.x, ty - self.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1.5 then return end
  local speed = min(LEAD_SPEED, 0.5 + d * 0.2)
  local mx, my = dx / d * speed, dy / d * speed
  local ok_x, ok_y = Body.move(self, mx, my, ctx.map)
  if ok_x or ok_y then
    self.stuck = 0
  else
    -- Hängt an einer Ecke fest: der Strick zieht es drüber.
    self.stuck = self.stuck + 1
    if self.stuck > 20 then self.x, self.y = self.x + mx, self.y + my end
  end
  self.dir = U.facing(mx, my, self.dir)
  self.moving = true
end

function Horse:update()
  self.moving = false
  if self.bubble_t > 0 then
    self.bubble_t = self.bubble_t - 1
    if self.bubble_t == 0 then self.bubble = nil end
  end
  if self.led then self:update_led() else self:update_loose() end
  if self.moving then
    self.anim = self.anim + (self.state == "flee" and 0.2 or 0.12)
    self.grazing = false
  end
end

function Horse:draw_shadow()
  local c = self.ctx.map:ground_at(self.x, self.y)
  c = c and c.shadow or 0
  local x, y = flr(self.x), flr(self.y)
  if self.dir == "left" or self.dir == "right" then
    rectfill(x - 11, y - 2, x + 11, y, c)
    rectfill(x - 8, y - 3, x + 8, y + 1, c)
  else
    rectfill(x - 6, y - 2, x + 6, y, c)
    rectfill(x - 4, y - 3, x + 4, y + 1, c)
  end
end

function Horse:draw()
  local n, img, S = self.names, self.ctx.S.img, self.ctx.S
  local phase = self.moving and flr(self.anim) % 4 or 0
  local step = phase == 1 or phase == 3
  local x, y = flr(self.x), flr(self.y)
  if self.dir == "right" or self.dir == "left" then
    local name = self.grazing and n.graze or (step and n.side_walk or n.side)
    local left = self.dir == "left"
    S.draw(name, left and x - 17 or x - 12, y - 22, left)
  elseif self.dir == "down" then
    S.draw(step and n.down_walk or n.down, x - 8, y - 24, phase == 3)
  else
    S.draw(step and n.up_walk or n.up, x - 8, y - 23, phase == 3)
  end
end

function Horse:draw_over()
  local x, y = flr(self.x), flr(self.y)
  if self.bubble then
    self.ctx.S.draw(self.bubble, flr(self:head_x()) - 7, y - 42)
  end
  local p = self.ctx.player
  if not self.led and not self.home and p and U.dist(p.x, p.y, self.x, self.y) < 48 then
    local w = textw(self.name)
    rectfill(x - w // 2 - 2, y + 3, x + w // 2 + 1, y + 12, self.ctx.colors.panel)
    print(self.name, x - w // 2, y + 4, self.ctx.colors.text)
  end
end

return Horse
