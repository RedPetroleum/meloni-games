-- Minispiel Vorführung für den Schönheitswettbewerb (Rückmeldung 1.3.5, wie Dressur): Kommandos (Pfeile, A)
-- laufen von rechts auf den Ring zu, im Ring die passende Taste drücken. Bindung → größeres Trefferfenster,
-- die Klasse macht es schneller. Leistung = Trefferquote, zusammen mit der Wertung des Pferds (Seltenheit,
-- Sauberkeit, Schmuck, Bindung) ergibt sie die Endwertung (game/turniere.lua T.endwertung).
local Rng = require("lib.rng")

local V = {}

V.N = 12                    -- Kommandos je Vorführung
V.RING_X = 64               -- Bildschirmposition des Rings
V.START_X = 360             -- erstes Kommando (Bildschirm-x beim Start)
V.GAP_MIN, V.GAP_MAX = 46, 78
V.KEYS = {"UP", "DOWN", "LEFT", "RIGHT", "A"}
V.PERFECT, V.GOOD = 1, 0.6  -- Wert eines Treffers (perfekt: halbes Fenster)

function V.speed(klasse) return 1.1 + 0.15 * (klasse or 1) end

-- Trefferfenster in Pixeln (± um den Ring): Bindung 0 → 6, Bindung 100 → 16.
function V.window(d) return 6 + d.bindung / 10 end

function V.new(d, klasse, seed)
  local R = Rng.new(seed or 1)
  local s = {d = d, klasse = klasse, x = 0, frame = 0, cmds = {}, done = false, last = nil, last_t = 0,
    speed = V.speed(klasse), win = V.window(d)}
  local x = V.START_X
  for i = 1, V.N do
    s.cmds[i] = {key = V.KEYS[R:int(1, #V.KEYS)], x = x, score = nil}
    x = x + R:int(V.GAP_MIN, V.GAP_MAX)
  end
  return s
end

-- Bildschirm-x eines Kommandos
function V.screen_x(s, c) return c.x - s.x end

-- Ein Frame. press: gedrückte Taste ("UP" … "A") oder nil.
function V.update(s, press)
  if s.done then return end
  s.frame = s.frame + 1
  s.x = s.x + s.speed
  if s.last_t > 0 then s.last_t = s.last_t - 1 end
  -- nächstes offenes Kommando
  local c
  for _, k in ipairs(s.cmds) do if not k.score then c = k break end end
  if not c then
    if s.last_t == 0 then s.done = true end
    return
  end
  local dx = math.abs(V.screen_x(s, c) - V.RING_X)
  if press and dx <= s.win + 14 then          -- Druck kurz vor dem Fenster zählt schon (sonst Strafe ohne Sinn)
    if press == c.key and dx <= s.win then
      c.score = dx <= s.win / 2 and V.PERFECT or V.GOOD
    else
      c.score = 0
    end
    s.last, s.last_t = c, 40
  elseif V.screen_x(s, c) < V.RING_X - s.win then
    c.score = 0                                -- vorbeigelaufen
    s.last, s.last_t = c, 40
  end
end

-- Trefferquote 0–1
function V.quote(s)
  local sum = 0
  for _, c in ipairs(s.cmds) do sum = sum + (c.score or 0) end
  return sum / V.N
end

-- Leistung 0–1 = Trefferquote.
function V.leistung(s) return V.quote(s) end

-- Turnier (Rückmeldung 1.3.5, wie beim Rennen): Note = Wertung des Pferds W (game/turniere.lua T.wertung:
-- Seltenheit, Sauberkeit, Schmuck, Bindung) × (0,4 + 0,6 × Trefferquote). Der beste Gegner einer Klasse hat Note
-- V.TOP[klasse], jeder weitere V.NPC_ABSTAND weniger, jeder ± V.NPC_STREUUNG zufällig.
V.TOP = {30, 42, 55, 67, 78, 88}
V.NPC = 5
V.NPC_ABSTAND = 4
V.NPC_STREUUNG = 2
V.LOCKER = 0.75            -- Aussicht 3: schon mit 75 % Treffern vor dem besten möglichen Gegner

function V.grund(d) return require("game.turniere").wertung(d, "schoenheitswettbewerb") end
function V.note(W, quote) return W * (0.4 + 0.6 * quote) end

-- Gegner: {nr (1 = bester), note}
function V.gegner(klasse, rng)
  local out = {}
  for i = 1, V.NPC do
    out[i] = {nr = i, note = V.TOP[klasse] - V.NPC_ABSTAND * (i - 1) + (rng:next() * 2 - 1) * V.NPC_STREUUNG}
  end
  return out
end

function V.platz(note, gegner)
  local p = 1
  for _, g in ipairs(gegner) do if g.note > note then p = p + 1 end end
  return p
end

-- Aussicht 0–3 aus der bestmöglichen Note (alle Figuren getroffen): 0 = auch gegen den schwächsten möglichen
-- Dritten zu wenig, 1 = Podest möglich, 2 = Sieg möglich, 3 = mit V.LOCKER Treffern vor dem besten möglichen Ersten.
function V.aussicht(d, klasse)
  local W, top = V.grund(d), V.TOP[klasse]
  if W <= top - 2 * V.NPC_ABSTAND - V.NPC_STREUUNG then return 0 end
  if W <= top - V.NPC_STREUUNG then return 1 end
  if V.note(W, V.LOCKER) > top + V.NPC_STREUUNG then return 3 end
  return 2
end

return V
