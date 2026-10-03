-- Hof-Automatik (Rückmeldung 1.5.2, E85): Was im Heimattal Pflicht war, kann man sich später abnehmen lassen.
-- Werte aus KATALOG §9: Heuraufe (füttert morgens), Kratzbürste (Sauberkeit), Stallburschenhütte (Stallbursche
-- streichelt und striegelt, kostet Lohn). Wirkt auf alle Pferde auf dem Hof (nicht im Anhänger), auch wenn
-- der Spieler gerade verreist ist. Days.new_day ruft Automatik.tag nach den Tagesregeln auf.
local K = require("game.katalog")
local Care = require("game.care")
local Farm = require("game.farm")
local Body = require("lib.body")
local U = require("lib.util")

local A = {}

A.MAX_HEU = 2              -- so oft füttert die Heuraufe ein Pferd höchstens am Morgen

-- Hinweis im Baumenü, wenn man ein Pflege-Bauteil wählt
A.INFO = {
  heuraufe = "Heuraufe: füttert jeden Morgen hungrige Pferde, mit Heu aus dem Haus oder gekauftem.",
  kratzbuerste = "Kratzbürste: alle Pferde auf dem Hof jeden Tag Sauberkeit +20.",
  stallburschenhuette = "Der Stallbursche streichelt und striegelt jeden Morgen alle Pferde. Lohn 15 G am Tag.",
}

-- Anzahl der Bauten mit dieser id auf dem Hof.
function A.anzahl(farm, id)
  local n = 0
  for _, b in ipairs(Farm.all_buildings(farm)) do if b.id == id then n = n + 1 end end
  return n
end

local function auf_dem_hof(d)
  return d.ort ~= "anhaenger"
end

-- Heu für die Raufe: erst aus dem Haus, sonst zum Ladenpreis (mit Hafersteuer). Gibt true, gekauft zurück.
local function heu(ctx)
  if (ctx.inv.heu or 0) > 0 then
    ctx.inv.heu = ctx.inv.heu - 1
    return true, false
  end
  local Economy = require("game.economy")
  local p = Economy.price(ctx, Economy.find("heu"))
  if ctx.money < p then return false end
  ctx.money = ctx.money - p
  return true, p
end

-- Ein Morgen: wendet alle Automatik-Bauten an. Gibt einen Bericht zurück:
-- {gefuettert, heu_gekauft, heu_kosten, kein_heu, gebuerstet, gepflegt, lohn, kein_lohn}.
function A.tag(ctx)
  local farm = ctx.hof or (ctx.area and ctx.area.farm)
  local r = {gefuettert = 0, heu_gekauft = 0, heu_kosten = 0, kein_heu = 0, gebuerstet = 0, gepflegt = 0, lohn = 0}
  if not farm then return r end
  local raufe, buerste, huette = A.anzahl(farm, "heuraufe"), A.anzahl(farm, "kratzbuerste"), A.anzahl(farm, "stallburschenhuette")
  if raufe + buerste + huette == 0 then return r end
  -- Stallbursche will zuerst seinen Lohn; ohne Geld bleibt er heute im Bett
  local bursche = false
  if huette > 0 then
    local lohn = K.bauteil("stallburschenhuette").lohn
    if ctx.money >= lohn then
      ctx.money = ctx.money - lohn
      r.lohn, bursche = lohn, true
    else
      r.kein_lohn = true
    end
  end
  local grenze = K.bauteil("heuraufe").auto_hunger
  local sauber = K.bauteil("kratzbuerste").wirkung.sauberkeit
  for _, d in ipairs(ctx.herd) do
    if auf_dem_hof(d) then
      if raufe > 0 then
        local n = 0
        while d.hunger > grenze and n < A.MAX_HEU do
          local ok, gekauft = heu(ctx)
          if not ok then r.kein_heu = r.kein_heu + 1 break end
          if gekauft then r.heu_gekauft, r.heu_kosten = r.heu_gekauft + 1, r.heu_kosten + gekauft end
          Care.feed(d, "heu")
          n = n + 1
        end
        if n > 0 then r.gefuettert = r.gefuettert + 1 end
      end
      if buerste > 0 and d.sauberkeit < 100 then
        d.sauberkeit = mid(0, d.sauberkeit + sauber, 100)
        r.gebuerstet = r.gebuerstet + 1
      end
      if bursche then
        Care.stroke(d)
        Care.brush(d)
        r.gepflegt = r.gepflegt + 1
      end
    end
  end
  return r
end

-- Kurzer Text für die Meldung am Morgen, nil ohne Automatik.
function A.text(r)
  if not r then return nil end
  local t = {}
  if r.gefuettert > 0 then
    t[#t + 1] = "Heuraufe: " .. r.gefuettert .. " gefüttert" .. (r.heu_kosten > 0 and (" (Heu " .. r.heu_kosten .. " G)") or "") .. "."
  end
  if r.kein_heu > 0 then t[#t + 1] = "Die Heuraufe ist leer, kein Geld für Heu." end
  if r.gepflegt > 0 then t[#t + 1] = "Stallbursche: " .. r.gepflegt .. " gepflegt (-" .. r.lohn .. " G)." end
  if r.kein_lohn then t[#t + 1] = "Der Stallbursche will Lohn sehen und bleibt heute liegen." end
  if #t == 0 then return nil end
  return table.concat(t, " ")
end

-- ---- Der Stallbursche als Figur auf dem Hof: steht an seiner Hütte und schlendert herum ----

local NPC = {}
NPC.__index = NPC
NPC.SPEED = 0.45
NPC.RANGE = 5              -- Kacheln um die Hütte

function NPC:pick()
  local h = self.home
  for _ = 1, 8 do
    local cx, cy = h[1] + self.rng(-NPC.RANGE, NPC.RANGE), h[2] + self.rng(0, NPC.RANGE)
    if self.ctx.map:walkable(cx, cy) then
      self.tx, self.ty = cx * 16 + 8, cy * 16 + 14
      return
    end
  end
  self.tx, self.ty = h[1] * 16 + 8, h[2] * 16 + 14
end

function NPC:update()
  if self.wait > 0 then
    self.wait = self.wait - 1
    if self.wait == 0 then self:pick() end
    return
  end
  local dx, dy = self.tx - self.x, self.ty - self.y
  local d = math.sqrt(dx * dx + dy * dy)
  self.moving = false
  if d < 2 or self.stuck > 90 then
    self.wait, self.stuck = 120 + self.rng(0, 180), 0
    return
  end
  local vx, vy = dx / d * NPC.SPEED, dy / d * NPC.SPEED
  local ok_x, ok_y = Body.move(self, vx, vy, self.ctx.map)
  if (ok_x and abs(vx) > 0.05) or (ok_y and abs(vy) > 0.05) then
    self.moving = true
    self.anim = self.anim + 0.06
    local fx, fy = 0, 0
    if abs(vx) > abs(vy) then fx = vx > 0 and 1 or -1 else fy = vy > 0 and 1 or -1 end
    self.dir = U.facing(fx, fy, self.dir)
  else
    self.stuck = self.stuck + 1
  end
end

function NPC:draw_shadow()
  local g = self.ctx.map:ground_at(self.x, self.y)
  local c = g and g.shadow or 0
  local x, y = flr(self.x), flr(self.y)
  rectfill(x - 5, y - 1, x + 5, y, c)
  rectfill(x - 3, y - 2, x + 3, y + 1, c)
end

function NPC:draw()
  local S = self.ctx.S
  local phase = self.moving and flr(self.anim * 4) % 4 or 0
  local walk = (phase == 1 or phase == 3) and "_walk" or ""
  local x, y = flr(self.x), flr(self.y)
  if self.dir == "left" or self.dir == "right" then
    S.draw("bursche_side" .. walk, x - 6, y - 19, self.dir == "left")
  else
    S.draw("bursche_" .. self.dir .. walk, x - 6, y - 19, phase == 3)
  end
end

-- Tür der Hütte (Kachel unter der Mitte), nil ohne Hütte.
local function huette_tuer(farm)
  for _, b in ipairs(Farm.all_buildings(farm)) do
    if b.id == "stallburschenhuette" then return {b.cx + 1, b.cy + 2} end
  end
end

-- Stellt den Stallburschen auf den Hof, wenn es eine Hütte gibt (und entfernt ihn sonst). Nur zu Hause.
function A.sync(ctx)
  local farm = ctx.area and ctx.area.farm
  local door = farm and huette_tuer(farm)
  local e = ctx.bursche_ent
  if e and (not door or e.home[1] ~= door[1] or e.home[2] ~= door[2]) then
    e.dead, ctx.bursche_ent, e = true, nil, nil
  end
  if door and not e then
    local seed = door[1] * 31 + door[2]
    local function rng(a, b)
      seed = (seed * 1103515245 + 12345) % 2147483648
      return a + seed % (b - a + 1)
    end
    e = setmetatable({ctx = ctx, home = door, x = door[1] * 16 + 8, y = door[2] * 16 + 14, fw = 8, fh = 4, reach = 32,
      dir = "down", anim = 0, wait = 60, stuck = 0, moving = false, rng = rng, is_bursche = true}, NPC)
    e.tx, e.ty = e.x, e.y
    ctx.world:add(e)
    ctx.bursche_ent = e
  end
  return ctx.bursche_ent
end

return A
