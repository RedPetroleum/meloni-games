-- Selbsttests für lib/util.lua.
local U = require("lib.util")
local C = require("game.tests.check")

return {
  {"hash ist fest und liegt in [0, 1)", function()
    for i = 1, 200 do
      local h = U.hash(i, i * 7, 3)
      C.between(h, 0, 0.9999)
      C.eq(U.hash(i, i * 7, 3), h, "gleiche Eingabe")
    end
    C.ok(U.hash(1, 2, 3) ~= U.hash(1, 2, 4), "anderer Seed, anderer Wert")
  end},
  {"facing", function()
    C.eq(U.facing(1, 0, "down"), "right")
    C.eq(U.facing(0, -2, "down"), "up")
    C.eq(U.facing(0, 0, "left"), "left")
  end},
  {"clock", function()
    C.eq(U.clock(60 * 75), "1:15")
  end},
}
