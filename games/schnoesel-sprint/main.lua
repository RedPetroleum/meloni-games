-- Schnösel-Sprint: Studio Eitel — Langhantel-Balance im eigenen Schnösel-Gym.
-- Links/rechts: Stange ausgleichen. A: Wiederholung. B: Monster-Boost. Unten: atmen.

local S = require("sprites")
local IMG, RECTS = S.img, S.rects
local W, H = SCREEN_W, SCREEN_H
local FITNESS_GOAL = 12
local REPS_PER_SET = 4
local SET_COUNT = 3
local HUD_H = 34
local FLOOR = 221

local state = "title"
local fitness, set_no, reps_in_set, combo, score, best
local form, tilt_adjust, stroke, boost_time, drinks, frame_count, flash_time

local C = {
  wall = rgb(44, 53, 64), wall_dark = rgb(29, 35, 46), wall_light = rgb(76, 88, 99),
  mirror = rgb(83, 111, 119), mirror_light = rgb(131, 160, 157), mirror_dark = rgb(46, 69, 78),
  floor = rgb(75, 72, 74), floor_dark = rgb(48, 50, 57), tile = rgb(101, 91, 83),
  red = rgb(168, 67, 58), red_light = rgb(211, 102, 75), gold = rgb(235, 190, 99),
  cream = rgb(244, 229, 202), ink = rgb(32, 31, 37), steel = rgb(178, 190, 193),
  steel_light = rgb(224, 225, 207), steel_dark = rgb(82, 92, 100),
  green = rgb(131, 190, 91), green_dark = rgb(67, 119, 69),
  amber = rgb(226, 148, 66), energy = rgb(108, 204, 72),
  form_bg = rgb(53, 54, 61), skin = rgb(237, 189, 153),
  panel = rgb(38, 41, 49), shadow = rgb(31, 34, 39),
}

local api_line = line
local function line(points, color, width)
  width = width or 1
  local half = flr((width - 1) / 2)
  for j = 1, #points - 2, 2 do
    for offset = -half, half do
      api_line(points[j], points[j + 1] + offset, points[j + 2], points[j + 3] + offset, color)
    end
  end
end

local function clamp(a, b, c) return mid(a, b, c) end

local function reset_run()
  fitness, set_no, reps_in_set, combo, score = 0, 1, 0, 0, 0
  form, tilt_adjust, stroke, boost_time, drinks = 100, 0, 0, 0, 2
  frame_count, flash_time = 0, 0
end

function _init()
  local save = loaddata()
  best = save and (save.best or 0) or 0
  reset_run()
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
  if state == "title" then
    if btnp(BTN_START) or btnp(BTN_A) then start_run() end
    return
  elseif state == "over" or state == "win" then
    if btnp(BTN_START) or btnp(BTN_A) then start_run() end
    return
  elseif state == "rest" then
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
  local tilt = math.sin(frame_count * 0.047 + fitness * 0.61) * wobble_power
    + math.sin(frame_count * 0.113 + 1.7) * 4 + tilt_adjust
  tilt = tilt * shake

  if btnp(BTN_A) then
    local _, in_window = lift_window()
    if in_window and abs(tilt) < 19 + (form < 30 and -5 or 0) then
      fitness = fitness + 1
      reps_in_set = reps_in_set + 1
      combo = combo + 1
      score = score + 100 + min(250, combo * 18) + max(0, 12 - flr(abs(tilt))) * 3
      form = max(0, form - 1.1)
      stroke = 0
      flash_time = 18
      tone(note("E5"), 0.07, "triangle", 0.2)
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

local function draw_wall()
  -- Oberes Studiogeschoss mit Stahlträgern und warmen Deckenleuchten.
  rectfill(0, HUD_H, W - 1, 70, C.wall_dark)
  for x = -20, W, 52 do
    rectfill(x, HUD_H, x + 6, 71, C.wall)
    line({x + 6, HUD_H, x + 22, 70}, C.wall_light, 2)
  end
  for x = 20, W - 20, 70 do
    rectfill(x, 39, x + 32, 42, C.cream)
    rectfill(x + 4, 42, x + 28, 45, C.gold)
  end

  -- Spiegelwand, Holzleisten und die Studio-Schrift geben dem Raum einen eigenen Charakter.
  rectfill(19, 52, 301, 140, C.wall_dark)
  rectfill(23, 56, 297, 133, C.mirror_dark)
  rectfill(26, 59, 294, 129, C.mirror)
  rectfill(28, 61, 292, 63, C.mirror_light)
  for x = 92, 276, 46 do rectfill(x, 59, x + 2, 129, C.mirror_dark) end
  rectfill(18, 134, 302, 141, C.red)
  rectfill(18, 141, 302, 144, C.wall_dark)
  -- Spiegelreflexe
  for i = 0, 6 do
    local x = 35 + i * 38
    line({x, 66, x + 10, 66}, rgb(162, 184, 175), 1)
    line({x - 4, 70, x + 2, 70}, rgb(112, 145, 148), 1)
  end
  rectfill(107, 71, 213, 88, C.ink)
  rect(108, 72, 212, 87, C.gold)
  print("STUDIO EITEL", 122, 77, C.cream)
  rectfill(143, 89, 177, 92, C.red)

  -- Gerahmte Trainingsplakate statt einer austauschbaren Stadtkulisse.
  rectfill(3, 83, 21, 121, C.ink); rect(4, 84, 20, 120, C.gold)
  rectfill(6, 87, 18, 116, rgb(78, 74, 71))
  line({8, 110, 12, 91}, C.cream, 2); line({12, 91, 16, 110}, C.cream, 2)
  rectfill(299, 83, 317, 121, C.ink); rect(300, 84, 316, 120, C.gold)
  rectfill(303, 88, 313, 108, C.red)
  print("NO", 304, 110, C.cream)
end

local function draw_rack()
  -- Hanteln und ein roter Trainingshocker stehen beidseits des Hauptbereichs.
  rectfill(274, 105, 278, 157, C.ink); rectfill(313, 105, 317, 157, C.ink)
  line({273, 111, 318, 111}, C.steel, 3)
  line({273, 128, 318, 128}, C.steel, 3)
  line({273, 145, 318, 145}, C.steel, 3)
  for y = 103, 138, 17 do
    for x = 282, 305, 11 do
      rectfill(x, y, x + 2, y + 10, C.steel_dark)
      rectfill(x - 2, y + 2, x, y + 8, C.steel)
      rectfill(x + 3, y + 2, x + 5, y + 8, C.steel_light)
    end
  end
  -- Bank und Hantelscheiben auf der Gegenseite.
  rectfill(34, 147, 86, 154, C.red); rectfill(38, 154, 43, 174, C.ink)
  rectfill(77, 154, 82, 174, C.ink); line({31, 144, 91, 144}, C.red_light, 2)
  for x = 36, 83, 16 do
    circfill(x, 142, 5, C.ink); circfill(x, 142, 3, C.steel_dark); pset(x, 141, C.steel_light)
  end
end

local function draw_floor()
  rectfill(0, 143, W - 1, H - 1, C.floor_dark)
  -- Gummifliesen laufen zum Fluchtpunkt und werden zum Spieler hin größer.
  for i = -3, 11 do
    local bottom_x = i * 40 - 20
    line({160, 139, bottom_x, H}, C.tile, 1)
  end
  for row = 1, 7 do
    local p = row / 7
    local y = 142 + p * p * 94
    line({0, y, W - 1, y}, row % 2 == 0 and C.floor or C.floor_dark, 1)
  end
  -- Mittlere Trainingsmatte wird zum Betrachter hin breiter.
  for y = 142, H - 1 do
    local p = (y - 142) / (H - 142)
    local half = 88 + p * 64
    rectfill(160 - half, y, 160 + half, y, rgb(58, 59, 65))
  end
  line({72, 142, 8, 239}, rgb(114, 75, 67), 2)
  line({248, 142, 312, 239}, rgb(114, 75, 67), 2)
  for y = 163, 230, 22 do line({45, y, 275, y}, rgb(68, 68, 73), 1) end
end

local function draw_gym()
  rectfill(0, 0, W - 1, H - 1, C.wall_dark)
  draw_wall()
  draw_floor()
  draw_rack()
  -- Kleine Spiegelglanz- und Staubpixel, fest gesetzt für einen ruhigen, konsistenten Stil.
  for i = 0, 19 do
    local x = (i * 47 + 13) % W
    local y = 76 + (i * 31) % 58
    pset(x, y, i % 3 == 0 and C.gold or C.mirror_light)
  end
end

local function draw_character(name, cx, bottom, scale, bob)
  local r = RECTS[name]
  local dw, dh = r[3] * scale, r[4] * scale
  sspr(IMG, r[1], r[2], r[3], r[4], flr(cx - dw / 2), flr(bottom - dh + bob), flr(dw + 0.5), flr(dh + 0.5))
end

local function player_sprite()
  if fitness >= 8 then return "snoesel_fit" end
  if fitness >= 4 then return "snoesel_mid" end
  return "snoesel_fat"
end

local function draw_barbell(y, tilt, phase)
  local angle = tilt * 0.36
  local half = 91
  local dy = math.sin(angle * 0.0174533) * half
  local x1, y1 = 160 - half, flr(y + dy)
  local x2, y2 = 160 + half, flr(y - dy)
  -- Schatten, Chromstange und gerändelte Griffzone.
  line({x1 - 2, y1 + 2, x2 + 2, y2 + 2}, C.shadow, 5)
  line({x1, y1, x2, y2}, C.ink, 5)
  line({x1, y1 - 1, x2, y2 - 1}, C.steel_dark, 3)
  line({x1 + 9, y1 - 1, x2 - 9, y2 - 1}, C.steel_light, 1)
  for grip = -1, 1, 2 do
    local gx = 160 + grip * 31
    local gy = y - grip * dy * 31 / half
    for stripe = -4, 4, 2 do line({gx + stripe, gy - 2, gx + stripe + 2, gy + 2}, C.steel, 1) end
  end
  local radius = 9 + (set_no - 1) * 3
  for _, x in ipairs({x1 + 10, x1 + 20, x2 - 10, x2 - 20}) do
    local side = x < 160 and 1 or -1
    local py = flr(y + (x - 160) * math.sin(angle * 0.0174533))
    circfill(x, py, radius + 2, C.ink)
    local outer = (x == x1 + 10 or x == x2 - 10) and C.steel_dark or C.steel
    circfill(x, py, radius, outer)
    circfill(x - 2, py - 2, max(2, radius - 4), C.steel_light)
    line({x - side * 2, py - radius + 3, x - side * 2, py + radius - 3}, C.steel_dark, 1)
  end
  -- Hände um die Stange und ein grüner Blendschutz, wenn der Lift perfekt sitzt.
  local hand_y = flr(y - 4)
  rectfill(160 - 34, hand_y, 160 - 27, hand_y + 6, C.skin)
  rectfill(160 + 27, hand_y, 160 + 34, hand_y + 6, C.skin)
  if phase >= 0.44 and phase <= 0.57 then
    line({x1 + 26, y1 - 10, x2 - 26, y2 - 10}, C.green, 1)
  end
end

local function draw_beat_meter(phase, in_window)
  local x, y, w, h = 25, 43, 270, 15
  rectfill(x - 2, y - 2, x + w + 2, y + h + 2, C.ink)
  rectfill(x, y, x + w, y + h, C.form_bg)
  rectfill(x + flr(w * 0.44), y + 1, x + flr(w * 0.57), y + h - 1, in_window and C.green or C.green_dark)
  local cx = x + flr(w * phase)
  rectfill(cx - 2, y - 3, cx + 2, y + h + 3, C.cream)
  print("OBEN IM GRÜNEN BEREICH DRÜCKEN", 67, 61, in_window and C.green or C.cream)
end

local function draw_balance_meter(tilt)
  local x, y, w = 50, 92, 220
  rectfill(x - 2, y - 2, x + w + 2, y + 8, C.ink)
  rectfill(x, y, x + w, y + 6, C.form_bg)
  rectfill(133, y, 187, y + 6, C.green_dark)
  local pos = x + flr((tilt + 45) / 90 * w)
  rectfill(pos - 2, y - 3, pos + 2, y + 9, C.gold)
  print("AUSGLEICH", 12, 91, C.cream)
  print("FORM", 12, 104, C.cream)
  rectfill(51, 106, 162, 114, C.form_bg)
  local fw = flr(109 * form / 100)
  rectfill(52, 107, 52 + fw, 113, form < 30 and C.red or C.green)
  print(tostring(flr(form)) .. "%", 169, 105, C.cream)
end

local function draw_hud(phase, in_window, tilt)
  rectfill(0, 0, W - 1, HUD_H - 1, C.panel)
  rectfill(0, HUD_H - 3, W - 1, HUD_H - 1, C.red)
  print("SATZ " .. tostring(set_no) .. "/" .. tostring(SET_COUNT), 8, 5, C.cream)
  print("WIEDERHOLUNGEN", 105, 5, C.cream)
  print("BEST " .. tostring(best), 245, 5, C.gold)
  for i = 1, REPS_PER_SET do
    local col = i <= reps_in_set and C.gold or C.form_bg
    rectfill(129 + (i - 1) * 17, 18, 141 + (i - 1) * 17, 27, col)
    rect(129 + (i - 1) * 17, 18, 141 + (i - 1) * 17, 27, C.ink)
  end
  print("GESAMT " .. tostring(fitness) .. "/" .. tostring(FITNESS_GOAL), 8, 20, C.green)
  for i = 1, 2 do
    if i <= drinks then
      local r = RECTS.monster_can
      sspr(IMG, r[1], r[2], r[3], r[4], 265 + (i - 1) * 18, 18, 9, 13)
    else
      rectfill(266 + (i - 1) * 18, 18, 273 + (i - 1) * 18, 29, C.form_bg)
    end
  end
  draw_beat_meter(phase, in_window)
  draw_balance_meter(tilt)
end

local function draw_play()
  draw_gym()
  local phase, in_window = lift_window()
  local wobble_power = 10 + (set_no - 1) * 6
  local shake = boost_time > 0 and 1.75 or 1
  local tilt = (math.sin(frame_count * 0.047 + fitness * 0.61) * wobble_power
    + math.sin(frame_count * 0.113 + 1.7) * 4 + tilt_adjust) * shake
  tilt = clamp(-45, 45, tilt)
  local bar_y = 198 - flr((1 - math.cos(phase * 6.28318)) * 14)
  local bob = frame_count % 20 < 10 and 0 or 1
  rectfill(111, FLOOR - 2, 209, FLOOR + 2, C.shadow)
  draw_character(player_sprite(), 160, FLOOR, 1.52, bob)
  draw_barbell(bar_y, tilt, phase)
  draw_hud(phase, in_window, tilt)
  if boost_time > 0 then
    print("MONSTER-RUSH!", 121, 128, C.energy)
  elseif flash_time > 0 then
    print(combo > 0 and "SAUBER!" or "WACKELIG!", 132, 128, combo > 0 and C.green or C.red)
  end
  print("LINKS/RECHTS: BALANCE   A: HEBEN", 29, 218, C.cream)
  print("B: MONSTER   UNTEN: RUHIG ATMEN", 35, 230, C.gold)
end

local function draw_title()
  draw_gym()
  rectfill(31, 12, 289, 81, C.panel)
  rect(32, 13, 288, 80, C.gold)
  print("SCHNÖSEL IM GYM", 96, 22, C.cream)
  print("STUDIO EITEL", 115, 38, C.gold)
  print("KREUZHEBEN MIT BALANCE", 68, 53, C.green)
  print("A: WENN DIE STANGE OBEN IST", 68, 68, C.cream)
  draw_character("snoesel_fat", 160, FLOOR, 1.6, 0)
  draw_barbell(185, 0, 0.5)
  rectfill(12, 196, 308, 239, C.panel)
  rect(13, 197, 307, 238, C.red)
  print("LINKS/RECHTS: AUSGLEICHEN", 52, 202, C.cream)
  print("B: POWER, ABER STANGE WACKELT", 48, 214, C.energy)
  print("UNTEN: ATMEN    START: LOS", 69, 227, C.gold)
end

local function draw_rest()
  draw_gym()
  draw_character(player_sprite(), 160, FLOOR, 1.52, 0)
  draw_barbell(202, tilt_adjust * 0.2, 0)
  draw_hud(0, false, 0)
  rectfill(38, 54, 282, 125, C.panel)
  rect(39, 55, 281, 124, C.gold)
  print("SATZ " .. tostring(set_no) .. " GESCHAFFT", 88, 68, C.green)
  print("Bisher " .. tostring(fitness) .. " saubere Wiederholungen", 61, 87, C.cream)
  print("UNTEN HALTEN: FOKUS ZURÜCKHOLEN", 40, 103, C.gold)
  print("A: NÄCHSTER SATZ", 103, 115, C.cream)
  print("B: MONSTER TRINKEN   UNTEN: AUSRUHEN", 30, 222, C.cream)
end

local function draw_end(won)
  draw_gym()
  draw_character(won and "snoesel_fit" or player_sprite(), 160, FLOOR, 1.55, 0)
  draw_barbell(185, 0, 0.5)
  rectfill(32, 46, 288, 116, C.panel)
  rect(33, 47, 287, 115, won and C.green or C.red)
  if won then
    print("STUDIO EITEL: ABGERÄUMT!", 76, 60, C.gold)
    print("Der Schnösel ist jetzt fit.", 76, 78, C.cream)
    print("Persol sitzt. Blazer spannt.", 73, 94, C.green)
  else
    print("DIE STANGE WACKELT!", 87, 61, C.red)
    print("Atmen, ausgleichen, nochmal.", 69, 80, C.cream)
  end
  print("SATZ " .. tostring(set_no) .. "   WIEDERHOLUNGEN " .. tostring(fitness), 84, 185, C.gold)
  print("A ODER START: NOCH EIN SATZ", 73, 222, C.cream)
end

function _draw()
  if state == "title" then draw_title()
  elseif state == "rest" then draw_rest()
  elseif state == "over" or state == "win" then draw_end(state == "win")
  else draw_play() end
end
