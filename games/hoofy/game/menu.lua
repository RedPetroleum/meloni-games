-- Kleine Auswahlmenüs (E7): Steuerkreuz wählen, A bestätigen, B zurück.
-- Haben alle Einträge ein Bild (icon), wird das Menü ein Kachelraster: Steuerkreuz in alle vier Richtungen,
-- unter jedem Bild ein Kurzname (short), darunter der volle Name des gewählten Eintrags. Sonst eine Liste.
local Stage = require("game.stage")
local SFX = require("game.sfx")
local S = require("sprites")

local Menu = {}
Menu.__index = Menu

Menu.TILE_W, Menu.TILE_H, Menu.GAP = 58, 50, 3
Menu.ICON = 24                  -- Bildfläche in der Kachel

-- items: Liste {label, id, dim = true (ausgegraut, nicht wählbar), icon = Sprite, short = Kurzname, badge = Text}.
-- title optional. opts.cols: Spalten im Raster (Standard: bis 5). opts.names = false: im Raster nur Bilder,
-- der Name steht dann nur unten für den gewählten Eintrag.
function Menu.new(items, title, opts)
  local self = setmetatable({items = items, title = title, sel = 1, names = not (opts and opts.names == false)}, Menu)
  local grid = #items > 0
  for _, it in ipairs(items) do if not it.icon then grid = false end end
  self.grid = grid
  if grid then
    local n = #items
    self.cols = (opts and opts.cols) or (n <= 5 and n or (n <= 8 and 4 or 5))
    self.rows = (n + self.cols - 1) // self.cols
  end
  self:skip(1)
  return self
end

function Menu:skip(dir)
  for _ = 1, #self.items do
    if not self.items[self.sel].dim then return end
    self.sel = (self.sel - 1 + dir) % #self.items + 1
  end
end

-- Raster: Bewegung in vier Richtungen, ausgegraute Kacheln lassen sich anwählen, aber nicht bestätigen.
local function grid_move(self)
  local n, cols = #self.items, self.cols
  local i = self.sel - 1
  local c, r = i % cols, i // cols
  local dir
  if btnp(BTN_LEFT) then c, dir = (c - 1) % cols, "h" end
  if btnp(BTN_RIGHT) then c, dir = (c + 1) % cols, "right" end
  if btnp(BTN_UP) then r, dir = (r - 1) % self.rows, "v" end
  if btnp(BTN_DOWN) then r, dir = (r + 1) % self.rows, "v" end
  if not dir then return end
  local j = r * cols + c
  if j >= n then                        -- die letzte Reihe ist kürzer
    if dir == "right" then j = r * cols           -- rechts hinaus: an den Anfang der Reihe
    else j = n - 1 end                             -- sonst: letzte Kachel
  end
  self.sel = j + 1
  SFX.select()
end

-- Liefert die id des gewählten Eintrags, "close" bei B, sonst nil.
function Menu:update()
  if self.grid then
    grid_move(self)
  else
    if btnp(BTN_UP) then self.sel = (self.sel - 2) % #self.items + 1; self:skip(-1); SFX.select() end
    if btnp(BTN_DOWN) then self.sel = self.sel % #self.items + 1; self:skip(1); SFX.select() end
  end
  if btnp(BTN_B) then SFX.back() return "close" end
  if btnp(BTN_A) then
    local it = self.items[self.sel]
    if it.dim then SFX.snort() return nil end
    SFX.ok()
    return it.id
  end
end

-- Zeichnet ein Sprite eingepasst in ein Feld box × box mit Mitte (cx, cy): kleine ganzzahlig vergrößert,
-- große verkleinert.
function Menu.icon(name, cx, cy, box)
  local r = S.rects[name]
  if not r then return end
  local w, h = r[3], r[4]
  local f = box / max(w, h)
  if f >= 1 then f = flr(f) end
  local dw, dh = flr(w * f), flr(h * f)
  sspr(S.img, r[1], r[2], w, h, cx - dw // 2, cy - dh // 2, dw, dh)
end

-- Graut ein Rechteck ab (x0, y0, x1, y1 inklusive).
function Menu.grey(x0, y0, x1, y1)
  clip(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
  shade(Stage.COLORS.panel, 0.6)
  clip()
end

-- Größe des Menüs in Pixeln.
function Menu:size()
  if self.grid then
    local w = self.cols * (Menu.TILE_W + Menu.GAP) - Menu.GAP + 12
    local h = self.rows * (Menu.TILE_H + Menu.GAP) - Menu.GAP + 12 + 13 + (self.title and 13 or 0)
    return w, h
  end
  local w = 0
  for _, it in ipairs(self.items) do w = max(w, textw(it.label)) end
  if self.title then w = max(w, textw(self.title)) end
  return w + 22, #self.items * 11 + 8 + (self.title and 11 or 0)
end

local function draw_grid(self, x, y)
  local C = Stage.COLORS
  local w, h = self:size()
  Stage.panel(x, y, x + w - 1, y + h - 1)
  local ty = y + 6
  if self.title then
    print(self.title, x + 8, ty, C.gold)
    ty = ty + 13
  end
  local TW, TH, G = Menu.TILE_W, Menu.TILE_H, Menu.GAP
  for i, it in ipairs(self.items) do
    local c, r = (i - 1) % self.cols, (i - 1) // self.cols
    local tx, ty2 = x + 6 + c * (TW + G), ty + r * (TH + G)
    local sel = i == self.sel
    rectfill(tx, ty2, tx + TW - 1, ty2 + TH - 1, sel and C.gold or C.panel_light)
    rectfill(tx + 2, ty2 + 2, tx + TW - 3, ty2 + TH - 3, sel and rgb(0x6b, 0x4a, 0x2e) or rgb(0x3a, 0x2a, 0x24))
    if self.names then
      Menu.icon(it.icon, tx + TW // 2, ty2 + 18, Menu.ICON)
      local short = it.short or it.label
      print(short, tx + (TW - textw(short)) // 2, ty2 + TH - 12, sel and C.gold or C.text)
    else
      Menu.icon(it.icon, tx + TW // 2, ty2 + TH // 2, Menu.ICON + 8)
    end
    if it.badge then
      local bw = textw(it.badge)
      rectfill(tx + TW - bw - 5, ty2 + 3, tx + TW - 4, ty2 + 12, C.panel)
      print(it.badge, tx + TW - bw - 4, ty2 + 4, C.text)
    end
    if it.dim then Menu.grey(tx, ty2, tx + TW - 1, ty2 + TH - 1) end
  end
  local cur = self.items[self.sel]
  if cur then
    local label = cur.label
    print(label, x + (w - textw(label)) // 2, y + h - 12, cur.dim and C.dim or C.gold)
  end
end

-- Zeichnet das Menü mit der oberen linken Ecke bei x, y (Bildschirmkoordinaten). Raster ohne x/y: unten mittig.
function Menu:draw(x, y)
  local C = Stage.COLORS
  local w, h = self:size()
  if self.grid then
    x = x or (SCREEN_W - w) // 2
    y = y or (SCREEN_H - h - 6)
    x = mid(2, x, SCREEN_W - w - 2)
    y = mid(16, y, SCREEN_H - h - 2)
    return draw_grid(self, x, y)
  end
  x = mid(2, x or 100, SCREEN_W - w - 2)
  y = mid(16, y or 50, SCREEN_H - h - 2)
  Stage.panel(x, y, x + w - 1, y + h - 1)
  local ty = y + 5
  if self.title then
    print(self.title, x + 8, ty, C.gold)
    ty = ty + 11
  end
  for i, it in ipairs(self.items) do
    local col = it.dim and C.dim or C.text
    if i == self.sel then
      print(">", x + 5, ty, C.gold)
      col = C.gold
    end
    print(it.label, x + 14, ty, col)
    ty = ty + 11
  end
end

return Menu
