-- Wildpferde im Gebiet: so viele gleichzeitig wie im Katalog (KATALOG §10), sie grasen, wandern
-- und fliehen vor dem Spieler. Alle 3 Tage (KATALOG §1) gehen 1–2 weg, neue kommen nach.
-- Weit entfernte Pferde werden nur selten aktualisiert.
local K = require("game.katalog")
local H = require("game.horse_model")
local G = require("game.horse_gfx")
local Body = require("lib.body")
local Bubbles = require("game.bubbles")
local Leash = require("game.leash")
local Ride = require("game.ride")
local Farm = require("game.farm")
local Rng = require("lib.rng")
local U = require("lib.util")

local Wild = {}
Wild.Horse = nil

-- Zähmen (E16): In der Zone (ZONE Pixel um das Pferd) schaut es 2–4 s weg (kürzer bei niedriger
-- Bindung), warnt 0,3 s (❗), schaut 1–2 s her. Bewegt sich der Spieler, während es hinschaut,
-- flieht es. Nah genug (TAME_DIST) und A drücken: gezähmt.
local ZONE = 110
local TAME_DIST = 26
local WARN = 18          -- 0,3 s
local LEAVE = 140        -- so weit weg beruhigt sich das Pferd wieder
local CALM_DIST = 110    -- nach der Flucht erst ab hier wieder grasen
local FAR = 420          -- weiter weg: nur alle FAR_EVERY Frames bewegen
local FAR_EVERY = 30

local Horse = {}
Horse.__index = Horse
Wild.Horse = Horse

function Horse.new(ctx, data, x, y)
  return setmetatable({
    ctx = ctx, data = data, x = x, y = y, fw = 14, fh = 6, reach = 40, is_horse = true, wild = true,
    coat = data.farbe, body = H.body(data), dir = rnd() < 0.5 and "left" or "right",
    state = "graze", timer = 60 + flr(rnd(180)), anim = 0, vx = 0, vy = 0, tick = flr(rnd(FAR_EVERY)),
  }, Horse)
end

-- Kopf des Pferds (Weltkoordinaten), dort hängt das Seil.
function Horse:head()
  return self.x + (self.dir == "right" and 11 or -11), self.y - 14
end

function Horse:distance_to(x, y)
  return U.dist(self.x, self.y, x, y)
end

local function set_state(h, state, frames)
  if h.debug_log and h.state ~= state then log("ZAEHMEN " .. frame() .. " " .. h.state .. " -> " .. state) end
  h.state, h.timer = state, frames
end

function Horse:step(dx, dy)
  local ok_x, ok_y = Body.move(self, dx, dy, self.ctx.map, self.allow)
  if dx ~= 0 then self.dir = dx > 0 and "right" or "left" end
  return ok_x or ok_y
end

-- Gezähmtes Pferd: "led" an der Leine, "follow" frei hinterher (Bindung ≥ 70), "free" lose,
-- "stand" bleibt stehen.
function Horse:update_tamed()
  if self.state == "stall" then return end
  local ctx, p = self.ctx, self.ctx.player
  local st = self.state
  self.moving = false
  if st == "ridden" then
    local r = self.rider
    self.x, self.y, self.moving, self.speed = r.x, r.y, r.moving, r.running and 3 or 1
    self.anim = r.anim
    self.ride_dir = r.dir
    self.dir = (r.dir == "left" or r.dir == "right") and r.dir or self.dir
  elseif st == "led" or st == "follow" then
    local i = 1
    for n, h in ipairs(ctx.lead) do if h == self then i = n end end
    local tx, ty = ctx.trail:point_at(p.x, p.y, Leash.lead_dist(i))
    local dx, dy = tx - self.x, ty - self.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d > 2 then
      local v = min(Leash.SPEED, d * 0.25 + 0.3)
      local ok = self:step(dx / d * v, dy / d * v)
      self.moving = ok
      self.anim = self.anim + v * 0.06
      self.speed = v
    else
      self.speed = 0
    end
    -- Die Leine reißt: geführte Pferde (nicht frei folgende) würfeln einmal pro Sekunde.
    if st == "led" then
      self.leash_t = (self.leash_t or 0) + 1
      if self.leash_t >= 60 then
        self.leash_t = 0
        local mode = p.riding and "reiten" or (p.running and "sprinten" or "gehen")
        if Leash.escape_roll(self.data.bindung, mode, self.data.zug) then ctx.wild:escape(self) end
      end
    end
  elseif st == "free" then
    self.timer = self.timer - 1
    if self.timer <= 0 then
      if self.vx ~= 0 or self.vy ~= 0 then self.vx, self.vy = 0, 0; self.timer = 120 + flr(rnd() * 200)
      else
        local a = rnd() * 2 * math.pi
        self.vx, self.vy = math.cos(a) * 0.3, math.sin(a) * 0.18
        self.timer = 60 + flr(rnd() * 90)
      end
    end
    if self.vx ~= 0 or self.vy ~= 0 then
      if not self:step(self.vx, self.vy) then self.vx, self.vy = 0, 0 end
      self.anim = self.anim + 0.12
      self.moving = true
    end
  elseif st == "escape" then
    local mx, my = self:step(self.vx, 0), self:step(0, self.vy)
    self.anim = self.anim + 0.25
    self.timer = self.timer - 1
    if self.timer <= 0 or not (mx or my) then
      self.state, self.timer, self.vx, self.vy = "free", 120, 0, 0
    end
  end
end

function Horse:update()
  if self.tamed then return self:update_tamed() end
  local p = self.ctx.player
  local d = U.dist(self.x, self.y, p.x, p.y)
  if d > FAR then
    self.tick = self.tick + 1
    if self.tick % FAR_EVERY ~= 0 then return end
    self.timer = self.timer - FAR_EVERY
    if self.timer <= 0 then set_state(self, "graze", 120 + flr(rnd(240))) end
    return
  end
  self.timer = self.timer - 1
  self.cool = max(0, (self.cool or 0) - 1)
  local watching = self.state == "away" or self.state == "warn" or self.state == "look"
  if not watching and self.state ~= "flee" and d < ZONE and self.cool == 0 then
    local bond = self.data.bindung
    local frames = (120 + rnd() * 120) * (0.5 + bond / 200)
    set_state(self, "away", flr(frames))
    watching = true
  end
  if watching then
    if d > LEAVE then
      set_state(self, "graze", 60)
    elseif self.state == "away" then
      if self.timer <= 0 then set_state(self, "warn", WARN); self:face(p) end
    elseif self.state == "warn" then
      if self.timer <= 0 then set_state(self, "look", 60 + flr(rnd() * 60)) end
    elseif self.state == "look" then
      self:face(p)
      if p.moving then self:flee(p) elseif self.timer <= 0 then set_state(self, "away", flr((120 + rnd() * 120) * (0.5 + self.data.bindung / 200))) end
    end
    return
  end
  if self.state == "flee" then
    local mx, my = self:step(self.vx, 0), self:step(0, self.vy)   -- beide Achsen, rutscht an Hindernissen
    local moved = mx or my
    self.anim = self.anim + 0.25
    if not moved or (self.timer <= 0 and d > CALM_DIST) then set_state(self, "idle", 40); self.cool = 240 end
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

function Horse:face(p)
  self.dir = p.x >= self.x and "right" or "left"
end

function Horse:flee(p)
  set_state(self, "flee", 90)
  local ax, ay = self.x - p.x, self.y - p.y
  local n = max(1, U.dist(0, 0, ax, ay))
  self.vx, self.vy = ax / n * 1.7, ay / n * 1.7
  self.dir = self.vx >= 0 and "right" or "left"
end

function Horse:pose()
  if self.state == "ridden" then
    local d, walk = self.ride_dir, flr(self.anim * 3) % 2 == 1
    if d == "up" or d == "down" then
      return d .. (self.moving and walk and "_walk" or "")
    end
    if self.rider.running and self.moving then return (flr(self.anim * 2) % 2 == 0) and "gallop1" or "gallop2" end
    return (self.moving and walk) and "side_walk" or "side"
  end
  if self.tamed then
    if self.state == "escape" then return (flr(self.anim * 2) % 2 == 0) and "gallop1" or "gallop2" end
    if self.moving then
      if (self.speed or 0) > 1.8 then return (flr(self.anim * 2) % 2 == 0) and "gallop1" or "gallop2" end
      return (flr(self.anim * 3) % 2 == 0) and "side" or "side_walk"
    end
    return "side"
  end
  if self.state == "away" then return "graze" end
  if self.state == "warn" or self.state == "look" then return "side" end
  if self.state == "flee" then return (flr(self.anim * 2) % 2 == 0) and "gallop1" or "gallop2" end
  if self.state == "walk" then return (flr(self.anim * 3) % 2 == 0) and "side" or "side_walk" end
  if self.state == "graze" then return "graze" end
  return "side"
end

function Horse:draw_shadow()
  if self.hidden then return end
  local c = self.ctx.map:ground_at(self.x, self.y)
  c = c and c.shadow or 0
  local x, y = flr(self.x), flr(self.y)
  rectfill(x - 11, y - 1, x + 11, y, c)
  rectfill(x - 8, y - 2, x + 8, y + 1, c)
end

function Horse:draw()
  if self.hidden then return end
  local r = self.rider
  local lift = r and r.air or 0
  G.draw(self.coat, self.body, self:pose(), self.x, self.y - lift, self.dir == "left")
  if r then
    -- Reiter auf dem Rücken: Figur der Blickrichtung
    local _, bh = G.size(self.coat, self.body, "side")
    local S = self.ctx.S
    local names = {down = "player_down", up = "player_up", left = "player_side", right = "player_side"}
    local d = self.ride_dir or "right"
    S.draw(names[d], flr(self.x) - 6, flr(self.y - lift) - bh + 4 - 10, d == "left")
  end
end

-- Blase über dem Kopf (E10). Wildpferde, die fliehen, haben Angst.
function Horse:draw_over()
  if self.hidden then return end
  if self.state == "flee" or self.state == "escape" then self.scared = true elseif not self.demo then self.scared = false end
  local b = self.state == "warn" and "emo_bang" or Bubbles.choose(self, frame())
  if b then Bubbles.draw(self.ctx.S, b, self.x + (self.dir == "right" and 10 or -10), self.y - 28, frame()) end
end

-- Ein Wildpferd in Reichweite wird gezähmt (A gedrückt, nicht auf der Flucht). Gibt es zurück.
function Wild:try_tame()
  local p = self.ctx.player
  for i, h in ipairs(self.list) do
    if h.state ~= "flee" and U.dist(h.x, h.y, p.x, p.y) <= TAME_DIST then
      table.remove(self.list, i)
      h.wild, h.data.wild, h.tamed = false, nil, true
      self.ctx.herd[#self.ctx.herd + 1] = h.data
      self.ctx.herd_horses[#self.ctx.herd_horses + 1] = h
      self:attach(h)
      return h
    end
  end
end

-- Stellt die Wildpferde ein. Gibt den Verwalter {ctx, list, rng, slot} zurück.
function Wild.new(ctx, seed, near)
  ctx.herd, ctx.herd_horses, ctx.lead = ctx.herd or {}, ctx.herd_horses or {}, ctx.lead or {}
  local self = {ctx = ctx, list = {}, rng = Rng.new(seed or 1), gebiet = ctx.area.nr, near = near}
  self.count = ctx.area.info.wildpferde
  self = setmetatable(self, {__index = Wild})
  ctx.wild = self
  return self
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

-- Nimmt ein gezähmtes Pferd mit: an die Leine, ab Bindung 70 frei folgend (max. MAX_LEAD).
function Wild:attach(h)
  h.data.ort, h.bounds, h.allow, h.hidden = nil, nil, nil, false
  local lead = self.ctx.lead
  if #lead >= 4 then h.state, h.timer = "free", 60; return false end
  lead[#lead + 1] = h
  h.state = h.data.bindung >= Leash.FOLLOW and "follow" or "led"
  h.leash_t = 0
  return true
end

-- Die Leine reißt: Pferd läuft weg und bleibt dort lose stehen.
function Wild:escape(h)
  for i, e in ipairs(self.ctx.lead) do
    if e == h then table.remove(self.ctx.lead, i) break end
  end
  local p = self.ctx.player
  local ax, ay = h.x - p.x, h.y - p.y
  local n = max(1, U.dist(0, 0, ax, ay))
  h.vx, h.vy = ax / n * 1.8, ay / n * 1.8
  h.state, h.timer = "escape", 70
  h.scared = true
  self.ctx.escaped = h
  return h
end

-- A bei einem geführten oder folgenden Pferd in Reichweite: aufsteigen. Gibt Pferd und Ergebnis
-- ("ok" oder "verweigert") zurück, nil wenn keins in Reichweite ist.
function Wild:try_mount()
  local p = self.ctx.player
  if p.riding then return nil end
  local best, bd = nil, Ride.REACH
  for _, h in ipairs(self.ctx.lead) do
    local d = U.dist(h.x, h.y, p.x, p.y)
    if d <= bd then best, bd = h, d end
  end
  if not best then return nil end
  if Ride.refuses(best.data, self.rng) then return best, "verweigert" end
  Ride.mount(self.ctx, best)
  return best, "ok"
end

-- Eigenes Pferd (geführt, folgend oder lose) in Reichweite des Spielers, nächstes zuerst.
function Wild:nearest_own()
  local p = self.ctx.player
  local best, bd = nil, Ride.REACH
  for _, h in ipairs(self.ctx.herd_horses) do
    if h.state ~= "ridden" and h.state ~= "escape" and not h.hidden then
      local d = U.dist(h.x, h.y, p.x, p.y)
      if d <= bd then best, bd = h, d end
    end
  end
  return best
end

-- Aufsitzen auf h (Menü, E2): "ok" oder "verweigert".
function Wild:mount(h)
  if Ride.refuses(h.data, self.rng) then return "verweigert" end
  Ride.mount(self.ctx, h)
  return "ok"
end

-- Leine lösen: das Pferd bleibt lose stehen.
function Wild:release(h)
  for i, e in ipairs(self.ctx.lead) do
    if e == h then table.remove(self.ctx.lead, i) break end
  end
  h.state, h.timer, h.vx, h.vy = "free", 90, 0, 0
end

-- Ein eigenes (gezähmtes) Pferd hinzufügen (Szenarien, Tests; später Kauf, Zucht). Gibt es zurück,
-- noch weder an der Leine noch untergebracht. opts: Felder wie H.wild plus bindung, sattel.
function Wild:add_own(opts)
  opts = opts or {}
  local p = self.ctx.player
  local h = self:spawn_at(p.x, p.y + 16, {rasse = opts.rasse or "haflinger", rng = self.rng, zug = opts.zug})
  table.remove(self.list)
  h.wild, h.data.wild, h.tamed = false, nil, true
  if opts.bindung then h.data.bindung = opts.bindung end
  if opts.name then h.data.name = opts.name end
  h.data.sattel = opts.sattel
  h.state = "free"
  self.ctx.herd[#self.ctx.herd + 1] = h.data
  self.ctx.herd_horses[#self.ctx.herd_horses + 1] = h
  return h
end

-- Unterbringung (E32): ort = "stall", "weide" oder "frei". Gibt true oder false und den Grund zurück.
function Wild:house(h, ort)
  local farm = self.ctx.area.farm
  local cap = Farm.capacity(farm)
  local n = Farm.count(self.ctx.herd, ort) - (h.data.ort == ort and 1 or 0)
  if n >= cap[ort] then return false, "voll" end
  if ort == "frei" and not Farm.may_roam(h.data, H) then return false, "zu schwach oder zu scheu" end
  for i, e in ipairs(self.ctx.lead) do
    if e == h then table.remove(self.ctx.lead, i) break end
  end
  h.data.ort = ort
  h.scared = false
  if ort == "stall" then
    h.state, h.hidden = "stall", true
    return true
  end
  local b = ort == "weide" and Farm.weide_bounds(farm) or Farm.plot_bounds(farm)
  h.bounds = b
  h.allow = function(x, y) return x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] end
  -- auf einen freien Platz in der Fläche setzen
  for _ = 1, 100 do
    local x, y = b[1] + rnd() * (b[3] - b[1]), b[2] + rnd() * (b[4] - b[2])
    if not self.ctx.map:blocked(x - 8, y - 6, x + 8, y) then h.x, h.y = x, y break end
  end
  h.state, h.timer, h.vx, h.vy, h.hidden = "free", 60, 0, 0, false
  return true
end

-- Aus Stall, Weide oder freier Haltung zurück an die Leine (Spieler steht daneben).
function Wild:take_out(h)
  local p = self.ctx.player
  h.data.ort, h.bounds, h.allow, h.hidden = nil, nil, nil, false
  h.x, h.y = p.x, p.y + 12
  self:attach(h)
end

-- Pferde im Stall (Liste der Pferd-Objekte).
function Wild:in_stall()
  local out = {}
  for _, h in ipairs(self.ctx.herd_horses) do if h.data.ort == "stall" then out[#out + 1] = h end end
  return out
end

-- Steht der Spieler vor der Stalltür?
function Wild:at_stall_door()
  local d = self.ctx.area.places.stalltuer
  local p = self.ctx.player
  return d and U.dist(p.x, p.y, d[1] * 16 + 8, d[2] * 16 + 8) <= 26
end

-- A bei einem losen gezähmten Pferd in Reichweite: wieder anleinen. Gibt das Pferd zurück.
function Wild:try_leash()
  local p = self.ctx.player
  for _, h in ipairs(self.ctx.herd_horses) do
    if h.state == "free" and U.dist(h.x, h.y, p.x, p.y) <= TAME_DIST + 4 then
      h.scared = false
      return self:attach(h) and h or nil
    end
  end
end

-- Pfiff: lose Pferde mit Bindung ≥ 90 kommen und folgen. Gibt die Anzahl zurück.
function Wild:whistle()
  local n = 0
  for _, h in ipairs(self.ctx.herd_horses) do
    if (h.state == "free" or h.state == "escape") and not h.data.ort and h.data.bindung >= Leash.WHISTLE then
      h.scared = false
      if self:attach(h) then n = n + 1 end
    end
  end
  return n
end

-- Setzt ein Pferd an eine Stelle (Szenarien, Tests).
function Wild:spawn_at(x, y, opts)
  local data = H.wild(opts or {rng = self.rng, gebiet = self.gebiet})
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
