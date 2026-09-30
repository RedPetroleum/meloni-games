-- Kuschelwiese: Hoppel sammelt auf der Blumenwiese Möhren. Ganz lieb. Bis die Gartenzwerge kommen.
-- Steuerkreuz: hoppeln   A halten: Kettensäge   B: Hechtsprung   START: los / Pause

local S = require("sprites")

local HUD_H = 16
local X0, X1 = 10, SCREEN_W - 10
local Y0, Y1 = HUD_H + 16, SCREEN_H - 4
local GOAL = 10            -- so viele Möhren bis zum Umschwung
local MAX_HP = 5

-- Farben als {r, g, b}, damit sich die Wiese langsam verfärben kann
local CUTE = {grass = {176, 222, 146}, tuft = {150, 204, 124}, hud = {255, 214, 228}}
local DARK = {grass = {58, 70, 50}, tuft = {44, 52, 38}, hud = {40, 20, 24}}

local C = {
  text = rgb(92, 60, 92),
  pink = rgb(240, 110, 160),
  white = rgb(255, 255, 255),
  red = rgb(214, 30, 44),
  blood = rgb(192, 24, 40),
  blood_dark = rgb(120, 12, 26),
  blood_old = rgb(140, 18, 30),
  gold = rgb(247, 214, 90),
  panel_cute = rgb(255, 236, 244),
  black = rgb(18, 10, 14),
  grey = rgb(160, 150, 160),
}

local KINDS = {
  normal = {sprite = "gnome_walk", hp = 3, speed = 0.55, pts = 10, scale = 1, reach = 9},
  flitz = {sprite = "flitz_walk", hp = 1, speed = 1.15, pts = 15, scale = 1, reach = 8},
  brumm = {sprite = "brumm_walk", hp = 12, speed = 0.33, pts = 50, scale = 2, reach = 15},
}

local COMBO_TEXT = {[3] = "GEMETZEL!", [5] = "MASSAKER!", [8] = "BLUTRAUSCH!!", [12] = "HASENHÖLLE!!!"}

local state, t
local save
local bunny, carrots, chicks, butterflies, gnomes, parts, decals, popups, flowers, tufts
local eaten, dark, shake, hitstop, msg, msg_t
local wave, to_spawn, spawn_t, wave_pause, kills, score, combo, combo_t, over_t, twist_t, twist_gnome
local draw_list = {}

-- ---------- Helfer ----------

local function dist(ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  return math.sqrt(dx * dx + dy * dy)
end

local function mix(a, b, f)
  return rgb(flr(a[1] + (b[1] - a[1]) * f), flr(a[2] + (b[2] - a[2]) * f), flr(a[3] + (b[3] - a[3]) * f))
end

local function center(text, y, c, scale)
  print(text, (SCREEN_W - textw(text, scale)) // 2, y, c, scale)
end

local function say(text, frames)
  msg, msg_t = text, frames or 180
end

local function write_save()
  savedata(save)
end

-- ---------- Töne ----------

local SFX = {}
function SFX.cute_music() tune("C5 E5 G5 E5 F5:2 A5 F5 G5 E5 C5:2 D5 E5 C5:2 -", 170, "triangle", 0.14, true, 7) end
function SFX.evil_music()
  tune("E2 E2 G2 E2 Bb2 A2 E2 - E2 E2 G2 E2 D3 C3 B2 -", 210, "saw", 0.16, true, 7)
end
function SFX.carrot() tune("C6:0.3 E6:0.3 G6:0.6", 900, "triangle", 0.3, false, 6) end
function SFX.splat() tone(70 + rnd(40), 0.25, "noise", 0.55) tone(note("C2"), 0.15, "square", 0.3) end
function SFX.saw() tone(55 + rnd(25), 0.09, "saw", 0.16, 5) end
function SFX.grind() tone(300 + rnd(300), 0.05, "noise", 0.22, 4) end
function SFX.hurt() tune("E4:0.5 C4:0.5 G3:1", 600, "square", 0.25, false, 6) end
function SFX.heal() tune("G5:0.3 C6:0.6", 800, "triangle", 0.3, false, 6) end
function SFX.dash() tone(note("A3"), 0.08, "noise", 0.2) end
function SFX.laugh() tune("A4:0.3 F4:0.3 A4:0.3 F4:0.3 A4:0.3 F4:0.6", 400, "square", 0.2, false, 6) end
function SFX.lullaby() tune("E5:2 C5:2 D5:2 G4:3 - E5:2 C5:2 D5:1 C5:4", 110, "triangle", 0.16, false, 7) end
function SFX.wave() tune("E3:0.5 E3:0.5 G3:0.5 E4:1.5", 400, "saw", 0.22, false, 6) end

-- ---------- Partikel und Flecken ----------

local function particle(p)
  if #parts >= 220 then table.remove(parts, 1) end
  parts[#parts + 1] = p
end

local function decal(d)
  if #decals >= 170 then table.remove(decals, 1) end
  decals[#decals + 1] = d
end

local function blood(x, y, n, force)
  force = force or 1.5
  for _ = 1, n do
    local a = rnd(1) * math.pi * 2
    local s = (0.4 + rnd(1)) * force
    particle({x = x, y = y, z = 6 + rnd(6), vx = math.cos(a) * s, vy = math.sin(a) * s * 0.6,
      vz = 0.5 + rnd(2.2), c = rnd(1) < 0.6 and C.blood or C.blood_dark, life = 60 + flr(rnd(40))})
  end
end

local function splat(x, y, n)
  for _ = 1, n do
    decal({x = x + rnd(28) - 14, y = y + rnd(14) - 7, r = 1 + flr(rnd(5)),
      c = rnd(1) < 0.5 and C.blood_old or C.blood_dark})
  end
end

local function gib(x, y, sprite)
  local a = rnd(1) * math.pi * 2
  particle({x = x, y = y, z = 10, vx = math.cos(a) * (1 + rnd(1.5)), vy = math.sin(a) * (0.6 + rnd(1)),
    vz = 2 + rnd(2), sprite = sprite, flip = rnd(1) < 0.5, life = 100000})
end

local function popup(x, y, text, c, scale)
  popups[#popups + 1] = {x = x, y = y, text = text, c = c or C.white, scale = scale or 1, life = 50}
end

local function update_parts()
  for i = #parts, 1, -1 do
    local p = parts[i]
    if p.z > 0 then
      p.x, p.y = p.x + p.vx, p.y + p.vy
      p.vz = p.vz - (p.float and 0.03 or 0.22)
      p.z = p.z + p.vz
      if p.z <= 0 then
        p.z = 0
        if p.c and rnd(1) < 0.35 then
          -- Blut bleibt als Fleck auf der Wiese
          decal({x = flr(p.x), y = flr(p.y), r = rnd(1) < 0.7 and 0 or 1, c = C.blood_old})
        end
        if p.sprite then
          -- Gelandete Teile bleiben als Fleck liegen
          decal({x = flr(p.x), y = flr(p.y), sprite = p.sprite, flip = p.flip})
          table.remove(parts, i)
          goto continue
        end
      end
    end
    p.life = p.life - 1
    if p.life <= 0 then table.remove(parts, i) end
    ::continue::
  end
  for i = #popups, 1, -1 do
    local p = popups[i]
    p.y, p.life = p.y - 0.5, p.life - 1
    if p.life <= 0 then table.remove(popups, i) end
  end
end

-- ---------- Wiese ----------

local function build_meadow()
  flowers, tufts = {}, {}
  for _ = 1, 34 do
    flowers[#flowers + 1] = {x = X0 + flr(rnd(X1 - X0 - 5)), y = Y0 - 8 + flr(rnd(Y1 - Y0)), y_flower = rnd(1) < 0.5}
  end
  for _ = 1, 60 do
    tufts[#tufts + 1] = {x = flr(rnd(SCREEN_W)), y = HUD_H + flr(rnd(SCREEN_H - HUD_H))}
  end
end

local function spawn_carrot()
  for _ = 1, 20 do
    local x, y = X0 + 10 + rnd(X1 - X0 - 20), Y0 + 6 + rnd(Y1 - Y0 - 12)
    if dist(x, y, bunny.x, bunny.y) > 50 then
      carrots[#carrots + 1] = {x = x, y = y, bob = rnd(60)}
      return
    end
  end
end

local function new_bunny(evil)
  return {x = 160, y = 140, dir = "down", left = false, moving = false, anim = 0, evil = evil,
    hp = MAX_HP, inv = 0, dash = 0, dash_cd = 0, saw = false, kvx = 0, kvy = 0, frozen = false}
end

local function reset_world(evil)
  bunny = new_bunny(evil)
  carrots, chicks, butterflies, gnomes, parts, decals, popups = {}, {}, {}, {}, {}, {}, {}
  build_meadow()
  eaten, shake, hitstop, msg, msg_t = 0, 0, 0, nil, 0
  kills, score, combo, combo_t = 0, 0, 0, 0
  dark = evil and 1 or 0
  if not evil then
    for i = 1, 3 do
      chicks[#chicks + 1] = {x = 60 + i * 60, y = 190 - i * 18, tx = 0, ty = 0, timer = 0, flee = false}
    end
    for _ = 1, 5 do
      butterflies[#butterflies + 1] = {x = rnd(SCREEN_W), y = Y0 + rnd(Y1 - Y0 - 40), ph = rnd(10),
        vx = rnd(1) < 0.5 and -0.4 or 0.4, fall = false, vy = 0}
    end
  end
end

-- ---------- Hase ----------

local DIRV = {right = {1, 0}, left = {-1, 0}, down = {0, 1}, up = {0, -1}}

local function saw_point()
  local v = DIRV[bunny.dir]
  if bunny.dir == "up" then return bunny.x + 5, bunny.y - 24 end
  if bunny.dir == "down" then return bunny.x + 5, bunny.y + 6 end
  return bunny.x + v[1] * 18, bunny.y - 6
end

local function update_bunny()
  local b = bunny
  b.moving = false
  if b.inv > 0 then b.inv = b.inv - 1 end
  if b.dash_cd > 0 then b.dash_cd = b.dash_cd - 1 end
  if b.frozen then return end
  if b.kvx ~= 0 or b.kvy ~= 0 then
    b.x, b.y = b.x + b.kvx, b.y + b.kvy
    b.kvx, b.kvy = b.kvx * 0.8, b.kvy * 0.8
    if abs(b.kvx) + abs(b.kvy) < 0.2 then b.kvx, b.kvy = 0, 0 end
  end
  local dx, dy = 0, 0
  if btn(BTN_LEFT) then dx = dx - 1 end
  if btn(BTN_RIGHT) then dx = dx + 1 end
  if btn(BTN_UP) then dy = dy - 1 end
  if btn(BTN_DOWN) then dy = dy + 1 end
  if b.evil then
    b.saw = btn(BTN_A) and b.dash == 0
    if btnp(BTN_B) and b.dash_cd == 0 then
      b.dash, b.dash_cd = 10, 45
      SFX.dash()
    end
  end
  if b.dash > 0 then
    b.dash = b.dash - 1
    local v = DIRV[b.dir]
    b.x, b.y = b.x + v[1] * 4.2, b.y + v[2] * 4.2
    b.moving = true
    if b.dash % 2 == 0 then
      particle({x = b.x, y = b.y, z = 1, vx = 0, vy = 0, vz = 0, c = C.white, life = 10})
    end
  elseif dx ~= 0 or dy ~= 0 then
    local speed = b.saw and 1.0 or 1.6
    if dx ~= 0 and dy ~= 0 then speed = speed * 0.7071 end
    b.x, b.y = b.x + dx * speed, b.y + dy * speed
    b.moving = true
    if dx ~= 0 and abs(dx) >= abs(dy) then
      b.dir, b.left = dx > 0 and "right" or "left", dx < 0
    elseif dy ~= 0 and dx == 0 then
      b.dir = dy > 0 and "down" or "up"
    end
  end
  b.x, b.y = mid(X0, b.x, X1), mid(Y0, b.y, Y1)
  if b.moving then b.anim = b.anim + (b.dash > 0 and 0.4 or 0.22) end
  if b.saw and t % 5 == 0 then SFX.saw() end
end

local function draw_saw(b, bx, by)
  local f = (b.saw and (t // 2) % 2 == 0) and "2" or "1"
  local jx = b.saw and (flr(rnd(3)) - 1) or 0
  if b.dir == "right" then
    S.draw("saw_side" .. f, bx + 3 + jx, by - 10)
  elseif b.dir == "left" then
    S.draw("saw_side" .. f, bx - 19 + jx, by - 10, true)
  elseif b.dir == "down" then
    S.draw("saw_v" .. f, bx + 3 + jx, by - 7)
  end
end

local function draw_bunny(b)
  if b.inv > 0 and (b.inv // 4) % 2 == 0 and b.hp > 0 then return end
  local prefix = b.evil and "evil_" or "bunny_"
  local x, y = flr(b.x), flr(b.y)
  if b.hp <= 0 then
    S.draw(prefix .. "dead", x - 8, y - 12)
    return
  end
  local hop = b.moving and flr(abs(math.sin(b.anim)) * 4) or 0
  if b.saw and not b.moving then hop = flr(rnd(2)) end
  -- Schatten
  rectfill(x - 5, y - 1, x + 5, y, mix(CUTE.tuft, DARK.tuft, dark))
  if b.evil and b.dir == "up" then
    S.draw("saw_v" .. ((b.saw and (t // 2) % 2 == 0) and "2" or "1"), x + 3, y - 30 - hop, false, true)
  end
  if b.dir == "left" or b.dir == "right" then
    S.draw(prefix .. "side", x - 8, y - 15 - hop, b.left)
  else
    S.draw(prefix .. b.dir, x - 7, y - 15 - hop)
  end
  if b.evil and b.dir ~= "up" then draw_saw(b, x, y - hop) end
end

-- ---------- Niedliche Phase ----------

local function update_chicks()
  for i = #chicks, 1, -1 do
    local c = chicks[i]
    if c.flee then
      c.x = c.x + (c.x < 160 and -2 or 2)
      if c.x < -20 or c.x > SCREEN_W + 20 then table.remove(chicks, i) end
    else
      c.timer = c.timer - 1
      if c.timer <= 0 then
        c.tx, c.ty = mid(X0, c.x + rnd(60) - 30, X1), mid(Y0, c.y + rnd(40) - 20, Y1)
        c.timer = 60 + flr(rnd(120))
      end
      local d = dist(c.x, c.y, c.tx, c.ty)
      if d > 1 then
        c.x, c.y = c.x + (c.tx - c.x) / d * 0.4, c.y + (c.ty - c.y) / d * 0.4
        c.left = c.tx < c.x
      end
    end
  end
end

local function update_butterflies()
  for i = #butterflies, 1, -1 do
    local f = butterflies[i]
    if f.fall then
      f.vy = f.vy + 0.08
      f.y = f.y + f.vy
      if f.y > f.ground then
        decal({x = flr(f.x), y = flr(f.y), sprite = "butterfly2"})
        table.remove(butterflies, i)
      end
    else
      f.ph = f.ph + 0.05
      f.x = f.x + f.vx
      f.y = f.y + math.sin(f.ph) * 0.4
      if f.x < 0 or f.x > SCREEN_W - 8 then f.vx = -f.vx end
    end
  end
end

local function update_cute()
  update_bunny()
  update_chicks()
  update_butterflies()
  update_parts()
  if #carrots < 2 and eaten + #carrots < GOAL then spawn_carrot() end
  for i = #carrots, 1, -1 do
    local c = carrots[i]
    if dist(c.x, c.y, bunny.x, bunny.y - 4) < 13 then
      table.remove(carrots, i)
      eaten = eaten + 1
      SFX.carrot()
      for k = 1, 3 do
        particle({x = c.x, y = c.y, z = 12, vx = (k - 2) * 0.4, vy = 0, vz = 0.6, float = true,
          sprite_float = "heart", life = 40})
      end
      local lines = {"Mjam!", "Lecker!", "Hmmm!", "Knusper!", "Hoppel ist glücklich!"}
      popup(c.x, c.y - 20, lines[1 + flr(rnd(#lines))], C.pink)
      if eaten >= GOAL then
        state, twist_t = "twist", 0
        bunny.frozen, bunny.moving = true, false
        stoptune(7)
        say("Mmmh ... satt und glücklich.", 100)
      end
    end
  end
end

-- ---------- Umschwung ----------

local function kill_chick(c)
  for i, o in ipairs(chicks) do
    if o == c then table.remove(chicks, i) break end
  end
  blood(c.x, c.y - 4, 30, 2)
  splat(c.x, c.y, 6)
  for _ = 1, 8 do
    local a = rnd(1) * math.pi * 2
    particle({x = c.x, y = c.y, z = 6, vx = math.cos(a) * 1.2, vy = math.sin(a) * 0.8, vz = 1.5 + rnd(1.5),
      float = true, sprite_float = "feather", life = 120})
  end
  gib(c.x, c.y, "gib_eye")
  shake = 10
  SFX.splat()
end

local function new_gnome(kind, x, y)
  local k = KINDS[kind]
  return {kind = k, x = x, y = y, hp = k.hp, hurt = 0, anim = rnd(10), kvx = 0, kvy = 0}
end

local function update_twist()
  twist_t = twist_t + 1
  update_parts()
  update_butterflies()
  local victim = chicks[1]
  if twist_t == 90 and victim then
    twist_gnome = new_gnome("normal", SCREEN_W + 12, victim.y)
    gnomes[1] = twist_gnome
    say("Nanu? Wer kommt denn da?", 140)
    for _, c in ipairs(chicks) do c.timer = 1000 end
  end
  local g = twist_gnome
  if g and victim and twist_t > 90 then
    local d = dist(g.x, g.y, victim.x, victim.y)
    g.anim = g.anim + 0.15
    if d > 6 then
      g.x, g.y = g.x + (victim.x - g.x) / d * 1.1, g.y + (victim.y - g.y) / d * 1.1
    else
      kill_chick(victim)
      for _, c in ipairs(chicks) do c.flee = true end
      twist_t = 1000
      SFX.laugh()
      say("Hehehe!", 120)
    end
  end
  update_chicks()
  if twist_t == 1080 then
    say("...", 90)
  elseif twist_t == 1170 then
    bunny.evil = true
    shake = 14
    SFX.splat()
    for _, f in ipairs(butterflies) do f.fall, f.ground = true, f.y + 20 + rnd(30) end
  elseif twist_t > 1170 and twist_t < 1290 then
    dark = min(1, (twist_t - 1170) / 110)
    if twist_t % 6 == 0 then SFX.saw() end
    bunny.saw = (twist_t // 20) % 2 == 0
  elseif twist_t == 1290 then
    bunny.saw, bunny.frozen = false, false
    state = "fight"
    wave, to_spawn, spawn_t, wave_pause = 1, 6, 30, 0
    save.seen = true
    write_save()
    SFX.evil_music()
    say("A halten: Kettensäge   B: Hechtsprung", 240)
  end
end

-- ---------- Kampf ----------

local function start_wave(n)
  wave = n
  to_spawn = 5 + n * 3
  spawn_t = 60
  wave_pause = 0
  popup(160, 110, "WELLE " .. n, C.red, 3)
  SFX.wave()
end

local function spawn_gnome()
  local kind = "normal"
  local r = rnd(1)
  if wave >= 3 and r < 0.12 + wave * 0.01 then
    kind = "brumm"
  elseif wave >= 2 and r < 0.45 then
    kind = "flitz"
  end
  local side = flr(rnd(4))
  local x, y
  if side == 0 then x, y = -14, Y0 + rnd(Y1 - Y0)
  elseif side == 1 then x, y = SCREEN_W + 14, Y0 + rnd(Y1 - Y0)
  elseif side == 2 then x, y = rnd(SCREEN_W), HUD_H - 4
  else x, y = rnd(SCREEN_W), SCREEN_H + 22 end
  gnomes[#gnomes + 1] = new_gnome(kind, x, y)
end

local function kill_gnome(i)
  local g = gnomes[i]
  table.remove(gnomes, i)
  local big = g.kind.scale > 1
  blood(g.x, g.y - 8, big and 70 or 36, big and 2.6 or 2)
  splat(g.x, g.y, big and 12 or 5)
  gib(g.x, g.y, "gib_hat")
  gib(g.x, g.y, "gib_beard")
  if rnd(1) < 0.6 then gib(g.x, g.y, "gib_boot") end
  if rnd(1) < 0.4 then gib(g.x, g.y, "gib_eye") end
  if big then gib(g.x, g.y, "gib_boot") gib(g.x, g.y, "gib_eye") end
  shake = max(shake, big and 12 or 6)
  hitstop = big and 8 or 4
  SFX.splat()
  kills = kills + 1
  combo = combo + 1
  combo_t = 100
  score = score + g.kind.pts * min(combo, 10)
  if COMBO_TEXT[combo] then
    popup(160, 60, COMBO_TEXT[combo], C.red, 2)
  else
    popup(g.x, g.y - 24, "+" .. g.kind.pts * min(combo, 10), C.gold)
  end
  if rnd(1) < 0.12 then carrots[#carrots + 1] = {x = g.x, y = g.y, bob = 0} end
end

local function hurt_bunny(g)
  local b = bunny
  b.hp = b.hp - 1
  b.inv = 70
  local d = max(1, dist(g.x, g.y, b.x, b.y))
  b.kvx, b.kvy = (b.x - g.x) / d * 4, (b.y - g.y) / d * 4
  blood(b.x, b.y - 8, 14, 1.4)
  shake = 8
  SFX.hurt()
  if b.hp <= 0 then
    state, over_t = "dying", 0
    b.saw = false
    stoptune(7)
    splat(b.x, b.y, 8)
    blood(b.x, b.y - 6, 50, 2.2)
    if score > (save.best or 0) then
      save.best = score
      save.new_best = true
    else
      save.new_best = false
    end
    save.kills = (save.kills or 0) + kills
    write_save()
  end
end

local function update_gnomes()
  local b = bunny
  local sx, sy = saw_point()
  local tick = b.saw and t % 6 == 0
  local speed_up = 1 + (wave - 1) * 0.06
  for i = #gnomes, 1, -1 do
    local g = gnomes[i]
    local k = g.kind
    if g.hurt > 0 then g.hurt = g.hurt - 1 end
    local dx, dy = b.x - g.x, b.y - g.y
    local d = math.sqrt(dx * dx + dy * dy)
    local sp = k.speed * speed_up * (g.hurt > 0 and 0.3 or 1)
    if d > 1 and b.hp > 0 then
      g.x, g.y = g.x + dx / d * sp + g.kvx, g.y + dy / d * sp + g.kvy
    end
    g.kvx, g.kvy = g.kvx * 0.8, g.kvy * 0.8
    g.anim = g.anim + sp * 0.25
    -- nicht alle auf einem Haufen
    for j = i - 1, 1, -1 do
      local o = gnomes[j]
      local ox, oy = g.x - o.x, g.y - o.y
      local rr = 6 * (g.kind.scale + o.kind.scale)
      if abs(ox) < rr and abs(oy) < rr * 0.7 then
        local px, py = sgn(ox) * 0.7, sgn(oy) * 0.45
        g.x, g.y = g.x + px, g.y + py
        o.x, o.y = o.x - px, o.y - py
      end
    end
    local hit = false
    if b.saw then
      local r = 11 + (k.scale - 1) * 7
      if dist(sx, sy, g.x, g.y - 8 * k.scale) < r then
        hit = true
        if tick then
          g.hp = g.hp - 1
          g.hurt = 8
          blood(sx, sy, 5, 1.8)
          SFX.grind()
          local v = DIRV[b.dir]
          g.kvx, g.kvy = v[1] * (1.2 / k.scale), v[2] * (1.2 / k.scale)
          if rnd(1) < 0.3 then splat(g.x, g.y, 1) end
          if g.hp <= 0 then
            kill_gnome(i)
            goto continue
          end
        end
      end
    end
    if b.dash > 0 and d < k.reach + 4 then
      -- Hechtsprung schubst Zwerge weg
      g.kvx, g.kvy = -dx / max(d, 1) * 3 / k.scale, -dy / max(d, 1) * 3 / k.scale
    elseif not hit and d < k.reach and b.inv == 0 and b.hp > 0 then
      hurt_bunny(g)
    end
    ::continue::
  end
end

local function update_fight()
  update_bunny()
  update_gnomes()
  update_parts()
  for i = #carrots, 1, -1 do
    local c = carrots[i]
    if dist(c.x, c.y, bunny.x, bunny.y - 4) < 13 then
      table.remove(carrots, i)
      if bunny.hp < MAX_HP then
        bunny.hp = bunny.hp + 1
        popup(c.x, c.y - 16, "+1 Herz", C.pink)
      else
        score = score + 25
        popup(c.x, c.y - 16, "+25", C.gold)
      end
      SFX.heal()
    end
  end
  if combo_t > 0 then
    combo_t = combo_t - 1
    if combo_t == 0 then combo = 0 end
  end
  if state ~= "fight" then return end
  if to_spawn > 0 then
    spawn_t = spawn_t - 1
    if spawn_t <= 0 then
      spawn_gnome()
      to_spawn = to_spawn - 1
      spawn_t = max(18, 70 - wave * 6) + flr(rnd(30))
    end
  elseif #gnomes == 0 then
    wave_pause = wave_pause + 1
    if wave_pause == 1 then
      popup(160, 100, "Welle " .. wave .. " geschafft", C.gold, 2)
      score = score + wave * 100
    elseif wave_pause > 120 then
      start_wave(wave + 1)
    end
  end
end

-- ---------- Zeichnen ----------

local function draw_ground()
  cls(mix(CUTE.grass, DARK.grass, dark))
  local tc = mix(CUTE.tuft, DARK.tuft, dark)
  for _, g in ipairs(tufts) do
    pset(g.x, g.y, tc) pset(g.x + 2, g.y - 1, tc) pset(g.x + 4, g.y, tc)
  end
  for _, f in ipairs(flowers) do
    local name = dark > 0.5 and "flower_dead" or (f.y_flower and "flower_y" or "flower_p")
    S.draw(name, f.x, f.y)
  end
  for _, d in ipairs(decals) do
    if d.sprite then
      S.draw(d.sprite, d.x - 3, d.y - 3, d.flip)
    else
      circfill(d.x, d.y, d.r, d.c)
      if d.r > 2 then circfill(d.x - 1, d.y - 1, d.r - 2, C.blood_dark) end
    end
  end
end

local function draw_gnome(g)
  local k = g.kind
  local x, y = flr(g.x), flr(g.y)
  local bob = flr(g.anim) % 2
  local jx = g.hurt > 0 and (flr(rnd(3)) - 1) or 0
  rectfill(x - 5 * k.scale, y - 1, x + 5 * k.scale, y, mix(CUTE.tuft, DARK.tuft, dark))
  if k.scale == 1 then
    S.draw(k.sprite, x - 6 + jx, y - 17 - bob, bunny.x < g.x)
  else
    local r = S.rects[k.sprite]
    sspr(S.img, r[1], r[2], r[3], r[4], x - 12 + jx, y - 35 - bob * 2, 24, 36, bunny.x < g.x)
    if g.hp < k.hp then
      rectfill(x - 10, y - 41, x + 10, y - 39, C.black)
      rectfill(x - 10, y - 41, x - 10 + flr(20 * g.hp / k.hp), y - 39, C.red)
    end
  end
end

local function by_y(a, b) return a.y < b.y end

local function draw_world()
  local ox, oy = 0, 0
  if shake > 0 then ox, oy = flr(rnd(shake * 2 + 1)) - shake, flr(rnd(shake * 2 + 1)) - shake end
  camera(ox, oy)
  draw_ground()
  for _, c in ipairs(carrots) do
    S.draw("carrot", flr(c.x) - 4, flr(c.y) - 9 - flr(abs(math.sin((t + c.bob) * 0.08)) * 2))
  end
  -- Figuren nach Tiefe sortiert
  local n = 0
  for _, c in ipairs(chicks) do n = n + 1 draw_list[n] = {y = c.y, chick = c} end
  for _, g in ipairs(gnomes) do n = n + 1 draw_list[n] = {y = g.y, gnome = g} end
  n = n + 1
  draw_list[n] = {y = bunny.y, bunny = true}
  for i = #draw_list, n + 1, -1 do draw_list[i] = nil end
  table.sort(draw_list, by_y)
  for _, e in ipairs(draw_list) do
    if e.bunny then
      draw_bunny(bunny)
    elseif e.gnome then
      draw_gnome(e.gnome)
    else
      local c = e.chick
      S.draw("chick", flr(c.x) - 4, flr(c.y) - 8 - ((t // 12) % 2), c.left)
    end
  end
  for _, p in ipairs(parts) do
    local x, y = flr(p.x), flr(p.y - p.z)
    if p.sprite then
      S.draw(p.sprite, x - 3, y - 3, p.flip)
    elseif p.sprite_float then
      S.draw(p.sprite_float, x - 3, y - 3)
    else
      rectfill(x, y, x + (p.z > 0 and 1 or 0), y + 1, p.c)
    end
  end
  for _, f in ipairs(butterflies) do
    S.draw((t // 8) % 2 == 0 and "butterfly1" or "butterfly2", flr(f.x), flr(f.y))
  end
  camera()
  for _, p in ipairs(popups) do
    print(p.text, flr(p.x - textw(p.text, p.scale) / 2), flr(p.y), p.scale > 1 and C.black or C.black, p.scale)
    print(p.text, flr(p.x - textw(p.text, p.scale) / 2) - 1, flr(p.y) - 1, p.c, p.scale)
  end
end

local function draw_hud()
  local evil = state == "fight" or state == "dying"
  rectfill(0, 0, SCREEN_W - 1, HUD_H - 1, mix(CUTE.hud, DARK.hud, dark))
  local tc = evil and C.white or C.text
  for i = 1, MAX_HP do
    S.draw(i <= bunny.hp and "heart" or "heart_empty", 4 + (i - 1) * 9, 4)
  end
  if evil then
    print("Welle " .. wave, 56, 4, C.grey)
    local s = tostring(score)
    print(s, SCREEN_W - textw(s) - 4, 4, C.gold)
    if combo >= 2 then print("x" .. min(combo, 10), SCREEN_W - textw(s) - 32, 4, C.red) end
  else
    S.draw("carrot", 56, 3)
    print(eaten .. "/" .. GOAL, 68, 4, tc)
    print("Kuschelwiese", SCREEN_W - textw("Kuschelwiese") - 4, 4, C.pink)
  end
  if msg then
    local w = textw(msg) + 12
    local x = (SCREEN_W - w) // 2
    rectfill(x, SCREEN_H - 20, x + w, SCREEN_H - 6, evil and C.black or C.panel_cute)
    print(msg, x + 6, SCREEN_H - 16, evil and C.red or C.text)
  end
end

-- ---------- Titel ----------

local function to_title()
  state, t = "title", 0
  reset_world(false)
  bunny.frozen = true
  bunny.x, bunny.y = 160, 150
  stoptune()
  SFX.cute_music()
end

local function start_cute()
  reset_world(false)
  state, t = "cute", 0
  SFX.cute_music()
  say("Hoppel hat Hunger! Sammle " .. GOAL .. " Möhren.", 220)
end

local function start_fight()
  reset_world(true)
  state, t = "fight", 0
  stoptune()
  SFX.evil_music()
  start_wave(1)
  say("A halten: Kettensäge   B: Hechtsprung", 200)
end

local function draw_title()
  -- Wer das Ende kennt, sieht ab und zu, was hinter der Wiese steckt.
  local creepy = save.seen and (t % 240) > 222
  dark = creepy and 0.9 or 0
  bunny.evil = creepy
  bunny.moving = true
  bunny.anim = t * 0.1
  draw_ground()
  for _, f in ipairs(butterflies) do
    S.draw((t // 8) % 2 == 0 and "butterfly1" or "butterfly2", flr(f.x), flr(f.y))
  end
  for _, c in ipairs(chicks) do S.draw("chick", flr(c.x) - 4, flr(c.y) - 8, c.left) end
  draw_bunny(bunny)
  local title = "Kuschelwiese"
  local x = (SCREEN_W - textw(title, 3)) // 2
  for dy = 1, 3 do print(title, x + 2, 34 + dy, creepy and C.black or C.white, 3) end
  print(title, x, 34, creepy and C.red or C.pink, 3)
  if creepy then
    for i = 0, 5 do
      local dx = x + 10 + i * 42
      rectfill(dx, 58, dx + 1, 60 + (t % 240 - 222) + i % 3 * 3, C.blood)
    end
  end
  center(creepy and "Sie werden alle bluten." or "Ein ganz liebes Hasenspiel", 66, creepy and C.red or C.text)
  rectfill(40, 176, 279, 230, C.panel_cute)
  rect(41, 177, 278, 229, C.pink)
  if (t // 30) % 2 == 0 then center("START oder A: los!", 184, C.pink) end
  if save.seen then
    center("B: direkt zur Rache", 198, C.text)
    center("Rekord " .. (save.best or 0) .. "   Zwerge gesamt " .. (save.kills or 0), 214, C.text)
  else
    center("Sammle Möhren für Hoppel!", 202, C.text)
  end
end

local function draw_over()
  local f = min(1, over_t / 60)
  if over_t < 60 then return end
  rectfill(30, 60, 289, 190, C.panel_cute)
  rect(31, 61, 288, 189, C.pink)
  center("Hoppel ist müde.", 72, C.pink, 2)
  center("Süße Träume, kleiner Hase.", 96, C.text)
  center(kills .. " Zwerge wurden lieb gekuschelt.", 116, C.text)
  center("Punkte " .. score .. "   Welle " .. wave, 132, C.text)
  if save.new_best then
    center("Neuer Rekord!", 148, C.red)
  else
    center("Rekord " .. (save.best or 0), 148, C.grey)
  end
  if over_t > 120 and f == 1 then center("A: nochmal   B: Titel", 172, C.text) end
end

-- ---------- Ablauf ----------

function _init()
  save = loaddata() or {}
  to_title()
end

function _update()
  t = t + 1
  if msg_t > 0 then
    msg_t = msg_t - 1
    if msg_t == 0 then msg = nil end
  end
  if shake > 0 and t % 2 == 0 then shake = shake - 1 end
  if state == "title" then
    update_butterflies()
    update_chicks()
    if btnp(BTN_START) or btnp(BTN_A) then
      start_cute()
    elseif btnp(BTN_B) and save.seen then
      start_fight()
    end
  elseif state == "pause" then
    if btnp(BTN_START) then state = "fight" end
  elseif hitstop > 0 then
    hitstop = hitstop - 1
  elseif state == "cute" then
    update_cute()
  elseif state == "twist" then
    update_twist()
  elseif state == "fight" then
    if btnp(BTN_START) then state = "pause" return end
    update_fight()
  elseif state == "dying" then
    over_t = over_t + 1
    update_parts()
    if over_t == 60 then SFX.lullaby() end
    if over_t > 120 then
      if btnp(BTN_A) or btnp(BTN_START) then start_fight()
      elseif btnp(BTN_B) then to_title() end
    end
  end
end

function _draw()
  if state == "title" then
    draw_title()
    return
  end
  draw_world()
  draw_hud()
  if state == "twist" and twist_t > 1170 and twist_t < 1290 and (twist_t // 8) % 2 == 0 then
    center("RACHE.", 90, C.black, 4)
    center("RACHE.", 88, C.red, 4)
  elseif state == "pause" then
    rectfill(100, 96, 219, 140, C.black)
    center("Pause", 104, C.red, 2)
    center("START: weiter", 126, C.white)
  elseif state == "dying" then
    draw_over()
  end
end
