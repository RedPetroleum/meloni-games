-- Minispiel Springreiten (Aufgabe E2): Parcours von der Seite, das Pferd galoppiert von selbst, A springt.
-- Stärke → Sprunghöhe (wie beim Reiten, E30), Ausdauer → Leistungsabfall: je weiter, desto mehr schwindet
-- die Höhe (bei Ausdauer 0 bis zur Hälfte am Ende). Im Turnier zählt die Leistung = Timing der Sprünge.
local K = require("game.katalog")
local Care = require("game.care")

local S = {}

S.HURDLES = 10
S.SPEED = 2.2              -- Pixel je Frame
S.JUMP_FRAMES = 30         -- Dauer eines Sprungs
S.HORSE_X = 70             -- Bildschirmposition des Pferds
S.FIRST, S.GAP = 200, 105  -- Abstand des ersten Hindernisses und zwischen Hindernissen (Welt-Pixel)
S.PAUSE = 24               -- Frames Stolpern nach einem Fehler
S.END_X = S.FIRST + S.GAP * (S.HURDLES - 1) + 120

-- Gegner im Turnier (Rückmeldung 1.3.5, wie beim Rennen): Der beste Gegner einer Klasse hat Stärke
-- S.TOP_STAERKE[klasse] und Ausdauer S.TOP_AUSDAUER[klasse] und springt mit perfektem Timing; die letzte Stange
-- ist genau so hoch, wie er dort noch kommt (die übrigen steigen gleichmäßig von S.LOW an). Jeder weitere Gegner
-- kommt S.NPC_ABSTAND (Anteil) weniger hoch, also Gegner 3 um 10 % (in jeder Klasse etwa gleich viele Fehler),
-- jeder hat ± S.NPC_STREUUNG Stärke zufällig. Gewertet wird: weniger Fehler, bei
-- Gleichstand der bessere Stil (Timing; Gegner zufällig S.NPC_STIL_MIN–MAX). Ohne Klasse wie Land.
S.KLASSE = 4
S.LOW = 8
S.TOP_STAERKE = {40, 60, 80, 90, 95, 98}
S.TOP_AUSDAUER = {75, 85, 90, 95, 98, 99}
S.NPC = 5
S.NPC_ABSTAND = 0.05       -- je Gegner 5 % weniger Sprunghöhe
S.NPC_STREUUNG = 1
S.NPC_STIL_MIN, S.NPC_STIL_MAX = 0.6, 0.9
S.LOCKER = 0.9             -- Aussicht 3: fehlerfrei sogar mit nur 90 % der Sprunghöhe (Stil schlägt jeden Gegner)

-- Sprunghöhe aus Stärke und Ausdauer beim Fortschritt p (0–1), wie beim Reiten (E30) mit Ermüdung.
function S.reach_wert(staerke, ausdauer, p)
  return (6 + 0.3 * staerke) * (1 - (1 - ausdauer / 100) * 0.5 * p)
end

function S.hurdle_x(i) return S.FIRST + (i - 1) * S.GAP end

function S.top(klasse)
  local k = klasse or S.KLASSE
  return S.reach_wert(S.TOP_STAERKE[k], S.TOP_AUSDAUER[k], S.hurdle_x(S.HURDLES) / S.END_X)
end

function S.hurdle_height(i, klasse) return S.LOW + (i - 1) * (S.top(klasse) - S.LOW) / (S.HURDLES - 1) end

-- Sprunghöhe des Pferds d nach Ermüdung beim Fortschritt p (0–1).
function S.reach(d, p)
  return S.reach_wert(Care.effective(d, "staerke"), Care.effective(d, "ausdauer"), p)
end

-- Fehler bei perfektem Timing mit q × Sprunghöhe (q = 1: technisch bestmöglich).
function S.fehler(staerke, ausdauer, klasse, q)
  local n = 0
  for i = 1, S.HURDLES do
    if (q or 1) * S.reach_wert(staerke, ausdauer, S.hurdle_x(i) / S.END_X) < S.hurdle_height(i, klasse) - 1e-6 then n = n + 1 end
  end
  return n
end

-- Gegner einer Klasse: {nr (1 = stärkster), fehler, stil}.
function S.gegner(klasse, rng)
  local out = {}
  for i = 1, S.NPC do
    local st = S.TOP_STAERKE[klasse] + (rng:next() * 2 - 1) * S.NPC_STREUUNG
    out[i] = {nr = i, fehler = S.fehler(st, S.TOP_AUSDAUER[klasse], klasse, 1 - S.NPC_ABSTAND * (i - 1)),
      stil = S.NPC_STIL_MIN + rng:next() * (S.NPC_STIL_MAX - S.NPC_STIL_MIN)}
  end
  return out
end

-- Platz des eigenen Ergebnisses (Fehler, Stil) gegen die Gegner.
function S.platz(fehler, stil, gegner)
  local p = 1
  for _, g in ipairs(gegner) do
    if g.fehler < fehler or (g.fehler == fehler and g.stil > stil) then p = p + 1 end
  end
  return p
end

-- Aussicht 0–3 aus dem technisch Möglichen (perfektes Timing): 0 = auch gegen den schwächsten möglichen
-- Dritten mehr Fehler, 1 = Podest möglich, 2 = Sieg möglich, 3 = fehlerfrei sogar mit S.LOCKER der Höhe.
function S.aussicht(d, klasse)
  local st, au = Care.effective(d, "staerke"), Care.effective(d, "ausdauer")
  local best = S.fehler(st, au, klasse)
  local A = S.TOP_AUSDAUER[klasse]
  local function npc(i) return S.fehler(S.TOP_STAERKE[klasse] - S.NPC_STREUUNG, A, klasse, 1 - S.NPC_ABSTAND * (i - 1)) end
  if best > npc(3) then return 0 end
  if best > npc(1) then return 1 end
  if S.fehler(st, au, klasse, S.LOCKER) == 0 then return 3 end
  return 2
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
      -- Timing (Leistung): wie nah am höchsten Punkt des Sprungs, unabhängig davon, wie hoch das Pferd kommt
      h.timing = s.jump > 0 and math.sin(math.min(1, s.jump / S.JUMP_FRAMES) * math.pi) or 0
      s.timing = (s.timing or 0) + h.timing
      if s.air >= h.h then h.state, s.clean = "clean", s.clean + 1
      else h.state, s.faults, s.stumble = "down", s.faults + 1, S.PAUSE end
    end
  end
  if s.x >= S.END_X then s.done = true end
end

-- Leistung 0–1 für das Turnier (game/turniere.lua T.endwertung): mittleres Timing über alle Stangen.
function S.leistung(s)
  return (s.timing or 0) / S.HURDLES
end

-- Punkte 0–100 (ohne Turnier) (Bindung 100 → ×1, 0 → ×0,5, wie die Wertung).
function S.punkte(s)
  return s.clean / S.HURDLES * 100 * (0.5 + s.d.bindung / 200)
end

return S
