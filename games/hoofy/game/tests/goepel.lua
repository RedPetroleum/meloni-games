-- Selbsttests für den Göpel-Generator (Aufgabe C6).
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local Days = require("game.days")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function setup()
  Area.clear()
  local ctx = Stage.build(1, 8)
  ctx.money = 10000
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  return ctx, ctx.area.plot
end

local function horse(staerke, ort)
  local d = H.wild({rng = Rng.new(2), zug = "faul", rasse = "haflinger"})
  for _, k in ipairs(H.STATS) do d.gen[k], d.train[k], d.pot[k] = 50, 0, 80 end
  d.gen.staerke = staerke
  d.alter, d.ort, d.energie = 1, ort or "goepel", 50
  return d
end

return {
  {"Göpel kostet 1 500; 40 Geld je Pferd und Tag, ein Pferd je Generator (Ort Göpel)", function()
    local ctx, p = setup()
    C.ok(Farm.place(ctx, "goepel_generator", p.x + 13, p.y + 5))
    C.eq(ctx.money, 8500)
    ctx.herd = {horse(60), horse(45), horse(70)}
    Days.new_day(ctx, 2)
    C.eq(ctx.money, 8540, "ein Generator, ein Pferd")
    C.ok(Farm.place(ctx, "goepel_generator", p.x + 16, p.y + 5))
    ctx.herd = {horse(60), horse(45), horse(70)}
    ctx.money = 0
    Days.new_day(ctx, 3)
    C.eq(ctx.money, 80, "zwei Generatoren, zwei stärkste")
  end},
  {"Bedingungen: Stärke ≥ 40, Energie ≥ 40, Pferd auf dem Hof, kein Fohlen; ohne Generator nichts", function()
    local ctx, p = setup()
    ctx.herd = {horse(60)}
    Days.new_day(ctx, 2)
    C.eq(ctx.money, 10000, "kein Generator")
    C.ok(Farm.place(ctx, "goepel_generator", p.x + 13, p.y + 5))
    ctx.money = 0
    local schwach, muede, fremd, fohlen = horse(39), horse(60), horse(60, nil), horse(60)
    muede.energie = 39
    fremd.ort = nil
    fohlen.alter = 0.5
    for _, d in ipairs({schwach, muede, fremd, fohlen}) do
      ctx.herd = {d}
      Days.new_day(ctx, 3)
    end
    C.eq(ctx.money, 0)
    ctx.goepel_mult = 2
    ctx.herd = {horse(60)}
    Days.new_day(ctx, 4)
    C.eq(ctx.money, 80, "Stromsubvention verdoppelt")
  end},
}
