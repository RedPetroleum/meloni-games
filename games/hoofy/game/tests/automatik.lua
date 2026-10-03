-- Selbsttests für die Hof-Automatik (Rückmeldung 1.5.2, E85): Heuraufe, Kratzbürste, Stallbursche.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local Days = require("game.days")
local Automatik = require("game.automatik")
local H = require("game.horse_model")
local K = require("game.katalog")
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

local function horse(ort)
  local d = H.wild({rng = Rng.new(2), zug = "faul", rasse = "haflinger"})
  d.alter, d.ort, d.hunger, d.sauberkeit, d.bindung = 1, ort or "stall", 70, 30, 40
  return d
end

return {
  {"Katalog: Preise und Werte der Pflege-Bauten", function()
    C.eq(K.bauteil("heuraufe").preis, 600)
    C.eq(K.bauteil("heuraufe").auto_hunger, 40)
    C.eq(K.bauteil("kratzbuerste").wirkung.sauberkeit, 20)
    C.eq(K.bauteil("stallburschenhuette").lohn, 15)
    local found = false
    for _, c in ipairs(Farm.CATEGORIES) do if c.id == "pflege" then found = #c.items == 3 end end
    C.ok(found, "Baumenü Pflege")
  end},
  {"Ohne Pflege-Bauten passiert nichts", function()
    local ctx = setup()
    local d = horse()
    ctx.herd = {d}
    local r = Automatik.tag(ctx)
    C.eq(r.gefuettert + r.gebuerstet + r.gepflegt, 0)
    C.eq(Automatik.text(r), nil)
  end},
  {"Heuraufe füttert hungrige Hofpferde, erst Heu aus dem Haus, dann gekauft; Anhänger zählt nicht", function()
    local ctx, p = setup()
    C.ok(Farm.place(ctx, "heuraufe", p.x + 13, p.y + 5))
    ctx.inv.heu = 1
    local a, b, weg = horse("stall"), horse("weide"), horse("anhaenger")
    a.hunger, b.hunger = 75, 30
    ctx.herd = {a, b, weg}
    local money = ctx.money
    local r = Automatik.tag(ctx)
    C.ok(a.hunger <= 40, "satt genug: " .. a.hunger)
    C.eq(b.hunger, 30, "nicht hungrig, kein Futter")
    C.eq(weg.hunger, 70, "im Anhänger nicht")
    C.eq(ctx.inv.heu, 0, "Heu aus dem Haus zuerst")
    C.eq(r.gefuettert, 1)
    C.eq(r.heu_gekauft, 1, "zweites Heu gekauft (Hunger 75 → 45 → 15)")
    C.eq(ctx.money, money - 5)
    C.ok(Automatik.text(r):find("Heuraufe"), "Meldung")
  end},
  {"Kratzbürste und Stallbursche: Sauberkeit, Bindung, Lohn; ohne Geld kein Bursche", function()
    local ctx, p = setup()
    C.ok(Farm.place(ctx, "kratzbuerste", p.x + 13, p.y + 5))
    C.ok(Farm.place(ctx, "stallburschenhuette", p.x + 15, p.y + 5))
    local d = horse("weide")
    ctx.herd = {d}
    local money = ctx.money
    local r = Automatik.tag(ctx)
    C.eq(d.sauberkeit, 30 + 20 + 40, "Bürste +20, Bursche striegelt +40")
    C.eq(d.bindung, 40 + 2 + 1, "streicheln +2, striegeln +1")
    C.eq(ctx.money, money - 15, "Lohn")
    C.eq(r.gepflegt, 1)
    ctx.money = 10
    local d2 = horse("stall")
    ctx.herd = {d2}
    r = Automatik.tag(ctx)
    C.ok(r.kein_lohn, "kein Lohn")
    C.eq(d2.bindung, 40, "Bursche bleibt liegen")
    C.eq(d2.sauberkeit, 50, "Bürste wirkt trotzdem")
    C.ok(Automatik.text(r):find("Lohn"), "Meldung")
  end},
  {"Tageswechsel wendet die Automatik an; Stallbursche steht an seiner Hütte", function()
    local ctx, p = setup()
    C.ok(Farm.place(ctx, "heuraufe", p.x + 13, p.y + 5))
    C.ok(Farm.place(ctx, "stallburschenhuette", p.x + 15, p.y + 5))
    local d = horse("stall")
    d.hunger = 50
    ctx.herd = {d}
    Days.new_day(ctx, 2)
    C.ok(d.hunger <= 40, "morgens gefüttert: " .. d.hunger)
    C.ok(ctx.automatik and ctx.automatik.gepflegt == 1, "Bursche hat gepflegt")
    local e = Automatik.sync(ctx)
    C.ok(e and e.is_bursche, "Figur da")
    for _ = 1, 600 do e:update() end
    local dx, dy = e.x / 16 - e.home[1], e.y / 16 - e.home[2]
    C.ok(math.abs(dx) <= 7 and math.abs(dy) <= 7, "bleibt bei der Hütte")
    C.ok(Farm.remove(ctx, p.x + 15, p.y + 5), "Hütte abreißen")
    C.eq(Automatik.sync(ctx), nil, "Figur weg")
    Area.clear()
    Stage.build(1, 1)
  end},
}
