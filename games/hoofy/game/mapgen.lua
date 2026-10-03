-- Erzeugt ein Gebiet aus einem Seed: Wiesen, Wald, Fluss mit Brücken, Wege, Hof-Grundstück, Dorf.
-- Ergebnis ist die Beschreibung für lib/tilemap.lua (Zeilen als Strings, Objekte als Liste) plus
-- Orte (places) für die Spielregeln. Gleicher Seed = gleiche Karte.
--
-- Beim Erzeugen gibt es flache Arrays über alle Kacheln (eine Zahl je Kachel); übrig bleiben nur
-- Strings je Zeile.
local Rng = require("lib.rng")
local U = require("lib.util")
local Tiles = require("game.tiles")

local Gen = {}

local byte, char = string.byte, string.char
local GRASS, FOREST, WATER = byte("."), byte("F"), byte("~")
local BRIDGE, BRIDGE_V, PATH, SAND = byte("="), byte("I"), byte(":"), byte("s")
local FORD, CHASM = byte("f"), byte("c")
local DOT = byte(".")

-- Landschaft je Gebiet (Rückmeldung 1.5.2, E84): jedes Gebiet sieht anders aus und spielt sich anders.
-- Das Heimattal (1) hat kein Profil und bleibt Kachel für Kachel wie bisher (gespeicherte Höfe sind Änderungen
-- gegenüber dem Seed).
--   wald      Schwelle des Rauschens für Wald (niedriger = mehr Wald), Heimattal 0,64
--   rand      Breite des dichten Waldrands, Heimattal 5
--   fluss     Boden des Flusses: "wasser", "sand" (Trockenbett) oder false (keiner); breite = {schmal, breit}
--   fluesse   so viele Flüsse (Flussauen 2)
--   seen      Rauschen über diesem Wert wird See, darüber inseln wieder Land (Inseln im See)
--   furten    Wege über Wasser werden Furten (begehbar, langsam) statt Brücken
--   schluchten so viele Schluchten (Canyon), quer und längs
--   insel     Meer statt Wald am Rand (Nebelinsel)
--   objekte   Anteil der Wiesenkacheln mit Objekt und die Mischung {Art, Anteil bis}
Gen.PROFILES = {
  [2] = {wald = 0.47, rand = 4, fluss = "wasser", breite = {1, 2},
    objekte = {0.07, {{"birke", 0.045}, {"bush", 0.06}, {"rock", 0.07}}}},
  [3] = {wald = 0.70, fluss = "wasser", fluesse = 2, breite = {2, 4}, seen = 0.55, inseln = 0.67, furten = true,
    objekte = {0.035, {{"tree", 0.012}, {"bush", 0.03}, {"rock", 0.035}}}},
  [4] = {wald = 0.80, fluss = "sand", breite = {2, 3},
    objekte = {0.06, {{"kaktus", 0.034}, {"rock", 0.048}, {"bush", 0.06}}}},
  [5] = {wald = 0.76, fluss = false, schluchten = 3,
    objekte = {0.055, {{"rock", 0.03}, {"kaktus", 0.04}, {"bush", 0.055}}}},
  [6] = {wald = 0.60, fluss = "wasser", breite = {2, 3}, insel = true,
    objekte = {0.04, {{"tree", 0.018}, {"bush", 0.03}, {"rock", 0.04}}}},
}

-- Dorf (E12): Zeichen siehe VILLAGE_LEGEND, Großbuchstaben sind Objekte mit Grundfläche ab dort,
-- "x" gehört zu einer Grundfläche. Zeile 5 ist die Dorfstraße.
local VILLAGE = {
  "..........................",
  "..b..Lxx.......Cxx.....b..",
  ".....xxx.......xxx........",
  "......:..Mx.....:.........",
  "......:....B....:.........",
  "::::::::::::::::::::::::::",
  ".....:...........:........",
  "..###:#.....#####:#####...",
  "..#sss#.....#sssssssss#...",
  "..#sss#.....#ssJssssJs#...",
  "..#sss#.....#sssssssss#...",
  "..#####.....#sssJsssss#...",
  "............#sssssssss#...",
  "............###########...",
  "..........................",
}
local VILLAGE_LEGEND = {
  L = "shop", C = "cottage", M = "stand", B = "board", J = "jump", b = "bush", ["#"] = "fence",
}
-- Orte im Dorf (Kachel vor der Tür bzw. am Stand), relativ zur Vorlage.
local VILLAGE_PLACES = {
  laden = {6, 3}, wohnhaus = {16, 3}, jobbrett = {11, 5}, markt = {9, 4}, turnier = {17, 7}, marktkoppel = {5, 7},
}

-- Binärer Heap für A*.
local function heap_push(h, cost, id)
  local n = #h.c + 1
  h.c[n], h.i[n] = cost, id
  while n > 1 do
    local p = n // 2
    if h.c[p] <= h.c[n] then break end
    h.c[p], h.c[n] = h.c[n], h.c[p]
    h.i[p], h.i[n] = h.i[n], h.i[p]
    n = p
  end
end

local function heap_pop(h)
  local c, i = h.c, h.i
  local n = #c
  local top_c, top_i = c[1], i[1]
  c[1], i[1] = c[n], i[n]
  c[n], i[n] = nil, nil
  n = n - 1
  local k = 1
  while true do
    local l, r, m = k * 2, k * 2 + 1, k
    if l <= n and c[l] < c[m] then m = l end
    if r <= n and c[r] < c[m] then m = r end
    if m == k then break end
    c[k], c[m] = c[m], c[k]
    i[k], i[m] = i[m], i[k]
    k = m
  end
  return top_c, top_i
end

-- Günstigster Weg von start zu einem Feld mit goal(id) = true. cost(id) = nil: gesperrt.
-- Gibt die Liste der Felder (Index 0-basiert: cy * w + cx) zurück oder nil.
local function astar(w, h, start, goal, cost, tx, ty)
  local dist, from, closed = {[start] = 0}, {}, {}
  local open = {c = {}, i = {}}
  heap_push(open, 0, start)
  local DX, DY = {1, -1, 0, 0}, {0, 0, 1, -1}
  while #open.c > 0 do
    local _, id = heap_pop(open)
    if not closed[id] then
      closed[id] = true
      if goal(id) then
        local path = {}
        while id do
          table.insert(path, 1, id)
          id = from[id]
        end
        return path
      end
      local cx, cy = id % w, id // w
      for d = 1, 4 do
        local nx, ny = cx + DX[d], cy + DY[d]
        if nx >= 0 and ny >= 0 and nx < w and ny < h then
          local nid = ny * w + nx
          local c = not closed[nid] and cost(nid)
          if c then
            local nd = dist[id] + c
            if not dist[nid] or nd < dist[nid] then
              dist[nid], from[nid] = nd, id
              local hx = tx and (abs(nx - tx) + abs(ny - ty)) or 0
              heap_push(open, nd + hx, nid)
            end
          end
        end
      end
    end
  end
  return nil
end

-- area: Eintrag aus K.welt.gebiete (nr, w, h), seed: Zahl. Ein Dorf gibt es nur im Heimattal (nr 1).
function Gen.generate(area, seed)
  local dorf = area.nr == 1
  local prof = Gen.PROFILES[area.nr]
  local W, H = area.w, area.h
  local R = Rng.new(seed)
  local N = W * H
  local g, obj, coll = {}, {}, {}   -- Boden-Byte, Objektart (sparse), Kollision (sparse)
  local reserved = {}               -- Grundstück und Dorf: keine Wiesen-Objekte, kein Wald
  local function idx(cx, cy) return cy * W + cx end

  -- 1. Wald aus Rauschen, dichter zum Rand hin
  local wald, rand = prof and prof.wald or 0.64, prof and prof.rand or 5
  for cy = 0, H - 1 do
    for cx = 0, W - 1 do
      local d = min(min(cx, cy), min(W - 1 - cx, H - 1 - cy))
      local n = 0.65 * Rng.noise(cx, cy, 11, seed) + 0.35 * Rng.noise(cx, cy, 5, seed + 1)
      if d < rand then n = n + (rand - d) * 0.07 end
      g[idx(cx, cy)] = (d < 2 or n > wald) and FOREST or GRASS
      if prof then
        -- Seen mit Inseln (Flussauen): eigenes Rauschen, die Mitte eines Sees wird wieder Land
        if prof.seen then
          local s = Rng.noise(cx, cy, 14, seed + 51)
          if s > prof.seen and d >= 3 then g[idx(cx, cy)] = s > prof.inseln and GRASS or WATER end
        end
        -- Insel (Nebelinsel): Meer statt Waldrand, die Küste ist unregelmäßig
        if prof.insel and d < 3 + Rng.noise(cx, cy, 6, seed + 61) * 5 then g[idx(cx, cy)] = WATER end
      end
    end
  end

  -- 2. Hof-Grundstück in der Mitte (auf dem 10er-Raster der Landstücke), Dorf daneben
  local plot = {x = (W // 2 - 10) // 10 * 10, y = (H // 2 - 10) // 10 * 10, w = 20, h = 20}
  local river_west = R:next() < 0.5
  local vw, vh = #VILLAGE[1], #VILLAGE
  local vx = river_west and plot.x + plot.w + 8 or plot.x - 8 - vw
  vx = mid(3, vx, W - vw - 3)
  local vy = mid(3, plot.y + plot.h // 2 - 5 + R:int(-3, 3), H - vh - 3)
  local function clear(x0, y0, x1, y1, mark)
    for cy = max(0, y0), min(H - 1, y1) do
      for cx = max(0, x0), min(W - 1, x1) do
        g[idx(cx, cy)] = GRASS
        if mark and cx >= x0 + mark and cx <= x1 - mark and cy >= y0 + mark and cy <= y1 - mark then
          reserved[idx(cx, cy)] = true
        end
      end
    end
  end
  clear(plot.x - 3, plot.y - 3, plot.x + plot.w + 2, plot.y + plot.h + 2, 3)
  if dorf then clear(vx - 2, vy - 2, vx + vw + 1, vy + vh + 1, 1) end

  -- 3. Fluss von oben nach unten auf der anderen Seite des Hofs (Gebiete: Trockenbett, mehrere Flüsse, Schluchten)
  local function river(west, ground, wlo, whi, salt)
    local rx
    if west then rx = R:int(12, plot.x - 14) else rx = R:int(plot.x + plot.w + 13, W - 14) end
    local rlo = west and 4 or plot.x + plot.w + 6
    local rhi = west and plot.x - 8 or W - 7
    local drift = 0
    for cy = 0, H - 1 do
      local nz = Rng.noise(0, cy, 9, seed + salt)
      local width = prof and wlo + flr(nz * (whi - wlo + 0.999)) or (nz > 0.5 and 3 or 2)
      for k = 0, width - 1 do g[idx(flr(rx) + k, cy)] = ground end
      drift = mid(-0.8, drift + (R:next() - 0.5) * 0.5, 0.8)
      rx = mid(rlo, rx + drift, rhi)
    end
  end
  -- Schlucht quer (Canyon): oberhalb oder unterhalb des Ankunftsplatzes von links nach rechts
  local function chasm_across(top)
    local ry = top and R:int(8, plot.y - 12) or R:int(plot.y + plot.h + 10, H - 10)
    local lo, hi = top and 5 or plot.y + plot.h + 7, top and plot.y - 9 or H - 6
    local drift = 0
    for cx = 0, W - 1 do
      local width = 2 + flr(Rng.noise(cx, 0, 8, seed + 71) * 3.999)
      for k = 0, width - 1 do g[idx(cx, flr(ry) + k)] = CHASM end
      drift = mid(-0.7, drift + (R:next() - 0.5) * 0.45, 0.7)
      ry = mid(lo, ry + drift, hi)
    end
  end
  if not prof then
    river(river_west, WATER, 2, 3, 5)
  else
    if prof.fluss then
      local ground = prof.fluss == "sand" and SAND or WATER
      river(river_west, ground, prof.breite[1], prof.breite[2], 5)
      if (prof.fluesse or 1) > 1 then river(not river_west, ground, prof.breite[1], prof.breite[2], 15) end
    end
    if prof.schluchten then
      river(river_west, CHASM, 2, 5, 25)
      chasm_across(R:next() < 0.5)
      if prof.schluchten > 2 then river(not river_west, CHASM, 2, 4, 35) end
    end
  end

  -- 4. Dorf nach Vorlage
  local places = {}
  for ty = 0, dorf and vh - 1 or -1 do
    local row = VILLAGE[ty + 1]
    for tx = 0, vw - 1 do
      local ch = row:sub(tx + 1, tx + 1)
      local i = idx(vx + tx, vy + ty)
      if ch == ":" then g[i] = PATH
      elseif ch == "s" then g[i] = SAND
      elseif ch == "J" then g[i] = SAND; obj[i] = "jump"
      elseif VILLAGE_LEGEND[ch] then obj[i] = VILLAGE_LEGEND[ch]
      end
      if ch ~= "." then reserved[i] = true end
    end
  end
  if dorf then for name, p in pairs(VILLAGE_PLACES) do places[name] = {vx + p[1], vy + p[2]} end end
  local street_y = vy + 5

  -- Kollision der Objekte eintragen (Grundfläche)
  local function stamp(i)
    local P = Tiles.PROPS[obj[i]]
    if P.coll then
      local cx, cy = i % W, i // W
      for dy = 0, (P.h or 1) - 1 do
        for dx = 0, (P.w or 1) - 1 do coll[idx(cx + dx, cy + dy)] = P.coll end
      end
    end
  end
  for i in pairs(obj) do stamp(i) end

  -- 5. Wege (A*): Hof → Dorf, Hof → Rand oben, unten und über den Fluss
  local in_plot = function(cx, cy)
    return cx >= plot.x and cx < plot.x + plot.w and cy >= plot.y and cy < plot.y + plot.h
  end
  local function cost(i)
    local cx, cy = i % W, i // W
    if coll[i] or in_plot(cx, cy) then return nil end
    local b = g[i]
    if b == PATH or b == BRIDGE or b == BRIDGE_V then return 1 end
    if b == SAND and (reserved[i] or not prof) then return nil end
    local c = 2 + U.hash(cx, cy, seed + 9) * 3
    if b == FOREST then c = c + 4 end
    if b == WATER or b == CHASM then c = c + 10 end
    if reserved[i] then c = c + 6 end
    return c
  end
  local function carve(path)
    for n, i in ipairs(path) do
      local b = g[i]
      if b == WATER and prof and prof.furten then
        g[i] = FORD                -- Flussauen: durch die Furt statt über eine Brücke
      elseif b == WATER or b == CHASM or b == BRIDGE or b == BRIDGE_V then
        local a, z = path[n - 1], path[n + 1]
        local horiz = (a and abs(a - i) == 1) or (z and abs(z - i) == 1)
        g[i] = horiz and BRIDGE or BRIDGE_V
      elseif b ~= SAND and b ~= FORD then
        g[i] = PATH
      end
    end
  end
  local gate_side = river_west and 1 or -1   -- Dorf liegt auf dieser Seite (1 = rechts)
  local mid_y = plot.y + plot.h // 2
  local gate = {gate_side > 0 and plot.x + plot.w or plot.x - 1, mid_y}
  places.hoftor = gate
  local street_end = gate_side > 0 and vx or vx + vw - 1
  local function route(sx, sy, goal, tx, ty)
    local p = astar(W, H, idx(sx, sy), goal, cost, tx, ty)
    if p then carve(p) end
    return p
  end
  local function at(tx, ty) local t = idx(tx, ty) return function(i) return i == t end, tx, ty end
  if dorf then route(gate[1], gate[2], at(street_end, street_y)) end
  local nx = plot.x + plot.w // 2 + R:int(-4, 4)
  route(nx, plot.y - 1, function(i) return i // W == 0 end, nx, 0)
  local sx = plot.x + plot.w // 2 + R:int(-4, 4)
  route(sx, plot.y + plot.h, function(i) return i // W == H - 1 end, sx, H - 1)
  local wx = gate_side > 0 and plot.x - 1 or plot.x + plot.w
  local edge_x = gate_side > 0 and 0 or W - 1
  local river_path = route(wx, mid_y + R:int(-6, 6), function(i) return i % W == edge_x end, edge_x, mid_y)
  for _, i in ipairs(river_path or {}) do
    if g[i] == BRIDGE or g[i] == BRIDGE_V or g[i] == FORD then places.bruecke = {i % W, i // W} break end
  end
  places.start = {plot.x + plot.w // 2, plot.y + plot.h // 2}

  -- 6. Erreichbarkeit: jede begehbare Fläche muss vom Hof aus erreichbar sein
  local function walkable(i)
    local b = g[i]
    return b ~= FOREST and b ~= WATER and b ~= CHASM and not coll[i]
  end
  local function flood(from)
    local seen, stack, count = {[from] = true}, {from}, 1
    while #stack > 0 do
      local i = table.remove(stack)
      local cx, cy = i % W, i // W
      for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        local nx2, ny2 = cx + d[1], cy + d[2]
        if nx2 >= 0 and ny2 >= 0 and nx2 < W and ny2 < H then
          local j = idx(nx2, ny2)
          if not seen[j] and walkable(j) then
            seen[j] = true
            count = count + 1
            stack[#stack + 1] = j
          end
        end
      end
    end
    return seen, count
  end
  local home = idx(places.start[1], places.start[2])
  for _ = 1, prof and 70 or 40 do
    local seen = flood(home)
    local lost
    for i = 0, N - 1 do
      if walkable(i) and not seen[i] then lost = i break end
    end
    if not lost then break end
    local comp, size = flood(lost)
    if size < 30 then
      for i in pairs(comp) do g[i] = FOREST end
    else
      local p = astar(W, H, lost, function(i) return seen[i] end, function(i)
        local cx, cy = i % W, i // W
        if coll[i] or in_plot(cx, cy) then return nil end
        return g[i] == FOREST and 3 or (g[i] == WATER or g[i] == CHASM) and 6 or 1
      end)
      if p then carve(p) else for i in pairs(comp) do g[i] = FOREST end end
    end
  end

  -- 7. Bäume am Waldrand, Wiesen-Objekte, Deko
  local function code(cx, cy)
    if cx < 0 or cy < 0 or cx >= W or cy >= H then return FOREST end
    return g[idx(cx, cy)]
  end
  for cy = 0, H - 1 do
    for cx = 0, W - 1 do
      local i = idx(cx, cy)
      if g[i] == FOREST then
        local open = false
        for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
          local b = code(cx + d[1], cy + d[2])
          if b ~= FOREST and b ~= WATER and b ~= CHASM then open = true end
        end
        if open and U.hash(cx, cy, seed + 21) < 0.85 then obj[i] = "edge_tree" end
      end
    end
  end
  local deco = {}
  local MIX = Tiles.DECO_MIX
  for cy = 1, H - 2 do
    for cx = 1, W - 2 do
      local i = idx(cx, cy)
      if g[i] == GRASS and not obj[i] and not coll[i] then
        local free = not reserved[i]
        for dy = -1, 1 do
          for dx = -1, 1 do
            local j = idx(cx + dx, cy + dy)
            if g[j] ~= GRASS or obj[j] or coll[j] then free = false end
          end
        end
        local r = U.hash(cx, cy, seed + 31)
        if free and prof and r < prof.objekte[1] then
          for _, o in ipairs(prof.objekte[2]) do
            if r < o[2] then obj[i] = o[1] break end
          end
          stamp(i)
        elseif free and not prof and r < 0.035 then
          obj[i] = r < 0.012 and "tree" or r < 0.025 and "bush" or "rock"
          stamp(i)
        elseif U.hash(cx, cy, seed + 37) < 0.2 then
          local k = 1 + flr(U.hash(cx, cy, seed + 41) * #MIX)
          deco[i] = byte(MIX, k)
        end
      end
    end
  end

  -- 8. Zäune: Form je nach Nachbarn
  local fb = Tiles.FENCE_BASE
  for i, kind in pairs(obj) do
    if kind == "fence" then
      local cx, cy = i % W, i // W
      local function f(x, y) return x >= 0 and y >= 0 and x < W and y < H and obj[idx(x, y)] == "fence" end
      local m = (f(cx - 1, cy) and 1 or 0) + (f(cx + 1, cy) and 2 or 0) + (f(cx, cy - 1) and 4 or 0) +
        (f(cx, cy + 1) and 8 or 0)
      coll[i] = char(fb + m)
    end
  end

  -- 9. In Zeilen-Strings und Objektliste umwandeln
  local ground, drows, crows, objects = {}, {}, {}, {}
  local buf_g, buf_d, buf_c = {}, {}, {}
  for cy = 0, H - 1 do
    for cx = 0, W - 1 do
      local i = idx(cx, cy)
      buf_g[cx + 1] = g[i]
      buf_d[cx + 1] = deco[i] or DOT
      local c = coll[i]
      buf_c[cx + 1] = c and byte(c) or DOT
    end
    ground[cy + 1] = char(table.unpack(buf_g))
    drows[cy + 1] = char(table.unpack(buf_d))
    crows[cy + 1] = char(table.unpack(buf_c))
  end
  local ids = {}
  for i in pairs(obj) do ids[#ids + 1] = i end
  table.sort(ids)
  for _, i in ipairs(ids) do objects[#objects + 1] = {obj[i], i % W, i // W} end

  return {
    w = W, h = H, seed = seed, ground = ground, deco = drows, coll = crows, objects = objects,
    grounds = Tiles.GROUNDS, decos = Tiles.DECOS, shapes = Tiles.SHAPES, heights = Tiles.HEIGHTS, props = Tiles.PROPS,
    plot = plot, places = places, village = dorf and {x = vx, y = vy, w = vw, h = vh} or nil,
  }
end

return Gen
