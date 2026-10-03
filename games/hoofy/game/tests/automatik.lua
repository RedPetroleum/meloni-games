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
  {"Heuraufe: mit A aus dem Haus befüllen (höchstens 20), füttert hungrige Hofpferde, kauft nie nach", function()
    local ctx, p = setup()
    C.eq(K.bauteil("heuraufe").vorrat_max, 20)
    C.ok(Farm.place(ctx, "heuraufe", p.x + 13, p.y + 5))
    local raufe = Automatik.raufen(ctx.area.farm)[1]
    C.eq(raufe.vorrat, 0, "leer gebaut")
    ctx.inv.heu = 25
    local n = Automatik.befuellen(ctx, raufe)
    C.eq(n, 20)
    C.eq(raufe.vorrat, 20)
    C.eq(ctx.inv.heu, 5, "Rest bleibt im Haus")
    C.eq(Automatik.befuellen(ctx, raufe), 0, "voll")
    -- vor der Raufe stehen: A befüllt
    ctx.player.x, ctx.player.y = (p.x + 14) * 16, (p.y + 6) * 16 + 10
    C.eq(Automatik.raufe_nah(ctx), raufe, "steht vor der Raufe")
    ctx.player.x = ctx.player.x + 80
    C.eq(Automatik.raufe_nah(ctx), nil, "zu weit weg")
    local a, b, weg = horse("stall"), horse("weide"), horse("anhaenger")
    a.hunger, b.hunger = 75, 30
    ctx.herd = {a, b, weg}
    raufe.vorrat = 1
    local money = ctx.money
    local r = Automatik.tag(ctx)
    C.eq(a.hunger, 45, "ein Heu, dann leer")
    C.eq(b.hunger, 30, "nicht hungrig, kein Futter")
    C.eq(weg.hunger, 70, "im Anhänger nicht")
    C.eq(raufe.vorrat, 0)
    C.eq(r.gefuettert, 1)
    C.eq(r.kein_heu, 1, "leer")
    C.eq(ctx.money, money, "kauft nichts nach")
    C.eq(ctx.inv.heu, 5, "nimmt nichts aus dem Haus")
    C.ok(Automatik.text(r):find("nachfüllen"), "Meldung")
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
    Automatik.raufen(ctx.area.farm)[1].vorrat = 20
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
