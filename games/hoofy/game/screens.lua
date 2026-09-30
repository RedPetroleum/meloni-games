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
    print("Wert: " .. Value.wert(data) .. " G", 6, 142, C.gold)
    if data.traechtig then print("Trächtig bis Tag " .. data.traechtig.tag, 6, 154, C.text) end
    if data.zucht_pause and ctx.clock and data.zucht_pause > ctx.clock.day then print("Pause bis Tag " .. data.zucht_pause, 6, 154, C.dim) end
    footer("A: umbenennen   B: zurück")
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
        msg = why == "Geld" and "Zu wenig Geld." or "Hast du schon."
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
      for k, e in ipairs({{"tempo", "Tempo"}, {"staerke", "Stärke"}, {"spuer", "Spür"}, {"ausdauer", "Ausdauer"}}) do
        stat_bar(8, 120 + (k - 1) * 11, e[2], d, e[1])
      end
      print("Bindung " .. d.bindung .. ", " .. K.charakter[d.zug].name, 8, 166, C.text)
      print("Leistung " .. flr(Value.leistung(d) * 100) .. " %, Wert " .. Value.wert(d) .. " G", 8, 177, C.dim)
      print("Farbfaktor x" .. Value.farbfaktor(d) .. ", Kauf = Wert x1,3", 8, 188, C.dim)
    end
    if msg and msg_t > 0 then print(msg, 8, 218, C.gold) end
    footer("A: kaufen   B: zurück")
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

-- ---- Pausenmenü (E5) ----

function Screens.pause(ctx, nav)
  local items = {
    {label = "Weiter", id = "resume"},
    {label = "Pferde", id = "horses"},
    {label = "Inventar", id = "inventory"},
    {label = "Bestellungen", id = "orders"},
    {label = "Karte", id = "map"},
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
    elseif r == "map" then n.push(Screens.map(ctx))
    elseif r == "orders" then n.push(Screens.orders(ctx))
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
