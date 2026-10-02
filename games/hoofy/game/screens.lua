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
local Care = require("game.care")
local S = require("sprites")

local Screens = {}

local C = Stage.COLORS

local function header(title)
  rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
  print(title, 6, 3, C.gold)
end

-- Tastenleiste unten: etwas heller als der Bildschirm, mit Trennlinie
local FOOTER_BG = rgb(0x3d, 0x2c, 0x25)
-- Teile wie „A: kaufen“ sind durch mindestens zwei Leerzeichen getrennt; solange die Taste gedrückt ist,
-- leuchtet ihr Teil gold (Klick-Effekt).
local FOOTER_KEYS = {A = {BTN_A}, B = {BTN_B}, v = {BTN_DOWN}, ["^"] = {BTN_UP}, START = {BTN_START},
  ["<"] = {BTN_LEFT, BTN_RIGHT}, ["</>"] = {BTN_LEFT, BTN_RIGHT}, ["A/B"] = {BTN_A, BTN_B}}
local function held(part)
  local key = part:match("^(%S+)"):gsub(":$", "")
  for _, b in ipairs(FOOTER_KEYS[key] or {}) do if btn(b) then return true end end
  return false
end
local function footer(text, bg, edge)
  rectfill(0, SCREEN_H - 13, SCREEN_W - 1, SCREEN_H - 1, bg or FOOTER_BG)
  line(0, SCREEN_H - 13, SCREEN_W - 1, SCREEN_H - 13, edge or C.panel_light)
  local x, pos = 6, 1
  while pos <= #text do
    local a, b = text:find("%s%s+", pos)
    local part = text:sub(pos, (a or #text + 1) - 1)
    print(part, x, SCREEN_H - 10, held(part) and C.gold or C.text)
    x = x + textw(text:sub(pos, b or #text))
    pos = (b or #text) + 1
  end
end

local ORT = {stall = "im Stall", weide = "auf der Weide", frei = "frei auf dem Hof", anhaenger = "im Anhänger", goepel = "am Göpel"}

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
      SFX.back()
      nav.pop()                                   -- B bricht ab, nichts wird übernommen (Rückmeldung 1.3.4)
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
    footer("A: Zeichen   B: abbrechen")
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
local STATE_COL = rgb(0x98, 0xc8, 0xde) -- Zustand: Überschrift, Balken, Zahl
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
local FILL = {gen = {0x9a, 0xdc, 0xb4}, train = {0x3a, 0xb0, 0x8e}, state = {0x98, 0xc8, 0xde}, red = {0xe0, 0x47, 0x5a}}

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

-- Pferde-Info: ← → blättert durch die eigenen Pferde (ctx.herd), ↓ Stammbaum, A umbenennen, B zurück.
function Screens.info(ctx, data)
  local s = {}
  local herd = ctx.herd or {}
  local function index()
    for i, d in ipairs(herd) do if d == data then return i end end
  end
  function s.update(nav)
    if btnp(BTN_B) then nav.pop() end
    if btnp(BTN_A) then
      local d = data
      nav.push(Screens.keyboard("Neuer Name", d.name, 12, function(text) d.name = text H.reserve_name(text) end))
    end
    if btnp(BTN_DOWN) then SFX.ok() nav.push(Screens.stammbaum(ctx, data)) end
    local i = index()
    if i and #herd > 1 then
      if btnp(BTN_LEFT) then data = herd[(i - 2) % #herd + 1] SFX.select() end
      if btnp(BTN_RIGHT) then data = herd[i % #herd + 1] SFX.select() end
    end
  end
  function s.draw()
    cls(C.panel)
    -- Kopf: Name groß, Wert rechts
    rectfill(0, 0, SCREEN_W - 1, 21, C.panel)
    font(1)                                          -- feinere große Schrift (API 3)
    local nx = print(data.name, 6, 3, C.gold)
    if index() and #herd > 1 then print("< >", nx + 8, 3, rgb(0x6e, 0x5c, 0x4c)) end   -- blass: ← → blättert
    font(0)
    local wert = "Wert " .. Value.wert(data) .. " G"
    print(wert, SCREEN_W - textw(wert) - 6, 7, C.gold)
    box(3, 23, SCREEN_W - 4, 80, BOX_ABOUT)
    rect(4, 24, SCREEN_W - 5, 79, BOX_ABOUT_EDGE)
    box(3, 83, SCREEN_W - 4, 146, BOX_SKILL)
    box(3, 149, SCREEN_W - 4, 224, BOX_STATE)
    -- Bild oben rechts unter dem Wert
    local rasse = K.rasse(data.rasse)
    Stage.panel(SCREEN_W - 77, 26, SCREEN_W - 7, 77)                -- oben und unten 3 px Abstand zum Kasten (23–80)
    rectfill(SCREEN_W - 75, 28, SCREEN_W - 9, 75, rgb(0x7f, 0xb0, 0x4f))
    G.draw(data.farbe, rasse.koerper, "side", SCREEN_W - 42, 68, false, data.schmuck)
    if data.alter < 1 then                          -- Fohlen: wie weit ausgewachsen
      rectfill(SCREEN_W - 73, 72, SCREEN_W - 11, 73, rgb(0x1e, 0x16, 0x14))   -- unten im Bild
      rectfill(SCREEN_W - 73, 72, SCREEN_W - 73 + flr(62 * data.alter), 73, C.gold)
    end
    -- Steckbrief links
    local sexw = data.sex == "m" and (data.alter < 1 and "Hengstfohlen" or "Hengst") or (data.alter < 1 and "Stutfohlen" or "Stute")
    print(sexw .. ", " .. rasse.name, 8, 27, C.text)
    local farbe = K.farbe(data.farbe).name        -- nur die sichtbare Farbe, die versteckte (farbe2) bleibt geheim
    if textw("Farbe: " .. farbe) <= SCREEN_W - 90 then farbe = "Farbe: " .. farbe end
    print(farbe, 8, 38, C.dim)
    print("Charakter: " .. K.charakter[data.zug].name, 8, 49, C.dim)
    print("Ort: " .. place_of(data), 8, 60, C.dim)
    local extra
    if data.traechtig then extra = "Trächtig bis Tag " .. data.traechtig.tag
    elseif data.zucht_pause and ctx.clock and data.zucht_pause > ctx.clock.day then extra = "Zuchtpause bis Tag " .. data.zucht_pause
    elseif data.reit_ab and data.bindung < data.reit_ab then extra = "Frisch gezähmt: noch nicht reitbar"
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
    footer("A umbenennen   v Stammbaum   B zurück")
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
      G.draw(d.farbe, K.rasse(d.rasse).koerper, "side", 26, y + 17, false, d.schmuck)
      print(d.name, 50, y, i == sel and C.gold or C.text)
      print(K.rasse(d.rasse).name, 50, y + 9, C.dim)
    end
    footer("A: Info   B: zurück")
  end
  s.full = true
  return s
end

-- ---- Laden (E13): Menübildschirm an der Tür, keine begehbaren Innenräume ----

-- Eigene Farben des Ladens: Rot, Dunkelrot, Rosa
local SHOP = {
  bg = rgb(0x3b, 0x10, 0x1a),      -- Grund
  dark = rgb(0x24, 0x08, 0x0e),    -- Kopf, Fuß, Textkasten
  tab = rgb(0x7a, 0x1f, 0x30),     -- Reiter
  pink = rgb(0xf3, 0x9b, 0xb8),    -- aktiver Reiter mit Linie, „Laden:“
  sel = rgb(0x9e, 0x2a, 0x3e),     -- gewählte Zeile
  dim = rgb(0xc9, 0x8f, 0x9c),     -- nicht kaufbar, Beschreibung
}

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
        msg = why == "Geld" and "Zu wenig Geld." or why == "Garage" and Economy.garage_text(list[sel].id) or "Hast du schon."
      end
      msg_t = 120
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
  end
  function s.draw()
    cls(SHOP.bg)
    rectfill(0, 0, SCREEN_W - 1, 13, SHOP.dark)
    print("Laden:", 6, 3, SHOP.pink)
    print(Economy.CATEGORIES[cat].name, 6 + textw("Laden: "), 3, C.text)
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 3, C.gold)
    -- Reiter als Icons über die ganze Breite (die Namen passen nicht nebeneinander), Name steht im Kopf.
    -- Darunter eine Linie in der Farbe des aktiven Reiters, der aktive Reiter geht in sie über.
    local n = #Economy.CATEGORIES
    local w = (SCREEN_W - 12 - (n - 1) * 3) // n
    rectfill(0, 32, SCREEN_W - 1, 33, SHOP.pink)
    for i, c in ipairs(Economy.CATEGORIES) do
      local x = 6 + (i - 1) * (w + 3)
      if i == cat then rectfill(x, 17, x + w - 1, 33, SHOP.pink) else rectfill(x, 18, x + w - 1, 30, SHOP.tab) end
      Menu.icon(c.icon, x + w // 2, 24, 12)
    end
    local list = items()
    local y = 40
    local first = max(1, sel - 8)
    for i = first, min(#list, first + 8) do
      local it = list[i]
      -- Fahrzeuge: Trennlinie vor den Anhängern
      if it.anhaenger and i > first and not list[i - 1].anhaenger then
        line(10, y - 2, SCREEN_W - 11, y - 2, SHOP.tab)
        y = y + 4
      end
      local price = Economy.price(ctx, it)
      local n = Economy.owned(ctx, it.id)
      local can = ctx.money >= price and not (it.einmalig and n > 0)
      if i == sel then
        rectfill(4, y - 2, SCREEN_W - 5, y + 10, SHOP.sel)
        rectfill(4, y - 2, 5, y + 10, SHOP.pink)
      end
      print(it.name, 10, y, can and C.text or SHOP.dim)
      print(price .. " G", 210, y, can and C.gold or SHOP.dim)
      print(n > 0 and ("x" .. n) or "", 270, y, SHOP.dim)
      y = y + 14
    end
    local cur = list[sel]
    if cur then
      rectfill(0, 172, SCREEN_W - 1, 215, SHOP.dark)
      -- Fahrzeuge und Anhänger mit Bild rechts im Kasten
      local pic = cur.fahrzeug and "fahrzeug_" .. cur.id or cur.anhaenger and "anhaenger_" .. cur.anhaenger
      local pw = 0
      if pic then
        local w, h = ctx.S.size(pic)
        pw = w + 10
        ctx.S.draw(pic, SCREEN_W - 6 - w, 211 - h)
      end
      local t = (cur.text:gsub("−", "-"))
      local lines = require("lib.util").wrap(t, SCREEN_W - 16 - pw)
      for i, line in ipairs(lines) do if i <= 4 then print(line, 8, 176 + (i - 1) * 10, SHOP.dim) end end
    end
    if msg and msg_t > 0 then print(msg, 8, 218, C.gold) end
    footer("A: kaufen   </>: Reiter   B: zurück", SHOP.dark, SHOP.tab)
  end
  return s
end

-- ---- Reisemenü am Fahrzeug (D1): Aufbau wie die Pferde-Info. Oben das Fahrzeug (← → wechselt zwischen den
-- Fahrzeugen im selben Gebäude), darunter die Ziele; A fährt, B zurück ----

-- Eigene Farben des Reisemenüs: gedämpfte Blautöne (Rückmeldung 0.5.9)
local GARAGE = {
  bg = rgb(0x1c, 0x24, 0x33),      -- Grund
  dark = rgb(0x14, 0x1a, 0x26),    -- Fuß, Bildrahmen
  about = rgb(0x28, 0x34, 0x49),   -- Kasten Fahrzeug
  edge = rgb(0x34, 0x43, 0x5c),
  list = rgb(0x21, 0x2b, 0x3c),    -- Kasten Ziele
  sel = rgb(0x3a, 0x4c, 0x6c),     -- gewählte Zeile
  head = rgb(0xa8, 0xc8, 0xe8),    -- „Wohin?“
  dim = rgb(0x93, 0xa2, 0xb8),     -- nicht wählbar, Nebentext
  pale = rgb(0x56, 0x66, 0x80),    -- „< >“
}
local function gbox(x0, y0, x1, y1, c)
  rectfill(x0, y0, x1, y1, c)
  pset(x0, y0, GARAGE.bg) pset(x1, y0, GARAGE.bg) pset(x0, y1, GARAGE.bg) pset(x1, y1, GARAGE.bg)
end

function Screens.reise(ctx, go)
  local Reise = require("game.reise")
  local sel, msg, msg_t = 1, nil, 0
  local armed = false            -- A erst nach dem Loslassen: gehaltenes A vom Öffnen fährt sonst gleich los
  local s = {full = true}
  -- Ziele, darunter „Pferde ausladen“, solange welche im Anhänger sind
  local function entries()
    local list = Reise.ziele(ctx)
    local n = Reise.geladen(ctx)
    if n > 0 then list[#list + 1] = {ausladen = n, ok = true} end
    return list
  end
  Reise.wahl(ctx)                -- an einer anderen Garage: deren Fahrzeug vorwählen
  function s.update(nav)
    local list = entries()
    local wahl = Reise.wahl(ctx)
    if #wahl > 1 and (btnp(BTN_LEFT) or btnp(BTN_RIGHT)) then
      local i = 1
      for k, f in ipairs(wahl) do if f == Economy.aktiv(ctx) then i = k end end
      i = btnp(BTN_LEFT) and (i - 2) % #wahl + 1 or i % #wahl + 1
      Economy.waehlen(ctx, wahl[i].id)
      SFX.select()
      list = entries()
    end
    if sel > #list then sel = max(1, #list) end
    if btnp(BTN_UP) and #list > 0 then sel = (sel - 2) % #list + 1; SFX.select() end
    if btnp(BTN_DOWN) and #list > 0 then sel = sel % #list + 1; SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() end
    if not armed then armed = not btn(BTN_A) return end
    if btnp(BTN_A) and list[sel] then
      if list[sel].ausladen then
        local n = Reise.ausladen(ctx)
        SFX.ok()
        nav.pop()
        if ctx.toast then ctx.toast(n == 1 and "Ein Pferd steht jetzt neben dem Anhänger." or n .. " Pferde stehen jetzt neben dem Anhänger.") end
      elseif list[sel].ok then SFX.start() go(list[sel].nr)
      else SFX.snort() msg, msg_t = (list[sel].grund or "geht nicht") .. ".", 150 end
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
  end
  function s.draw()
    cls(GARAGE.bg)
    local f, plaetze = Economy.aktiv(ctx), Economy.plaetze(ctx)
    local wahl = Reise.wahl(ctx)
    -- Kopf: Fahrzeug groß, „< >“ blass, wenn es im Gebäude noch andere gibt; Geld rechts
    font(1)
    local nx = print(f.name, 6, 3, C.gold)
    if #wahl > 1 then print("< >", nx + 8, 3, GARAGE.pale) end
    font(0)
    local money = ctx.money .. " G"
    print(money, SCREEN_W - textw(money) - 6, 7, C.gold)
    -- Steckbrief: Anhänger, Reichweite, Sprit; rechts das Gespann auf Gras
    gbox(3, 23, SCREEN_W - 4, 80, GARAGE.about)
    rect(4, 24, SCREEN_W - 5, 79, GARAGE.edge)
    local rw = Reise.rig_width(ctx.S, f.id, plaetze)
    local pw = max(70, rw + 16)
    local px = SCREEN_W - 7 - pw
    rectfill(px, 26, SCREEN_W - 7, 77, GARAGE.dark)
    rect(px + 1, 27, SCREEN_W - 8, 76, GARAGE.edge)
    -- Hintergrund grau mit angedeuteter Straße: hellerer Gehweg oben, Fahrbahn mit gestrichelter Mittellinie
    rectfill(px + 2, 28, SCREEN_W - 9, 75, rgb(0x8a, 0x90, 0x98))
    rectfill(px + 2, 60, SCREEN_W - 9, 75, rgb(0x5c, 0x62, 0x6b))
    line(px + 2, 59, SCREEN_W - 9, 59, rgb(0x6d, 0x73, 0x7a))
    for x = px + 4, SCREEN_W - 13, 10 do line(x, 73, x + 5, 73, rgb(0xc8, 0xcd, 0xd1)) end
    Reise.draw_rig(ctx.S, f.id, plaetze, px + (pw - rw) // 2, 70)
    local n = Reise.geladen(ctx)
    print(plaetze > 0 and ("Anhänger: " .. n .. "/" .. plaetze) or "Kein Anhänger", 8, 27, C.text)
    if #ctx.lead > 0 then print("An der Leine: " .. #ctx.lead, 8, 38, GARAGE.dim) end
    print("Bis " .. K.welt.gebiete[f.gebiete].name, 8, 49, GARAGE.dim)
    print(f.fahrtkosten > 0 and ("Sprit " .. f.fahrtkosten .. " G/Gebiet") or "Sprit: gratis", 8, 60, GARAGE.dim)
    -- Ziele
    gbox(3, 83, SCREEN_W - 4, 224, GARAGE.list)
    print("Wohin?", 8, 87, GARAGE.head)
    local list = entries()
    local y = 101
    for i, z in ipairs(list) do
      if i == sel then rectfill(6, y - 2, SCREEN_W - 7, y + 9, GARAGE.sel) end
      if z.ausladen then
        print("Pferde ausladen (" .. z.ausladen .. ")", 12, y, i == sel and C.gold or C.text)
      else
        print(z.nr .. "  " .. z.name .. (z.nr == 1 and " (heim)" or ""), 12, y, z.ok and (i == sel and C.gold or C.text) or GARAGE.dim)
        local k = z.kosten > 0 and (z.kosten .. " G") or "gratis"
        print(k, SCREEN_W - 12 - textw(k), y, z.ok and C.gold or GARAGE.dim)
      end
      y = y + 13
    end
    if #list == 0 then print("Mit diesem Fahrzeug geht es nirgends hin.", 12, y, GARAGE.dim) end
    local cur = list[sel]
    if msg and msg_t > 0 then print(msg, 12, 210, C.red)
    elseif cur and not cur.ok then print(cur.grund .. ".", 12, 210, GARAGE.dim) end
    local a = cur and cur.ausladen and "A ausladen" or "A losfahren"
    footer(a .. (#wahl > 1 and "   < > Fahrzeug" or "") .. "   B zurück", GARAGE.dark, GARAGE.edge)
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
      print("Leistung x" .. flr(Value.leistungsfaktor(d) * 100 + 0.5) / 100 .. ", Wert " .. Value.wert(d) .. " G", 8, 182, C.dim)
      print("Farbfaktor x" .. Value.farbfaktor(d) .. ", Kauf = Wert x1,5", 8, 193, C.dim)
    end
    if msg and msg_t > 0 then print(msg, 8, 218, C.gold) end
    footer("A: kaufen   B: zurück")
  end
  return s
end

-- ---- Turnierplatz (E1): Klasse → Wettbewerb → Pferd (mit Chancen) → Ergebnis ----

-- Eigene Farben des Turnierplatzes: Grüntöne mit Gelb (Rückmeldung 1.3.5), Aufbau wie Garage und Pferde-Info
local TURNIER = {
  bg = rgb(0x16, 0x2b, 0x1a),      -- Grund
  dark = rgb(0x0e, 0x1e, 0x12),    -- Fuß, Bildrahmen
  about = rgb(0x22, 0x40, 0x28),   -- oberer Kasten
  edge = rgb(0x30, 0x58, 0x37),
  list = rgb(0x1b, 0x35, 0x21),    -- Kasten Liste
  sel = rgb(0x35, 0x66, 0x3d),     -- gewählte Zeile
  head = rgb(0xa6, 0xe0, 0x8a),    -- Überschriften (Hellgrün)
  dim = rgb(0x8f, 0xb0, 0x92),     -- Nebentext, nicht wählbar
  yellow = rgb(0xf6, 0xdc, 0x4a),  -- Gewähltes, Geld, Preise
  grass = rgb(0x7f, 0xb0, 0x4f),
}
local RESULT_WAIT = 45             -- Ergebnis: so lange (und bis A losgelassen ist) nimmt es keine Taste an

local function tbox(x0, y0, x1, y1, c)
  rectfill(x0, y0, x1, y1, c)
  pset(x0, y0, TURNIER.bg) pset(x1, y0, TURNIER.bg) pset(x0, y1, TURNIER.bg) pset(x1, y1, TURNIER.bg)
end

local function wb_name(id)
  for _, w in ipairs(K.turniere.wettbewerbe) do if w.id == id then return (w.name:gsub(" %(Minispiel%)", "")) end end
  return id
end

local function rprint(text, xr, y, c) print(text, xr - textw(text), y, c) end

-- Siegerpodest mit Pferden (doppelt groß) in y0–y1: Platz 2 links, 1 Mitte, 3 rechts. Das eigene Pferd steht auf
-- seinem Platz (mit Namen darüber), die übrigen Plätze bekommen Gegnerpferde.
local PODEST = {{x = 160, top = 132}, {x = 88, top = 142}, {x = 232, top = 148}}   -- Mitte der Stufe, Oberkante
local function podest(ctx, r)
  local Turniere = require("game.turniere")
  local y0, y1 = 40, 168
  rectfill(4, y0, SCREEN_W - 5, y1, rgb(0x9c, 0xc8, 0xe0))           -- Himmel
  rectfill(4, 154, SCREEN_W - 5, y1, TURNIER.grass)                   -- Rasen
  -- die stärksten Gegner stehen oben (dieselben Pferde wie auf der Rennbahn)
  local looks, g = Turniere.gegner_pferde(ctx, r.kidx, r.wb, r.runde), Turniere.gegner(ctx, r.kidx, r.wb, r.runde)
  local order = {}
  for i = 1, #looks do order[i] = i end
  table.sort(order, function(x, y) return g[x] > g[y] end)
  local fremde, n = {}, 0
  for i, k in ipairs(order) do fremde[i] = looks[k] end
  if r.lauf then                                    -- Minispiel: echter Einlauf ohne das eigene Pferd
    fremde = {}
    for _, e in ipairs(r.lauf) do if not e.own and e.look then fremde[#fremde + 1] = e.look end end
  end
  local cols = {{0xf6, 0xdc, 0x4a}, {0xc8, 0xcc, 0xd2}, {0xd0, 0x8a, 0x4a}}       -- Gold, Silber, Bronze
  for platz = 1, 3 do
    local p = PODEST[platz]
    rectfill(p.x - 34, p.top, p.x + 33, 160, col(cols[platz]))
    line(p.x - 34, p.top, p.x + 33, p.top, C.text)
    local num = tostring(platz)
    print(num, p.x - textw(num) // 2, p.top + 3, mix(cols[platz], {0, 0, 0}, 0.35))   -- wie dunkel durchscheinend
    local own = platz == r.rank
    local d = own and r.d
    if not d then n = n + 1 d = fremde[n] end
    local body = K.rasse(d.rasse).koerper
    G.draw_scaled(d.farbe, body, "side", p.x, p.top, 2, platz == 3, own and d.schmuck or nil)
    if own then
      local _, h = G.size(d.farbe, body, "side")
      local nm = d.name
      rectfill(p.x - textw(nm) // 2 - 3, p.top - h * 2 - 13, p.x + (textw(nm) + 1) // 2 + 2, p.top - h * 2 - 3, TURNIER.dark)
      print(nm, p.x - textw(nm) // 2, p.top - h * 2 - 11, TURNIER.yellow)
    end
  end
end

function Screens.turnier(ctx)
  local Turniere = require("game.turniere")
  local U = require("lib.util")
  local stage, sel, sel_k, sel_w, result, msg, msg_t = "klasse", 1, nil, nil, nil, nil, 0
  local wait, armed, lock = 0, true, 0
  local chancen = {}               -- Chancen je Pferd, solange Klasse und Wettbewerb gleich bleiben
  local day = ctx.clock.day
    local s = {full = true}
  local function lists()
    if stage == "klasse" then return Turniere.klassen(ctx) end
    if stage == "wb" then return K.turniere.wettbewerbe end
    local out = {}
    for _, d in ipairs(ctx.herd) do if d.alter >= 1 then out[#out + 1] = d end end
    return out
  end
  local function aussicht(d)                -- 0–3 Hufeisen (Rennen: aus der Bestzeit gegen die Gegner)
    if not chancen[d] then
      local M = sel_w == "pferderennen" and "game.rennen" or sel_w == "springreiten" and "game.springen" or "game.vorfuehrung"
      chancen[d] = require(M).aussicht(d, sel_k)
    end
    return chancen[d]
  end
  local function offen(k)
    local n, st = 0, Turniere.state(ctx, day)
    for _, w in ipairs(K.turniere.wettbewerbe) do if not st.weg[k .. ":" .. w.id] then n = n + 1 end end
    return n
  end
  local function rest_text()
    local rest = (Turniere.runde(day) + 1) * K.turniere.rotation_tage + 1 - day
    return rest == 1 and "Neue Wettbewerbe morgen" or ("Neue Wettbewerbe in " .. rest .. " Tagen")
  end
  function s.update(nav)
    local list = lists()
    if msg_t > 0 then msg_t = msg_t - 1 end
    if stage == "ergebnis" then
      -- Erst nach der Sperrzeit und nach dem Loslassen: A vom Rennen/Springen schaltet sonst gleich weiter
      if wait > 0 then wait = wait - 1 end
      if not armed then armed = wait == 0 and not btn(BTN_A) and not btn(BTN_B) return end
      if btnp(BTN_A) or btnp(BTN_B) then
        SFX.ok() stage, sel, result = "klasse", 1, nil
        lock, armed = 30, false            -- danach wieder erst nach Pause und Loslassen (kein neuer Start per Dauerdrücken)
      end
      return
    end
    if lock > 0 or not armed then
      if lock > 0 then lock = lock - 1 end
      armed = lock == 0 and not btn(BTN_A) and not btn(BTN_B)
      return
    end
    if btnp(BTN_UP) and #list > 0 then sel = (sel - 2) % #list + 1; SFX.select() end
    if btnp(BTN_DOWN) and #list > 0 then sel = sel % #list + 1; SFX.select() end
    if btnp(BTN_B) then
      SFX.back()
      if stage == "klasse" then nav.pop()
      elseif stage == "wb" then
        for i, c in ipairs(Turniere.klassen(ctx)) do if c.index == sel_k then sel = i end end
        stage = "klasse"
      else
        for i, w in ipairs(K.turniere.wettbewerbe) do if w.id == sel_w then sel = i end end
        stage = "wb"
      end
    end
    if btnp(BTN_A) and list[sel] then
      if stage == "klasse" then sel_k, stage, sel = list[sel].index, "wb", 1 SFX.ok()
      elseif stage == "wb" then
        local st = Turniere.state(ctx, day)
        if st.weg[sel_k .. ":" .. list[sel].id] then SFX.snort() msg, msg_t = "Schon gelaufen. " .. rest_text() .. ".", 150
        else sel_w, stage, sel, chancen = list[sel].id, "pferd", 1, {} SFX.ok() end
      else
        local d = list[sel]
        local function antreten(leistung, platz, lauf)  -- Leistung 0–1 aus dem Minispiel (Rennen: Platz, Zieleinlauf)
          local punkte = Turniere.endwertung(d, sel_w, sel_k, leistung)
          local r, why = Turniere.teilnehmen(ctx, day, d, sel_k, sel_w, punkte, platz)
          if r then
            r.d, r.kidx, r.runde, r.lauf = d, sel_k, Turniere.state(ctx, day).runde, lauf
            result, stage, wait, armed = r, "ergebnis", RESULT_WAIT, false
            if r.rank == 1 then SFX.tame() else SFX.ok() end
          else SFX.snort() msg, msg_t = why == "Geld" and "Zu wenig Geld für die Startgebühr." or (why .. "."), 150 end
        end
        if ctx.money < K.turniere.klassen[sel_k].gebuehr then
          SFX.snort() msg, msg_t = "Zu wenig Geld für die Startgebühr.", 150
        elseif sel_w == "springreiten" then
          nav.push(Screens.springreiten(ctx, d, antreten, sel_k, Turniere.gegner_pferde(ctx, sel_k, sel_w, Turniere.state(ctx, day).runde)))
        elseif sel_w == "pferderennen" then
          nav.push(Screens.rennen(ctx, d, {}, antreten, sel_k, Turniere.gegner_pferde(ctx, sel_k, sel_w, Turniere.state(ctx, day).runde)))
        else
          nav.push(Screens.vorfuehrung(ctx, d, antreten, sel_k, Turniere.gegner_pferde(ctx, sel_k, sel_w, Turniere.state(ctx, day).runde)))
        end
      end
    end
  end

  -- Untere Zeilen (Kasten y 194–224) zum gewählten Eintrag
  local function detail()
    local list = lists()
    local e = list[sel]
    local l1, l2
    if stage == "klasse" and e then
      local k = e.def
      l1, l2 = {"Preise " .. k.preise[1] .. " / " .. k.preise[2] .. " / " .. k.preise[3] .. " G", TURNIER.yellow}, {rest_text(), TURNIER.dim}
    elseif stage == "wb" and e then
      local w = U.wrap(e.text, SCREEN_W - 24)
      l1, l2 = {w[1], TURNIER.dim}, w[2] and {w[2], TURNIER.dim}
    elseif stage == "pferd" and e then
      local skill = sel_w == "schoenheitswettbewerb" and ("Auftritt " .. flr(Turniere.fach(e, sel_w)))
        or sel_w == "springreiten" and ("Stärke " .. flr(Care.effective(e, "staerke")) .. "   Ausdauer " .. flr(Care.effective(e, "ausdauer")))
        or ("Tempo " .. flr(Care.effective(e, "tempo")) .. "   Ausdauer " .. flr(Care.effective(e, "ausdauer")))
      l1, l2 = {skill, C.text}, {"Bindung " .. flr(e.bindung), TURNIER.dim}
    end
    if msg and msg_t > 0 then l2 = {msg, C.red} end
    tbox(3, 194, SCREEN_W - 4, 224, TURNIER.about)
    if l1 then print(l1[1], 10, 198, l1[2]) end
    if l2 then print(l2[1], 10, 210, l2[2]) end
  end

  function s.draw()
    cls(TURNIER.bg)
    S.draw("pokal", 6, 2)
    font(1)
    print("Turnierplatz", 26, 3, TURNIER.yellow)
    font(0)
    rprint(ctx.money .. " G", SCREEN_W - 6, 7, TURNIER.yellow)
    local XR = SCREEN_W - 12           -- rechte Spalte, rechtsbündig
    if stage == "ergebnis" then
      local r = result
      print(r.klasse .. " · " .. wb_name(r.wb), 6, 26, TURNIER.head)
      podest(ctx, r)
      Stage.center("Platz " .. r.rank .. " von " .. (Turniere.GEGNER + 1), 176, r.rank == 1 and TURNIER.yellow or C.text, 2)
      local text = r.preis > 0 and ("Preisgeld " .. r.preis .. " G, nach Gebühr " .. (r.preis - r.gebuehr) .. " G")
        or ("Kein Preisgeld, Startgebühr " .. r.gebuehr .. " G")
      Stage.center(text, 202, r.preis > 0 and TURNIER.yellow or TURNIER.dim)
      footer(armed and "A weiter" or "", TURNIER.dark, TURNIER.edge)
      return
    end
    local where = stage == "klasse" and "Klasse wählen"
      or stage == "wb" and (K.turniere.klassen[sel_k].name .. " · Wettbewerb wählen")
      or (K.turniere.klassen[sel_k].name .. " · " .. wb_name(sel_w))
    print(where, 6, 26, TURNIER.head)
    tbox(3, 38, SCREEN_W - 4, 190, TURNIER.list)
    local list = lists()
    local rh = stage == "pferd" and 20 or 13                       -- Zeilenhöhe (Pferde mit Bild)
    local rows = (186 - 56) // rh + 1
    if stage == "klasse" then rprint("Gebühr", XR - 70, 42, TURNIER.dim) rprint("offen", XR, 42, TURNIER.dim)
    elseif stage == "wb" then rprint("Stand", XR, 42, TURNIER.dim)
    else rprint("Aussicht", XR, 42, TURNIER.dim) end
    local first = max(1, min(sel - rows // 2, #list - rows + 1))
    local y = 56
    for i = first, min(#list, first + rows - 1) do
      local e, on = list[i], i == sel
      local name_col = on and TURNIER.yellow or C.text
      if stage == "klasse" then
        if on then rectfill(6, y - 2, SCREEN_W - 7, y + 9, TURNIER.sel) end
        local k, n = e.def, offen(e.index)
        local ok = ctx.money >= k.gebuehr
        print(k.name, 12, y, ok and name_col or TURNIER.dim)
        rprint(k.gebuehr .. " G", XR - 70, y, ok and TURNIER.yellow or TURNIER.dim)
        rprint(n .. "/" .. #K.turniere.wettbewerbe, XR, y, n > 0 and C.text or TURNIER.dim)
      elseif stage == "wb" then
        if on then rectfill(6, y - 2, SCREEN_W - 7, y + 9, TURNIER.sel) end
        local weg = Turniere.state(ctx, day).weg[sel_k .. ":" .. e.id]
        print(wb_name(e.id), 12, y, weg and TURNIER.dim or name_col)
        rprint(weg and "gelaufen" or "offen", XR, y, weg and TURNIER.dim or C.text)
      else
        if on then rectfill(6, y - 3, SCREEN_W - 7, y + 15, TURNIER.sel) end
        G.draw(e.farbe, K.rasse(e.rasse).koerper, "side", 28, y + 15, false, e.schmuck)
        print(e.name, 50, y - 1, name_col)
        print(K.rasse(e.rasse).name, 50, y + 8, TURNIER.dim)
        local n = aussicht(e)
        for k = 1, 3 do S.draw(k <= n and "ico_hufeisen_gold" or "ico_hufeisen_leer", XR - 38 + (k - 1) * 13, y + 2) end
      end
      y = y + rh
    end
    if first > 1 then print("^", SCREEN_W // 2, 46, TURNIER.dim) end
    if first + rows - 1 < #list then print("v", SCREEN_W // 2, 181, TURNIER.dim) end
    if #list == 0 then print("Keine erwachsenen Pferde.", 12, 56, TURNIER.dim) end
    detail()
    footer((stage == "pferd" and "A antreten" or "A wählen") .. "   B zurück", TURNIER.dark, TURNIER.edge)
  end
  return s
end

-- Turnier-Zufall für die Gegner eines Minispiels (fest je Tag, Klasse und Wettbewerb).
local function turnier_rng(ctx, klasse, n)
  return require("lib.rng").new((ctx.seed or 1) * 7 + (ctx.clock and ctx.clock.day or 0) * 131 + (klasse or 0) * 17 + n)
end

-- Zieleinlauf fürs Podest: eigenes Pferd ({own = true}) und Gegner ({look}) nach better(a, b) sortiert.
local function einlauf(own, gegner, looks, better)
  own.own = true
  local lauf = {own}
  for _, g in ipairs(gegner) do g.look = looks and looks[g.nr] lauf[#lauf + 1] = g end
  table.sort(lauf, better)
  return lauf
end

-- Endtafel der Minispiele: A zählt erst nach RESULT_WAIT Frames und nachdem A einmal losgelassen war
-- (Rückmeldung 1.3.5: gehämmertes oder gehaltenes A schaltete sonst sofort weiter).
local function end_gate()
  local g = {wait = RESULT_WAIT, armed = false}
  function g.ready()
    if g.wait > 0 then g.wait = g.wait - 1 end
    if not g.armed then g.armed = g.wait == 0 and not btn(BTN_A) return false end
    return btnp(BTN_A)
  end
  return g
end

-- ---- Minispiel Vorführung (Schönheitswettbewerb): Kommandos im Ring treffen; am Ende A, dann done(punkte) ----

local VF_KEYS = {UP = BTN_UP, DOWN = BTN_DOWN, LEFT = BTN_LEFT, RIGHT = BTN_RIGHT, A = BTN_A}
local VF_POSE = {UP = "up", DOWN = "down", LEFT = "side_walk", RIGHT = "side_walk", A = "graze"}
local VF_FIGUR = {UP = "Steigen", DOWN = "Verneigen", LEFT = "Schritt links", RIGHT = "Schritt rechts", A = "Kompliment"}

-- Kommando als Symbol (24 × 24) mit Mitte cx, cy
local function vf_symbol(key, cx, cy, c)
  if key == "A" then
    circfill(cx, cy, 11, TURNIER.dark)
    circfill(cx, cy, 9, c or TURNIER.yellow)
    print("A", cx - textw("A", 2) // 2 + 1, cy - 6, TURNIER.dark, 2)
    return
  end
  local name = (key == "UP" or key == "DOWN") and "pfeil_hoch" or "pfeil_rechts"
  local r = S.rects[name]
  sspr(r[5] or S.img, r[1], r[2], r[3], r[4], cx - 12, cy - 12, 24, 24, key == "LEFT", key == "DOWN")
end

function Screens.vorfuehrung(ctx, d, done, klasse, looks)
  local Vf = require("game.vorfuehrung")
  local Turniere = require("game.turniere")
  local st = Vf.new(d, klasse, (ctx.seed or 1) + ctx.clock.day * 7 + (klasse or 1))
  local gate, finished = end_gate(), false
  local gegner = klasse and Vf.gegner(klasse, turnier_rng(ctx, klasse, 1))
  local platz, note
  local rasse = K.rasse(d.rasse)
  local LANE_Y = 44                  -- Mitte der Kommandospur
  local s = {full = true}
  function s.update(nav)
    if st.done then
      if gegner and not platz then
        note = Vf.note(Vf.grund(d), Vf.quote(st))
        platz = Vf.platz(note, gegner)
      end
      if gate.ready() and not finished then
        finished = true
        nav.pop()
        if gegner then
          local lauf = einlauf({note = note}, gegner, looks, function(a, b) return a.note > b.note end)
          done(Vf.leistung(st), platz, lauf)
        else
          done(Vf.leistung(st))
        end
      end
      return
    end
    local press
    for k, b in pairs(VF_KEYS) do if btnp(b) then press = k end end
    Vf.update(st, press)
    if st.last and st.last_t == 40 then                -- gerade gewertet
      if st.last.score > 0 then SFX.ok() else SFX.snort() end
    end
  end
  function s.draw()
    cls(TURNIER.bg)
    font(1)
    print("Vorführung", 6, 3, TURNIER.yellow)
    font(0)
    local tr = 0
    for _, c in ipairs(st.cmds) do if c.score and c.score > 0 then tr = tr + 1 end end
    rprint(d.name, SCREEN_W - 6, 7, C.text)
    -- Kommandospur
    tbox(3, 23, SCREEN_W - 4, 66, TURNIER.about)
    rect(4, 24, SCREEN_W - 5, 65, TURNIER.edge)
    local w = flr(st.win)
    rectfill(Vf.RING_X - w, 27, Vf.RING_X + w, 62, TURNIER.sel)          -- Trefferfenster (Bindung)
    circ(Vf.RING_X, LANE_Y, 14, TURNIER.yellow)
    clip(5, 25, SCREEN_W - 10, 40)
    for _, c in ipairs(st.cmds) do
      local x = flr(Vf.screen_x(st, c))
      if not c.score and x > -20 and x < SCREEN_W + 20 then vf_symbol(c.key, x, LANE_Y) end
    end
    clip()
    -- Arena: Sand, weißer Zaun, Pferd in der Mitte (doppelt groß), Pose nach dem letzten Kommando
    rectfill(3, 70, SCREEN_W - 4, 196, rgb(0xd5, 0xbb, 0x82))
    rectfill(3, 70, SCREEN_W - 4, 92, TURNIER.grass)
    for x = 10, SCREEN_W - 10, 24 do rectfill(x, 84, x + 2, 100, C.text) end
    line(3, 88, SCREEN_W - 4, 88, C.text) line(3, 95, SCREEN_W - 4, 95, C.text)
    local L = st.last_t > 0 and st.last
    local pose, flip = "side", false
    if L and L.score and L.score > 0 then pose, flip = VF_POSE[L.key], L.key == "LEFT"
    elseif (st.frame // 30) % 2 == 1 then pose = "side_walk" end
    local hx = 160 + (L and L.score == 0 and ((st.frame // 2) % 2 * 4 - 2) or 0)
    G.draw_scaled(d.farbe, rasse.koerper, pose, hx, 180, 2, flip, d.schmuck)
    if L then
      local t = L.score == Vf.PERFECT and "Perfekt!" or (L.score or 0) > 0 and "Gut" or "Daneben"
      local c = L.score == Vf.PERFECT and TURNIER.yellow or (L.score or 0) > 0 and C.text or C.red
      Stage.center(t, 106, c, 2)
      if L.score and L.score > 0 then Stage.center(VF_FIGUR[L.key], 124, TURNIER.dark) end
    end
    -- Fortschritt: ein Feld je Kommando
    for i, c in ipairs(st.cmds) do
      local x = 160 - Vf.N * 7 + (i - 1) * 14
      local col = not c.score and TURNIER.list or c.score == Vf.PERFECT and TURNIER.yellow or c.score > 0 and TURNIER.head or C.red
      rectfill(x, 202, x + 10, 210, col)
    end
    if st.done then
      tbox(60, 96, 259, 160, TURNIER.dark)
      rect(61, 97, 258, 159, TURNIER.edge)
      Stage.center(tr .. " von " .. Vf.N .. " Figuren", 106, TURNIER.yellow, 2)
      local q = Vf.quote(st)
      Stage.center(q >= 0.8 and "Die Richter sind begeistert." or q >= 0.5 and "Eine ordentliche Vorführung." or "Die Richter schauen streng.", 128, C.text)
      footer(gate.armed and "A weiter" or "", TURNIER.dark, TURNIER.edge)
    else
      footer("Pfeile und A: Figur im Ring", TURNIER.dark, TURNIER.edge)
    end
  end
  return s
end

-- ---- Minispiel Springreiten (E2): A springt; am Ende A, dann done(leistung 0–1) ----

-- klasse: Turnier (Gegner nach game/springen.lua, done(leistung, platz, einlauf)); looks: Aussehen der Gegner.
function Screens.springreiten(ctx, d, done, klasse, looks)
  local Sp = require("game.springen")
  local st = Sp.new(d, klasse)
  local gegner = klasse and Sp.gegner(klasse, turnier_rng(ctx, klasse, 2))
  local platz
  local s = {full = true}
  local finished, gate = false, end_gate()
  local rasse = K.rasse(d.rasse)
  function s.update(nav)
    Sp.update(st, btnp(BTN_A) and not st.done)
    if st.done then
      if gegner and not platz then platz = Sp.platz(st.faults, Sp.leistung(st), gegner) end
      if gate.ready() then
        if finished then return end
        finished = true
        nav.pop()
        if gegner then
          local lauf = einlauf({fehler = st.faults, stil = Sp.leistung(st)}, gegner, looks,
            function(a, b) if a.fehler ~= b.fehler then return a.fehler < b.fehler end return a.stil > b.stil end)
          done(Sp.leistung(st), platz, lauf)
        else
          done(Sp.leistung(st))
        end
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
    G.draw(d.farbe, rasse.koerper, pose, Sp.HORSE_X, ground - st.air, false, d.schmuck)
    -- Fortschritt
    rectfill(10, 24, 309, 28, C.panel)
    rectfill(10, 24, 10 + flr(299 * min(1, st.x / Sp.END_X)), 28, C.gold)
    if st.done then
      Stage.panel(60, 80, 259, 130)                       -- der Platz kommt erst mit dem Podest
      Stage.center(st.faults .. " Fehler, Stil " .. flr(Sp.leistung(st) * 100) .. " %", 90, C.gold)
      if gate.armed then Stage.center("A: weiter", 112, C.dim) end
    else
      print("A: springen", 6, SCREEN_H - 10, C.dim)
    end
  end
  return s
end

-- ---- Minispiel Pferderennen (E3): A halten = Spurt; am Ende A, dann done(leistung, platz) (ohne klasse: punkte) ----

-- looks (optional): Aussehen der Gegner {rasse, farbe} (game/turniere.lua T.gegner_pferde), sonst braune Pferde
-- derselben Rasse.
function Screens.rennen(ctx, d, gegner, done, klasse, looks)
  local Rn = require("game.rennen")
  local st = Rn.new(d, gegner, require("lib.rng").new(5 + (klasse or 0) + (ctx.clock and ctx.clock.day or 0)), klasse, true)
  local s = {full = true}
  local finished, gate = false, end_gate()
  local rasse = K.rasse(d.rasse)
  local a_frei = false             -- A vom Menü davor noch gedrückt: erst nach dem Loslassen zählt es (sonst Unruhe)
  function s.update(nav)
    local vorher, frueh = st.ampel, st.fehlstart
    if not btn(BTN_A) then a_frei = true end
    Rn.update(st, a_frei and btn(BTN_A) and not st.done)
    if st.fehlstart and not frueh then SFX.snort() end
    if vorher and not st.ampel then SFX.start() end
    if st.ampel and (st.pre == Rn.ROT[1] or st.pre == Rn.ROT[2] or st.pre == Rn.ROT[3]) then SFX.select() end
    if st.done and gate.ready() and not finished then
      finished = true
      nav.pop()
      -- Zieleinlauf für das Podest: eigenes Pferd (own) oder Aussehen des Gegners, schnellste zuerst
      local lauf = {{time = st.time, own = true}}
      for _, r in ipairs(st.rivals) do lauf[#lauf + 1] = {time = r.time, look = looks and looks[r.nr]} end
      table.sort(lauf, function(a, b) return a.time < b.time end)
      done(klasse and Rn.leistung(st) or Rn.punkte(st), Rn.platz(st), lauf)
    end
  end
  function s.draw()
    cls(rgb(0x9f, 0xcd, 0x66))
    rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
    print("Pferderennen: " .. d.name, 6, 3, C.gold)
    local lanes = #st.rivals + 1
    local lane_h = 24
    local y0 = 30
    local cam = min(st.x, st.length) - 90
    for i = 1, lanes do
      local y = y0 + (i - 1) * lane_h
      rectfill(0, y + 20, SCREEN_W - 1, y + 21, rgb(0xb3, 0x8c, 0x57))
    end
    -- Ziellinie
    local fx = flr(st.length - cam)
    if fx < SCREEN_W then rectfill(fx, y0, fx + 3, y0 + lanes * lane_h, C.text) end
    -- Startboxen (Weltposition 0): Rückwand, Dach, vorne die Klappe (zu bis Grün, dann nach oben geklappt)
    local gx = flr(-cam)
    local box_col, flap_col = rgb(0xe8, 0xe4, 0xd8), rgb(0xc8, 0x3a, 0x3a)
    if gx > -40 then
      for i = 1, lanes do
        local y = y0 + (i - 1) * lane_h
        rectfill(gx - 22, y + 1, gx - 20, y + 20, box_col)
        rectfill(gx - 22, y + 1, gx + 22, y + 2, box_col)
      end
    end
    -- eigenes Pferd auf der letzten Bahn, Gegner darüber
    local function horse_at(x, i, own, nr, delay)
      local y = y0 + (i - 1) * lane_h + 20
      -- unruhig (A vor dem letzten Rot) oder verrannt (Fehlstart): galoppiert auf der Stelle und zappelt
      local zappelt = own and ((st.unruhe or 0) > 0 or (st.fehlstart and (st.ampel or (st.stall or 0) > 0)))
      local t = st.ampel and st.pre or st.frame
      local standing = not zappelt and (st.ampel or (own and st.started == false) or (delay and st.frame <= delay))
      local pose = standing and "side" or (((t // 5) % 2 == 0) and "gallop1" or "gallop2")
      if zappelt then x = x + (t // 3) % 2 * 2 - 1 end
      local look = not own and looks and looks[nr or i]
      local col = own and d.farbe or (look and look.farbe or "brauner")
      local body = look and K.rasse(look.rasse).koerper or rasse.koerper
      G.draw(col, body, pose, flr(x - cam), y, false)
    end
    for i, r in ipairs(st.rivals) do horse_at(r.x, i, false, r.nr, r.delay) end
    horse_at(st.x, lanes, true)
    if gx > -40 then
      for i = 1, lanes do
        local y = y0 + (i - 1) * lane_h
        if st.ampel then
          rectfill(gx + 20, y + 3, gx + 22, y + 20, flap_col)
          for yy = y + 6, y + 18, 6 do rectfill(gx + 20, yy, gx + 22, yy + 2, box_col) end
        else
          rectfill(gx + 20, y - 8, gx + 22, y + 2, flap_col)           -- aufgeklappt
        end
      end
    end
    -- Ampel mit Hinweis, bis kurz nach dem Start
    if st.ampel or st.frame < 60 then
      local bx0, by0, bx1, by1 = 128, 34, SCREEN_W - 8, 100
      Stage.panel(bx0, by0, bx1, by1)
      local cx = (bx0 + bx1) // 2
      for k = 1, 3 do
        local lx = cx - 26 + (k - 1) * 26
        local c = rgb(0x40, 0x30, 0x2c)
        if not st.ampel then c = rgb(0x5c, 0xd0, 0x5a)
        elseif st.pre >= Rn.ROT[k] then c = C.red end
        circfill(lx, by0 + 16, 9, C.panel_light)
        circfill(lx, by0 + 16, 7, c)
      end
      local l1, l2, c1 = "A halten = Sprint", "Erst bei Grün loslaufen!", C.text
      if st.fehlstart then l1, l2, c1 = "Zu früh!", "Das Pferd verrennt sich.", C.red
      elseif not st.ampel then l1, l2, c1 = "Los!", "", C.gold end
      print(l1, cx - textw(l1) // 2, by0 + 34, c1)
      print(l2, cx - textw(l2) // 2, by0 + 46, st.fehlstart and C.red or C.dim)
    end
    -- Ausdauer
    rectfill(10, 216, 129, 224, C.panel)
    rectfill(11, 217, 11 + flr(117 * st.stamina / st.cap), 223, st.stamina > 0 and C.gold or C.red)
    print("Ausdauer", 136, 216, C.text)
    if st.done then
      Stage.panel(70, 90, 249, 140)
      Stage.center("Im Ziel!", 100, C.gold, 2)                -- der Platz kommt erst mit dem Podest
      local l = klasse and ("Leistung " .. flr(Rn.leistung(st) * 100) .. " %") or ("Punkte " .. flr(Rn.punkte(st)))
      Stage.center(l .. (gate.armed and "   A: weiter" or ""), 124, C.dim)
    else
      print("A: Spurt", SCREEN_W - 70, 216, C.dim)
    end
  end
  return s
end

-- ---- Rückfrage (Rückmeldung 1.3.1: Verkaufen bestätigen) ----
-- lines: Text; yes: Beschriftung für Ja; on_yes(nav) nach dem Schließen. „Nein“ ist vorgewählt, B = nein.
function Screens.confirm(title, text, yes, on_yes)
  local lines = {}
  for _, t in ipairs(text) do
    for _, l in ipairs(require("lib.util").wrap(t, SCREEN_W - 20)) do lines[#lines + 1] = l end
  end
  local sel = 1
  local s = {full = true}
  local wait = btn(BTN_A)
  function s.update(nav)
    if wait then if not btn(BTN_A) then wait = false end return end
    if btnp(BTN_UP) or btnp(BTN_DOWN) then sel = 3 - sel SFX.select() end
    if btnp(BTN_B) then SFX.back() nav.pop() return end
    if btnp(BTN_A) then
      nav.pop()
      if sel == 2 then on_yes(nav) else SFX.back() end
    end
  end
  function s.draw()
    cls(C.panel)
    header(title)
    for i, l in ipairs(lines) do print(l, 10, 30 + (i - 1) * 12, C.text) end
    local y0 = 40 + #lines * 12
    for i, label in ipairs({"Nein, behalten", yes}) do
      local y = y0 + (i - 1) * 18
      if i == sel then rectfill(4, y - 3, SCREEN_W - 5, y + 11, C.panel_light) end
      print(label, 14, y, i == 2 and C.red or (i == sel and C.gold or C.text))
    end
    footer("A: wählen   B: zurück")
  end
  return s
end

-- Was beim Verkauf in den Vorrat zurückgeht (Text), nil wenn nichts.
local function worn_text(d)
  local names = {}
  if d.sattel then names[#names + 1] = Economy.find(d.sattel).name end
  if d.taschen then names[#names + 1] = Economy.find(d.taschen).name end
  if d.lampe then names[#names + 1] = "Sattellampe" end
  for _, j in ipairs(Economy.JEWELRY) do if d.schmuck and d.schmuck[j] then names[#names + 1] = Economy.find(j).name end end
  if #names == 0 then return nil end
  return "Zurück in den Vorrat: " .. table.concat(names, ", ") .. "."
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
      local offer, why = Buyers.offer(typ, d, ctx.clock and ctx.clock.day)
      if not offer then
        SFX.snort()
        msg = H.gtext(d, Buyers.pronoun(typ, true) .. " nimmt {sie|ihn|es} nicht: ") .. tostring(why)
      else
        SFX.ok()
        local lines = {name .. " für " .. offer .. " G an " .. info.name .. " verkaufen?", "Das lässt sich nicht rückgängig machen."}
        lines[#lines + 1] = worn_text(d)
        nav.push(Screens.confirm("Wirklich verkaufen?", lines, "Ja, verkaufen", function(nv)
          local price, extra = Buyers.sell(ctx, typ, d)
          if price then
            SFX.tame()
            nv.pop()
            if nav_done then nav_done(name .. " verkauft für " .. price .. " G.") end
          else
            SFX.snort()
            msg = H.gtext(d, Buyers.pronoun(typ, true) .. " nimmt {sie|ihn|es} nicht: ") .. tostring(extra)
          end
        end))
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
      local price, why = Buyers.offer(typ, d, ctx.clock and ctx.clock.day)
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
      local price, why = Buyers.offer(typ, d, ctx.clock and ctx.clock.day)
      if price then
        print(Buyers.pronoun(typ, true) .. " zahlt " .. price .. " G (Wert " .. Value.wert(d) .. " G).", 8, 190, C.gold)
        local f = Buyers.folge(typ)
        if f ~= 0 then print("Die übrigen Pferde: Bindung " .. (f > 0 and "+" or "") .. f, 8, 201, f > 0 and C.text or C.red) end
      else
        local no = require("lib.util").wrap(H.gtext(d, Buyers.pronoun(typ, true) .. " nimmt {sie|ihn|es} nicht: ") .. tostring(why), SCREEN_W - 16)
        for i, line in ipairs(no) do if i <= 2 then print(line, 8, 190 + (i - 1) * 11, C.red) end end
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
      local d = l[sel]
      local name = d.name
      if not Orders.matches(order, d) then
        SFX.snort()
      else
        SFX.ok()
        local lines = {name .. " für " .. Orders.reward(d) .. " G an " .. order.kunde .. " liefern?", "Das lässt sich nicht rückgängig machen."}
        lines[#lines + 1] = worn_text(d)
        nav.push(Screens.confirm("Wirklich liefern?", lines, "Ja, liefern", function(nv)
          local sum = Orders.deliver(ctx, order, d)
          if sum then
            SFX.tame()
            nv.pop()
            if done then done(name .. " geliefert: " .. sum .. " G von " .. order.kunde .. ".") end
          else
            SFX.snort()
          end
        end))
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
      if Jobs.eligible(d, job, day(), ctx) then ok[#ok + 1] = d else rest[#rest + 1] = d end
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
      if Jobs.eligible(d, job, day(), ctx) then
        -- Minispiel (Rückmeldung 1.2.1), danach Lohn nach Ergebnis
        SFX.ok()
        nav.pop()
        nav.push(require("game.jobspiel").screen(ctx, job, d, function(anteil)
          local sum = Jobs.run(ctx, job, d, day(), anteil)
          SFX.tame()
          if done then done(d.name .. " hat gearbeitet: " .. (sum or 0) .. " G.") end
        end))
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
      local ok, why = Jobs.eligible(d, job, day(), ctx)
      if i == sel then rectfill(4, y - 2, SCREEN_W - 5, y + 21, C.panel_light) end
      G.draw(d.farbe, K.rasse(d.rasse).koerper, "side", 26, y + 19, false)
      print(d.name, 50, y, ok and (i == sel and C.gold or C.text) or C.dim)
      print(ok and ("Energie " .. flr(d.energie)) or why, 50, y + 10, ok and C.dim or C.red)
      local t = ok and ("bis " .. Jobs.lohn(d, job) .. " G") or ""
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
      if Jobs.done(ctx, list[sel], ctx.clock and ctx.clock.day or 1) then
        SFX.snort() msg, msg_t = "Diesen Job gibt es morgen wieder.", 150
      else
        SFX.ok()
        nav.push(job_horses(ctx, list[sel], function(text) msg, msg_t = text, 240 end))
      end
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
      local done = Jobs.done(ctx, job, ctx.clock and ctx.clock.day or 1)
      print(job.name, 10, y, done and C.dim or (i == sel and C.gold or C.text))
      print(done and "heute erledigt" or ("ab " .. Jobs.STAT_NAMES[job.braucht] .. " " .. job.braucht_wert), 160, y, C.dim)
      print("Lohn " .. job.lohn_basis .. " + " .. Jobs.STAT_NAMES[job.lohn_stat] .. "/" .. job.lohn_teiler, 10, y + 12, C.gold)
      local train = {}
      for key, amount in pairs(job.training) do train[#train + 1] = Jobs.STAT_NAMES[key] .. " +" .. amount end
      table.sort(train)
      print("Training: " .. table.concat(train, ", "), 10, y + 24, C.dim)
      print("Minispiel, Energie -" .. job.energie, 10, y + 35, C.dim)
    end
    print("Jeder Job einmal am Tag, ein Job pro Pferd.", 10, 176, C.dim)
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
    if btnp(BTN_B) or btnp(BTN_A) or btnp(BTN_UP) then SFX.back() nav.pop() end
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
      print(label or "?", x + 3, y + 2, C.dim)
    end
  end
  -- Zeichnet Knoten der Ebene `level` (0 = Pferd) in den Zeilenbereich [y0, y0 + h)
  local function draw_level(node, level, y0, h)
    local x = 4 + level * COLW
    local bh = min(h - 2, 22)
    box(x, y0 + (h - bh) // 2, bh, node, level == 0 and "" or "?")
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
    draw_level(root, 0, 16, SCREEN_H - 20)
  end
  return s
end

-- ---- Baumodus (E8, geändert nach Rückmeldung 0.5.2): Cursor im Kachelraster, A setzt, START öffnet die
-- Bauteil-Auswahl als Kachelmenü (erst Art, dann Bauteil), B schließt. Dezentes Raster aus 2 × 2 Pixel großen
-- Punkten an den Kachelecken des Grundstücks. ----

-- Bild eines Bauteils für das Kachelmenü
local BUILD_ICON = {
  weg = "land_path1", boden = "land_sand1", beet = "ground_beet",
  zaun = "fence_post",
}
local CAT_ICON = {
  deko = "blumenkuebel", wege = "land_path1", anbau = "ground_beet", pflanzen = "pflanze_karotte_3",
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
  if cat == "pflanzen" then return Farm.crop(id).name .. " x" .. (ctx.inv["samen_" .. id] or 0), nil end
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
  local chosen = false         -- erst nach der ersten Wahl gibt es Cursor und Bauteil (Rückmeldung 1.3.4)
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
      local empty = #c.items == 0 and c.id ~= "abriss" and c.id ~= "land"
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
    picker = {stage = "item", cat = ci, m = Menu.new(items, c.name, {names = false})}
    if ci == cat then picker.m.sel = item end
  end

  local function act()
    local id, c = cur_item()
    if c.id == "abriss" then
      local sum, why = Farm.remove(ctx, cx, cy)
      if sum then SFX.brush() say(changed() or (sum > 0 and ("Abgerissen: +" .. sum .. " G.") or "Abgerissen.")) else SFX.snort() say(why .. ".") end
    elseif c.id == "land" then
      local ok, why = Farm.buy_land(ctx, cx, cy)
      if ok then
        SFX.ok() say("Land gekauft: " .. why .. " G.")
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

  open_cats(1)                  -- gleich „Was bauen?“ (Rückmeldung 1.3.4)

  function s.update(nav)
    cur_item()
    if picker then
      local r = picker.m:update()
      if btnp(BTN_START) and not btn(BTN_SELECT) then
        if chosen then picker = nil end
      elseif r == "close" then
        if picker.stage == "item" then open_cats(picker.cat)
        elseif chosen then picker = nil
        else nav.pop() return end                -- noch nichts gewählt: B verlässt den Baumodus
      elseif r and picker.stage == "cat" then
        if cats[r].id == "abriss" then cat, item, picker, chosen = r, 1, nil, true  say("A reißt ab, was unter dem Cursor steht.")
        elseif cats[r].id == "land" then cat, item, picker, chosen = r, 1, nil, true  say("Feld am Hof wählen, A kauft.")
        else open_items(r) end
      elseif r and picker.stage == "item" then
        if not chosen then say("START: anderes Bauteil") end
        cat, item, picker, chosen = picker.cat, r, nil, true
      end
    else
      if cats[cat].id == "land" then
        -- Land: Cursor springt feldweise, auch ein Feld über das Grundstück hinaus
        local L = Farm.LAND
        local x0, y0 = max(0, plot.x - L), max(0, plot.y - L)
        local x1 = min((ctx.map.w // L) * L - 1, plot.x + plot.w + L - 1)
        local y1 = min((ctx.map.h // L) * L - 1, plot.y + plot.h + L - 1)
        if btnp(BTN_LEFT) then cx = max(x0, cx - L) end
        if btnp(BTN_RIGHT) then cx = min(x1, cx + L) end
        if btnp(BTN_UP) then cy = max(y0, cy - L) end
        if btnp(BTN_DOWN) then cy = min(y1, cy + L) end
      else
        cx, cy = mid(plot.x, cx, plot.x + plot.w - 1), mid(plot.y, cy, plot.y + plot.h - 1)
        if btnp(BTN_LEFT) then cx = max(plot.x, cx - 1) end
        if btnp(BTN_RIGHT) then cx = min(plot.x + plot.w - 1, cx + 1) end
        if btnp(BTN_UP) then cy = max(plot.y, cy - 1) end
        if btnp(BTN_DOWN) then cy = min(plot.y + plot.h - 1, cy + 1) end
      end
      if btnp(BTN_START) and not btn(BTN_SELECT) then open_cats() SFX.select()
      elseif btnp(BTN_B) then SFX.back() nav.pop() return
      elseif btnp(BTN_A) then act() end
    end
    if msg_t > 0 then msg_t = msg_t - 1 end
    if cats[cat].id == "land" then
      local L = Farm.LAND
      ctx.camera:follow((cx // L * L + L // 2) * 16, (cy // L * L + L // 2) * 16)
    else
      ctx.camera:follow(cx * 16 + 8, cy * 16 + 8)
    end
  end

  -- Passt das Bauteil an die Cursorstelle? Gibt ok, Breite, Höhe (Kacheln) zurück.
  local function check(id, c)
    if c.id == "abriss" then return select(3, Farm.demolish_target(ctx, cx, cy)) or Farm.plant_at(farm, cx, cy) ~= nil, 1, 1 end
    if c.id == "land" then local price = Farm.land_angebot(ctx, cx, cy) return price ~= nil and ctx.money >= price, 1, 1 end
    if c.id == "pflanzen" then
      if not id then return false, 1, 1 end
      local crop = Farm.crop(id)
      return Farm.can_plant(ctx, id, cx, cy), crop.w, crop.h
    end
    local it = Farm.ITEMS[id]
    return Farm.can_place(ctx.map, farm, id, cx, cy, ctx.player) and ctx.money >= K.bauteil(id).preis
      and not Farm.tool_missing(ctx, id), it.w or 1, it.h or 1
  end

  function s.draw()
    local cam = ctx.camera
    local id, c = cur_item()
    local ok, w, h = check(id, c)
    camera(cam.x, cam.y)
    -- Raster: dezente 2 × 2-Punkte an jeder zweiten Kachelecke des Grundstücks (nur Sichtbares)
    local x0 = max(plot.x, cam.x // 32 * 2)
    local x1 = min(plot.x + plot.w, (cam.x + SCREEN_W) // 16 + 1)
    local y0 = max(plot.y, cam.y // 32 * 2)
    local y1 = min(plot.y + plot.h, (cam.y + SCREEN_H) // 16 + 1)
    local dot = rgb(0xfb, 0xf8, 0xef)
    for ty = y0, y1, 2 do
      for tx = x0, x1, 2 do
        if Farm.owns(farm, tx, ty) or Farm.owns(farm, tx - 1, ty) or Farm.owns(farm, tx, ty - 1)
          or Farm.owns(farm, tx - 1, ty - 1) then
          rectfill(tx * 16 - 1, ty * 16 - 1, tx * 16, ty * 16, dot)
        end
      end
    end
    Farm.outline(farm, 0, 0, 16, C.gold)
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
    if not chosen then
      -- noch kein Bauteil gewählt: kein Cursor
    elseif c.id == "land" then
      -- gewähltes Feld grün (kaufbar) oder rot getönt
      local L = Farm.LAND
      local fx, fy = (cx // L) * L * 16 - cam.x, (cy // L) * L * 16 - cam.y
      local own = Farm.owns(farm, cx, cy)
      camera()
      if not own then
        clip(fx, fy, L * 16, L * 16)
        shade(ok and rgb(0x5f, 0xc0, 0x50) or C.red, 0.3)
        clip()
      end
      rect(fx, fy, fx + L * 16 - 1, fy + L * 16 - 1, (ok or own) and C.text or C.red)
      camera(cam.x, cam.y)
    else
      for dy = 0, h - 1 do
        for dx = 0, w - 1 do ctx.S.draw(ok and "cursor_ok" or "cursor_bad", (cx + dx) * 16, (cy + dy) * 16) end
      end
    end
    camera()
    if picker then                -- Auswahl offen: ohne Leiste unten (Rückmeldung 1.3.4)
      picker.m:draw()
      return
    end
    -- Leiste unten: gewähltes Bauteil, Meldung, Tasten
    local y = SCREEN_H - 36
    Stage.panel(0, y, SCREEN_W - 1, SCREEN_H - 1)
    local line
    if c.id == "abriss" then
      local it, refund, ok, why = Farm.demolish_target(ctx, cx, cy)
      local pf = Farm.plant_at(farm, cx, cy)
      line = pf and ("Abreißen: " .. Farm.crop(pf.id).name .. " (Samen weg)")
        or it and ("Abreißen: " .. K.bauteil(it.id).name .. (ok and ("  +" .. refund .. " G") or (": " .. why)))
        or "Abreißen: hier steht nichts"
    elseif c.id == "land" then
      local price, why = Farm.land_angebot(ctx, cx, cy)
      line = "Land 10×10: " .. (price and (price .. " G") or why)
    elseif c.id == "pflanzen" then
      if id then
        local crop = Farm.crop(id)
        line = crop.name .. " x" .. (ctx.inv["samen_" .. id] or 0) .. ": reif nach " .. crop.reif .. " T, dann alle " .. crop.dann .. " T, " .. crop.ertrag .. "x"
      else
        line = "Keine Samen im Vorrat"
      end
    else
      local b = K.bauteil(id)
      local tool = Farm.tool_missing(ctx, id)
      line = b.name .. "  " .. (tool and "braucht eine Hacke (Laden)" or (b.preis .. " G"))
        .. (b.wirkung.schoenheit and ("  Schönheit +" .. b.wirkung.schoenheit) or "")
    end
    Menu.icon(c.id == "abriss" and "cursor_bad" or c.id == "land" and "ico_karte" or (id and build_icon(c.id, id))
      or "ico_bauen", 16, y + 13, 20)
    print(line, 32, y + 5, ok and C.text or C.red)
    if msg_t > 0 then
      print(msg, 32, y + 16, C.dim)          -- Meldung bekommt die ganze Zeile
    else
      local bonus, next_at, score = Farm.schoenheit_bonus(farm)
      print("Schönheit " .. flr(score) .. (next_at and ("/" .. next_at) or "") .. "  Bindung +" .. bonus, 32, y + 16, C.dim)
    end
    Stage.center("A bauen   START Auswahl   B fertig", y + 27, C.gold)
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
        if it.kat == c.id and (n > 0 or c.id == "futter") then
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
    if btnp(BTN_B) or btnp(BTN_A) then nav.pop() end
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
      if area.farm then Farm.outline(area.farm, ox, oy, PX, C.gold)
      else rect(ox + p.x * PX - 1, oy + p.y * PX - 1, ox + (p.x + p.w) * PX, oy + (p.y + p.h) * PX, C.gold) end
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
  local m = Menu.new(items, "Pause", {aside = "Tag " .. day})   -- der Tag steht hier statt oben links (Rückmeldung 1.3.4)
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
