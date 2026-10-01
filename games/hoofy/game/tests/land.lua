-- Selbsttests für Land kaufen (Aufgabe C7): Streifen, Preise, Kartenrand, Bauen auf neuem Land.
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
  {"Start 20×20; ein Streifen = 2 Stücke, Preis 500 + 750, jedes weitere +250", function()
    local ctx = setup()
    local p = ctx.area.farm.plot
    local x0, y0 = p.x, p.y
    C.eq(p.w, 20)
    local ok, price = Farm.buy_land(ctx, "land_o")
    C.ok(ok)
    C.eq(price, 500 + 750)
    C.eq(ctx.money, 100000 - 1250)
    C.eq(p.w, 30)
    C.eq(p.x, x0)
    local _, price2 = Farm.buy_land(ctx, "land_n")
    C.eq(price2, 3 * 0 + (500 + 250 * 2) + (500 + 250 * 3) + (500 + 250 * 4), "Nord: jetzt 3 Stücke breit")
    C.eq(p.y, y0 - 10)
    C.eq(p.h, 30)
    C.eq(ctx.area.farm.land, 5)
    C.ok(ctx.area.plot == p, "Karte und Hof teilen das Grundstück")
  end},
  {"Zu wenig Geld ändert nichts; am Kartenrand geht es nicht weiter", function()
    local ctx = setup(100)
    local p = ctx.area.farm.plot
    local ok, why = Farm.buy_land(ctx, "land_w")
    C.ok(not ok and why == "Geld")
    C.eq(ctx.money, 100)
    C.eq(p.w, 20)
    ctx.money = 1000000
    local n = 0
    while Farm.buy_land(ctx, "land_w") do n = n + 1 end
    C.ok(n > 0 and p.x >= 0 and p.x < 10, "bis an den Rand: " .. p.x)
    local ok2, why2 = Farm.buy_land(ctx, "land_w")
    C.ok(not ok2 and why2 == "Kartenrand")
  end},
  {"Auf neuem Land lässt sich bauen, außerhalb nicht; Start bleibt im Hof", function()
    local ctx = setup()
    local p = ctx.area.farm.plot
    local sx, sy = ctx.area.places.start[1], ctx.area.places.start[2]
    local bx, by = p.x + p.w + 2, p.y + 3
    local ok = Farm.can_place(ctx.map, ctx.area.farm, "bank", bx, by)
    C.ok(not ok, "vor dem Kauf nicht")
    Farm.buy_land(ctx, "land_o")
    local ok2, why = Farm.place(ctx, "bank", p.x + p.w - 3, p.y + 3)
    C.ok(ok2, tostring(why))
    C.eq(ctx.area.farm.home[1], sx)
    C.eq(ctx.area.farm.home[2], sy)
  end},
}
