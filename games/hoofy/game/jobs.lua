-- Jobs (KATALOG §12): Postritt, Kutschtaxi, Pflügen. Wenig, aber sicheres Geld; trainiert nebenbei.
-- Gearbeitet wird in einem Minispiel (game/jobspiel.lua), das Ergebnis bestimmt den Lohn.
-- Ein Job pro Pferd und Tag (data.job_tag = Tag der letzten Arbeit), jeden Job gibt es einmal am Tag
-- (ctx.jobs[id] = Tag, an dem er erledigt wurde).
local K = require("game.katalog")
local H = require("game.horse_model")
local Care = require("game.care")

local J = {}

J.STAT_NAMES = {bindung = "Bindung", staerke = "Stärke", tempo = "Tempo", ausdauer = "Ausdauer", spuer = "Aufspürung"}

function J.list()
  return K.jobs.liste
end

-- Wert, den das Pferd für die Voraussetzung mitbringt (Bindung direkt, Stats als Gesamtwert).
local function have(d, key)
  if key == "bindung" then return d.bindung end
  return H.stat(d, key)
end

-- Ist der Job heute schon erledigt (von irgendeinem Pferd)?
function J.done(ctx, job, day)
  return ctx and ctx.jobs and ctx.jobs[job.id] == day or false
end

-- Darf Pferd d heute diesen Job machen? Gibt true oder false und den Grund (Text). Mit ctx zählt auch,
-- ob der Job heute schon vergeben ist.
function J.eligible(d, job, day, ctx)
  if J.done(ctx, job, day) then return false, "Job heute schon erledigt" end
  if d.job_tag == day then return false, "hat heute schon gearbeitet" end
  if have(d, job.braucht) < job.braucht_wert then
    return false, J.STAT_NAMES[job.braucht] .. " " .. job.braucht_wert .. " nötig"
  end
  if d.energie < job.energie then return false, "zu müde (Energie " .. job.energie .. ")" end
  return true
end

-- Lohn = Basis + Stat / Teiler (Gesamtwert). anteil (0–1, Ergebnis des Minispiels, Rückmeldung 1.2.1):
-- 40 % gibt es immer, den Rest nach dem Ergebnis; ohne anteil der volle Lohn.
J.LOHN_SOCKEL = 0.4

function J.lohn(d, job, anteil)
  local full = job.lohn_basis + flr(have(d, job.lohn_stat) / job.lohn_teiler)
  if not anteil then return full end
  return flr(full * (J.LOHN_SOCKEL + (1 - J.LOHN_SOCKEL) * anteil) + 0.5)
end

-- Arbeitet: Geld, Energie ab, Training. Gibt Lohn oder nil, Grund zurück.
function J.run(ctx, job, d, day, anteil)
  local ok, why = J.eligible(d, job, day, ctx)
  if not ok then return nil, why end
  local sum = J.lohn(d, job, anteil)
  ctx.money = ctx.money + sum
  ctx.jobs = ctx.jobs or {}
  ctx.jobs[job.id] = day
  d.energie = d.energie - job.energie
  d.job_tag = day
  for key, amount in pairs(job.training) do Care.train(d, key, amount) end
  return sum
end

return J
