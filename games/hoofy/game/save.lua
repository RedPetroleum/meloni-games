-- Spielstand (README §Technik, KATALOG §1: Speichern beim Schlafen, Gebietswechsel und Beenden).
-- Gespeichert wird nur, was sich gegenüber dem Seed geändert hat: Seed, Tag und Uhrzeit, Geld,
-- Vorrat, die Pferde (reine Datentabellen), der Hof und die Kartenänderungen.
local Save = {}

Save.VERSION = 1

-- Wie savedata() in der Engine: Lua-Text, Zahlen, Strings, Booleans, verschachtelte Tabellen.
-- Nur für die Größenangabe im Test und zum Vergleichen.
function Save.encode(v)
  local t = type(v)
  if t == "number" then
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.9g", v)
  elseif t == "string" then return string.format("%q", v)
  elseif t == "boolean" then return tostring(v)
  elseif t == "table" then
    local parts = {}
    for k, val in pairs(v) do parts[#parts + 1] = "[" .. Save.encode(k) .. "]=" .. Save.encode(val) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("nicht speicherbar: " .. t)
end

-- Der Spielstand als Tabelle. clock: game/clock.lua, ctx: Welt. Ein aufgesessener Reiter wird
-- dabei nicht abgesattelt, das Pferd bleibt einfach beim Spieler.
function Save.snapshot(ctx, clock, seed)
  local p = ctx.player
  if ctx.wild then ctx.wild:mark_loose() end
  local herd = {}
  for i, d in ipairs(ctx.herd) do herd[i] = d end
  -- Unterwegs gespeichert: der Spielstand liegt zu Hause (Fahrzeug fährt heim, Mitgenommene kommen an die Leine)
  local heim = ctx.heim
  if heim then
    return {
      ver = Save.VERSION, seed = seed, gebiet = 1,
      tag = clock.day, zeit = clock.t, geld = ctx.money, inv = ctx.inv, pos = heim.pos,
      herd = herd, hof = ctx.hof, aenderungen = heim.aenderungen, erkundet = heim.erkundet, markt = ctx.market,
      kaeufer = ctx.buyer, bestellungen = ctx.orders, gefunden = ctx.gefunden, turnier = ctx.turnier, reform = ctx.reform, album = ctx.album, getauscht = ctx.getauscht,
      gezaehmt = ctx.gezaehmt, jobs = ctx.jobs, namen = require("game.horse_model").used_names(), outfit = ctx.outfit,
    }
  end
  return {
    ver = Save.VERSION, seed = seed, gebiet = ctx.area.nr,
    tag = clock.day, zeit = clock.t, geld = ctx.money, inv = ctx.inv,
    pos = {flr(p.x), flr(p.y)},
    herd = herd, hof = ctx.area.farm, aenderungen = ctx.map.changes, erkundet = ctx.explored, markt = ctx.market, kaeufer = ctx.buyer, bestellungen = ctx.orders,
    gefunden = ctx.gefunden, lager = ctx.lager, turnier = ctx.turnier, reform = ctx.reform, album = ctx.album, getauscht = ctx.getauscht,
      gezaehmt = ctx.gezaehmt, jobs = ctx.jobs, namen = require("game.horse_model").used_names(), outfit = ctx.outfit,
  }
end

-- Lädt einen Spielstand, falls es einen gültigen gibt (nil sonst; Test-Spielstände zählen nicht).
function Save.read()
  local s = loaddata()
  if type(s) ~= "table" or s.scenario or s.ver ~= Save.VERSION then return nil end
  return s
end

function Save.write(snap)
  savedata(snap)
end

-- Neuer Weltseed (E18).
function Save.new_seed()
  return 1 + flr(rnd(900000))
end

return Save
