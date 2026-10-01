-- Der Hof (KATALOG §9, §2 Unterbringung): Bauten auf dem Grundstück, Plätze, Tagesverluste.
-- Das Hof-Grundstück liegt in der Mitte des Heimattals (area.plot). Ein Bau ist
-- {id (KATALOG §9), cx, cy}; Zäune und das Tor gehören zur Weide.
local K = require("game.katalog")
local Tiles = require("game.tiles")

local Farm = {}

-- Karte zu einem Hof merken (nicht im Spielstand), damit Plätze ohne Karte abgefragt werden können.
local MAPOF = setmetatable({}, {__mode = "k"})

Farm.PASTURE_PER_TILES = 10       -- ein Weideplatz je 10 freie Kacheln (E32)
Farm.FREE_PER_TILES = 50          -- ein Platz frei auf dem Grundstück je 50 Kacheln (E32)

-- Startausstattung (KATALOG §15): Wohnwagen, Stall S, Weide mit Tor.
function Farm.default(plot)
  local px, py = plot.x, plot.y
  return {
    plot = plot,
    home = {px + 10, py + 8},         -- Startpunkt im Hof (bleibt, wenn das Grundstück wächst)
    land = 0,                         -- gekaufte 10×10-Stücke (C7)
    buildings = {
      {id = "wohnwagen", cx = px + 2, cy = py + 2},
      {id = "stall_s", cx = px + 8, cy = py + 2},
    },
    -- Weide: Zaunring (außen), Tor in der oberen Kante
    weide = {x0 = px + 3, y0 = py + 10, x1 = px + 12, y1 = py + 16, gate = {px + 7, py + 10}},
    items = {},
  }
end

local PROP = {wohnwagen = "wohnwagen", stall_s = "stall_s"}

-- Trägt den Hof in die Karte ein (Objekte und Kollision). Mehrfaches Anwenden ist nicht vorgesehen.
function Farm.apply(map, farm)
  MAPOF[farm] = map
  for _, b in ipairs(farm.buildings) do
    local prop = PROP[b.id] or error("kein Bild für " .. b.id)
    map:add_object(prop, b.cx, b.cy)
    local P = map.props[prop]
    for dy = 0, (P.h or 1) - 1 do
      for dx = 0, (P.w or 1) - 1 do map:set("coll", b.cx + dx, b.cy + dy, P.coll) end
    end
  end
  local w = farm.weide
  local fence = {}
  for x = w.x0, w.x1 do fence[x .. "," .. w.y0] = true; fence[x .. "," .. w.y1] = true end
  for y = w.y0, w.y1 do fence[w.x0 .. "," .. y] = true; fence[w.x1 .. "," .. y] = true end
  local function f(x, y) return fence[x .. "," .. y] end
  local base = string.byte("A")
  for key in pairs(fence) do
    local x, y = key:match("(%d+),(%d+)")
    x, y = tonumber(x), tonumber(y)
    if x == w.gate[1] and y == w.gate[2] then
      map:add_object("gate", x, y)            -- Tor: begehbar
    else
      local m = (f(x - 1, y) and 1 or 0) + (f(x + 1, y) and 2 or 0) + (f(x, y - 1) and 4 or 0) +
        (f(x, y + 1) and 8 or 0)
      map:add_object("fence", x, y)
      map:set("coll", x, y, string.char(base + m))
    end
  end
  Farm.apply_items(map, farm)
end

-- Grenzen in Pixeln (Fußpunkt darf sich darin bewegen): {x0, y0, x1, y1}
function Farm.weide_bounds(farm)
  local w = farm.weide
  return {(w.x0 + 1) * 16 + 6, (w.y0 + 1) * 16 + 12, w.x1 * 16 - 6, w.y1 * 16 - 2}
end

function Farm.plot_bounds(farm)
  local p = farm.plot
  return {p.x * 16 + 8, p.y * 16 + 14, (p.x + p.w) * 16 - 8, (p.y + p.h) * 16 - 2}
end

-- Kachel vor der Stalltür (Mitte der Unterkante des ersten Stalls).
function Farm.stall_door(farm)
  for _, b in ipairs(farm.buildings) do
    if b.id:find("^stall_") then return {b.cx + 1, b.cy + 3} end
  end
end

-- Kachel vor der Wohnwagentür (Schlafen).
function Farm.bed_door(farm)
  for _, b in ipairs(farm.buildings) do
    if b.id == "wohnwagen" or b.id == "haeuschen" or b.id == "villa" then return {b.cx + 1, b.cy + 2} end
  end
end

-- Plätze: Stall (Summe der Ställe), Weide (Innenfläche / 10), frei (Grundstück / 50).
-- ---- Weiden (C2): geschlossene Flächen aus Zäunen, Gebäuden und anderen Bauten mit einem Tor ----

local DIRS4 = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

-- Alle Weiden des Hofs: {id = "cx,cy" (erste Kachel), tiles = {Kachelschlüssel = true}, n, list = {{cx, cy}…}, plaetze}.
-- Eine Weide ist eine zusammenhängende Fläche freier Kacheln auf dem Grundstück, die ringsum von Zaun,
-- Gebäuden oder Bauten begrenzt ist (keine Verbindung zum Rand des Grundstücks) und an ein Tor grenzt.
function Farm.pastures(map, farm)
  map = map or MAPOF[farm]
  local p = farm.plot
  local gates = {}
  local function key(cx, cy) return cx * 4096 + cy end
  for _, it in ipairs(farm.items or {}) do if it.id == "tor" then gates[key(it.cx, it.cy)] = true end end
  gates[key(farm.weide.gate[1], farm.weide.gate[2])] = true
  local function open(cx, cy)
    return map:walkable(cx, cy) and not gates[key(cx, cy)]
  end
  local seen, out = {}, {}
  for cy = p.y, p.y + p.h - 1 do
    for cx = p.x, p.x + p.w - 1 do
      if not seen[key(cx, cy)] and open(cx, cy) then
        local tiles, list, escaped, at_gate = {}, {}, false, false
        local stack = {{cx, cy}}
        seen[key(cx, cy)] = true
        while #stack > 0 do
          local t = table.remove(stack)
          tiles[key(t[1], t[2])] = true
          list[#list + 1] = t
          for _, d in ipairs(DIRS4) do
            local nx, ny = t[1] + d[1], t[2] + d[2]
            if nx < p.x or ny < p.y or nx >= p.x + p.w or ny >= p.y + p.h then
              escaped = true
            elseif gates[key(nx, ny)] then
              at_gate = true
            elseif open(nx, ny) and not seen[key(nx, ny)] then
              seen[key(nx, ny)] = true
              stack[#stack + 1] = {nx, ny}
            end
          end
        end
        if not escaped and at_gate then
          out[#out + 1] = {id = cx .. "," .. cy, tiles = tiles, n = #list, list = list,
            plaetze = flr(#list / Farm.PASTURE_PER_TILES)}
        end
      end
    end
  end
  return out
end

-- Liegt der Fußpunkt (Pixel) in der Weide?
function Farm.in_pasture(pasture, x, y)
  return pasture.tiles[flr(x / 16) * 4096 + flr((y - 1) / 16)] == true
end

function Farm.capacity(farm)
  local stall = 0
  for _, b in ipairs(Farm.all_buildings(farm)) do
    if b.id:find("^stall_") then stall = stall + K.bauteil(b.id).plaetze end
  end
  local weide = 0
  if MAPOF[farm] then
    for _, w in ipairs(Farm.pastures(nil, farm)) do weide = weide + w.plaetze end
  end
  return {
    stall = stall,
    weide = weide,
    frei = flr(farm.plot.w * farm.plot.h / Farm.FREE_PER_TILES),
  }
end

-- Pferde einer bestimmten Weide (data.weide_id).
function Farm.count_pasture(herd, id)
  local n = 0
  for _, d in ipairs(herd) do if d.ort == "weide" and d.weide_id == id then n = n + 1 end end
  return n
end

-- Wie viele Pferde der Liste sind an diesem Ort untergebracht?
function Farm.count(herd, ort)
  local n = 0
  for _, d in ipairs(herd) do if d.ort == ort then n = n + 1 end end
  return n
end

-- Darf das Pferd frei auf dem Grundstück leben? (nur ab Stärke 60 und Bindung 70)
function Farm.may_roam(data, H)
  local u = K.stats.unterbringung.frei
  return H.stat(data, "staerke") >= u.min_staerke and data.bindung >= u.min_bindung
end

local TRAIN = {"tempo", "staerke", "spuer", "ausdauer"}

-- Tagesverlust eines untergebrachten Pferds (KATALOG §2): Training sinkt je Stat um
-- verlust × (1 − Stärke/100), Sauberkeit sinkt. data.ort = "stall" / "weide" / "frei" / nil.
-- Gibt den Trainingsverlust je Stat zurück.
function Farm.daily(data, H)
  local u = K.stats.unterbringung[data.ort]
  if not u then return 0 end
  local loss = 0
  if u.verlust > 0 then loss = u.verlust * (1 - H.stat(data, "staerke") / 100) end
  for _, k in ipairs(TRAIN) do data.train[k] = max(0, data.train[k] - loss) end
  data.sauberkeit = max(0, data.sauberkeit + u.sauberkeit)
  return loss
end

-- ---- Baumodus (C1): Dinge, die der Spieler auf dem Grundstück baut ----
-- farm.items = Liste {id, cx, cy, alt}; alt = ursprüngliches Zeichen des Bodens bei Wegen/Böden.

Farm.CATEGORIES = {
  {id = "deko", name = "Deko", items = {"bank", "lampe", "blumenkuebel", "busch", "hecke", "stein", "baum", "brunnen", "teich", "statue"}},
  {id = "wege", name = "Wege", items = {"weg", "boden"}},
  {id = "anbau", name = "Anbau", items = {"beet", "feld"}},
  {id = "pflanzen", name = "Pflanzen", items = {}},          -- Liste der Samen im Vorrat, siehe Farm.categories
  {id = "zaun", name = "Zaun", items = {"zaun", "tor"}},
  {id = "gebaeude", name = "Bauten", items = {"stall_s", "stall_m", "stall_l", "stall_xl", "haeuschen", "villa", "schuppen", "garage", "hangar", "goepel_generator"}},
  {id = "land", name = "Land", items = {"land_n", "land_o", "land_s", "land_w"}},
  {id = "abriss", name = "Abreißen", items = {}},
}

-- ---- Land kaufen (C7): das Grundstück wächst streifenweise um 10 Kacheln, je 10×10-Stück 500 G, jedes weitere +250 ----
Farm.LAND_DIRS = {
  land_n = {name = "Land Nord", dx = 0, dy = -1}, land_o = {name = "Land Ost", dx = 1, dy = 0},
  land_s = {name = "Land Süd", dx = 0, dy = 1}, land_w = {name = "Land West", dx = -1, dy = 0},
}

-- Zahl der Stücke und Preis des Streifens in Richtung id; nil + Grund am Kartenrand.
function Farm.land_angebot(ctx, id)
  local d = Farm.LAND_DIRS[id]
  local p, map = ctx.area.farm.plot, ctx.map
  local n = ((d.dx ~= 0) and p.h or p.w) // 10
  local free
  if id == "land_n" then free = p.y elseif id == "land_w" then free = p.x
  elseif id == "land_s" then free = map.h - (p.y + p.h) else free = map.w - (p.x + p.w) end
  if free < 10 then return nil, "Kartenrand" end
  local k, sum = ctx.area.farm.land or 0, 0
  for i = 0, n - 1 do sum = sum + 500 + 250 * (k + i) end
  return sum, n
end

function Farm.buy_land(ctx, id)
  local farm = ctx.area.farm
  local price, n = Farm.land_angebot(ctx, id)
  if not price then return false, n end
  if ctx.money < price then return false, "Geld" end
  ctx.money = ctx.money - price
  local d, p = Farm.LAND_DIRS[id], farm.plot
  if id == "land_n" then p.y, p.h = p.y - 10, p.h + 10
  elseif id == "land_w" then p.x, p.w = p.x - 10, p.w + 10
  elseif id == "land_s" then p.h = p.h + 10 else p.w = p.w + 10 end
  farm.land = (farm.land or 0) + n
  return true, price
end

-- id → Bild (prop), Größe in Kacheln; Boden-Ersatz bei Wegen.
Farm.ITEMS = {
  bank = {prop = "bank"}, lampe = {prop = "lampe"}, blumenkuebel = {prop = "blumenkuebel"},
  busch = {prop = "bush"}, hecke = {prop = "hecke"}, stein = {prop = "rock"}, baum = {prop = "tree"},
  brunnen = {prop = "brunnen", w = 2, h = 2}, teich = {prop = "teich", w = 2, h = 2}, statue = {prop = "statue"},
  weg = {ground = ":"}, boden = {ground = "s"},
  beet = {ground = "b"}, feld = {ground = "b"},
  zaun = {prop = "fence", fence = true}, tor = {prop = "gate", gate = true},
  -- Gebäude (C3): Grundfläche in Kacheln
  wohnwagen = {prop = "wohnwagen", w = 3, h = 2, building = true},
  stall_s = {prop = "stall_s", w = 4, h = 3, building = true},
  stall_m = {prop = "stall_m", w = 6, h = 3, building = true},
  stall_l = {prop = "stall_l", w = 8, h = 4, building = true},
  stall_xl = {prop = "stall_xl", w = 10, h = 4, building = true},
  haeuschen = {prop = "haeuschen", w = 3, h = 2, building = true},
  villa = {prop = "villa", w = 5, h = 3, building = true},
  schuppen = {prop = "schuppen", w = 3, h = 2, building = true},
  garage = {prop = "garage", w = 4, h = 3, building = true},
  hangar = {prop = "hangar", w = 6, h = 4, building = true},
  goepel_generator = {prop = "goepel", w = 2, h = 2, building = true},
}

-- Alle Bauten des Hofs: Startbauten und gebaute Gebäude, {id, cx, cy}.
function Farm.all_buildings(farm)
  local out = {}
  for _, b in ipairs(farm.buildings) do out[#out + 1] = b end
  for _, it in ipairs(farm.items or {}) do
    if Farm.ITEMS[it.id].building then out[#out + 1] = it end
  end
  return out
end

-- Türen (Kachel vor der Mitte der Unterkante) aller Gebäude, die die Bedingung erfüllen.
local function doors(farm, pred)
  local out = {}
  for _, b in ipairs(Farm.all_buildings(farm)) do
    if pred(b.id) then
      local it = Farm.ITEMS[b.id]
      out[#out + 1] = {b.cx + (it.w - 1) // 2, b.cy + it.h, id = b.id}
    end
  end
  return out
end

function Farm.stall_doors(farm) return doors(farm, function(id) return id:find("^stall_") ~= nil end) end
function Farm.bed_doors(farm)
  return doors(farm, function(id) return id == "wohnwagen" or id == "haeuschen" or id == "villa" end)
end

-- Bindung pro Tag für Pferde im Stall: der beste Stall zählt (KATALOG §9: 1/2/3/4).
function Farm.stall_bonus(farm)
  local best = 0
  for _, b in ipairs(Farm.all_buildings(farm)) do
    if b.id:find("^stall_") then best = max(best, K.bauteil(b.id).bindung_tag or 0) end
  end
  return best
end

-- Welche Fahrzeuge kann der Hof unterstellen (Schuppen, Garage, Hangar)? Gibt Menge id → true zurück.
function Farm.garaged(farm)
  local out = {}
  for _, b in ipairs(Farm.all_buildings(farm)) do
    local def = K.bauteil(b.id)
    for _, v in ipairs(def.fahrzeuge or {}) do out[v] = true end
  end
  return out
end

-- Göpel-Generatoren (C6): je Generator ein Pferd, das Stärke und Energie mitbringt, bringt Geld pro Tag.
-- Gibt die Pferde zurück, die heute laufen (stärkste zuerst), und das Geld je Pferd.
function Farm.goepel_pferde(farm, herd, H)
  local n, def = 0, K.bauteil("goepel_generator")
  for _, b in ipairs(Farm.all_buildings(farm)) do if b.id == "goepel_generator" then n = n + 1 end end
  local ok = {}
  for _, d in ipairs(herd) do
    if d.ort and d.alter >= 1 and H.stat(d, "staerke") >= def.min_staerke and d.energie >= def.energie then ok[#ok + 1] = d end
  end
  table.sort(ok, function(a, b) return H.stat(a, "staerke") > H.stat(b, "staerke") end)
  while #ok > n do ok[#ok] = nil end
  return ok, def.geld_pferd
end

local function size(id)
  local it = Farm.ITEMS[id]
  return it.w or 1, it.h or 1
end

local byte = string.byte

local function cell_key(cx, cy) return cx * 4096 + cy end

-- Index: Kachel → Item (für alle Kacheln der Grundfläche) aus farm.items aufbauen.
local INDEX = setmetatable({}, {__mode = "k"})     -- nicht im Spielstand: farm → Index

function Farm.reindex(farm)
  local index = {}
  for _, it in ipairs(farm.items) do
    local w, h = size(it.id)
    for dy = 0, h - 1 do
      for dx = 0, w - 1 do index[cell_key(it.cx + dx, it.cy + dy)] = it end
    end
  end
  INDEX[farm] = index
  return index
end

function Farm.item_at(farm, cx, cy)
  return (INDEX[farm] or Farm.reindex(farm))[cell_key(cx, cy)]
end

local function in_plot(farm, cx, cy, w, h)
  local p = farm.plot
  return cx >= p.x and cy >= p.y and cx + w <= p.x + p.w and cy + h <= p.y + p.h
end

-- Gehört die Kachel zu einem Zaunstück (Zaun-Kollision A..P, Tor, Weidentor)?
local function is_fence(map, farm, cx, cy)
  if cx < 0 or cy < 0 or cx >= map.w or cy >= map.h then return false end
  local c = byte(map.coll[cy + 1], cx + 1) - Tiles.FENCE_BASE
  if c >= 0 and c < 16 then return true end
  local it = Farm.item_at(farm, cx, cy)
  if it and it.id == "tor" then return true end
  local g = farm.weide.gate
  return g[1] == cx and g[2] == cy
end

-- Zaunform einer Kachel aus den Nachbarn neu setzen (nur Zaunstücke mit Kollision, keine Tore).
local function refit_fence(map, farm, cx, cy)
  if cx < 0 or cy < 0 or cx >= map.w or cy >= map.h then return end
  local c = byte(map.coll[cy + 1], cx + 1) - Tiles.FENCE_BASE
  if c < 0 or c >= 16 then return end
  local m = (is_fence(map, farm, cx - 1, cy) and 1 or 0) + (is_fence(map, farm, cx + 1, cy) and 2 or 0) +
    (is_fence(map, farm, cx, cy - 1) and 4 or 0) + (is_fence(map, farm, cx, cy + 1) and 8 or 0)
  map:set("coll", cx, cy, string.char(Tiles.FENCE_BASE + m), true)
  map:refresh_block_at(cx, cy)
end

local function refit_around(map, farm, cx, cy)
  for _, d in ipairs({{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do refit_fence(map, farm, cx + d[1], cy + d[2]) end
end

-- Darf id an (cx, cy) gebaut werden? player: {x, y} des Spielers in Pixeln (darf nicht im Weg stehen).
-- Gibt true oder false und den Grund zurück.
function Farm.can_place(map, farm, id, cx, cy, player)
  local it = Farm.ITEMS[id] or error("unbekanntes Bauteil " .. tostring(id))
  local w, h = size(id)
  if not in_plot(farm, cx, cy, w, h) then return false, "nur auf dem Grundstück" end
  for dy = 0, h - 1 do
    for dx = 0, w - 1 do
      local x, y = cx + dx, cy + dy
      if Farm.item_at(farm, x, y) then return false, "schon belegt" end
      if byte(map.coll[y + 1], x + 1) ~= 46 then return false, "im Weg" end
      local g = map:code(x, y)
      if it.ground then
        if g ~= "." then return false, "nur auf Gras" end
      elseif g ~= "." and g ~= ":" and g ~= "s" then
        return false, "hier nicht möglich"
      end
      local wg = farm.weide.gate
      if wg[1] == x and wg[2] == y then return false, "im Weg" end
    end
  end
  if player and not it.ground and not it.gate then
    local pcx, pcy = flr(player.x / 16), flr((player.y - 2) / 16)
    if pcx >= cx and pcx < cx + w and pcy >= cy and pcy < cy + h then return false, "du stehst im Weg" end
  end
  return true
end

local function put(map, farm, it)
  local d = Farm.ITEMS[it.id]
  local w, h = size(it.id)
  if d.ground then
    it.alt = map:code(it.cx, it.cy)
    local row = map.ground[it.cy + 1]
    map:set("ground", it.cx, it.cy, d.ground, true)
    return
  end
  map:add_object(d.prop, it.cx, it.cy)
  local P = map.props[d.prop]
  if d.gate then
    -- Tor: begehbar, verbindet die Nachbarzäune
  elseif d.fence then
    map:set("coll", it.cx, it.cy, string.char(Tiles.FENCE_BASE), true)
  else
    for dy = 0, h - 1 do
      for dx = 0, w - 1 do map:set("coll", it.cx + dx, it.cy + dy, P.coll, true) end
    end
  end
end

-- Baut und zieht den Preis ab (ctx.money). Gibt true oder false und den Grund zurück.
function Farm.place(ctx, id, cx, cy)
  local farm, map = ctx.area.farm, ctx.map
  local ok, why = Farm.can_place(map, farm, id, cx, cy, ctx.player)
  if not ok then return false, why end
  local price = K.bauteil(id).preis
  if ctx.money < price then return false, "Geld" end
  ctx.money = ctx.money - price
  local it = {id = id, cx = cx, cy = cy}
  farm.items[#farm.items + 1] = it
  Farm.reindex(farm)
  put(map, farm, it)
  if Farm.ITEMS[id].fence or Farm.ITEMS[id].gate then refit_around(map, farm, cx, cy) end
  return true
end

-- Reißt ab, was an (cx, cy) steht, und erstattet den Kaufpreis. Gibt Erstattung oder nil, Grund zurück.
function Farm.remove(ctx, cx, cy)
  local farm, map = ctx.area.farm, ctx.map
  local plant = Farm.plant_at(farm, cx, cy)
  if plant then
    Farm.remove_plant(ctx, plant)
    return 0
  end
  local it = Farm.item_at(farm, cx, cy)
  if not it then return nil, "hier steht nichts Abreißbares" end
  local d = Farm.ITEMS[it.id]
  for i, e in ipairs(farm.items) do if e == it then table.remove(farm.items, i) break end end
  Farm.reindex(farm)
  if d.ground then
    map:set("ground", it.cx, it.cy, it.alt or ".", true)
  else
    map:remove_object(d.prop, it.cx, it.cy)
    local w, h = size(it.id)
    if not d.gate then
      for dy = 0, h - 1 do
        for dx = 0, w - 1 do map:set("coll", it.cx + dx, it.cy + dy, ".", true) end
      end
    end
  end
  if d.fence or d.gate then refit_around(map, farm, it.cx, it.cy) end
  local price = K.bauteil(it.id).preis
  ctx.money = ctx.money + price
  return price
end

-- Zaunring um x0..x1 × y0..y1 (Kacheln, äußerer Rand), Tor an gate = {cx, cy} (nil: geschlossen ohne Tor).
-- Für Szenarien und Tests; kostet wie beim Bauen. Gibt die Zahl der gebauten Stücke zurück.
function Farm.fence_rect(ctx, x0, y0, x1, y1, gate)
  local n = 0
  for x = x0, x1 do
    for _, y in ipairs({y0, y1}) do
      local id = (gate and gate[1] == x and gate[2] == y) and "tor" or "zaun"
      if Farm.place(ctx, id, x, y) then n = n + 1 end
    end
  end
  for y = y0 + 1, y1 - 1 do
    for _, x in ipairs({x0, x1}) do
      local id = (gate and gate[1] == x and gate[2] == y) and "tor" or "zaun"
      if Farm.place(ctx, id, x, y) then n = n + 1 end
    end
  end
  return n
end

-- Schönheit des Hofs: Summe der Deko-Punkte (KATALOG §9), für C4.
function Farm.schoenheit(farm)
  local sum = 0
  for _, it in ipairs(farm.items) do sum = sum + (K.bauteil(it.id).wirkung.schoenheit or 0) end
  for _, b in ipairs(farm.buildings) do sum = sum + ((K.bauteil(b.id).wirkung or {}).schoenheit or 0) end
  for _, p in ipairs(farm.pflanzen or {}) do
    local crop = Farm.crop(p.id)
    if crop.deko then sum = sum + (crop.wirkung.schoenheit or 0) end
  end
  return sum
end

-- Bindung pro Tag für alle Pferde aus der Hof-Schönheit (KATALOG §9): ab 50 / 150 / 400 → +1 / +2 / +3.
-- Gibt Bonus (0–3) und die Stufe des nächsten Ziels (Schwelle oder nil) zurück.
function Farm.schoenheit_bonus(farm)
  local score = Farm.schoenheit(farm)
  local stufen, bonus = K.bau.schoenheit_stufen, K.bau.schoenheit_bindung
  local b, next_at = 0, stufen[1]
  for i, limit in ipairs(stufen) do
    if score >= limit then b = bonus[i]; next_at = stufen[i + 1] end
  end
  return b, next_at, score
end

-- Spielerbauten beim Laden wieder in die Karte eintragen (Farm.apply ruft das).
function Farm.apply_items(map, farm)
  farm.items = farm.items or {}
  farm.pflanzen = farm.pflanzen or {}
  Farm.reindex(farm)
  for _, it in ipairs(farm.items) do put(map, farm, it) end
  Farm.apply_plants(map, farm)
  for _, it in ipairs(farm.items) do
    if Farm.ITEMS[it.id].fence or Farm.ITEMS[it.id].gate then refit_around(map, farm, it.cx, it.cy) end
  end
end

-- ---- Anbau (C5): Pflanzen auf Beeten (farm.pflanzen = Liste {id, cx, cy, start, bereit, stufe}) ----

-- Ertrag: Pflanze → Name des Vorrats-Eintrags (heu, karotte, hafer wie im Laden, sonst eigene Namen)
Farm.CROP_ITEM = {gras = "heu", karotte = "karotte", apfelbaum = "apfel", hafer = "hafer", sonnenblume = "sonnenblumenkerne",
  minze = "minze", zuckerruebe = "zuckerruebe", luzerne = "luzerne", drachenfrucht = "drachenfrucht", goldene_karotte = "goldene_karotte"}
Farm.CROP_NAME = {heu = "Heu", karotte = "Karotte", apfel = "Äpfel", hafer = "Hafer", sonnenblumenkerne = "Sonnenblumenkerne",
  minze = "Minze", zuckerruebe = "Zuckerrüben", luzerne = "Luzerne", drachenfrucht = "Drachenfrüchte", goldene_karotte = "Goldene Karotten"}

function Farm.crop(id)
  for _, p in ipairs(K.futter.anbau) do if p.id == id then return p end end
  error("unbekannte Pflanze " .. tostring(id))
end

local function pkind(p) return "pflanze_" .. p.id .. "_" .. p.stufe end

-- Kategorien des Baumodus: wie Farm.CATEGORIES, „Pflanzen“ enthält die gekauften Samen (einmalig gekauft = unbegrenzt pflanzbar).
function Farm.categories(ctx)
  local out = {}
  for _, c in ipairs(Farm.CATEGORIES) do
    if c.id == "pflanzen" then
      local items = {}
      for _, p in ipairs(K.futter.anbau) do
        if (ctx.inv["samen_" .. p.id] or 0) > 0 then items[#items + 1] = p.id end
      end
      out[#out + 1] = {id = c.id, name = c.name, items = items}
    else
      out[#out + 1] = c
    end
  end
  return out
end

function Farm.plant_at(farm, cx, cy)
  for _, p in ipairs(farm.pflanzen or {}) do
    local crop = Farm.crop(p.id)
    if cx >= p.cx and cx < p.cx + crop.w and cy >= p.cy and cy < p.cy + crop.h then return p end
  end
end

-- Darf id an (cx, cy) gepflanzt werden? Braucht den Samen im Vorrat (einmal gekauft), Beet auf allen Kacheln, nichts darauf.
function Farm.can_plant(ctx, id, cx, cy)
  local farm, map = ctx.area.farm, ctx.map
  if (ctx.inv["samen_" .. id] or 0) < 1 then return false, "kein Samen" end
  local crop = Farm.crop(id)
  for dy = 0, crop.h - 1 do
    for dx = 0, crop.w - 1 do
      if map:code(cx + dx, cy + dy) ~= "b" then return false, "braucht Beet" end
      if Farm.plant_at(farm, cx + dx, cy + dy) then return false, "schon bepflanzt" end
    end
  end
  return true
end

local function stage_of(p, day)
  if day >= p.bereit then return 3 end
  local total = max(1, p.bereit - p.start)
  return ((day - p.start) / total >= 0.5) and 2 or 1
end

local function put_plant(map, p)
  map:add_object(pkind(p), p.cx, p.cy)
end

-- Pflanzt (kostenlos, der Samen bleibt: die Pflanze trägt danach unbegrenzt). day: heutiger Tag.
function Farm.plant(ctx, id, cx, cy, day)
  local ok, why = Farm.can_plant(ctx, id, cx, cy)
  if not ok then return false, why end
  local farm = ctx.area.farm
  local crop = Farm.crop(id)
  day = day or (ctx.clock and ctx.clock.day) or 1
  local p = {id = id, cx = cx, cy = cy, start = day, bereit = day + crop.reif, stufe = 1}
  p.stufe = stage_of(p, day)
  farm.pflanzen = farm.pflanzen or {}
  farm.pflanzen[#farm.pflanzen + 1] = p
  put_plant(ctx.map, p)
  return true
end

-- Ausgewachsene Pflanze ernten: Ertrag in den Vorrat, nächste Reife nach „dann alle“ Tagen. Gibt Vorrats-Name und Menge zurück.
function Farm.harvest(ctx, p, day)
  if p.stufe < 3 then return nil, "noch nicht reif" end
  local crop = Farm.crop(p.id)
  local item = Farm.CROP_ITEM[p.id]
  ctx.inv[item] = (ctx.inv[item] or 0) + crop.ertrag
  day = day or (ctx.clock and ctx.clock.day) or 1
  ctx.map:remove_object(pkind(p), p.cx, p.cy)
  p.start, p.bereit = day, day + crop.dann
  p.stufe = 1
  put_plant(ctx.map, p)
  return item, crop.ertrag
end

-- Nächste reife Pflanze in Reichweite des Spielers (Pixel), nil wenn keine.
function Farm.ripe_near(ctx, reach)
  reach = reach or 26
  local best, bd = nil, reach
  local pl = ctx.player
  for _, p in ipairs(ctx.area.farm.pflanzen or {}) do
    if p.stufe == 3 then
      local crop = Farm.crop(p.id)
      local x, y = (p.cx + crop.w / 2) * 16, (p.cy + crop.h / 2) * 16
      local d = math.sqrt((x - pl.x) ^ 2 + (y - (pl.y - 6)) ^ 2)
      if d <= bd then best, bd = p, d end
    end
  end
  return best
end

-- Tageswechsel (day = neuer Tag): Pflanzen wachsen, Bilder wechseln. Gibt die Zahl reifer Pflanzen zurück.
function Farm.grow(ctx, day)
  local ripe = 0
  for _, p in ipairs(ctx.area.farm.pflanzen or {}) do
    local stufe = stage_of(p, day)
    if stufe ~= p.stufe then
      ctx.map:remove_object(pkind(p), p.cx, p.cy)
      p.stufe = stufe
      put_plant(ctx.map, p)
    end
    if p.stufe == 3 then ripe = ripe + 1 end
  end
  return ripe
end

-- Pflanze entfernen (Abreißen): kein Geld zurück, der Samen bleibt.
function Farm.remove_plant(ctx, p)
  local farm = ctx.area.farm
  for i, e in ipairs(farm.pflanzen) do if e == p then table.remove(farm.pflanzen, i) break end end
  ctx.map:remove_object(pkind(p), p.cx, p.cy)
end

-- Pflanzen beim Laden wieder in die Karte eintragen.
function Farm.apply_plants(map, farm)
  farm.pflanzen = farm.pflanzen or {}
  for _, p in ipairs(farm.pflanzen) do put_plant(map, p) end
end

return Farm
