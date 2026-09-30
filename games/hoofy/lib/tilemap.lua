-- Kachelkarte für große Gebiete: ein Byte pro Kachel und Ebene, keine Tabelle pro Kachel.
-- Kennt keine Spielregeln, nur Boden, Kanten, Deko, Kollision und Objekte.
--
--   local map = Tilemap.new{
--     w = 96, h = 80,
--     ground = {"....~~..", ...},    -- h Zeilen mit w Zeichen: Bodenart je Kachel
--     deco = {"..a...b.", ...},      -- optional: Deko-Zeichen je Kachel ("." = keine)
--     coll = {"....T...", ...},      -- optional: Kollisionsform je Kachel ("." = frei), siehe shapes
--     grounds = {["."] = {base = true}, ["~"] = {frames = {...}, edges = "bank", solid = true}, ...},
--     decos = {a = "deco_tuft", ...},
--     shapes = {T = {{4, 9, 12, 16}}, ...},  -- Rechtecke in Pixeln relativ zur Kachel
--     objects = {{kind, cx, cy}, ...},       -- Bäume, Häuser …, werden in Blöcke einsortiert
--     props = {tree = {sprite = "tree"}, ...},
--     sprites = S,                            -- aus require('sprites')
--   }
--
-- Objekte liegen in Blöcken zu BLOCK x BLOCK Kacheln und bekommen ihre Zeichenteile erst, wenn ihr
-- Block sichtbar wird; höchstens CACHE Blöcke behalten ihre Teile (das spart Speicher bei großen
-- Karten). Weltkoordinaten sind Pixel, (0, 0) ist oben links.
local Map = {}
Map.__index = Map
Map.TILE = 16
Map.BLOCK = 16
local TILE, BLOCK = 16, 16
local CACHE = 12
local BLOCK_PX = TILE * BLOCK
local byte, sub = string.byte, string.sub
local DOT = 46   -- "."

-- Zeichenbefehl für ein Sprite an einer Weltposition: {sx, sy, sw, sh, x, y, flip}
local function part(S, name, x, y, flip)
  local r = S.rects[name]
  if not r then error("unknown sprite " .. tostring(name), 3) end
  return {r[1], r[2], r[3], r[4], x, y, flip}
end
Map.part = part

local function by_byte(t)
  local out = {}
  for k, v in pairs(t) do out[byte(k)] = v end
  return out
end

function Map.new(def)
  local self = setmetatable({}, Map)
  local S = def.sprites
  self.S, self.img = S, S.img
  self.w, self.h = def.w, def.h
  self.pw, self.ph = self.w * TILE, self.h * TILE
  self.ground, self.deco, self.coll = def.ground, def.deco, def.coll
  self.G = by_byte(def.grounds)
  self.D = by_byte(def.decos or {})
  self.shapes = by_byte(def.shapes or {})
  self.heights = by_byte(def.heights or {})
  self.props = def.props or {}
  self.seed = def.seed or 1
  self.anim = 1
  self.changes = {}
  for cy = 1, self.h do
    if #self.ground[cy] ~= self.w then error("ground row " .. cy .. " has " .. #self.ground[cy] .. " tiles") end
    for cx = 1, self.w do
      if not self.G[byte(self.ground[cy], cx)] then
        error("unknown ground '" .. sub(self.ground[cy], cx, cx) .. "' in row " .. cy)
      end
    end
  end
  -- Objekte in Blöcke
  self.bw = (self.w + BLOCK - 1) // BLOCK
  self.bh = (self.h + BLOCK - 1) // BLOCK
  self.blocks, self.built, self.used, self.nbuilt, self.stamp = {}, {}, {}, 0, 0
  for _, o in ipairs(def.objects or {}) do self:add_object(o[1], o[2], o[3]) end
  return self
end

function Map:add_object(kind, cx, cy)
  if not self.props[kind] then error("unknown prop " .. tostring(kind)) end
  local k = (cy // BLOCK) * self.bw + cx // BLOCK + 1
  local list = self.blocks[k]
  if not list then list = {}; self.blocks[k] = list end
  list[#list + 1] = {kind, cx, cy}
  self:drop_block(k)
end

function Map:drop_block(k)
  if self.built[k] then
    self.built[k] = nil
    self.nbuilt = self.nbuilt - 1
  end
end

-- Bodenart (Tabelle aus grounds) einer Kachel, nil außerhalb.
function Map:ground_at_cell(cx, cy)
  if cx < 0 or cy < 0 or cx >= self.w or cy >= self.h then return nil end
  return self.G[byte(self.ground[cy + 1], cx + 1)]
end

function Map:ground_at(x, y)
  return self:ground_at_cell(x // TILE, y // TILE)
end

-- Zeichen der Bodenart einer Kachel ("" außerhalb).
function Map:code(cx, cy)
  if cx < 0 or cy < 0 or cx >= self.w or cy >= self.h then return "" end
  return sub(self.ground[cy + 1], cx + 1, cx + 1)
end

-- Ist die Kachel begehbar (Boden nicht fest, keine Kollisionsform)?
function Map:walkable(cx, cy)
  if cx < 0 or cy < 0 or cx >= self.w or cy >= self.h then return false end
  if self.G[byte(self.ground[cy + 1], cx + 1)].solid then return false end
  return not self.coll or byte(self.coll[cy + 1], cx + 1) == DOT
end

local function set_char(rows, cx, cy, ch)
  local row = rows[cy + 1]
  rows[cy + 1] = sub(row, 1, cx) .. ch .. sub(row, cx + 2)
end

-- Ändert eine Ebene ("ground", "deco", "coll") und merkt sich die Änderung gegenüber dem Seed
-- (nolog: nicht merken, z. B. wenn der Hof die Änderung selbst speichert).
function Map:set(layer, cx, cy, ch, nolog)
  set_char(self[layer], cx, cy, ch)
  if not nolog then self.changes[#self.changes + 1] = {layer, cx, cy, ch} end
end

-- Entfernt ein Objekt (Art und Kachel müssen stimmen). Gibt zurück, ob es eins gab.
function Map:remove_object(kind, cx, cy)
  local k = (cy // BLOCK) * self.bw + cx // BLOCK + 1
  local list = self.blocks[k]
  if not list then return false end
  for i, o in ipairs(list) do
    if o[1] == kind and o[2] == cx and o[3] == cy then
      table.remove(list, i)
      self:drop_block(k)
      return true
    end
  end
  return false
end

-- Zeichenteile des Blocks mit der Kachel neu bauen lassen (z. B. nach Zaun-Änderungen).
function Map:refresh_block_at(cx, cy)
  self:drop_block((cy // BLOCK) * self.bw + cx // BLOCK + 1)
end

-- Ist ein Rechteck (x1, y1 exklusiv) irgendwo blockiert? Außerhalb der Karte ist immer blockiert.
-- clear: Sprunghöhe; Formen mit heights[Zeichen] <= clear werden übersprungen.
function Map:blocked(x0, y0, x1, y1, clear)
  if x0 < 0 or y0 < 0 or x1 > self.pw or y1 > self.ph then return true end
  local G, ground, coll, shapes, heights = self.G, self.ground, self.coll, self.shapes, self.heights
  for cy = y0 // TILE, (y1 - 1) // TILE do
    local grow, crow = ground[cy + 1], coll and coll[cy + 1]
    for cx = x0 // TILE, (x1 - 1) // TILE do
      if G[byte(grow, cx + 1)].solid then return true end
      if crow then
        local c = byte(crow, cx + 1)
        if c ~= DOT and not (clear and heights[c] and heights[c] <= clear) then
          local tx, ty = cx * TILE, cy * TILE
          local list = shapes[c]
          for k = 1, #list do
            local r = list[k]
            if x0 < tx + r[3] and x1 > tx + r[1] and y0 < ty + r[4] and y1 > ty + r[2] then return true end
          end
        end
      end
    end
  end
  return false
end

-- Zeichnet Boden, Kanten und Deko im sichtbaren Ausschnitt; vorher camera(cx, cy) setzen.
-- Die Grundfarbe (Gras) füllt der Aufrufer mit cls(), gezeichnet wird nur, was davon abweicht.
function Map:draw(cam_x, cam_y, view_w, view_h)
  local img, S, G, D = self.img, self.S.rects, self.G, self.D
  local ground, deco, w, h = self.ground, self.deco, self.w, self.h
  local anim, seed = self.anim, self.seed
  local x0, y0 = max(0, cam_x // TILE), max(0, cam_y // TILE)
  local x1 = min(w - 1, (cam_x + view_w - 1) // TILE)
  local y1 = min(h - 1, (cam_y + view_h - 1) // TILE)
  for cy = y0, y1 do
    local row, up, down = ground[cy + 1], ground[cy] or ground[cy + 1], ground[cy + 2] or ground[cy + 1]
    local drow = deco and deco[cy + 1]
    local y = cy * TILE
    for cx = x0, x1 do
      local b = byte(row, cx + 1)
      local g = G[b]
      local x = cx * TILE
      if not g.base then
        local list = g.rects
        if g.frames then list = g.frame_rects[anim] end
        local r = list[1 + (cx * 7 + cy * 13) % #list]
        sspr(img, r[1], r[2], 16, 16, x, y)
        local e = g.edge_rects
        if e then
          local n
          n = byte(up, cx + 1)
          if n ~= b and cy > 0 and G[n].base then r = e.n; sspr(img, r[1], r[2], r[3], r[4], x, y) end
          n = byte(down, cx + 1)
          if n ~= b and cy < h - 1 and G[n].base then r = e.s; sspr(img, r[1], r[2], r[3], r[4], x, y + TILE - r[4]) end
          if cx > 0 then
            n = byte(row, cx)
            if n ~= b and G[n].base then r = e.w; sspr(img, r[1], r[2], r[3], r[4], x, y) end
          end
          if cx < w - 1 then
            n = byte(row, cx + 2)
            if n ~= b and G[n].base then r = e.e; sspr(img, r[1], r[2], r[3], r[4], x + TILE - r[3], y) end
          end
        end
      end
      if drow then
        local d = byte(drow, cx + 1)
        if d ~= DOT then
          local r = S[D[d]]
          local hsh = (cx * 374761393 + cy * 668265263 + seed) & 0xffff
          sspr(img, r[1], r[2], r[3], r[4], x + hsh % (TILE - r[3]), y + (hsh >> 8) % (TILE - r[4]))
        end
      end
    end
  end
end

-- Schaltet animierte Böden (Wasser) auf Bild 1 oder 2.
function Map:set_anim_frame(n)
  self.anim = n
end

-- Nach dem Laden der Sprites: Zeichenrechtecke der Bodenarten vorberechnen.
function Map:prepare()
  local R = self.S.rects
  local function rects(names)
    local out = {}
    for i, n in ipairs(names) do
      out[i] = R[n] or error("unknown sprite " .. n)
    end
    return out
  end
  for _, g in pairs(self.G) do
    if g.sprites then g.rects = rects(g.sprites) end
    if g.frames then
      g.frame_rects = {rects(g.frames[1]), rects(g.frames[2])}
      g.rects = g.frame_rects[1]
    end
    if g.edges then
      g.edge_rects = {}
      for _, side in ipairs({"n", "s", "w", "e"}) do g.edge_rects[side] = R[g.edges .. "_" .. side] end
    end
  end
  return self
end

-- Baut die Zeichenteile der Objekte eines Blocks (einmal, beim ersten Anzeigen).
-- Requisite P: P.w, P.h Grundfläche in Kacheln (Standard 1x1), das Sprite steht unten mittig darauf,
-- P.dx/P.dy verschieben es; P.build(map, cx, cy) liefert eigene Teile; P.sort_dy verschiebt die Tiefe.
function Map:block_props(k)
  self.used[k] = self.stamp
  local built = self.built[k]
  if built then return built end
  if self.nbuilt >= CACHE then
    -- am längsten nicht gebrauchten Block vergessen
    local old, oldest = nil, math.huge
    for bk in pairs(self.built) do
      if self.used[bk] < oldest then old, oldest = bk, self.used[bk] end
    end
    self:drop_block(old)
  end
  built = {}
  local S = self.S
  for i, o in ipairs(self.blocks[k] or {}) do
    local P = self.props[o[1]]
    local cx, cy = o[2], o[3]
    local x, y = cx * TILE, cy * TILE
    local fw, fh = (P.w or 1) * TILE, (P.h or 1) * TILE
    local sx, sy = x + fw / 2, y + fh - 1 + (P.sort_dy or 0)   -- Tiefe: Unterkante der Grundfläche
    if P.build then
      -- mehrteilig: {parts = {Teil, …}, x, y, x0, y0, x1, y1}
      local parts = P.build(self, cx, cy)
      local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
      for _, p in ipairs(parts) do
        x0, y0 = min(x0, p[5]), min(y0, p[6])
        x1, y1 = max(x1, p[5] + p[3]), max(y1, p[6] + p[4])
      end
      built[i] = {parts = parts, x = sx, y = sy, x0 = x0, y0 = y0, x1 = x1, y1 = y1}
    else
      -- ein Sprite: das Objekt ist selbst der Zeichenbefehl {sx, sy, sw, sh, x, y, flip, x = , y = }
      local sprite = P.sprite
      if P.variants then
        sprite = P.variants[1 + (cx * 5 + cy * 3) % #P.variants]
      end
      local sw, sh = S.size(sprite)
      local jx = P.jitter and ((cx * 13 + cy * 7) % (P.jitter * 2 + 1) - P.jitter) or 0
      local p = part(S, sprite, x + (fw - sw) // 2 + (P.dx or 0) + jx, y + fh - sh + (P.dy or 0),
        P.flip and (cx + cy) % 2 == 0)
      p.x, p.y = sx, sy
      built[i] = p
    end
  end
  self.built[k] = built
  self.nbuilt = self.nbuilt + 1
  return built
end

-- Hängt alle Objekte an out an, deren Bild das Rechteck berührt. Gibt die neue Anzahl zurück.
-- margin: so weit dürfen Bilder über ihren Block hinausragen (Pixel).
function Map:props_in(x0, y0, x1, y1, out, n, margin)
  margin = margin or 64
  self.stamp = self.stamp + 1
  local bx0, by0 = max(0, (x0 - margin) // BLOCK_PX), max(0, (y0 - margin) // BLOCK_PX)
  local bx1 = min(self.bw - 1, (x1 + margin) // BLOCK_PX)
  local by1 = min(self.bh - 1, (y1 + margin) // BLOCK_PX)
  for by = by0, by1 do
    for bx = bx0, bx1 do
      local k = by * self.bw + bx + 1
      if self.blocks[k] then
        local list = self:block_props(k)
        for i = 1, #list do
          local p = list[i]
          local px0, py0, px1, py1
          if p.parts then
            px0, py0, px1, py1 = p.x0, p.y0, p.x1, p.y1
          else
            px0, py0 = p[5], p[6]
            px1, py1 = px0 + p[3], py0 + p[4]
          end
          if px1 > x0 and px0 < x1 and py1 > y0 and py0 < y1 then
            n = n + 1
            out[n] = p
          end
        end
      end
    end
  end
  return n
end

return Map
