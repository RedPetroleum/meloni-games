-- Benannte Ausgangslagen zum Testen: Ein Spielstand {scenario = "name", …} startet das Spiel
-- direkt dort (tools/hoofy-test.sh schreibt so einen Spielstand und startet den Runner).
--
-- Ein Szenario ist eine Funktion(save) und gibt die Szene zurück, mit der es weitergeht
-- (Name und Argument wie in main.lua), z. B. "world".
local Scenarios = {}

-- Alle Selbsttests aus game/tests/ (Liste in game/tests/list.lua). save.only = "modul": nur dieses.
-- Loggt "SELFTEST OK <n>" oder wirft beim ersten Fehler (Runner endet mit Status 1).
function Scenarios.selftest(save)
  local modules = require("game.tests.list")
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

function Scenarios.welt()
  return "world"
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
