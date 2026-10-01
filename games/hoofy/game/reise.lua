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
  local f = Economy.aktiv(ctx)
  if f.preis == 0 then return nil end
  local farm = ctx.area.farm
  if not farm then return ctx.area.places.start end
  for _, d in ipairs(Farm.vehicle_doors(farm)) do
    if d.fahrzeuge[f.id] then return d end
  end
end

-- Zu Hause: Tür eines Schuppens/einer Garage/eines Hangars mit eigenem Fahrzeug, vor der der Spieler steht.
function R.door_near(ctx)
  local farm = ctx.area.farm
  if not farm then return nil end
  local p = ctx.player
  for _, d in ipairs(Farm.vehicle_doors(farm)) do
    if U.dist(p.x, p.y, d[1] * 16 + 8, d[2] * 16 + 8) <= R.REACH then
      for id in pairs(d.fahrzeuge) do if (ctx.inv[id] or 0) > 0 then return d end end
    end
  end
end

function R.at_station(ctx)
  if R.door_near(ctx) then return true end
  local s = R.station(ctx)
  if not s then return false end
  local p = ctx.player
  return U.dist(p.x, p.y, s[1] * 16 + 8, s[2] * 16 + 8) <= R.REACH
end

-- Fahrzeuge zur Wahl im Reisemenü: zu Hause die eigenen im selben Gebäude (an dessen Tür der Spieler steht),
-- unterwegs nur das, mit dem man gekommen ist. Steht das gewählte woanders, wird das beste von hier gewählt.
function R.wahl(ctx)
  local a = Economy.aktiv(ctx)
  if not ctx.area.farm then return {a} end
  local d = R.door_near(ctx) or R.station(ctx)
  local out = {}
  for _, f in ipairs(K.welt.fahrzeuge) do
    if f.preis > 0 and (ctx.inv[f.id] or 0) > 0 and d and d.fahrzeuge[f.id] then out[#out + 1] = f end
  end
  if #out == 0 then return {a} end
  local here = false
  for _, f in ipairs(out) do if f == a then here = true end end
  if not here then Economy.waehlen(ctx, out[#out].id) end
  return out
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
    local f = Economy.aktiv(ctx)
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

-- ---- Anhänger (Rückmeldung 0.5.8): Pferde mit data.ort = "anhaenger" fahren mit ----

-- Linke Kante, Unterkante (Pixel) und Breite des Anhängers in der Welt, nil ohne Anhänger oder Fahrzeug.
-- Zu Hause parkt er neben der Garagentür, unterwegs hängt er hinter dem Zugfahrzeug (wie R.entity).
function R.trailer_box(ctx)
  local f, n = Economy.aktiv(ctx), Economy.plaetze(ctx)
  if f.preis == 0 or n == 0 then return nil end
  local st = R.station(ctx)
  if not st then return nil end
  local x0 = st[1] * 16 + 18
  if not ctx.area.farm then x0 = x0 + ctx.S.size("fahrzeug_" .. f.id) - R.HITCH[f.id] end
  return x0, st[2] * 16 + 15, (ctx.S.size("anhaenger_" .. n))
end

-- Steht der Spieler am Anhänger (davor, daneben oder dahinter)?
function R.at_trailer(ctx)
  local x0, y, w = R.trailer_box(ctx)
  if not x0 then return false end
  local p = ctx.player
  return p.x >= x0 - 10 and p.x <= x0 + w + 10 and p.y >= y - 26 and p.y <= y + 22
end

-- Pferde im Anhänger (Daten) und Plätze.
function R.geladen(ctx)
  return Farm.count(ctx.herd, "anhaenger"), Economy.plaetze(ctx)
end

-- Lädt alle Pferde aus dem Anhänger und stellt sie lose daneben (unter den Anhänger, nach rechts weiter).
-- Gibt die Anzahl zurück.
function R.ausladen(ctx)
  local x0, y, w = R.trailer_box(ctx)
  local p = ctx.player
  local n = 0
  for _, h in ipairs(ctx.herd_horses) do
    if h.data.ort == "anhaenger" then
      local hx, hy = p.x + n * 20, p.y + 12
      if x0 then
        for k = 0, 30 do
          local cx, cy = x0 + 8 + (n + k) % 4 * 20, y + 18 + (n + k) // 4 * 16
          if not ctx.map:blocked(cx - 8, cy - 6, cx + 8, cy) then hx, hy = cx, cy break end
        end
      end
      h.data.ort, h.hidden, h.bounds, h.allow = nil, false, nil, nil
      h.x, h.y, h.dir = hx, hy, "right"
      h.state, h.timer, h.vx, h.vy = "free", 120, 0, 0
      n = n + 1
    end
  end
  return n
end

-- Fahrtkosten nach nr: Kosten je Gebiet Entfernung × Abstand der Gebietsnummern.
function R.kosten(ctx, nr)
  return Economy.aktiv(ctx).fahrtkosten * math.abs(nr - ctx.area.nr)
end

-- Ziele der Reise: {nr, name, kosten, ok, grund}
-- Mitfahren: Pferde im Anhänger und die an der Leine (werden bei der Abfahrt eingeladen). Unterwegs müssen
-- alle eigenen Pferde mit, die da sind: ein loses Pferd hält die Abfahrt auf.
function R.ziele(ctx)
  local out = {}
  local mit = #ctx.lead + R.geladen(ctx)
  local draussen
  if not ctx.area.farm then
    for _, h in ipairs(ctx.herd_horses) do
      if not h.hidden and h.state ~= "ridden" and h.state ~= "led" and h.state ~= "follow" then draussen = draussen or h.data.name end
    end
  end
  for nr = 1, Economy.aktiv(ctx).gebiete do
    if nr ~= ctx.area.nr then
      local kosten = R.kosten(ctx, nr)
      local ok, why = true, nil
      if ctx.player.riding then ok, why = false, "erst absteigen"
      elseif mit > Economy.plaetze(ctx) then ok, why = false, "Anhänger zu klein (" .. mit .. " Pferde)"
      elseif draussen then ok, why = false, draussen .. " ist nicht im Anhänger"
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
  local lead = {}
  for i, h in ipairs(ctx.lead) do lead[i] = h end
  for _, h in ipairs(lead) do ctx.wild:house(h, "anhaenger", true) end
  local mit = {}
  for _, d in ipairs(ctx.herd) do if d.ort == "anhaenger" then mit[d] = true end end
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
