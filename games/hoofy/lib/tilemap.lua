-- Kachelkarte aus Textzeilen: ein Zeichen pro Feld, die Legende sagt, was es bedeutet.
-- Kennt keine Spielregeln, nur Boden, Kanten, Deko, feste Requisiten, Kollision und Markierungen.
--
--   local map = Tilemap.new{
--     rows = {"T..~~", ...},          -- alle Zeilen gleich lang
--     legend = {['~'] = {ground = 'water'}, T = {ground = 'grass', prop = 'tree'},
--               ['1'] = {ground = 'grass', spawn = 'horse', id = 1}},
--     grounds = {grass = {base = true, deco = {...}}, water = {sprites = {...}, solid = true, edges = 'bank'}},
--     props = {tree = {sprite = 'tree', solid = {12, 12, 20, 16}}},
--     sprites = S,                     -- aus require('sprites')
--   }
--
-- Ein Feld ist TILE Pixel groß. Weltkoordinaten sind Pixel, (0, 0) ist oben links.
local U = require("lib.util")

local Map = {}
Map.__index = Map
Map.TILE = 16
local TILE = 16
local DIRS = {n = {0, -1}, s = {0, 1}, w = {-1, 0}, e = {1, 0}}

-- Zeichenbefehl für ein Sprite an einer Weltposition: {sx, sy, sw, sh, x, y, flip}
local function part(S, name, x, y, flip)
  local r = S.rects[name]
  if not r then error("unknown sprite " .. tostring(name), 3) end
  return {r[1], r[2], r[3], r[4], x, y, flip}
end
Map.part = part

function Map.new(def)
  local self = setmetatable({}, Map)
  local S = def.sprites
  self.S, self.img = S, S.img
  self.w, self.h = #def.rows[1], #def.rows
  self.pw, self.ph = self.w * TILE, self.h * TILE
  self.ground, self.tags, self.layer, self.anim, self.solids = {}, {}, {}, {}, {}
  self.props, self.spawns = {}, {}
  self.grounds, self.legend, self.rows = def.grounds, def.legend, def.rows
  local seed = def.seed or 1

  -- 1. Legende auflösen
  for cy = 0, self.h - 1 do
    local row = def.rows[cy + 1]
    if #row ~= self.w then error("map row " .. (cy + 1) .. " has " .. #row .. " fields, expected " .. self.w) end
    for cx = 0, self.w - 1 do
      local ch = row:sub(cx + 1, cx + 1)
      local L = def.legend[ch]
      if not L then error("map row " .. (cy + 1) .. ": no legend entry for '" .. ch .. "'") end
      local i = cy * self.w + cx + 1
      local g = def.grounds[L.ground]
      if not g then error("unknown ground " .. tostring(L.ground)) end
      self.ground[i] = g
      self.tags[i] = L.tag or g.tag
      if L.spawn then
        self.spawns[#self.spawns + 1] = {kind = L.spawn, id = L.id, x = cx * TILE + TILE / 2, y = cy * TILE + TILE - 2}
      end
    end
  end

  -- 2. Boden, Kanten und Deko vorberechnen (pro Feld eine Liste von Zeichenbefehlen)
  for cy = 0, self.h - 1 do
    for cx = 0, self.w - 1 do
      local i = cy * self.w + cx + 1
      local g = self.ground[i]
      local x, y = cx * TILE, cy * TILE
      local list = {}
      if g.solid then self:add_solid(x, y, x + TILE, y + TILE) end
      if g.sprites then
        local k = 1 + flr(U.hash(cx, cy, seed) * #g.sprites)
        list[#list + 1] = part(S, g.sprites[k], x, y)
      end
      if g.frames then
        local p = part(S, g.frames[1], x, y)
        local r2 = S.rects[g.frames[2]]
        p.alt = {r2[1], r2[2]}
        p.base = {p[1], p[2]}
        self.anim[#self.anim + 1] = p
        list[#list + 1] = p
      end
      if g.edges then
        for side, d in pairs(DIRS) do
          local n = self:ground_at_cell(cx + d[1], cy + d[2])
          if n and n ~= g and n.base then
            local name = g.edges .. "_" .. side
            local sw, sh = S.size(name)
            local ex = side == "e" and x + TILE - sw or x
            local ey = side == "s" and y + TILE - sh or y
            list[#list + 1] = part(S, name, ex, ey)
          end
        end
      end
      if g.deco and U.hash(cx, cy, seed + 7) < (g.deco_chance or 0.2) then
        local k = 1 + flr(U.hash(cx, cy, seed + 13) * #g.deco)
        local name = g.deco[k]
        local sw, sh = S.size(name)
        local dx = flr(U.hash(cx, cy, seed + 17) * (TILE - sw))
        local dy = flr(U.hash(cx, cy, seed + 19) * (TILE - sh))
        list[#list + 1] = part(S, name, x + dx, y + dy)
      end
      local L = def.legend[def.rows[cy + 1]:sub(cx + 1, cx + 1)]
      if L.deco then
        for _, name in ipairs(L.deco) do
          local sw, sh = S.size(name)
          list[#list + 1] = part(S, name, x + flr(U.hash(cx, cy, seed + 23) * (TILE - sw)),
            y + flr(U.hash(cx, cy, seed + 29) * (TILE - sh)))
        end
      end
      if #list > 0 then self.layer[i] = list end
    end
  end

  -- 3. Requisiten (stehen in der Welt, werden mit den Figuren nach Tiefe sortiert)
  for cy = 0, self.h - 1 do
    for cx = 0, self.w - 1 do
      local L = def.legend[def.rows[cy + 1]:sub(cx + 1, cx + 1)]
      if L.prop then
        local P = def.props[L.prop]
        if not P then error("unknown prop " .. tostring(L.prop)) end
        self:place_prop(P, cx, cy, L.prop)
      end
    end
  end
  return self
end

-- Requisite P mit linker oberer Ecke ihrer Grundfläche in Feld cx, cy.
-- P.w, P.h: Grundfläche in Feldern (Standard 1x1); das Sprite steht unten mittig darauf.
-- P.solid: {x0, y0, x1, y1} in Pixeln relativ zur Grundfläche. P.build(map, cx, cy): eigene Teile.
function Map:place_prop(P, cx, cy, kind)
  local x, y = cx * TILE, cy * TILE
  local fw, fh = (P.w or 1) * TILE, (P.h or 1) * TILE
  local parts
  if P.build then
    parts = P.build(self, cx, cy)
  else
    local sw, sh = self.S.size(P.sprite)
    parts = {part(self.S, P.sprite, x + (fw - sw) // 2 + (P.dx or 0), y + fh - sh + (P.dy or 0))}
  end
  local solids = P.solids or (P.solid and {P.solid})
  if P.solids_for then solids = P.solids_for(self, cx, cy) end
  for _, s in ipairs(solids or {}) do
    self:add_solid(x + s[1], y + s[2], x + s[3], y + s[4])
  end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(parts) do
    x0, y0 = min(x0, p[5]), min(y0, p[6])
    x1, y1 = max(x1, p[5] + p[3]), max(y1, p[6] + p[4])
  end
  self.props[#self.props + 1] = {
    kind = kind, cx = cx, cy = cy, parts = parts,
    x = x + fw / 2, y = y + fh - 1 + (P.sort_dy or 0),   -- Tiefe: Unterkante der Grundfläche
    x0 = x0, y0 = y0, x1 = x1, y1 = y1,
  }
end

function Map:add_solid(x0, y0, x1, y1)
  local r = {x0, y0, x1, y1}
  for cy = y0 // TILE, (y1 - 1) // TILE do
    for cx = x0 // TILE, (x1 - 1) // TILE do
      if cx >= 0 and cy >= 0 and cx < self.w and cy < self.h then
        local i = cy * self.w + cx + 1
        local list = self.solids[i]
        if not list then list = {}; self.solids[i] = list end
        list[#list + 1] = r
      end
    end
  end
end

-- Legendeneintrag eines Feldes (nil außerhalb der Karte).
function Map:legend_at(cx, cy)
  if cx < 0 or cy < 0 or cx >= self.w or cy >= self.h then return nil end
  return self.legend[self.rows[cy + 1]:sub(cx + 1, cx + 1)]
end

function Map:ground_at_cell(cx, cy)
  if cx < 0 or cy < 0 or cx >= self.w or cy >= self.h then return nil end
  return self.ground[cy * self.w + cx + 1]
end

function Map:ground_at(x, y)
  return self:ground_at_cell(flr(x / TILE), flr(y / TILE))
end

function Map:tag_at(x, y)
  local cx, cy = flr(x / TILE), flr(y / TILE)
  if cx < 0 or cy < 0 or cx >= self.w or cy >= self.h then return nil end
  return self.tags[cy * self.w + cx + 1]
end

-- Ist ein Rechteck (x1, y1 exklusiv) irgendwo blockiert? Außerhalb der Karte ist immer blockiert.
function Map:blocked(x0, y0, x1, y1)
  if x0 < 0 or y0 < 0 or x1 > self.pw or y1 > self.ph then return true end
  local w, solids = self.w, self.solids
  for cy = y0 // TILE, (y1 - 1) // TILE do
    for cx = x0 // TILE, (x1 - 1) // TILE do
      local list = solids[cy * w + cx + 1]
      if list then
        for k = 1, #list do
          local r = list[k]
          if x0 < r[3] and x1 > r[1] and y0 < r[4] and y1 > r[2] then return true end
        end
      end
    end
  end
  return false
end

-- Zeichnet den Boden im sichtbaren Ausschnitt; vorher camera(cx, cy) setzen.
-- Die Grundfarbe (Gras) füllt der Aufrufer mit cls(), gezeichnet wird nur, was davon abweicht.
function Map:draw(cam_x, cam_y, view_w, view_h)
  local img, w, layer = self.img, self.w, self.layer
  local x0, y0 = max(0, cam_x // TILE), max(0, cam_y // TILE)
  local x1 = min(w - 1, (cam_x + view_w - 1) // TILE)
  local y1 = min(self.h - 1, (cam_y + view_h - 1) // TILE)
  for cy = y0, y1 do
    local base = cy * w + 1
    for cx = x0, x1 do
      local list = layer[base + cx]
      if list then
        for k = 1, #list do
          local p = list[k]
          sspr(img, p[1], p[2], p[3], p[4], p[5], p[6])
        end
      end
    end
  end
end

-- Schaltet animierte Böden (Wasser) auf Bild 1 oder 2.
function Map:set_anim_frame(n)
  for _, p in ipairs(self.anim) do
    local src = n == 2 and p.alt or p.base
    p[1], p[2] = src[1], src[2]
  end
end

return Map
