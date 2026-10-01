-- Vollbild-Menüs (E5, E7): Pausenmenü, Pferdeliste, Pferde-Info, Inventar, Bildschirmtastatur.
-- Jeder Bildschirm ist {update = function(nav), draw = function()}. nav hat push(screen) und pop().
-- Bedienung überall: Steuerkreuz wählen, A bestätigen, B zurück.
local K = require("game.katalog")
local H = require("game.horse_model")
local G = require("game.horse_gfx")
local Stage = require("game.stage")
local Menu = require("game.menu")
local Tiles = require("game.tiles")
local Explore = require("game.explore")
local SFX = require("game.sfx")
local Economy = require("game.economy")
local Value = require("game.value")
local Market = require("game.market")
local Buyers = require("game.buyers")
local Orders = require("game.orders")
local Jobs = require("game.jobs")
local Farm = require("game.farm")

local Screens = {}

local C = Stage.COLORS

local function header(title)
  rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
  print(title, 6, 3, C.gold)
end

-- Tastenleiste unten: etwas heller als der Bildschirm, mit Trennlinie
local FOOTER_BG = rgb(0x3d, 0x2c, 0x25)
local function footer(text)
  rectfill(0, SCREEN_H - 13, SCREEN_W - 1, SCREEN_H - 1, FOOTER_BG)
  line(0, SCREEN_H - 13, SCREEN_W - 1, SCREEN_H - 13, C.panel_light)
  print(text, 6, SCREEN_H - 10, C.text)
end

local ORT = {stall = "im Stall", weide = "auf der Weide", frei = "frei auf dem Hof"}

local function place_of(data)
  return data.ort and ORT[data.ort] or "an der Leine"
end

-- ---- Bildschirmtastatur (E7) ----

local ROWS = {
  "ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZÄÖÜß-", "abcdefghij", "klmnopqrst", "uvwxyzäöü .",
}

-- title, text (Startwert), max Zeichen, on_done(text) oder nil bei Abbruch
function Screens.keyboard(title, text, max, on_done, rows)
  local ROWS = rows or ROWS
  local chars = {}
  for _, row in ipairs(ROWS) do
    local r = {}
    for _, c in utf8.codes(row) do r[#r + 1] = utf8.char(c) end
    chars[#chars + 1] = r
  end
  chars[#chars + 1] = {"LÖSCHEN", "FERTIG"}
  local cx, cy = 1, 1
  local s = {}
  local function len(str) return utf8.len(str) or #str end
  function s.update(nav)
    local row = chars[cy]
    if btnp(BTN_LEFT) then cx = cx - 1; SFX.select() end
    if btnp(BTN_RIGHT) then cx = cx + 1; SFX.select() end
    if btnp(BTN_UP) then cy = cy - 1; SFX.select() end
    if btnp(BTN_DOWN) then cy = cy + 1; SFX.select() end
    cy = (cy - 1) % #chars + 1
    row = chars[cy]
    cx = (cx - 1) % #row + 1
    if btnp(BTN_B) then
      if len(text) > 0 then text = text:sub(1, utf8.offset(text, -1) - 1) else nav.pop() end
    elseif btnp(BTN_A) then
      SFX.key()
      local key = row[cx]
      if key == "LÖSCHEN" then
        if len(text) > 0 then text = text:sub(1, utf8.offset(text, -1) - 1) end
      elseif key == "FERTIG" then
        nav.pop()
        if on_done and len(text) > 0 then on_done(text) end
      elseif len(text) < max then
        text = text .. key
      end
    end
  end
  function s.draw()
    cls(C.panel)
    header(title)
    Stage.panel(40, 24, 279, 46)
    local shown = text .. ((frame() // 20) % 2 == 0 and "_" or " ")
    print(shown, 52, 31, C.text, 2)
    print(len(text) .. "/" .. max, 240, 52, C.dim)
    for ry, row in ipairs(chars) do
      if ry <= #ROWS then
        for rx, key in ipairs(row) do
          local x, y = 40 + (rx - 1) * 22, 66 + (ry - 1) * 22
          local sel = rx == cx and ry == cy
          rectfill(x, y, x + 19, y + 19, sel and C.gold or C.panel_light)
          print(key, x + 10 - textw(key) // 2, y + 6, sel and C.panel or C.text)
        end
      else
        for rx, key in ipairs(row) do
          local x, y = 40 + (rx - 1) * 100, 66 + (ry - 1) * 22
          local sel = rx == cx and ry == cy
          rectfill(x, y, x + 94, y + 19, sel and C.gold or C.panel_light)
          print(key, x + 47 - textw(key) // 2, y + 6, sel and C.panel or C.text)
        end
      end
    end
    footer("A: Zeichen   B: zurück/löschen")
  end
  s.full = true
  return s
end

-- ---- Pferde-Info (Rückmeldung 0.5.3: aufgeräumt, Balken mit Unterteilung alle 20) ----

local BAR_X, BAR_W = 76, 196           -- Balken: 100 Punkte = 196 px
local SKILL_COL = rgb(0x9a, 0xdc, 0xb4) -- Fähigkeiten (Mintgrün, passt zum Blau; Gold bleibt Geld und Titeln)
local GEN_COL = rgb(0x9a, 0xdc, 0xb4)   -- Fähigkeit aus den Genen (Mint wie die Überschrift)
local TRAIN_COL = rgb(0x3a, 0xb0, 0x8e) -- dazutrainiert (kräftiges, gedecktes Türkisgrün)
-- Info-Bildschirm: Kopfband und je Bereich ein dezent getönter Kasten
local BOX_ABOUT = rgb(0x48, 0x34, 0x29)   -- Steckbrief: hervorgehoben, warm, mit dezentem Rand
local BOX_ABOUT_EDGE = rgb(0x56, 0x40, 0x32)
local BOX_SKILL = rgb(0x29, 0x29, 0x23)   -- Fähigkeiten: leicht zum Mint
local BOX_STATE = rgb(0x27, 0x25, 0x2b)   -- Zustand: leicht zum Blau

-- Kasten mit abgeschnittenen Ecken
local function box(x0, y0, x1, y1, col)
  rectfill(x0, y0, x1, y1, col)
  pset(x0, y0, C.panel) pset(x1, y0, C.panel) pset(x0, y1, C.panel) pset(x1, y1, C.panel)
end
local STATE_COL = rgb(0x8f, 0xc8, 0xe6) -- Zustand: Überschrift, Balken, Zahl
local function bx_of(v) return BAR_X + flr(mid(0, v, 100) * BAR_W / 100) end

-- Farben als {r, g, b}, damit sich Zwischentöne berechnen lassen
local function col(t) return rgb(t[1], t[2], t[3]) end
local function mix(a, b, f) return rgb(flr(a[1] + (b[1] - a[1]) * f), flr(a[2] + (b[2] - a[2]) * f), flr(a[3] + (b[3] - a[3]) * f)) end

-- Farben eines Balkens: bg = Fläche dahinter, track = Spur bis 100, talent = Rahmen bis zum Talent
-- (bg_rgb: dieselbe Hintergrundfarbe als {r, g, b} für Zwischentöne)
local BAR_BROWN = {bg = C.panel, bg_rgb = {0x2b, 0x1f, 0x1d}, track = {0x1e, 0x16, 0x14}, talent = {0x4a, 0x36, 0x2c}}
local BAR_SKILL = {bg = BOX_SKILL, bg_rgb = {0x29, 0x29, 0x23}, track = {0x1a, 0x1a, 0x16}, talent = {0x45, 0x4a, 0x3f}}
local BAR_STATE = {bg = BOX_STATE, bg_rgb = {0x27, 0x25, 0x2b}, track = {0x19, 0x17, 0x1c}}

-- Füllfarben des inneren Balkens
local FILL = {gen = {0x9a, 0xdc, 0xb4}, train = {0x3a, 0xb0, 0x8e}, state = {0x8f, 0xc8, 0xe6}, red = {0xe0, 0x47, 0x5a}}

-- Segmente alle 20 Punkte wie (=====)(=====): an jeder Grenze oben und unten drei Pixel breit und eins tief in
-- Hintergrundfarbe ausgespart, an den Enden je ein Eckpixel; dazwischen die Farbe des Balkens (Talent oder Spur) halb durchsichtig. Der gefüllte
-- innere Balken bekommt an der Grenze nur eine Andeutung: oberstes und unterstes Pixel halb durchsichtig.
-- frame_x: bis hier reicht der Rahmen (Talent), fills: {{x0, x1, Farbe {r, g, b}}} der gefüllten Abschnitte.
local function notches(y, th, frame_x, fills)
  for _, x in ipairs({BAR_X, BAR_X + BAR_W - 1}) do pset(x, y, th.bg) pset(x, y + 8, th.bg) end
  for v = 20, 80, 20 do
    local x = bx_of(v)
    pset(x - 1, y, th.bg) pset(x, y, th.bg) pset(x + 1, y, th.bg) pset(x, y + 1, th.bg)
    pset(x - 1, y + 8, th.bg) pset(x, y + 8, th.bg) pset(x + 1, y + 8, th.bg) pset(x, y + 7, th.bg)
    local under = x < frame_x and th.talent or th.track
    line(x, y + 2, x, y + 6, mix(under, th.bg_rgb, 0.5))  -- ohne Füllung: Balkenfarbe halb durchsichtig
    for _, f in ipairs(fills) do
      if x >= f[1] and x <= f[2] then
        line(x, y + 3, x, y + 5, col(f[3]))
        local soft = mix(f[3], under, 0.5)
        pset(x, y + 2, soft) pset(x, y + 6, soft)
      end
    end
  end
end

-- Fähigkeit: Rahmen bis zum Talent (Potenzial), darin der aktuelle Wert: Gen-Anteil Mint, Training kräftiger.
local function stat_bar(x, y, label, data, key, th)
  th = th or BAR_BROWN
  print(label, x, y, C.text)
  local v = H.stat(data, key)
  local pot = data.pot[key]
  rectfill(BAR_X, y, BAR_X + BAR_W - 1, y + 8, col(th.track))                  -- Spur bis 100
  rectfill(BAR_X, y, bx_of(pot) - 1, y + 8, col(th.talent))                    -- Talent
  local g = min(data.gen[key], v)
  local fills = {}
  if g >= 1 then
    rectfill(BAR_X + 1, y + 2, bx_of(g) - 1, y + 6, GEN_COL)
    fills[#fills + 1] = {BAR_X + 1, bx_of(g) - 1, FILL.gen}
  end
  if bx_of(v) > bx_of(g) then
    local x0 = max(BAR_X + 1, bx_of(g))
    rectfill(x0, y + 2, bx_of(v) - 1, y + 6, TRAIN_COL)
    fills[#fills + 1] = {x0, bx_of(v) - 1, FILL.train}
  end
  notches(y, th, bx_of(pot), fills)
  print(tostring(flr(v)), BAR_X + BAR_W + 6, y, SKILL_COL)
end

-- Zustand: ein Balken 0–100 (value/max), blau, mit warn rot.
local function state_bar(x, y, label, value, max, warn, th)
  th = th or BAR_STATE
  print(label, x, y, C.text)
  rectfill(BAR_X, y, BAR_X + BAR_W - 1, y + 8, col(th.track))
  local v = 100 * value / max
  local fc = warn and FILL.red or FILL.state
  local fills = {}
  if v >= 1 then
    rectfill(BAR_X + 1, y + 2, bx_of(v) - 1, y + 6, col(fc))
    fills[1] = {BAR_X + 1, bx_of(v) - 1, fc}
  end
  notches(y, th, BAR_X, fills)
  print(tostring(flr(value)), BAR_X + BAR_W + 6, y, col(fc))
end

function Screens.info(ctx, data)
  local s = {}
  function s.update(nav)
    if btnp(BTN_B) then nav.pop() end
    if btnp(BTN_A) then
      nav.push(Screens.keyboard("Neuer Name", data.name, 12, function(text) data.name = text end))
    end
    if btnp(BTN_RIGHT) then SFX.ok() nav.push(Screens.stammbaum(ctx, data)) end
  end
  function s.draw()
    cls(C.panel)
    -- Kopf: Name groß, Wert rechts
    rectfill(0, 0, SCREEN_W - 1, 21, C.panel)
    font(1)                                          -- feinere große Schrift (API 3)
    print(data.name, 6, 3, C.gold)
    font(0)
    local wert = "Wert " .. Value.wert(data) .. " G"
    print(wert, SCREEN_W - textw(wert) - 6, 7, C.gold)
    box(3, 23, SCREEN_W - 4, 80, BOX_ABOUT)
    rect(4, 24, SCREEN_W - 5, 79, BOX_ABOUT_EDGE)
    box(3, 83, SCREEN_W - 4, 146, BOX_SKILL)
    box(3, 149, SCREEN_W - 4, 224, BOX_STATE)
    -- Bild oben rechts unter dem Wert
    local rasse = K.rasse(data.rasse)
    Stage.panel(SCREEN_W - 78, 27, SCREEN_W - 8, 75)                -- mittig im Kasten (23–80)
    rectfill(SCREEN_W - 76, 29, SCREEN_W - 10, 73, rgb(0x7f, 0xb0, 0x4f))
    G.draw(data.farbe, rasse.koerper, "side", SCREEN_W - 43, 69, false)
    if data.alter < 1 then                          -- Fohlen: wie weit ausgewachsen
      rectfill(SCREEN_W - 78, 77, SCREEN_W - 8, 78, rgb(0x1e, 0x16, 0x14))
      rectfill(SCREEN_W - 78, 77, SCREEN_W - 78 + flr(70 * data.alter), 78, C.gold)
    end
    -- Steckbrief links
    local sexw = data.sex == "m" and (data.alter < 1 and "Hengstfohlen" or "Hengst") or (data.alter < 1 and "Stutfohlen" or "Stute")
    print(sexw .. ", " .. rasse.name, 8, 27, C.text)
    local f1, f2 = K.farbe(data.farbe).name, K.farbe(data.farbe2).name
    local farbe = f1 .. (data.farbe2 ~= data.farbe and (" / " .. f2) or "")
    if textw("Farbe: " .. farbe) <= SCREEN_W - 90 then farbe = "Farbe: " .. farbe end
    print(farbe, 8, 38, C.dim)
    print("Charakter: " .. K.charakter[data.zug].name, 8, 49, C.dim)
    print("Ort: " .. place_of(data), 8, 60, C.dim)
    local extra
    if data.traechtig then extra = "Trächtig bis Tag " .. data.traechtig.tag
    elseif data.zucht_pause and ctx.clock and data.zucht_pause > ctx.clock.day then extra = "Zuchtpause bis Tag " .. data.zucht_pause
    elseif data.sattel then extra = "Sattel: " .. K.artikel(data.sattel).name end
    if extra then print(extra, 8, 71, C.dim) end
    -- Fähigkeiten und Zustand über die ganze Breite
    print("Fähigkeiten", 8, 87, SKILL_COL)
    local y = 100
    for _, e in ipairs({{"tempo", "Tempo"}, {"staerke", "Stärke"}, {"ausdauer", "Ausdauer"}, {"spuer", "Spürsinn"}}) do
      stat_bar(8, y, e[2], data, e[1], BAR_SKILL)
      y = y + 11
    end
    print("Zustand", 8, 153, STATE_COL)
    y = 166
    state_bar(8, y, "Bindung", data.bindung, 100); y = y + 11
    state_bar(8, y, "Hunger", data.hunger, 100, data.hunger > 60); y = y + 11
    state_bar(8, y, "Sauber", data.sauberkeit, 100, data.sauberkeit < 40); y = y + 11
    state_bar(8, y, "Gewicht", data.gewicht, 100)
    line(bx_of(50), y - 1, bx_of(50), y + 9, C.text)                -- Idealgewicht
    y = y + 11
    state_bar(8, y, "Energie", data.energie, H.stat(data, "ausdauer"))
    footer("A umbenennen   > Stammbaum   B zurück")
  end
  s.full = true
  return s
end

-- ---- Pferdeliste ----

function Screens.horses(ctx)
  local sel = 1
  local s = {}
  function s.update(nav)
    local n = #ctx.herd
    if btnp(BTN_UP) and n > 0 then sel = (sel - 2) % n + 1; SFX.select() end
    if btnp(BTN_DOWN) and n > 0 then sel = sel % n + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) and n > 0 then SFX.ok() nav.push(Screens.info(ctx, ctx.herd[sel])) end
  end
  function s.draw()
    cls(C.panel)
    header("Pferde (" .. #ctx.herd .. ")")
    if #ctx.herd == 0 then
      print("Noch keine Pferde.", 20, 40, C.dim)
      print("Such ein Wildpferd und zähme es!", 20, 54, C.dim)
    end
    local first = max(1, sel - 9)
    for i = first, min(#ctx.herd, first + 9) do
      local d = ctx.herd[i]
      local y = 18 + (i - first) * 20
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 17, C.panel_light) end
      G.draw(d.farbe, K.rasse(d.rasse).koerper, "side", 26, y + 17, false)
      print(d.name, 50, y, i == sel and C.gold or C.text)
      print(K.rasse(d.rasse).name .. ", " .. place_of(d), 50, y + 9, C.dim)
      print("B " .. flr(d.bindung), 290, y, C.dim)
    end
    footer("A: Info   B: zurück")
  end
  s.full = true
  return s
end

-- ---- Laden (E13): Menübildschirm an der Tür, keine begehbaren Innenräume ----

function Screens.shop(ctx)
  local cat, sel, msg, msg_t = 1, 1, nil, 0
  local function items()
    local out = {}
    local id = Economy.CATEGORIES[cat].id
    for _, it in ipairs(Economy.catalog(ctx.max_gebiet or 1)) do
      if it.kat == id then out[#out + 1] = it end
    end
    return out
  end
  local s = {full = true}
  function s.update(nav)
    local list = items()
    if btnp(BTN_LEFT) then cat = (cat - 2) % #Economy.CATEGORIES + 1; sel = 1; SFX.select() end
    if btnp(BTN_RIGHT) then cat = cat % #Economy.CATEGORIES + 1; sel = 1; SFX.select() end
    if btnp(BTN_UP) and #list > 0 then sel = (sel - 2) % #list + 1; SFX.select() end
    if btnp(BTN_DOWN) and #list > 0 then sel = sel % #list + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) and list[sel] then
      local ok, why = Economy.buy(ctx, list[sel].id)
      if ok then
        SFX.eat()
        msg = list[sel].name .. " gekauft."
      else
        SFX.snort()
        msg = why == "Geld" and "Zu wenig Geld." or why == "Garage" and "Dafür fehlt die Garage (Schuppen/Garage/Hangar)." or "Hast du schon."
      end
      msg_t = 120
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
  end
  function s.draw()
    cls(C.panel)
    header("Laden")
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    -- Reiter
    local x = 6
    for i, c in ipairs(Economy.CATEGORIES) do
      local w = textw(c.name) + 10
      rectfill(x, 18, x + w - 1, 30, i == cat and C.gold or C.panel_light)
      print(c.name, x + 5, 21, i == cat and C.panel or C.text)
      x = x + w + 3
    end
    local list = items()
    local y = 38
    local first = max(1, sel - 8)
    for i = first, min(#list, first + 8) do
      local it = list[i]
      local price = Economy.price(ctx, it)
      local n = Economy.owned(ctx, it.id)
      local can = ctx.money >= price and not (it.einmalig and n > 0)
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 10, C.panel_light) end
      print(it.name, 10, y, can and (i == sel and C.gold or C.text) or C.dim)
      print(price .. " G", 210, y, can and C.gold or C.dim)
      print(n > 0 and ("x" .. n) or "", 270, y, C.dim)
      y = y + 14
    end
    local cur = list[sel]
    if cur then
      rectfill(0, 172, SCREEN_W - 1, 215, rgb(0x1a, 0x13, 0x12))
      local t = (cur.text:gsub("−", "-"))
      local lines = require("lib.util").wrap(t, SCREEN_W - 16)
      for i, line in ipairs(lines) do if i <= 4 then print(line, 8, 176 + (i - 1) * 10, C.dim) end end
    end
    if msg and msg_t > 0 then print(msg, 8, 218, C.gold) end
    footer("A: kaufen   </>: Reiter   B: zurück")
  end
  return s
end

-- ---- Reisemenü am Fahrzeug (D1): Ziel wählen, A fährt, B zurück ----

function Screens.reise(ctx, go)
  local Reise = require("game.reise")
  local sel, msg, msg_t = 1, nil, 0
  local s = {full = true}
  function s.update(nav)
    local list = Reise.ziele(ctx)
    if btnp(BTN_UP) and #list > 0 then sel = (sel - 2) % #list + 1; SFX.select() end
    if btnp(BTN_DOWN) and #list > 0 then sel = sel % #list + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) and list[sel] then
      if list[sel].ok then SFX.start() go(list[sel].nr)
      else SFX.snort() msg, msg_t = (list[sel].grund or "geht nicht") .. ".", 150 end
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
  end
  function s.draw()
    cls(C.panel)
    header("Reise  (" .. Economy.fahrzeug(ctx).name .. ", Anhänger " .. Economy.plaetze(ctx) .. " Plätze)")
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    local list = Reise.ziele(ctx)
    local y = 28
    for i, z in ipairs(list) do
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 10, C.panel_light) end
      print(z.nr .. "  " .. z.name .. (z.nr == 1 and " (heim)" or ""), 10, y, z.ok and (i == sel and C.gold or C.text) or C.dim)
      print(z.kosten .. " G", 250, y, z.ok and C.gold or C.dim)
      y = y + 14
    end
    if #list == 0 then print("Mit diesem Fahrzeug geht es nirgends hin.", 10, y, C.dim) end
    print("Mitgenommen: " .. #ctx.lead .. " Pferd(e) an der Leine", 10, 190, C.dim)
    if msg and msg_t > 0 then print(msg, 10, 204, C.red) end
    footer("A: losfahren   B: zurück")
  end
  return s
end

-- ---- Pferdemarkt (E13) ----

function Screens.market(ctx)
  local sel, msg, msg_t = 1, nil, 0
  local s = {full = true}
  function s.update(nav)
    local list = ctx.market.horses
    if btnp(BTN_UP) and #list > 0 then sel = (sel - 2) % #list + 1; SFX.select() end
    if btnp(BTN_DOWN) and #list > 0 then sel = sel % #list + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) and list[sel] then
      local name = list[sel].name
      local ok, why = Market.buy(ctx, sel)
      if ok then
        SFX.tame()
        msg = name .. " gehört jetzt dir und folgt dir."
        sel = min(sel, max(1, #list))
      else
        SFX.snort()
        msg = why == "Geld" and "Zu wenig Geld." or why == "voll" and "Mehr als " .. Market.MAX_HERD .. " Pferde gehen nicht." or "Schon weg."
      end
      msg_t = 150
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
  end
  function s.draw()
    cls(C.panel)
    header("Pferdemarkt")
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    local list = ctx.market.horses
    if #list == 0 then
      print("Heute ist alles verkauft.", 20, 40, C.dim)
      print("Alle " .. Market.CYCLE .. " Tage kommen neue Pferde.", 20, 54, C.dim)
    end
    for i, d in ipairs(list) do
      local y = 20 + (i - 1) * 22
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 19, C.panel_light) end
      G.draw(d.farbe, K.rasse(d.rasse).koerper, "side", 26, y + 19, false)
      print(d.name .. " (" .. (d.sex == "m" and "Hengst" or "Stute") .. ")", 50, y, i == sel and C.gold or C.text)
      print(K.rasse(d.rasse).name .. ", " .. K.farbe(d.farbe).name, 50, y + 10, C.dim)
      local price = d.preis .. " G"
      print(price, SCREEN_W - textw(price) - 10, y + 4, ctx.money >= d.preis and C.gold or C.dim)
    end
    local d = list[sel]
    if d then
      rectfill(0, 116, SCREEN_W - 1, 215, rgb(0x1a, 0x13, 0x12))
      for k, e in ipairs({{"tempo", "Tempo"}, {"staerke", "Stärke"}, {"ausdauer", "Ausdauer"}, {"spuer", "Spürsinn"}}) do
        stat_bar(8, 120 + (k - 1) * 12, e[2], d, e[1])
      end
      print("Bindung " .. d.bindung .. ", " .. K.charakter[d.zug].name, 8, 171, C.text)
      print("Leistung " .. flr(Value.leistung(d) * 100) .. " %, Wert " .. Value.wert(d) .. " G", 8, 182, C.dim)
      print("Farbfaktor x" .. Value.farbfaktor(d) .. ", Kauf = Wert x1,3", 8, 193, C.dim)
    end
    if msg and msg_t > 0 then print(msg, 8, 218, C.gold) end
    footer("A: kaufen   B: zurück")
  end
  return s
end

-- ---- Turnierplatz (E1): Klasse → Wettbewerb → Pferd (mit Chancen) → Ergebnis ----

function Screens.turnier(ctx)
  local Turniere = require("game.turniere")
  local stage, sel, sel_k, sel_w, result, msg, msg_t = "klasse", 1, nil, nil, nil, nil, 0
  local day = ctx.clock.day
  local s = {full = true}
  local function lists()
    if stage == "klasse" then return Turniere.klassen(ctx) end
    if stage == "wb" then return K.turniere.wettbewerbe end
    local out = {}
    for _, d in ipairs(ctx.herd) do if d.alter >= 1 then out[#out + 1] = d end end
    return out
  end
  function s.update(nav)
    local list = lists()
    if stage == "ergebnis" then
      if btnp(BTN_A) or btnp(BTN_B) then stage, sel, result = "klasse", 1, nil end
      return
    end
    if btnp(BTN_UP) and #list > 0 then sel = (sel - 2) % #list + 1; SFX.select() end
    if btnp(BTN_DOWN) and #list > 0 then sel = sel % #list + 1; SFX.select() end
    if btnp(BTN_B) then
      SFX.back()
      if stage == "klasse" then nav.pop() elseif stage == "wb" then stage, sel = "klasse", 1 else stage, sel = "wb", 1 end
    end
    if btnp(BTN_A) and list[sel] then
      if stage == "klasse" then sel_k, stage, sel = list[sel].index, "wb", 1 SFX.ok()
      elseif stage == "wb" then
        local st = Turniere.state(ctx, day)
        if st.weg[sel_k .. ":" .. list[sel].id] then SFX.snort() msg, msg_t = "Dieser Wettbewerb ist bis zur nächsten Runde weg.", 150
        else sel_w, stage, sel = list[sel].id, "pferd", 1 SFX.ok() end
      else
        local d = list[sel]
        local function antreten(punkte, platz)
          local r, why = Turniere.teilnehmen(ctx, day, d, sel_k, sel_w, punkte, platz)
          if r then result, stage = r, "ergebnis" if r.rank == 1 then SFX.tame() else SFX.ok() end
          else SFX.snort() msg, msg_t = why == "Geld" and "Zu wenig Geld für die Startgebühr." or (why .. "."), 150 end
        end
        if sel_w == "springreiten" then
          if ctx.money < K.turniere.klassen[sel_k].gebuehr then SFX.snort() msg, msg_t = "Zu wenig Geld für die Startgebühr.", 150
          else nav.push(Screens.springreiten(ctx, d, antreten)) end
        elseif sel_w == "pferderennen" then
          if ctx.money < K.turniere.klassen[sel_k].gebuehr then SFX.snort() msg, msg_t = "Zu wenig Geld für die Startgebühr.", 150
          else
            local g = Turniere.gegner(ctx, sel_k, sel_w, Turniere.state(ctx, day).runde)
            nav.push(Screens.rennen(ctx, d, g, antreten))
          end
        else
          antreten()
        end
      end
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
  end
  function s.draw()
    cls(C.panel)
    header("Turnierplatz   Runde " .. (Turniere.runde(day) + 1) .. ", neue alle " .. K.turniere.rotation_tage .. " Tage")
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    if stage == "ergebnis" then
      local r = result
      Stage.center("Platz " .. r.rank .. " von " .. (Turniere.GEGNER + 1), 60, r.rank == 1 and C.gold or C.text, 2)
      Stage.center(r.klasse .. ": " .. K.turniere.wettbewerbe[1].name and (function() for _, w in ipairs(K.turniere.wettbewerbe) do if w.id == r.wb then return w.name end end end)(), 90, C.dim)
      Stage.center("Wertung " .. flr(r.wertung), 104, C.dim)
      Stage.center(r.preis > 0 and ("Preisgeld " .. r.preis .. " G (Gebühr " .. r.gebuehr .. " G)") or ("Kein Preis, Gebühr " .. r.gebuehr .. " G"), 124, r.preis > 0 and C.gold or C.red)
      footer("A: weiter")
      return
    end
    local list = lists()
    local y = 24
    if stage == "klasse" then print("Klasse wählen", 8, 16, C.dim) y = 30 end
    for i, e in ipairs(list) do
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 10, C.panel_light) end
      if stage == "klasse" then
        local k = e.def
        print(k.name, 10, y, i == sel and C.gold or C.text)
        print("Gebühr " .. k.gebuehr .. " G", 100, y, ctx.money >= k.gebuehr and C.text or C.dim)
        print(k.preise[1] .. "/" .. k.preise[2] .. "/" .. k.preise[3], 200, y, C.gold)
      elseif stage == "wb" then
        local weg = Turniere.state(ctx, day).weg[sel_k .. ":" .. e.id]
        print(e.name, 10, y, weg and C.dim or (i == sel and C.gold or C.text))
        print(weg and "weg" or "offen", 270, y, weg and C.dim or C.text)
      else
        local win, top = Turniere.chancen(ctx, e, sel_k, sel_w, Turniere.state(ctx, day).runde)
        print(e.name, 10, y, i == sel and C.gold or C.text)
        print("Sieg " .. win .. " %", 130, y, C.text)
        print("Podest " .. top .. " %", 210, y, C.text)
      end
      y = y + 13
      if y > 190 then break end
    end
    if stage == "wb" then
      local w = K.turniere.wettbewerbe[sel]
      if w then for i, l in ipairs(require("lib.util").wrap(w.text, SCREEN_W - 20)) do print(l, 10, 192 + (i - 1) * 10, C.dim) end end
    elseif stage == "pferd" then
      print("Wertung = Stat × (0,5 + Bindung/200)", 10, 192, C.dim)
      print("Podest = Platz 1 bis 3", 10, 202, C.dim)
    end
    if msg and msg_t > 0 then print(msg, 10, 214, C.red) end
    footer((stage == "pferd" and "A: antreten" or "A: wählen") .. "   B: zurück")
  end
  return s
end

-- ---- Minispiel Springreiten (E2): A springt; am Ende A, dann done(punkte) ----

function Screens.springreiten(ctx, d, done)
  local Sp = require("game.springen")
  local st = Sp.new(d)
  local s = {full = true}
  local finished = false
  local rasse = K.rasse(d.rasse)
  function s.update(nav)
    Sp.update(st, btnp(BTN_A) and not st.done)
    if st.done then
      if btnp(BTN_A) then
        if finished then return end
        finished = true
        nav.pop()
        done(Sp.punkte(st))
      end
    elseif st.jump == 1 then SFX.jump() end
  end
  function s.draw()
    cls(rgb(0x9f, 0xcd, 0x66))
    rectfill(0, 150, SCREEN_W - 1, SCREEN_H - 1, rgb(0x7f, 0xb0, 0x4f))
    rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
    print("Springreiten: " .. d.name, 6, 3, C.gold)
    local info = st.clean .. " sauber, " .. st.faults .. " Fehler"
    print(info, SCREEN_W - textw(info) - 6, 3, C.text)
    local ground = 178
    -- Stangen (Weltposition → Bildschirm)
    for _, h in ipairs(st.hurdles) do
      local sx = flr(h.x - st.x + Sp.HORSE_X)
      if sx > -20 and sx < SCREEN_W + 10 then
        if h.state == "down" then
          rectfill(sx - 12, ground - 3, sx + 12, ground - 1, rgb(0xb0, 0x7a, 0x44))
        else
          rectfill(sx - 11, ground - h.h, sx - 9, ground, rgb(0x55, 0x33, 0x20))
          rectfill(sx + 9, ground - h.h, sx + 11, ground, rgb(0x55, 0x33, 0x20))
          rectfill(sx - 11, ground - h.h, sx + 11, ground - h.h + 2, h.state == "clean" and C.gold or rgb(0xe0, 0x47, 0x5a))
        end
      end
    end
    local pose = (st.stumble > 0 or st.jump > 0) and "side" or ((st.frame // 6) % 2 == 0 and "gallop1" or "gallop2")
    G.draw(d.farbe, rasse.koerper, pose, Sp.HORSE_X, ground - st.air, false)
    -- Fortschritt
    rectfill(10, 24, 309, 28, C.panel)
    rectfill(10, 24, 10 + flr(299 * min(1, st.x / Sp.END_X)), 28, C.gold)
    if st.done then
      Stage.panel(60, 80, 259, 130)
      Stage.center(st.clean .. " von " .. Sp.HURDLES .. " Stangen sauber", 90, C.gold)
      Stage.center("Punkte " .. flr(Sp.punkte(st)), 104, C.text)
      Stage.center("A: weiter", 116, C.dim)
    else
      print("A: springen", 6, SCREEN_H - 10, C.dim)
    end
  end
  return s
end

-- ---- Minispiel Pferderennen (E3): A halten = Spurt; am Ende A, dann done(punkte, platz) ----

function Screens.rennen(ctx, d, gegner, done)
  local Rn = require("game.rennen")
  local st = Rn.new(d, gegner, require("lib.rng").new(5))
  local s = {full = true}
  local finished = false
  local rasse = K.rasse(d.rasse)
  function s.update(nav)
    Rn.update(st, btn(BTN_A) and not st.done)
    if st.done and btnp(BTN_A) and not finished then
      finished = true
      nav.pop()
      done(Rn.punkte(st), Rn.platz(st))
    end
  end
  function s.draw()
    cls(rgb(0x9f, 0xcd, 0x66))
    rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
    print("Pferderennen: " .. d.name, 6, 3, C.gold)
    local lanes = #st.rivals + 1
    local lane_h = 24
    local y0 = 30
    local cam = min(st.x, Rn.LENGTH) - 90
    for i = 1, lanes do
      local y = y0 + (i - 1) * lane_h
      rectfill(0, y + 20, SCREEN_W - 1, y + 21, rgb(0xb3, 0x8c, 0x57))
    end
    -- Ziellinie
    local fx = flr(Rn.LENGTH - cam)
    if fx < SCREEN_W then rectfill(fx, y0, fx + 3, y0 + lanes * lane_h, C.text) end
    -- eigenes Pferd auf der letzten Bahn, Gegner darüber
    local function horse_at(x, i, own)
      local y = y0 + (i - 1) * lane_h + 20
      local pose = ((st.frame // 5) % 2 == 0) and "gallop1" or "gallop2"
      local col = own and d.farbe or "brauner"
      G.draw(col, rasse.koerper, pose, flr(x - cam), y, false)
    end
    for i, r in ipairs(st.rivals) do horse_at(r.x, i, false) end
    horse_at(st.x, lanes, true)
    -- Ausdauer
    rectfill(10, 216, 129, 224, C.panel)
    rectfill(11, 217, 11 + flr(117 * st.stamina / st.cap), 223, st.stamina > 0 and C.gold or C.red)
    print("Ausdauer", 136, 216, C.text)
    if st.done then
      Stage.panel(70, 90, 249, 140)
      Stage.center("Platz " .. Rn.platz(st) .. " von " .. lanes, 100, C.gold, 2)
      Stage.center("Punkte " .. flr(Rn.punkte(st)) .. "   A: weiter", 124, C.dim)
    else
      print("A: Spurt", SCREEN_W - 70, 216, C.dim)
    end
  end
  return s
end

-- ---- Käufer am Hof ----

function Screens.buyer(ctx, nav_done)
  local typ = ctx.buyer.typ
  local info = Buyers.INFO[typ]
  local sel, msg = 1, nil
  local s = {full = true}
  local function list()
    local out = {}
    for _, d in ipairs(ctx.herd) do
      local riding = false
      for _, h in ipairs(ctx.herd_horses) do if h.data == d and h.state == "ridden" then riding = true end end
      if not riding then out[#out + 1] = d end
    end
    return out
  end
  function s.update(nav)
    local l = list()
    if btnp(BTN_UP) and #l > 0 then sel = (sel - 2) % #l + 1; SFX.select() end
    if btnp(BTN_DOWN) and #l > 0 then sel = sel % #l + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) and l[sel] then
      local d = l[sel]
      local name = d.name
      local price, extra = Buyers.sell(ctx, typ, d)
      if price then
        SFX.tame()
        nav.pop()
        if nav_done then nav_done(name .. " verkauft für " .. price .. " G.") end
      else
        SFX.snort()
        msg = "Das nimmt er nicht: " .. tostring(extra)
      end
    end
  end
  function s.draw()
    cls(C.panel)
    header(info.name .. " kauft")
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    local l = list()
    if #l == 0 then
      print("Du hast kein Pferd zum Verkaufen.", 20, 40, C.dim)
    end
    local first = max(1, sel - 5)
    for i = first, min(#l, first + 5) do
      local d = l[i]
      local y = 20 + (i - first) * 22
      local price, why = Buyers.offer(typ, d)
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 19, C.panel_light) end
      G.draw(d.farbe, K.rasse(d.rasse).koerper, "side", 26, y + 19, false)
      print(d.name, 50, y, i == sel and C.gold or C.text)
      print(K.rasse(d.rasse).name .. ", " .. K.farbe(d.farbe).name, 50, y + 10, C.dim)
      local t = price and (price .. " G") or "nein"
      print(t, SCREEN_W - textw(t) - 10, y + 4, price and C.gold or C.dim)
    end
    local d = l[sel]
    if d then
      rectfill(0, 152, SCREEN_W - 1, 227, rgb(0x1a, 0x13, 0x12))
      local spruch = Buyers.spruch(typ, d, ctx.clock and ctx.clock.day or 1)
      local lines = require("lib.util").wrap("\"" .. spruch .. "\"", SCREEN_W - 16)
      for i, line in ipairs(lines) do if i <= 3 then print(line, 8, 156 + (i - 1) * 10, C.text) end end
      local price, why = Buyers.offer(typ, d)
      if price then
        print("Er zahlt " .. price .. " G (Wert " .. Value.wert(d) .. " G).", 8, 190, C.gold)
        local f = Buyers.folge(typ)
        if f ~= 0 then print("Die übrigen Pferde: Bindung " .. (f > 0 and "+" or "") .. f, 8, 201, f > 0 and C.text or C.red) end
      else
        print("Er nimmt es nicht: " .. tostring(why), 8, 190, C.red)
      end
      if msg then print(msg, 8, 214, C.red) end
    end
    footer("A: verkaufen   B: zurück")
  end
  return s
end

-- ---- Bestellungen ----

-- Welches Pferd liefern? Passende Pferde oben mit dem Preis, die übrigen grau.
local function order_horses(ctx, order, done)
  local sel = 1
  local s = {full = true}
  local function list()
    local out, rest = {}, {}
    for _, d in ipairs(ctx.herd) do
      if Orders.matches(order, d) then out[#out + 1] = d else rest[#rest + 1] = d end
    end
    for _, d in ipairs(rest) do out[#out + 1] = d end
    return out
  end
  function s.update(nav)
    local l = list()
    if btnp(BTN_UP) and #l > 0 then sel = (sel - 2) % #l + 1; SFX.select() end
    if btnp(BTN_DOWN) and #l > 0 then sel = sel % #l + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) and l[sel] then
      local name = l[sel].name
      local sum, why = Orders.deliver(ctx, order, l[sel])
      if sum then
        SFX.tame()
        nav.pop()
        if done then done(name .. " geliefert: " .. sum .. " G von " .. order.kunde .. ".") end
      else
        SFX.snort()
      end
    end
  end
  function s.draw()
    cls(C.panel)
    header("Welches Pferd liefern?")
    local lines = require("lib.util").wrap(order.kunde .. ": " .. Orders.text(order), SCREEN_W - 16)
    for i, line in ipairs(lines) do print(line, 8, 18 + (i - 1) * 10, C.gold) end
    local l = list()
    local first = max(1, sel - 5)
    for i = first, min(#l, first + 5) do
      local d = l[i]
      local y = 44 + (i - first) * 22
      local ok = Orders.matches(order, d)
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 19, C.panel_light) end
      G.draw(d.farbe, K.rasse(d.rasse).koerper, "side", 26, y + 19, false)
      print(d.name .. " (" .. (d.sex == "m" and "Hengst" or "Stute") .. ")", 50, y, ok and (i == sel and C.gold or C.text) or C.dim)
      print(K.farbe(d.farbe).name .. ", " .. Orders.STATS[order.stat].name .. " " .. flr(H.stat(d, order.stat)), 50, y + 10, C.dim)
      local t = ok and (Orders.reward(d) .. " G") or "passt nicht"
      print(t, SCREEN_W - textw(t) - 10, y + 4, ok and C.gold or C.dim)
    end
    footer("A: liefern   B: zurück")
  end
  return s
end

function Screens.orders(ctx)
  local sel = 1
  local s = {full = true}
  local msg, msg_t = nil, 0
  function s.update(nav)
    local n = #ctx.orders
    if btnp(BTN_UP) and n > 0 then sel = (sel - 2) % n + 1; SFX.select() end
    if btnp(BTN_DOWN) and n > 0 then sel = sel % n + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) and ctx.orders[sel] then
      SFX.ok()
      nav.push(order_horses(ctx, ctx.orders[sel], function(text) msg, msg_t = text, 240 end))
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
    sel = min(sel, max(1, #ctx.orders))
  end
  function s.draw()
    cls(C.panel)
    header("Bestellungen (" .. #ctx.orders .. ")")
    local day = ctx.clock and ctx.clock.day or 1
    if #ctx.orders == 0 then
      print("Keine offenen Bestellungen.", 20, 40, C.dim)
      print("Alle 3 Tage gibt jemand eine auf.", 20, 54, C.dim)
    end
    for i, o in ipairs(ctx.orders) do
      local y = 20 + (i - 1) * 44
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 40, C.panel_light) end
      print(o.kunde, 10, y, i == sel and C.gold or C.text)
      local lines = require("lib.util").wrap(Orders.text(o), SCREEN_W - 24)
      for k, line in ipairs(lines) do if k <= 2 then print(line, 10, y + 10 + (k - 1) * 10, C.text) end end
      local left = o.frist - day
      local t = left > 0 and ("noch " .. left .. " Tage") or "letzter Tag"
      print(t, 10, y + 30, left <= 1 and C.red or C.dim)
      print("Wert x1,5", SCREEN_W - textw("Wert x1,5") - 10, y + 30, C.gold)
    end
    if msg and msg_t > 0 then print(msg, 8, 214, C.gold) end
    footer("A: Pferd liefern   B: zurück")
  end
  return s
end

-- ---- Jobbrett (E13) ----

local function job_horses(ctx, job, done)
  local sel = 1
  local s = {full = true}
  local day = function() return ctx.clock and ctx.clock.day or 1 end
  local function list()
    local ok, rest = {}, {}
    for _, d in ipairs(ctx.herd) do
      if Jobs.eligible(d, job, day()) then ok[#ok + 1] = d else rest[#rest + 1] = d end
    end
    for _, d in ipairs(rest) do ok[#ok + 1] = d end
    return ok
  end
  function s.update(nav)
    local l = list()
    if btnp(BTN_UP) and #l > 0 then sel = (sel - 2) % #l + 1; SFX.select() end
    if btnp(BTN_DOWN) and #l > 0 then sel = sel % #l + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) and l[sel] then
      local d = l[sel]
      local name = d.name
      local sum = Jobs.run(ctx, job, d, day())
      if sum then
        SFX.tame()
        nav.pop()
        if done then done(name .. " hat gearbeitet: " .. sum .. " G.") end
      else
        SFX.snort()
      end
    end
  end
  function s.draw()
    cls(C.panel)
    header(job.name .. ": welches Pferd?")
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    local l = list()
    if #l == 0 then print("Du hast kein Pferd.", 20, 40, C.dim) end
    local first = max(1, sel - 6)
    for i = first, min(#l, first + 6) do
      local d = l[i]
      local y = 20 + (i - first) * 24
      local ok, why = Jobs.eligible(d, job, day())
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 21, C.panel_light) end
      G.draw(d.farbe, K.rasse(d.rasse).koerper, "side", 26, y + 19, false)
      print(d.name, 50, y, ok and (i == sel and C.gold or C.text) or C.dim)
      print(ok and ("Energie " .. flr(d.energie)) or why, 50, y + 10, ok and C.dim or C.red)
      local t = ok and (Jobs.lohn(d, job) .. " G") or ""
      print(t, SCREEN_W - textw(t) - 10, y + 4, C.gold)
    end
    footer("A: arbeiten   B: zurück")
  end
  return s
end

function Screens.jobs(ctx)
  local sel, msg, msg_t = 1, nil, 0
  local s = {full = true}
  function s.update(nav)
    local list = Jobs.list()
    if btnp(BTN_UP) then sel = (sel - 2) % #list + 1; SFX.select() end
    if btnp(BTN_DOWN) then sel = sel % #list + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if btnp(BTN_A) then
      SFX.ok()
      nav.push(job_horses(ctx, list[sel], function(text) msg, msg_t = text, 240 end))
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
  end
  function s.draw()
    cls(C.panel)
    header("Jobbrett")
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    for i, job in ipairs(Jobs.list()) do
      local y = 22 + (i - 1) * 50
      if i == sel then rectfill(4, y - 3, SCREEN_W - 5, y + 44, C.panel_light) end
      print(job.name, 10, y, i == sel and C.gold or C.text)
      print("ab " .. Jobs.STAT_NAMES[job.braucht] .. " " .. job.braucht_wert, 160, y, C.dim)
      print("Lohn " .. job.lohn_basis .. " + " .. Jobs.STAT_NAMES[job.lohn_stat] .. "/" .. job.lohn_teiler, 10, y + 12, C.gold)
      local train = {}
      for key, amount in pairs(job.training) do train[#train + 1] = Jobs.STAT_NAMES[key] .. " +" .. amount end
      table.sort(train)
      print("Training: " .. table.concat(train, ", "), 10, y + 24, C.dim)
      print("Energie " .. job.energie, 10, y + 35, C.dim)
    end
    print("Ein Job pro Pferd und Tag.", 10, 176, C.dim)
    if msg and msg_t > 0 then print(msg, 8, 214, C.gold) end
    footer("A: Job wählen   B: zurück")
  end
  return s
end

-- ---- Stammbaum (E44): Pferd links, Eltern, Großeltern, Urgroßeltern rechts ----

function Screens.stammbaum(ctx, data)
  local s = {full = true, static = true}
  local drawn = false
  function s.update(nav)
    if btnp(BTN_B) or btnp(BTN_A) or btnp(BTN_LEFT) then SFX.back() nav.pop() end
  end
  local COLW, BOXW = 80, 76
  local function box(x, y, h, node, label)
    rectfill(x, y, x + BOXW - 1, y + h - 1, C.panel_light)
    rect(x, y, x + BOXW - 1, y + h - 1, C.panel)
    if node then
      print((node.name or "?"):sub(1, 9), x + 3, y + 2, C.text)
      if h >= 20 then
        local r = node.rasse and K.rasse(node.rasse).name or ""
        print(r:sub(1, 9), x + 3, y + 11, C.dim)
      end
    else
      print(label or "unbekannt", x + 3, y + 2, C.dim)
    end
  end
  -- Zeichnet Knoten der Ebene `level` (0 = Pferd) in den Zeilenbereich [y0, y0 + h)
  local function draw_level(node, level, y0, h)
    local x = 4 + level * COLW
    local bh = min(h - 2, 22)
    box(x, y0 + (h - bh) // 2, bh, node, level == 0 and "" or (level == 1 and "unbekannt" or "?"))
    if level < 3 then
      local half = h // 2
      draw_level(node and node.v, level + 1, y0, half)
      draw_level(node and node.m, level + 1, y0 + half, half)
      -- Verbindungslinien zu den Eltern
      local cx = x + BOXW
      local my = y0 + h // 2
      line(cx, my, cx + 2, my, C.dim)
      line(cx + 2, y0 + half // 2, cx + 2, y0 + half + half // 2, C.dim)
      line(cx + 2, y0 + half // 2, cx + 3, y0 + half // 2, C.dim)
      line(cx + 2, y0 + half + half // 2, cx + 3, y0 + half + half // 2, C.dim)
    end
  end
  function s.draw()
    if drawn then return end
    drawn = true
    cls(C.panel)
    header("Stammbaum: " .. data.name)
    local root = {name = data.name, rasse = data.rasse, v = data.ahnen and data.ahnen.v, m = data.ahnen and data.ahnen.m}
    draw_level(root, 0, 16, 208)
    print("Vater oben, Mutter unten", 6, SCREEN_H - 10, C.dim)
    if not data.ahnen then print("Wildfang: keine Ahnen bekannt", 100, SCREEN_H - 10, C.dim) end
  end
  return s
end

-- ---- Baumodus (E8, geändert nach Rückmeldung 0.5.2): Cursor im Kachelraster, A setzt, START öffnet die
-- Bauteil-Auswahl als Kachelmenü (erst Art, dann Bauteil), B schließt. Dezentes Raster aus 2 × 2 Pixel großen
-- Punkten an den Kachelecken des Grundstücks. ----

-- Bild eines Bauteils für das Kachelmenü
local BUILD_ICON = {
  weg = "ground_path1", boden = "ground_sand1", beet = "ground_carrots", feld = "ground_carrots",
  zaun = "fence_post", land_n = "ico_karte", land_o = "ico_karte", land_s = "ico_karte", land_w = "ico_karte",
}
local CAT_ICON = {
  deko = "blumenkuebel", wege = "ground_path1", anbau = "ground_carrots", pflanzen = "pflanze_karotte_3",
  zaun = "gate", gebaeude = "stable", land = "ico_karte", abriss = "cursor_bad",
}
local function build_icon(cat, id)
  if cat == "pflanzen" then return "pflanze_" .. id .. "_3" end
  if BUILD_ICON[id] then return BUILD_ICON[id] end
  local it = Farm.ITEMS[id]
  local P = it and it.prop and Tiles.PROPS[it.prop]
  return P and (P.sprite or (P.variants and P.variants[1])) or "ico_bauen"
end

-- Name, Preis (oder nil) eines Bauteils
local function build_name(ctx, cat, id)
  if cat == "pflanzen" then return Farm.crop(id).name, nil end
  if cat == "land" then return Farm.LAND_DIRS[id].name, (Farm.land_angebot(ctx, id)) end
  local b = K.bauteil(id)
  return b.name, b.preis
end

local function short(name)
  return #name > 9 and name:sub(1, 8) .. "." or name
end

function Screens.build(ctx)
  local farm = ctx.area.farm
  local plot = farm.plot
  local cat, item = 1, 1
  local cx = mid(plot.x, flr(ctx.player.x / 16), plot.x + plot.w - 1)
  local cy = mid(plot.y, flr((ctx.player.y - 2) / 16), plot.y + plot.h - 1)
  local msg, msg_t = "START: anderes Bauteil", 300
  local picker                 -- offenes Kachelmenü: {stage = "cat"|"item", m = Menu}
  local s = {}
  local pastures = Farm.pastures(ctx.map, farm)
  -- Nach jedem Umbau: Weiden neu berechnen, Pferde umsetzen, Meldung
  local function changed()
    local before = 0
    for _, w in ipairs(pastures) do before = before + w.plaetze end
    pastures = Farm.pastures(ctx.map, farm)
    local after = 0
    for _, w in ipairs(pastures) do after = after + w.plaetze end
    local lost = ctx.wild and ctx.wild:rehome() or {}
    if #lost > 0 then return "Weide weg: " .. lost[1] .. " kommt an die Leine." end
    if after ~= before then return "Weiden: " .. #pastures .. ", Plätze " .. after .. "." end
  end
  local cats = Farm.categories(ctx)
  -- Kategorie und Bauteil gültig halten (die Samenliste ändert sich beim Pflanzen)
  local function cur_item()
    cats = Farm.categories(ctx)
    cat = mid(1, cat, #cats)
    local c = cats[cat]
    item = mid(1, item, max(1, #c.items))
    return c.items[item], c
  end
  local function say(text) msg, msg_t = text, 180 end

  local function open_cats(sel)
    local items = {}
    for i, c in ipairs(cats) do
      local empty = #c.items == 0 and c.id ~= "abriss"
      items[i] = {label = c.name .. (empty and " (keine Samen)" or ""), id = i, icon = CAT_ICON[c.id] or "ico_bauen",
        short = short(c.name), dim = empty}
    end
    picker = {stage = "cat", m = Menu.new(items, "Was bauen?")}
    picker.m.sel = sel or cat
  end
  local function open_items(ci)
    local c = cats[ci]
    local items = {}
    for i, id in ipairs(c.items) do
      local name, price = build_name(ctx, c.id, id)
      items[i] = {label = name .. (price and ("  " .. price .. " G") or ""), id = i, icon = build_icon(c.id, id),
        short = short(name), badge = price and tostring(price) or nil}
    end
    picker = {stage = "item", cat = ci, m = Menu.new(items, c.name)}
    if ci == cat then picker.m.sel = item end
  end

  local function act()
    local id, c = cur_item()
    if c.id == "abriss" then
      local sum, why = Farm.remove(ctx, cx, cy)
      if sum then SFX.brush() say(changed() or ("Abgerissen: +" .. sum .. " G.")) else SFX.snort() say(why .. ".") end
    elseif c.id == "land" then
      local ok, why = Farm.buy_land(ctx, id)
      if ok then
        SFX.ok() say(Farm.LAND_DIRS[id].name .. " gekauft: " .. why .. " G.")
        pastures = Farm.pastures(ctx.map, farm)
        plot = farm.plot
      else SFX.snort() say(why == "Geld" and "Zu wenig Geld." or (why .. ".")) end
    elseif c.id == "pflanzen" then
      if not id then say("Noch keine Samen: im Laden kaufen.")
      else
        local ok, why = Farm.plant(ctx, id, cx, cy)
        if ok then SFX.ok() say(Farm.crop(id).name .. " gepflanzt.") else SFX.snort() say(why .. ".") end
      end
    else
      local ok, why = Farm.place(ctx, id, cx, cy)
      if ok then SFX.ok() say(changed() or (K.bauteil(id).name .. " gebaut."))
      else SFX.snort() say(why == "Geld" and "Zu wenig Geld." or (why .. ".")) end
    end
  end

  function s.update(nav)
    cur_item()
    if picker then
      local r = picker.m:update()
      if btnp(BTN_START) and not btn(BTN_SELECT) then picker = nil
      elseif r == "close" then
        if picker.stage == "item" then open_cats(picker.cat) else picker = nil end
      elseif r and picker.stage == "cat" then
        if cats[r].id == "abriss" then cat, item, picker = r, 1, nil  say("A reißt ab, was unter dem Cursor steht.")
        else open_items(r) end
      elseif r and picker.stage == "item" then
        cat, item, picker = picker.cat, r, nil
      end
    else
      if btnp(BTN_LEFT) then cx = max(plot.x, cx - 1) end
      if btnp(BTN_RIGHT) then cx = min(plot.x + plot.w - 1, cx + 1) end
      if btnp(BTN_UP) then cy = max(plot.y, cy - 1) end
      if btnp(BTN_DOWN) then cy = min(plot.y + plot.h - 1, cy + 1) end
      if btnp(BTN_START) and not btn(BTN_SELECT) then open_cats() SFX.select()
      elseif btnp(BTN_B) then SFX.back() nav.pop() return
      elseif btnp(BTN_A) then act() end
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
    ctx.camera:follow(cx * 16 + 8, cy * 16 + 8)
  end

  -- Passt das Bauteil an die Cursorstelle? Gibt ok, Breite, Höhe (Kacheln) zurück.
  local function check(id, c)
    if c.id == "abriss" then return Farm.item_at(farm, cx, cy) ~= nil or Farm.plant_at(farm, cx, cy) ~= nil, 1, 1 end
    if c.id == "land" then local price = Farm.land_angebot(ctx, id) return price ~= nil and ctx.money >= price, 1, 1 end
    if c.id == "pflanzen" then
      if not id then return false, 1, 1 end
      local crop = Farm.crop(id)
      return Farm.can_plant(ctx, id, cx, cy), crop.w, crop.h
    end
    local it = Farm.ITEMS[id]
    return Farm.can_place(ctx.map, farm, id, cx, cy, ctx.player) and ctx.money >= K.bauteil(id).preis, it.w or 1, it.h or 1
  end

  function s.draw()
    local cam = ctx.camera
    local id, c = cur_item()
    local ok, w, h = check(id, c)
    camera(cam.x, cam.y)
    -- Raster: dezente 2 × 2-Punkte an den Kachelecken (nur Sichtbares)
    local x0 = max(plot.x, cam.x // 16)
    local x1 = min(plot.x + plot.w, (cam.x + SCREEN_W) // 16 + 1)
    local y0 = max(plot.y, cam.y // 16)
    local y1 = min(plot.y + plot.h, (cam.y + SCREEN_H) // 16 + 1)
    local dot = rgb(0xfb, 0xf8, 0xef)
    for ty = y0, y1 do
      for tx = x0, x1 do rectfill(tx * 16 - 1, ty * 16 - 1, tx * 16, ty * 16, dot) end
    end
    rect(plot.x * 16 - 1, plot.y * 16 - 1, (plot.x + plot.w) * 16, (plot.y + plot.h) * 16, C.gold)
    -- Weiden: gelbe Punkte auf jeder Kachel, Beschriftung an der ersten
    for _, pw in ipairs(pastures) do
      for _, t in ipairs(pw.list) do
        local x, y = t[1] * 16, t[2] * 16
        if x + 16 > cam.x and x < cam.x + SCREEN_W and y + 16 > cam.y and y < cam.y + SCREEN_H then
          rectfill(x + 7, y + 7, x + 8, y + 8, C.gold)
        end
      end
      local t = pw.list[1]
      print("Weide " .. pw.plaetze .. " Plätze", t[1] * 16 + 2, t[2] * 16 + 2, C.gold)
    end
    if c.id ~= "land" then
      for dy = 0, h - 1 do
        for dx = 0, w - 1 do ctx.S.draw(ok and "cursor_ok" or "cursor_bad", (cx + dx) * 16, (cy + dy) * 16) end
      end
    end
    camera()
    -- Leiste unten: gewähltes Bauteil, Meldung, Tasten
    local y = SCREEN_H - 36
    Stage.panel(0, y, SCREEN_W - 1, SCREEN_H - 1)
    local line
    if c.id == "abriss" then
      local it = Farm.item_at(farm, cx, cy)
      local pf = Farm.plant_at(farm, cx, cy)
      line = pf and ("Abreißen: " .. Farm.crop(pf.id).name .. " (Samen bleibt)")
        or it and ("Abreißen: " .. K.bauteil(it.id).name .. "  +" .. K.bauteil(it.id).preis .. " G") or "Abreißen: hier steht nichts"
    elseif c.id == "land" then
      local price, n = Farm.land_angebot(ctx, id)
      line = Farm.LAND_DIRS[id].name .. ": " .. (price and (n .. " Stück(e), " .. price .. " G") or "Kartenrand")
    elseif c.id == "pflanzen" then
      if id then
        local crop = Farm.crop(id)
        line = crop.name .. ": reif nach " .. crop.reif .. " T, dann alle " .. crop.dann .. " T, " .. crop.ertrag .. "x"
      else
        line = "Keine Samen im Vorrat"
      end
    else
      local b = K.bauteil(id)
      line = b.name .. "  " .. b.preis .. " G" .. (b.wirkung.schoenheit and ("  Schönheit +" .. b.wirkung.schoenheit) or "")
    end
    Menu.icon(c.id == "abriss" and "cursor_bad" or (id and build_icon(c.id, id)) or "ico_bauen", 16, y + 13, 20)
    print(line, 32, y + 5, ok and C.text or C.red)
    if msg_t > 0 then
      print(msg, 32, y + 16, C.dim)          -- Meldung bekommt die ganze Zeile
    else
      local bonus, next_at, score = Farm.schoenheit_bonus(farm)
      print("Schönheit " .. flr(score) .. (next_at and ("/" .. next_at) or "") .. "  Bindung +" .. bonus, 32, y + 16, C.dim)
    end
    Stage.center("A bauen   START Auswahl   B fertig", y + 27, C.gold)
    if picker then picker.m:draw() end
  end
  return s
end

-- ---- Inventar ----

function Screens.inventory(ctx)
  local s = {}
  function s.update(nav)
    if btnp(BTN_B) or btnp(BTN_A) then nav.pop() end
  end
  function s.draw()
    cls(C.panel)
    header("Inventar")
    print("Geld: " .. ctx.money .. " G", 20, 20, C.gold)
    local y, col = 36, 0
    for _, c in ipairs(Economy.CATEGORIES) do
      local lines = {}
      for _, it in ipairs(Economy.catalog(6)) do
        local n = Economy.owned(ctx, it.id)
        if it.kat == c.id and (n > 0 or (c.id == "futter" and it.id ~= "buerste")) then
          lines[#lines + 1] = {it.name, n}
        end
      end
      if #lines > 0 then
        print(c.name, 20, y, C.gold)
        y = y + 11
        for _, l in ipairs(lines) do
          print(l[1], 28, y, l[2] > 0 and C.text or C.dim)
          print("x" .. l[2], 200, y, l[2] > 0 and C.text or C.dim)
          y = y + 10
        end
        y = y + 4
      end
    end
    -- Ernte (C5)
    local crops = {}
    for _, id in ipairs({"apfel", "sonnenblumenkerne", "minze", "zuckerruebe", "luzerne", "drachenfrucht", "goldene_karotte"}) do
      if (ctx.inv[id] or 0) > 0 then crops[#crops + 1] = id end
    end
    if #crops > 0 then
      print("Ernte", 20, y, C.gold)
      y = y + 11
      for _, id in ipairs(crops) do
        print(Farm.CROP_NAME[id], 28, y, C.text)
        print("x" .. ctx.inv[id], 200, y, C.text)
        y = y + 10
      end
    end
    footer("B: zurück")
  end
  s.full = true
  return s
end

-- ---- Karte (E6): nur Erkundetes, 1 Kachel = 2 Pixel, wird einmal gezeichnet ----

local PX = 2

function Screens.map(ctx)
  local map, area = ctx.map, ctx.area
  local ox, oy = (SCREEN_W - map.w * PX) // 2, 22
  local s = {full = true, static = true}
  local drawn = false
  local byte = string.byte
  local colors = {}
  for ch, g in pairs(Tiles.GROUNDS) do colors[byte(ch)] = g.map end
  local cell = Explore.CELL
  function s.update(nav)
    if btnp(BTN_B) or btnp(BTN_A) or btnp(BTN_SELECT) then nav.pop() end
  end
  local function explored(tx, ty)
    return Explore.is_explored(ctx.explored, tx // cell, ty // cell)
  end
  function s.draw()
    if drawn then return end
    drawn = true
    cls(C.panel)
    header("Karte: " .. area.name .. "   " .. flr(Explore.share(ctx.explored) * 100) .. " % erkundet")
    rectfill(ox - 1, oy - 1, ox + map.w * PX, oy + map.h * PX, rgb(0x1a, 0x13, 0x12))
    for cy = 0, #ctx.explored - 1 do
      for cx = 0, #ctx.explored[1] - 1 do
        if Explore.is_explored(ctx.explored, cx, cy) then
          for ty = cy * cell, min(map.h - 1, cy * cell + cell - 1) do
            local row = map.ground[ty + 1]
            local tx = cx * cell
            local tx1 = min(map.w - 1, tx + cell - 1)
            while tx <= tx1 do
              local b = byte(row, tx + 1)
              local run = tx
              while run < tx1 and byte(row, run + 2) == b do run = run + 1 end
              rectfill(ox + tx * PX, oy + ty * PX, ox + run * PX + PX - 1, oy + ty * PX + PX - 1, colors[b])
              tx = run + 1
            end
          end
        end
      end
    end
    for k = 1, map.bw * map.bh do
      for _, o in ipairs(map.blocks[k] or {}) do
        if explored(o[2], o[3]) then
          local P = map.props[o[1]]
          local x, y = ox + o[2] * PX, oy + o[3] * PX
          rectfill(x, y, x + (P.w or 1) * PX - 1, y + (P.h or 1) * PX - 1, P.map)
        end
      end
    end
    -- Hof und Dorf, sobald etwas davon erkundet ist
    local p = area.plot
    if explored(p.x + p.w // 2, p.y + p.h // 2) then
      rect(ox + p.x * PX - 1, oy + p.y * PX - 1, ox + (p.x + p.w) * PX, oy + (p.y + p.h) * PX, C.gold)
      print("Hof", ox + p.x * PX + 3, oy + p.y * PX + 3, C.gold)
    end
    local v = area.village
    if v and explored(v.x + v.w // 2, v.y + v.h // 2) then
      print("Dorf", ox + v.x * PX + 2, oy + (v.y + v.h) * PX + 2, C.text)
    end
    -- gezähmte Pferde (gelbe Punkte) und der Spieler mit Blickrichtung (roter Pfeil)
    for _, h in ipairs(ctx.herd_horses) do
      if not h.hidden then
        local x, y = ox + flr(h.x / 16 * PX), oy + flr(h.y / 16 * PX)
        rectfill(x - 1, y - 1, x + 1, y + 1, C.gold)
        rect(x - 2, y - 2, x + 2, y + 2, C.panel)
      end
    end
    local pl = ctx.player
    local x, y = ox + flr(pl.x / 16 * PX), oy + flr(pl.y / 16 * PX)
    local dx, dy = 0, 1
    if pl.dir == "left" then dx, dy = -1, 0 elseif pl.dir == "right" then dx, dy = 1, 0 elseif pl.dir == "up" then dx, dy = 0, -1 end
    local tx, ty = x + dx * 6, y + dy * 6
    line(x, y, tx, ty, C.red)
    line(tx, ty, tx - dx * 3 - dy * 3, ty - dy * 3 + dx * 3, C.red)
    line(tx, ty, tx - dx * 3 + dy * 3, ty - dy * 3 - dx * 3, C.red)
    circfill(x, y, 2, C.red)
    circ(x, y, 3, C.text)
    footer("B: zurück")
    print("Pfeil: du   Gelb: Pferde", 120, SCREEN_H - 10, C.dim)
  end
  return s
end

-- ---- Sammelalbum (E5): eine Seite je Rasse, links/rechts blättern ----

function Screens.album(ctx)
  local Album = require("game.album")
  local page, sel = 1, 1
  local s = {full = true}
  local function rasse() return K.rassen.liste[page] end
  function s.update(nav)
    local n = #Album.farben(rasse().id)
    if btnp(BTN_LEFT) then page = (page - 2) % #K.rassen.liste + 1; sel = 1; SFX.select() end
    if btnp(BTN_RIGHT) then page = page % #K.rassen.liste + 1; sel = 1; SFX.select() end
    if btnp(BTN_UP) then sel = max(1, sel - 5); SFX.select() end
    if btnp(BTN_DOWN) then sel = min(n, sel + 5); SFX.select() end
    if btnp(BTN_B) or btnp(BTN_A) then SFX.back() nav.pop() end
  end
  function s.draw()
    cls(C.panel)
    local r = rasse()
    local all, total = Album.zaehler(ctx)
    header("Album  " .. all .. "/" .. total)
    local n1, t1 = Album.zaehler(ctx, r.id)
    print("< " .. r.name .. " >  " .. n1 .. "/" .. t1, 10, 20, C.gold)
    local colors = Album.farben(r.id)
    for i, f in ipairs(colors) do
      local col, row = (i - 1) % 5, (i - 1) // 5
      local x, y = 6 + col * 62, 36 + row * 38
      if i == sel then rectfill(x - 2, y - 2, x + 59, y + 35, C.panel_light) end
      rect(x, y, x + 57, y + 33, C.dim)
      if Album.gefunden(ctx, r.id, f) then
        G.draw(f, r.koerper, "side", x + 29, y + 31, false)
      else
        print("?", x + 26, y + 12, C.dim)
      end
    end
    local f = colors[sel]
    if f then
      local found = Album.gefunden(ctx, r.id, f)
      print(found and K.farbe(f).name or "Noch nicht entdeckt", 10, 200, found and C.text or C.dim)
    end
    footer("</>: Rasse   A/B: zurück")
  end
  return s
end

-- ---- Tauschen (E6): Pferd als Code abgeben oder einen Code einlösen ----

local CODE_ROWS = {"ABCDEFGH", "JKLMNPQR", "STUVWXYZ", "23456789"}

function Screens.tausch(ctx)
  local Tausch = require("game.tausch")
  local stage, sel, msg, msg_t, code, pick = "menu", 1, nil, 0, nil, nil
  local s = {full = true}
  local function say(t) msg, msg_t = t, 200 end
  local function herd() return ctx.herd end
  function s.update(nav)
    if msg_t > 0 then msg_t = msg_t - 1 end
    if stage == "code" then
      if btnp(BTN_A) or btnp(BTN_B) then stage, sel, code = "menu", 1, nil SFX.back() end
      return
    end
    local n = stage == "menu" and 2 or (stage == "pferd" and #herd() or 2)
    if btnp(BTN_UP) and n > 0 then sel = (sel - 2) % n + 1; SFX.select() end
    if btnp(BTN_DOWN) and n > 0 then sel = sel % n + 1; SFX.select() end
    if btnp(BTN_B) then
      SFX.back()
      if stage == "menu" then nav.pop() else stage, sel = "menu", 1 end
    elseif btnp(BTN_A) then
      if stage == "menu" then
        if sel == 1 then
          if #herd() == 0 then SFX.snort() say("Du hast kein Pferd zum Abgeben.")
          else stage, sel = "pferd", 1 SFX.ok() end
        else
          nav.push(Screens.keyboard("Code eingeben (28 Zeichen)", "", Tausch.LENGTH + 6, function(text)
            local h, why = Tausch.annehmen(ctx, text)
            if h then SFX.tame() say(h.data.name .. " ist angekommen und folgt dir.")
            else SFX.snort() say(({["Länge"] = "Der Code hat nicht 28 Zeichen.", ["Zeichen"] = "Unerlaubtes Zeichen im Code.", ["Prüfsumme"] = "Tippfehler im Code (Prüfsumme).", ["schon benutzt"] = "Dieser Code wurde schon eingelöst.", voll = "Der Hof ist voll."})[why] or "Der Code ist ungültig.") end
          end, CODE_ROWS))
        end
      elseif stage == "pferd" then
        pick, stage, sel = herd()[sel], "sicher", 2 SFX.ok()
      elseif stage == "sicher" then
        if sel == 1 then
          local c, why = Tausch.abgeben(ctx, pick)
          if c then code, stage = Tausch.format(c), "code" SFX.tame() else say(why .. "."); stage, sel = "menu", 1 end
        else stage, sel = "menu", 1 end
      end
    end
  end
  function s.draw()
    cls(C.panel)
    header("Pferde tauschen")
    if stage == "menu" then
      for i, l in ipairs({"Pferd abgeben (Code erhalten)", "Code eingeben (Pferd erhalten)"}) do
        local y = 30 + (i - 1) * 16
        if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 11, C.panel_light) end
        print(l, 10, y, i == sel and C.gold or C.text)
      end
      print("Ohne Server: Abgeben gibt einen Code.", 10, 80, C.dim)
      print("Der andere gibt ihn bei sich ein.", 10, 92, C.dim)
      print("Danach ist das Pferd bei dir weg.", 10, 104, C.dim)
      print("Name, Stammbaum, Ausrüstung bleiben.", 10, 116, C.dim)
    elseif stage == "pferd" then
      for i, d in ipairs(herd()) do
        local y = 24 + (i - 1) * 12
        if y > 200 then break end
        if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 9, C.panel_light) end
        print(d.name .. ", " .. K.rasse(d.rasse).name, 10, y, i == sel and C.gold or C.text)
      end
    elseif stage == "sicher" then
      Stage.center("Wirklich " .. pick.name .. " abgeben?", 70, C.gold)
      Stage.center("Danach ist das Pferd weg.", 86, C.dim)
      for i, l in ipairs({"Ja, Code erzeugen", "Nein"}) do
        local y = 110 + (i - 1) * 16
        if i == sel then rectfill(80, y - 2, 239, y + 11, C.panel_light) end
        print(l, 90, y, i == sel and C.gold or C.text)
      end
    else
      Stage.center("Dein Code - gut aufschreiben!", 40, C.gold)
      local a, b = code:sub(1, 19), code:sub(21)
      Stage.center(a, 80, C.text, 2)
      Stage.center(b, 104, C.text, 2)
      Stage.center("Das Pferd ist jetzt weg. A: weiter", 160, C.dim)
    end
    if msg and msg_t > 0 then print(msg, 10, 210, C.red) end
    footer(stage == "code" and "A: weiter" or "A: wählen   B: zurück")
  end
  return s
end

-- ---- Zeitung (E4): aktive Reformen, nächste Ausgabe ----

function Screens.zeitung(ctx)
  local Reformen = require("game.reformen")
  local s = {full = true}
  function s.update(nav)
    if btnp(BTN_B) or btnp(BTN_A) then SFX.back() nav.pop() end
  end
  function s.draw()
    cls(rgb(0xe8, 0xdd, 0xc0))
    rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
    print("Hoofy-Bote", 6, 3, C.gold)
    local day = ctx.clock and ctx.clock.day or 1
    local ink = rgb(0x2b, 0x1f, 0x1d)
    local st = Reformen.state(ctx)
    print("Die Regierung ist radikal. Neu im Land:", 10, 22, ink)
    local y = 40
    if #st.aktiv == 0 then print("Zurzeit gilt keine Reform.", 10, y, ink) y = y + 14 end
    for _, a in ipairs(st.aktiv) do
      local def = Reformen.def(a.id)
      def = {name = def.name, text = (def.text:gsub("–", "-"):gsub("≥", ">=")):gsub("×", "x")}
      print(def.name .. "  (noch bis Tag " .. a.bis .. ")", 10, y, rgb(0xb8, 0x47, 0x3a))
      for i, l in ipairs(require("lib.util").wrap(def.text, SCREEN_W - 30)) do print(l, 18, y + 10 * i, ink) end
      y = y + 12 + 10 * #require("lib.util").wrap(def.text, SCREEN_W - 30) + 6
      if a.id == "pferdesteuer" then print("Heute " .. Reformen.steuer(day) .. " G je Pferd.", 18, y - 8, ink) y = y + 8 end
    end
    print("Nächste Ausgabe an Tag " .. st.naechste, 10, 206, ink)
    footer("B: zurück")
  end
  return s
end

-- ---- Pausenmenü (E5) ----

function Screens.pause(ctx, nav)
  local F = require("game.fortschritt")
  local day = F.tag(ctx)
  local all = {
    {label = "Weiter", id = "resume", icon = "ico_weiter"},
    {label = "Pferde", id = "horses", icon = "icon_horse"},
    {label = "Inventar", id = "inventory", icon = "ico_vorrat", short = "Vorrat"},
    {label = "Bestellungen", id = "orders", icon = "ico_kunden", short = "Kunden", ab = "bestellungen"},
    {label = "Karte", id = "map", icon = "ico_karte"},
    {label = "Bauen", id = "build", dim = not ctx.on_plot or not ctx.on_plot(), icon = "ico_bauen"},
    {label = "Zeitung", id = "news", icon = "ico_zeitung", ab = "zeitung"},
    {label = "Album", id = "album", icon = "ico_album"},
    {label = "Tauschen", id = "swap", icon = "ico_tausch", short = "Tausch", ab = "tauschen"},
    {label = "Speichern", id = "save", dim = not ctx.saving_ok, icon = "ico_sichern", short = "Sichern"},
  }
  local items = {}                 -- noch nicht freigeschaltete Einträge fehlen ganz (Fortschritt)
  for _, it in ipairs(all) do if not it.ab or F.offen(it.ab, day) then items[#items + 1] = it end end
  local m = Menu.new(items, "Pause")
  local s = {}
  function s.update(n)
    if btnp(BTN_START) and not btn(BTN_SELECT) then return n.pop() end
    local r = m:update()
    if r == "close" or r == "resume" then n.pop()
    elseif r == "horses" then n.push(Screens.horses(ctx))
    elseif r == "map" then n.push(Screens.map(ctx))
    elseif r == "build" then
      n.pop()
      n.push(Screens.build(ctx))
    elseif r == "news" then n.push(Screens.zeitung(ctx))
    elseif r == "album" then n.push(Screens.album(ctx))
    elseif r == "swap" then n.push(Screens.tausch(ctx))
    elseif r == "orders" then n.push(Screens.orders(ctx))
    elseif r == "inventory" then n.push(Screens.inventory(ctx))
    elseif r == "save" then
      ctx.save()
      ctx.toast("Gespeichert.")
      n.pop()
    end
  end
  function s.draw()
    local _, h = m:size()
    m:draw(nil, (SCREEN_H - h) // 2 + 6)
  end
  s.items = items
  s.overlay = true        -- Welt bleibt darunter sichtbar
  return s
end

return Screens
