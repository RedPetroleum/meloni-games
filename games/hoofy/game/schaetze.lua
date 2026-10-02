-- Schätze (Aufgabe D3, KATALOG §11): 15–30 je Gebiet, versteckt auf Wiesenkacheln. Ein Pferd (geritten oder frei
-- folgend) spürt sie im Radius auf (👃), nach 1 s ohne Eingabe läuft es hin. Funde: im Heimattal sofort ins Haus
-- (verkauft), sonst in die Satteltaschen, am Fahrzeug ins Fahrzeuglager, zu Hause ins Haus.
local K = require("game.katalog")
local H = require("game.horse_model")
local Care = require("game.care")
local Economy = require("game.economy")
local Rng = require("lib.rng")
local U = require("lib.util")

local S = {}

S.IDLE_FRAMES = 60          -- so lange ohne Steuern, dann läuft das Pferd los (E4)
S.GIVE_UP = 900             -- Frames, dann gibt das Pferd auf (Hindernis)
S.CATCH = 10                -- Pixel Abstand zum Fund

-- Gewichte je Häufigkeit; weiter entfernte Gebiete bringen mehr Seltenes (README §7).
local WEIGHT = {["sehr häufig"] = 40, ["häufig"] = 25, ["selten"] = 6, ["sehr selten"] = 2, ["legendär"] = 1}
local RARE = {["selten"] = true, ["sehr selten"] = true, ["legendär"] = true}

local function pick_fund(R, nr)
  local list, sum = {}, 0
  for _, f in ipairs(K.schaetze.funde) do
    if (f.gebiet or 1) <= nr then
      local w = WEIGHT[f.haeufigkeit] * (RARE[f.haeufigkeit] and nr or 1)
      sum = sum + w
      list[#list + 1] = {f, sum}
    end
  end
  local r = R:next() * sum
  for _, e in ipairs(list) do if r < e[2] then return e[1].id end end
  return list[#list][1].id
end

-- Liste {cx, cy, fund, nr = laufende Nummer} für ein Gebiet (aus Seed). Nicht auf dem Grundstück, im Dorf oder am Start.
function S.generate(area)
  local map, R = area.map, Rng.new(area.seed * 7 + area.nr * 131)
  local n = R:int(15, 30)
  local out, tries = {}, 0
  local pl, v, st = area.plot, area.village, area.places.start
  while #out < n and tries < 4000 do
    tries = tries + 1
    local cx, cy = R:int(3, map.w - 4), R:int(3, map.h - 4)
    local in_plot = cx >= pl.x - 2 and cx < pl.x + pl.w + 2 and cy >= pl.y - 2 and cy < pl.y + pl.h + 2
    local in_vil = v and cx >= v.x - 2 and cx < v.x + v.w + 2 and cy >= v.y - 2 and cy < v.y + v.h + 2
    if not in_plot and not in_vil and U.dist(cx, cy, st[1], st[2]) > 8 and map:code(cx, cy) == "."
        and map:walkable(cx, cy) then
      local dup = false
      for _, t in ipairs(out) do if U.dist(t.cx, t.cy, cx, cy) < 4 then dup = true break end end
      if not dup then out[#out + 1] = {cx = cx, cy = cy, fund = pick_fund(R, area.nr), nr = #out + 1} end
    end
  end
  return out
end

-- Noch nicht gefundene Schätze von Gebiet nr: gefunden = ctx.gefunden[nr] (Menge der laufenden Nummern).
function S.setup(ctx)
  ctx.gefunden = ctx.gefunden or {}
  local done = ctx.gefunden[ctx.area.nr] or {}
  ctx.schaetze = {}
  for _, t in ipairs(S.generate(ctx.area)) do
    if not done[t.nr] then ctx.schaetze[#ctx.schaetze + 1] = t end
  end
end

function S.radius(d) return (K.schaetze.radius_basis + H.stat(d, "spuer") / K.schaetze.radius_teiler) * 16 end
function S.chance(d) return H.stat(d, "spuer") / K.schaetze.chance_teiler / 100 end

local function pos(ctx, h)
  if h.state == "ridden" then return ctx.player.x, ctx.player.y end
  return h.x, h.y
end

-- Pferde, die suchen dürfen: das geritten wird und freie Folger (nicht am Seil), mit Platz für Funde.
local function searchers(ctx)
  local out = {}
  local r = ctx.player.riding
  if r then out[#out + 1] = r end
  for _, h in ipairs(ctx.lead) do if h.state == "follow" then out[#out + 1] = h end end
  return out
end

-- Platz für einen Fund: im Heimattal immer; sonst Satteltasche mit freiem Platz.
function S.has_room(ctx, h)
  if ctx.area.nr == 1 then return true end
  return #(h.data.fund or {}) < Economy.tasche_plaetze(h.data)
end

function S.target(ctx, h)
  for _, t in ipairs(ctx.schaetze) do if t == h.schatz then return t end end
end

-- Wert eines Funds im Haus: Münzen; ein Samen kommt in den Vorrat.
function S.verkaufen(ctx, fund, rng)
  local info
  for _, f in ipairs(K.schaetze.funde) do if f.id == fund then info = f end end
  if info.samen then
    local list = K.futter.anbau
    local p = list[(rng and rng:int(1, #list)) or 1]
    ctx.inv["samen_" .. p.id] = (ctx.inv["samen_" .. p.id] or 0) + 1
    return "Samen: " .. p.name, 0
  end
  ctx.money = ctx.money + info.wert
  return info.name, info.wert
end

-- Alles aus Taschen und Fahrzeuglager ins Haus (Fahrzeug im Heimattal oder Pferd auf dem Grundstück).
function S.heimbringen(ctx)
  local sum, n = 0, 0
  local function flush(list)
    for _, f in ipairs(list or {}) do local _, w = S.verkaufen(ctx, f, ctx.fund_rng) sum, n = sum + w, n + 1 end
  end
  flush(ctx.lager)
  ctx.lager = {}
  for _, d in ipairs(ctx.herd) do flush(d.fund) d.fund = nil end
  return n, sum
end

-- Am Fahrzeug: Taschen ins Fahrzeuglager.
function S.abladen(ctx)
  local n = 0
  for _, d in ipairs(ctx.herd) do
    for _, f in ipairs(d.fund or {}) do ctx.lager[#ctx.lager + 1] = f n = n + 1 end
    d.fund = nil
  end
  return n
end

local function collect(ctx, h, t)
  for i, e in ipairs(ctx.schaetze) do if e == t then table.remove(ctx.schaetze, i) break end end
  ctx.gefunden[ctx.area.nr] = ctx.gefunden[ctx.area.nr] or {}
  ctx.gefunden[ctx.area.nr][t.nr] = true
  local name, wert
  if ctx.area.nr == 1 then
    name, wert = S.verkaufen(ctx, t.fund, ctx.fund_rng)
  else
    h.data.fund = h.data.fund or {}
    h.data.fund[#h.data.fund + 1] = t.fund
    for _, f in ipairs(K.schaetze.funde) do if f.id == t.fund then name = f.name end end
    wert = nil
  end
  Care.train(h.data, "spuer", K.schaetze.fund_training)
  h.schatz, h.laufen = nil, nil
  return name, wert
end

-- Ein Frame: Spüren (einmal je Sekunde), Laufen, Finden. idle = Frames ohne Steuern.
-- Gibt Name und Wert eines Funds zurück, wenn gerade einer gemacht wurde.
function S.update(ctx, idle, now)
  if not ctx.schaetze then return end
  local found_name, found_val
  for _, h in ipairs(searchers(ctx)) do
    local x, y = pos(ctx, h)
    if h.schatz and not S.target(ctx, h) then h.schatz, h.laufen = nil, nil end
    if not h.schatz and now % 60 == 0 and S.has_room(ctx, h) then
      local best, bd = nil, S.radius(h.data)
      for _, t in ipairs(ctx.schaetze) do
        local d = U.dist(x, y, t.cx * 16 + 8, t.cy * 16 + 8)
        if d <= bd and not ((t.skip or 0) > now) then best, bd = t, d end
      end
      if best and rnd() < S.chance(h.data) then h.schatz, h.suche_t = best, 0 end
    end
    if h.schatz then
      h.suche_t = (h.suche_t or 0) + 1
      if idle >= S.IDLE_FRAMES then h.laufen = true elseif idle == 0 then h.laufen = nil end
      local t = h.schatz
      if h.laufen then
        if U.dist(x, y, t.cx * 16 + 8, t.cy * 16 + 8) <= S.CATCH then
          found_name, found_val = collect(ctx, h, t)
        elseif h.suche_t > S.GIVE_UP then
          t.skip, h.schatz, h.laufen = now + 3600, nil, nil
        end
      end
    end
  end
  return found_name, found_val
end

-- Richtung (dx, dy, normiert) zum Fund für ein laufendes Pferd, sonst nil.
function S.heading(h, x, y)
  if not (h.laufen and h.schatz) then return nil end
  local dx, dy = h.schatz.cx * 16 + 8 - x, h.schatz.cy * 16 + 8 - y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1 then return nil end
  -- Hängt es fest (kaum bewegt), ein Stück seitlich ausweichen
  if h.lx and U.dist(x, y, h.lx, h.ly) < 0.3 then h.stuck = (h.stuck or 0) + 1 else h.stuck = 0 end
  h.lx, h.ly = x, y
  if h.stuck > 10 or (h.umweg or 0) > 0 then
    if h.stuck > 10 then h.umweg, h.stuck = 40, 0; h.umweg_s = ((h.umweg_s or 1) * -1) end
    h.umweg = h.umweg - 1
    return -dy / d * h.umweg_s, dx / d * h.umweg_s
  end
  return dx / d, dy / d
end

return S
