-- Kamera mit Totzone: Sie bewegt sich erst, wenn das Ziel den mittleren Bereich verlässt.
-- Das spart Bildübertragung auf der Konsole (unbewegter Hintergrund = nur geänderte Zeilen).
local Camera = {}
Camera.__index = Camera

-- opts: view_w, view_h (sichtbarer Bereich), top (so viele Pixel oben verdeckt, z. B. Anzeige),
-- dz_w, dz_h (Größe der Totzone)
function Camera.new(map_w, map_h, opts)
  opts = opts or {}
  return setmetatable({
    x = 0, y = 0,
    map_w = map_w, map_h = map_h,
    view_w = opts.view_w or SCREEN_W, view_h = opts.view_h or SCREEN_H,
    top = opts.top or 0,
    dz_w = opts.dz_w or 80, dz_h = opts.dz_h or 56,
  }, Camera)
end

function Camera:clamp()
  self.x = mid(0, self.x, max(0, self.map_w - self.view_w))
  self.y = mid(-self.top, self.y, max(-self.top, self.map_h - self.view_h))
  self.x, self.y = flr(self.x), flr(self.y)
end

-- Sofort auf das Ziel zentrieren.
function Camera:snap(tx, ty)
  self.x = tx - self.view_w // 2
  self.y = ty - (self.view_h + self.top) // 2
  self:clamp()
end

-- Dem Ziel folgen, sobald es die Totzone verlässt.
function Camera:follow(tx, ty)
  local cx = self.x + self.view_w // 2
  local cy = self.y + (self.view_h + self.top) // 2
  local hw, hh = self.dz_w // 2, self.dz_h // 2
  if tx < cx - hw then self.x = self.x + (tx - (cx - hw)) end
  if tx > cx + hw then self.x = self.x + (tx - (cx + hw)) end
  if ty < cy - hh then self.y = self.y + (ty - (cy - hh)) end
  if ty > cy + hh then self.y = self.y + (ty - (cy + hh)) end
  self:clamp()
end

function Camera:apply()
  camera(self.x, self.y)
end

return Camera
