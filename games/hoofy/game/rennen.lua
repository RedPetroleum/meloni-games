-- Minispiel Pferderennen (Aufgabe E3): Seitenansicht, A halten = Spurt. Tempo → Höchstgeschwindigkeit,
-- Ausdauer → wie lange der Spurt hält; danach lahmt das Pferd, ohne A erholt es sich im Trab.
-- Gegner laufen mit gleichmäßigem Tempo aus ihrer Stärke. Punkte = erreichte Geschwindigkeit als Tempo-Wert.
local Care = require("game.care")
local Rng = require("lib.rng")

local R = {}

R.LENGTH = 900            -- Welt-Pixel bis ins Ziel
R.BASE, R.RANGE = 1.3, 2.1 -- Geschwindigkeit in px/Frame = 1,3 + 2,1 × Wert/100 (Tempo 100 → 3,4, wie Galopp beim Reiten)
R.JOG = 0.7                -- Trab ohne Spurt (Anteil der Höchstgeschwindigkeit)
R.TIRED = 0.55             -- erschöpft (Anteil)
R.REGAIN = 0.5             -- Erholung je Frame im Trab

-- Geschwindigkeit für einen Wert 0–100.
function R.speed(v) return R.BASE + R.RANGE * v / 100 end

-- Spurtvorrat in Frames aus der Ausdauer: 120 + 3 × Ausdauer (Ausdauer 100 → 7 s).
function R.stamina(d) return 120 + 3 * Care.effective(d, "ausdauer") end

-- Höchstgeschwindigkeit des eigenen Pferds: Tempo × (0,5 + Bindung/200) wie die Wertung.
function R.vmax(d)
  return R.speed(Care.effective(d, "tempo") * (0.5 + d.bindung / 200))
end

-- gegner: Stärken (0–100) der Gegner; rng: Tagesform ± 10 %.
function R.new(d, gegner, rng)
  rng = rng or Rng.new(1)
  local s = {d = d, x = 0, frame = 0, vmax = R.vmax(d), stamina = R.stamina(d), cap = R.stamina(d), done = false, rivals = {}}
  for i, g in ipairs(gegner) do
    local v = R.speed(g * (1 + (rng:next() - 0.5) * 0.2))
    s.rivals[i] = {x = 0, v = v, time = R.LENGTH / v}
  end
  return s
end

-- Ein Frame. hold: A gehalten.
function R.update(s, hold)
  if s.done then return end
  s.frame = s.frame + 1
  local v
  if hold and s.stamina > 0 then
    v = s.vmax
    s.stamina = s.stamina - 1
  elseif hold then
    v = s.vmax * R.TIRED
  else
    v = s.vmax * R.JOG
    s.stamina = math.min(s.cap, s.stamina + R.REGAIN)
  end
  s.v = v
  s.x = s.x + v
  for _, r in ipairs(s.rivals) do r.x = r.x + r.v end
  if s.x >= R.LENGTH then s.done, s.time = true, s.frame end
end

-- Platz (1 = vorn) aus den Laufzeiten.
function R.platz(s)
  local p = 1
  for _, r in ipairs(s.rivals) do if r.time < s.time then p = p + 1 end end
  return p
end

-- Punkte 0–100: erreichte Durchschnittsgeschwindigkeit als Wert (Bindung steckt schon in vmax).
function R.punkte(s)
  local v = R.LENGTH / s.time
  return math.max(0, math.min(100, (v - R.BASE) / R.RANGE * 100))
end

return R
