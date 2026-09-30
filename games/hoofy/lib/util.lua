-- Kleine Helfer, die jedes Spiel brauchen kann.
local U = {}

function U.dist(ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  return math.sqrt(dx * dx + dy * dy)
end

-- Fester Zufall aus Koordinaten (0 <= r < 1): gleiche Stelle, gleiches Ergebnis, ohne rnd() zu stören.
function U.hash(x, y, seed)
  local h = (x * 374761393 + y * 668265263 + (seed or 0) * 982451653) & 0x7fffffff
  h = ((h ~ (h >> 13)) * 1274126177) & 0x7fffffff
  return (h ~ (h >> 16)) % 10000 / 10000
end

-- Blickrichtung aus einer Bewegung; bei gleich starken Achsen bleibt die alte.
function U.facing(dx, dy, old)
  local ax, ay = abs(dx), abs(dy)
  if ax == 0 and ay == 0 then return old end
  if ax > ay then return dx > 0 and "right" or "left" end
  if ay > ax then return dy > 0 and "down" or "up" end
  return old
end

-- Sekunden als m:ss.
function U.clock(frames)
  local s = ceil(frames / 60)
  return string.format("%d:%02d", s // 60, s % 60)
end

-- Bricht text in Zeilen um, die höchstens width Pixel breit sind (Umbruch an Leerzeichen).
function U.wrap(text, width, scale)
  local lines, line = {}, nil
  for word in text:gmatch("%S+") do
    local try = line and (line .. " " .. word) or word
    if line and textw(try, scale) > width then
      lines[#lines + 1] = line
      line = word
    else
      line = try
    end
  end
  if line then lines[#lines + 1] = line end
  return lines
end

return U
