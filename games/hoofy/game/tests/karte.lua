-- Selbsttests für den Kartengenerator (Aufgabe A1).
local S = require("sprites")
local Map = require("lib.tilemap")
local Gen = require("game.mapgen")
local K = require("game.katalog")
local C = require("game.tests.check")

local HEIMAT = K.welt.gebiete[1]

local function build(seed)
  local def = Gen.generate(HEIMAT, seed)
  def.sprites = S
  return Map.new(def):prepare(), def
end

-- Anzahl begehbarer Kacheln und wie viele davon vom Start aus erreichbar sind.
local function reach(map, sx, sy)
  local w = map.w
  local seen, stack, n = {[sy * w + sx] = true}, {sy * w + sx}, 1
  while #stack > 0 do
    local i = table.remove(stack)
    local cx, cy = i % w, i // w
    for d = 1, 4 do
      local nx, ny = cx + ({1, -1, 0, 0})[d], cy + ({0, 0, 1, -1})[d]
      local j = ny * w + nx
      if not seen[j] and map:walkable(nx, ny) then
        seen[j] = true
        n = n + 1
        stack[#stack + 1] = j
      end
    end
  end
  local total = 0
  for cy = 0, map.h - 1 do
    for cx = 0, map.w - 1 do
      if map:walkable(cx, cy) then total = total + 1 end
    end
  end
  return n, total, seen
end

return {
  {"gleicher Seed = gleiche Karte, anderer Seed = andere", function()
    local _, a = build(7)
    local _, b = build(7)
    local _, c = build(8)
    local same, diff = true, false
    for y = 1, a.h do
      if a.ground[y] ~= b.ground[y] or a.deco[y] ~= b.deco[y] or a.coll[y] ~= b.coll[y] then same = false end
      if a.ground[y] ~= c.ground[y] then diff = true end
    end
    C.ok(same, "Seed 7 zweimal verschieden")
    C.eq(#a.objects, #b.objects, "Objekte")
    C.ok(diff, "Seed 7 und 8 gleich")
  end},
  {"Größe aus dem Katalog, Wald, Fluss und Brücken vorhanden", function()
    local map = build(1)
    C.eq(map.w, 96)
    C.eq(map.h, 80)
    local count = {}
    for y = 1, map.h do
      for ch in map.ground[y]:gmatch(".") do count[ch] = (count[ch] or 0) + 1 end
    end
    local n = map.w * map.h
    C.between((count.F or 0) / n, 0.15, 0.6, "Waldanteil")
    C.ok((count["~"] or 0) > 80, "Fluss")
    C.ok((count["="] or 0) + (count.I or 0) > 0, "Brücke")
    C.ok((count[":"] or 0) > 60, "Wege")
  end},
  {"jede begehbare Kachel ist vom Hof aus erreichbar (5 Seeds)", function()
    for seed = 1, 5 do
      local map, def = build(seed)
      local st = def.places.start
      local n, total, seen = reach(map, st[1], st[2])
      C.eq(n, total, "Seed " .. seed .. " erreichbar")
      for name, p in pairs(def.places) do
        C.ok(seen[p[2] * map.w + p[1]], "Seed " .. seed .. " Ort " .. name .. " nicht erreichbar")
      end
    end
  end},
  {"Hof-Grundstück frei (Gras), Dorf komplett", function()
    local map, def = build(1)
    local p = def.plot
    for cy = p.y, p.y + p.h - 1 do
      for cx = p.x, p.x + p.w - 1 do
        C.eq(map:code(cx, cy), ".", "Grundstück " .. cx .. "," .. cy)
        C.ok(map:walkable(cx, cy), "Grundstück begehbar")
      end
    end
    local kinds = {}
    for _, o in ipairs(def.objects) do kinds[o[1]] = true end
    for _, k in ipairs({"shop", "cottage", "stand", "board", "jump", "fence"}) do C.ok(kinds[k], "Dorf: " .. k) end
  end},
  {"Speicher", function()
    collectgarbage()
    local before = collectgarbage("count")
    local map = build(3)
    for k = 1, map.bw * map.bh do map.stamp = k; map:block_props(k) end
    collectgarbage()
    local after = collectgarbage("count")
    C.ok(map.nbuilt <= 12, "höchstens 12 Blöcke mit Zeichenteilen")
    log(string.format("KARTE Speicher: Karte nach Durchlauf aller Blöcke %.0f KB, Lua gesamt %.0f KB", after - before, after))
    C.ok(after < 2048, "Lua-Speicher unter 2 MB")
    map = nil
  end},
}
