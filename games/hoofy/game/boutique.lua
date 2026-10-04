-- Editor der Garderobe im blauen Haus („Mähne & Masche“, game/garderobe.lua), Vollbild in Lila.
-- Links ein Spiegel: die Figur groß von vorn, klein von der Seite (läuft) und von hinten. Rechts die Kategorien
-- Hut, Haarfarbe, Frisur, Oberteil, Farbe, Unterteil, Farbe. ↑↓ wählt die Kategorie, ←→ probiert an: was man
-- schon hat, wird gleich angezogen, anderes nur anprobiert. A kauft (und zieht an), B geht; nicht Gekauftes
-- zieht man dabei wieder aus.
local Garderobe = require("game.garderobe")
local Figur = require("game.figur")
local Stage = require("game.stage")
local SFX = require("game.sfx")
local S = require("sprites")

local B = {}

B.NAME = "Mähne & Masche"

-- Lila Farben des Editors
B.COLORS = {
  bg = rgb(0x24, 0x14, 0x34),       -- Grund
  dark = rgb(0x16, 0x0c, 0x22),     -- Kopf, Fuß
  frame = rgb(0x7a, 0x52, 0xb0),    -- Spiegelrahmen
  frame_light = rgb(0xb0, 0x88, 0xe0),
  mirror = rgb(0x3a, 0x26, 0x56),   -- Spiegelfläche
  sheen = rgb(0x48, 0x32, 0x68),    -- Glanz auf dem Spiegel
  floor = rgb(0x2c, 0x1c, 0x44),    -- Lichtfleck am Boden
  panel = rgb(0x30, 0x1d, 0x46),    -- Infokasten
  sel = rgb(0x55, 0x34, 0x80),      -- gewählte Zeile
  lilac = rgb(0xd0, 0xaa, 0xf6),    -- Akzent
  pink = rgb(0xf4, 0xa8, 0xe8),
  dim = rgb(0xa8, 0x8e, 0xca),      -- Beschriftung, Nebentext
  pale = rgb(0x6c, 0x54, 0x90),     -- Pfeile der anderen Zeilen
  text = rgb(0xfb, 0xf6, 0xff),
  gold = Stage.COLORS.gold,
  red = rgb(0xf0, 0x70, 0x8a),
}
local C = B.COLORS

-- Lage auf dem Bildschirm
B.BIG = {x = 20, y = 92, scale = 6}       -- Figur von vorn (linke obere Ecke des 12×20-Bilds)
B.SIDE = {x = 114, y = 58, scale = 2}     -- von der Seite, läuft
B.BACK = {x = 114, y = 140, scale = 2}    -- von hinten
B.ROW_X, B.ROW_Y, B.ROW_H = 148, 18, 21
B.INFO_Y = 169
local LABEL = {hut = "Hut", haarfarbe = "Haarfarbe", frisur = "Frisur", oberteil = "Oberteil", ofarbe = "Farbe",
  unterteil = "Unterteil", ufarbe = "Farbe"}
local INDENT = {ofarbe = 8, ufarbe = 8}

local function copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

-- Lichtfleck (Ellipse aus Streifen) mit Mitte cx, cy, halber Breite rx, halber Höhe ry.
local function spot(cx, cy, rx, ry)
  for dy = -ry, ry do
    local w = flr(rx * math.sqrt(1 - (dy / (ry + 0.5)) ^ 2))
    rectfill(cx - w, cy + dy, cx + w, cy + dy, C.floor)
  end
end

local function footer(text)
  rectfill(0, SCREEN_H - 13, SCREEN_W - 1, SCREEN_H - 1, C.dark)
  line(0, SCREEN_H - 13, SCREEN_W - 1, SCREEN_H - 13, C.sel)
  local keys = {["^v"] = {BTN_UP, BTN_DOWN, BTN_LEFT, BTN_RIGHT}, A = {BTN_A}, B = {BTN_B}}
  local x, pos = 6, 1
  while pos <= #text do
    local a, b = text:find("%s%s+", pos)
    local part = text:sub(pos, (a or #text + 1) - 1)
    local hot = false
    for _, k in ipairs(keys[part:match("^(%S+)")] or {}) do if btn(k) then hot = true end end
    print(part, x, SCREEN_H - 10, hot and C.lilac or C.text)
    x = x + textw(text:sub(pos, b or #text))
    pos = (b or #text) + 1
  end
end

-- ctx: Spielzustand (ctx.outfit, ctx.money, ctx.max_gebiet).
function B.new(ctx)
  ctx.outfit = Garderobe.pruefen(ctx.outfit)
  local o = ctx.outfit
  local probe = copy(o.an)          -- was die Figur gerade zeigt (auch Anprobiertes)
  local row, t = 1, 0
  local msg, msg_t, sparkle = nil, 0, 0
  local s = {full = true}

  local function kat() return Garderobe.KATEGORIEN[row] end
  local function cur(k) return Garderobe.eintrag(k.id, probe[k.id]) end
  local function anprobiert()
    for _, k in ipairs(Garderobe.KATEGORIEN) do
      if not Garderobe.besitzt(o, k.id, probe[k.id]) then return true end
    end
    return false
  end
  local function say(text) msg, msg_t = text, 150 end

  function s.update(nav)
    t = t + 1
    if msg_t > 0 then msg_t = msg_t - 1 end
    if sparkle > 0 then sparkle = sparkle - 1 end
    local n = #Garderobe.KATEGORIEN
    if btnp(BTN_UP) then row = (row - 2) % n + 1 SFX.select() end
    if btnp(BTN_DOWN) then row = row % n + 1 SFX.select() end
    local k = kat()
    local d = (btnp(BTN_RIGHT) and 1 or 0) - (btnp(BTN_LEFT) and 1 or 0)
    if d ~= 0 then
      local i = (k.index[probe[k.id]] + d - 1) % #k.liste + 1
      local id = k.liste[i].id
      probe[k.id] = id
      if Garderobe.besitzt(o, k.id, id) then o.an[k.id] = id end   -- schon gekauft: gleich anziehen
      SFX.select()
    end
    if btnp(BTN_A) then
      local it = cur(k)
      local ok, why = Garderobe.kaufen(ctx, k.id, it.id)
      if ok then
        SFX.ok()
        sparkle = 50
        say(it.name .. " gekauft!")
      elseif why == "hat" then
        SFX.select()
        say("Gehört dir schon.")
      elseif why == "gesperrt" then
        SFX.snort()
        say("Gibt es erst ab Gebiet " .. it.ab .. ".")
      else
        SFX.snort()
        say("Zu wenig Geld.")
      end
    end
    if btnp(BTN_B) then
      SFX.back()
      nav.pop()
    end
  end

  local function draw_mirror()
    rectfill(4, 17, 143, 225, C.frame)
    rect(5, 18, 142, 224, C.frame_light)
    rectfill(7, 20, 140, 222, C.mirror)
    -- Glanz: zwei schräge Streifen oben links
    clip(7, 20, 134, 203)
    for i = 0, 5 do line(12 + i, 20, -40 + i, 72, C.sheen) end
    for i = 0, 2 do line(30 + i, 20, -22 + i, 72, C.sheen) end
    clip()
    local b, sd, bk = B.BIG, B.SIDE, B.BACK
    spot(b.x + 36, b.y + 118, 34, 6)
    spot(sd.x + 12, sd.y + 39, 14, 3)
    spot(bk.x + 12, bk.y + 39, 14, 3)
    clip(7, 20, 134, 203)
    Figur.draw(probe, "down", 1, b.x, b.y, false, b.scale)
    Figur.draw(probe, "side", (t // 16) % 2 + 1, sd.x, sd.y, false, sd.scale)
    Figur.draw(probe, "up", 1, bk.x, bk.y, false, bk.scale)
    if sparkle > 0 then                -- Glitzern nach dem Kauf
      for i = 0, 7 do
        local a = i * 0.785 + t * 0.05
        local r = 40 + (50 - sparkle) * 0.6
        local x, y = b.x + 36 + math.cos(a) * r, b.y + 50 + math.sin(a) * r * 1.2
        rectfill(x - 1, y, x + 1, y, C.pink)
        rectfill(x, y - 1, x, y + 1, C.text)
      end
    end
    clip()
  end

  local function draw_rows()
    for i, k in ipairs(Garderobe.KATEGORIEN) do
      local y = B.ROW_Y + (i - 1) * B.ROW_H
      local it = cur(k)
      local selected = i == row
      if selected then
        rectfill(B.ROW_X, y, SCREEN_W - 5, y + B.ROW_H - 2, C.sel)
        rectfill(B.ROW_X, y, B.ROW_X + 1, y + B.ROW_H - 2, C.lilac)
      end
      print(LABEL[k.id], B.ROW_X + 6 + (INDENT[k.id] or 0), y + 2, selected and C.lilac or C.dim)
      -- rechts: Haken (hast du), Preis (kaufbar) oder Schloss (gibt es noch nicht)
      if Garderobe.besitzt(o, k.id, it.id) then
        S.draw("gard_haken", SCREEN_W - 16, y + 2)
      elseif not Garderobe.frei(ctx, it) then
        S.draw("gard_schloss", SCREEN_W - 16, y + 1)
      else
        local p = it.preis .. " G"
        print(p, SCREEN_W - 9 - textw(p), y + 2, ctx.money >= it.preis and C.gold or C.red)
      end
      local arrow = selected and C.lilac or C.pale
      print("<", B.ROW_X + 6, y + 11, arrow)
      print(">", SCREEN_W - 16, y + 11, arrow)
      local x = B.ROW_X + 18
      local sw = Garderobe.farbe(k.id, it.id)
      if sw then
        rectfill(x, y + 11, x + 7, y + 18, C.dark)
        rectfill(x + 1, y + 12, x + 6, y + 17, sw)
        x = x + 12
      end
      local own = Garderobe.besitzt(o, k.id, it.id)
      print(it.name, x, y + 11, own and C.text or (Garderobe.frei(ctx, it) and C.pink or C.dim))
    end
  end

  local function draw_info()
    local y0 = B.INFO_Y
    rectfill(B.ROW_X, y0, SCREEN_W - 5, 222, C.panel)
    local k = kat()
    local it = cur(k)
    local i = k.index[it.id] .. "/" .. #k.liste
    print(it.name, B.ROW_X + 6, y0 + 5, C.gold)
    print(i, SCREEN_W - 9 - textw(i), y0 + 5, C.dim)
    local line2
    if Garderobe.besitzt(o, k.id, it.id) then
      line2 = "Gehört dir."
    elseif not Garderobe.frei(ctx, it) then
      line2 = "Erst ab Gebiet " .. it.ab .. ":"
    else
      line2 = "Kostet " .. it.preis .. " G."
    end
    print(line2, B.ROW_X + 6, y0 + 17, C.text)
    local line3
    if not Garderobe.besitzt(o, k.id, it.id) and not Garderobe.frei(ctx, it) then
      line3 = Garderobe.gebiet_name(it.ab) .. "."
    elseif not Garderobe.besitzt(o, k.id, it.id) then
      line3 = ctx.money >= it.preis and "A: kaufen" or "Zu wenig Geld."
    end
    if line3 then print(line3, B.ROW_X + 6, y0 + 27, C.dim) end
    if msg and msg_t > 0 then
      print(msg, B.ROW_X + 6, y0 + 40, C.pink)
    elseif anprobiert() then
      print("Nur anprobiert", B.ROW_X + 6, y0 + 40, C.dim)
    end
  end

  function s.draw()
    cls(C.bg)
    rectfill(0, 0, SCREEN_W - 1, 13, C.dark)
    print(B.NAME, 6, 3, C.lilac)
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    draw_mirror()
    draw_rows()
    draw_info()
    footer("^v </>: wählen  A: kaufen  B: fertig")
  end

  -- für Tests: was gerade anprobiert ist
  function s.probe() return probe end
  return s
end

-- Schild vor dem blauen Haus, solange die Garderobe zu hat (Kundenstopper neben dem Weg zur Tür).
B.SCHILD = {1, 0}            -- Kachel relativ zum Ort „wohnhaus“ (vor der Tür)
function B.schild(ctx)
  local pl = ctx.area.places.wohnhaus
  local e = {x = (pl[1] + B.SCHILD[1]) * 16 + 10, y = pl[2] * 16 + 15, reach = 24}
  function e.draw()
    if Garderobe.offen(ctx) then return end
    S.draw("schild_bald", e.x - 10, e.y - 16)
  end
  return e
end

return B
