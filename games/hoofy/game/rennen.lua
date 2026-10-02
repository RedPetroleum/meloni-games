-- Minispiel Pferderennen (Aufgabe E3): Seitenansicht, A halten = Spurt. Tempo → Höchstgeschwindigkeit,
-- Ausdauer → wie lange der Spurt hält; danach lahmt das Pferd, ohne A erholt es sich im Trab.
-- Gegner laufen mit gleichmäßigem Tempo. Im Turnier (klasse) nach festen Formeln (Rückmeldung 1.3.5): Der schnellste
-- Gegner hat Tempo R.TOP_TEMPO[klasse] und Ausdauer R.TOP_AUSDAUER[klasse], die Strecke ist so lang, dass er im
-- Dauerspurt genau seinen ganzen Vorrat verbraucht; jeder weitere ist R.NPC_ABSTAND langsamer (Vorrat reicht),
-- jeder ± R.NPC_STREUUNG zufällig, die Bahnen zufällig verteilt. Der Platz kommt direkt aus dem Rennen.
local Care = require("game.care")
local Rng = require("lib.rng")

local R = {}

R.LENGTH = 900            -- Welt-Pixel bis ins Ziel
R.BASE, R.RANGE = 1.3, 2.1 -- Geschwindigkeit in px/Frame = 1,3 + 2,1 × Wert/100 (Tempo 100 → 3,4, wie Galopp beim Reiten)
R.JOG = 0.7                -- Trab ohne Spurt (Anteil der Höchstgeschwindigkeit)
R.TIRED = 0.55             -- erschöpft (Anteil)
R.REGAIN = 0.5             -- Erholung je Frame im Trab
R.GRUEN_MIN, R.GRUEN_MAX = 170, 230  -- Ampel: Frame, an dem es grün wird (zufällig)
R.ROT = {60, 100, 140}     -- Frames, an denen die drei roten Lampen angehen
R.FEHLSTART = 45           -- Frames, die das Pferd nach Grün noch in der Box bleibt (A ab dem letzten Rot gedrückt)
R.UNRUHE = 40              -- A vor dem letzten Rot: so lange zappelt das Pferd (beruhigt sich vor Grün, ohne Strafe)
R.TOP_TEMPO = {40, 60, 80, 90, 95, 98}       -- schnellster Gegner je Klasse (Dorf … International)
R.TOP_AUSDAUER = {75, 85, 90, 95, 98, 99}
R.NPC = 5                  -- Gegner
R.NPC_ABSTAND = 3          -- Tempo-Abstand zwischen den Gegnern
R.NPC_STREUUNG = 1         -- ± Tempo zufällig je Gegner und Rennen
R.NPC_START_MIN, R.NPC_START_MAX = 12, 36    -- Gegner: zufällige Verzögerung beim Start in Frames (Reaktion)
R.REAKTION = 18            -- angenommene eigene Reaktion auf Grün (Frames) für die Aussicht

-- Geschwindigkeit für einen Wert 0–100.
function R.speed(v) return R.BASE + R.RANGE * v / 100 end

-- Spurtvorrat in Frames aus der Ausdauer: 120 + 3 × Ausdauer (Ausdauer 100 → 7 s).
function R.vorrat(ausdauer) return 120 + 3 * ausdauer end
function R.stamina(d) return R.vorrat(Care.effective(d, "ausdauer")) end

-- Streckenlänge der Klasse: der schnellste Gegner sprintet sie mit genau seinem ganzen Vorrat.
function R.laenge(klasse) return R.speed(R.TOP_TEMPO[klasse]) * R.vorrat(R.TOP_AUSDAUER[klasse]) end

-- Tempo des i-schnellsten Gegners (ohne Streuung).
function R.npc_tempo(klasse, i) return R.TOP_TEMPO[klasse] - R.NPC_ABSTAND * (i - 1) end

-- Höchstgeschwindigkeit des eigenen Pferds: Tempo × (0,5 + Bindung/200) wie die Wertung.
function R.vmax(d)
  return R.speed(Care.effective(d, "tempo") * (0.5 + d.bindung / 200))
end

-- Laufzeit in Frames mit einer Strategie: "spurt" = Spurt, solange Vorrat da ist (bestmöglich), "trab" = nie,
-- "halten" = A durchgehend gehalten (so spielen die meisten).
function R.zeit(d, strategie, length)
  local s = R.new(d, {})
  s.length = length or R.LENGTH
  while not s.done do R.update(s, strategie == "halten" or (strategie == "spurt" and s.stamina >= 1)) end
  return s.time
end

-- gegner: Stärken (0–100) der Gegner ohne klasse (Tagesform ± 10 %); rng: Zufall.
-- klasse (Turnier): Gegner und Strecke nach den Formeln oben, gegner wird nicht gebraucht.
-- ampel: Start aus der Startbox mit Ampel (Bildschirm): A ab dem letzten Rot bis Grün = Fehlstart (vorher wird das
-- Pferd nur kurz unruhig), nach Grün läuft das eigene Pferd erst mit dem ersten A los (Reaktion zählt in die Zeit).
-- Gegner: {x, v, time, nr}; nr = Rang nach Tempo (1 = schnellster), die Reihenfolge in s.rivals ist die Bahn.
function R.new(d, gegner, rng, klasse, ampel)
  rng = rng or Rng.new(1)
  local s = {d = d, x = 0, frame = 0, vmax = R.vmax(d), stamina = R.stamina(d), cap = R.stamina(d), done = false, rivals = {},
    length = klasse and R.laenge(klasse) or R.LENGTH}
  if klasse then
    s.best, s.worst = R.zeit(d, "spurt", s.length), R.zeit(d, "trab", s.length)
    for i = 1, R.NPC do
      local v = R.speed(R.npc_tempo(klasse, i) + (rng:next() * 2 - 1) * R.NPC_STREUUNG)
      local delay = rng:int(R.NPC_START_MIN, R.NPC_START_MAX)
      s.rivals[i] = {x = 0, v = v, time = delay + s.length / v, nr = i, delay = delay}
    end
    for i = #s.rivals, 2, -1 do                     -- Bahnen zufällig
      local j = rng:int(1, i)
      s.rivals[i], s.rivals[j] = s.rivals[j], s.rivals[i]
    end
  else
    for i, g in ipairs(gegner) do
      local v = R.speed(g * (1 + (rng:next() - 0.5) * 0.2))
      s.rivals[i] = {x = 0, v = v, time = s.length / v, nr = i}
    end
  end
  if ampel then s.ampel, s.pre, s.green, s.started = true, 0, rng:int(R.GRUEN_MIN, R.GRUEN_MAX), false end
  return s
end

-- Aussicht 0–3 vor dem Start aus der bestmöglichen Zeit des Pferds gegen die Gegner (mit Streuung):
-- 0 = auch gegen den langsamsten möglichen Dritten kein Podest, 1 = Platz 3–2 möglich, 2 = Sieg möglich,
-- 3 = schlägt sogar den schnellsten möglichen Ersten (mit schnellster Reaktion).
-- Eigene Zeit: A durchgehend gehalten plus R.REAKTION (realistisch statt bildgenau optimal); die Geschwindigkeit
-- kommt aus R.vmax, also Tempo × (0,5 + Bindung / 200) wie im Rennen.
function R.aussicht(d, klasse)
  local L = R.laenge(klasse)
  local best = R.zeit(d, "halten", L) + R.REAKTION
  local function t(v, delay) return L / R.speed(v) + delay end
  local v1, v3 = R.npc_tempo(klasse, 1), R.npc_tempo(klasse, 3)
  if best >= t(v3 - R.NPC_STREUUNG, R.NPC_START_MAX) then return 0 end
  if best >= t(v1 - R.NPC_STREUUNG, R.NPC_START_MAX) then return 1 end
  if best >= t(v1 + R.NPC_STREUUNG, R.NPC_START_MIN) then return 2 end
  return 3
end

-- Leistung 0–1 (nur mit klasse): 1 = bestmögliche Zeit, 0 = nur Trab oder langsamer.
function R.leistung(s)
  return math.max(0, math.min(1, (s.worst - s.time) / (s.worst - s.best)))
end

-- Ein Frame. hold: A gehalten.
function R.update(s, hold)
  if s.done then return end
  if s.ampel then
    s.pre = s.pre + 1
    if s.unruhe and s.unruhe > 0 then s.unruhe = s.unruhe - 1 end
    if s.pre < s.green then
      if hold and s.pre >= R.ROT[3] then s.fehlstart = true
      elseif hold then s.unruhe = math.min(R.UNRUHE, s.green - s.pre - 1) end
      return
    end
    s.ampel = false                             -- grün: Klappen auf
    s.stall = s.fehlstart and R.FEHLSTART or 0
  end
  s.frame = s.frame + 1
  local v
  if s.started == false then                    -- in der Box: verrannt oder noch nicht losgelaufen
    if s.stall > 0 then s.stall = s.stall - 1
    elseif hold then s.started = true end
  end
  if s.started == false then
    v = 0
  elseif hold and s.stamina > 0 then
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
  for _, r in ipairs(s.rivals) do if s.frame > (r.delay or 0) then r.x = r.x + r.v end end
  if s.x >= s.length then s.done, s.time = true, s.frame end
end

-- Platz (1 = vorn) aus den Laufzeiten.
function R.platz(s)
  local p = 1
  for _, r in ipairs(s.rivals) do if r.time < s.time then p = p + 1 end end
  return p
end

-- Punkte 0–100: erreichte Durchschnittsgeschwindigkeit als Wert (Bindung steckt schon in vmax).
function R.punkte(s)
  local v = s.length / s.time
  return math.max(0, math.min(100, (v - R.BASE) / R.RANGE * 100))
end

return R
