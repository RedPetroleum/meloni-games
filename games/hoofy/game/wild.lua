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
local SFX = require("game.sfx")
local Farm = require("game.farm")
local Rng = require("lib.rng")
local U = require("lib.util")

local Wild = {}
Wild.Horse = nil

-- Zähmen (E16): In der Zone (ZONE Pixel um das Pferd) schaut es 2–4 s weg (kürzer bei niedriger
-- Bindung), warnt 0,3 s (❗), schaut 1–2 s her. Bewegt sich der Spieler, während es hinschaut,
-- flieht es. Schwerer gemacht (Rückmeldung 1.2.1): Wer in der Zone sprintet, verscheucht es; A muss man
-- nah genug (TAME_DIST) drücken, während es wegschaut, und dann stillstehend halten (Wild.tame_frames).
-- Es hört auch (Rückmeldung 1.3.4): Gehen in der Zone füllt einen verborgenen Lärmpegel (nah schneller),
-- Stehen leert ihn. Ab NOISE_ON zeigt es ❗, bis er unter NOISE_OFF fällt; ist er voll, flieht es.
local ZONE = 110
local TAME_DIST = 26
local WARN = 18          -- 0,3 s
local LEAVE = 140        -- so weit weg beruhigt sich das Pferd wieder
local CALM_DIST = 110    -- nach der Flucht erst ab hier wieder grasen
local FAR = 420          -- weiter weg: nur alle FAR_EVERY Frames bewegen
local FAR_EVERY = 30
local NOISE_ON, NOISE_OFF = 0.6, 0.35
local NOISE_UP = 0.6 / 60       -- je Frame Gehen am Rand der Zone (voll nach 1,7 s) …
local NOISE_NEAR = 0.6 / 60     -- … plus so viel ganz nah am Pferd (voll nach knapp 1 s)
local NOISE_DOWN = 1 / 90       -- je Frame Stehen (von voll auf leer in 1,5 s)

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

-- Reaktion als Sprechblase (Rückmeldung 0.5.1: das Pferd zeigt Emojis statt Werte im Text).
function Horse:react(sprite, frames)
  self.react_emo, self.react_until = sprite, frame() + (frames or 120)
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

-- Durchs Tor nur mit dem Menschen (Rückmeldung 0.5.2): an der Leine, folgend oder geritten. Allein
-- (lose, auf der Weide, ausgerissen, wild) bleibt der Fußpunkt aus Torkacheln heraus.
local WITH_PLAYER = {led = true, follow = true, ridden = true}

local function gate_allow(self)
  local farm = self.ctx.area.farm
  return function(x, y)
    if self.allow and not self.allow(x, y) then return false end
    return not Farm.is_gate(farm, flr(x / 16), flr((y - 1) / 16))
  end
end

-- Mit dem Menschen: nicht durchs Tor in eine volle Weide (Rückmeldung 1.3.4), mit Hinweis.
local function full_gate_allow(self)
  return function(x, y)
    if self.allow and not self.allow(x, y) then return false end
    if Farm.gate_open(self.ctx, self.data, self.x, self.y, x, y) then return true end
    Wild.weide_voll(self.ctx)
    return false
  end
end

function Wild.weide_voll(ctx)
  local f = frame()
  if ctx.toast and f - (ctx.voll_hinweis or -999) > 150 then ctx.toast("Weide ist voll.") end
  ctx.voll_hinweis = f
end

function Horse:step(dx, dy)
  local allow = self.allow
  if self.ctx.area.farm then
    if WITH_PLAYER[self.state] then
      self.with_allow = self.with_allow or full_gate_allow(self)
      allow = self.with_allow
    else
      self.alone_allow = self.alone_allow or gate_allow(self)
      allow = self.alone_allow
    end
  end
  local ok_x, ok_y = Body.move(self, dx, dy, self.ctx.map, allow)
  if dx ~= 0 then self.dir = dx > 0 and "right" or "left" end
  return ok_x or ok_y
end

-- Gezähmtes Pferd: "led" an der Leine, "follow" frei hinterher (Bindung ≥ 70), "free" lose,
-- "stand" bleibt stehen.
function Horse:update_tamed()
  if self.hidden then return end          -- im Stall oder im Anhänger
  local ctx, p = self.ctx, self.ctx.player
  -- einmal auf dem eigenen Grundstück: nicht mehr neu, reißt es sich los, bleibt es deins
  if self.data.neu and ctx.area.farm then
    self.neu_t = (self.neu_t or 0) + 1
    if self.neu_t % 30 == 0 and Farm.owns(ctx.area.farm, flr(self.x / 16), flr((self.y - 1) / 16)) then self.data.neu = nil end
  end
  local st = self.state
  self.moving = false
  if st == "ridden" then
    local r = self.rider
    self.x, self.y, self.moving, self.speed = r.x, r.y, r.moving, r.running and 3 or 1
    self.anim = r.anim
    self.ride_dir = r.dir
    self.dir = (r.dir == "left" or r.dir == "right") and r.dir or self.dir
  elseif st == "follow" and self.laufen and self.schatz then      -- läuft zum aufgespürten Schatz (D3)
    local hx, hy = require("game.schaetze").heading(self, self.x, self.y)
    if hx then
      self.moving = self:step(hx * 1.0, hy * 1.0)
      self.anim = self.anim + 0.1
      self.speed = 1
    end
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
        if Leash.escape_roll(self.data.bindung, mode, self.data.zug, nil, Ride.fresh(self.data)) then ctx.wild:escape(self) end
      end
    end
  elseif st == "goepel" then
    -- zieht den Göpel: Kreis um den Generator, gegen den Uhrzeigersinn
    local g = self.goepel
    self.angle = (self.angle + Wild.GOEPEL_SPEED) % (2 * math.pi)
    local nx, ny = g.x + math.cos(self.angle) * Wild.GOEPEL_RX, g.y + math.sin(self.angle) * Wild.GOEPEL_RY
    if nx ~= self.x then self.dir = nx > self.x and "right" or "left" end
    self.x, self.y = nx, ny
    self.moving, self.speed = true, 0.4
    self.anim = self.anim + 0.05
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
    self.flee_t = (self.flee_t or 0) + 1
    if self.flee_t % 12 == 0 then self.vx, self.vy = self:flee_dir(p, 1.8) end
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
    self.noise, self.alarm = 0, false
    if self.timer <= 0 then set_state(self, "graze", 120 + flr(rnd(240))) end
    return
  end
  self.timer = self.timer - 1
  self.cool = max(0, (self.cool or 0) - 1)
  -- Sprinten (oder Galopp) in der Zone ist zu laut: es flieht sofort
  if d < ZONE and p.running and p.moving and self.state ~= "flee" then
    self:flee(p)
    return
  end
  if self.state ~= "flee" and self:listen(p, d) then
    self:flee(p)
    return
  end
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
      if self.timer <= 0 then set_state(self, "warn", WARN); self:face(p); SFX.warn() end
    elseif self.state == "warn" then
      if self.timer <= 0 then set_state(self, "look", 60 + flr(rnd() * 60)) end
    elseif self.state == "look" then
      self:face(p)
      if p.moving then self:flee(p) elseif self.timer <= 0 then set_state(self, "away", flr((120 + rnd() * 120) * (0.5 + self.data.bindung / 200))) end
    end
    return
  end
  if self.state == "flee" then
    -- Richtung alle 12 Frames neu wählen (und sofort, wenn es hängt)
    self.flee_t = (self.flee_t or 0) + 1
    if self.flee_t % 12 == 0 then self.vx, self.vy = self:flee_dir(p, 1.7) end
    local mx, my = self:step(self.vx, 0), self:step(0, self.vy)   -- beide Achsen, rutscht an Hindernissen
    local moved = mx or my
    if not moved then
      self.vx, self.vy = self:flee_dir(p, 1.7)
      moved = self:step(self.vx, 0) or self:step(0, self.vy)
    end
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

-- Fluchtrichtung (Rückmeldung 0.5.2: nicht stur geradeaus in die Wand): weg vom Spieler, aber nur in eine
-- Richtung, in der die nächsten FLEE_LOOK Pixel frei sind. Geprüft wird geradeaus, dann immer weiter
-- seitlich, zuerst auf der Seite, auf die das Pferd zuletzt ausgewichen ist. Gibt vx, vy zurück.
local FLEE_LOOK = {14, 28, 42}
local FLEE_TURN = {0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35, 1.8, -1.8, 2.3, -2.3}

local function path_free(h, ax, ay)
  local map = h.ctx.map
  for _, d in ipairs(FLEE_LOOK) do
    local x, y = h.x + ax * d, h.y + ay * d
    if not Body.free(map, x, y, h.fw, h.fh) then return false end
    if h.allow and not h.allow(x, y) then return false end
    if h.alone_allow and not h.alone_allow(x, y) then return false end
  end
  return true
end

function Horse:flee_dir(p, speed)
  local base = math.atan(self.y - p.y, self.x - p.x)
  local side = self.flee_side or (rnd() < 0.5 and 1 or -1)
  for _, t in ipairs(FLEE_TURN) do
    local a = base + t * side
    local ax, ay = math.cos(a), math.sin(a)
    if path_free(self, ax, ay) then
      if t ~= 0 then self.flee_side = t > 0 and side or -side end
      return ax * speed, ay * speed
    end
  end
  return 0, 0                    -- eingekesselt: stehen bleiben
end

-- Lärmpegel für einen Frame nachführen (siehe oben). Gibt true zurück, wenn er voll ist.
function Horse:listen(p, d)
  local n = self.noise or 0
  if d < ZONE and p.moving then n = n + NOISE_UP + NOISE_NEAR * (1 - d / ZONE) else n = n - NOISE_DOWN end
  n = mid(0, n, 1)
  if not self.alarm and n >= NOISE_ON then
    self.alarm = true
    SFX.warn()
    if self.debug_log then log("ZAEHMEN " .. frame() .. " hört etwas") end
  elseif self.alarm and n <= NOISE_OFF then
    self.alarm = false
  end
  self.noise = n
  return n >= 1
end

function Horse:face(p)
  self.dir = p.x >= self.x and "right" or "left"
end

function Horse:flee(p)
  SFX.whinny()
  set_state(self, "flee", 90)
  self.noise, self.alarm = 0, false
  self.flee_side = nil
  self.vx, self.vy = self:flee_dir(p, 1.7)
  self.flee_t = 0
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

local BEAM, BEAM_DARK = rgb(0xb0, 0x7a, 0x44), rgb(0x55, 0x33, 0x20)
local TAME_BG, TAME_FG = rgb(0x2b, 0x1f, 0x1d), rgb(0xe0, 0x47, 0x5a)

function Horse:draw()
  if self.hidden then return end
  if self.state == "goepel" then          -- Zugbalken von der Nabe zum Rücken
    local g = self.goepel
    line(g.x, g.hub, self.x, self.y - 13, BEAM)
    line(g.x, g.hub + 1, self.x, self.y - 12, BEAM_DARK)
  end
  local r = self.rider
  local lift = r and r.air or 0
  G.draw(self.coat, self.body, self:pose(), self.x, self.y - lift, self.dir == "left", self.data.schmuck)
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
  if self.taming then                 -- Zähmen: Balken über dem Pferd füllt sich
    local w = 24
    local x0, y0 = flr(self.x) - w // 2, flr(self.y) - 34
    rectfill(x0 - 1, y0 - 1, x0 + w, y0 + 3, TAME_BG)
    rectfill(x0, y0, x0 + flr(w * self.taming / self.tame_need), y0 + 2, TAME_FG)
    return
  end
  local b = (self.state == "warn" or self.alarm) and "emo_bang" or Bubbles.choose(self, frame())
  if b then Bubbles.draw(self.ctx.S, b, self.x + (self.dir == "right" and 10 or -10), self.y - 28, frame()) end
end

-- Gezähmte Wildpferde wachsen erst beim nächsten Wechsel nach (KATALOG §10), auch nach Reisen und Laden:
-- ctx.gezaehmt[gebiet] = {runde = Wechselrunde, n = in dieser Runde gezähmt}.
local function wechsel_runde(ctx)
  return ((ctx.clock and ctx.clock.day or 1) - 1) // K.zeit.wild_wechsel_tage
end

function Wild.gezaehmt(ctx, gebiet)
  local z = ctx.gezaehmt and ctx.gezaehmt[gebiet]
  if z and z.runde == wechsel_runde(ctx) then return z.n end
  return 0
end

function Wild.merke_zaehmung(ctx, gebiet)
  ctx.gezaehmt = ctx.gezaehmt or {}
  ctx.gezaehmt[gebiet] = {runde = wechsel_runde(ctx), n = Wild.gezaehmt(ctx, gebiet) + 1}
end

-- So lange muss A gehalten werden: 1,5 s plus 1 Frame je fehlendem Bindungspunkt (Bindung 35 → 2,6 s).
function Wild.tame_frames(bindung)
  return 90 + (100 - bindung)
end

-- Wildpferd in Reichweite (nicht auf der Flucht), nil wenn keins.
function Wild:tame_target()
  local p = self.ctx.player
  for _, h in ipairs(self.list) do
    if h.state ~= "flee" and U.dist(h.x, h.y, p.x, p.y) <= TAME_DIST then return h end
  end
end

-- A gedrückt bei h: Schaut es gerade her (❗ oder hinschauen), sieht es die Hand und flieht (false).
-- Sonst beginnt das Zähmen (true); weiter mit tame_step, solange A gehalten wird.
function Wild:tame_begin(h)
  if h.state == "warn" or h.state == "look" then
    h:flee(self.ctx.player)
    return false
  end
  h.taming, h.tame_need = 0, Wild.tame_frames(h.data.bindung)
  return true
end

-- Ein Frame Zähmen. holding: A gehalten. Gibt "ok" (gezähmt), "weg" (abgebrochen) oder nil (läuft) zurück.
function Wild:tame_step(h, holding)
  local p = self.ctx.player
  if not holding or p.moving or h.state == "flee" or h.dead or U.dist(h.x, h.y, p.x, p.y) > TAME_DIST + 8 then
    h.taming = nil
    return "weg"
  end
  h.taming = h.taming + 1
  if h.taming >= h.tame_need then
    h.taming = nil
    self:tame(h)
    return "ok"
  end
end

-- Zähmt h sofort (Ende von tame_step; Tests). Bis es einmal auf dem Grundstück war, ist es neu (data.neu):
-- Reißt es sich vorher los, wird es wieder wild (Rückmeldung 1.2.1).
function Wild:tame(h)
  for i, e in ipairs(self.list) do if e == h then table.remove(self.list, i) break end end
  Wild.merke_zaehmung(self.ctx, self.gebiet)
  h.wild, h.data.wild, h.tamed = false, nil, true
  h.data.reit_ab = h.data.bindung + Ride.FRESH_BOND          -- frisch gezähmt: noch nicht reitbar (E71)
  h.data.neu = true
  H.claim_name(h.data, self.rng)                 -- nie ein Name, den es schon gab (Rückmeldung 1.3.1)
  require("game.breeding").ensure_id(h.data, self.ctx.herd)
  self.ctx.herd[#self.ctx.herd + 1] = h.data
  self.ctx.herd_horses[#self.ctx.herd_horses + 1] = h
  self:attach(h)
  return h
end

-- Ein neues Pferd reißt sich los, bevor es auf dem Hof war: wieder wild, mit der Bindung von vor dem Zähmen.
function Wild:rewild(h)
  local ctx = self.ctx
  for i, e in ipairs(ctx.lead) do if e == h then table.remove(ctx.lead, i) break end end
  for i, d in ipairs(ctx.herd) do if d == h.data then table.remove(ctx.herd, i) break end end
  for i, e in ipairs(ctx.herd_horses) do if e == h then table.remove(ctx.herd_horses, i) break end end
  local d = h.data
  if d.reit_ab then d.bindung = mid(0, d.reit_ab - Ride.FRESH_BOND, 100) end
  d.reit_ab, d.neu, d.ort, d.lose, d.wild = nil, nil, nil, nil, true
  h.tamed, h.wild, h.hidden, h.bounds, h.allow, h.alone_allow = false, true, false, nil, nil, nil
  local z = ctx.gezaehmt and ctx.gezaehmt[self.gebiet]
  if z and z.n > 0 then z.n = z.n - 1 end
  self.list[#self.list + 1] = h
  h:flee(ctx.player)
  h.timer = 150
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

-- Nimmt ein gezähmtes Pferd mit: an die Leine (höchstens Leash.MAX_LED), ab Bindung 70 frei folgend
-- (zusammen höchstens Leash.MAX_LEAD). Geht das nicht, steht es lose: false.
function Wild:can_lead(h)
  if #self.ctx.lead >= Leash.MAX_LEAD then return false end
  return h.data.bindung >= Leash.FOLLOW or self:led_count() < Leash.MAX_LED
end

function Wild:attach(h)
  h.data.ort, h.bounds, h.allow, h.hidden = nil, nil, nil, false
  local lead = self.ctx.lead
  local follow = h.data.bindung >= Leash.FOLLOW
  if not self:can_lead(h) then
    h.state, h.timer, h.vx, h.vy = "free", 60, 0, 0
    return false
  end
  lead[#lead + 1] = h
  h.state = follow and "follow" or "led"
  h.leash_t = 0
  return true
end

-- Pferde am Strick (ohne die frei folgenden).
function Wild:led_count()
  local n = 0
  for _, h in ipairs(self.ctx.lead) do if h.state == "led" then n = n + 1 end end
  return n
end

-- Die Leine reißt: Pferd läuft weg und bleibt dort lose stehen. War es noch nie auf dem Hof (data.neu),
-- ist es wieder wild (ctx.escaped_wild).
function Wild:escape(h)
  if h.data.neu then
    self:rewild(h)
    SFX.snap()
    self.ctx.escaped, self.ctx.escaped_wild = h, true
    return h
  end
  for i, e in ipairs(self.ctx.lead) do
    if e == h then table.remove(self.ctx.lead, i) break end
  end
  local p = self.ctx.player
  h.state, h.flee_side, h.flee_t = "escape", nil, 0
  h.vx, h.vy = h:flee_dir(p, 1.8)
  SFX.snap()
  SFX.whinny()
  h.state, h.timer = "escape", 70
  h.scared = true
  self.ctx.escaped = h
  return h
end

-- A bei einem geführten oder folgenden Pferd in Reichweite: aufsteigen. Gibt Pferd und Ergebnis
-- ("ok", "frisch" oder "verweigert") zurück, nil wenn keins in Reichweite ist.
function Wild:try_mount()
  local p = self.ctx.player
  if p.riding then return nil end
  local best, bd = nil, Ride.REACH
  for _, h in ipairs(self.ctx.lead) do
    local d = U.dist(h.x, h.y, p.x, p.y)
    if d <= bd then best, bd = h, d end
  end
  if not best then return nil end
  if Ride.fresh(best.data) then return best, "frisch" end
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

-- Aufsitzen auf h (Menü, E2): "ok", "frisch" (frisch gezähmt, E71) oder "verweigert".
function Wild:mount(h)
  if Ride.fresh(h.data) then return "frisch" end
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
  return self:settle(h)
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
  require("game.breeding").ensure_id(h.data, self.ctx.herd)
  self.ctx.herd[#self.ctx.herd + 1] = h.data
  self.ctx.herd_horses[#self.ctx.herd_horses + 1] = h
  return h
end

-- Nimmt ein gespeichertes Pferd (Datentabelle) wieder in den Bestand: untergebracht, wo es war,
-- sonst an der Leine beim Spieler.
function Wild:adopt(data)
  require("game.breeding").ensure_id(data, self.ctx.herd)
  local p = self.ctx.player
  local h = Horse.new(self.ctx, data, p.x, p.y + 16)
  h.wild, h.tamed, h.state = false, true, "free"
  data.wild = nil
  self.ctx.world:add(h)
  self.ctx.herd[#self.ctx.herd + 1] = data
  self.ctx.herd_horses[#self.ctx.herd_horses + 1] = h
  local ort, lose = data.ort, data.lose
  data.ort, data.lose = nil, nil
  -- lose gespeichert (z. B. in die Weide geführt, aber nicht untergebracht): bleibt, wo es stand
  if not ort and lose then
    h.x, h.y, h.timer = lose[1], lose[2], 60
    self:settle(h)                 -- stand es in einer Weide: ist jetzt Weidepferd (Rückmeldung 1.3.2)
    return h
  end
  -- Gespeicherte Unterbringung wiederherstellen, ohne Platz und Bedingungen neu zu prüfen: was beim Speichern
  -- auf der Weide stand, bleibt dort (Rückmeldung 0.5.1). Nur wenn es gar keine Weide mehr gibt: an die Leine.
  if not ort or not self:house(h, ort, true) then self:attach(h) end
  return h
end

-- Fohlen (Rückmeldung 1.2.1): kommt in den Stall. Ist dort kein Platz, macht make_room Platz. Gibt das
-- Pferd und die Meldungen über Umzüge zurück.
function Wild:place_foal(data, mother)
  data.ort = "stall"
  local h = self:adopt(data)
  return h, self:make_room({[data] = true, [mother] = true})
end

-- Stall überbelegt: das billigste Pferd (nie eins aus protect, Menge Daten → true) zieht auf die Weide; ist die
-- voll, zieht dort das billigste auf das Grundstück (frei, auch wenn es dafür sonst zu schwach wäre); ist auch das
-- voll, läuft das Pferd mit dem geringsten Wert fort. Gibt die Meldungen zurück.
function Wild:make_room(protect)
  local ctx, farm = self.ctx, self.ctx.area.farm
  local out = {}
  if not farm then return out end
  local V = require("game.value")
  local function cheapest(orte, skip)
    local best
    for _, h in ipairs(ctx.herd_horses) do
      local d = h.data
      if orte[d.ort] and not protect[d] and h ~= skip and (not best or V.wert_roh(d) < V.wert_roh(best.data)) then best = h end
    end
    return best
  end
  for _ = 1, 30 do
    local cap = Farm.capacity(farm)
    if Farm.count(ctx.herd, "stall") <= cap.stall then break end
    local x = cheapest({stall = true})
    if not x then break end
    if self:house(x, "weide") then
      out[#out + 1] = x.data.name .. " zieht auf die Weide."
    else
      local y = cheapest({weide = true}, x)
      self.force_roam = true
      local ok = y and self:house(y, "frei")
      self.force_roam = nil
      if ok and self:house(x, "weide") then
        out[#out + 1] = y.data.name .. " läuft jetzt frei auf dem Hof, " .. x.data.name .. " zieht auf die Weide."
      else
        if ok then self:house(y, "weide", true) end              -- zurück, es hat nichts genützt
        local z = cheapest({stall = true, weide = true, frei = true})
        if not z then break end
        out[#out + 1] = z.data.name .. " ist fortgelaufen: Auf dem Hof war kein Platz mehr."
        self:free(z)
      end
    end
  end
  return out
end

-- Vor dem Speichern (und vor einer Reise vom Hof): lose eigene Pferde merken sich ihren Platz (data.lose),
-- damit sie nach dem Laden dort stehen statt an der Leine. Unterwegs gilt das nicht (anderes Gebiet).
function Wild:mark_loose()
  for _, h in ipairs(self.ctx.herd_horses) do
    local loose = (h.state == "free" or h.state == "escape") and not h.data.ort and not self.ctx.heim
    h.data.lose = loose and {flr(h.x), flr(h.y)} or nil
  end
end

-- Legt die Bewegungsgrenzen eines Pferds auf eine Weide (Kachelmenge) fest.
local function confine_to(h, pasture)
  h.data.weide_id = pasture.id
  h.bounds = nil
  h.allow = function(x, y) return Farm.in_pasture(pasture, x, y) end
end

-- Lose in einer Weide (losgelassen, oder so gespeichert): wird Weidepferd dieser Weide, wenn dort Platz ist,
-- und bleibt, wo es steht (Rückmeldung 1.3.2: zählte sonst nicht unter „Ort“). Gibt true zurück, wenn ja.
function Wild:settle(h)
  local farm = self.ctx.area.farm
  if not farm or h.data.ort then return false end
  for _, w in ipairs(Farm.pastures(self.ctx.map, farm)) do
    if Farm.in_pasture(w, h.x, h.y) then
      if Farm.count_pasture(self.ctx.herd, w.id) >= w.plaetze then return false end
      h.data.ort, h.data.lose, h.data.neu = "weide", nil, nil
      confine_to(h, w)
      h.state, h.timer, h.vx, h.vy, h.scared = "free", 60, 0, 0, false
      return true
    end
  end
  return false
end

-- Unterbringung (E32, C2): ort = "stall", "weide" oder "frei". Gibt true oder false und den Grund zurück.
-- restore: Spielstand laden: keine Platz- und Stärkeprüfung, die gespeicherte Weide (weide_id) zuerst.
function Wild:house(h, ort, restore)
  local farm = self.ctx.area.farm
  if ort == "anhaenger" then return self:load(h, restore) end
  if not farm then return false, "nur auf dem Hof" end
  if not restore then
    local cap = Farm.capacity(farm)
    local n = Farm.count(self.ctx.herd, ort) - (h.data.ort == ort and 1 or 0)
    if n >= cap[ort] then return false, "voll" end
    if ort == "frei" and not Farm.may_roam(h.data, H) and not self.force_roam then return false, "zu schwach oder zu scheu" end
    if ort == "goepel" and not Farm.may_pull(h.data, H) then return false, "zu schwach für den Göpel" end
  end
  if ort == "goepel" then return self:to_goepel(h, restore) end
  local pasture
  if ort == "weide" then
    local list = Farm.pastures(self.ctx.map, farm)
    if restore then
      for _, w in ipairs(list) do if w.id == h.data.weide_id then pasture = w end end
    end
    -- sonst die erste Weide mit freiem Platz (beim Laden notfalls irgendeine)
    for _, w in ipairs(list) do
      if pasture then break end
      local used = Farm.count_pasture(self.ctx.herd, w.id) - ((h.data.ort == "weide" and h.data.weide_id == w.id) and 1 or 0)
      if used < w.plaetze then pasture = w end
    end
    if not pasture and restore then pasture = list[1] end
    if not pasture then return false, "voll" end
  end
  for i, e in ipairs(self.ctx.lead) do
    if e == h then table.remove(self.ctx.lead, i) break end
  end
  h.data.ort, h.data.neu = ort, nil
  h.scared = false
  if ort == "stall" then
    h.data.weide_id = nil
    h.state, h.hidden = "stall", true
    return true
  end
  if ort == "weide" then
    confine_to(h, pasture)
    -- auf eine freie Kachel der Weide setzen
    for _ = 1, 100 do
      local t = pasture.list[1 + flr(rnd() * #pasture.list)]
      local x, y = t[1] * 16 + 8, t[2] * 16 + 14
      if not self.ctx.map:blocked(x - 8, y - 6, x + 8, y) then h.x, h.y = x, y break end
    end
  else
    h.data.weide_id = nil
    local b = Farm.plot_bounds(farm)
    h.bounds = b
    h.allow = function(x, y)
      return x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] and Farm.owns(farm, flr(x / 16), flr((y - 1) / 16))
    end
    for _ = 1, 100 do
      local x, y = b[1] + rnd() * (b[3] - b[1]), b[2] + rnd() * (b[4] - b[2])
      if h.allow(x, y) and not self.ctx.map:blocked(x - 8, y - 6, x + 8, y) then h.x, h.y = x, y break end
    end
  end
  h.state, h.timer, h.vx, h.vy, h.hidden = "free", 60, 0, 0, false
  return true
end

-- Göpel (Rückmeldung 1.2.1): ein Pferd je Generator, es läuft im Kreis um ihn herum (state "goepel").
-- restore: beim Laden der gemerkte Göpel (data.goepel_id) zuerst, notfalls irgendeiner.
Wild.GOEPEL_RX, Wild.GOEPEL_RY, Wild.GOEPEL_SPEED = 30, 13, 0.012

function Wild:to_goepel(h, restore)
  local list = Farm.goepels(self.ctx.area.farm)
  local used = {}
  for _, d in ipairs(self.ctx.herd) do
    if d ~= h.data and d.ort == "goepel" and d.goepel_id then used[d.goepel_id] = true end
  end
  local g
  for _, e in ipairs(list) do if restore and e.key == h.data.goepel_id then g = e end end
  for _, e in ipairs(list) do if not g and not used[e.key] then g = e end end
  if not g and restore then g = list[1] end
  if not g then return false, "kein Göpel frei" end
  for i, e in ipairs(self.ctx.lead) do
    if e == h then table.remove(self.ctx.lead, i) break end
  end
  h.data.ort, h.data.goepel_id, h.data.weide_id, h.data.lose, h.data.neu = "goepel", g.key, nil, nil, nil
  h.bounds, h.allow, h.hidden, h.scared = nil, nil, false, false
  h.state = "goepel"
  h.goepel = {x = g[1] * 16 + 16, y = g[2] * 16 + 27, hub = g[2] * 16 + 19}
  h.angle = h.angle or 0
  h.x, h.y = h.goepel.x + Wild.GOEPEL_RX, h.goepel.y
  return true
end

-- In den Anhänger (Rückmeldung 0.5.8): ein Platz je Pferd, geht zu Hause und unterwegs.
function Wild:load(h, restore)
  local Reise = require("game.reise")
  if not restore then
    if not Reise.trailer_box(self.ctx) then return false, "kein Anhänger" end
    local n, cap = Reise.geladen(self.ctx)
    if h.data.ort ~= "anhaenger" and n >= cap then return false, "der Anhänger ist voll" end
  end
  for i, e in ipairs(self.ctx.lead) do
    if e == h then table.remove(self.ctx.lead, i) break end
  end
  h.data.ort, h.data.weide_id, h.data.lose, h.bounds, h.allow = "anhaenger", nil, nil, nil, nil
  h.state, h.hidden, h.scared = "anhaenger", true, false
  return true
end

-- Freilassen (unterwegs, E73): das Pferd gehört nicht mehr dir und läuft davon.
function Wild:free(h)
  local ctx = self.ctx
  for i, e in ipairs(ctx.lead) do if e == h then table.remove(ctx.lead, i) break end end
  for i, d in ipairs(ctx.herd) do if d == h.data then table.remove(ctx.herd, i) break end end
  for i, e in ipairs(ctx.herd_horses) do if e == h then table.remove(ctx.herd_horses, i) break end end
  if ctx.escaped == h then ctx.escaped = nil end
  h.dead = true
end

-- Nach einem Umbau: Weiden neu berechnen. Weidenpferde bleiben auf ihrer Weide, wenn es sie noch gibt
-- und Platz ist; sonst suchen sie eine andere, und wenn keine da ist, kommen sie an die Leine.
-- Gibt die Namen der Pferde zurück, die ihre Weide verloren haben.
function Wild:rehome()
  local farm = self.ctx.area.farm
  if not farm then return {} end
  local pastures = Farm.pastures(self.ctx.map, farm)
  local by_id = {}
  for _, w in ipairs(pastures) do by_id[w.id] = w end
  local used = {}
  for _, w in ipairs(pastures) do used[w.id] = 0 end
  local lost = {}
  for _, h in ipairs(self.ctx.herd_horses) do
    if h.data.ort == "weide" then
      local w = by_id[h.data.weide_id]
      if w and used[w.id] < w.plaetze then
        used[w.id] = used[w.id] + 1
        confine_to(h, w)
      else
        -- andere Weide mit Platz?
        local other
        for _, o in ipairs(pastures) do if used[o.id] < o.plaetze then other = o break end end
        if other then
          used[other.id] = used[other.id] + 1
          confine_to(h, other)
          local t = other.list[1]
          h.x, h.y = t[1] * 16 + 8, t[2] * 16 + 14
        else
          lost[#lost + 1] = h.data.name
          h.data.ort, h.data.weide_id, h.allow, h.bounds = nil, nil, nil, nil
          h.state, h.timer = "free", 60
        end
      end
    end
  end
  return lost
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

-- Steht der Spieler vor einer Stalltür? Gibt die Tür ({cx, cy, id, b = Gebäude}) zurück, sonst nil.
function Wild:at_stall_door()
  local p = self.ctx.player
  for _, d in ipairs(self.ctx.area.farm and Farm.stall_doors(self.ctx.area.farm) or {}) do
    if U.dist(p.x, p.y, d[1] * 16 + 8, d[2] * 16 + 8) <= 26 then return d end
  end
  return nil
end

-- Steht der Spieler vor einer Schlaftür (Wohnwagen, Häuschen, Villa)?
function Wild:at_bed_door()
  local p = self.ctx.player
  for _, d in ipairs(self.ctx.area.farm and Farm.bed_doors(self.ctx.area.farm) or {}) do
    if U.dist(p.x, p.y, d[1] * 16 + 8, d[2] * 16 + 8) <= 26 then return true end
  end
  return false
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
  local want = self.count - Wild.gezaehmt(self.ctx, self.gebiet)
  while #self.list < want do
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
