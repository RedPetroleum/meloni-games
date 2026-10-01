-- Minispiel Springreiten (Aufgabe E2): Parcours von der Seite, das Pferd galoppiert von selbst, A springt.
-- Stärke → Sprunghöhe (wie beim Reiten, E30), Ausdauer → Leistungsabfall: je weiter, desto mehr schwindet
-- die Höhe (bei Ausdauer 0 bis zur Hälfte am Ende). Punkte = saubere Sprünge in % × Bindungsfaktor.
local K = require("game.katalog")
local Care = require("game.care")
local Ride = require("game.ride")

local S = {}

S.HURDLES = 10
S.SPEED = 2.2              -- Pixel je Frame
S.JUMP_FRAMES = 30         -- Dauer eines Sprungs
S.HORSE_X = 70             -- Bildschirmposition des Pferds
S.FIRST, S.GAP = 200, 105  -- Abstand des ersten Hindernisses und zwischen Hindernissen (Welt-Pixel)
S.PAUSE = 24               -- Frames Stolpern nach einem Fehler
S.END_X = S.FIRST + S.GAP * (S.HURDLES - 1) + 120

-- Höhe der Stange i (1–10): von 8 Pixeln bis zur höchsten Stange der Turnierklasse (KATALOG §13:
-- 18 + 3 × Klasse, Dorf 21, International 36). Ohne Klasse wie Land (30).
S.KLASSE = 4
S.LOW = 8

function S.top(klasse)
  local T = K.turniere
  return T.stange_basis + T.stange_klasse * (klasse or S.KLASSE)
end

function S.hurdle_height(i, klasse) return S.LOW + (i - 1) * (S.top(klasse) - S.LOW) / (S.HURDLES - 1) end

-- Sprunghöhe des Pferds d nach Ermüdung beim Fortschritt p (0–1).
function S.reach(d, p)
  local tired = (1 - Care.effective(d, "ausdauer") / 100) * 0.5 * p
  return Ride.jump_height(d) * (1 - tired)
end

function S.new(d, klasse)
  local s = {d = d, x = 0, t = 0, jump = 0, air = 0, faults = 0, clean = 0, stumble = 0, frame = 0, done = false, hurdles = {}}
  for i = 1, S.HURDLES do
    s.hurdles[i] = {x = S.FIRST + (i - 1) * S.GAP, h = S.hurdle_height(i, klasse), state = "open"}
  end
  return s
end

-- Ein Frame. press: A wurde gedrückt.
function S.update(s, press)
  if s.done then return end
  s.frame = s.frame + 1
  if s.stumble > 0 then
    s.stumble = s.stumble - 1
  else
    s.x = s.x + S.SPEED
  end
  if press and s.jump == 0 and s.stumble == 0 then s.jump = 1 end
  if s.jump > 0 then
    s.jump = s.jump + 1
    local reach = S.reach(s.d, math.min(1, s.x / S.END_X))
    s.air = math.sin(math.min(1, s.jump / S.JUMP_FRAMES) * math.pi) * reach
    if s.jump > S.JUMP_FRAMES then s.jump, s.air = 0, 0 end
  end
  for _, h in ipairs(s.hurdles) do
    if h.state == "open" and s.x >= h.x then       -- Stange erreicht: Höhe des Pferds jetzt zählt
      if s.air >= h.h then h.state, s.clean = "clean", s.clean + 1
      else h.state, s.faults, s.stumble = "down", s.faults + 1, S.PAUSE end
    end
  end
  if s.x >= S.END_X then s.done = true end
end

-- Punkte 0–100 für das Turnier (Bindung 100 → ×1, 0 → ×0,5, wie die Wertung).
function S.punkte(s)
  return s.clean / S.HURDLES * 100 * (0.5 + s.d.bindung / 200)
end

return S
