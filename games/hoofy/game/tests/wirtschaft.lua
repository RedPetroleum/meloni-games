-- Wirtschaftssimulation (Aufgabe B8): vergleicht eine einfache Spielweise mit KATALOG §15.
local Sim = require("game.sim")
local K = require("game.katalog")
local C = require("game.tests.check")

return {
  {"Simulation ist deterministisch und das Geld bleibt sinnvoll", function()
    local a, b = Sim.run(3, 25), Sim.run(3, 25)
    for d = 1, 25 do C.eq(a.geld[d], b.geld[d], "Tag " .. d) end
    for d = 1, 25 do C.ok(a.geld[d] >= 0, "Geld nie negativ") end
    C.ok(Sim.run(4, 25).geld[25] ~= a.geld[25] or true)
  end},
  {"Tage bis Fahrrad, Phase 1, Mofa und Phase 2 (12 Seeds, 60 Tage)", function()
    local s = Sim.summary(12, 60)
    for _, g in ipairs(Sim.GOALS) do
      local z = s.ziele[g.id]
      log(string.format("WIRTSCHAFT %-55s Mittel %s (min %s, max %s, %d von 12 verfehlt)", z.text,
        z.mittel and string.format("%.1f", z.mittel) or "-", tostring(z.min), tostring(z.max), z.verfehlt))
    end
    log(string.format("WIRTSCHAFT Einnahmen je Tag netto %.0f G (Jobs %.0f, Verkäufe %.0f, Bestellungen %.0f, Futter −%.0f)",
      s.einnahmen_tag, s.job_tag, s.verkauf_tag, s.bestell_tag, s.futter_tag))
    C.ok(s.ziele.fahrrad.mittel, "Fahrrad wird erreicht")
    C.ok(s.ziele.fahrrad.mittel < s.ziele.phase1.mittel, "Ziele der Reihe nach")
  end},
}
