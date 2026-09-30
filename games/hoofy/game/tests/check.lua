-- Prüfungen für Selbsttests: werfen mit einer lesbaren Meldung, wenn etwas nicht stimmt.
local C = {}

function C.ok(cond, msg)
  if not cond then error(msg or "Bedingung falsch", 2) end
end

function C.eq(got, want, msg)
  if got ~= want then
    error((msg and msg .. ": " or "") .. "erwartet " .. tostring(want) .. ", bekommen " .. tostring(got), 2)
  end
end

-- |got − want| <= tol
function C.near(got, want, tol, msg)
  if abs(got - want) > tol then
    error((msg and msg .. ": " or "") .. "erwartet " .. tostring(want) .. " ± " .. tostring(tol) ..
      ", bekommen " .. tostring(got), 2)
  end
end

-- lo <= got <= hi
function C.between(got, lo, hi, msg)
  if got < lo or got > hi then
    error((msg and msg .. ": " or "") .. "erwartet " .. tostring(lo) .. " bis " .. tostring(hi) ..
      ", bekommen " .. tostring(got), 2)
  end
end

return C
