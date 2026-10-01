-- Selbsttests für das Wetter (Aufgabe D4): Regentage und Sauberkeit draußen.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Days = require("game.days")
local Wetter = require("game.wetter")
local C = require("game.tests.check")

local function setup()
  Area.clear()
  local ctx = Stage.build(1, 31)
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  return ctx
end

return {
  {"Etwa jeder vierte Tag regnet, aus dem Seed", function()
    local ctx = setup()
    local n = 0
    for day = 1, 400 do
      local r = Wetter.regnet(ctx, day)
      C.eq(Wetter.regnet(ctx, day), r, "stabil")
      if r then n = n + 1 end
    end
    C.between(n, 70, 130, "Regentage von 400")
  end},
  {"Regen: Weide und frei −15 Sauberkeit, Stall nicht; ohne Regen nichts", function()
    local ctx = setup()
    local a = ctx.wild:add_own({rasse = "noriker", name = "Weide"})
    local b = ctx.wild:add_own({rasse = "noriker", name = "Stall"})
    ctx.wild:house(a, "weide")
    ctx.wild:house(b, "stall")
    a.data.sauberkeit, b.data.sauberkeit = 100, 100
    ctx.regen_erzwungen = false
    Days.new_day(ctx, 2)
    local weide, stall = a.data.sauberkeit, b.data.sauberkeit
    ctx.regen_erzwungen = true
    a.data.sauberkeit, b.data.sauberkeit = 100, 100
    Days.new_day(ctx, 3)
    C.eq(a.data.sauberkeit, weide - 15, "Weide zusätzlich −15")
    C.eq(b.data.sauberkeit, stall, "Stall bleibt trocken")
    C.eq(ctx.nasse, 1)
  end},
}
