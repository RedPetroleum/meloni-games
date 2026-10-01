-- Selbsttests für das Freischalten im Spielverlauf (Rückmeldung 0.5.2, E65).
local F = require("game.fortschritt")
local Buyers = require("game.buyers")
local Orders = require("game.orders")
local Reformen = require("game.reformen")
local Stage = require("game.stage")
local Screens = require("game.screens")
local C = require("game.tests.check")

local function pause_ids(day)
  local ctx = Stage.build(1)
  ctx.clock = {day = day}
  local ids = {}
  for _, it in ipairs(Screens.pause(ctx, {}).items or {}) do ids[it.id] = true end
  return ids, ctx
end

return {
  {"Käufer ab Tag 5, Sammlerin ab Tag 9", function()
    for day = 1, F.AB.kaeufer - 1 do C.eq(Buyers.visit(5, day), nil, "Tag " .. day) end
    for day = F.AB.kaeufer, F.AB.sammlerin - 1 do
      for seed = 1, 30 do C.ok(Buyers.visit(seed, day).typ ~= "sammlerin", "Sammlerin zu früh") end
    end
    local seen = false
    for seed = 1, 60 do if Buyers.visit(seed, F.AB.sammlerin).typ == "sammlerin" then seen = true end end
    C.ok(seen, "Sammlerin kommt ab ihrem Tag")
  end},
  {"Bestellungen ab Tag 4, Zeitung ab Tag 10, Hunde nicht vor Tag 16", function()
    local ctx = Stage.build(1)
    for day = 1, F.AB.bestellungen - 1 do C.eq(Orders.tick(ctx, day).neu, nil) end
    local ctx2 = Stage.build(1)
    for day = 2, 60 do
      Reformen.tick(ctx2, day)
      if ctx2.reform_neu then C.ok(day >= F.AB.zeitung, "Zeitung zu früh") end
      for _, a in ipairs(Reformen.state(ctx2).aktiv) do
        if a.id == "hunde_frei" then C.ok(a.von >= F.AB.hunde, "Hunde zu früh: Tag " .. a.von) end
      end
    end
  end},
  {"Pausenmenü zeigt Kunden, Zeitung, Tauschen erst ab ihrem Tag; Meldung am Morgen", function()
    local ids = pause_ids(1)
    C.ok(ids.horses and ids.map and not ids.orders and not ids.news and not ids.swap, "Tag 1")
    ids = pause_ids(20)
    C.ok(ids.orders and ids.news and ids.swap, "Tag 20")
    C.eq(#F.neu(2), 0)
    C.eq(#F.neu(F.AB.zeitung), 1)
  end},
}
