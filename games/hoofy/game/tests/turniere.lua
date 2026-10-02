-- Selbsttests für Turniere (Aufgabe E1): Klassen nach Fahrzeug, Wertung, Rotation, Teilnahme, Chancen.
local Stage = require("game.stage")
local Area = require("game.area")
local Turniere = require("game.turniere")
local Economy = require("game.economy")
local H = require("game.horse_model")
local K = require("game.katalog")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function setup()
  Area.clear()
  local ctx = Stage.build(1, 41)
  ctx.money = 10000
  return ctx
end

local function horse(v, bindung)
  local d = H.wild({rng = Rng.new(3), rasse = "haflinger"})
  for _, k in ipairs(H.STATS) do d.gen[k], d.train[k], d.pot[k] = v, 0, 100 end
  d.bindung, d.alter, d.sauberkeit = bindung or 100, 1, 100
  return d
end

return {
  {"Klassen nach Fahrzeug: Dorf immer, Kreis ab Fahrrad … International ab Flugzeug", function()
    local ctx = setup()
    C.eq(#Turniere.klassen(ctx), 1)
    local n = {fahrrad = 2, mofa = 3, kleinwagen = 4, suv = 5, flugzeug = 6}
    for id, count in pairs(n) do
      ctx.inv = {[id] = 1}
      C.eq(#Turniere.klassen(ctx), count, id)
    end
  end},
  {"Wertung = Stat-Anteil × (0,5 + Bindung / 200)", function()
    local d = horse(60, 100)
    d.zug = "brav"
    C.near(Turniere.fach(d, "springreiten"), 60, 0.5)
    C.near(Turniere.wertung(d, "springreiten"), 60, 0.5, "Bindung 100 → ×1")
    d.bindung = 0
    C.near(Turniere.wertung(d, "pferderennen"), 30, 0.3, "Bindung 0 → ×0,5")
    d.bindung = 100
    d.sauberkeit = 0
    C.ok(Turniere.fach(d, "schoenheitswettbewerb") < 60, "Schönheit hängt an Sauberkeit/Schmuck")
    local rar, plain = horse(50), horse(50)
    rar.farbe = K.farben.stufen[5].farben[1]
    C.ok(Turniere.seltenheit(rar) > Turniere.seltenheit(plain), "seltene Farbe zählt")
  end},
  {"Chancen steigen mit der Stärke; Klassen werden härter", function()
    local ctx = setup()
    local lo, hi = horse(20), horse(90)
    local wl = Turniere.chancen(ctx, lo, 1, "pferderennen", 0)
    local wh = Turniere.chancen(ctx, hi, 1, "pferderennen", 0)
    C.ok(wh > wl, "stark vs. schwach")
    C.eq(wh, 100)
    C.ok(Turniere.chancen(ctx, hi, 6, "pferderennen", 0) < wh, "International schwerer")
    local g = Turniere.gegner(ctx, 1, "pferderennen", 0)
    C.eq(#g, Turniere.GEGNER)
    local g2 = Turniere.gegner(ctx, 1, "pferderennen", 1)
    local same = true
    for i = 1, #g do if g[i] ~= g2[i] then same = false end end
    C.ok(not same, "neue Runde, neue Teilnehmer")
  end},
  {"Teilnahme: Gebühr und Preis, Wettbewerb danach weg bis zur nächsten Runde, Fahrzeug nötig", function()
    local ctx = setup()
    local d = horse(95)
    local r = Turniere.teilnehmen(ctx, 1, d, 1, "springreiten")
    C.eq(r.rank, 1)
    C.eq(ctx.money, 10000 - 10 + 50, "Gebühr 10, 1. Preis 50")
    local ok, why = Turniere.teilnehmen(ctx, 2, d, 1, "springreiten")
    C.ok(not ok and why == "weg", "Tag 2 gleiche Runde")
    C.ok(Turniere.teilnehmen(ctx, 2, d, 1, "pferderennen"), "andere Wettbewerbe bleiben offen")
    C.ok(Turniere.teilnehmen(ctx, 4, d, 1, "springreiten"), "Runde 2 ab Tag 4")
    local ok2, why2 = Turniere.teilnehmen(ctx, 4, d, 2, "springreiten")
    C.ok(not ok2 and why2 == "Fahrzeug")
    ctx.money = 5
    local ok3, why3 = Turniere.teilnehmen(ctx, 4, d, 1, "schoenheitswettbewerb")
    C.ok(not ok3 and why3 == "Geld")
    local foal = horse(95)
    foal.alter = 0.5
    ctx.money = 1000
    local ok4, why4 = Turniere.teilnehmen(ctx, 4, foal, 1, "schoenheitswettbewerb")
    C.ok(not ok4 and why4 == "Fohlen")
  end},
  {"Turnierplatz zeichnet und bedient sich per Tasten", function()
    local Screens = require("game.screens")
    local ctx = setup()
    ctx.clock = {day = 1}
    ctx.herd = {horse(95)}
    local nav = {stack = {}}
    function nav.push(s) nav.stack[#nav.stack + 1] = s end
    function nav.pop() nav.stack[#nav.stack] = nil end
    local s = Screens.turnier(ctx)
    nav.push(s)
    local old = btnp
    local function key(k) btnp = function(b) return b == k end; s.update(nav) s.draw() end
    s.draw()
    key(BTN_A) key(BTN_A) key(BTN_A)          -- Dorf, Schönheit, Pferd → Vorführung
    C.eq(#nav.stack, 2, "Vorführung offen")
    local vf = nav.stack[2]
    btnp = function() return false end
    for _ = 1, 3000 do if nav.stack[2] then vf.update(nav) vf.draw() end end   -- alles verpasst, Endtafel
    C.eq(#nav.stack, 2, "Endtafel wartet auf A")
    btnp = function(b) return b == BTN_A end
    for _ = 1, 50 do if nav.stack[2] then vf.update(nav) end end   -- erst nach der Sperre
    C.eq(#nav.stack, 1, "Vorführung zu")
    C.ok(Turniere.state(ctx, 1).weg["1:schoenheitswettbewerb"], "angetreten")
    s.draw()
    key(BTN_A)                                -- sofortiges A: Ergebnis bleibt (Sperre)
    key(BTN_A) key(BTN_A)
    C.ok(Turniere.state(ctx, 1).weg["1:schoenheitswettbewerb"])
    for _ = 1, 50 do key(BTN_A) end           -- nach der Sperre schließt A das Ergebnis
    key(BTN_A) key(BTN_A)                     -- gleich danach: gesperrt, kein neuer Start
    C.eq(#nav.stack, 1)
    for _ = 1, 35 do key(nil) end             -- Sperre abwarten
    key(BTN_A) key(BTN_A)                     -- Dorf, Schönheit ist weg
    C.eq(#nav.stack, 1)
    key(BTN_B) key(BTN_B)
    btnp = old
    C.eq(#nav.stack, 0)
  end},
  {"Spiel zählt: unpassendes Pferd mit perfektem Spiel nicht Letzter, überlegenes mit schwachem Spiel kein Podest", function()
    local ctx = setup()
    local podest, letzter, n = 0, 0, 0
    for klasse = 1, 6 do
      for runde = 0, 9 do
        local g = Turniere.gegner(ctx, klasse, "springreiten", runde)
        table.sort(g)
        local a, b = Turniere.anteile(8, klasse)          -- unpassendes Pferd (Wertung 8), perfekte Leistung
        if a + b < g[1] then letzter = letzter + 1 end
        a, b = Turniere.anteile(100, klasse)              -- überlegenes Pferd, Leistung 0,2
        if a + b * 0.2 > g[#g - 2] then podest = podest + 1 end
        n = n + 1
      end
    end
    C.ok(letzter <= 1, "unpassendes Pferd, perfektes Spiel: Letzter in " .. letzter .. " von " .. n)
    C.ok(podest <= n // 10, "überlegenes Pferd, schwaches Spiel: Podest in " .. podest .. " von " .. n)
  end},
}
