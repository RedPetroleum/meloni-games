-- Drittmittel-Fischen: Über den Campus vor dem GoetheLab flattern Forschungsanträge. Kescher raus,
-- einfangen und im Antragsbriefkasten einreichen, bevor die Frist abläuft. Kleine Anträge (K1, K2,
-- STIPP), mittlere (ZIM, LrA, BMBF, Defense), Verbünde, goldene EU-Anträge. Rote Ablehnungen stehen
-- unter Strom.
-- Steuerkreuz: laufen   A: Kescher schwingen   B halten: rennen   START: los / Pause

local S = require("sprites")

local HUD_H = 16
local FX0, FX1 = 10, SCREEN_W - 10          -- Spielfeld (Bodenkoordinaten)
local FY0, FY1 = 52, SCREEN_H - 6
local CAP = 6                               -- so viele Anträge passen in die Mappe
local ROUND_FRAMES = 75 * 60
local BOX = {x = 148, y = 172}              -- Antragsbriefkasten (Sprite 24×28)
local BOX_FOOT = BOX.y + 24                 -- Unterkante für Tiefensortierung
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
  grass = rgb(146, 200, 104),
  grass2 = rgb(132, 188, 94),
  path = rgb(222, 204, 166),
  path2 = rgb(204, 184, 146),
  wall = rgb(206, 208, 214),
  wall2 = rgb(178, 182, 192),
  roof = rgb(92, 98, 112),
  window = rgb(112, 156, 200),
  window2 = rgb(160, 196, 228),
  window_open = rgb(40, 44, 60),
  door = rgb(120, 86, 60),
  sign = rgb(60, 66, 84),
  net = rgb(238, 240, 244),
  ring = rgb(120, 126, 140),
  handle = rgb(150, 100, 60),
  black = rgb(14, 12, 20),
  zap = rgb(255, 246, 120),
  zap2 = rgb(255, 255, 255),
  steam = rgb(240, 240, 240),
  bush = rgb(84, 150, 70),
  bush2 = rgb(104, 172, 84),
}

-- Die Antragsarten. speed in Pixeln pro Frame, flee/hunt: ab diesem Abstand fliehen/angreifen
-- labels: Förderprogramme, eins wird beim Erscheinen ausgewürfelt und beim Fangen angezeigt
local KINDS = {
  skizze = {sprite = "blatt", val = 20, speed = 0.55, r = 7, name = "Kleinantrag", col = C.text,
    labels = {"K1", "K2", "STIPP"}},
  antrag = {sprite = "antrag", val = 60, speed = 0.8, r = 7, flee = 46, flee_mul = 1.7,
    name = "Vollantrag", col = C.blue, labels = {"ZIM", "LrA", "BMBF", "Defense"}},
  verbund = {sprite = "verbund", val = 150, speed = 0.35, r = 10, hp = 2, big = true,
    name = "Verbundantrag", col = C.pink, labels = {"KoRoLas", "HyDe", "TraVer", "NDAM", "PersoLas"}},
  bescheid = {sprite = "bescheid", val = 200, speed = 1.25, r = 7, flee = 70, flee_mul = 1.6,
    life = 7 * 60, name = "EU-Antrag", col = C.gold, labels = {"EU", "Horizon", "EFRE"}},
  nein = {sprite = "nein", val = 0, speed = 0.45, r = 7, hunt = 50, life = 20 * 60, name = "Ablehnung",
    col = C.red},
}

-- Partner, die beim Verbundantrag noch fehlen
local PARTNERS = {"LLT", "ILT", "MASCOR", "Industrie", "Prof. Bremen"}

local ROUND_NAMES = {"Sommerloch", "MID-Gutschein", "Begutachtung", "Fristendspurt", "LASER.region",
  "Haushaltssperre", "Horizon Europe", "Antragsmarathon"}

local REASONS = {"Dreister Projektträger!", "Kein industrielles Interesse!",
  "Unzureichender Forschungstransfer!", "Nicht innovativ genug!", "Gutachter 2 sagt nein!",
  "Formfehler auf Seite 37!", "Thema verfehlt!", "Zu wenig Vorarbeiten!", "Budget unplausibel!",
  "Schriftgröße 11 statt 12!", "Arbeitspaket 4 fehlt!", "Bitte neu einreichen!"}
-- die drei Klassiker kommen öfter
local REASONS_TOP = {"Dreister Projektträger!", "Kein industrielles Interesse!",
  "Unzureichender Forschungstransfer!"}

local WINDOWS = {}   -- Fenster des Instituts, aus denen Anträge flattern
for i = 0, 8 do
  if i ~= 4 then WINDOWS[#WINDOWS + 1] = {x = 16 + i * 34, open = 0} end
end

local state, t, save
local P, sheets, parts, popups, coffee, flowers
local round, cfg, frames_left, banked, total, spawn_t, gold_t, coffee_t, swing_id, shake
local goal_said, card_t, msg, msg_t, lost_carry
local draw_list = {}

-- ---------- Helfer ----------

local function dist(ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  return math.sqrt(dx * dx + dy * dy)
end

local function atan2(y, x) return math.atan(y, x) end

local function wrap(a)
  while a > PI do a = a - 2 * PI end
  while a < -PI do a = a + 2 * PI end
  return a
end

local function steer(a, target, rate)
  local d = wrap(target - a)
  return a + mid(-rate, d, rate)
end

local function fmt(n)
  local s = tostring(flr(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
  if out:sub(1, 1) == "." then out = out:sub(2) end
  return out
end

-- Das Euro-Zeichen fehlt in der Schrift: als kleine Pixelgrafik (6×7, beliebig skaliert)
local EURO = {"..###.", ".#...#", "####..", ".#....", "####..", ".#...#", "..###."}
local function euro(x, y, c, sc)
  sc = sc or 1
  for r = 1, 7 do
    local row = EURO[r]
    for i = 1, 6 do
      if row:sub(i, i) == "#" then
        rectfill(x + (i - 1) * sc, y + (r - 1) * sc, x + i * sc - 1, y + r * sc - 1, c)
      end
    end
  end
end

-- "1.250 k€" in der aktuellen Schrift; sc = Größe des €-Zeichens (1 bei font 0, 2 bei font 1)
local function money_w(n, prefix, sc)
  return textw((prefix or "") .. fmt(n) .. " k") + 7 * (sc or 1)
end

local function money(n, x, y, c, sc, prefix)
  sc = sc or 1
  local x2 = print((prefix or "") .. fmt(n) .. " k", x, y, c)
  euro(x2, y + (sc == 1 and 0 or 1), c, sc)
  return x2 + 7 * sc
end

local function center(text, y, c)
  print(text, (SCREEN_W - textw(text)) // 2, y, c)
end

local function center_money(n, y, c, sc, prefix)
  money(n, (SCREEN_W - money_w(n, prefix, sc)) // 2, y, c, sc, prefix)
end

local function say(text, frames)
  msg, msg_t = text, frames or 150
end

local function popup(x, y, text, c, amount, prefix)
  y = math.max(y, HUD_H + 34)
  -- nicht über einen noch sichtbaren Text schreiben: darüber stapeln
  for _ = 1, 4 do
    local moved = false
    for _, p in ipairs(popups) do
      if math.abs(p.x - x) < 60 and math.abs(p.y - y) < 10 then
        y, moved = p.y - 10, true
      end
    end
    if not moved then break end
  end
  popups[#popups + 1] = {x = x, y = y, text = text, c = c or C.text, amount = amount, prefix = prefix,
    life = 55}
end

local function particle(p)
  if #parts >= 160 then table.remove(parts, 1) end
  parts[#parts + 1] = p
end

local function confetti(x, y, n, colors)
  for _ = 1, n do
    local a = rnd(1) * PI * 2
    local s = 0.5 + rnd(1.8)
    particle({x = x, y = y, vx = math.cos(a) * s, vy = math.sin(a) * s - 1, g = 0.06,
      c = rnd(colors), life = 30 + flr(rnd(30)), w = 2, h = 1 + flr(rnd(2))})
  end
end

local function sparks(x, y, n)
  for _ = 1, n do
    local a = rnd(1) * PI * 2
    local s = 1 + rnd(2)
    particle({x = x, y = y, vx = math.cos(a) * s, vy = math.sin(a) * s, g = 0,
      c = rnd(1) < 0.5 and C.zap or C.zap2, life = 10 + flr(rnd(12)), w = 1, h = 1})
  end
end

-- ---------- Töne ----------

local SFX = {}
function SFX.music()
  tune("G4 B4 D5 B4 C5:2 A4:2 F#4 A4 C5 A4 B4:2 G4:2 E4 G4 B4 G4 A4 C5 B4 A4 G4:3 -", 150, "triangle",
    0.12, true, 7)
end
function SFX.title() tune("D5 G5 B5:2 A5 G5 E5:2 D5:3 -", 140, "triangle", 0.15, true, 7) end
function SFX.swing() tone(500 + rnd(200), 0.07, "noise", 0.18) end
function SFX.catch() tune("E6:0.25 G6:0.25 C7:0.5", 900, "triangle", 0.28, false, 6) end
function SFX.wobble() tune("C5:0.3 C4:0.5", 700, "square", 0.2, false, 6) end
function SFX.full() tune("A4:0.4 A4:0.4", 600, "square", 0.18, false, 6) end
function SFX.gold() tune("C6:0.3 E6:0.3 G6:0.3 C7:0.3 G6:0.3 C7:1", 700, "square", 0.24, false, 6) end
function SFX.zap()
  tone(60, 0.5, "saw", 0.4, 4)
  tone(900, 0.4, "noise", 0.3, 5)
end
function SFX.submit() tune("C5:0.5 E5:0.5 G5:0.5 C6:0.5 E6:1.5", 600, "triangle", 0.3, false, 6) end
function SFX.coffee() tune("G5:0.3 B5:0.3 D6:0.8", 700, "triangle", 0.26, false, 6) end
function SFX.tick() tone(note("A5"), 0.06, "square", 0.22) end
function SFX.win() tune("C5 E5 G5 C6:2 - G5 C6:3", 300, "square", 0.22, false, 7) end
function SFX.lose() tune("G4 F4 E4 D4:2 C4:4", 200, "square", 0.22, false, 7) end

-- ---------- Spielfeld ----------

local function build_flowers()
  -- eigener kleiner Zufall, damit die Wiese immer gleich aussieht und rnd() unberührt bleibt
  local seed = 1234
  local function r(n)
    seed = (seed * 75 + 74) % 65537          -- passt in 32 Bit
    return seed / 65537 * n
  end
  local colors = {C.text, C.gold, C.pink, C.blue}
  flowers = {}
  for _ = 1, 46 do
    local x = FX0 + flr(r(FX1 - FX0))
    local y = FY0 + 4 + flr(r(FY1 - FY0 - 6))
    local c = colors[1 + flr(r(4))]
    local tuft = r(1) < 0.5
    if math.abs(x - 160) > 18 then
      flowers[#flowers + 1] = {x = x, y = y, c = c, tuft = tuft}
    end
  end
end

local function draw_ground()
  rectfill(0, HUD_H, SCREEN_W - 1, SCREEN_H - 1, C.grass)
  -- Weg vom Institut zum Briefkasten
  rectfill(150, 46, 170, BOX_FOOT + 6, C.path)
  rectfill(150, 46, 151, BOX_FOOT + 6, C.path2)
  rectfill(169, 46, 170, BOX_FOOT + 6, C.path2)
  for _, f in ipairs(flowers) do
    if f.tuft then
      line(f.x, f.y, f.x - 1, f.y - 3, C.grass2)
      line(f.x + 2, f.y, f.x + 3, f.y - 3, C.grass2)
    else
      pset(f.x, f.y - 1, f.c)
      pset(f.x - 1, f.y, f.c)
      pset(f.x + 1, f.y, f.c)
      pset(f.x, f.y + 1, f.c)
      pset(f.x, f.y, C.gold)
    end
  end
  -- Büsche in den Ecken
  circfill(14, SCREEN_H - 10, 12, C.bush)
  circfill(26, SCREEN_H - 4, 9, C.bush2)
  circfill(SCREEN_W - 14, SCREEN_H - 10, 12, C.bush)
  circfill(SCREEN_W - 26, SCREEN_H - 4, 9, C.bush2)
end

local function draw_building()
  rectfill(0, HUD_H, SCREEN_W - 1, 45, C.wall)
  rectfill(0, HUD_H, SCREEN_W - 1, HUD_H + 2, C.roof)
  rectfill(0, 44, SCREEN_W - 1, 45, C.wall2)
  local sign = "GoetheLab for Additive Manufacturing"
  local w = textw(sign)
  rectfill(158 - w // 2 - 3, 20, 162 + w // 2 + 2, 29, C.sign)
  print(sign, 160 - w // 2, 21, C.text)
  for _, win in ipairs(WINDOWS) do
    local wx = win.x
    if win.open > 0 then
      rectfill(wx, 32, wx + 15, 42, C.window_open)
      rect(wx - 1, 31, wx + 16, 43, C.wall2)
      rectfill(wx - 4, 32, wx - 1, 42, C.window2)    -- aufgeklappte Flügel
      rectfill(wx + 16, 32, wx + 19, 42, C.window2)
    else
      rectfill(wx, 32, wx + 15, 42, C.window)
      line(wx + 1, 33, wx + 5, 33, C.window2)
      line(wx + 8, 32, wx + 8, 42, C.wall2)
      rect(wx - 1, 31, wx + 16, 43, C.wall2)
    end
  end
  -- Tür in der Mitte
  rectfill(150, 31, 170, 45, C.door)
  rect(150, 31, 170, 45, C.roof)
  pset(166, 39, C.gold)
end

-- ---------- Anträge ----------

local function pick_kind()
  local r = rnd(1)
  if r < cfg.antrag then return "antrag" end
  r = r - cfg.antrag
  if r < cfg.verbund then return "verbund" end
  return "skizze"
end

local function new_sheet(kind, x, y, a)
  local k = KINDS[kind]
  local s = {kind = kind, k = k, x = x, y = y, a = a or rnd(1) * PI * 2, h = 10, ph = rnd(1) * 6.28,
    hp = k.hp or 1, life = k.life and (kind == "nein" and k.life + flr(rnd(k.life)) or k.life), knock = 0, enter = false, leaving = false, hit = -1}
  s.label = k.labels and rnd(k.labels)
  sheets[#sheets + 1] = s
  return s
end

local function spawn_sheet(kind)
  kind = kind or pick_kind()
  if rnd(1) < 0.6 then
    -- aus einem Fenster des Instituts
    local win = rnd(WINDOWS)
    win.open = 50
    local s = new_sheet(kind, win.x + 8, FY0 - 6, PI / 2 + rnd(0.8) - 0.4)
    s.enter = true
    return s
  end
  local left = rnd(1) < 0.5
  local s = new_sheet(kind, left and -10 or SCREEN_W + 10, FY0 + 20 + rnd(FY1 - FY0 - 50),
    (left and 0 or PI) + rnd(0.8) - 0.4)
  s.enter = true
  return s
end

local function sheet_size(s)
  if s.k.big then return S.size("verbund") end
  return S.size("blatt_1")
end

-- Mittelpunkt des Blatts auf dem Bildschirm (es schwebt über seinem Schatten)
local function sheet_screen(s)
  local _, hh = sheet_size(s)
  return s.x, s.y - s.h - hh / 2
end

-- Anträge zum Fangen (ohne Bewilligung) und Ablehnungen werden getrennt nachgefüllt
local function live_count()
  local n, nein = 0, 0
  for _, s in ipairs(sheets) do
    if not s.leaving then
      if s.kind == "nein" then nein = nein + 1
      elseif s.kind ~= "bescheid" then n = n + 1 end
    end
  end
  return n, nein
end

local function has_kind(kind)
  for _, s in ipairs(sheets) do
    if s.kind == kind then return true end
  end
  return false
end

local function update_sheet(s)
  local k = s.k
  local dx, dy = s.x - P.x, s.y - P.y
  local d = math.sqrt(dx * dx + dy * dy)
  local sp = k.speed * (1 + (round - 1) * 0.06)
  s.a = s.a + (rnd(1) - 0.5) * 0.18
  if not s.enter and not s.leaving then
    if k.flee and d < k.flee then
      s.a = steer(s.a, atan2(dy, dx), 0.12)
      sp = sp * k.flee_mul
    elseif k.hunt and d < k.hunt and P.inv == 0 and P.stun == 0 then
      s.a = steer(s.a, atan2(-dy, -dx), 0.06)
      sp = sp * 1.2
    end
  end
  if s.knock > 0 then
    s.knock = s.knock - 1
    sp = sp + s.knock * 0.06
  end
  if s.leaving then
    s.a = steer(s.a, s.out_a, 0.1)
    sp = math.max(sp, 1.6)
  end
  s.x = s.x + math.cos(s.a) * sp
  s.y = s.y + math.sin(s.a) * sp * 0.8
  s.h = 10 + math.sin(t * 0.08 + s.ph) * 4

  local x0, x1, y0, y1 = FX0 + 8, FX1 - 8, FY0 + 6, FY1 - 4
  if s.leaving then
    if s.x < -24 or s.x > SCREEN_W + 24 or s.y < FY0 - 30 or s.y > SCREEN_H + 30 then return false end
  elseif s.enter then
    if s.x > x0 and s.x < x1 and s.y > y0 and s.y < y1 then s.enter = false end
    -- rein ins Feld steuern, falls es außen herumtrudelt
    s.a = steer(s.a, atan2(118 + 40 - s.y, 160 - s.x), 0.03)
  else
    if s.x < x0 then s.x, s.a = x0, PI - s.a end
    if s.x > x1 then s.x, s.a = x1, PI - s.a end
    if s.y < y0 then s.y, s.a = y0, -s.a end
    if s.y > y1 then s.y, s.a = y1, -s.a end
  end
  if s.life then
    s.life = s.life - 1
    if s.life <= 0 and not s.leaving then
      s.leaving = true
      s.out_a = s.x < 160 and PI or 0
    end
  end
  return true
end

-- ---------- Forscherin ----------

local function new_player()
  return {x = 160, y = 150, dir = "down", fx = 0, fy = 1, walk = 0, moving = false, swing = 0, cool = 0,
    stun = 0, inv = 0, energy = 1, boost = 0, carry = {}}
end

local function blocked(x, y)
  return x > BOX.x - 4 and x < BOX.x + 27 and y > BOX.y + 10 and y < BOX_FOOT + 3
end

local function hand_pos()
  return P.x, P.y - 10
end

local function net_angle()
  local base = atan2(P.fy, P.fx)
  local p = 1 - P.swing / 14
  return base - 1.0 + 2.0 * p
end

local function hoop_pos()
  local hx, hy = hand_pos()
  local a = net_angle()
  return hx + math.cos(a) * 17, hy + math.sin(a) * 14
end

local function drop_carry(n)
  for _ = 1, n do
    local kind = table.remove(P.carry)
    if not kind then return end
    local s = new_sheet(kind, P.x + rnd(16) - 8, P.y + rnd(8) - 4)
    s.knock = 24
  end
end

local function zap(s)
  P.stun, P.inv = 80, 150
  local lost = math.ceil(#P.carry / 2)
  drop_carry(lost)
  shake = 12
  SFX.zap()
  sparks(P.x, P.y - 10, 24)
  local text = rnd(1) < 0.5 and rnd(REASONS_TOP) or rnd(REASONS)
  popup(P.x, P.y - 34, text, C.red)
  if lost > 0 then say("Abgelehnt! " .. lost .. " Antrag" .. (lost > 1 and "e" or "") .. " davongeflattert", 120) end
  if s then
    s.a = atan2(s.y - P.y, s.x - P.x)
    s.knock = 30
  end
end

local function catch(s, i)
  local k = s.k
  local sx, sy = sheet_screen(s)
  if s.kind == "nein" then
    zap(s)
    return
  end
  if #P.carry >= CAP then
    s.a = atan2(s.y - P.y, s.x - P.x)
    s.knock = 18
    popup(sx, sy - 10, "Mappe voll!", C.gold)
    say("Mappe voll! Ab zum Briefkasten.", 120)
    SFX.full()
    return
  end
  if s.hp > 1 then
    s.hp = s.hp - 1
    s.knock = 26
    s.a = atan2(s.y - P.y, s.x - P.x)
    popup(sx, sy - 12, rnd(PARTNERS) .. " fehlt noch!", C.pink)
    confetti(sx, sy, 6, {C.pink, C.text})
    SFX.wobble()
    return
  end
  table.remove(sheets, i)
  P.carry[#P.carry + 1] = s.kind
  popup(sx, sy - 8, nil, k.col, k.val, s.label and (s.label .. " +"))
  if s.kind == "bescheid" then
    SFX.gold()
    confetti(sx, sy, 26, {C.gold, C.text, C.zap})
    say("EU-Antrag! Schnell einreichen.", 120)
  elseif s.kind == "verbund" then
    SFX.catch()
    confetti(sx, sy, 14, {C.pink, C.text})
    popup(sx, sy - 20, "Verbund " .. (s.label or "") .. " steht!", C.pink)
  else
    SFX.catch()
    confetti(sx, sy, 8, {C.text, k.col})
  end
end

local function submit()
  local n = #P.carry
  if n == 0 then return end
  local sum = 0
  for _, kind in ipairs(P.carry) do sum = sum + KINDS[kind].val end
  local full = n >= CAP
  if full then sum = flr(sum * 1.5) end
  banked = banked + sum
  total = total + sum
  P.carry = {}
  SFX.submit()
  confetti(BOX.x + 12, BOX.y + 6, 20, {C.text, C.blue, C.gold})
  popup(BOX.x + 12, BOX.y - 6, nil, C.green, sum)
  if full then
    popup(BOX.x + 12, BOX.y - 18, "Volle Mappe x1,5!", C.gold)
  end
  if banked >= cfg.quota and not goal_said then
    goal_said = true
    say("Ziel erreicht! Alles weitere ist Bonus.", 180)
  end
end

local function update_player()
  if P.inv > 0 then P.inv = P.inv - 1 end
  if P.cool > 0 then P.cool = P.cool - 1 end
  if P.swing > 0 then P.swing = P.swing - 1 end
  if P.boost > 0 then P.boost = P.boost - 1 end
  if P.stun > 0 then
    P.stun = P.stun - 1
    P.moving = false
    return
  end

  local dx, dy = 0, 0
  if btn(BTN_LEFT) then dx = dx - 1 end
  if btn(BTN_RIGHT) then dx = dx + 1 end
  if btn(BTN_UP) then dy = dy - 1 end
  if btn(BTN_DOWN) then dy = dy + 1 end
  P.moving = dx ~= 0 or dy ~= 0
  if P.moving then
    if dx ~= 0 and dy ~= 0 then dx, dy = dx * 0.707, dy * 0.707 end
    if P.swing == 0 then
      P.fx, P.fy = dx, dy
      if math.abs(dx) > math.abs(dy) then P.dir = dx < 0 and "left" or "right"
      else P.dir = dy < 0 and "up" or "down" end
    end
    local sp = 1.25
    local running = btn(BTN_B) and (P.energy > 0.02 or P.boost > 0)
    if running then
      sp = 2.1
      if P.boost == 0 then P.energy = math.max(0, P.energy - 1 / 150) end
    end
    if P.boost > 0 then sp = sp * 1.35 end
    if P.swing > 0 then sp = sp * 0.6 end
    local nx = mid(FX0 + 6, P.x + dx * sp, FX1 - 6)
    if not blocked(nx, P.y) then P.x = nx end
    local ny = mid(FY0 + 2, P.y + dy * sp, FY1)
    if not blocked(P.x, ny) then P.y = ny end
    P.walk = P.walk + sp
    if not running then P.energy = math.min(1, P.energy + 1 / 300) end
  else
    P.energy = math.min(1, P.energy + 1 / 240)
  end

  if btnp(BTN_A) and P.cool == 0 then
    P.swing, P.cool = 14, 20
    swing_id = swing_id + 1
    SFX.swing()
  end

  -- Briefkasten erreicht?
  if #P.carry > 0 and dist(P.x, P.y, BOX.x + 12, BOX_FOOT) < 26 then submit() end
end

local function update_swing()
  if P.swing < 3 or P.swing > 12 then return end
  local hx, hy = hoop_pos()
  for i = #sheets, 1, -1 do
    local s = sheets[i]
    if s.hit ~= swing_id and not s.enter then
      local sx, sy = sheet_screen(s)
      if dist(hx, hy, sx, sy) < 6 + s.k.r and math.abs(s.y - P.y) < 26 then
        s.hit = swing_id
        catch(s, i)
        if P.stun > 0 then return end
      end
    end
  end
end

local function update_contacts()
  if P.inv > 0 or P.stun > 0 then return end
  for _, s in ipairs(sheets) do
    if s.kind == "nein" and not s.enter and math.abs(s.x - P.x) < 9 and math.abs(s.y - P.y) < 7 then
      zap(s)
      return
    end
  end
end

-- ---------- Kaffee ----------

local function update_coffee()
  if coffee then
    coffee.life = coffee.life - 1
    if coffee.life <= 0 then coffee = nil
    elseif P.stun == 0 and dist(P.x, P.y, coffee.x, coffee.y) < 11 then
      P.boost, P.energy = 6 * 60, 1
      SFX.coffee()
      popup(coffee.x, coffee.y - 16, "Koffein!", C.gold)
      coffee = nil
    end
  else
    coffee_t = coffee_t - 1
    if coffee_t <= 0 then
      coffee_t = (16 + flr(rnd(10))) * 60
      local x, y
      repeat
        x, y = FX0 + 20 + rnd(FX1 - FX0 - 40), FY0 + 20 + rnd(FY1 - FY0 - 30)
      until dist(x, y, BOX.x + 12, BOX_FOOT) > 40 and dist(x, y, P.x, P.y) > 50
      coffee = {x = x, y = y, life = 10 * 60}
    end
  end
end

-- ---------- Runden ----------

local function round_cfg(r)
  return {
    quota = 50 + 350 * r,
    pop = math.min(6 + r, 12),
    nein = math.min(1 + r, 7),
    antrag = math.min(0.2 + r * 0.04, 0.4),
    verbund = 0.12,
    gold_every = math.max(18 * 60 - r * 60, 11 * 60),
  }
end

local function round_name(r)
  return ROUND_NAMES[r] or ("Runde " .. r)
end

local function start_round(r)
  round = r
  cfg = round_cfg(r)
  P = new_player()
  sheets, parts, popups = {}, {}, {}
  coffee = nil
  frames_left = ROUND_FRAMES
  banked = 0
  spawn_t, gold_t, coffee_t = 0, cfg.gold_every // 2, 12 * 60
  goal_said = false
  msg, msg_t = nil, 0
  lost_carry = 0
  for _, win in ipairs(WINDOWS) do win.open = 0 end
  -- ein paar Anträge sind schon unterwegs
  for i = 1, cfg.pop - 3 + math.max(1, cfg.nein - 2) do
    local s = new_sheet(i <= cfg.pop - 3 and pick_kind() or "nein", FX0 + 20 + rnd(FX1 - FX0 - 40), FY0 + 10 + rnd(FY1 - FY0 - 30))
    if dist(s.x, s.y, P.x, P.y) < 50 then s.x = s.x < 160 and s.x - 50 or s.x + 50 end
    s.x = mid(FX0 + 10, s.x, FX1 - 10)
  end
  state, card_t = "card", 0
  stoptune()
end

local function new_game()
  total = 0
  start_round(1)
end

local function end_round()
  lost_carry = #P.carry
  stoptune()
  if banked >= cfg.quota then
    state, card_t = "clear", 0
    SFX.win()
  else
    state, card_t = "over", 0
    SFX.lose()
  end
  local changed = false
  if total > (save.best or 0) then save.best, changed = total, true end
  if round > (save.round or 0) then save.round, changed = round, true end
  if changed then savedata(save) end
end

local function update_play()
  update_player()
  update_swing()

  for i = #sheets, 1, -1 do
    if not update_sheet(sheets[i]) then table.remove(sheets, i) end
  end
  update_contacts()
  update_coffee()

  spawn_t = spawn_t - 1
  if spawn_t <= 0 then
    local n, nein = live_count()
    if nein < cfg.nein then
      spawn_sheet("nein")
      spawn_t = 40
    elseif n < cfg.pop then
      spawn_sheet()
      spawn_t = 40
    end
  end
  gold_t = gold_t - 1
  if gold_t <= 0 then
    gold_t = cfg.gold_every + flr(rnd(4 * 60))
    if not has_kind("bescheid") then
      spawn_sheet("bescheid")
      say("Ein EU-Antrag flattert herum!", 120)
    end
  end
  for _, win in ipairs(WINDOWS) do
    if win.open > 0 then win.open = win.open - 1 end
  end

  frames_left = frames_left - 1
  if frames_left == 30 * 60 then say("Noch 30 Sekunden bis zur Frist!", 120) end
  if frames_left <= 10 * 60 and frames_left % 60 == 0 and frames_left > 0 then SFX.tick() end
  if frames_left <= 0 then end_round() end
end

local function update_fx()
  for i = #parts, 1, -1 do
    local p = parts[i]
    p.x, p.y = p.x + p.vx, p.y + p.vy
    p.vy = p.vy + p.g
    p.vx = p.vx * 0.97
    p.life = p.life - 1
    if p.life <= 0 then table.remove(parts, i) end
  end
  for i = #popups, 1, -1 do
    local p = popups[i]
    p.y = p.y - 0.5
    p.life = p.life - 1
    if p.life <= 0 then table.remove(popups, i) end
  end
  if msg_t > 0 then msg_t = msg_t - 1 end
  if shake > 0 then shake = shake - 1 end
end

-- ---------- Zeichnen ----------

local function draw_net()
  local hx, hy = hand_pos()
  local cx, cy
  if P.swing > 0 then
    cx, cy = hoop_pos()
  else
    -- Kescher lässig über der Schulter
    local side = (P.dir == "left") and -1 or 1
    hx = P.x + 6 * side
    cx, cy = hx - 2 * side, hy - 16
  end
  line(hx, hy, cx, cy, C.handle)
  line(hx + 1, hy, cx + 1, cy, C.handle)
  circfill(cx, cy, 6, C.net)
  line(cx - 4, cy - 3, cx + 4, cy + 3, C.dim)
  line(cx - 4, cy + 3, cx + 4, cy - 3, C.dim)
  circ(cx, cy, 6, C.ring)
  circ(cx, cy, 5, C.ring)
  if P.swing > 2 and P.swing < 13 then
    -- Schwung-Streifen
    local a = net_angle() - 0.35
    local hx2, hy2 = hand_pos()
    line(hx2 + math.cos(a) * 19, hy2 + math.sin(a) * 16, hx2 + math.cos(a) * 24, hy2 + math.sin(a) * 20, C.text)
  end
end

local function draw_player()
  local frame = (P.moving and flr(P.walk / 10) % 2 == 1) and 2 or 1
  local name, flip
  if P.dir == "down" then name = "down"
  elseif P.dir == "up" then name = "up"
  else name, flip = "side", P.dir == "left" end
  local prefix = (P.stun > 0 and flr(P.stun / 4) % 2 == 0) and "zap_" or "pl_"
  if P.inv > 0 and P.stun == 0 and flr(P.inv / 3) % 3 == 0 then return end
  local net_behind = P.dir == "up" or (P.swing == 0 and P.dir ~= "down")
  if net_behind then draw_net() end
  -- Mappe auf dem Rücken wird mit jedem Antrag dicker
  S.draw(prefix .. name .. frame, P.x - 7, P.y - 19, flip)
  if not net_behind then draw_net() end
  if #P.carry > 0 then
    local bx = P.x + ((P.dir == "left") and 4 or -10)
    local by = P.y - 9
    for i, kind in ipairs(P.carry) do
      rectfill(bx, by - i * 2, bx + 6, by - i * 2 + 1, KINDS[kind].col)
      pset(bx, by - i * 2, C.black)
    end
  end
  if P.stun > 0 then
    -- Blitze
    for _ = 1, 3 do
      local a = rnd(1) * PI * 2
      local x0, y0 = P.x + math.cos(a) * 6, P.y - 10 + math.sin(a) * 9
      local x1, y1 = P.x + math.cos(a) * 14 + rnd(4) - 2, P.y - 10 + math.sin(a) * 16
      local mx, my = (x0 + x1) / 2 + rnd(6) - 3, (y0 + y1) / 2 + rnd(6) - 3
      line(x0, y0, mx, my, C.zap)
      line(mx, my, x1, y1, C.zap2)
    end
  end
  -- Puste-Leiste über dem Kopf, wenn nicht voll
  if P.energy < 0.99 and P.boost == 0 then
    rectfill(P.x - 8, P.y - 25, P.x + 8, P.y - 23, C.black)
    rectfill(P.x - 7, P.y - 24, P.x - 7 + flr(14 * P.energy), P.y - 24, P.energy > 0.25 and C.green or C.red)
  elseif P.boost > 0 then
    rectfill(P.x - 8, P.y - 25, P.x + 8, P.y - 23, C.black)
    rectfill(P.x - 7, P.y - 24, P.x - 7 + flr(14 * P.boost / 360), P.y - 24, C.gold)
  end
end

local function draw_sheet(s)
  local w, hh = sheet_size(s)
  local x = flr(s.x - w / 2)
  local y = flr(s.y - s.h - hh)
  if s.k.big then
    S.draw("verbund", x, y, flr((t + s.ph * 10) / 16) % 2 == 1)
    if s.hp > 1 and s.knock > 0 and t % 4 < 2 then rect(x - 1, y - 1, x + w, y + hh, C.pink) end
  else
    local f = flr((t + s.ph * 10) / 12) % 2 + 1
    S.draw(s.k.sprite .. "_" .. f, x, y)
  end
  if s.kind == "bescheid" then
    print("EU", x + w // 2 - 7, y - 9, C.gold)
  end
  if s.kind == "bescheid" and t % 8 < 4 then
    pset(x - 2 + flr(rnd(w + 4)), y - 2 + flr(rnd(hh + 4)), C.zap2)
  elseif s.kind == "nein" and t % 20 < 3 then
    line(x - 2, y + 3, x - 5, y + 6, C.zap)
    line(x + w + 1, y + 6, x + w + 4, y + 3, C.zap)
  end
end

local function draw_coffee(c)
  if c.life < 120 and t % 8 < 4 then return end
  S.draw("coffee", c.x - 5, c.y - 9)
  local st = (t // 6) % 3
  pset(c.x - 2, c.y - 12 - st, C.steam)
  pset(c.x + 1, c.y - 13 - (st + 1) % 3, C.steam)
end

local function by_y(a, b) return a.y < b.y end

local function draw_world()
  draw_ground()
  draw_building()
  -- Schatten zuerst
  for _, s in ipairs(sheets) do
    if s.k.big then S.draw("shadow_big", s.x - 9, s.y - 3)
    else S.draw("shadow", s.x - 6, s.y - 2) end
  end
  S.draw("shadow", P.x - 6, P.y - 2)

  local n = 0
  local function add(y, kind, obj)
    n = n + 1
    local e = draw_list[n]
    if not e then e = {} draw_list[n] = e end
    e.y, e.kind, e.obj = y, kind, obj
  end
  add(BOX_FOOT, "box")
  add(P.y, "player")
  if coffee then add(coffee.y, "coffee", coffee) end
  for _, s in ipairs(sheets) do add(s.y, "sheet", s) end
  for i = n + 1, #draw_list do draw_list[i] = nil end
  table.sort(draw_list, by_y)
  for i = 1, n do
    local e = draw_list[i]
    if e.kind == "box" then
      S.draw("box", BOX.x, BOX.y)
      local label = "Anträge"
      print(label, BOX.x + 12 - textw(label) // 2, BOX.y - 10, C.sign)
      if #P.carry > 0 and t % 30 < 20 then
        -- Pfeil zum Briefkasten
        local ax, ay = BOX.x + 12, BOX.y - 15 - (t // 6) % 3
        line(ax - 3, ay - 3, ax, ay, C.gold)
        line(ax + 3, ay - 3, ax, ay, C.gold)
      end
    elseif e.kind == "player" then draw_player()
    elseif e.kind == "coffee" then draw_coffee(e.obj)
    else draw_sheet(e.obj) end
  end

  for _, p in ipairs(parts) do
    rectfill(p.x, p.y, p.x + p.w - 1, p.y + p.h - 1, p.c)
  end
  for _, p in ipairs(popups) do
    if p.amount then
      local pre = p.prefix or "+"
      local w = money_w(p.amount, pre)
      local x = mid(2, flr(p.x - w / 2), SCREEN_W - w - 2)
      money(p.amount, x + 1, flr(p.y) + 1, C.black, 1, pre)
      money(p.amount, x, flr(p.y), p.c, 1, pre)
    else
      local w = textw(p.text)
      local x = mid(2, flr(p.x - w / 2), SCREEN_W - w - 2)
      print(p.text, x + 1, flr(p.y) + 1, C.black)
      print(p.text, x, flr(p.y), p.c)
    end
  end
end

local function draw_hud()
  rectfill(0, 0, SCREEN_W - 1, HUD_H - 1, C.hud)
  line(0, HUD_H - 1, SCREEN_W - 1, HUD_H - 1, C.hud_line)
  print("R" .. round, 4, 4, C.dim)
  -- Frist
  local secs = math.max(0, math.ceil(frames_left / 60))
  local tc = C.text
  if secs <= 10 then tc = (t % 30 < 15) and C.red or C.text end
  print(string.format("%d:%02d", secs // 60, secs % 60), 24, 4, tc)
  -- Fortschritt zum Ziel
  local bx0, bx1 = 64, 120
  rectfill(bx0, 4, bx1, 11, C.black)
  local f = math.min(1, banked / cfg.quota)
  if f > 0 then rectfill(bx0 + 1, 5, bx0 + 1 + flr((bx1 - bx0 - 2) * f), 10, f >= 1 and C.green or C.blue) end
  rect(bx0, 4, bx1, 11, C.hud_line)
  local x = print(fmt(banked), bx1 + 6, 4, banked >= cfg.quota and C.green or C.text)
  money(cfg.quota, x, 4, C.dim, 1, "/")
  -- Mappe
  for i = 1, CAP do
    local mx = SCREEN_W - 6 - (CAP - i + 1) * 7
    local kind = P.carry[i]
    if kind then
      rectfill(mx, 3, mx + 5, 12, KINDS[kind].col)
      line(mx + 1, 6, mx + 4, 6, C.dim)
      line(mx + 1, 8, mx + 4, 8, C.dim)
    else
      rect(mx, 3, mx + 5, 12, C.hud_line)
    end
  end
end

local function draw_msg()
  if msg_t > 0 and msg then
    local w = textw(msg)
    rectfill((SCREEN_W - w) // 2 - 4, HUD_H + 34, (SCREEN_W + w) // 2 + 3, HUD_H + 45, C.black)
    center(msg, HUD_H + 36, C.gold)
  end
end

local function draw_panel(y0, y1)
  shade(C.black, 0.55)
  rectfill(30, y0, SCREEN_W - 31, y1, C.hud)
  rect(30, y0, SCREEN_W - 31, y1, C.hud_line)
end

local function draw_card()
  draw_panel(60, 180)
  font(1)
  center("Runde " .. round, 70, C.dim)
  font(2)
  center(round_name(round), 88, C.gold)
  font(0)
  print("Ziel:", 76, 124, C.dim)
  money(cfg.quota, 150, 124, C.text)
  print("Frist:", 76, 136, C.dim)
  print((ROUND_FRAMES // 60) .. " Sekunden", 150, 136, C.text)
  if total > 0 then
    print("Bisher:", 76, 148, C.dim)
    money(total, 150, 148, C.text)
  end
  if t % 40 < 28 then center("A: Kescher raus!", 164, C.green) end
end

local function draw_clear()
  draw_panel(50, 196)
  font(2)
  center("Bewilligt!", 60, C.green)
  font(0)
  print("Eingereicht:", 60, 96, C.dim)
  money(banked, 180, 96, C.text)
  print("Ziel:", 60, 108, C.dim)
  money(cfg.quota, 180, 108, C.text)
  print("Drittmittel:", 60, 124, C.dim)
  money(total, 180, 124, C.gold)
  if lost_carry > 0 then
    center(lost_carry .. " Antr" .. (lost_carry > 1 and "äge" or "ag") .. " nicht eingereicht: verfallen", 144, C.red)
  else
    center("Alles rechtzeitig eingereicht.", 144, C.dim)
  end
  center("Weiter geht's: " .. round_name(round + 1), 160, C.text)
  if card_t > 40 and t % 40 < 28 then center("A: nächste Runde", 180, C.green) end
end

local function draw_over()
  draw_panel(44, 204)
  font(2)
  center("Frist verpasst!", 54, C.red)
  font(0)
  center("Die Stelle im GoetheLab läuft aus.", 84, C.text)
  print("Eingereicht:", 60, 104, C.dim)
  money(banked, 180, 104, C.text)
  print("Nötig:", 60, 116, C.dim)
  money(cfg.quota, 180, 116, C.text)
  print("Drittmittel:", 60, 132, C.dim)
  money(total, 180, 132, C.gold)
  print("Geschafft bis:", 60, 144, C.dim)
  print(round_name(round), 180, 144, C.text)
  print("Rekord:", 60, 160, C.dim)
  money(save.best or 0, 180, 160, total >= (save.best or 0) and total > 0 and C.green or C.text)
  if total > 0 and total >= (save.best or 0) then center("Neuer Rekord!", 174, C.green) end
  if card_t > 60 and t % 40 < 28 then center("A: neuer Antrag", 188, C.green) end
end

-- ---------- Titel ----------

local title_sheets

local function to_title()
  state = "title"
  title_sheets = {}
  sheets = title_sheets
  for _, kind in ipairs({"skizze", "antrag", "verbund", "bescheid", "nein", "skizze", "antrag"}) do
    local s = new_sheet(kind, 40 + rnd(240), 150 + rnd(70))
    s.leaving = false
  end
  P = new_player()
  P.x, P.y, P.dir, P.fx, P.fy = 160, 200, "right", 1, 0
  round, cfg, banked, frames_left = 1, round_cfg(1), 0, ROUND_FRAMES
  SFX.title()
end

local function update_title()
  for _, s in ipairs(sheets) do
    s.a = s.a + (rnd(1) - 0.5) * 0.18
    s.x = s.x + math.cos(s.a) * s.k.speed * 0.8
    s.y = s.y + math.sin(s.a) * s.k.speed * 0.6
    if s.x < 20 or s.x > 300 then s.a = PI - s.a s.x = mid(20, s.x, 300) end
    if s.y < 150 or s.y > 228 then s.a = -s.a s.y = mid(150, s.y, 228) end
    s.h = 10 + math.sin(t * 0.08 + s.ph) * 4
  end
  P.moving = false
  if t % 90 == 0 then P.swing = 14 end
  if P.swing > 0 then P.swing = P.swing - 1 end
  if btnp(BTN_START) or btnp(BTN_A) then new_game() end
end

local function draw_title()
  cls(C.grass)
  draw_ground()
  draw_building()
  for _, s in ipairs(sheets) do
    if s.k.big then S.draw("shadow_big", s.x - 9, s.y - 3) else S.draw("shadow", s.x - 6, s.y - 2) end
  end
  table.sort(sheets, by_y)
  for _, s in ipairs(sheets) do
    if s.y < P.y then draw_sheet(s) end
  end
  draw_player()
  for _, s in ipairs(sheets) do
    if s.y >= P.y then draw_sheet(s) end
  end

  rectfill(0, 0, SCREEN_W - 1, HUD_H - 1, C.hud)
  rectfill(20, 52, SCREEN_W - 21, 146, C.hud)
  rect(20, 52, SCREEN_W - 21, 146, C.hud_line)
  font(2)
  center("Drittmittel-", 58, C.gold)
  center("Fischen", 82, C.text)
  font(0)
  center("Drittmittel fürs GoetheLab!", 110, C.dim)
  local best = save.best or 0
  if best > 0 then
    local w = textw("Rekord: ") + money_w(best)
    local x = print("Rekord: ", (SCREEN_W - w) // 2, 122, C.dim)
    money(best, x, 122, C.gold)
  end
  if t % 40 < 28 then center("START oder A: los", 134, C.green) end
  print("A Kescher  B rennen  START Pause", 32, 4, C.dim)
end

-- ---------- Ablauf ----------

function _init()
  save = loaddata() or {}
  t, shake, swing_id = 0, 0, 0
  parts, popups = {}, {}
  msg_t = 0
  build_flowers()
  to_title()
end

function _update()
  t = t + 1
  if state == "title" then
    update_title()
  elseif state == "card" then
    card_t = card_t + 1
    if card_t > 20 and (btnp(BTN_A) or btnp(BTN_START)) or card_t > 240 then
      state = "play"
      SFX.music()
    end
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
      SFX.music()
    end
  elseif state == "clear" then
    card_t = card_t + 1
    update_fx()
    if card_t > 40 and btnp(BTN_A) then start_round(round + 1) end
  elseif state == "over" then
    card_t = card_t + 1
    update_fx()
    if card_t > 60 and btnp(BTN_A) then to_title() end
  end
end

function _draw()
  if state == "title" then
    draw_title()
    return
  end
  cls(C.grass)
  if shake > 0 then camera(rnd(4) - 2, rnd(4) - 2) end
  draw_world()
  camera()
  draw_hud()
  draw_msg()
  if state == "card" then draw_card()
  elseif state == "pause" then
    draw_panel(96, 140)
    font(1)
    center("Pause", 102, C.text)
    font(0)
    center("START: weiter", 124, C.dim)
  elseif state == "clear" then draw_clear()
  elseif state == "over" then draw_over() end
end
