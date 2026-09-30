-- Bewegung mit Fußkasten: Figuren stoßen nur mit den Füßen an (3/4-Ansicht), der Kopf darf
-- vor einer Wand oder hinter einem Baum stehen.
local Body = {}

-- Fußkasten von e (e.x, e.y = Mitte der Unterkante, e.fw x e.fh Pixel).
local function box(x, y, fw, fh)
  local x0 = flr(x - fw / 2)
  local y0 = flr(y - fh)
  return x0, y0, x0 + fw, y0 + fh
end

function Body.free(map, x, y, fw, fh)
  local x0, y0, x1, y1 = box(x, y, fw, fh)
  return not map:blocked(x0, y0, x1, y1)
end

-- Bewegt e um dx, dy, getrennt nach Achsen (so rutscht man an Wänden entlang).
-- allow(x, y): optional, darf die Figur dort stehen (z. B. nur auf der Koppel)?
-- Gibt zurück, ob die Bewegung in x bzw. y geklappt hat.
function Body.move(e, dx, dy, map, allow)
  local ok_x, ok_y = true, true
  if dx ~= 0 then
    local nx = e.x + dx
    if Body.free(map, nx, e.y, e.fw, e.fh) and (not allow or allow(nx, e.y)) then
      e.x = nx
    else
      ok_x = false
    end
  end
  if dy ~= 0 then
    local ny = e.y + dy
    if Body.free(map, e.x, ny, e.fw, e.fh) and (not allow or allow(e.x, ny)) then
      e.y = ny
    else
      ok_y = false
    end
  end
  return ok_x, ok_y
end

return Body
