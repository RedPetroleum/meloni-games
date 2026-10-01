-- Selbsttests für Fahrzeuge und Reisen (Aufgabe D1).
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local Economy = require("game.economy")
local Reise = require("game.reise")
local Clock = require("game.clock")
local Save = require("game.save")
local C = require("game.tests.check")

local function setup(money)
  Area.clear()
  local ctx = Stage.build(1, 12)
  ctx.money = money or 200000
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  ctx.clock = Clock.new()
  return ctx, ctx.area.plot
end

return {
  {"Zugfahrzeug braucht die passende Garage; Gebiet und Anhänger folgen dem Besitz", function()
    local ctx, p = setup()
    C.eq(ctx.max_gebiet, 1)
    local ok, why = Economy.buy(ctx, "fahrrad")
    C.ok(not ok and why == "Garage", "ohne Schuppen nicht")
    C.ok(Farm.place(ctx, "schuppen", p.x + 13, p.y + 14))
    C.ok(Economy.buy(ctx, "fahrrad"))
    C.eq(ctx.max_gebiet, 2)
    C.ok(Economy.buy(ctx, "mofa"))
    C.eq(ctx.max_gebiet, 3)
    local ok2, why2 = Economy.buy(ctx, "kleinwagen")
    C.ok(not ok2 and why2 == "Garage", "Kleinwagen braucht die Garage")
    C.eq(Economy.garage_text("mofa"), "Für das Mofa fehlt dir ein Schuppen.")
    C.eq(Economy.garage_text("kleinwagen"), "Für den Kleinwagen fehlt dir eine Garage.")
    C.eq(Economy.garage_text("flugzeug"), "Für das Flugzeug fehlt dir ein Hangar.")
    C.ok(Farm.place(ctx, "garage", p.x + 16, p.y + 5))
    C.ok(Economy.buy(ctx, "kleinwagen"))
    C.eq(ctx.max_gebiet, 4)
    C.eq(Economy.fahrzeug(ctx).id, "kleinwagen")
    C.eq(Economy.plaetze(ctx), 0)
    C.ok(Economy.buy(ctx, "anhaenger_1"))
    C.ok(Economy.buy(ctx, "anhaenger_3"))
    C.eq(Economy.plaetze(ctx), 3)
  end},
  {"Fahrtkosten nach Entfernung; Pferde nur so viele wie der Anhänger hat; Reiten geht nicht", function()
    local ctx, p = setup()
    Farm.place(ctx, "garage", p.x + 16, p.y + 5)
    Economy.buy(ctx, "kleinwagen")
    Economy.buy(ctx, "anhaenger_1")
    local z = Reise.ziele(ctx)
    C.eq(#z, 3, "Gebiete 2, 3, 4")
    C.eq(z[1].kosten, 10)
    C.eq(z[3].kosten, 30, "Entfernung 3 × 10")
    ctx.lead = {{data = {}}, {data = {}}}
    C.ok(not Reise.ziele(ctx)[1].ok, "zwei Pferde, ein Platz")
    ctx.lead = {{data = {}}}
    C.ok(Reise.ziele(ctx)[1].ok)
    ctx.player.riding = {}
    C.ok(not Reise.ziele(ctx)[1].ok)
    ctx.player.riding = nil
    ctx.money = 5
    C.ok(not Reise.ziele(ctx)[1].ok, "zu wenig Geld")
  end},
  {"Fahrt zahlt, nimmt nur die Pferde an der Leine mit; Heimfahrt bringt den Hof zurück", function()
    local ctx, p = setup()
    Farm.place(ctx, "schuppen", p.x + 13, p.y + 14)
    Economy.buy(ctx, "mofa")
    Economy.buy(ctx, "anhaenger_1")
    local a = ctx.wild:add_own({rasse = "noriker", name = "Hilde"})
    local b = ctx.wild:add_own({rasse = "haflinger", name = "Bruno"})
    ctx.wild:attach(a)
    ctx.wild:house(b, "stall")
    local before = ctx.money
    local snap = Reise.fahren(ctx, ctx.clock, 12, 3)
    C.eq(before - ctx.money, 10, "2 Gebiete × 5")
    C.eq(snap.gebiet, 3)
    C.ok(snap.mit[a.data] and not snap.mit[b.data])
    C.eq(#snap.herd, 2)
    C.ok(snap.heim and snap.heim.pos, "Hof wird gemerkt")
    -- unterwegs gespeichert: Spielstand liegt zu Hause
    local away = {area = {nr = 3}, hof = ctx.hof, heim = snap.heim, herd = snap.herd, money = 100, inv = ctx.inv,
      player = {x = 1, y = 1}, map = {changes = {}}, orders = {}}
    local save = Save.snapshot(away, ctx.clock, 12)
    C.eq(save.gebiet, 1)
    C.eq(save.pos[1], snap.heim.pos[1])
    -- Heimfahrt
    away.area, away.lead, away.max_gebiet = {nr = 3, places = {start = {1, 1}}}, {}, 3
    local back = Reise.fahren(setmetatable(away, {__index = ctx}), ctx.clock, 12, 1)
    C.eq(back.gebiet, 1)
    C.eq(back.pos[1], snap.heim.pos[1])
    C.ok(back.heim == nil)
  end},
  {"Anhänger zu Hause: Pferd über Ort einladen, voll, nur Pferde im Anhänger fahren mit (Rückmeldung 0.5.8)", function()
    local ctx, p = setup()
    Farm.place(ctx, "schuppen", p.x + 13, p.y + 14)
    Economy.buy(ctx, "mofa")
    Economy.buy(ctx, "anhaenger_1")
    local a = ctx.wild:add_own({rasse = "noriker", name = "Hilde"})
    local b = ctx.wild:add_own({rasse = "haflinger", name = "Bruno"})
    local c = ctx.wild:add_own({rasse = "haflinger", name = "Keks"})
    ctx.wild:attach(a)
    ctx.wild:house(c, "stall")
    C.ok(ctx.wild:house(b, "anhaenger"))
    C.ok(b.hidden and b.data.ort == "anhaenger")
    C.eq(Reise.geladen(ctx), 1)
    local ok, why = ctx.wild:house(a, "anhaenger")
    C.ok(not ok and why == "der Anhänger ist voll")
    C.ok(not Reise.ziele(ctx)[1].ok, "Leine + Anhänger > 1 Platz")
    ctx.wild:release(a)
    C.ok(Reise.ziele(ctx)[1].ok, "Hilde bleibt lose zu Hause")
    local snap = Reise.fahren(ctx, ctx.clock, 12, 2)
    C.ok(snap.mit[b.data] and not snap.mit[a.data] and not snap.mit[c.data])
    C.eq(c.data.ort, "stall")
    -- zu Hause ausladen: neben dem Anhänger an der Schuppentür
    local x0, y = Reise.trailer_box(ctx)
    C.eq(Reise.ausladen(ctx), 1)
    C.ok(b.data.ort == nil and not b.hidden)
    C.ok(math.abs(b.x - x0) <= 80 and b.y > y and b.y < y + 40, "neben dem Anhänger")
  end},
  {"Anhänger unterwegs: einladen, lose Pferde halten auf, Freilassen, Ausladen neben dem Anhänger", function()
    Area.clear()
    local ctx = Stage.build(2, 12)
    ctx.wild = Wild.new(ctx, 3)
    ctx.wild.count = 0
    ctx.clock = Clock.new()
    ctx.inv.mofa, ctx.inv.anhaenger_2 = 1, 1
    Economy.refresh_gebiet(ctx)
    C.ok(ctx.area.village == nil and ctx.area.places.laden == nil, "kein Dorf")
    C.eq(#Farm.all_buildings(nil), 0, "ohne Hof keine Gebäude")
    local a = ctx.wild:add_own({rasse = "noriker", name = "Hilde"})
    local b = ctx.wild:add_own({rasse = "haflinger", name = "Bruno"})
    local z = Reise.ziele(ctx)[1]
    C.ok(not z.ok and z.grund:find("nicht im Anhänger"), "lose Pferde müssen mit")
    local x0, y, w = Reise.trailer_box(ctx)
    C.ok(x0 and w > 0)
    ctx.player.x, ctx.player.y = x0 + w // 2, y + 10
    C.ok(Reise.at_trailer(ctx))
    ctx.player.x = x0 + w + 60
    C.ok(not Reise.at_trailer(ctx))
    C.ok(ctx.wild:house(a, "anhaenger"))
    ctx.wild:free(b)
    C.eq(#ctx.herd, 1)
    C.eq(#ctx.herd_horses, 1)
    C.ok(b.dead)
    C.ok(Reise.ziele(ctx)[1].ok)
    C.eq(Reise.ausladen(ctx), 1)
    C.ok(a.data.ort == nil and not a.hidden and a.state == "free")
    C.ok(a.x >= x0 and a.x <= x0 + 80 and a.y > y, "steht unter/neben dem Anhänger")
    Area.clear()
  end},
  {"Fahrzeugwahl: im selben Schuppen wählbar, im Hof gemerkt, bestimmt Reichweite und Kosten", function()
    local ctx, p = setup()
    Farm.place(ctx, "schuppen", p.x + 13, p.y + 14)
    Farm.place(ctx, "garage", p.x + 16, p.y + 5)
    Economy.buy(ctx, "fahrrad")
    Economy.buy(ctx, "mofa")
    Economy.buy(ctx, "kleinwagen")
    C.eq(Economy.aktiv(ctx).id, "kleinwagen", "ohne Wahl das beste")
    local d = Reise.station(ctx)
    ctx.player.x, ctx.player.y = d[1] * 16 + 8, d[2] * 16 + 8
    C.eq(#Reise.wahl(ctx), 1, "Garage: nur der Kleinwagen")
    local sd
    for _, v in ipairs(Farm.vehicle_doors(ctx.area.farm)) do if v.fahrzeuge.mofa then sd = v end end
    ctx.player.x, ctx.player.y = sd[1] * 16 + 8, sd[2] * 16 + 8
    C.ok(Reise.at_station(ctx), "auch am Schuppen")
    local w = Reise.wahl(ctx)
    C.eq(#w, 2, "Schuppen: Fahrrad und Mofa")
    C.eq(Economy.aktiv(ctx).id, "mofa", "am Schuppen das beste von dort")
    Economy.waehlen(ctx, "fahrrad")
    C.eq(ctx.area.farm.fahrzeug, "fahrrad")
    local z = Reise.ziele(ctx)
    C.eq(#z, 1, "Fahrrad: nur Gebiet 2")
    C.eq(z[1].kosten, 0)
    C.eq(Economy.fahrzeug(ctx).id, "kleinwagen", "Besitz zählt weiter für Markt und Turniere")
  end},
  {"Heimfahrt geht immer: kostet höchstens das Geld, das noch da ist", function()
    Area.clear()
    local ctx = Stage.build(4, 12)
    ctx.wild = Wild.new(ctx, 3)
    ctx.wild.count = 0
    ctx.clock = Clock.new()
    ctx.inv.kleinwagen = 1
    ctx.money = 7
    local z = Reise.ziele(ctx)
    C.ok(z[1].nr == 1 and z[1].ok and z[1].kosten == 7, "heim für 7 statt 30")
    C.ok(not z[2].ok, "Flussauen (20 G) nicht")
    ctx.money = 0
    C.ok(Reise.ziele(ctx)[1].ok and Reise.ziele(ctx)[1].kosten == 0, "ohne Geld gratis")
    Area.clear()
  end},
}
