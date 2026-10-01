-- Selbsttests für Land kaufen (Aufgabe C7, geändert nach Rückmeldung 0.5.3): einzelne 10×10-Felder neben dem Hof,
-- Preise, Kartenrand, Bauen auf neuem Land, Weiden und Spielstände mit altem Rechteck.
local Stage = require("game.stage")
local Area = require("game.area")
local Farm = require("game.farm")
local C = require("game.tests.check")

local function setup(money)
  Area.clear()
  local ctx = Stage.build(1, 11)
  ctx.money = money or 100000
  return ctx
end

return {
  {"Start 20×20 = 4 Felder; Feld daneben 500, jedes weitere +250; Rechteck wächst mit", function()
    local ctx = setup()
    local farm = ctx.area.farm
    local p = farm.plot
    local x0, y0 = p.x, p.y
    C.eq(p.w, 20)
    C.eq(#Farm.parcels(farm), 4)
    C.ok(Farm.owns(farm, x0, y0) and Farm.owns(farm, x0 + 19, y0 + 19) and not Farm.owns(farm, x0 + 20, y0))
    local ok, price = Farm.buy_land(ctx, x0 + 25, y0 + 3)
    C.ok(ok, tostring(price))
    C.eq(price, 500)
    C.eq(ctx.money, 100000 - 500)
    C.eq(p.w, 30)
    C.eq(p.h, 20)
    C.eq(p.x, x0)
    C.ok(Farm.owns(farm, x0 + 29, y0 + 9) and not Farm.owns(farm, x0 + 29, y0 + 10), "nur das eine Feld")
    local _, price2 = Farm.buy_land(ctx, x0 + 3, y0 - 1)
    C.eq(price2, 750)
    C.eq(p.y, y0 - 10)
    C.eq(p.h, 30)
    C.eq(farm.land, 2)
    C.ok(ctx.area.plot == p, "Karte und Hof teilen das Grundstück")
  end},
  {"Nur angrenzende, freie Felder; zu wenig Geld ändert nichts; Kartenrand", function()
    local ctx = setup(100)
    local farm = ctx.area.farm
    local p = farm.plot
    local x0, y0 = p.x, p.y
    local v, W = ctx.area.village, ctx.map.w
    local east = v.x < x0                -- vom Dorf weg
    local ok, why = Farm.buy_land(ctx, east and x0 + 25 or x0 - 5, y0)
    C.ok(not ok and why == "Geld", tostring(why))
    C.eq(ctx.money, 100)
    ctx.money = 1000000
    C.ok(not Farm.land_angebot(ctx, x0 + 3, y0 + 3), "schon deins")
    local _, why2 = Farm.land_angebot(ctx, x0 - 5, y0 - 5)
    C.eq(why2, "grenzt nicht an deinen Hof", "diagonal zählt nicht")
    -- vom Dorf weg bis an den Kartenrand
    local n, cx = 0, east and x0 + 25 or x0 - 5
    while Farm.buy_land(ctx, cx, y0) do n, cx = n + 1, cx + (east and 10 or -10) end
    if east then C.ok(n > 0 and p.x + p.w <= W and p.x + p.w > W - 10, "bis an den Rand: " .. p.x + p.w)
    else C.ok(n > 0 and p.x >= 0 and p.x < 10, "bis an den Rand: " .. p.x) end
    local ok3, why3 = Farm.buy_land(ctx, cx, y0)
    C.ok(not ok3 and why3 == "Kartenrand", tostring(why3))
    local _, why4 = Farm.land_angebot(ctx, east and x0 - 5 or x0 + 25, y0)
    C.ok(why4 == nil or why4 == "gehört zum Dorf", "zum Dorf hin: " .. tostring(why4))
  end},
  {"Auf neuem Land lässt sich bauen, außerhalb und über die Lücke nicht; Start bleibt im Hof", function()
    local ctx = setup()
    local farm = ctx.area.farm
    local p = farm.plot
    local x0, y0 = p.x, p.y
    local sx, sy = ctx.area.places.start[1], ctx.area.places.start[2]
    C.ok(not Farm.can_place(ctx.map, farm, "bank", x0 + 22, y0 + 3), "vor dem Kauf nicht")
    Farm.buy_land(ctx, x0 + 22, y0 + 3)
    local ok2, why = Farm.place(ctx, "bank", x0 + 27, y0 + 3)
    C.ok(ok2, tostring(why))
    C.ok(not Farm.can_place(ctx.map, farm, "bank", x0 + 27, y0 + 13), "Ecke im Rechteck, aber nicht gekauft")
    C.ok(not Farm.can_place(ctx.map, farm, "stall_s", x0 + 24, y0 + 8), "ragt ins fremde Feld")
    C.eq(farm.home[1], sx)
    C.eq(farm.home[2], sy)
    C.eq(Farm.capacity(farm).frei, 10, "5 Felder = 500 Kacheln / 50")
  end},
  {"Alter Spielstand ohne Felder: Felder aus dem Rechteck", function()
    local farm = Farm.default({x = 40, y = 30, w = 30, h = 20})
    C.eq(#Farm.parcels(farm), 6)
    C.ok(Farm.owns(farm, 69, 49) and not Farm.owns(farm, 70, 49) and not Farm.owns(farm, 39, 30))
  end},
}
