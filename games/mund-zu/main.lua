-- Mund zu! Laborführung im GoetheLab: Du erklärst den Besuchern die Metall-3D-Drucker, und aus den
-- Anlagen staubt Metallpulver. Laut Sicherheitsunterweisung ist der Kontakt zu vermeiden, also bloß
-- nichts davon in den Mund bekommen. Du redest aber ständig ...
-- Steuerkreuz: bewegen   A halten: Mund zu (kostet Luft)   B: pusten   START: los / Pause

local S = require("sprites")

local HUD_H = 16
local BLOW_CD = 420   -- Frames bis zum nächsten Pusten (7 s)
local FLOOR_Y = 76                      -- Oberkante des Hallenbodens (darüber die Anlage)
local PX0, PX1 = 24, SCREEN_W - 24      -- Bewegungsbereich des Kopfes (Mitte des Gesichts)
local PY0, PY1 = 116, 208
local K = 2                             -- der Kopf wird doppelt so groß gezeichnet
local MAXG = 170                        -- höchstens so viele Pulverkörner gleichzeitig
local PHASE_FRAMES = 25 * 60
local LIVES = 3
local PI = math.pi

local C = {
  hud = rgb(36, 40, 64),
  hud_line = rgb(70, 78, 120),
  text = rgb(240, 240, 248),
  dim = rgb(150, 156, 180),
  gold = rgb(255, 214, 80),
  red = rgb(232, 64, 64),
  green = rgb(110, 220, 120),
  blue = rgb(120, 180, 255),
  pink = rgb(247, 166, 200),
  black = rgb(14, 12, 20),
  floor = rgb(58, 66, 82),
  floor2 = rgb(50, 58, 72),
  wall = rgb(58, 64, 80),
  mach = rgb(214, 218, 224),
  mach2 = rgb(176, 182, 192),
  mach3 = rgb(130, 136, 148),
  panel = rgb(40, 46, 60),
  glass = rgb(26, 22, 30),
  laser = rgb(255, 140, 60),
  laser2 = rgb(255, 220, 140),
  hazard = rgb(240, 200, 40),
  puff = rgb(236, 240, 248),
  bubble = rgb(250, 250, 252),
  ink = rgb(30, 30, 44),
}

-- Pulversorten: fall = höchste Fallgeschwindigkeit, float = trudelt hin und her
local METALS = {
  st = {name = "316L", c = rgb(150, 156, 168), fall = 1.1},
  ti = {name = "Ti6Al4V", c = rgb(176, 186, 206), fall = 1.5},
  al = {name = "AlSi10Mg", c = rgb(226, 230, 236), fall = 0.6, float = true},
  cu = {name = "Kupfer", c = rgb(206, 116, 64), fall = 1.2},
  coc = {name = "CoCr", c = rgb(132, 140, 156), fall = 1.3},
  inc = {name = "Inconel", c = rgb(150, 160, 136), fall = 1.25},
}

-- Abschnitte der Führung, alle PHASE_FRAMES der nächste
local PHASES = {
  {name = "M1 Cusing", sub = "Edelstahl 316L", metals = {"st"}, every = 58, cloud = {3, 6}, src = "door"},
  {name = "EOSINT M 270", sub = "Kobaltchrom staubt mit", metals = {"st", "coc"}, every = 54, cloud = {4, 8},
    src = "door"},
  {name = "Siebstation", sub = "Es staubt von der Seite", metals = {"st", "ti"}, every = 46, cloud = {4, 7},
    src = "side"},
  {name = "AlSi10Mg", sub = "Schwebt wie Puderzucker", metals = {"al"}, every = 40, cloud = {5, 9},
    src = "wide"},
  {name = "X Line 2000 R", sub = "160 Liter Pulver!", metals = {"st", "ti", "coc"}, every = 42,
    cloud = {7, 12}, src = "wide", big = true},
  {name = "Entpacken", sub = "Alles muss raus", metals = {"st", "ti", "al", "cu", "coc", "inc"}, every = 36,
    cloud = {7, 12}, src = "mix", big = true},
}

-- Was beim Verschlucken auf dem Bildschirm steht
local LINES = {"Kontakt mit Metallpulver vermeiden!", "Das war kein Proteinpulver!",
  "316L ist kein Puderzucker!", "Unterweisung, Punkt 1: Nicht essen!", "Pulver gehört ins Pulverbett!",
  "Mmh, schmeckt nach Titan.", "FFP3 trägt man im Gesicht!", "Zählt nicht als Eisenzufuhr!",
  "Bitte nicht probieren!", "Ab jetzt bist du magnetisch."}

-- Was der Laborführer den Besuchern erzählt (dabei ist der Mund offen)
local TALK = {"Und hier sehen Sie ...", "Feiner als Mehl!", "Zwei Laser, je 1 kW!", "160 Liter Bauraum!",
  "Völlig harmlos, wenn ...", "Fragen? Ja, Sie da?", "Das ist Titan!", "Bitte nichts anfassen!",
  "Das war mal Pulver.", "Pulverbettverfahren!", "Schicht für Schicht ...", "Ganz ruhig atmen."}

-- Zurufe aus dem Team
local SHOUTS = {"Patrick: Absaugung ist an. Glaub ich.", "Jan: Wer hat die Kammer offen?",
  "Marius: Brille sitzt. Und der Mund?", "Alexander: Erdung prüfen, nicht kosten!",
  "Lukas: Der ATEX-Sauger ist voll.", "Jeremy: Ich sieb mal eben nach!",
  "Peter: Kurz die Bauplatte raus!", "Jan: Handschuhe sind auch Pflicht!",
  "Patrick: Nicht so nah ans Sieb!", "Marius: Die Gruppe wartet!"}

local state, t, save
local P, grains, pickups, parts, popups
local phase_i, phase, phase_t, spawn_t, big_t, warn_t, banner_t
local pick_t, mask_t, suck_t, paper_t, shout_t
local msg, msg_t, shake, over_t, alive
local alert, alert_t = nil, 0
local talk_text, talk_show, talk_cd

-- ---------- Helfer ----------

local function center(text, y, c)
  print(text, (SCREEN_W - textw(text)) // 2, y, c)
end

local function shadow_text(text, x, y, c)
  print(text, x + 1, y + 1, C.black)
  print(text, x, y, c)
end

local function say(text, frames)
  msg, msg_t = text, frames or 150
end

local function popup(x, y, text, c, life)
  local w = textw(text)
  x = mid(2, flr(x - w / 2), SCREEN_W - w - 2)
  y = mid(HUD_H + 2, y, SCREEN_H - 12)
  for _, p in ipairs(popups) do
    if math.abs(p.y - y) < 10 and math.abs(p.x - x) < 80 then y = p.y - 10 end
  end
  popups[#popups + 1] = {x = x, y = y, text = text, c = c or C.text, life = life or 60}
end

local function particle(x, y, vx, vy, c, life, g, w)
  if #parts >= 140 then table.remove(parts, 1) end
  parts[#parts + 1] = {x = x, y = y, vx = vx, vy = vy, c = c, life = life, g = g or 0, w = w or 2}
end

local function puffs(x, y, n, dir_y)
  for _ = 1, n do
    local a = (dir_y or -1) * PI / 2 + rnd(1.6) - 0.8
    local s = 1 + rnd(2)
    particle(x, y, math.cos(a) * s, math.sin(a) * s, C.puff, 12 + flr(rnd(12)), 0, 2)
  end
end

local function sparkle(x, y, n, colors)
  for _ = 1, n do
    local a = rnd(1) * PI * 2
    local s = 0.5 + rnd(1.6)
    particle(x, y, math.cos(a) * s, math.sin(a) * s - 0.8, rnd(colors), 25 + flr(rnd(20)), 0.06, 2)
  end
end

-- ---------- Töne ----------

local SFX = {}
function SFX.music(bpm)
  tune("C5 E5 G5 E5 F5 A5 G5:2 E5 C5 D5 F5 E5 D5 C5:2 G4 C5 E5 C5 D5 B4 C5:3 -", bpm or 150, "triangle",
    0.12, true, 7)
end
function SFX.title() tune("G4 C5 E5 G5:2 E5 C5 D5:2 B4 G4 C5:3 -", 130, "triangle", 0.14, true, 7) end
function SFX.gulp()
  tune("C3:0.3 G2:0.6", 500, "square", 0.3, false, 6)
  tone(200, 0.25, "noise", 0.2, 5)
end
function SFX.cough() tone(300 + rnd(200), 0.12, "noise", 0.25) end
function SFX.blow() tone(1200, 0.35, "noise", 0.18) end
function SFX.gasp() tune("E4:0.3 A4:0.6", 600, "saw", 0.16, false, 6) end
function SFX.sneeze_wind() tune("C5:0.5 D5:0.5 E5:0.8", 400, "triangle", 0.2, false, 6) end
function SFX.sneeze() tone(2000, 0.4, "noise", 0.35, 4) tone(120, 0.3, "square", 0.2, 5) end
function SFX.pick() tune("E6:0.25 G6:0.25 C7:0.5", 900, "triangle", 0.26, false, 6) end
function SFX.mask() tune("C6:0.3 E6:0.3 G6:0.3 C7:0.8", 700, "square", 0.22, false, 6) end
function SFX.suck() tone(180, 1.4, "noise", 0.22, 4) end
function SFX.warn() tune("A5:0.4 - A5:0.4 - A5:0.4", 500, "square", 0.2, false, 6) end
function SFX.over() tune("G4 F4 E4 D4:2 C4:4", 200, "square", 0.22, false, 7) end

-- ---------- Spieler ----------

local function new_player()
  return {x = 160, y = 190, lives = LIVES, air = 1, sneeze = 0, gasp = 0, blow = 0, blow_cd = 0, sneeze_t = 0,
    cough = 0, inv = 0, mask = 0, suck = 0, dust = {}, dust_n = 0, eaten = 0, parts = 0, score = 0,
    moving = false, bob = 0}
end

-- Wie der Mund gerade steht: "open", "gasp", "blow", "shut" oder "cough" (zu)
local function mouth()
  if P.cough > 0 then return "cough" end
  if P.sneeze_t > 27 then return "gasp" end
  if P.sneeze_t > 0 then return "shut" end
  if P.gasp > 0 then return "gasp" end
  if P.blow > 0 then return "blow" end
  if state == "play" and btn(BTN_A) and P.air > 0 then return "shut" end
  return "open"
end

local function mouth_box(m)
  if m == "open" then return 8, 6 end
  if m == "gasp" then return 11, 9 end
  if m == "blow" then return 6, 5 end
  return nil
end

local function head_hit(x, y, pad)
  local ex, ey = (x - P.x) / (20 + pad), (y - (P.y - 8)) / (24 + pad)
  return ex * ex + ey * ey < 1
end

local function start_sneeze()
  P.sneeze_t, P.sneeze = 50, 0
  SFX.sneeze_wind()
  popup(P.x, P.y - 46, "Ha ... ha ...", C.pink, 30)
end

local function swallow(g)
  P.lives = P.lives - 1
  P.eaten = P.eaten + 1
  P.inv, P.cough = 110, 60
  shake = 10
  SFX.gulp()
  for _ = 1, 10 do
    particle(P.x, P.y + 6, rnd(3) - 1.5, -rnd(2), g.m.c, 20 + flr(rnd(15)), 0.1, 2)
  end
  alert, alert_t = rnd(LINES), 130
  if P.lives <= 0 then
    state, over_t = "dying", 0
    stoptune()
    SFX.over()
  end
end

local function dust(g)
  if P.mask > 0 then
    particle(g.x, g.y, rnd(1) - 0.5, -0.5, g.m.c, 10, 0.1, 1)
    return
  end
  P.dust_n = P.dust_n + 1
  local dx, dy = flr(g.x - P.x), flr(g.y - P.y)
  if head_hit(g.x, g.y, -4) then
    if #P.dust >= 60 then table.remove(P.dust, 1) end
    P.dust[#P.dust + 1] = {x = dx, y = dy, c = g.m.c}
  end
  if P.sneeze_t == 0 and P.cough == 0 then
    P.sneeze = P.sneeze + 0.07
    if P.sneeze >= 1 then start_sneeze() end
  end
end

local function update_player()
  P.inv = math.max(0, P.inv - 1)
  P.mask = math.max(0, P.mask - 1)
  P.blow = math.max(0, P.blow - 1)
  P.blow_cd = math.max(0, P.blow_cd - 1)
  if P.cough > 0 then
    P.cough = P.cough - 1
    if P.cough % 15 == 0 then SFX.cough() end
  end
  if P.sneeze_t > 0 then
    P.sneeze_t = P.sneeze_t - 1
    if P.sneeze_t == 40 then
      SFX.sneeze()
      shake = 8
      popup(P.x, P.y - 48, "HATSCHI!", C.pink, 50)
      puffs(P.x, P.y + 6, 24, -1)
    end
  end

  local dx, dy = 0, 0
  if state == "play" then
    if btn(BTN_LEFT) then dx = dx - 1 end
    if btn(BTN_RIGHT) then dx = dx + 1 end
    if btn(BTN_UP) then dy = dy - 1 end
    if btn(BTN_DOWN) then dy = dy + 1 end
  end
  P.moving = dx ~= 0 or dy ~= 0
  if P.moving then
    if dx ~= 0 and dy ~= 0 then dx, dy = dx * 0.707, dy * 0.707 end
    local sp = P.cough > 0 and 1.0 or 1.7
    P.x = mid(PX0, P.x + dx * sp, PX1)
    P.y = mid(PY0, P.y + dy * sp, PY1)
    P.bob = P.bob + 1
  end

  -- Luft: Mund zu kostet, Mund auf füllt auf; leer heißt Luft schnappen
  local m = mouth()
  if P.gasp > 0 then
    P.gasp = P.gasp - 1
    P.air = math.min(1, P.air + 1 / 50)
  elseif m == "shut" and P.sneeze_t == 0 then
    P.air = P.air - 1 / 160
    if P.air <= 0 then
      P.air, P.gasp = 0, 50
      SFX.gasp()
      popup(P.x, P.y - 46, "*keuch*", C.blue, 40)
    end
  else
    P.air = math.min(1, P.air + 1 / 100)
  end

  if state == "play" and btnp(BTN_B) and P.blow_cd == 0 and P.air >= 0.3 and P.gasp == 0
      and P.sneeze_t == 0 and P.cough == 0 then
    P.blow, P.blow_cd, P.air = 14, BLOW_CD, P.air - 0.3
    SFX.blow()
    puffs(P.x, P.y + 4, 6, -1)
  end

  if P.suck > 0 then P.suck = P.suck - 1 end
end

-- ---------- Pulver ----------

local function spawn_cloud(x, y, n, vx0, vy0, spread)
  for _ = 1, n do
    if #grains >= MAXG then return end
    grains[#grains + 1] = {x = x + rnd(spread * 2) - spread, y = y + rnd(spread) - spread / 2,
      vx = vx0 + rnd(0.6) - 0.3, vy = vy0 + rnd(0.4), m = METALS[rnd(phase.metals)],
      s = rnd(1) < 0.25 and 3 or 2, ph = rnd(6.28)}
  end
end

local function spawn_from(src)
  local n = phase.cloud[1] + flr(rnd(phase.cloud[2] - phase.cloud[1] + 1))
  if src == "mix" then src = rnd({"door", "side", "wide"}) end
  if src == "side" then
    local left = rnd(1) < 0.5
    local y = FLOOR_Y + 14 + rnd(60)
    spawn_cloud(left and -4 or SCREEN_W + 4, y, n, (left and 1 or -1) * (1.2 + rnd(1.2)), -0.3, 5)
  else
    local x
    if src == "door" then x = 160 + rnd(120) - 60 else x = 20 + rnd(SCREEN_W - 40) end
    -- manche Wolken zielen grob auf den Kopf
    local aim = rnd(1) < 0.3 + math.min(phase_i, 6) * 0.03 and 1 or rnd(1) * 0.5
    spawn_cloud(x, FLOOR_Y - 2, n, (P.x - x) * 0.006 * aim, 0.3, 6)
  end
end

local function update_grains()
  local m = mouth()
  local mw, mh = mouth_box(m)
  local mx, my = P.x, P.y + 6
  local blast = P.sneeze_t <= 40 and P.sneeze_t > 28
  local nx, ny = P.x + 34, P.y        -- Saugrohr
  for i = #grains, 1, -1 do
    local g = grains[i]
    local remove = false
    if P.suck > 0 then
      local dx, dy = nx - g.x, ny - g.y
      local d = math.sqrt(dx * dx + dy * dy) + 0.01
      g.vx, g.vy = dx / d * 4.5, dy / d * 4.5
      if d < 6 then remove = true end
    else
      g.vy = math.min(g.vy + 0.025, g.m.fall)
      if g.m.float then
        g.vx = g.vx * 0.98 + math.sin(t * 0.05 + g.ph) * 0.03
      else
        g.vx = g.vx * 0.995
      end
      if P.blow > 0 or blast then
        local dx, dy = g.x - mx, g.y - my
        local d = math.sqrt(dx * dx + dy * dy) + 0.01
        local r = blast and 130 or 50
        if d < r and (blast or dy < 24) then
          local f = blast and 1.1 or 0.25
          g.vx = mid(-4, g.vx + dx / d * f, 4)
          g.vy = mid(-4, g.vy + dy / d * f - (blast and 0 or 0.06), 4)
        end
      end
    end
    g.x, g.y = g.x + g.vx, g.y + g.vy

    if not remove and P.suck == 0 and state == "play" then
      local dx, dy = g.x - mx, g.y - my
      if mw and math.abs(dx) < mw and math.abs(dy) < mh then
        if P.inv > 0 or P.mask > 0 or P.sneeze_t > 0 then dust(g) else swallow(g) end
        remove = true
      elseif not g.face and head_hit(g.x, g.y, 0) then
        -- das Pulver rieselt vor dem Gesicht herunter, ein Teil bleibt kleben
        g.face = true
        if rnd(1) < 0.22 then
          dust(g)
          remove = true
        end
      end
    end
    if remove or g.y > SCREEN_H + 4 or g.y < FLOOR_Y - 60 or g.x < -30 or g.x > SCREEN_W + 30 then
      table.remove(grains, i)
    end
  end
end

-- ---------- Fundsachen ----------

local PICK_NAMES = {part = "p_part", mask = "p_mask", sauger = "p_sauger", paper = "p_paper"}

local function spawn_pickup(kind)
  pickups[#pickups + 1] = {kind = kind, x = 30 + rnd(SCREEN_W - 60), y = FLOOR_Y - 4, ph = rnd(6.28)}
end

local function collect(p)
  local x, y = p.x, p.y
  if p.kind == "part" then
    P.parts = P.parts + 1
    SFX.pick()
    popup(x, y - 14, "+50 Bauteil gerettet", C.gold)
    sparkle(x, y, 10, {C.gold, C.text})
  elseif p.kind == "mask" then
    P.mask = 8 * 60
    SFX.mask()
    popup(x, y - 14, "FFP3-Maske!", C.green)
    sparkle(x, y, 14, {C.green, C.text})
  elseif p.kind == "sauger" then
    P.suck = 100
    SFX.suck()
    popup(x, y - 14, "ATEX-Sauger!", C.hazard)
  elseif p.kind == "paper" then
    P.lives = math.min(LIVES, P.lives + 1)
    SFX.pick()
    popup(x, y - 14, "Unterweisung unterschrieben!", C.green)
    sparkle(x, y, 10, {C.green, C.text})
  end
end

local function update_pickups()
  for i = #pickups, 1, -1 do
    local p = pickups[i]
    p.y = p.y + 0.55
    p.x = p.x + math.sin(t * 0.04 + p.ph) * 0.4
    if state == "play" and P.cough == 0 and head_hit(p.x, p.y, 14) then
      collect(p)
      table.remove(pickups, i)
    elseif p.y > SCREEN_H + 10 then
      table.remove(pickups, i)
    end
  end
end

-- ---------- Ablauf der Führung ----------

local function set_phase(i)
  phase_i = i
  local base = PHASES[math.min(i, #PHASES)]
  phase = {name = base.name, sub = base.sub, metals = base.metals, cloud = base.cloud, src = base.src,
    big = base.big, every = base.every}
  if i > #PHASES then
    phase.every = math.max(18, base.every - (i - #PHASES) * 3)
    phase.sub = "Noch mehr Pulver (Runde " .. (i - #PHASES + 1) .. ")"
  end
  phase_t, banner_t = PHASE_FRAMES, 150
  spawn_t, big_t, warn_t = i == 1 and 150 or 80, 6 * 60, 0
  SFX.music(140 + math.min(i, 8) * 8)
end

local function update_play()
  alive = alive + 1
  update_player()
  update_grains()
  update_pickups()

  spawn_t = spawn_t - 1
  if spawn_t <= 0 then
    spawn_from(phase.src)
    spawn_t = phase.every + flr(rnd(phase.every // 2))
  end
  if phase.big then
    if warn_t > 0 then
      warn_t = warn_t - 1
      if warn_t == 0 then
        -- die Kammer geht auf: große Wolke
        for _ = 1, 3 do spawn_cloud(160 + rnd(40) - 20, FLOOR_Y - 2, 12, rnd(3) - 1.5, 0.2, 14) end
        shake = 6
      end
    else
      big_t = big_t - 1
      if big_t <= 0 then
        big_t = (7 + flr(rnd(4))) * 60
        warn_t = 70
        SFX.warn()
        say("Achtung: Baukammer wird geöffnet!", 90)
      end
    end
  end

  pick_t = pick_t - 1
  if pick_t <= 0 then
    pick_t = (6 + flr(rnd(5))) * 60
    spawn_pickup("part")
  end
  mask_t = mask_t - 1
  if mask_t <= 0 then
    mask_t = (26 + flr(rnd(10))) * 60
    spawn_pickup("mask")
  end
  if phase_i >= 2 then
    suck_t = suck_t - 1
    if suck_t <= 0 then
      suck_t = (32 + flr(rnd(12))) * 60
      spawn_pickup("sauger")
    end
  end
  if P.lives < LIVES then
    paper_t = paper_t - 1
    if paper_t <= 0 then
      paper_t = 40 * 60
      spawn_pickup("paper")
    end
  end
  shout_t = shout_t - 1
  if shout_t <= 0 then
    shout_t = (18 + flr(rnd(10))) * 60
    say(rnd(SHOUTS), 180)
  end

  -- Geplauder: alle paar Sekunden ein Satz für die Besucher
  talk_cd = talk_cd - 1
  if talk_show > 0 then talk_show = talk_show - 1 end
  if talk_cd <= 0 then
    talk_cd = 200 + flr(rnd(140))
    talk_text, talk_show = rnd(TALK), 110
  end

  P.score = flr(alive / 6) + P.parts * 50
  phase_t = phase_t - 1
  if banner_t > 0 then banner_t = banner_t - 1 end
  if phase_t <= 0 then set_phase(phase_i + 1) end
end

local function update_fx()
  for i = #parts, 1, -1 do
    local p = parts[i]
    p.x, p.y = p.x + p.vx, p.y + p.vy
    p.vy = p.vy + p.g
    p.vx = p.vx * 0.95
    p.life = p.life - 1
    if p.life <= 0 then table.remove(parts, i) end
  end
  for i = #popups, 1, -1 do
    local p = popups[i]
    p.y = p.y - 0.4
    p.life = p.life - 1
    if p.life <= 0 then table.remove(popups, i) end
  end
  if msg_t > 0 then msg_t = msg_t - 1 end
  if alert_t > 0 then alert_t = alert_t - 1 end
  if shake > 0 then shake = shake - 1 end
end

local function new_game()
  P = new_player()
  grains, pickups, parts, popups = {}, {}, {}, {}
  alive = 0
  pick_t, mask_t, suck_t, paper_t, shout_t = 4 * 60, 14 * 60, 20 * 60, 30 * 60, 9 * 60
  talk_cd, talk_show, talk_text = 60, 0, TALK[1]
  msg, msg_t = nil, 0
  state = "play"
  set_phase(1)
  say("Willkommen zur Laborführung!", 120)
end

local function end_game()
  state = "over"
  over_t = 0
  local changed = false
  if P.score > (save.best or 0) then save.best, changed = P.score, true end
  if alive > (save.time or 0) then save.time, changed = alive, true end
  if changed then savedata(save) end
end

-- ---------- Zeichnen ----------

local function draw_floor()
  rectfill(0, FLOOR_Y, SCREEN_W - 1, SCREEN_H - 1, C.floor)
  for y = FLOOR_Y + 36, SCREEN_H - 1, 40 do line(0, y, SCREEN_W - 1, y, C.floor2) end
  for x = 20, SCREEN_W - 1, 56 do line(x, FLOOR_Y + 4, x, SCREEN_H - 1, C.floor2) end
  -- gelb-schwarze Bodenmarkierung vor der Anlage
  rectfill(0, FLOOR_Y, SCREEN_W - 1, FLOOR_Y + 3, C.black)
  for x = 0, SCREEN_W - 1, 16 do rectfill(x, FLOOR_Y, x + 7, FLOOR_Y + 3, C.hazard) end
end

local function draw_machine()
  rectfill(0, HUD_H, SCREEN_W - 1, FLOOR_Y - 1, C.wall)
  rectfill(24, HUD_H + 2, SCREEN_W - 25, FLOOR_Y - 1, C.mach)
  rectfill(24, HUD_H + 2, SCREEN_W - 25, HUD_H + 5, C.mach3)
  rectfill(24, FLOOR_Y - 5, SCREEN_W - 25, FLOOR_Y - 1, C.mach2)
  rect(24, HUD_H + 2, SCREEN_W - 25, FLOOR_Y - 1, C.mach3)
  -- Typenschild
  local name = phase and phase.name or "X Line 2000 R"
  local w = textw(name)
  rectfill(160 - w // 2 - 4, HUD_H + 8, 160 + w // 2 + 3, HUD_H + 18, C.panel)
  print(name, 160 - w // 2, HUD_H + 10, C.text)
  -- Bedienfeld links, Pulverflaschen rechts
  rectfill(36, 40, 76, 66, C.panel)
  rectfill(40, 44, 72, 54, C.blue)
  for i = 0, 3 do rectfill(40 + i * 9, 58, 45 + i * 9, 62, (t // 20 + i) % 4 == 0 and C.green or C.mach3) end
  for i = 0, 2 do
    local x = 250 + i * 14
    rectfill(x, 46, x + 9, 68, C.mach3)
    rectfill(x + 2, 42, x + 7, 46, C.mach2)
    rectfill(x + 1, 52, x + 8, 58, C.hazard)
  end
  -- Baukammer mit Sichtfenster
  local warn = warn_t and warn_t > 0
  local open = warn and warn_t < 20
  rectfill(116, 34, 204, 70, warn and (t % 10 < 5) and C.red or C.mach3)
  if open then
    rectfill(120, 38, 200, 70, C.black)
  else
    rectfill(120, 38, 200, 66, C.glass)
    -- Laser fährt über das Pulverbett
    local lx = 124 + (t * 3) % 72
    local ly = 56 + flr(math.sin(t * 0.07) * 4)
    line(lx, 40, lx, ly, C.laser)
    rectfill(lx - 1, ly, lx + 1, ly + 1, C.laser2)
    rectfill(122, 60, 198, 64, C.mach3)
  end
end

-- side: nil = automatisch, true = rechts vom Kopf, false = links
local function draw_bubble(text, x, y, c, side)
  local w = textw(text) + 6
  local right = x < SCREEN_W - w - 30
  if side ~= nil then right = side end
  local bx = right and x + 18 or x - 18 - w
  bx = mid(2, bx, SCREEN_W - w - 2)
  local by = mid(FLOOR_Y + 6, y - 50, SCREEN_H - 14)
  rectfill(bx, by, bx + w - 1, by + 11, C.bubble)
  rect(bx, by, bx + w - 1, by + 11, C.ink)
  local tx = right and bx + 4 or bx + w - 5
  line(tx, by + 11, x + (right and 10 or -10), y - 30, C.ink)
  print(text, bx + 3, by + 2, c or C.ink)
end

-- Sprite doppelt groß zeichnen; dx, dy sind die Abstände in Sprite-Pixeln zur Gesichtsmitte
local function big(name, x, y, dx, dy)
  local r = S.rects[name]
  sspr(r[5] or S.img, r[1], r[2], r[3], r[4], x + dx * K, y + dy * K, r[3] * K, r[4] * K)
end

local function draw_player()
  if P.inv > 0 and P.cough == 0 and (P.inv // 3) % 3 == 0 then return end
  local jx = P.cough > 0 and flr(rnd(3)) - 1 or 0
  local x = flr(P.x) + jx
  local y = flr(P.y) + ((P.moving and (P.bob // 8) % 2 == 1) and 1 or 0)
  big("head", x, y, -12, -15)
  local m = mouth()
  if m == "open" then
    if talk_show > 0 and (t // 6) % 2 == 1 then big("m_talk", x, y, -4, 1)
    else big("m_open", x, y, -4, 1) end
  elseif m == "gasp" then big("m_gasp", x, y, -5, 0)
  elseif m == "blow" then big("m_blow", x, y, -3, 1)
  elseif m == "shut" then big("m_shut", x, y, -4, 1)
  else big("m_cough", x, y, -4, 1) end
  if P.cough > 0 or P.sneeze_t > 0 then big("eyes_shut", x, y, -7, -6) end
  for _, d in ipairs(P.dust) do rectfill(x + d.x, y + d.y, x + d.x + 1, y + d.y + 1, d.c) end
  if P.mask > 0 and (P.mask > 90 or t % 8 < 5) then big("mask", x, y, -8, -2) end
  if P.suck > 0 then
    -- ATEX-Sauger in der Hand
    big("p_sauger", x, y, 12, -4)
  end
end

local function draw_grains()
  for _, g in ipairs(grains) do
    rectfill(g.x, g.y, g.x + g.s - 1, g.y + g.s - 1, g.m.c)
  end
end

local function draw_pickups()
  for _, p in ipairs(pickups) do
    local name = PICK_NAMES[p.kind]
    local w, h = S.size(name)
    big(name, flr(p.x), flr(p.y), -w // 2, -h // 2)
    if t % 16 < 3 then rectfill(p.x + w + 1, p.y - h - 1, p.x + w + 2, p.y - h, C.text) end
  end
end

local function draw_bar(x0, x1, f, c)
  rectfill(x0, 5, x1, 10, C.black)
  if f > 0 then rectfill(x0 + 1, 6, x0 + 1 + flr((x1 - x0 - 2) * math.min(1, f)), 9, c) end
  rect(x0, 5, x1, 10, C.hud_line)
end

local function draw_hud()
  rectfill(0, 0, SCREEN_W - 1, HUD_H - 1, C.hud)
  line(0, HUD_H - 1, SCREEN_W - 1, HUD_H - 1, C.hud_line)
  for i = 1, LIVES do
    if i <= P.lives then S.draw("life", 4 + (i - 1) * 9, 4)
    else rect(4 + (i - 1) * 9, 4, 9 + (i - 1) * 9, 10, C.hud_line) end
  end
  print("Luft", 34, 4, C.dim)
  draw_bar(68, 110, P.air, (P.gasp > 0 or P.air < 0.25) and C.red or C.blue)
  -- Pusten: dünne Linie unter der Luft, gold = bereit
  local pf = 1 - P.blow_cd / BLOW_CD
  line(68, 12, 68 + flr(42 * pf), 12, P.blow_cd == 0 and C.gold or C.dim)
  print("Nies", 118, 4, C.dim)
  draw_bar(152, 186, P.sneeze, C.pink)
  local s = "Punkte " .. P.score
  print(s, SCREEN_W - 4 - textw(s), 4, C.text)
end

local function draw_msg()
  if msg_t > 0 and msg then
    local w = textw(msg)
    local y = FLOOR_Y + 8
    rectfill((SCREEN_W - w) // 2 - 4, y - 2, (SCREEN_W + w) // 2 + 3, y + 9, C.black)
    center(msg, y, C.gold)
  end
end

local function draw_alert()
  if alert_t <= 0 or not alert then return end
  local y = 44
  rectfill(0, y - 4, SCREEN_W - 1, y + 19, C.black)
  line(0, y - 4, SCREEN_W - 1, y - 4, C.red)
  line(0, y + 19, SCREEN_W - 1, y + 19, C.red)
  font(1)
  center(alert, y, (t // 8) % 2 == 0 and C.red or C.text)
  font(0)
end

local function draw_popups()
  for _, p in ipairs(popups) do shadow_text(p.text, p.x, flr(p.y), p.c) end
end

local function draw_world()
  draw_floor()
  draw_machine()
  draw_pickups()
  draw_player()
  draw_grains()
  for _, p in ipairs(parts) do rectfill(p.x, p.y, p.x + p.w - 1, p.y + p.w - 1, p.c) end
  local m = mouth()
  if state == "play" and banner_t <= 0 then
    -- Der Satz bleibt stehen, auch wenn A oder B gedrückt wird
    local talk_right = nil
    if talk_show > 0 then
      talk_right = P.x < SCREEN_W - textw(talk_text) - 36
      draw_bubble(talk_text, P.x, P.y, nil, talk_right)
    end
    if m == "shut" and P.sneeze_t == 0 then
      local side = nil
      if talk_right ~= nil then side = not talk_right end
      draw_bubble("Mmmh!", P.x, P.y, C.ink, side)
    end
  end
  draw_popups()
end

local function draw_panel(y0, y1)
  shade(C.black, 0.55)
  rectfill(24, y0, SCREEN_W - 25, y1, C.hud)
  rect(24, y0, SCREEN_W - 25, y1, C.hud_line)
end

local function draw_banner()
  if banner_t <= 0 or state ~= "play" then return end
  local y = 112
  rectfill(0, y - 4, SCREEN_W - 1, y + 34, C.black)
  font(1)
  center("Station " .. phase_i .. ": " .. phase.name, y, C.gold)
  font(0)
  center(phase.sub, y + 22, C.dim)
end

local function verdict()
  local s = alive / 60
  if s < 25 then return "Nachschulung bei Prof. Bremen!" end
  if s < 60 then return "Unterweisung bitte nochmal lesen." end
  if s < 120 then return "Fast unterweisungskonform." end
  return "Vorbildlich! Kaum Pulver gegessen."
end

local function draw_over()
  draw_panel(40, 212)
  font(2)
  center("Pulver gegessen!", 48, C.red)
  font(0)
  center("Unterweisung nicht bestanden.", 78, C.text)
  local rows = {
    {"Durchgehalten:", (alive // 60) .. " s"},
    {"Bis Station:", phase_i .. " " .. phase.name},
    {"Bauteile gerettet:", tostring(P.parts)},
    {"Pulver im Gesicht:", P.dust_n .. " Körner"},
    {"Punkte:", tostring(P.score)},
    {"Rekord:", tostring(save.best or 0)},
  }
  for i, r in ipairs(rows) do
    print(r[1], 44, 92 + i * 12, C.dim)
    print(r[2], 192, 92 + i * 12, i == 5 and C.gold or C.text)
  end
  center(verdict(), 182, C.pink)
  if over_t > 60 and t % 40 < 28 then center("A: nochmal unterweisen lassen", 198, C.green) end
end

-- ---------- Titel ----------

local function to_title()
  state = "title"
  P = new_player()
  P.y = 210
  grains, pickups, parts, popups = {}, {}, {}, {}
  phase_i = 1
  phase = PHASES[1]
  warn_t, banner_t = 0, 0
  talk_text, talk_show, talk_cd = "Willkommen im GoetheLab!", 9999, 9999
  msg_t = 0
  SFX.title()
end

local function update_title()
  if t % 20 == 0 then spawn_cloud(30 + rnd(260), FLOOR_Y - 2, 3, rnd(0.6) - 0.3, 0.3, 6) end
  for i = #grains, 1, -1 do
    local g = grains[i]
    g.vy = math.min(g.vy + 0.025, g.m.fall)
    g.x, g.y = g.x + g.vx, g.y + g.vy
    if g.y > SCREEN_H + 4 then table.remove(grains, i) end
  end
  if btnp(BTN_START) or btnp(BTN_A) then new_game() end
end

local function draw_title()
  draw_floor()
  draw_machine()
  draw_grains()
  draw_player()
  draw_bubble(talk_text, P.x, P.y)
  rectfill(0, 0, SCREEN_W - 1, HUD_H - 1, C.hud)
  print("A Mund zu  B pusten  START Pause", 32, 4, C.dim)
  rectfill(16, 84, SCREEN_W - 17, 158, C.hud)
  rect(16, 84, SCREEN_W - 17, 158, C.hud_line)
  font(2)
  print("MUND ZU!", (SCREEN_W - textw("MUND ZU!", 2)) // 2, 88, C.gold, 2)
  font(0)
  center("Kontakt mit Metallpulver vermeiden!", 138, C.text)
  local best = save.best or 0
  if best > 0 then center("Rekord: " .. best .. " Punkte", 148, C.dim)
  elseif t % 40 < 28 then center("START oder A: Führung starten", 148, C.green) end
end

-- ---------- Ablauf ----------

function _init()
  save = loaddata() or {}
  t, shake, over_t = 0, 0, 0
  to_title()
end

function _update()
  t = t + 1
  if state == "title" then
    update_title()
  elseif state == "play" then
    if btnp(BTN_START) then
      state = "pause"
      stoptune()
    else
      update_play()
      update_fx()
    end
  elseif state == "pause" then
    if btnp(BTN_START) or btnp(BTN_A) then
      state = "play"
      SFX.music(140 + math.min(phase_i, 8) * 8)
    end
  elseif state == "dying" then
    over_t = over_t + 1
    update_player()
    update_grains()
    update_pickups()
    update_fx()
    if over_t > 70 then end_game() end
  elseif state == "over" then
    over_t = over_t + 1
    update_fx()
    if over_t > 60 and btnp(BTN_A) then to_title() end
  end
end

function _draw()
  if state == "title" then
    draw_title()
    return
  end
  if shake > 0 then camera(rnd(4) - 2, rnd(4) - 2) end
  draw_world()
  camera()
  draw_hud()
  draw_msg()
  draw_alert()
  draw_banner()
  if state == "pause" then
    draw_panel(96, 140)
    font(1)
    center("Pause", 102, C.text)
    font(0)
    center("START: weiter", 124, C.dim)
  elseif state == "over" then
    draw_over()
  end
end
