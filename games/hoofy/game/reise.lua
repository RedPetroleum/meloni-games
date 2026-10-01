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

-- Wie weit der Anhänger unter das Heck des Zugfahrzeugs rückt (Pixel; Flugzeug: Abstand).
R.HITCH = {fahrrad = 1, mofa = 2, kleinwagen = 2, suv = 2, flugzeug = -4}

-- Breite des Gespanns aus Zugfahrzeug f (id aus K.welt.fahrzeuge) und Anhänger für plaetze Pferde (0: ohne).
function R.rig_width(S, f, plaetze)
  local w = S.size("fahrzeug_" .. f)
  if plaetze == 0 then return w end
  return w - R.HITCH[f] + S.size("anhaenger_" .. plaetze)
end

-- Zeichnet das Gespann, Front links; x, y: linke untere Ecke auf dem Boden.
function R.draw_rig(S, f, plaetze, x, y)
  local name = "fahrzeug_" .. f
  local w, h = S.size(name)
  if plaetze > 0 then
    local tn = "anhaenger_" .. plaetze
    local _, th = S.size(tn)
    S.draw(tn, x + w - R.HITCH[f], y - th)
  end
  S.draw(name, x, y - h)
end

-- Figur für die Welt (ctx.world:add). Zu Hause steht das Zugfahrzeug in Schuppen/Garage/Hangar,
-- nur der Anhänger parkt rechts neben der Tür; unterwegs steht das ganze Gespann rechts neben dem
-- Ankunftspunkt. So verdeckt es weder Tür noch Spieler.
-- Prüft alle halbe Sekunde, ob sich Fahrzeug, Anhänger oder Gebäude geändert haben.
function R.entity(ctx)
  local e = {x = 0, y = 0, reach = 100, t = 0}
  local function place()
    local f = Economy.fahrzeug(ctx)
    local st = f.preis > 0 and R.station(ctx)
    e.f, e.plaetze, e.daheim = st and f.id, Economy.plaetze(ctx), ctx.area.farm ~= nil
    if st then e.x0, e.y = st[1] * 16 + 18, st[2] * 16 + 15 e.x = e.x0 + 40 end
  end
  place()
  function e.update()
    e.t = e.t + 1
    if e.t % 30 == 0 then place() end
  end
  function e.draw()
    if not e.f then return end
    if not e.daheim then R.draw_rig(ctx.S, e.f, e.plaetze, e.x0, e.y)
    elseif e.plaetze > 0 then
      local name = "anhaenger_" .. e.plaetze
      local _, h = ctx.S.size(name)
      ctx.S.draw(name, e.x0, e.y - h)
    end
  end
  return e
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
    if ctx.wild then ctx.wild:mark_loose() end
    heim = {pos = {flr(ctx.player.x), flr(ctx.player.y)}, aenderungen = ctx.map.changes, erkundet = ctx.explored}
  end
  local snap = {
    seed = seed, gebiet = nr, hof = ctx.hof, tag = clock.day, zeit = clock.t, geld = ctx.money, inv = ctx.inv,
    herd = ctx.herd, markt = ctx.market, kaeufer = ctx.buyer, bestellungen = ctx.orders,
    mit = mit, heim = heim, gefunden = ctx.gefunden, lager = ctx.lager, turnier = ctx.turnier, reform = ctx.reform, album = ctx.album, getauscht = ctx.getauscht,
  }
  if nr == 1 then       -- Heimfahrt: Zustand des Hofs zurück
    snap.pos, snap.aenderungen, snap.erkundet, snap.heim = heim.pos, heim.aenderungen, heim.erkundet, nil
  end
  return snap
end

return R
