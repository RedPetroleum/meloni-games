-- Stall von innen (Rückmeldung 1.2.1): A an der Stalltür. Boxen je nach Größe (S 2, M 4 in einer Reihe,
-- L 8 und XL 12 in zwei Reihen mit Stallgasse), Holz und Boden je Größe anders. Pferd wählen und A: das
-- Pferdemenü (pflegen, füttern, herausholen, züchten …). Leere Box und A: das Pferd an der Leine einstellen.
local K = require("game.katalog")
local G = require("game.horse_gfx")
local Stage = require("game.stage")
local Farm = require("game.farm")
local Bubbles = require("game.bubbles")
local HorseMenu = require("game.horse_menu")
local SFX = require("game.sfx")
local U = require("lib.util")
local S = require("sprites")

local SV = {}

local C = Stage.COLORS

-- Aussehen je Stallgröße: Boxen je Reihe, Reihen, Wand, Bretter, Pfosten, Boden, Gasse.
local LOOK = {
  stall_s = {cols = 2, rows = 1, wall = rgb(0xb0, 0x7a, 0x44), plank = rgb(0x93, 0x63, 0x36), post = rgb(0x6b, 0x45, 0x26),
    floor = rgb(0xd9, 0xb3, 0x5a), straw = rgb(0xf3, 0xd5, 0x7f), aisle = rgb(0x8a, 0x5a, 0x36), name = "Stall S"},
  stall_m = {cols = 4, rows = 1, wall = rgb(0x9a, 0x62, 0x38), plank = rgb(0x7b, 0x4c, 0x2b), post = rgb(0x55, 0x33, 0x20),
    floor = rgb(0xd9, 0xb3, 0x5a), straw = rgb(0xf3, 0xd5, 0x7f), aisle = rgb(0x8a, 0x5a, 0x36), name = "Stall M", window = true},
  stall_l = {cols = 4, rows = 2, wall = rgb(0xa8, 0x4a, 0x3a), plank = rgb(0x8a, 0x31, 0x29), post = rgb(0x55, 0x33, 0x20),
    floor = rgb(0xd9, 0xb3, 0x5a), straw = rgb(0xf3, 0xd5, 0x7f), aisle = rgb(0x9a, 0xa0, 0xa6), name = "Stall L", window = true},
  stall_xl = {cols = 6, rows = 2, wall = rgb(0x6b, 0x45, 0x26), plank = rgb(0x55, 0x33, 0x20), post = rgb(0x3a, 0x27, 0x21),
    floor = rgb(0xe0, 0xc0, 0x70), straw = rgb(0xf7, 0xe0, 0x95), aisle = rgb(0xc8, 0xcd, 0xd1), name = "Stall XL",
    window = true, lamp = true, trim = rgb(0xf3, 0xd5, 0x7f)},
}

local TOP, BOTTOM = 15, SCREEN_H - 26      -- Bereich zwischen Kopfzeile und Infozeile

-- Rechteck der Box i (1 … cols × rows): x0, y0, x1, y1.
local function box_rect(look, i)
  local c, r = (i - 1) % look.cols, (i - 1) // look.cols
  local w = (SCREEN_W - 8) // look.cols
  local x0 = 4 + c * w
  if look.rows == 1 then return x0, 60, x0 + w - 1, 182 end
  local h = (BOTTOM - TOP - 18) // 2
  local y0 = TOP + 2 + r * (h + 16)
  return x0, y0, x0 + w - 1, y0 + h - 1
end

-- Gasse zwischen den Reihen (zwei Reihen) bzw. vor den Boxen (eine Reihe)
local function draw_room(look)
  cls(look.wall)
  for y = TOP, BOTTOM, 6 do line(0, y, SCREEN_W - 1, y, look.plank) end
  if look.rows == 1 then
    rectfill(0, 183, SCREEN_W - 1, BOTTOM, look.aisle)
    if look.window then
      for x = 40, SCREEN_W - 60, 120 do
        rectfill(x, 22, x + 36, 46, look.post)
        rectfill(x + 2, 24, x + 34, 44, rgb(0x8f, 0xc8, 0xe6))
        line(x + 18, 24, x + 18, 44, look.post)
      end
    end
  else
    local _, _, _, y1 = box_rect(look, 1)
    rectfill(0, y1 + 1, SCREEN_W - 1, y1 + 15, look.aisle)
    for x = 0, SCREEN_W - 1, 16 do line(x, y1 + 1, x, y1 + 15, look.post) end
  end
end

local function draw_box(look, i, d, h, sel, now)
  local x0, y0, x1, y1 = box_rect(look, i)
  local fy = y1 - 14                      -- Stroh beginnt hier
  rectfill(x0, fy, x1, y1, look.floor)
  for k = 0, 17 do                        -- Halme an festen Stellen
    local sx = x0 + 2 + flr(U.hash(i, k, 3) * (x1 - x0 - 4))
    local sy = fy + 1 + flr(U.hash(i, k, 9) * 12)
    line(sx, sy, sx + 2, sy - 1, look.straw)
  end
  rectfill(x0, y0, x0 + 2, y1, look.post)
  rectfill(x1 - 2, y0, x1, y1, look.post)
  rectfill(x0, y0, x1, y0 + 2, look.post)
  if look.trim then line(x0, y0 + 3, x1, y0 + 3, look.trim) end
  if look.lamp and i % look.cols ~= 0 then circfill(x1, y0 + 12, 3, rgb(0xff, 0xe0, 0x70)) end
  local cx = (x0 + x1) // 2
  if d then
    -- Pferd: Kopf zur Gasse; die Hälfte schaut nach links, die Hälfte nach rechts
    G.draw(d.farbe, K.rasse(d.rasse).koerper, "side", cx, y1 - 5, i % 2 == 0, d.schmuck)
    local b = h and Bubbles.choose(h, now)
    if b then Bubbles.draw(S, b, cx + (i % 2 == 0 and -8 or 8), y1 - 50, now) end
    local name = d.name
    while textw(name) > x1 - x0 - 8 do name = name:sub(1, #name - 1) end
    local nw = textw(name)
    rectfill(cx - nw // 2 - 2, y0 + 4, cx + nw // 2 + 2, y0 + 13, look.post)
    print(name, cx - nw // 2, y0 + 5, d.traechtig and C.gold or C.text)
  else
    local t = "frei"
    print(t, cx - textw(t) // 2, (y0 + fy) // 2, look.plank)
  end
  -- Halbtür vorn: drei Querbretter
  for k = 0, 2 do line(x0 + 3, y1 - 2 - k * 4, x1 - 3, y1 - 2 - k * 4, look.post) end
  if sel then
    rect(x0, y0, x1, y1, C.gold)
    rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, C.gold)
  end
end

-- env: wie für das Pferdemenü (ctx, wild, nav, say …); door: Stalltür aus Farm.stall_doors (door.b = Gebäude).
function SV.new(env, door)
  local ctx, wild = env.ctx, env.wild
  local look = LOOK[door.id] or LOOK.stall_s
  local n = look.cols * look.rows
  local sel, menu, msg, msg_t = 1, nil, nil, 0
  local s = {full = true}
  local now = 0

  local function say(text, frames) msg, msg_t = text, frames or 150 end
  local function my_horses()
    for _, e in ipairs(Farm.stall_boxes(ctx.area.farm, ctx.herd)) do
      if e.b == door.b then return e.pferde, e.plaetze end
    end
    return {}, n
  end
  local function horse_of(d)
    for _, h in ipairs(ctx.herd_horses) do if h.data == d then return h end end
  end
  local leave = false
  local menv = {ctx = ctx, wild = wild, nav = env.nav, say = say, in_stall = true, on_leave = function() leave = true end}

  function s.update(nav)
    now = now + 1
    if msg_t > 0 then msg_t = msg_t - 1 end
    if menu then
      if menu:update() then menu = nil end
      if leave then nav.pop() env.say(msg or "", 150) end
      return
    end
    local cols = look.cols
    if btnp(BTN_LEFT) then sel = (sel - 2) % n + 1; SFX.select() end
    if btnp(BTN_RIGHT) then sel = sel % n + 1; SFX.select() end
    if (btnp(BTN_UP) or btnp(BTN_DOWN)) and look.rows > 1 then sel = (sel - 1 + cols) % n + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() return end
    if btnp(BTN_A) then
      local list = my_horses()
      local d = list[sel]
      if d then
        local h = horse_of(d)
        if h then menu = HorseMenu.open(menv, h) SFX.select() end
      else
        -- leere Box: das Pferd an der Leine einstellen
        local lh = ctx.lead[1]
        if not lh then
          SFX.snort() say("Die Box ist frei. Bring ein Pferd an der Leine mit, um es einzustellen.")
        else
          local ok, why = wild:house(lh, "stall")
          if ok then SFX.ok() say(lh.data.name .. " steht jetzt im Stall.")
          else SFX.snort() say("Geht nicht: " .. tostring(why) .. ".") end
        end
      end
    end
  end

  function s.draw()
    draw_room(look)
    local list, plaetze = my_horses()
    for i = 1, n do
      local d = list[i]
      draw_box(look, i, d, d and horse_of(d), i == sel and not menu, now)
    end
    -- Kopfzeile und Info zur gewählten Box
    rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
    print(look.name .. ": " .. #list .. "/" .. plaetze, 6, 3, C.gold)
    local all = Farm.capacity(ctx.area.farm).stall
    local t = "alle Ställe " .. Farm.count(ctx.herd, "stall") .. "/" .. all
    print(t, SCREEN_W - textw(t) - 6, 3, C.dim)
    rectfill(0, BOTTOM + 1, SCREEN_W - 1, SCREEN_H - 14, C.panel)
    local d = list[sel]
    local info
    if d then
      local sex = d.sex == "m" and (d.alter < 1 and "Hengstfohlen" or "Hengst") or (d.alter < 1 and "Stutfohlen" or "Stute")
      local day = ctx.clock and ctx.clock.day or 1
      local extra = d.traechtig and (", Fohlen an Tag " .. d.traechtig.tag)
        or (d.zucht_pause and d.zucht_pause > day and (", Zuchtpause bis Tag " .. d.zucht_pause)) or ""
      info = d.name .. ": " .. sex .. ", " .. K.rasse(d.rasse).name .. extra
    else
      info = ctx.lead[1] and ("A: " .. ctx.lead[1].data.name .. " einstellen") or "Box frei"
    end
    print(info, 6, BOTTOM + 3, C.text)
    rectfill(0, SCREEN_H - 13, SCREEN_W - 1, SCREEN_H - 1, rgb(0x3d, 0x2c, 0x25))
    print(d and "A: Pferd  </>: Box  B: hinaus" or "A: einstellen  </>: Box  B: hinaus", 6, SCREEN_H - 10, C.text)
    if menu then menu:draw(SCREEN_W // 2, SCREEN_H // 2) end
    if msg and msg_t > 0 then
      local lines = U.wrap(msg, SCREEN_W - 40)
      local h = #lines * 11 + 10
      Stage.panel(10, 18, SCREEN_W - 11, 18 + h)
      for i, l in ipairs(lines) do Stage.center(l, 24 + (i - 1) * 11, C.gold) end
    end
  end
  return s
end

return SV
