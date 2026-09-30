-- Schnösel im Gym: Langhantel-Curls im Studio Eitel.
-- Links/rechts: Stange ausgleichen. A: Wiederholung. B: Monster-Boost. Unten: atmen.
-- Mit jeder sauberen Wiederholung wird der Schnösel fitter: dick, pummelig, sportlich, muskulös.

local S = require("sprites")
local IMG, RECTS = S.img, S.rects
local W, H = SCREEN_W, SCREEN_H
local FITNESS_GOAL = 12
local REPS_PER_SET = 4
local SET_COUNT = 3
local HUD_H = 26
local FLOOR = 218          -- Unterkante der Schuhe
local ZOOM = 2             -- Figur pixelgenau verdoppelt
local FIG_CX = 25.5        -- Mittelachse der Figur im Sprite
local GRIP = 27            -- Abstand der Hände von der Mitte (Bildschirm)
local HAND_Y = {down = 47, mid = 39, up = 30}
local STAGES = {"fat", "chubby", "sporty", "muscle"}
local STAGE_NAMES = {"MOPPELIG", "PUMMELIG", "SPORTLICH", "MUSKELPROTZ"}

local state = "title"
local fitness, set_no, reps_in_set, combo, score, best
local form, tilt_adjust, stroke, boost_time, drinks, frame_count, flash_time
local tilt, level_up_time

local C = {
  wall = rgb(58, 66, 92), wall_dark = rgb(40, 45, 66), wall_light = rgb(78, 88, 118),
  mirror = rgb(96, 128, 150), mirror_light = rgb(150, 184, 196), mirror_dark = rgb(64, 88, 112),
  wood = rgb(176, 120, 74), wood_dark = rgb(132, 86, 54), wood_light = rgb(206, 152, 98),
  rubber = rgb(44, 46, 54), rubber_light = rgb(62, 64, 74),
  red = rgb(206, 72, 82), pink = rgb(255, 120, 170), pink_dim = rgb(140, 60, 100),
  gold = rgb(246, 206, 96), cream = rgb(248, 238, 216), ink = rgb(26, 22, 32),
  steel = rgb(176, 186, 196), steel_light = rgb(232, 236, 240), steel_dark = rgb(92, 100, 114),
  plate = rgb(52, 56, 68), plate_light = rgb(84, 90, 106),
  green = rgb(120, 214, 96), green_dark = rgb(56, 120, 66),
  energy = rgb(120, 230, 70), sweat = rgb(170, 220, 255),
  meter_bg = rgb(34, 34, 46), panel = rgb(30, 30, 44), panel_edge = rgb(70, 64, 96),
  shadow = rgb(24, 24, 32), plant = rgb(74, 150, 88), plant_dark = rgb(44, 100, 64),
  pot = rgb(226, 222, 210),
}
local STAGE_COL = {rgb(236, 120, 70), rgb(236, 180, 70), rgb(170, 214, 80), rgb(110, 224, 110)}

local function reset_run()
  fitness, set_no, reps_in_set, combo, score = 0, 1, 0, 0, 0
  form, tilt_adjust, stroke, boost_time, drinks = 100, 0, 0, 0, 2
  frame_count, flash_time, tilt, level_up_time = 0, 0, 0, 0
end

function _init()
  local save = loaddata()
  best = save and (save.best or 0) or 0
  reset_run()
end

local function stage_of(fit)
  return min(4, flr(fit / 3) + 1)
end

local function finish(won)
  state = won and "win" or "over"
  if score > best then
    best = score
    savedata({best = best})
  end
  if won then tune("C5 E5 G5 C6:2", 175, "triangle", 0.32)
  else tone(note("C3"), 0.25, "triangle", 0.3) end
end

local function start_run()
  reset_run()
  state = "play"
  tone(note("C5"), 0.1, "triangle", 0.3)
end

local function start_next_set()
  if set_no >= SET_COUNT then finish(true); return end
  set_no = set_no + 1
  reps_in_set = 0
  stroke = 0
  tilt_adjust = 0
  state = "play"
  tune("C4 E4 G4", 180, "triangle", 0.18)
end

local function lift_window()
  local period = max(104, 166 - (set_no - 1) * 17 - (boost_time > 0 and 28 or 0))
  local phase = (stroke % period) / period
  return phase, phase >= 0.44 and phase <= 0.57
end

function _update()
  if level_up_time > 0 then level_up_time = level_up_time - 1 end
  if state == "title" then
    frame_count = frame_count + 1
    if btnp(BTN_START) or btnp(BTN_A) then start_run() end
    return
  elseif state == "over" or state == "win" then
    frame_count = frame_count + 1
    if btnp(BTN_START) or btnp(BTN_A) then start_run() end
    return
  elseif state == "rest" then
    frame_count = frame_count + 1
    if btn(BTN_DOWN) then form = min(100, form + 0.32) end
    if btnp(BTN_B) and drinks > 0 then
      drinks = drinks - 1
      form = min(100, form + 23)
      boost_time = 180
      tone(note("E5"), 0.12, "square", 0.2)
    end
    if btnp(BTN_A) or btnp(BTN_START) then start_next_set() end
    return
  end

  frame_count = frame_count + 1
  stroke = stroke + 1
  if boost_time > 0 then boost_time = boost_time - 1 end
  if flash_time > 0 then flash_time = flash_time - 1 end
  form = max(0, form - 0.014)
  if btn(BTN_DOWN) then
    form = min(100, form + 0.19)
    tilt_adjust = tilt_adjust * 0.94
  end

  -- Gewichte schwingen von selbst. Gegenlenken links/rechts dämpft den Ausschlag.
  if btn(BTN_LEFT) then tilt_adjust = max(-25, tilt_adjust - 1.15)
  elseif btn(BTN_RIGHT) then tilt_adjust = min(25, tilt_adjust + 1.15)
  else tilt_adjust = tilt_adjust * 0.985 end

  if btnp(BTN_B) and drinks > 0 and boost_time <= 0 then
    drinks = drinks - 1
    form = min(100, form + 22)
    boost_time = 180
    tilt_adjust = tilt_adjust + (tilt_adjust >= 0 and 5 or -5)
    tone(note("G4"), 0.1, "square", 0.21)
  end

  local wobble_power = 10 + (set_no - 1) * 6
  local shake = boost_time > 0 and 1.75 or 1
  tilt = (math.sin(frame_count * 0.047 + fitness * 0.61) * wobble_power
    + math.sin(frame_count * 0.113 + 1.7) * 4 + tilt_adjust) * shake

  if btnp(BTN_A) then
    local _, in_window = lift_window()
    if in_window and abs(tilt) < 19 + (form < 30 and -5 or 0) then
      local old_stage = stage_of(fitness)
      fitness = fitness + 1
      reps_in_set = reps_in_set + 1
      combo = combo + 1
      score = score + 100 + min(250, combo * 18) + max(0, 12 - flr(abs(tilt))) * 3
      form = max(0, form - 1.1)
      stroke = 0
      flash_time = 18
      if stage_of(fitness) > old_stage then
        level_up_time = 90
        tune("E5 G5 C6", 240, "square", 0.18, false, 6)
      else
        tone(note("E5"), 0.07, "triangle", 0.2)
      end
      if reps_in_set >= REPS_PER_SET then
        if set_no >= SET_COUNT then finish(true)
        else state = "rest"; tune("C5 G5", 180, "triangle", 0.22) end
      end
    else
      combo = 0
      form = max(0, form - (in_window and 17 or 12))
      tilt_adjust = tilt_adjust + (tilt >= 0 and 9 or -9)
      flash_time = 28
      tone(note("C3"), 0.13, "noise", 0.2)
    end
  end
  if form <= 0 then finish(false) end
end

-- ------------------------------------------------------------------ Zeichnen

local function print_c(text, y, col, scale)
  print(text, flr((W - textw(text, scale)) / 2), y, col, scale)
end

local function print_shadow(text, y, col, scale)
  local x = flr((W - textw(text, scale)) / 2)
  print(text, x + 1, y + 1, C.ink, scale)
  print(text, x, y, col, scale)
end

local function draw_room()
  -- Rückwand mit Paneelen und Deckenlicht
  rectfill(0, HUD_H, W - 1, 150, C.wall)
  rectfill(0, HUD_H, W - 1, HUD_H + 5, C.wall_dark)
  for x = 0, W, 40 do rectfill(x, HUD_H + 6, x + 1, 150, C.wall_dark) end
  -- Neon-Schild
  rectfill(96, 32, 223, 49, C.ink)
  rect(97, 33, 222, 48, C.pink_dim)
  local blink = (frame_count % 180) < 170
  print("STUDIO EITEL", 112, 37, blink and C.pink or C.pink_dim)
  -- Große Spiegelwand hinter der Figur
  rectfill(36, 56, 283, 150, C.ink)
  rectfill(39, 59, 280, 150, C.mirror)
  rectfill(39, 59, 280, 62, C.mirror_light)
  for x = 99, 220, 60 do rectfill(x, 59, x + 1, 150, C.mirror_dark) end
  for i = 0, 3 do
    local x = 52 + i * 60
    for k = 0, 2 do
      local px = x + k * 5
      for y = 70, 100, 2 do pset(px + (y - 70) / 3, y, C.mirror_light) end
    end
  end
  -- Boden: Gummimatten außen, Holz-Plattform in der Mitte
  rectfill(0, 150, W - 1, H - 1, C.rubber)
  for y = 158, H, 14 do rectfill(0, y, W - 1, y, C.rubber_light) end
  rectfill(0, 150, W - 1, 152, C.shadow)
  for y = 153, H - 1, 1 do
    local p = (y - 153) / (H - 153)
    local half = flr(84 + p * 40)
    rectfill(160 - half, y, 160 + half, y, C.wood)
  end
  for i = -3, 3 do
    line(160 + i * 24, 153, 160 + i * 34, H - 1, C.wood_dark)
  end
  line(76, 153, 36, H - 1, C.wood_light)
  line(244, 153, 284, H - 1, C.wood_dark)
end

local function draw_props()
  -- Hantelständer links
  rectfill(30, 108, 33, 162, C.ink)
  rectfill(60, 108, 63, 162, C.ink)
  for i = 0, 2 do
    local y = 116 + i * 16
    rectfill(28, y, 65, y + 2, C.steel_dark)
    for k = 0, 2 do
      local x = 34 + k * 10
      rectfill(x, y - 5, x + 2, y - 1, C.plate)
      rectfill(x + 6, y - 5, x + 8, y - 1, C.plate)
      rectfill(x + 3, y - 4, x + 5, y - 2, C.steel)
    end
  end
  -- Grünpflanze im weißen Topf rechts (Schnösel-Studio eben)
  rectfill(256, 140, 280, 163, C.pot)
  rectfill(256, 140, 280, 143, C.steel_light)
  rectfill(277, 144, 280, 163, C.steel)
  for i = 0, 6 do
    local a = -2.4 + i * 0.3
    local x2, y2 = 268 + math.cos(a) * 26, 138 + math.sin(a) * 34
    line(268, 140, x2, y2, C.plant_dark)
    circfill(x2, y2, 4, C.plant)
    pset(x2 - 1, y2 - 1, C.green)
  end
end

local function draw_scene()
  draw_room()
  draw_props()
end

local function sprite2x(name, dx, dy)
  local r = RECTS[name]
  sspr(IMG, r[1], r[2], r[3], r[4], dx, dy, r[3] * ZOOM, r[4] * ZOOM)
end

local function fig_top()
  return FLOOR - 70 * ZOOM
end

local function draw_figure(name, cx, shift)
  local dx = flr(cx - ((shift or 0) + FIG_CX) * ZOOM)
  -- weicher Schatten unter den Füßen
  rectfill(cx - 46, FLOOR - 3, cx + 46, FLOOR + 2, C.wood_dark)
  rectfill(cx - 38, FLOOR - 4, cx + 38, FLOOR + 3, C.wood_dark)
  sprite2x(name, dx, fig_top())
end

local function plate_stack(x, y, dir, radius)
  -- Hantelscheiben von der Seite: schmale hohe Rechtecke, außen kleiner
  local sizes = {radius, radius, radius - 6}
  for i, r in ipairs(sizes) do
    local px = x + dir * (i - 1) * 8
    rectfill(px - 4, y - r - 1, px + 4, y + r + 1, C.ink)
    rectfill(px - 3, y - r, px + 3, y + r, i == 3 and C.red or C.plate)
    rectfill(px - 3, y - r, px - 2, y + r, i == 3 and C.pink or C.plate_light)
    rectfill(px - 3, y - 1, px + 3, y + 1, C.ink)
  end
end

local function draw_barbell(cy, ang, set_no_)
  local c, s = math.cos(ang), math.sin(ang)
  local half = 108
  local x1, y1 = 160 - c * half, cy + s * half
  local x2, y2 = 160 + c * half, cy - s * half
  -- Stange: Kontur, Stahl, Glanzlinie
  for o = -2, 2 do line(x1, y1 + o, x2, y2 + o, C.ink) end
  line(x1, y1, x2, y2, C.steel_dark)
  line(x1, y1 - 1, x2, y2 - 1, C.steel_light)
  line(x1 + c * 4, y1, x2 - c * 4, y2, C.steel)
  local radius = 15 + (set_no_ - 1) * 3
  for _, side in ipairs({-1, 1}) do
    local d = 84
    plate_stack(160 + side * c * d, cy - side * s * d, side, radius)
    -- Klemme
    local kx, ky = 160 + side * c * 78, cy - side * s * 78
    rectfill(kx - 2, ky - 4, kx + 2, ky + 4, C.ink)
    rectfill(kx - 1, ky - 3, kx + 1, ky + 3, C.red)
  end
  -- Fäuste um die Stange
  for _, side in ipairs({-1, 1}) do
    local hx, hy = 160 + side * c * GRIP, cy - side * s * GRIP
    sprite2x("fist", flr(hx - 8), flr(hy - 7))
  end
end

local function pose_for(phase)
  local u = (1 - math.cos(phase * 6.28318)) / 2
  if u < 0.3 then return "down" elseif u < 0.72 then return "mid" end
  return "up"
end

local function draw_lifter(stage, pose, tilt_deg)
  draw_figure("snoesel_" .. STAGES[stage] .. "_" .. pose, 160)
  local ang = tilt_deg * 0.3 * 0.0174533
  draw_barbell(fig_top() + HAND_Y[pose] * ZOOM + 1, ang, set_no)
end

local function draw_sweat(intensity)
  local top = fig_top()
  for i = 0, intensity - 1 do
    local t = (frame_count + i * 17) % 40
    local side = i % 2 == 0 and -1 or 1
    local x = 160 + side * (26 + i * 3)
    local y = top + 14 + t / 2
    rectfill(x, y, x + 1, y + 2, C.sweat)
    pset(x, y - 1, C.sweat)
  end
end

local function draw_boost_aura()
  local top = fig_top()
  for i = 0, 7 do
    local a = frame_count * 0.08 + i * 0.785
    local r = 62 + math.sin(frame_count * 0.2 + i) * 4
    local x, y = 160 + math.cos(a) * r, top + 80 + math.sin(a) * r * 0.9
    rectfill(x - 1, y - 1, x + 1, y + 1, C.energy)
  end
end

local function draw_can(x, y)
  local r = RECTS.monster_can
  sspr(IMG, r[1], r[2], r[3], r[4], x, y, 11, 18)
end

local function draw_hud()
  rectfill(0, 0, W - 1, HUD_H - 1, C.panel)
  rectfill(0, HUD_H - 2, W - 1, HUD_H - 1, C.panel_edge)
  print("SATZ " .. set_no .. "/" .. SET_COUNT, 6, 4, C.cream)
  print(tostring(score), 6, 14, C.gold)
  -- Wiederholungen im Satz als Kästchen
  for i = 1, REPS_PER_SET do
    local x = 112 + (i - 1) * 25
    rectfill(x, 5, x + 20, 18, C.ink)
    rectfill(x + 1, 6, x + 19, 17, i <= reps_in_set and C.gold or C.meter_bg)
    if i <= reps_in_set then rectfill(x + 2, 7, x + 18, 8, C.cream) end
  end
  for i = 1, 2 do
    if i <= drinks then draw_can(276 + (i - 1) * 16, 4)
    else rect(276 + (i - 1) * 16, 5, 286 + (i - 1) * 16, 21, C.panel_edge) end
  end
end

local function vbar(x, y0, y1, frac, col, label)
  rectfill(x - 1, y0 - 1, x + 11, y1 + 1, C.ink)
  rectfill(x, y0, x + 10, y1, C.meter_bg)
  local h = flr((y1 - y0) * mid(0, frac, 1))
  if h > 0 then
    rectfill(x, y1 - h, x + 10, y1, col)
    rectfill(x + 1, y1 - h, x + 2, y1, C.cream)
  end
  print(label, x + 5 - flr(textw(label) / 2), y1 + 5, C.cream)
end

local function draw_side_meters()
  -- Links: Form (Kraft), rechts: Fitness mit den vier Stufen
  vbar(8, 70, 196, form / 100, form < 30 and C.red or C.green, "FORM")
  local x, y0, y1 = 301, 70, 196
  rectfill(x - 1, y0 - 1, x + 11, y1 + 1, C.ink)
  rectfill(x, y0, x + 10, y1, C.meter_bg)
  local seg = (y1 - y0 + 1) / FITNESS_GOAL
  for i = 1, fitness do
    local ya, yb = flr(y1 - i * seg + 2), flr(y1 - (i - 1) * seg)
    rectfill(x + 1, ya, x + 9, yb, STAGE_COL[stage_of(i - 1)])
  end
  for k = 1, 3 do
    local y = flr(y1 - k * 3 * seg + 1)
    rectfill(x - 3, y, x + 13, y, C.ink)
  end
  print("FIT", x + 5 - flr(textw("FIT") / 2), y1 + 5, C.cream)
end

local function draw_timing(phase, in_window)
  local x0, x1, y = 60, 259, 228
  rectfill(x0 - 2, y - 2, x1 + 2, y + 9, C.ink)
  rectfill(x0, y, x1, y + 7, C.meter_bg)
  local g0, g1 = x0 + flr((x1 - x0) * 0.44), x0 + flr((x1 - x0) * 0.57)
  rectfill(g0, y, g1, y + 7, in_window and C.green or C.green_dark)
  local px = x0 + flr((x1 - x0) * phase)
  rectfill(px - 1, y - 3, px + 1, y + 10, C.cream)
  print("TAKT", 20, y, C.cream)
  print(in_window and "A!" or "", 276, y, C.green)
end

local function draw_level(t)
  -- Wasserwaage über dem Kopf zeigt die Schräglage der Stange
  local x0, x1, y = 120, 199, 62
  rectfill(x0 - 1, y - 1, x1 + 1, y + 6, C.ink)
  rectfill(x0, y, x1, y + 5, C.meter_bg)
  rectfill(146, y, 173, y + 5, C.green_dark)
  local px = 160 + flr(mid(-45, t, 45) / 45 * 38)
  local col = abs(t) < 19 and C.gold or C.red
  circfill(px, y + 2, 3, col)
  pset(px - 1, y + 1, C.cream)
end

local function draw_play()
  draw_scene()
  local phase, in_window = lift_window()
  local stage = stage_of(fitness)
  if boost_time > 0 then draw_boost_aura() end
  draw_lifter(stage, pose_for(phase), mid(-45, tilt, 45))
  if form < 45 then draw_sweat(form < 25 and 4 or 2) end
  draw_hud()
  draw_side_meters()
  draw_level(tilt)
  draw_timing(phase, in_window)
  -- Rückmeldungen erscheinen groß anstelle des Neon-Schilds
  local msg, col
  if level_up_time > 0 then msg, col = STAGE_NAMES[stage] .. "!", STAGE_COL[stage]
  elseif boost_time > 0 then msg, col = "MONSTER!", C.energy
  elseif flash_time > 0 then
    if combo > 0 then msg, col = "SAUBER!", C.green else msg, col = "WACKELIG!", C.red end
  end
  if msg then
    rectfill(56, 29, 263, 52, C.ink)
    print_shadow(msg, 33, col, 2)
  end
end

local function panel(x0, y0, x1, y1, edge)
  rectfill(x0 + 3, y0 + 3, x1 + 3, y1 + 3, C.shadow)
  rectfill(x0, y0, x1, y1, C.panel)
  rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, edge)
end

local function draw_title()
  draw_scene()
  -- Vorher / Nachher
  draw_figure("snoesel_fat_down", 92)
  draw_figure("snoesel_muscle_flex", 232, 6)
  for i = 0, 2 do
    local x = 150 + i * 8 + (frame_count // 8) % 3
    line(x, 150, x + 5, 155, C.gold); line(x + 5, 155, x, 160, C.gold)
  end
  print("VORHER", 68, 66, C.cream)
  print("NACHHER", 204, 66, C.gold)
  rectfill(0, 0, W - 1, 58, C.panel)
  rectfill(0, 57, W - 1, 58, C.panel_edge)
  print_shadow("SCHNÖSEL", 6, C.gold, 2)
  print_shadow("IM GYM", 24, C.pink, 2)
  print_c("12 saubere Curls bis zum Muskelprotz", 44, C.cream)
  rectfill(0, 219, W - 1, H - 1, C.panel)
  print_c("A IM GRÜNEN TAKT  <> BALANCE", 221, C.cream)
  print_c("B MONSTER  UNTEN ATMEN  START LOS", 231, C.green)
end

local function draw_rest()
  draw_scene()
  local stage = stage_of(fitness)
  draw_lifter(stage, "down", 0)
  draw_hud()
  draw_side_meters()
  panel(28, 28, 291, 74, C.gold)
  print_c("SATZ " .. set_no .. " GESCHAFFT!", 35, C.green)
  print_c("UNTEN: DURCHATMEN   B: MONSTER", 49, C.cream)
  print_c("A: NÄCHSTER SATZ", 62, C.gold)
end

local function draw_end(won)
  draw_scene()
  if won then
    for i = 0, 11 do
      local a = i * 0.5236 + frame_count * 0.02
      local r = 70 + (i % 2) * 12
      local x, y = 160 + math.cos(a) * r, 140 + math.sin(a) * r * 0.7
      rectfill(x - 1, y - 3, x + 1, y + 3, C.gold)
      rectfill(x - 3, y - 1, x + 3, y + 1, C.gold)
    end
    draw_figure("snoesel_muscle_flex", 160, 6)
  else
    draw_lifter(stage_of(fitness), "down", 20)
    draw_sweat(4)
  end
  panel(20, 6, 299, 74, won and C.green or C.red)
  if won then
    print_c("GESCHAFFT!", 14, C.gold, 2)
    print_c("Vom Moppel zum Muskelprotz.", 36, C.cream)
  else
    print_c("STANGE WEG!", 14, C.red, 2)
    print_c("Stufe: " .. STAGE_NAMES[stage_of(fitness)], 36, STAGE_COL[stage_of(fitness)])
  end
  print_c("PUNKTE " .. score .. "   REKORD " .. best, 50, C.gold)
  print_c("A ODER START: NOCHMAL", 62, C.cream)
end

function _draw()
  if state == "title" then draw_title()
  elseif state == "rest" then draw_rest()
  elseif state == "over" or state == "win" then draw_end(state == "win")
  else draw_play() end
end
