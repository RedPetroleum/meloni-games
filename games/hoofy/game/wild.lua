-- Wildpferde im Gebiet: so viele gleichzeitig wie im Katalog (KATALOG §10), sie grasen, wandern
-- und fliehen vor dem Spieler. Alle 3 Tage (KATALOG §1) gehen 1–2 weg, neue kommen nach.
-- Weit entfernte Pferde werden nur selten aktualisiert.
local K = require("game.katalog")
local H = require("game.horse_model")
local G = require("game.horse_gfx")
local Body = require("lib.body")
local Rng = require("lib.rng")
local U = require("lib.util")

local Wild = {}

local FLEE_DIST = 72     -- so nah darf der Spieler kommen, bevor das Pferd flieht
local CALM_DIST = 110    -- ab hier beruhigt es sich wieder
local FAR = 420          -- weiter weg: nur alle FAR_EVERY Frames bewegen
local FAR_EVERY = 30

local Horse = {}
Horse.__index = Horse

function Horse.new(ctx, data, x, y)
  return setmetatable({
    ctx = ctx, data = data, x = x, y = y, fw = 14, fh = 6, reach = 40, is_horse = true, wild = true,
    coat = data.farbe, body = H.body(data), dir = rnd() < 0.5 and "left" or "right",
    state = "graze", timer = 60 + flr(rnd(180)), anim = 0, vx = 0, vy = 0, tick = flr(rnd(FAR_EVERY)),
  }, Horse)
end

function Horse:distance_to(x, y)
  return U.dist(self.x, self.y, x, y)
end

local function set_state(h, state, frames)
  h.state, h.timer = state, frames
end

function Horse:step(dx, dy)
  local ok_x, ok_y = Body.move(self, dx, dy, self.ctx.map)
  if dx ~= 0 then self.dir = dx > 0 and "right" or "left" end
  return ok_x or ok_y
end

function Horse:update()
  local p = self.ctx.player
  local d = U.dist(self.x, self.y, p.x, p.y)
  if d > FAR then
    self.tick = self.tick + 1
    if self.tick % FAR_EVERY ~= 0 then return end
    self.timer = self.timer - FAR_EVERY
    if self.timer <= 0 then set_state(self, "graze", 120 + flr(rnd(240))) end
    return
  end
  if d < FLEE_DIST and self.state ~= "flee" then
    set_state(self, "flee", 90)
    local ax, ay = self.x - p.x, self.y - p.y
    local n = max(1, U.dist(0, 0, ax, ay))
    self.vx, self.vy = ax / n * 1.7, ay / n * 1.7
    self.dir = self.vx >= 0 and "right" or "left"
  end
  self.timer = self.timer - 1
  if self.state == "flee" then
    local mx, my = self:step(self.vx, 0), self:step(0, self.vy)   -- beide Achsen, rutscht an Hindernissen
    local moved = mx or my
    self.anim = self.anim + 0.25
    if not moved or (self.timer <= 0 and d > CALM_DIST) then set_state(self, "idle", 40) end
    if self.timer <= 0 and d <= CALM_DIST then self.timer = 30 end
  elseif self.state == "walk" then
    local ok = self:step(self.vx, self.vy)
    self.anim = self.anim + 0.12
    if self.timer <= 0 or not ok then set_state(self, "graze", 150 + flr(rnd(250))) end
  elseif self.timer <= 0 then
    if self.state == "graze" and rnd() < 0.6 then
      local a = rnd() * 2 * math.pi
      self.vx, self.vy = math.cos(a) * 0.35, math.sin(a) * 0.35 * 0.6
      set_state(self, "walk", 60 + flr(rnd(120)))
    else
      set_state(self, "graze", 120 + flr(rnd(240)))
    end
  end
end

function Horse:pose()
  if self.state == "flee" then return (flr(self.anim * 2) % 2 == 0) and "gallop1" or "gallop2" end
  if self.state == "walk" then return (flr(self.anim * 3) % 2 == 0) and "side" or "side_walk" end
  if self.state == "graze" then return "graze" end
  return "side"
end

function Horse:draw_shadow()
  local c = self.ctx.map:ground_at(self.x, self.y)
  c = c and c.shadow or 0
  local x, y = flr(self.x), flr(self.y)
  rectfill(x - 11, y - 1, x + 11, y, c)
  rectfill(x - 8, y - 2, x + 8, y + 1, c)
end

function Horse:draw()
  G.draw(self.coat, self.body, self:pose(), self.x, self.y, self.dir == "left")
end

-- Stellt die Wildpferde ein. Gibt den Verwalter {ctx, list, rng, slot} zurück.
function Wild.new(ctx, seed, near)
  local self = {ctx = ctx, list = {}, rng = Rng.new(seed or 1), gebiet = ctx.area.nr, near = near}
  self.count = ctx.area.info.wildpferde
  return setmetatable(self, {__index = Wild})
end

-- Zufällige freie Wiesenkachel weit genug vom Hof und von der Kamera (Pixel).
function Wild:spot()
  local map, rng, area = self.ctx.map, self.rng, self.ctx.area
  local plot, p = area.plot, self.ctx.player
  for _ = 1, 200 do
    local cx, cy = rng:int(3, map.w - 4), rng:int(3, map.h - 4)
    local ok = map:walkable(cx, cy) and map:code(cx, cy) == "."
    if ok and not self.near and cx >= plot.x - 2 and cx < plot.x + plot.w + 2 and cy >= plot.y - 2 and cy < plot.y + plot.h + 2 then
      ok = false
    end
    local d = U.dist(cx * 16, cy * 16, p.x, p.y)
    if ok and self.near then ok = d > 90 and d < 170 end
    if ok and not self.near and d < 200 then ok = false end
    if ok and map:blocked(cx * 16 - 8, cy * 16 - 4, cx * 16 + 24, cy * 16 + 16) then ok = false end
    if ok then return cx * 16 + 8, cy * 16 + 14 end
  end
end

function Wild:spawn()
  local x, y = self:spot()
  if not x then return nil end
  local data = H.wild({gebiet = self.gebiet, rng = self.rng})
  local h = Horse.new(self.ctx, data, x, y)
  self.list[#self.list + 1] = h
  self.ctx.world:add(h)
  return h
end

function Wild:fill()
  while #self.list < self.count do
    if not self:spawn() then break end
  end
end

-- Tageswechsel (alle 3 Tage): 1–2 Pferde verschwinden, neue kommen nach.
function Wild:rotate()
  local n = self.rng:int(K.zeit.wild_wechsel_min, K.zeit.wild_wechsel_max)
  local gone = 0
  for _ = 1, n do
    if #self.list == 0 then break end
    local i = self.rng:int(1, #self.list)
    local h = table.remove(self.list, i)
    h.dead = true
    gone = gone + 1
  end
  self:fill()
  return gone
end

-- Wird bei jedem neuen Tag aufgerufen (day = Tageszähler, ab 1).
function Wild:new_day(day)
  if day > 1 and (day - 1) % K.zeit.wild_wechsel_tage == 0 then return self:rotate() end
  return 0
end

return Wild
