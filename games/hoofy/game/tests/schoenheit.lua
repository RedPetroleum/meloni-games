-- Selbsttests für die Hof-Schönheit (Aufgabe C4): Summe der Deko-Punkte, Bindungsbonus ab 50 / 150 / 400.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local Days = require("game.days")
local K = require("game.katalog")
local C = require("game.tests.check")

local function setup()
  Area.clear()
  local ctx = Stage.build(1, 9)
  ctx.money = 1e7
  local p = ctx.area.plot
  ctx.player.x, ctx.player.y = (p.x + 10) * 16 + 8, (p.y + 8) * 16 + 8
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  return ctx, p
end

local function put(ctx, id, x, y)
  local ok, why = Farm.place(ctx, id, x, y)
  if not ok then error(id .. " bei " .. x .. "," .. y .. ": " .. tostring(why), 2) end
end

-- Baut n Stücke der Sorte id in freie Kacheln der Reihe y (ab x0).
local function row(ctx, id, n, x0, y)
  local built = 0
  local x = x0
  while built < n and x < ctx.area.plot.x + ctx.area.plot.w do
    if Farm.place(ctx, id, x, y) then built = built + 1 end
    x = x + 1
  end
  return built
end

return {
  {"Summe der Deko-Punkte nach Katalog (Bank 3, Lampe 4, Kübel 2, Brunnen 25, Teich 35, Statue 80, Weg 0,5 …)", function()
    local ctx, p = setup()
    local farm = ctx.area.farm
    C.eq(Farm.schoenheit(farm), 0, "Startzustand")
    Farm.place(ctx, "bank", p.x + 12, p.y + 7)
    C.eq(Farm.schoenheit(farm), 3)
    Farm.place(ctx, "lampe", p.x + 13, p.y + 7)
    Farm.place(ctx, "blumenkuebel", p.x + 14, p.y + 7)
    C.eq(Farm.schoenheit(farm), 9)
    Farm.place(ctx, "brunnen", p.x + 12, p.y + 5)
    Farm.place(ctx, "statue", p.x + 15, p.y + 7)
    C.eq(Farm.schoenheit(farm), 9 + 25 + 80)
    for i = 0, 3 do Farm.place(ctx, "weg", p.x + 16 + i, p.y + 7) end
    C.eq(Farm.schoenheit(farm), 9 + 25 + 80 + 2, "4 Wegkacheln = 2")
    Farm.place(ctx, "stein", p.x + 16, p.y + 8)
    C.eq(Farm.schoenheit(farm), 9 + 25 + 80 + 2, "Stein +0")
    Farm.remove(ctx, p.x + 15, p.y + 7)
    C.eq(Farm.schoenheit(farm), 9 + 25 + 2)
  end},
  {"Bindungsbonus: unter 50 nichts, ab 50 +1, ab 150 +2, ab 400 +3", function()
    local ctx, p = setup()
    local farm = ctx.area.farm
    local function bonus() return (Farm.schoenheit_bonus(farm)) end
    C.eq(bonus(), 0)
    row(ctx, "bank", 16, p.x + 1, p.y + 7)              -- 16 × 3 = 48
    C.eq(Farm.schoenheit(farm), 48)
    C.eq(bonus(), 0, "48 < 50")
    row(ctx, "blumenkuebel", 1, p.x + 17, p.y + 8)      -- +2 = 50
    C.eq(Farm.schoenheit(farm), 50)
    C.eq(bonus(), 1, "genau 50")
    put(ctx, "statue", p.x + 12, p.y + 9)        -- +80 = 130
    C.eq(bonus(), 1)
    put(ctx, "teich", p.x + 14, p.y + 9)         -- +35 = 165
    C.eq(Farm.schoenheit(farm), 165)
    C.eq(bonus(), 2, "ab 150")
    put(ctx, "villa", p.x + 14, p.y + 12)        -- +100 = 265
    put(ctx, "haeuschen", p.x + 17, p.y + 15)    -- +20 = 285
    put(ctx, "statue", p.x + 10, p.y + 9)        -- +80 = 365
    C.eq(bonus(), 2)
    put(ctx, "brunnen", p.x + 6, p.y + 5)        -- +25 = 390
    put(ctx, "lampe", p.x + 4, p.y + 9)          -- +4 = 394
    C.eq(bonus(), 2, "394 < 400")
    put(ctx, "baum", p.x + 3, p.y + 9)           -- +2 = 396
    put(ctx, "baum", p.x + 2, p.y + 9)           -- +2 = 398
    put(ctx, "baum", p.x + 1, p.y + 9)           -- +2 = 400
    C.eq(Farm.schoenheit(farm), 400)
    C.eq(bonus(), 3, "ab 400")
    local b, next_at = Farm.schoenheit_bonus(farm)
    C.eq(next_at, nil, "höchste Stufe erreicht")
    Farm.remove(ctx, p.x + 1, p.y + 9)
    C.eq(bonus(), 2, "Abreißen senkt wieder")
  end},
  {"Tageswechsel: alle Pferde (nicht nur im Stall) bekommen den Hof-Bonus, Stallbonus kommt dazu", function()
    local ctx, p = setup()
    local w = ctx.wild
    local a, b = w:add_own({name = "Leine"}), w:add_own({name = "Stall"})
    w:house(b, "stall")
    for _, h in ipairs({a, b}) do h.data.bindung, h.data.hunger = 50, 0 end
    Days.new_day(ctx, 2)
    C.eq(a.data.bindung, 50, "kein Bonus ohne Schönheit")
    C.eq(b.data.bindung, 51, "nur Stall S")
    row(ctx, "statue", 1, p.x + 12, p.y + 7)            -- 80 → +1
    row(ctx, "statue", 1, p.x + 14, p.y + 7)            -- 160 → +2
    C.eq((Farm.schoenheit_bonus(ctx.area.farm)), 2)
    for _, h in ipairs({a, b}) do h.data.bindung, h.data.hunger = 50, 0 end
    Days.new_day(ctx, 3)
    C.eq(a.data.bindung, 52, "Leine: +2 Hof")
    C.eq(b.data.bindung, 53, "Stall: +1 Stall, +2 Hof")
    a.data.bindung, a.data.hunger = 99, 0
    Days.new_day(ctx, 4)
    C.eq(a.data.bindung, 100, "höchstens 100")
  end},
  {"Baumodus zeigt Schönheit und Bonus", function()
    local Screens = require("game.screens")
    local ctx, p = setup()
    Farm.place(ctx, "statue", p.x + 12, p.y + 7)
    Screens.build(ctx).draw()
  end},
}
