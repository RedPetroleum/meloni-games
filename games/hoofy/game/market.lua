-- Pferdemarkt im Dorf (E13): immer offen, wenige Pferde zum Kauf (Wert × 1,3), alle 3 Tage neu.
-- Welche Pferde es gibt, hängt vom weitesten erreichbaren Gebiet ab (Fahrzeugklasse, KATALOG §10).
local K = require("game.katalog")
local H = require("game.horse_model")
local V = require("game.value")
local Rng = require("lib.rng")

local M = {}

M.SLOTS = 4            -- so viele Pferde stehen zum Verkauf (E39)
M.CYCLE = 3            -- Tage bis zur neuen Auswahl
M.MAX_HERD = 24        -- so viele eigene Pferde höchstens (Speicher und Übersicht, KATALOG „Offene Fragen“)

-- Die Auswahl eines Zyklus: deterministisch aus Welt-Seed und Zyklus, damit sie sich nach dem Laden
-- nicht ändert. Gibt {cycle = n, horses = {Pferdedaten …}} zurück.
function M.stock(seed, cycle, max_gebiet)
  local rng = Rng.new((seed or 1) * 131 + cycle * 7 + 5)
  local horses = {}
  for i = 1, M.SLOTS do
    local g = rng:int(1, max_gebiet or 1)
    local d = H.wild({gebiet = g, rng = rng})
    d.wild = nil
    d.preis = V.kaufpreis(d)
    horses[i] = d
  end
  return {cycle = cycle, horses = horses}
end

function M.cycle_of(day)
  return (day - 1) // M.CYCLE
end

-- Sorgt dafür, dass ctx.market zum Tag passt (nach dem Laden oder beim Tageswechsel).
function M.refresh(ctx, day)
  local c = M.cycle_of(day)
  if not ctx.market or ctx.market.cycle ~= c then
    ctx.market = M.stock(ctx.seed, c, ctx.max_gebiet)
  end
  return ctx.market
end

-- Pferd i kaufen: Geld abziehen, Pferd in den Bestand (Wild:adopt legt es an die Leine).
-- Gibt true oder false, Grund ("Geld", "voll", "weg") zurück.
function M.buy(ctx, i)
  local m = ctx.market
  local d = m and m.horses[i]
  if not d then return false, "weg" end
  if #ctx.herd >= M.MAX_HERD then return false, "voll" end
  if ctx.money < d.preis then return false, "Geld" end
  ctx.money = ctx.money - d.preis
  table.remove(m.horses, i)
  d.preis = nil
  local h = ctx.wild:adopt(d)
  return true, h
end

return M
