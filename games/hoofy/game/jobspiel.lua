-- Jobs als Minispiele (Rückmeldung 1.2.1). Jeder Job dauert etwa 20 s; das Ergebnis (Anteil 0–1) bestimmt
-- den Lohn (Jobs.run), die Energie des Pferds geht dabei sichtbar herunter (job.energie, KATALOG §12).
--   Postritt:   Briefkästen fliegen vorbei, A wirft den Brief, wenn der Kasten neben dem Reiter ist.
--   Kutschtaxi: drei Spuren, ↑/↓ wechselt; Fahrgäste einsammeln, Pfützen und Steinen ausweichen.
--   Pflügen:    ein Zeiger pendelt, A im grünen Bereich zieht die Furche ein Stück weiter (Stärke = breiter).
local K = require("game.katalog")
local G = require("game.horse_gfx")
local Stage = require("game.stage")
local SFX = require("game.sfx")
local Care = require("game.care")
local Rng = require("lib.rng")
local S = require("sprites")

local JS = {}

JS.POST_N = 8                  -- Briefkästen
JS.POST_X = 100                -- Bildschirm-x des Reiters (Brief fällt hier)
JS.POST_WINDOW = 12            -- so nah muss der Kasten sein (px)
JS.POST_COOL = 20              -- Frames bis zum nächsten Wurf
JS.TAXI_N = 18                 -- Dinge auf der Straße
JS.TAXI_LANES = {118, 152, 186}
JS.TAXI_X = 60                 -- Bildschirm-x der Kutsche (linke Kante)
JS.PFLUG_SEG = 18              -- 3 Furchen × 6 Stücke
JS.PFLUG_TIME = 1200           -- 20 s
JS.PFLUG_STUN = 20             -- nach einem Fehlgriff so lange gesperrt

local KIND = {postritt = "post", kutschtaxi = "taxi", pfluegen = "pflug"}

-- Neues Spiel für Job job und Pferd d. rng: Ablauf der Straße (Kutschtaxi).
function JS.new(job, d, rng)
  rng = rng or Rng.new(7)
  local st = {job = job, d = d, kind = KIND[job.id] or "post", t = 0, done = false, energie0 = d.energie}
  if st.kind == "post" then
    st.v = 1.4 + Care.effective(d, "tempo") / 100 * 1.2
    st.x, st.hits, st.miss, st.cool, st.boxes, st.letters = 0, 0, 0, 0, {}, {}
    for i = 1, JS.POST_N do st.boxes[i] = {x = 260 + (i - 1) * 150} end
  elseif st.kind == "taxi" then
    st.v = 1.5 + Care.effective(d, "staerke") / 100
    st.x, st.lane, st.picked, st.hits, st.shake, st.things, st.gaeste = 0, 2, 0, 0, 0, {}, 0
    local x = 300
    for i = 1, JS.TAXI_N do
      local gast = rng:next() < 0.4
      if gast then st.gaeste = st.gaeste + 1 end
      st.things[i] = {x = x, lane = rng:int(1, 3), gast = gast, art = rng:next() < 0.5 and "job_pfuetze" or "land_rock",
        wer = ({"reithof_down", "sammlerin_down", "zuechter_down"})[rng:int(1, 3)]}
      x = x + 70 + rng:int(0, 40)
    end
    st.ende = x + 60
  else
    st.pos, st.seg, st.stun, st.dir = 0, 0, 0, 1
    st.zone = 0.14 + Care.effective(d, "staerke") / 100 * 0.16      -- Breite des grünen Bereichs
    st.speed = 0.028
  end
  return st
end

-- Fortschritt 0–1 (für die Energie-Anzeige).
function JS.progress(st)
  if st.kind == "post" then return min(1, st.x / (st.boxes[#st.boxes].x + 200)) end
  if st.kind == "taxi" then return min(1, st.x / st.ende) end
  return min(1, max(st.t / JS.PFLUG_TIME, st.seg / JS.PFLUG_SEG))
end

-- Ergebnis 0–1.
function JS.anteil(st)
  if st.kind == "post" then return mid(0, (st.hits - 0.5 * st.miss) / JS.POST_N, 1) end
  if st.kind == "taxi" then return mid(0, (st.picked - 0.5 * st.hits) / max(1, st.gaeste), 1) end
  return mid(0, st.seg / JS.PFLUG_SEG, 1)
end

-- Ein Frame. inp: {a = A gedrückt (Flanke), up, down}.
function JS.update(st, inp)
  if st.done then return end
  st.t = st.t + 1
  if st.kind == "post" then
    st.x = st.x + st.v
    st.cool = max(0, st.cool - 1)
    if inp.a and st.cool == 0 then
      st.cool = JS.POST_COOL
      local hit
      for _, b in ipairs(st.boxes) do
        if not b.done and math.abs(b.x - st.x - JS.POST_X) <= JS.POST_WINDOW then hit = b end
      end
      if hit then hit.done, st.hits = "ok", st.hits + 1 SFX.ok() else st.miss = st.miss + 1 SFX.snort() end
      st.letters[#st.letters + 1] = {t = 0, ok = hit ~= nil}
    end
    for _, b in ipairs(st.boxes) do
      if not b.done and b.x - st.x < JS.POST_X - JS.POST_WINDOW - 1 then b.done = "verpasst" end
    end
    for i = #st.letters, 1, -1 do
      local l = st.letters[i]
      l.t = l.t + 1
      if l.t > 16 then table.remove(st.letters, i) end
    end
    if st.x > st.boxes[#st.boxes].x + 200 then st.done = true end
  elseif st.kind == "taxi" then
    st.x = st.x + st.v
    if inp.up then st.lane = max(1, st.lane - 1) end
    if inp.down then st.lane = min(3, st.lane + 1) end
    st.shake = max(0, st.shake - 1)
    for _, o in ipairs(st.things) do
      local sx = o.x - st.x
      if not o.weg and o.lane == st.lane and sx < JS.TAXI_X + 46 and sx > JS.TAXI_X - 8 then
        o.weg = true
        if o.gast then st.picked = st.picked + 1 SFX.ok() else st.hits, st.shake = st.hits + 1, 20 SFX.land() end
      end
    end
    if st.x >= st.ende then st.done = true end
  else
    if st.stun > 0 then
      st.stun = st.stun - 1
    else
      st.pos = st.pos + st.speed * st.dir
      if st.pos >= 1 then st.pos, st.dir = 1, -1 elseif st.pos <= 0 then st.pos, st.dir = 0, 1 end
      if inp.a then
        if math.abs(st.pos - 0.5) <= st.zone / 2 then st.seg = st.seg + 1 SFX.ok()
        else st.stun = JS.PFLUG_STUN SFX.snort() end
      end
    end
    if st.seg >= JS.PFLUG_SEG or st.t >= JS.PFLUG_TIME then st.done = true end
  end
end

-- ---- Bildschirm ----

local C = Stage.COLORS
local SKY, GRASS, ROAD, FIELD, FURROW = rgb(0x8f, 0xc8, 0xe6), rgb(0x7f, 0xb0, 0x4f), rgb(0xd4, 0xb0, 0x77),
  rgb(0x8a, 0x5a, 0x36), rgb(0x60, 0x3c, 0x24)
local GREEN = rgb(0x5f, 0xc0, 0x50)

-- Pferd mit Reiter (Seitenansicht nach rechts).
local function rider(d, x, y, pose)
  local body = K.rasse(d.rasse).koerper
  G.draw(d.farbe, body, pose, x, y, false, d.schmuck)
  local _, bh = G.size(d.farbe, body, "side")
  S.draw("player_side", x - 6, y - bh + 4 - 10)
end

local function draw_post(st)
  cls(SKY)
  rectfill(0, 130, SCREEN_W - 1, SCREEN_H - 1, GRASS)
  rectfill(0, 168, SCREEN_W - 1, 196, ROAD)
  for k = 0, 8 do                                  -- Zaunpfähle zeigen das Tempo
    local px = flr(k * 40 - st.x % 40)
    rectfill(px, 140, px + 2, 160, rgb(0x7b, 0x4c, 0x2b))
  end
  line(0, 146, SCREEN_W - 1, 146, rgb(0x7b, 0x4c, 0x2b))
  for _, b in ipairs(st.boxes) do
    local sx = flr(b.x - st.x)
    if sx > -20 and sx < SCREEN_W then
      S.draw("job_briefkasten", sx - 5, 152)
      if b.done == "ok" then S.draw("job_brief", sx - 3, 150) end
    end
  end
  local pose = ((st.t // 6) % 2 == 0) and "gallop1" or "gallop2"
  rider(st.d, JS.POST_X - 14, 186, pose)
  for _, l in ipairs(st.letters) do
    S.draw("job_brief", JS.POST_X - 2 + l.t // 3, 150 + l.t // 2)
  end
  rect(JS.POST_X - JS.POST_WINDOW, 150, JS.POST_X + JS.POST_WINDOW, 168, C.gold)
  print("Briefe " .. st.hits .. "/" .. JS.POST_N .. (st.miss > 0 and ("  daneben " .. st.miss) or ""), 8, 20, C.panel)
  return "A: Brief werfen (Kasten im Rahmen)"
end

local function draw_taxi(st)
  cls(GRASS)
  rectfill(0, 96, SCREEN_W - 1, 200, ROAD)
  for k = 0, 10 do
    local px = flr(k * 32 - st.x % 32)
    rectfill(px, 134, px + 14, 135, rgb(0xf3, 0xe5, 0xc4))
    rectfill(px, 168, px + 14, 169, rgb(0xf3, 0xe5, 0xc4))
  end
  for _, o in ipairs(st.things) do
    local sx = flr(o.x - st.x)
    if not o.weg and sx > -20 and sx < SCREEN_W then
      local y = JS.TAXI_LANES[o.lane]
      if o.gast then S.draw(o.wer, sx, y - 22) else S.draw(o.art, sx, y - 6) end
    end
  end
  local y = JS.TAXI_LANES[st.lane] + ((st.shake > 0 and st.t % 4 < 2) and 1 or 0)
  local pose = ((st.t // 8) % 2 == 0) and "side" or "side_walk"
  S.draw("job_kutsche", JS.TAXI_X - 4, y - 16)
  G.draw(st.d.farbe, K.rasse(st.d.rasse).koerper, pose, JS.TAXI_X + 34, y, false, st.d.schmuck)
  print("Fahrgäste " .. st.picked .. "/" .. st.gaeste .. (st.hits > 0 and ("  Rumpler " .. st.hits) or ""), 8, 20, C.panel)
  return "^/v: Spur, Fahrgäste einsammeln"
end

local function draw_pflug(st)
  cls(GRASS)
  rectfill(20, 50, SCREEN_W - 21, 170, FIELD)
  local per = JS.PFLUG_SEG // 3
  local seg_w = (SCREEN_W - 60) // per
  for r = 0, 2 do
    local fy = 74 + r * 36
    local n = mid(0, st.seg - r * per, per)
    if n > 0 then rectfill(30, fy - 2, 30 + n * seg_w, fy + 1, FURROW) end
  end
  local row = min(2, st.seg // per)
  local n = st.seg - row * per
  local hx = 30 + n * seg_w + 34
  local fy = 74 + row * 36
  S.draw("job_pflug", hx - 30, fy - 8)
  G.draw(st.d.farbe, K.rasse(st.d.rasse).koerper, (st.t // 10) % 2 == 0 and "side" or "side_walk", hx, fy + 2, false, st.d.schmuck)
  -- Zeigerleiste
  local bx0, bx1, by = 40, SCREEN_W - 41, 186
  rectfill(bx0, by, bx1, by + 10, C.panel)
  local zw = flr((bx1 - bx0) * st.zone)
  local mx = (bx0 + bx1) // 2
  rectfill(mx - zw // 2, by + 1, mx + zw // 2, by + 9, GREEN)
  local px = bx0 + flr((bx1 - bx0) * st.pos)
  rectfill(px - 1, by - 3, px + 1, by + 13, st.stun > 0 and C.red or C.text)
  local left = max(0, JS.PFLUG_TIME - st.t) // 60
  print("Furche " .. st.seg .. "/" .. JS.PFLUG_SEG .. "   noch " .. left .. " s", 8, 20, C.panel)
  return "A: ziehen, wenn der Zeiger grün ist"
end

-- Bildschirm des Minispiels. done(anteil) nach dem Ende und A.
function JS.screen(ctx, job, d, done)
  local st = JS.new(job, d, Rng.new((ctx.seed or 1) + (ctx.clock and ctx.clock.day or 1) * 13))
  local s = {full = true}
  local finished = false
  local wait = btn(BTN_A)
  function s.update(nav)
    if wait and not btn(BTN_A) then wait = false end
    local a = btnp(BTN_A) and not wait
    if st.done then
      if a and not finished then
        finished = true
        nav.pop()
        done(JS.anteil(st))
      end
      return
    end
    JS.update(st, {a = a, up = btnp(BTN_UP), down = btnp(BTN_DOWN)})
  end
  function s.draw()
    local hint
    if st.kind == "post" then hint = draw_post(st)
    elseif st.kind == "taxi" then hint = draw_taxi(st)
    else hint = draw_pflug(st) end
    rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
    print(job.name .. ": " .. d.name, 6, 3, C.gold)
    -- Energie des Pferds geht mit dem Job herunter
    local e = st.energie0 - job.energie * JS.progress(st)
    local w, x0 = 70, SCREEN_W - 76
    print("Energie", x0 - textw("Energie") - 4, 3, C.text)
    rectfill(x0, 4, x0 + w, 9, C.panel_light)
    rectfill(x0, 4, x0 + flr(w * mid(0, e, 100) / 100), 9, e < 15 and C.red or C.gold)
    rectfill(0, SCREEN_H - 13, SCREEN_W - 1, SCREEN_H - 1, rgb(0x3d, 0x2c, 0x25))
    print(st.done and "A: weiter" or hint, 6, SCREEN_H - 10, C.text)
    if st.done then
      local Jobs = require("game.jobs")
      local pct = flr(JS.anteil(st) * 100 + 0.5)
      Stage.panel(60, 80, SCREEN_W - 61, 140)
      Stage.center("Geschafft: " .. pct .. " %", 92, C.gold, 2)
      Stage.center("Lohn " .. Jobs.lohn(d, job, JS.anteil(st)) .. " G, Energie -" .. job.energie, 120, C.text)
    end
  end
  return s
end

return JS
