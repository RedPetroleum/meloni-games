-- Der Hof (KATALOG §9, §2 Unterbringung): Bauten auf dem Grundstück, Plätze, Tagesverluste.
-- Das Hof-Grundstück liegt in der Mitte des Heimattals (area.plot). Ein Bau ist
-- {id (KATALOG §9), cx, cy}; Zäune und das Tor gehören zur Weide.
local K = require("game.katalog")
local Tiles = require("game.tiles")

local Farm = {}

Farm.PASTURE_PER_TILES = 10       -- ein Weideplatz je 10 freie Kacheln (E32)
Farm.FREE_PER_TILES = 50          -- ein Platz frei auf dem Grundstück je 50 Kacheln (E32)

-- Startausstattung (KATALOG §15): Wohnwagen, Stall S, Weide mit Tor.
function Farm.default(plot)
  local px, py = plot.x, plot.y
  return {
    plot = plot,
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
function Farm.capacity(farm)
  local stall = 0
  for _, b in ipairs(farm.buildings) do
    if b.id:find("^stall_") then stall = stall + K.bauteil(b.id).plaetze end
  end
  local w = farm.weide
  local interior = (w.x1 - w.x0 - 1) * (w.y1 - w.y0 - 1)
  return {
    stall = stall,
    weide = flr(interior / Farm.PASTURE_PER_TILES),
    frei = flr(farm.plot.w * farm.plot.h / Farm.FREE_PER_TILES),
  }
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
  {id = "zaun", name = "Zaun", items = {"zaun", "tor"}},
  {id = "abriss", name = "Abreißen", items = {}},
}

-- id → Bild (prop), Größe in Kacheln; Boden-Ersatz bei Wegen.
Farm.ITEMS = {
  bank = {prop = "bank"}, lampe = {prop = "lampe"}, blumenkuebel = {prop = "blumenkuebel"},
  busch = {prop = "bush"}, hecke = {prop = "hecke"}, stein = {prop = "rock"}, baum = {prop = "tree"},
  brunnen = {prop = "brunnen", w = 2, h = 2}, teich = {prop = "teich", w = 2, h = 2}, statue = {prop = "statue"},
  weg = {ground = ":"}, boden = {ground = "s"},
  zaun = {prop = "fence", fence = true}, tor = {prop = "gate", gate = true},
}

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

-- Schönheit des Hofs: Summe der Deko-Punkte (KATALOG §9), für C4.
function Farm.schoenheit(farm)
  local sum = 0
  for _, it in ipairs(farm.items) do sum = sum + (K.bauteil(it.id).wirkung.schoenheit or 0) end
  for _, b in ipairs(farm.buildings) do sum = sum + ((K.bauteil(b.id).wirkung or {}).schoenheit or 0) end
  return sum
end

-- Spielerbauten beim Laden wieder in die Karte eintragen (Farm.apply ruft das).
function Farm.apply_items(map, farm)
  farm.items = farm.items or {}
  Farm.reindex(farm)
  for _, it in ipairs(farm.items) do put(map, farm, it) end
  for _, it in ipairs(farm.items) do
    if Farm.ITEMS[it.id].fence or Farm.ITEMS[it.id].gate then refit_around(map, farm, it.cx, it.cy) end
  end
end

return Farm
