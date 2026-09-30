-- Erkundung für die Karte (E6): das Gebiet ist in Zellen zu CELL x CELL Kacheln geteilt, eine
-- Zelle gilt als erkundet, sobald ein Stück davon auf dem Bildschirm zu sehen war. Gespeichert
-- wird ein String je Zelleneihe ("1" erkundet, "0" nicht).
local Explore = {}

Explore.CELL = 4

function Explore.new(map_w, map_h)
  local cw, ch = (map_w + Explore.CELL - 1) // Explore.CELL, (map_h + Explore.CELL - 1) // Explore.CELL
  local rows = {}
  for y = 1, ch do rows[y] = string.rep("0", cw) end
  return rows
end

-- Markiert alle Zellen, die das Pixelrechteck x0, y0, x1, y1 berühren. Gibt zurück, ob sich etwas änderte.
function Explore.reveal(rows, x0, y0, x1, y1)
  local size = Explore.CELL * 16
  local cw, ch = #rows[1], #rows
  local changed = false
  for cy = max(0, y0 // size), min(ch - 1, y1 // size) do
    local row = rows[cy + 1]
    for cx = max(0, x0 // size), min(cw - 1, x1 // size) do
      if row:sub(cx + 1, cx + 1) == "0" then
        row = row:sub(1, cx) .. "1" .. row:sub(cx + 2)
        changed = true
      end
    end
    rows[cy + 1] = row
  end
  return changed
end

function Explore.is_explored(rows, cx, cy)
  local row = rows[cy + 1]
  return row ~= nil and row:sub(cx + 1, cx + 1) == "1"
end

-- Anteil erkundeter Zellen (0–1).
function Explore.share(rows)
  local n, total = 0, 0
  for _, row in ipairs(rows) do
    for i = 1, #row do
      total = total + 1
      if row:sub(i, i) == "1" then n = n + 1 end
    end
  end
  return n / total
end

return Explore
