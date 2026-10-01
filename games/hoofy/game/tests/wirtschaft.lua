-- Wirtschaftssimulation (Aufgabe B8, E77): spielt eine normale Spielweise durch und vergleicht mit KATALOG §15.
-- Ziel des Menschen: pro Gebiet etwa 1–3 Stunden Spielzeit.
local Sim = require("game.sim")
local K = require("game.katalog")
local C = require("game.tests.check")

return {
  {"Simulation ist deterministisch und das Geld bleibt sinnvoll", function()
    local a, b = Sim.run(3, 25), Sim.run(3, 25)
    for d = 1, 25 do C.eq(a.geld[d], b.geld[d], "Tag " .. d) end
    for d = 1, 25 do C.ok(a.geld[d] >= 0, "Geld nie negativ") end
  end},
  {"Tage je Phase (12 Seeds, 250 Tage): jede Phase etwa 0,75–3,5 Stunden", function()
    local s = Sim.summary(12, 250)
    local total = 0
    for i, p in ipairs(s.phasen) do
      local q = p.quellen
      total = total + (p.mittel or 0)
      log(string.format("WIRTSCHAFT %-52s %5.1f Tage (min %s, max %s, %d verfehlt) ≈ %s min | netto %5.0f G/Tag: Verkauf %5.0f, Jobs %4.0f, Bestellungen %4.0f, Turniere %5.0f, Futter %4.0f",
        p.text, p.mittel or 0, tostring(p.min), tostring(p.max), p.verfehlt, p.minuten and string.format("%.0f", p.minuten) or "-",
        q.netto, q.verkauf, q.jobs, q.bestellung, q.turnier, q.futter))
      C.ok(p.mittel, "Phase " .. i .. " wird erreicht")
      C.ok(p.minuten >= 45 and p.minuten <= 210, "Phase " .. i .. ": " .. string.format("%.0f", p.minuten) .. " min")
    end
    log(string.format("WIRTSCHAFT bis zum Flugzeug %.0f Tage ≈ %.1f h", total, total * Sim.MIN_PER_DAY / 60))
    C.eq(#s.phasen, #K.wirtschaft.phasen)
  end},
}
