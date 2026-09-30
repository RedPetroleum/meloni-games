-- Vollbild-Menüs (E5, E7): Pausenmenü, Pferdeliste, Pferde-Info, Inventar, Bildschirmtastatur.
-- Jeder Bildschirm ist {update = function(nav), draw = function()}. nav hat push(screen) und pop().
-- Bedienung überall: Steuerkreuz wählen, A bestätigen, B zurück.
local K = require("game.katalog")
local H = require("game.horse_model")
local G = require("game.horse_gfx")
local Stage = require("game.stage")
local Menu = require("game.menu")

local Screens = {}

local C = Stage.COLORS
local BAR = 80     -- Balkenbreite in Pixeln für 100 Punkte
local function px(v) return flr(v * BAR / 100) end

local function header(title)
  rectfill(0, 0, SCREEN_W - 1, 13, C.panel)
  print(title, 6, 3, C.gold)
end

local function footer(text)
  rectfill(0, SCREEN_H - 12, SCREEN_W - 1, SCREEN_H - 1, C.panel)
  print(text, 6, SCREEN_H - 10, C.dim)
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
function Screens.keyboard(title, text, max, on_done)
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
    if btnp(BTN_LEFT) then cx = cx - 1 end
    if btnp(BTN_RIGHT) then cx = cx + 1 end
    if btnp(BTN_UP) then cy = cy - 1 end
    if btnp(BTN_DOWN) then cy = cy + 1 end
    cy = (cy - 1) % #chars + 1
    row = chars[cy]
    cx = (cx - 1) % #row + 1
    if btnp(BTN_B) then
      if len(text) > 0 then text = text:sub(1, utf8.offset(text, -1) - 1) else nav.pop() end
    elseif btnp(BTN_A) then
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
  return s
end

-- ---- Pferde-Info ----

local function stat_bar(x, y, label, data, key)
  print(label, x, y, C.text)
  local bx = x + 66
  rectfill(bx, y, bx + BAR - 1, y + 6, C.panel)
  local g, t, p = data.gen[key], data.train[key], data.pot[key]
  rectfill(bx, y, bx + px(g) - 1, y + 6, C.gold)
  if t >= 1 then rectfill(bx + px(g), y, bx + px(g + t) - 1, y + 6, rgb(0x7f, 0xd0, 0x6f)) end
  rect(bx, y, bx + BAR - 1, y + 6, C.panel_light)
  line(bx + px(p) - 1, y - 1, bx + px(p) - 1, y + 7, C.red)
  print(string.format("%d+%d/%d", flr(g), flr(t), flr(p)), bx + BAR + 4, y, C.dim)
end

local function state_bar(x, y, label, value, max, good_high)
  print(label, x, y, C.text)
  local bx = x + 66
  rectfill(bx, y, bx + BAR - 1, y + 6, C.panel)
  rectfill(bx, y, bx + flr(BAR * value / max) - 1, y + 6, C.dim)
  rect(bx, y, bx + BAR - 1, y + 6, C.panel_light)
  print(tostring(flr(value)), bx + BAR + 4, y, C.dim)
end

function Screens.info(ctx, data)
  local s = {}
  function s.update(nav)
    if btnp(BTN_B) then nav.pop() end
    if btnp(BTN_A) then
      nav.push(Screens.keyboard("Neuer Name", data.name, 12, function(text) data.name = text end))
    end
  end
  function s.draw()
    cls(C.panel)
    header(data.name)
    local sexw = data.sex == "m" and (data.alter < 1 and "Hengstfohlen" or "Hengst") or (data.alter < 1 and "Stutfohlen" or "Stute")
    local rasse = K.rasse(data.rasse)
    print(sexw .. ", " .. rasse.name, 6, 18, C.text)
    local f1, f2 = K.farbe(data.farbe).name, K.farbe(data.farbe2).name
    print("Farbe: " .. f1 .. (data.farbe2 ~= data.farbe and (" / " .. f2) or ""), 6, 28, C.dim)
    print("Charakter: " .. K.charakter[data.zug].name .. ", " .. place_of(data), 6, 38, C.dim)
    -- Bild
    Stage.panel(6, 52, 71, 100)
    rectfill(8, 54, 69, 98, rgb(0x7f, 0xb0, 0x4f))
    G.draw(data.farbe, rasse.koerper, "side", 39, 92, false)
    if data.alter < 1 then
      print("Fohlen", 8, 104, C.text)
      rectfill(8, 114, 69, 119, C.panel_light)
      rectfill(8, 114, 8 + flr(61 * data.alter), 119, C.gold)
    end
    -- Werte
    local y = 54
    print("Gen+Training/Potenzial", 82, 48, C.gold)
    y = 60
    for _, e in ipairs({{"tempo", "Tempo"}, {"staerke", "Stärke"}, {"spuer", "Spür"}, {"ausdauer", "Ausdauer"}}) do
      stat_bar(82, y, e[2], data, e[1])
      y = y + 12
    end
    y = 116
    print("Zustand", 82, 108, C.gold)
    state_bar(82, y, "Bindung", data.bindung, 100); y = y + 12
    state_bar(82, y, "Hunger", data.hunger, 100); y = y + 12
    state_bar(82, y, "Sauber.", data.sauberkeit, 100); y = y + 12
    state_bar(82, y, "Gewicht", data.gewicht, 100)
    line(82 + 66 + BAR // 2, y - 1, 82 + 66 + BAR // 2, y + 7, C.text)
    y = y + 12
    state_bar(82, y, "Energie", data.energie, H.stat(data, "ausdauer"))
    if data.sattel then print("Sattel: " .. K.artikel(data.sattel).name, 6, 130, C.dim) end
    footer("A: umbenennen   B: zurück")
  end
  return s
end

-- ---- Pferdeliste ----

function Screens.horses(ctx)
  local sel = 1
  local s = {}
  function s.update(nav)
    local n = #ctx.herd
    if btnp(BTN_UP) and n > 0 then sel = (sel - 2) % n + 1 end
    if btnp(BTN_DOWN) and n > 0 then sel = sel % n + 1 end
    if btnp(BTN_B) then nav.pop() end
    if btnp(BTN_A) and n > 0 then nav.push(Screens.info(ctx, ctx.herd[sel])) end
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
    print("Geld: " .. ctx.money .. " G", 20, 24, C.gold)
    print("Futter", 20, 44, C.gold)
    local y = 56
    for _, f in ipairs(K.futter.kaufen) do
      if f.id ~= "buerste" then
        local n = ctx.inv[f.id] or 0
        print(f.name, 28, y, n > 0 and C.text or C.dim)
        print("x" .. n, 150, y, n > 0 and C.text or C.dim)
        print((f.text:gsub("−", "-")):sub(1, 17), 185, y, C.dim)
        y = y + 12
      end
    end
    y = y + 8
    print("Sonstiges", 20, y, C.gold)
    y = y + 12
    print("Bürste", 28, y, (ctx.inv.buerste or 0) > 0 and C.text or C.dim)
    print("x" .. (ctx.inv.buerste or 0), 150, y, C.dim)
    footer("B: zurück")
  end
  return s
end

-- ---- Pausenmenü (E5) ----

function Screens.pause(ctx, nav)
  local items = {
    {label = "Weiter", id = "resume"},
    {label = "Pferde", id = "horses"},
    {label = "Inventar", id = "inventory"},
    {label = "Karte (bald)", id = "map", dim = true},
    {label = "Bauen (bald)", id = "build", dim = true},
    {label = "Album (bald)", id = "album", dim = true},
    {label = "Speichern", id = "save", dim = not ctx.saving_ok},
  }
  local m = Menu.new(items, "Pause")
  local s = {}
  function s.update(n)
    if btnp(BTN_START) and not btn(BTN_SELECT) then return n.pop() end
    local r = m:update()
    if r == "close" or r == "resume" then n.pop()
    elseif r == "horses" then n.push(Screens.horses(ctx))
    elseif r == "inventory" then n.push(Screens.inventory(ctx))
    elseif r == "save" then
      ctx.save()
      ctx.toast("Gespeichert.")
      n.pop()
    end
  end
  function s.draw()
    m:draw(100, 50)
  end
  s.overlay = true        -- Welt bleibt darunter sichtbar
  return s
end

return Screens
