-- Der Hof (KATALOG §9, §2 Unterbringung): Bauten auf dem Grundstück, Plätze, Tagesverluste.
-- Das Hof-Grundstück liegt in der Mitte des Heimattals (area.plot). Ein Bau ist
-- {id (KATALOG §9), cx, cy}; Zäune und das Tor gehören zur Weide.
local K = require("game.katalog")

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

return Farm
