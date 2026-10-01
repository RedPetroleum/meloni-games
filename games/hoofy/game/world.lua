-- Die Welt-Szene: herumlaufen im aktuellen Gebiet. Pferde, Tag/Nacht, Menüs kommen mit den
-- Aufgaben aus PLAN.md dazu.
local Stage = require("game.stage")
local Wild = require("game.wild")
local Leash = require("game.leash")
local Ride = require("game.ride")
local Care = require("game.care")
local Farm = require("game.farm")
local Clock = require("game.clock")
local Days = require("game.days")
local Screens = require("game.screens")
local Save = require("game.save")
local Explore = require("game.explore")
local Economy = require("game.economy")
local Reise = require("game.reise")
local Schaetze = require("game.schaetze")
local Wetter = require("game.wetter")
local Reformen = require("game.reformen")
local Market = require("game.market")
local Buyers = require("game.buyers")
local Orders = require("game.orders")
local Breeding = require("game.breeding")
local Rng = require("lib.rng")
local Menu = require("game.menu")
local K = require("game.katalog")
local H = require("game.horse_model")
local U = require("lib.util")

local WorldScene = {}

local ctx, paused, anim_frame, t, wild, toast, a_hold, a_free, mounted_hold, menu, clock
local stack, nav = {}, {}
local select_held, select_used = false, false
local idle_t = 0
local saving, seed_now     -- saving: echtes Spiel (Neu/Weiter), Szenarien speichern nie

-- arg (optional): {ort = Name aus area.places} oder {cx, cy}: dort starten statt am Hof.
function WorldScene.enter(arg)
  local snap, farm, seed
  saving = false
  if arg and arg.laden then
    snap = Save.read()
    if snap then seed, farm = snap.seed, snap.hof end
  end
  if arg and arg.neu then seed = Save.new_seed() end
  local reise = arg and arg.reise            -- Fahrt in ein anderes Gebiet (D1), arg.reise = Reisedaten
  if reise then snap, seed, farm = reise, reise.seed, reise.hof end
  seed_now = seed
  saving = (arg and (arg.neu or (arg.laden and snap) or (reise and arg.saving))) and true or false
  ctx = Stage.build(reise and reise.gebiet or 1, seed, farm)
  ctx.hof = farm or ctx.area.farm
  if arg and (arg.ort or arg.cx) then
    local p = arg.ort and ctx.area.places[arg.ort] or (arg.cx and {arg.cx, arg.cy})
    if not p then error("unbekannter Ort " .. tostring(arg.ort)) end
    ctx.player.x, ctx.player.y = p[1] * 16 + 8, p[2] * 16 + 14
    ctx.trail:reset(ctx.player.x, ctx.player.y)
    ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
  end
  paused, anim_frame, t = false, 1, 0
  stack = {}
  wild = Wild.new(ctx, ctx.area.seed, arg and arg.wild_nah)
  toast, a_hold, a_free, menu = nil, 0, false, nil
  clock = Clock.new(arg and arg.tag, arg and arg.zeit)
  ctx.clock = clock
  if arg and arg.regen ~= nil then ctx.regen_erzwungen = arg.regen end
  if arg and arg.anbau then
    -- Beete mit allen Pflanzen, danach arg.tage Tage vergehen (nur das Wachsen, keine Tagesregeln)
    local pl = ctx.area.plot
    ctx.money = 1000
    ctx.player.x, ctx.player.y = (pl.x + 10) * 16, (pl.y + 8) * 16 + 12
    for _, pf in ipairs(K.futter.anbau) do ctx.inv["samen_" .. pf.id] = 1 end
    for x = 13, 19 do for y = 5, 6 do Farm.place(ctx, "beet", pl.x + x, pl.y + y) end end
    for x = 13, 14 do for y = 7, 8 do Farm.place(ctx, "beet", pl.x + x, pl.y + y) end end
    local row = {"gras", "karotte", "hafer", "sonnenblume", "zuckerruebe", "drachenfrucht", "goldene_karotte"}
    for i, id in ipairs(row) do Farm.plant(ctx, id, pl.x + 12 + i, pl.y + 5, 1) end
    for x = 13, 19 do Farm.plant(ctx, "karotte", pl.x + x, pl.y + 6, 1) end
    Farm.plant(ctx, "apfelbaum", pl.x + 13, pl.y + 7, 1)
    for d = 2, 1 + (arg.tage or 0) do Farm.grow(ctx, d) end
    wild.count = 0
  elseif arg and arg.fahrt then
    -- Reise: Schuppen mit Mofa, Anhänger für 2, zwei Pferde an der Leine, vor dem Schuppen
    local pl = ctx.area.plot
    ctx.money = 1000
    assert(Farm.place(ctx, "schuppen", pl.x + 13, pl.y + 14))
    ctx.money = 500
    ctx.inv.mofa, ctx.inv.anhaenger_2 = 1, 1
    Economy.refresh_gebiet(ctx)
    ctx.player.x, ctx.player.y = (pl.x + 14) * 16 + 8, (pl.y + 16) * 16 + 14
    ctx.trail:reset(ctx.player.x, ctx.player.y)
    ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
    wild.count = 0
    for _, n in ipairs({"Hilde", "Bruno"}) do wild:attach(wild:add_own({rasse = "noriker", bindung = 40, name = n})) end
  elseif arg and arg.schatz then
    -- Reiter mit Aufspürung 100 steht 5 Kacheln neben dem ersten Schatz; ohne Steuern findet er ihn
    Schaetze.setup(ctx)
    local t = ctx.schaetze[1]
    ctx.player.x, ctx.player.y = (t.cx + 5) * 16 + 8, t.cy * 16 + 8
    ctx.trail:reset(ctx.player.x, ctx.player.y)
    ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
    wild.count = 0
    local h = wild:add_own({rasse = "haflinger", bindung = 80, name = "Spürnase", sattel = "einfacher_sattel"})
    h.x, h.y = ctx.player.x, ctx.player.y
    h.data.gen.spuer, h.data.pot.spuer = 100, 100
    wild:mount(h)
    ctx.money = 0
  elseif arg and arg.gebaeude then
    -- Alle Gebäude auf dem Grundstück (Koordinaten relativ zum Grundstück)
    local pl = ctx.area.plot
    ctx.money = 100000
    ctx.player.x, ctx.player.y = (pl.x + 10) * 16, (pl.y + 9) * 16 + 12
    for _, b in ipairs({{"hangar", 0, 5}, {"stall_xl", 6, 5}, {"garage", 16, 5}, {"stall_l", 12, 0},
      {"villa", 14, 10}, {"schuppen", 13, 14}, {"haeuschen", 17, 14}, {"stall_m", 0, 17}}) do
      local ok, why = Farm.place(ctx, b[1], pl.x + b[2], pl.y + b[3])
      if not ok then error("Gebäude " .. b[1] .. ": " .. tostring(why)) end
    end
    wild.count = 0
  elseif arg and arg.weiden then
    -- Zweite Weide rechts neben der ersten (6×5 innen, Tor oben) und eine offene Koppel ohne Tor
    local pl = ctx.area.plot
    ctx.money = 1000
    Farm.fence_rect(ctx, pl.x + 14, pl.y + 10, pl.x + 19, pl.y + 15, {pl.x + 16, pl.y + 10})
    Farm.fence_rect(ctx, pl.x + 14, pl.y + 2, pl.x + 18, pl.y + 6, nil)
    wild.count = 0
  elseif arg and arg.stammbaum then
    -- Vier Generationen: 8 wilde Urgroßeltern → Großeltern → Eltern → Fohlen C
    wild.count = 0
    local rng = Rng.new(17)
    local function wildhorse(sex, name)
      local d = H.wild({rng = rng, sex = sex})
      d.name = name
      Breeding.ensure_id(d, ctx.herd)
      return d
    end
    local function kid(f, m, name)
      local d = Breeding.foal(f, m, rng, 0)
      d.name, d.alter = name, 1
      Breeding.ensure_id(d, ctx.herd)
      return d
    end
    local z = {}
    for i, n in ipairs({"Zora", "Zeus", "Zita", "Zorro", "Zilli", "Zack", "Zenzi", "Zabel"}) do z[i] = wildhorse(i % 2 == 0 and "m" or "w", n) end
    local a1, a2 = kid(z[2], z[1], "Anton"), kid(z[4], z[3], "Berta")
    local a3, a4 = kid(z[6], z[5], "Cäsar"), kid(z[8], z[7], "Dora")
    local b1, b2 = kid(a1, a2, "Emil"), kid(a3, a4, "Frieda")
    local c = kid(b1, b2, "Gustl")
    wild:adopt(c)
  elseif arg and arg.hof then
    -- Drei eigene Pferde: eins auf der Weide, eins im Stall, eins an der Leine
    wild.count = 0
    local a = wild:add_own({rasse = "noriker", bindung = 40, name = "Hilde"})
    local b = wild:add_own({rasse = "haflinger", bindung = 50, name = "Bruno"})
    local c = wild:add_own({rasse = "shetlandpony", bindung = 30, name = "Keks"})
    wild:house(a, "weide")
    wild:house(b, "stall")
    wild:attach(c)
    if arg.staerke then a.data.gen.staerke, a.data.pot.staerke = arg.staerke, 100 end
  elseif arg and arg.ritt then
    -- Ein zahmes Pferd (Bindung 80, Sattel) steht neben dem Spieler; eine Reihe Büsche 6 Kacheln rechts.
    wild.count = 0
    local h = wild:spawn_at(ctx.player.x + 18, ctx.player.y, {rasse = arg.rasse or "haflinger", rng = wild.rng})
    h.data.bindung, h.data.sattel = arg.bindung or 80, arg.sattel or "einfacher_sattel"
    h.data.lampe = arg.lampe or nil
    if arg.staerke then h.data.gen.staerke, h.data.pot.staerke = arg.staerke, max(arg.staerke, h.data.pot.staerke) end
    h.wild, h.data.wild, h.tamed = false, nil, true
    table.remove(wild.list)
    ctx.herd[1], ctx.herd_horses[1] = h.data, h
    wild:attach(h)
    if arg.aufsitzen then wild:mount(h) end
    local cx, cy = ctx.player.x // 16 + 6, ctx.player.y // 16
    for dy = -2, 2 do
      ctx.map:set("coll", cx, cy + dy, arg.hindernis or "u")
      ctx.map:add_object(arg.hindernis == "o" and "rock" or "bush", cx, cy + dy)
    end
  elseif arg and arg.zaehmen then
    -- ein einzelnes Pferd, 140 px rechts vom Spieler (Szenario zaehmen)
    wild.count = 0
    local h = wild:spawn_at(ctx.player.x + 140, ctx.player.y, {rasse = "haflinger", rng = wild.rng})
    h.data.bindung = arg.bindung or 35
    h.debug_log = true
  else
    wild:fill()
  end
  ctx.wild = wild
  ctx.sfx.music(clock:is_night() and "night" or "day")
  ctx.day = clock.day
  ctx.on_plot = function()
    if not ctx.area.farm then return false end
    local p, pl = ctx.player, ctx.area.plot
    return p.x >= pl.x * 16 and p.x < (pl.x + pl.w) * 16 and p.y >= pl.y * 16 and p.y < (pl.y + pl.h) * 16
  end
  ctx.save = function() end
  if arg and arg.geld then ctx.money = arg.geld end
  ctx.saving_ok = saving
  ctx.toast = function(text) toast = {text = text, t = 120} end
  if saving then ctx.save = WorldScene.save end
  if snap and (saving or reise) then
    ctx.money, ctx.inv, ctx.market, ctx.buyer = snap.geld, snap.inv, snap.markt, snap.kaeufer
    ctx.orders = snap.bestellungen or {}
    Economy.refresh_gebiet(ctx)
    clock.day, clock.t = snap.tag, snap.zeit
    clock.woke = not reise and clock.t > 0 and clock.t < Clock.DAWN
    if snap.pos then
      ctx.player.x, ctx.player.y = snap.pos[1], snap.pos[2]
      ctx.trail:reset(ctx.player.x, ctx.player.y)
      ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
    end
    for _, c in ipairs(snap.aenderungen or {}) do ctx.map:set(c[1], c[2], c[3], c[4]) end
    if snap.erkundet then ctx.explored = snap.erkundet end
    ctx.heim = reise and reise.heim or nil
    ctx.gefunden, ctx.lager = snap.gefunden or {}, snap.lager or {}
    ctx.turnier, ctx.reform = snap.turnier, snap.reform
    for _, d in ipairs(snap.herd) do
      if ctx.heim and not (snap.mit and snap.mit[d]) then
        ctx.herd[#ctx.herd + 1] = d        -- bleibt zu Hause: nur die Daten reisen mit dem Spielstand
      else
        wild:adopt(d)
      end
    end
  end
  Reformen.erreicht(ctx, ctx.area.nr, clock.day)
  Reformen.anwenden(ctx)
  ctx.lager = ctx.lager or {}
  ctx.fund_rng = Rng.new((ctx.seed or 1) + 77)
  Schaetze.setup(ctx)
  if ctx.area.nr == 1 and reise then
    local n, sum = Schaetze.heimbringen(ctx)
    if n > 0 then toast = {text = "Fundstücke verkauft: " .. n .. " (" .. sum .. " G).", t = 200} end
  end
  if not ctx.buyer then ctx.buyer = Buyers.visit(ctx.seed, clock.day) end
  if not snap and #ctx.orders == 0 and (clock.day - 1) % 3 == 0 then Orders.tick(ctx, clock.day) end
  if arg and arg.bestellung then
    local d = ctx.herd[1]
    ctx.orders = {Orders.for_horse(d, clock.day, "Frau Schmitt"), Orders.generate(ctx.seed, clock.day + 1, 1)}
  end
  if arg and arg.kaeufer then ctx.buyer = {typ = arg.kaeufer, tag = clock.day, verkauft = false} end
  Buyers.sync(ctx, clock:is_night())
  if arg and arg.reform then
    local st = Reformen.state(ctx)
    st.aktiv[#st.aktiv + 1] = {id = arg.reform, von = 1, bis = clock.day + 3}
    Reformen.anwenden(ctx)
  end
  if arg and arg.fahrzeug then ctx.inv[arg.fahrzeug] = 1 Economy.refresh_gebiet(ctx) end
  if arg and arg.screen then
    local name = arg.screen
    if name ~= "none" and name ~= "bauen" and name ~= "weiden" then nav.push(Screens.pause(ctx, nav)) end
    if name == "horses" or name == "info" or name == "keyboard" then nav.push(Screens.horses(ctx)) end
    if name == "info" or name == "keyboard" then nav.push(Screens.info(ctx, ctx.herd[1])) end
    if name == "keyboard" then nav.push(Screens.keyboard("Neuer Name", ctx.herd[1].name, 12, function(t) ctx.herd[1].name = t end)) end
    if name == "map" then nav.push(Screens.map(ctx)) end
    if name == "bauen" or name == "weiden" then nav.push(Screens.build(ctx)) end
    if name == "stammbaum" then nav.push(Screens.stammbaum(ctx, ctx.herd[#ctx.herd])) end
    if name == "springen" then nav.push(Screens.springreiten(ctx, ctx.herd[1], function() end)) end
    if name == "rennen" then nav.push(Screens.rennen(ctx, ctx.herd[1], {35, 30, 25, 20, 15}, function() end)) end
    if name == "zeitung" then nav.push(Screens.zeitung(ctx)) end
    if name == "turnier" then nav.push(Screens.turnier(ctx)) end
    if name == "jobs" then nav.push(Screens.jobs(ctx)) end
    if name == "bestellung" then nav.push(Screens.orders(ctx)) end
    if name == "kaeufer" then nav.push(Screens.buyer(ctx, function(text) say(text, 150) end)) end
    if name == "markt" then Market.refresh(ctx, clock.day) nav.push(Screens.market(ctx)) end
    if name == "laden" then nav.push(Screens.shop(ctx)) end
    if name == "inventar" then nav.push(Screens.inventory(ctx)) end
  end
end


local FOODS = {"heu", "hafer", "karotte", "premiumfutter"}

local function say(text, frames)
  toast = {text = text, t = frames or 120}
end

-- Meldungen der Reformen am Morgen (E4): Angriff der Nacht, Steuer, neue Zeitung. nil, wenn nichts war.
local function chaos_text()
  local a = ctx.angriff
  if a then
    if a.abgewehrt then return a.tiere .. ": Starke Pferde haben die Tiere abgewehrt." end
    if a.zerstoert > 0 or a.erschreckt > 0 then
      return a.tiere .. ": " .. a.zerstoert .. " Deko kaputt, " .. a.erschreckt .. " Pferd(e) erschreckt."
    end
  end
  if (ctx.steuer or 0) > 0 then return "Pferdesteuer: " .. ctx.steuer .. " G bezahlt." end
  if ctx.reform_neu then return "Zeitung: Neue Reform " .. ctx.reform_neu .. "!" end
end

-- Hauptmenü eines eigenen Pferds (E2).
local function open_menu(h)
  local led = h.state == "led" or h.state == "follow"
  menu = {
    horse = h, stage = "main",
    m = Menu.new({
      {label = "Streicheln", id = "stroke"},
      {label = "Füttern", id = "feed"},
      {label = "Striegeln", id = "brush", dim = (ctx.inv.buerste or 0) < 1},
      {label = led and "Leine lösen" or "Anleinen", id = "leash"},
      {label = "Aufsitzen", id = "mount"},
      {label = "Ausrüsten", id = "gear"},
      {label = "Unterbringen", id = "house"},
      {label = "Info", id = "info"},
    }, h.data.name),
  }
end

local CROP_FOODS = {"apfel", "sonnenblumenkerne", "minze", "zuckerruebe", "luzerne", "drachenfrucht", "goldene_karotte"}

local function open_food(h)
  local items = {}
  for _, id in ipairs(FOODS) do
    local n = ctx.inv[id] or 0
    local name = id
    for _, f in ipairs(K.futter.kaufen) do if f.id == id then name = f.name end end
    items[#items + 1] = {label = name .. " x" .. n, id = id, dim = n < 1}
  end
  for _, id in ipairs(CROP_FOODS) do          -- Ernte nur, wenn welche da ist
    local n = ctx.inv[id] or 0
    if n > 0 then items[#items + 1] = {label = Farm.CROP_NAME[id] .. " x" .. n, id = id} end
  end
  menu.stage, menu.m = "food", Menu.new(items, "Füttern")
end

-- Ausrüstung: anlegen aus dem Vorrat, ablegen was getragen wird.
local function gear_items(d)
  local items = {}
  local worn = {}
  if d.sattel then worn[#worn + 1] = d.sattel end
  if d.taschen then worn[#worn + 1] = d.taschen end
  if d.lampe then worn[#worn + 1] = "sattellampe" end
  for _, j in ipairs(Economy.JEWELRY) do if d.schmuck and d.schmuck[j] then worn[#worn + 1] = j end end
  for _, id in ipairs(worn) do
    items[#items + 1] = {label = "ab: " .. Economy.find(id).name, id = "ab:" .. id}
  end
  local all = {}
  for _, id in ipairs(Economy.SLOTS.sattel) do all[#all + 1] = id end
  for _, id in ipairs(Economy.SLOTS.taschen) do all[#all + 1] = id end
  all[#all + 1] = "sattellampe"
  for _, id in ipairs(Economy.JEWELRY) do all[#all + 1] = id end
  for _, id in ipairs(all) do
    local n = ctx.inv[id] or 0
    if n > 0 then items[#items + 1] = {label = "an: " .. Economy.find(id).name .. " x" .. n, id = "an:" .. id} end
  end
  if #items == 0 then items[1] = {label = "Nichts im Vorrat", id = "none", dim = true} end
  return items
end

local function open_gear(h)
  menu.stage, menu.m = "gear", Menu.new(gear_items(h.data), "Ausrüstung " .. h.data.name)
end

local HOUSE_NAMES = {stall = "Stall", weide = "Weide", frei = "Frei"}

local function open_house(h)
  local cap = Farm.capacity(ctx.area.farm)
  local items = {}
  for _, ort in ipairs({"stall", "weide", "frei"}) do
    local n = Farm.count(ctx.herd, ort)
    local full = n >= cap[ort] and h.data.ort ~= ort
    local weak = ort == "frei" and not Farm.may_roam(h.data, H)
    items[#items + 1] = {label = string.format("%s %d/%d", HOUSE_NAMES[ort], n, cap[ort]), id = ort,
      dim = full or weak or h.data.ort == ort}
  end
  menu.stage, menu.m = "house", Menu.new(items, "Wohin mit " .. h.data.name .. "?")
end

-- Menü an der Stalltür: Pferde im Stall herausholen, Zucht starten.
local function open_stall()
  local items = {}
  for i, h in ipairs(wild:in_stall()) do
    local d = h.data
    local tag = d.traechtig and " (trächtig)" or (d.zucht_pause and d.zucht_pause > clock.day and " (Pause)") or ""
    items[#items + 1] = {label = d.name .. tag, id = i}
  end
  local can = #Breeding.stallions(ctx.herd) > 0 and #Breeding.mares(ctx.herd, clock.day) > 0
  items[#items + 1] = {label = "Zucht starten", id = "breed", dim = not can}
  menu = {horse = ctx.player, stage = "stall", m = Menu.new(items, "Im Stall")}
end

local function open_pick(stage, list, title)
  local items = {}
  for i, d in ipairs(list) do items[#items + 1] = {label = d.name, id = i} end
  menu.stage, menu.list, menu.m = stage, list, Menu.new(items, title)
end

local function do_action(id)
  local h = menu.horse
  local d = h.data
  if menu.stage == "hengst" then
    if id == "close" then return open_stall() end
    menu.hengst = menu.list[id]
    open_pick("stute", Breeding.mares(ctx.herd, clock.day), "Stute für " .. menu.hengst.name)
    -- Verwandtschaft sofort anzeigen (Inzucht-Malus)
    for i, d in ipairs(menu.list) do
      local pct, what = Breeding.verwandtschaft(menu.hengst, d)
      if pct > 0 then menu.m.items[i].label = d.name .. " (" .. what .. ": -" .. pct .. " %)" end
    end
    return
  end
  if menu.stage == "stute" then
    if id == "close" then return open_stall() end
    local mare, stallion = menu.list[id], menu.hengst
    local ok, why = Breeding.start(ctx, stallion, mare, clock.day)
    local pct = Breeding.verwandtschaft(stallion, mare)
    say(ok and (stallion.name .. " und " .. mare.name .. ": Fohlen in " .. K.zeit.traechtig_tage .. " Tagen." .. (pct > 0 and (" Inzucht: Gen-Werte -" .. pct .. " %.") or "")) or ("Geht nicht: " .. tostring(why)), 180)
    if ok then ctx.sfx.pet() end
    menu = nil
    return
  end
  if menu.stage == "stall" then
    if id == "close" then menu = nil return end
    if id == "breed" then
      return open_pick("hengst", Breeding.stallions(ctx.herd), "Hengst wählen")
    end
    local inside = wild:in_stall()
    local sel = inside[id]
    menu = nil
    if sel then
      wild:take_out(sel)
      say(sel.data.name .. " ist an der Leine.")
    end
    return
  end
  if menu.stage == "gear" then
    if id == "close" then return open_menu(h) end
    local kind, what = id:match("^(%a+):(.+)$")
    if kind == "an" then
      local ok, why = Economy.equip(ctx, d, what)
      say(ok and d.name .. " trägt: " .. Economy.find(what).name .. "." or "Geht nicht: " .. tostring(why) .. ".")
    elseif kind == "ab" then
      Economy.unequip(ctx, d, what)
      say(d.name .. " trägt " .. Economy.find(what).name .. " nicht mehr.")
    end
    menu = nil
    return
  end
  if menu.stage == "house" then
    if id == "close" then return open_menu(h) end
    local ok, why = wild:house(h, id)
    say(ok and d.name .. " kommt in: " .. HOUSE_NAMES[id] .. "." or "Geht nicht: " .. tostring(why) .. ".")
    menu = nil
    return
  end
  if menu.stage == "food" then
    if id == "close" then return open_menu(h) end
    ctx.inv[id] = ctx.inv[id] - 1
    local name, bond = Care.feed(d, id)
    ctx.sfx.eat()
    say(d.name .. " frisst " .. name .. ". Bindung +" .. bond .. ".")
    h.heart_t = 90
    menu = nil
    return
  end
  if id == "close" then menu = nil return end
  if id == "stroke" then
    local add = Care.stroke(d)
    ctx.sfx.pet()
    h.heart_t = 120
    say(add > 0 and d.name .. " genießt das. Bindung +" .. add .. "." or d.name .. " hatte heute schon genug Streicheleinheiten.")
    menu = nil
  elseif id == "feed" then
    open_food(h)
  elseif id == "house" then
    open_house(h)
  elseif id == "gear" then
    open_gear(h)
  elseif id == "brush" then
    local add = Care.brush(d)
    ctx.sfx.brush()
    say(d.name .. " glänzt. Sauberkeit +" .. add .. ".")
    menu = nil
  elseif id == "leash" then
    if h.state == "led" or h.state == "follow" then
      wild:release(h)
      say(d.name .. " ist frei.")
    else
      wild:attach(h)
      say(d.name .. (h.state == "follow" and " folgt dir." or " ist an der Leine."))
    end
    menu = nil
  elseif id == "mount" then
    if wild:mount(h) == "ok" then
      say(d.name .. ": aufgesessen!", 90)
      mounted_hold = true
    else
      ctx.sfx.snort()
      say(d.name .. " verweigert das Reiten!")
    end
    menu = nil
  elseif id == "info" then
    say(string.format("%s, %s: Tempo %d Stärke %d Bindung %d. %s.", d.name, K.rasse(d.rasse).name,
      H.stat(d, "tempo"), H.stat(d, "staerke"), d.bindung, Care.describe(d)), 240)
    menu = nil
  end
end

-- Speichert (Schlafen, Gebietswechsel, Pause-Menü, Beenden). Nur im echten Spiel.
function WorldScene.save()
  if not saving then return false end
  if ctx.heim then Schaetze.heimbringen(ctx) end        -- Fahrzeug fährt heim, Funde kommen ins Haus
  local snap = Save.snapshot(ctx, clock, seed_now)
  Save.write(snap)
  return true
end

-- Fährt in Gebiet nr (D1): neue Welt aus den Reisedaten, Spielstand wird gespeichert.
function WorldScene.reise(nr)
  local snap, why = Reise.fahren(ctx, clock, seed_now, nr)
  if not snap then say(why .. ".") return end
  local keep = saving
  WorldScene.enter({reise = snap, saving = keep})
  if keep then WorldScene.save() end
  say("Angekommen: " .. ctx.area.name .. ".", 150)
end

-- Beim Beenden über das Menü der Konsole (main.lua ruft _quit).
function WorldScene.quit()
  WorldScene.save()
end

-- Sattellampe (D5): leuchtet, wenn das Pferd, auf dem man reitet, sie trägt (Sichtkreis × 1,8).
function WorldScene.lamp()
  local r = ctx.player.riding
  return r and r.data.lampe or false
end

-- Erkundung: alles, was der Spieler gerade sieht (tagsüber der Bildschirm, nachts der Sichtkreis).
function WorldScene.explore()
  local p, cam = ctx.player, ctx.camera
  local r = clock:sight(70, WorldScene.lamp())
  if r and r < 400 then
    Explore.reveal(ctx.explored, p.x - r, p.y - r, p.x + r, p.y + r)
  else
    Explore.reveal(ctx.explored, cam.x, cam.y, cam.x + SCREEN_W, cam.y + SCREEN_H)
  end
end

function nav.push(screen) stack[#stack + 1] = screen end
function nav.pop() stack[#stack] = nil end

function WorldScene.update()
  -- Bildschirm-Stapel (E5): Pausenmenü und alles, was davon aufgeht; die Welt steht still
  if #stack > 0 then
    stack[#stack].update(nav)
    return
  end
  if btnp(BTN_START) and not btn(BTN_SELECT) then
    nav.push(Screens.pause(ctx, nav))
    ctx.sfx.ok()
    return
  end
  -- SELECT allein (beim Loslassen, wenn dabei nichts anderes gedrückt wurde): Karte (E6)
  if btn(BTN_SELECT) then
    for _, b in ipairs({BTN_LEFT, BTN_RIGHT, BTN_UP, BTN_DOWN, BTN_A, BTN_B, BTN_START}) do
      if btn(b) then select_used = true end
    end
    select_held = true
  elseif select_held then
    select_held = false
    if not select_used then
      nav.push(Screens.map(ctx))
      select_used = false
      return
    end
    select_used = false
  end
  if menu then
    local r = menu.m:update()
    if r then do_action(r) end
    if toast then toast.t = toast.t - 1; if toast.t <= 0 then toast = nil end end
    return
  end
  t = t + 1
  if t % 20 == 1 then WorldScene.explore() end
  local ev = clock:update()
  if ev == "dusk" then
    ctx.sfx.dusk()
    Buyers.sync(ctx, true)
    ctx.sfx.music("night")
    Days.dusk(ctx)
    say("Es wird dunkel.", 120)
  elseif ev == "day" then
    ctx.sfx.dawn()
    ctx.sfx.music("day")
    Days.new_day(ctx, clock.day)
    if #ctx.geburten > 0 then say("Fohlen geboren: " .. ctx.geburten[1], 200) end
    Market.refresh(ctx, clock.day)
    ctx.buyer = Buyers.visit(ctx.seed, clock.day)
    Buyers.sync(ctx, false)
    local od = Orders.tick(ctx, clock.day)
    if od.neu then say("Neue Bestellung von " .. od.neu.kunde .. ".", 150) end
    if #od.verfallen > 0 then say("Eine Bestellung ist verfallen.", 150) end
    local chaos = chaos_text()
    if chaos then say(chaos, 200)
    elseif ctx.nasse > 0 then say("Es hat geregnet: " .. ctx.nasse .. " Pferd(e) draußen sind schmutzig.", 180)
    elseif not toast then say("Tag " .. clock.day .. " beginnt.", 150) end
  end
  local p = ctx.player
  -- Schätze (D3): Frames ohne Steuern zählen, Pferd spürt auf und läuft los
  if btn(BTN_LEFT) or btn(BTN_RIGHT) or btn(BTN_UP) or btn(BTN_DOWN) then idle_t = 0 else idle_t = idle_t + 1 end
  local fname, fval = Schaetze.update(ctx, idle_t, t)
  if fname then
    ctx.sfx.ok()
    say("Gefunden: " .. fname .. (fval and fval > 0 and (" (+" .. fval .. " G)") or "") .. "!", 150)
  end
  if ctx.heim and Reise.at_station(ctx) and t % 30 == 0 then
    local n = Schaetze.abladen(ctx)
    if n > 0 then say(n .. " Fund" .. (n > 1 and "e" or "") .. " ins Fahrzeug geladen.", 150) end
  end
  if p.riding then
    -- Reiten (E3): A antippen = springen, A lange halten = absteigen
    if mounted_hold then
      if not btn(BTN_A) then mounted_hold = false end
    elseif btn(BTN_A) then
      a_hold = a_hold + 1
      if a_hold == Ride.HOLD then
        Ride.dismount(ctx)
        a_free = false
        toast = {text = "Abgestiegen.", t = 60}
      end
    else
      if a_hold > 0 and a_hold < 20 and p.riding then Ride.jump(p) end
      a_hold = 0
    end
  elseif btnp(BTN_A) then
    a_hold, a_free = 0, false
    local h = wild:try_tame()
    if h then
      local how = h.state == "follow" and "gezähmt, folgt dir." or "gezähmt, an der Leine."
      toast = {text = h.data.name .. " ist " .. how, t = 150}
      ctx.sfx.tame()
      log("ZAEHMEN " .. frame() .. " gezähmt: " .. h.data.name)
    else
      local own = wild:nearest_own()
      local ripe = Farm.ripe_near(ctx)
      if Reise.at_station(ctx) then          -- Fahrzeug hat Vorrang vor dem Pferdemenü (die Pferde stehen immer daneben)
        nav.push(Screens.reise(ctx, function(nr) WorldScene.reise(nr) end))
        ctx.sfx.ok()
      elseif own then
        open_menu(own)
        ctx.sfx.select()
      elseif ripe then
        local item, n = Farm.harvest(ctx, ripe, clock.day)
        ctx.sfx.eat()
        say("Geerntet: " .. n .. "x " .. Farm.CROP_NAME[item] .. ".", 120)
      elseif wild:at_bed_door() then
        if clock:sleep() then
          Days.new_day(ctx, clock.day)
          Market.refresh(ctx, clock.day)
          ctx.buyer = Buyers.visit(ctx.seed, clock.day)
          Buyers.sync(ctx, false)
          Orders.tick(ctx, clock.day)
          ctx.sfx.dawn()
          ctx.sfx.music("day")
          local saved = WorldScene.save()
          local fohlen = #ctx.geburten > 0 and (" Fohlen geboren: " .. ctx.geburten[1]) or ""
          say("Gut geschlafen. Tag " .. clock.day .. " beginnt." .. fohlen .. (saved and " Gespeichert." or ""), 200)
          local chaos = chaos_text()
          if chaos then say(chaos, 200) end
          ctx.sfx.start()
        else
          say("Noch nicht müde. Nachts kannst du im Wohnwagen schlafen.", 150)
        end
      elseif ctx.buyer_ent and U.dist(p.x, p.y, ctx.buyer_ent.x, ctx.buyer_ent.y) <= 30 then
        nav.push(Screens.buyer(ctx, function(text) say(text, 150) end))
        ctx.sfx.ok()
      elseif ctx.area.places.jobbrett and U.dist(p.x, p.y, ctx.area.places.jobbrett[1] * 16 + 8, ctx.area.places.jobbrett[2] * 16 + 8) <= 26 then
        nav.push(Screens.jobs(ctx))
        ctx.sfx.ok()
      elseif ctx.area.places.turnier and U.dist(p.x, p.y, ctx.area.places.turnier[1] * 16 + 8, ctx.area.places.turnier[2] * 16 + 8) <= 30 then
        nav.push(Screens.turnier(ctx))
        ctx.sfx.ok()
      elseif ctx.area.places.laden and U.dist(p.x, p.y, ctx.area.places.laden[1] * 16 + 8, ctx.area.places.laden[2] * 16 + 8) <= 26 then
        nav.push(Screens.shop(ctx))
        ctx.sfx.ok()
      elseif ctx.area.places.markt and U.dist(p.x, p.y, ctx.area.places.markt[1] * 16 + 8, ctx.area.places.markt[2] * 16 + 8) <= 26 then
        Market.refresh(ctx, clock.day)
        nav.push(Screens.market(ctx))
        ctx.sfx.ok()
      elseif wild:at_stall_door() and #wild:in_stall() > 0 then
        open_stall()
        ctx.sfx.select()
      else
        a_free = true
      end
    end
  elseif btn(BTN_A) and a_free then
    a_hold = a_hold + 1
    if a_hold == Leash.WHISTLE_FRAMES then
      ctx.sfx.start()
      local n = wild:whistle()
      toast = {text = n > 0 and "Pfiff! Sie kommen." or "Pfiff!", t = 90}
    end
  end
  if ctx.escaped then
    toast = {text = ctx.escaped.data.name .. " ist ausgerissen!", t = 150}
    ctx.escaped = nil
  end
  if toast then
    toast.t = toast.t - 1
    if toast.t <= 0 then toast = nil end
  end
  ctx.world:update()
  ctx.fx:update()
  local p = ctx.player
  ctx.camera:follow(p.x, p.y - 10)
  local frame_no = (t // 40) % 2 + 1
  if frame_no ~= anim_frame then
    anim_frame = frame_no
    ctx.map:set_anim_frame(frame_no)
  end
end

local function draw_hud()
  local C = ctx.colors
  rectfill(0, 0, SCREEN_W - 1, Stage.HUD_H - 1, C.panel)
  print("Tag " .. clock.day, 4, 3, C.text)
  local icon, f = clock:face()
  ctx.S.draw(icon, 50, 3)
  rectfill(62, 5, 101, 8, C.panel_light)
  rectfill(62, 5, 62 + flr(39 * f), 8, icon == "icon_sun" and C.gold or C.dim)
  local money = ctx.money .. " G"
  print(money, SCREEN_W - textw(money) - 4, 3, C.gold)
  local name = ctx.area.name
  print(name, (SCREEN_W - textw(name)) // 2, 3, C.dim)
  if Wetter.regnet(ctx, clock.day) then print("Regen", 215, 3, rgb(0xa8, 0xc8, 0xe8)) end
  -- Energie des Pferds beim Reiten (E9)
  local r = ctx.player.riding
  if r then
    local max_e = H.stat(r.data, "ausdauer")
    local e = r.data.energie
    local w = 70
    rectfill(4, SCREEN_H - 12, 4 + w + 1, SCREEN_H - 5, C.panel)
    rectfill(5, SCREEN_H - 11, 5 + flr(w * e / max_e), SCREEN_H - 6, e < 15 and C.red or C.gold)
    print("Energie", 80, SCREEN_H - 12, C.text)
  end
end

-- Seil von der Hand des Spielers zum Kopf jedes geführten Pferds (nicht bei freiem Folgen).
local function draw_rope()
  local hx, hy = ctx.player:hand()
  for _, h in ipairs(ctx.lead) do
    if h.state == "led" then
      local ax, ay = h:head()
      local d = U.dist(hx, hy, ax, ay)
      local sag = max(0, 10 - d / 4)
      local mx, my = (hx + ax) / 2, (hy + ay) / 2 + sag
      line(hx, hy + 1, mx, my + 1, 4)
      line(mx, my + 1, ax, ay + 1, 4)
      line(hx, hy, mx, my, 15)
      line(mx, my, ax, ay, 15)
    end
  end
end

function WorldScene.draw()
  local top = stack[#stack]
  if top and top.full then return top.draw() end   -- Vollbild: die Welt darunter bleibt ungezeichnet
  Stage.draw_world(ctx, function()
    draw_rope()
    if ctx.area.farm then Reformen.draw_tiere(ctx, clock, t) end
    if ctx.heim then      -- unterwegs steht das Fahrzeug am Ankunftspunkt
      local st = ctx.area.places.start
      ctx.S.draw("fahrzeug", st[1] * 16 - 8, st[2] * 16 - 10)
    end
  end)
  local radius = clock:sight(70, WorldScene.lamp())
  if radius and radius < 400 then
    local p = ctx.player
    Stage.draw_night(flr(p.x - ctx.camera.x), flr(p.y - 10 - ctx.camera.y), radius)
  end
  if Wetter.regnet(ctx, clock.day) and not clock:is_night() then Wetter.draw(t) end
  draw_hud()
  if menu then
    local h = menu.horse
    menu.m:draw(h.x - ctx.camera.x + 24, h.y - ctx.camera.y - 50)
  end
  if toast then
    local C = ctx.colors
    Stage.panel(40, 200, 279, 226)
    Stage.center(toast.text, 209, C.gold)
  end
  for i = 1, #stack do stack[i].draw() end
end

return WorldScene
