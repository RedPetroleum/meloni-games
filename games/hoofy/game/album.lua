-- Sammelalbum (Aufgabe E5): jede Kombination Rasse × sichtbare Farbe, die man besitzt oder besessen hat, wird
-- eingetragen (Rückmeldung 0.5.3: nicht schon beim Sehen, erst ab dem Zähmen).
local K = require("game.katalog")

local A = {}

-- ctx.album: Menge "rasse:farbe" → true (wird gespeichert).
function A.state(ctx)
  if not ctx.album then ctx.album = {} end
  return ctx.album
end

-- Trägt das Pferd ein. Gibt true zurück, wenn die Kombination neu war.
function A.eintragen(ctx, d)
  local st = A.state(ctx)
  local key = d.rasse .. ":" .. d.farbe
  if st[key] then return false end
  st[key] = true
  return true
end

-- Farben einer Rasse in Seltenheitsreihenfolge (Matrix des Katalogs), ohne Doppelte.
function A.farben(rasse)
  local out, seen = {}, {}
  for _, tier in ipairs(K.farben.matrix[rasse]) do
    for _, f in ipairs(tier) do
      if not seen[f] then seen[f] = true out[#out + 1] = f end
    end
  end
  return out
end

function A.gefunden(ctx, rasse, farbe) return A.state(ctx)[rasse .. ":" .. farbe] == true end

-- Zahl der eingetragenen und der möglichen Kombinationen, optional für eine Rasse.
function A.zaehler(ctx, rasse)
  local n, total = 0, 0
  for _, r in ipairs(K.rassen.liste) do
    if not rasse or r.id == rasse then
      for _, f in ipairs(A.farben(r.id)) do
        total = total + 1
        if A.gefunden(ctx, r.id, f) then n = n + 1 end
      end
    end
  end
  return n, total
end

-- Alle eigenen Pferde eintragen (gezähmt, gekauft, gezüchtet). Gibt die Zahl der neuen Einträge zurück.
function A.sichten(ctx)
  local new = 0
  for _, d in ipairs(ctx.herd) do if A.eintragen(ctx, d) then new = new + 1 end end
  return new
end

return A
