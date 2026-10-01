-- Reisen (Aufgabe D1): Zugfahrzeug und Anhänger bestimmen, wohin es geht und wie viele Pferde mitkommen.
-- Zu Hause steht das Fahrzeug an der Tür des Schuppens/der Garage/des Hangars, unterwegs am Ankunftspunkt.
local K = require("game.katalog")
local Economy = require("game.economy")
local Farm = require("game.farm")
local U = require("lib.util")

local R = {}

R.REACH = 26

-- Kachel, an der das Fahrzeug steht: unterwegs der Ankunftspunkt, zu Hause die Tür der Garage, die es unterstellt.
function R.station(ctx)
  local f = Economy.fahrzeug(ctx)
  if f.preis == 0 then return nil end
  local farm = ctx.area.farm
  if not farm then return ctx.area.places.start end
  for _, d in ipairs(Farm.vehicle_doors(farm)) do
    if d.fahrzeuge[f.id] then return d end
  end
end

function R.at_station(ctx)
  local s = R.station(ctx)
  if not s then return false end
  local p = ctx.player
  return U.dist(p.x, p.y, s[1] * 16 + 8, s[2] * 16 + 8) <= R.REACH
end

-- Fahrtkosten nach nr: Kosten je Gebiet Entfernung × Abstand der Gebietsnummern.
function R.kosten(ctx, nr)
  return Economy.fahrzeug(ctx).fahrtkosten * math.abs(nr - ctx.area.nr)
end

-- Ziele der Reise: {nr, name, kosten, ok, grund}
function R.ziele(ctx)
  local out = {}
  local mit = #ctx.lead
  for nr = 1, ctx.max_gebiet or 1 do
    if nr ~= ctx.area.nr then
      local kosten = R.kosten(ctx, nr)
      local ok, why = true, nil
      if ctx.player.riding then ok, why = false, "erst absteigen"
      elseif mit > Economy.plaetze(ctx) then ok, why = false, "Anhänger zu klein (" .. mit .. " Pferde)"
      elseif ctx.money < kosten then ok, why = false, "zu wenig Geld" end
      out[#out + 1] = {nr = nr, name = K.welt.gebiete[nr].name, kosten = kosten, ok = ok, grund = why}
    end
  end
  return out
end

-- Reisedaten für WorldScene.enter({reise = …}): Zustand der Welt, wie ein Spielstand, dazu das Gebiet.
-- Bezahlt die Fahrt. clock: Uhr der Welt. Gibt nil und den Grund zurück, wenn es nicht geht.
function R.fahren(ctx, clock, seed, nr)
  local ziel
  for _, z in ipairs(R.ziele(ctx)) do if z.nr == nr then ziel = z end end
  if not ziel then return nil, "nicht erreichbar" end
  if not ziel.ok then return nil, ziel.grund end
  ctx.money = ctx.money - ziel.kosten
  local mit = {}
  for _, h in ipairs(ctx.lead) do mit[h.data] = true end
  local heim = ctx.heim
  if not heim then      -- Abfahrt vom Hof: den Hof so merken, wie er ist
    heim = {pos = {flr(ctx.player.x), flr(ctx.player.y)}, aenderungen = ctx.map.changes, erkundet = ctx.explored}
  end
  local snap = {
    seed = seed, gebiet = nr, hof = ctx.hof, tag = clock.day, zeit = clock.t, geld = ctx.money, inv = ctx.inv,
    herd = ctx.herd, markt = ctx.market, kaeufer = ctx.buyer, bestellungen = ctx.orders,
    mit = mit, heim = heim, gefunden = ctx.gefunden, lager = ctx.lager, turnier = ctx.turnier, reform = ctx.reform,
  }
  if nr == 1 then       -- Heimfahrt: Zustand des Hofs zurück
    snap.pos, snap.aenderungen, snap.erkundet, snap.heim = heim.pos, heim.aenderungen, heim.erkundet, nil
  end
  return snap
end

return R
