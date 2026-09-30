-- Jobs (KATALOG §12): Postritt, Kutschtaxi, Pflügen. Wenig, aber sicheres Geld; trainiert nebenbei.
-- Ein Job pro Pferd und Tag (data.job_tag = Tag der letzten Arbeit).
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

-- Darf Pferd d heute diesen Job machen? Gibt true oder false und den Grund (Text).
function J.eligible(d, job, day)
  if d.job_tag == day then return false, "hat heute schon gearbeitet" end
  if have(d, job.braucht) < job.braucht_wert then
    return false, J.STAT_NAMES[job.braucht] .. " " .. job.braucht_wert .. " nötig"
  end
  if d.energie < job.energie then return false, "zu müde (Energie " .. job.energie .. ")" end
  return true
end

-- Lohn = Basis + Stat / Teiler (Gesamtwert).
function J.lohn(d, job)
  return job.lohn_basis + flr(have(d, job.lohn_stat) / job.lohn_teiler)
end

-- Arbeitet: Geld, Energie ab, Training. Gibt Lohn oder nil, Grund zurück.
function J.run(ctx, job, d, day)
  local ok, why = J.eligible(d, job, day)
  if not ok then return nil, why end
  local sum = J.lohn(d, job)
  ctx.money = ctx.money + sum
  d.energie = d.energie - job.energie
  d.job_tag = day
  for key, amount in pairs(job.training) do Care.train(d, key, amount) end
  return sum
end

return J
