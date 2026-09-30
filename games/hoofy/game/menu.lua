-- Kleine Auswahlmenüs (E7): Steuerkreuz wählen, A bestätigen, B zurück.
local Stage = require("game.stage")

local Menu = {}
Menu.__index = Menu

-- items: Liste {label, id, dim = true (ausgegraut, nicht wählbar)}. title optional.
function Menu.new(items, title)
  local self = setmetatable({items = items, title = title, sel = 1}, Menu)
  self:skip(1)
  return self
end

function Menu:skip(dir)
  for _ = 1, #self.items do
    if not self.items[self.sel].dim then return end
    self.sel = (self.sel - 1 + dir) % #self.items + 1
  end
end

-- Liefert die id des gewählten Eintrags, "close" bei B, sonst nil.
function Menu:update()
  if btnp(BTN_UP) then self.sel = (self.sel - 2) % #self.items + 1; self:skip(-1) end
  if btnp(BTN_DOWN) then self.sel = self.sel % #self.items + 1; self:skip(1) end
  if btnp(BTN_B) then return "close" end
  if btnp(BTN_A) then return self.items[self.sel].id end
end

-- Zeichnet das Menü mit der oberen linken Ecke bei x, y (Bildschirmkoordinaten).
function Menu:draw(x, y)
  local C = Stage.COLORS
  local w = 0
  for _, it in ipairs(self.items) do w = max(w, textw(it.label)) end
  if self.title then w = max(w, textw(self.title)) end
  w = w + 22
  local h = #self.items * 11 + 8 + (self.title and 11 or 0)
  x = mid(2, x, SCREEN_W - w - 2)
  y = mid(16, y, SCREEN_H - h - 2)
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
