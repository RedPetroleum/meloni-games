-- Benannte Ausgangslagen zum Testen: Ein Spielstand {scenario = "name", …} startet das Spiel
-- direkt dort (tools/hoofy-test.sh schreibt so einen Spielstand und startet den Runner).
--
-- Ein Szenario ist eine Funktion(save) und gibt die Szene zurück, mit der es weitergeht
-- (Name und Argument wie in main.lua), z. B. "world".
local Scenarios = {}

-- Alle Selbsttests aus game/tests/ (Liste in game/tests/list.lua). save.only = "modul": nur dieses,
-- save.list = "game.tests.andere_liste": andere Liste (z. B. für eine einmalige Messung).
-- Loggt "SELFTEST OK <n>" oder wirft beim ersten Fehler (Runner endet mit Status 1).
function Scenarios.selftest(save)
  local modules = require(save.list or "game.tests.list")
  local n = 0
  for _, name in ipairs(modules) do
    if not save.only or save.only == name then
      local tests = require("game.tests." .. name)
      for _, t in ipairs(tests) do
        local ok, err = pcall(t[2])
        if not ok then error("SELFTEST FEHLER " .. name .. ": " .. t[1] .. ": " .. tostring(err), 0) end
        n = n + 1
      end
    end
  end
  log("SELFTEST OK " .. n)
  return "title"
end

-- Welt. save.ort = Ort aus area.places (start, hoftor, bruecke, laden …) oder save.cx, save.cy.
function Scenarios.welt(save)
  if save.ort or save.cx then return "world", {ort = save.ort, cx = save.cx, cy = save.cy} end
  return "world"
end

-- Ganzes Gebiet verkleinert (1 Kachel = 2 px). save.gebiet (Standard 1), save.seed.
function Scenarios.karte_ganz(save)
  return "overview", {nr = save.gebiet or 1, seed = save.seed}
end

-- Wildpferde im Sichtfeld: Start am Hof, save.cx/cy überschreiben. Pferde stehen dann nah am Spieler.
function Scenarios.wildpferde(save)
  return "world", {ort = "start", wild_nah = true}
end

-- Alle Rassen mit je drei Farben, Posen laufen durch (Seite wechselt alle 4 s).
function Scenarios.galerie()
  return "gallery"
end

-- save: der geladene Spielstand mit save.scenario. Gibt Szene und Argument zurück.
function Scenarios.start(save)
  local f = Scenarios[save.scenario]
  if type(f) ~= "function" or save.scenario == "start" then
    error("unbekanntes Szenario " .. tostring(save.scenario), 0)
  end
  return f(save)
end

return Scenarios
