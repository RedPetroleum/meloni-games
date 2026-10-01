-- Selbsttests für Geld und Laden (Aufgabe B1): Kaufen, Zurückgeben, Ausrüstung.
local Stage = require("game.stage")
local Economy = require("game.economy")
local Ride = require("game.ride")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function ctx_new(money)
  local ctx = Stage.build(1)
  ctx.money = money or 300
  return ctx
end

local function horse()
  local d = H.wild({rng = Rng.new(2), zug = "faul", rasse = "haflinger"})
  for _, k in ipairs(H.STATS) do d.gen[k], d.train[k], d.pot[k] = 40, 0, 60 end
  return d
end

return {
  {"Startgeld 300, ohne Bürste; Warenliste nach Katalog", function()
    local ctx = ctx_new()
    C.eq(ctx.money, 300)
    C.eq(ctx.inv.buerste, 0)
    local cats = {}
    for _, it in ipairs(Economy.catalog(1)) do cats[it.kat] = (cats[it.kat] or 0) + 1 end
    C.eq(cats.futter, 4, "Heu, Hafer, Karotte, Premium")
    C.eq(cats.saettel, 4)
    C.eq(cats.zubehoer, 6, "Bürste, Taschen S/M/L, Sattellampe, Laterne")
    C.eq(cats.schmuck, 4)
    C.eq(cats.samen, 3, "Gebiet 1: Gras, Karotte, Apfelbaum")
    local all = 0
    for _, it in ipairs(Economy.catalog(6)) do if it.kat == "samen" then all = all + 1 end end
    C.eq(all, 10, "alle Samen ab Gebiet 6")
  end},
  {"Kaufen zieht den Preis ab und füllt den Vorrat; zu wenig Geld geht nicht", function()
    local ctx = ctx_new(100)
    local ok = Economy.buy(ctx, "heu")
    C.ok(ok)
    C.eq(ctx.money, 95)
    C.eq(ctx.inv.heu, 4, "3 Start + 1")
    for _ = 1, 19 do Economy.buy(ctx, "heu") end
    C.eq(ctx.money, 0)
    local ok2, why = Economy.buy(ctx, "heu")
    C.ok(not ok2 and why == "Geld")
    C.eq(ctx.inv.heu, 3 + 20)
    local ok3, why3 = Economy.buy(ctx_new(10), "einfacher_sattel")
    C.ok(not ok3 and why3 == "Geld", "Sattel 150")
  end},
  {"Einmalige Waren: Bürste und Samen nur einmal", function()
    local ctx = ctx_new(1000)
    C.ok(Economy.buy(ctx, "buerste"), "Bürste gibt es nicht zum Start")
    local ok, why = Economy.buy(ctx, "buerste")
    C.ok(not ok and why == "schon da", "Bürste nur einmal")
    C.ok(Economy.buy(ctx, "samen_karotte"))
    C.eq(ctx.money, 1000 - 20 - 15)
    C.ok(Economy.has_seed(ctx, "karotte"))
    local ok2, why2 = Economy.buy(ctx, "samen_karotte")
    C.ok(not ok2 and why2 == "schon da")
    C.ok(not Economy.has_seed(ctx, "apfelbaum"))
  end},
  {"Hafersteuer: Futter +50 %, andere Waren nicht", function()
    local ctx = ctx_new(1000)
    ctx.futter_aufschlag = 50
    C.eq(Economy.price(ctx, Economy.find("heu")), 8, "5 × 1,5 aufgerundet")
    C.eq(Economy.price(ctx, Economy.find("premiumfutter")), 90)
    C.eq(Economy.price(ctx, Economy.find("einfacher_sattel")), 150)
  end},
  {"Bauelemente zum halben Kaufpreis zurück", function()
    local ctx = ctx_new(1000)
    C.ok(Economy.buy_building(ctx, "stall_m"))
    C.eq(ctx.money, 100)
    local ok = Economy.buy_building(ctx, "villa")
    C.ok(not ok, "zu teuer")
    C.eq(Economy.refund_building(ctx, "stall_m"), 450)
    C.eq(ctx.money, 550, "halber Preis zurück")
    Economy.buy_building(ctx, "zaun", 10)
    C.eq(ctx.money, 500)
    Economy.refund_building(ctx, "zaun", 10)
    C.eq(ctx.money, 520)
    Economy.sell_find(ctx, 200)
    C.eq(ctx.money, 720)
  end},
  {"Sattel anlegen: Tempo-Bonus, Wechsel gibt den alten zurück, Taschen nur mit Sattel", function()
    local ctx = ctx_new(5000)
    local d = horse()
    local base = Ride.tempo(d)
    Economy.buy(ctx, "einfacher_sattel")
    Economy.buy(ctx, "rennsattel")
    Economy.buy(ctx, "satteltaschen_m")
    local ok, why = Economy.equip(ctx, d, "satteltaschen_m")
    C.ok(not ok and why == "braucht einen Sattel")
    C.ok(Economy.equip(ctx, d, "einfacher_sattel"))
    C.eq(Ride.tempo(d), base + 5)
    C.eq(ctx.inv.einfacher_sattel, 0)
    C.ok(Economy.equip(ctx, d, "rennsattel"))
    C.eq(Ride.tempo(d), base + 15)
    C.eq(ctx.inv.einfacher_sattel, 1, "alter Sattel zurück im Vorrat")
    C.ok(Economy.equip(ctx, d, "satteltaschen_m"))
    C.eq(Economy.tasche_plaetze(d), 2)
    Economy.unequip(ctx, d, "rennsattel")
    C.eq(d.sattel, nil)
    C.eq(d.taschen, nil, "Taschen gehen mit dem Sattel ab")
    C.eq(ctx.inv.satteltaschen_m, 1)
    C.eq(Ride.tempo(d), base)
  end},
  {"Schmuck und Lampe: einmal je Stück, Schönheit aus dem Katalog", function()
    local ctx = ctx_new(20000)
    local d = horse()
    for _, id in ipairs({"maehnenschleife", "blumenkranz", "glitzerdecke", "goldhufeisen", "sattellampe", "goldsattel"}) do
      Economy.buy(ctx, id)
    end
    C.ok(Economy.equip(ctx, d, "maehnenschleife"))
    local ok = Economy.equip(ctx, d, "maehnenschleife")
    C.ok(not ok, "nicht im Vorrat / schon an")
    C.ok(Economy.equip(ctx, d, "blumenkranz"))
    C.ok(Economy.equip(ctx, d, "glitzerdecke"))
    C.ok(Economy.equip(ctx, d, "goldhufeisen"))
    C.eq(Economy.schoenheit(d), 5 + 10 + 15 + 30)
    C.ok(Economy.equip(ctx, d, "goldsattel"))
    C.eq(Economy.schoenheit(d), 60 + 20, "Goldsattel +20")
    C.ok(Economy.equip(ctx, d, "sattellampe"))
    C.ok(d.lampe)
    Economy.unequip(ctx, d, "blumenkranz")
    C.eq(Economy.schoenheit(d), 70)
    C.eq(ctx.inv.blumenkranz, 1)
  end},
  {"Laden und Inventar zeichnen, Kauf im Laden per Tasten", function()
    local Screens = require("game.screens")
    local ctx = ctx_new(50)
    local nav = {stack = {}}
    function nav.push(s) nav.stack[#nav.stack + 1] = s end
    function nav.pop() nav.stack[#nav.stack] = nil end
    local shop = Screens.shop(ctx)
    nav.push(shop)
    shop.draw()
    local old = btnp
    local function key(k) btnp = function(b) return b == k end; shop.update(nav) end
    key(BTN_A)                                       -- Heu
    C.eq(ctx.money, 45)
    key(BTN_DOWN) key(BTN_DOWN) key(BTN_DOWN) key(BTN_A)   -- Premiumfutter 60: zu teuer
    C.eq(ctx.money, 45)
    key(BTN_RIGHT) key(BTN_A)                        -- Sättel: einfacher Sattel 150: zu teuer
    C.eq(ctx.money, 45)
    key(BTN_B)
    btnp = old
    C.eq(#nav.stack, 0)
    Screens.inventory(ctx).draw()
  end},
}
