-- Selbsttests für die Erkundung und die Karte (Aufgabe A15).
local Explore = require("game.explore")
local Stage = require("game.stage")
local Clock = require("game.clock")
local Save = require("game.save")
local Screens = require("game.screens")
local C = require("game.tests.check")

return {
  {"Zellen: 96×80 Kacheln → 24×20 Zellen, anfangs nichts erkundet", function()
    local rows = Explore.new(96, 80)
    C.eq(#rows, 20)
    C.eq(#rows[1], 24)
    C.eq(Explore.share(rows), 0)
    C.ok(not Explore.is_explored(rows, 3, 3))
  end},
  {"Aufdecken: nur berührte Zellen, doppelt aufdecken ändert nichts", function()
    local rows = Explore.new(96, 80)
    -- Bildschirm 320×240 ab (100, 100): Zellen 1..6 × 1..5 (64 px je Zelle)
    C.ok(Explore.reveal(rows, 100, 100, 420, 340), "geändert")
    C.ok(Explore.is_explored(rows, 1, 1))
    C.ok(Explore.is_explored(rows, 6, 5))
    C.ok(not Explore.is_explored(rows, 0, 0))
    C.ok(not Explore.is_explored(rows, 7, 5))
    C.ok(not Explore.is_explored(rows, 6, 6))
    C.ok(not Explore.reveal(rows, 100, 100, 420, 340), "nichts Neues")
    C.near(Explore.share(rows), 30 / 480, 1e-6)
    Explore.reveal(rows, -500, -500, 10, 10)             -- außerhalb ist kein Fehler
    Explore.reveal(rows, 5000, 5000, 6000, 6000)
    C.ok(Explore.is_explored(rows, 0, 0))
  end},
  {"Spielstand enthält die Erkundung und stellt sie wieder her", function()
    local ctx = Stage.build(1)
    Explore.reveal(ctx.explored, 0, 0, 400, 300)
    local snap = Save.snapshot(ctx, Clock.new(), 1)
    local back = load("return " .. Save.encode(snap), "=x", "t", {})()
    C.eq(#back.erkundet, 20)
    C.eq(back.erkundet[1], ctx.explored[1])
    C.near(Explore.share(back.erkundet), Explore.share(ctx.explored), 1e-9)
  end},
  {"Karte zeichnet mit Erkundung, Hof, Dorf und Pferden ohne Fehler", function()
    local ctx = Stage.build(1)
    local p = ctx.area.plot
    Explore.reveal(ctx.explored, p.x * 16, p.y * 16, (p.x + p.w) * 16, (p.y + p.h) * 16)
    local s = Screens.map(ctx)
    s.draw()
    s.draw()                                             -- zweites Mal zeichnet nichts neu
    C.ok(s.full and s.static)
  end},
}
