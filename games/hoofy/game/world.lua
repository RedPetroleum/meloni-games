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
local Album = require("game.album")
local Market = require("game.market")
local Buyers = require("game.buyers")
local Orders = require("game.orders")
local Breeding = require("game.breeding")
local Rng = require("lib.rng")
local HorseMenu = require("game.horse_menu")
local StallView = require("game.stall_view")
local Fortschritt = require("game.fortschritt")
local K = require("game.katalog")
local H = require("game.horse_model")
local U = require("lib.util")

local WorldScene = {}

local ctx, paused, anim_frame, t, wild, toast, a_hold, a_free, a_release, menu, clock, taming
local stack, nav = {}, {}
local idle_t = 0
local day_banner = nil       -- bis zu diesem t steht „Tag N“ groß in der Mitte (neuer Tag)
local DAY_BANNER = 150
local saving, seed_now     -- saving: echtes Spiel (Neu/Weiter), Szenarien speichern nie

-- arg (optional): {ort = Name aus area.places} oder {cx, cy}: dort starten statt am Hof.
function WorldScene.enter(arg)
  local snap, farm, seed, fill_later
  saving = false
  if arg and arg.laden then
    snap = Save.read()
    if snap then seed, farm = snap.seed, snap.hof end
  end
  if arg and arg.neu then seed = Save.new_seed() end
  local reise = arg and arg.reise            -- Fahrt in ein anderes Gebiet (D1), arg.reise = Reisedaten
  if reise then snap, seed, farm = reise, reise.seed, reise.hof end
  seed_now = seed
  -- Vergebene Namen (Rückmeldung 1.3.1): aus dem Spielstand, bei einer Reise bleiben sie, sonst neu
  if snap and snap.namen then H.names_reset(snap.namen) elseif not reise then H.names_reset({}) end
  saving = (arg and (arg.neu or (arg.laden and snap) or (reise and arg.saving))) and true or false
  ctx = Stage.build(reise and reise.gebiet or arg and arg.gebiet or 1, seed, farm)
  ctx.hof = ctx.area.farm or farm     -- der geladene Hof (Titel hat ihn schon im Speicher), unterwegs der Hof daheim
  if arg and (arg.ort or arg.cx) then
    local p = arg.ort and ctx.area.places[arg.ort] or (arg.cx and {arg.cx, arg.cy})
    if not p then error("unbekannter Ort " .. tostring(arg.ort)) end
    ctx.player.x, ctx.player.y = p[1] * 16 + 8, p[2] * 16 + 14
    ctx.trail:reset(ctx.player.x, ctx.player.y)
    ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
  end
  paused, anim_frame, t, day_banner = false, 1, 0, nil
  stack = {}
  wild = Wild.new(ctx, ctx.area.seed, arg and arg.wild_nah)
  toast, a_hold, a_free, a_release, menu, taming = nil, 0, false, false, nil, nil
  clock = Clock.new(arg and arg.tag, arg and arg.zeit)
  ctx.clock = clock
  if arg and arg.regen ~= nil then ctx.regen_erzwungen = arg.regen end
  if arg and arg.anbau then
    -- Beete mit allen Pflanzen, danach arg.tage Tage vergehen (nur das Wachsen, keine Tagesregeln)
    local pl = ctx.area.plot
    ctx.money = 1000
    ctx.player.x, ctx.player.y = (pl.x + 10) * 16, (pl.y + 8) * 16 + 12
    for _, pf in ipairs(K.futter.anbau) do ctx.inv["samen_" .. pf.id] = 20 end
    ctx.inv.hacke = 1
    for x = 13, 19 do for y = 5, 6 do Farm.place(ctx, "beet", pl.x + x, pl.y + y) end end
    for x = 13, 14 do for y = 7, 8 do Farm.place(ctx, "beet", pl.x + x, pl.y + y) end end
    for x = 15, 19 do Farm.place(ctx, "beet", pl.x + x, pl.y + 8) end        -- leere Beete zum Vergleich
    local row = {"gras", "karotte", "hafer", "sonnenblume", "zuckerruebe", "drachenfrucht", "goldene_karotte"}
    for i, id in ipairs(row) do Farm.plant(ctx, id, pl.x + 12 + i, pl.y + 5, 1) end
    for x = 13, 19 do Farm.plant(ctx, "karotte", pl.x + x, pl.y + 6, 1) end
    Farm.plant(ctx, "apfelbaum", pl.x + 13, pl.y + 7, 1)
    for d = 2, 1 + (arg.tage or 0) do Farm.grow(ctx, d) end
    wild.count = 0
  elseif arg and arg.fahrt then
    -- Reise: Schuppen mit Fahrrad und Mofa, Anhänger für 2, ein Pferd an der Leine und eins, das folgt, vor dem Schuppen
    local pl = ctx.area.plot
    ctx.money = 1000
    assert(Farm.place(ctx, "schuppen", pl.x + 13, pl.y + 14))
    ctx.money = 500
    ctx.inv.fahrrad, ctx.inv.mofa, ctx.inv.anhaenger_2 = 1, 1, 1
    Economy.refresh_gebiet(ctx)
    ctx.player.x, ctx.player.y = (pl.x + 14) * 16 + 8, (pl.y + 16) * 16 + 14
    ctx.trail:reset(ctx.player.x, ctx.player.y)
    ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
    wild.count = 0
    for _, n in ipairs({"Hilde", "Bruno"}) do wild:attach(wild:add_own({rasse = "noriker", bindung = n == "Bruno" and 75 or 40, name = n})) end
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
    a.data.train.staerke, a.data.train.tempo = 12, 8           -- etwas Training (Info-Balken zeigt den Anteil)
  elseif arg and arg.stall then
    -- Stall arg.stall (stall_s … stall_xl) mit so vielen Pferden, wie hineinpassen, minus eins; Ansicht offen
    local pl = ctx.area.plot
    ctx.money = 100000
    wild.count = 0
    local door
    if arg.stall == "stall_s" then
      door = Farm.stall_door(ctx.area.farm)
    else
      ctx.player.x, ctx.player.y = (pl.x + 16) * 16, (pl.y + 18) * 16
      assert(Farm.place(ctx, arg.stall, pl.x + 6, pl.y + 5))
      assert(Farm.remove(ctx, pl.x + 8, pl.y + 2))         -- der Startstall zählt dann nicht mit
      door = Farm.stall_doors(ctx.area.farm)[1]
    end
    local rassen = {"haflinger", "noriker", "shetlandpony", "friese", "araber", "mustang"}
    for i = 1, K.bauteil(arg.stall).plaetze - 1 do
      local h = wild:add_own({rasse = rassen[(i - 1) % #rassen + 1], name = "Pferd " .. i})
      h.data.sex = i % 2 == 0 and "m" or "w"
      assert(wild:house(h, "stall", true))
      if i == 2 then h.data.schmuck = {blumenkranz = true, maehnenschleife = true} end
    end
    ctx.player.x, ctx.player.y = door[1] * 16 + 8, door[2] * 16 + 14
    ctx.stall_door = door
  elseif arg and arg.goepel then
    -- Göpel rechts vom Startpunkt, ein Noriker zieht ihn (Szenario goepel)
    local pl = ctx.area.plot
    ctx.money = 2000
    assert(Farm.place(ctx, "goepel_generator", pl.x + 13, pl.y + 6))
    ctx.player.x, ctx.player.y = (pl.x + 11) * 16 + 8, (pl.y + 8) * 16 + 14
    ctx.trail:reset(ctx.player.x, ctx.player.y)
    ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
    wild.count = 0
    local h = wild:add_own({rasse = "noriker", bindung = 50, name = "Bruno"})
    h.data.gen.staerke = 60
    assert(wild:house(h, "goepel"))
  elseif arg and arg.zucht then
    -- Hengst und Stute im Stall, der Spieler steht vor der Stalltür (Szenario zucht)
    wild.count = 0
    local door = Farm.stall_door(ctx.area.farm)
    ctx.player.x, ctx.player.y = door[1] * 16 + 8, door[2] * 16 + 14
    ctx.trail:reset(ctx.player.x, ctx.player.y)
    ctx.camera:snap(ctx.player.x, ctx.player.y - 10)
    local hengst = wild:add_own({rasse = "noriker", bindung = 50, name = "Max"})
    local stute = wild:add_own({rasse = "haflinger", bindung = 50, name = "Lotte"})
    hengst.data.sex, hengst.data.alter = "m", 3
    stute.data.sex, stute.data.alter = "w", 3
    wild:house(hengst, "stall")
    wild:house(stute, "stall")
    if arg.geburt then                  -- Stute trägt schon, das Fohlen kommt am nächsten Morgen
      assert(Breeding.start(ctx, hengst.data, stute.data, clock.day))
      stute.data.traechtig.tag = clock.day + 1
    end
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
  elseif arg and arg.pferde then
    -- Eigene Pferde beim Spieler (Szenario gebiet, pferde = n): das erste an der Leine, die anderen folgen
    wild.count = 0
    for i = 1, arg.pferde do wild:attach(wild:add_own({rasse = "haflinger", bindung = i == 1 and 40 or 80, name = "Pferd " .. i})) end
  else
    fill_later = true            -- erst nach dem Spielstand: Tag und gezähmte Pferde zählen (KATALOG §10)
  end
  ctx.wild = wild
  ctx.sfx.music(clock:is_night() and "night" or "day")
  ctx.day = clock.day
  ctx.on_plot = function()
    if not ctx.area.farm then return false end
    local p = ctx.player
    return Farm.owns(ctx.area.farm, flr(p.x / 16), flr((p.y - 1) / 16))
  end
  ctx.save = function() end
  if arg and arg.geld then ctx.money = arg.geld end
  if arg and arg.laterne then ctx.inv.laterne = 1 end
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
    ctx.turnier, ctx.reform, ctx.album = snap.turnier, snap.reform, snap.album
    ctx.getauscht = snap.getauscht
    ctx.gezaehmt, ctx.jobs = snap.gezaehmt, snap.jobs
    for _, d in ipairs(snap.herd) do
      if ctx.heim and not (snap.mit and snap.mit[d]) then
        ctx.herd[#ctx.herd + 1] = d        -- bleibt zu Hause: nur die Daten reisen mit dem Spielstand
      else
        wild:adopt(d)
      end
    end
  end
  -- Namen eigener Pferde und ihrer Vorfahren gelten als vergeben (auch für ältere Spielstände ohne Liste)
  local function reserve_tree(a)
    if not a then return end
    H.reserve_name(a.name)
    reserve_tree(a.v)
    reserve_tree(a.m)
  end
  for _, d in ipairs(ctx.herd) do
    H.reserve_name(d.name)
    if d.ahnen then reserve_tree(d.ahnen.v) reserve_tree(d.ahnen.m) end
    if d.traechtig then H.reserve_name(d.traechtig.vater.name) end
  end
  if fill_later then wild:fill() end
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
  if arg and arg.album_voll then
    for _, r in ipairs(K.rassen.liste) do
      for i, f in ipairs(Album.farben(r.id)) do if i % 2 == 1 then ctx.album = ctx.album or {} ctx.album[r.id .. ":" .. f] = true end end
    end
  end
  if arg and arg.reform then
    local st = Reformen.state(ctx)
    st.aktiv[#st.aktiv + 1] = {id = arg.reform, von = 1, bis = clock.day + 3}
    Reformen.anwenden(ctx)
  end
  if arg and arg.fahrzeug then ctx.inv[arg.fahrzeug] = 1 Economy.refresh_gebiet(ctx) end
  if arg and arg.anhaenger then ctx.inv["anhaenger_" .. arg.anhaenger] = 1 end
  if reise then Reise.ausladen(ctx) end     -- angekommen: Pferde aus dem Anhänger stehen daneben
  if reise and ctx.area.farm then
    -- unterwegs geborene Fohlen stehen im Stall: Platz machen, Fohlen und Mütter bleiben
    local protect = {}
    for _, d in ipairs(ctx.herd) do
      if d.alter < 1 or (d.zucht_pause or 0) > clock.day then protect[d] = true end
    end
    local moves = wild:make_room(protect)
    if #moves > 0 then toast = {text = table.concat(moves, " "), t = 240} end
  end
  ctx.world:add(Reise.entity(ctx))
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
    if name == "tausch" then nav.push(Screens.tausch(ctx)) end
    if name == "album" then nav.push(Screens.album(ctx)) end
    if name == "zeitung" then nav.push(Screens.zeitung(ctx)) end
    if name == "turnier" then nav.push(Screens.turnier(ctx)) end
    if name == "jobs" then nav.push(Screens.jobs(ctx)) end
    if name == "jobspiel" then
      local job
      for _, j in ipairs(K.jobs.liste) do if j.id == arg.job then job = j end end
      nav.push(require("game.jobspiel").screen(ctx, job or K.jobs.liste[1], ctx.herd[1], function() end))
    end
    if name == "bestellung" then nav.push(Screens.orders(ctx)) end
    if name == "kaeufer" then nav.push(Screens.buyer(ctx, function(text) say(text, 150) end)) end
    if name == "markt" then Market.refresh(ctx, clock.day) nav.push(Screens.market(ctx)) end
    if name == "laden" then nav.push(Screens.shop(ctx)) end
    if name == "inventar" then nav.push(Screens.inventory(ctx)) end
  end
end


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

-- Umgebung für das Pferdemenü (game/horse_menu.lua) und die Stallansicht.
local function menu_env()
  return {ctx = ctx, wild = wild, nav = nav, say = say, on_mount = function() a_release = true end}
end

-- Hauptmenü eines eigenen Pferds (E2).
local function open_menu(h)
  menu = HorseMenu.open(menu_env(), h)
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

-- Licht des Spielers: Sattellampe (D5) am gerittenen Pferd 1,8, sonst Laterne 1 (einmal gekauft, wird
-- nachts von selbst getragen), ohne beides nil (alles gleichmäßig dunkel).
function WorldScene.light()
  local r = ctx.player.riding
  if r and r.data.lampe then return 1.8 end
  if (ctx.inv.laterne or 0) > 0 then return 1 end
  return nil
end

-- Erkundung: alles, was der Spieler gerade sieht (tagsüber der Bildschirm, nachts der Sichtkreis).
function WorldScene.explore()
  local p, cam = ctx.player, ctx.camera
  local r = clock:sight(70, WorldScene.light())
  if r and r < 400 then
    Explore.reveal(ctx.explored, p.x - r, p.y - r, p.x + r, p.y + r)
  else
    Explore.reveal(ctx.explored, cam.x, cam.y, cam.x + SCREEN_W, cam.y + SCREEN_H)
  end
end

function nav.push(screen) stack[#stack + 1] = screen end
function nav.pop() stack[#stack] = nil end

function WorldScene.update()
  if ctx.stall_door then nav.push(StallView.new(menu_env(), ctx.stall_door)) ctx.stall_door = nil end   -- Szenario stall
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
  if menu then
    if menu:update() then menu = nil end
    if toast then toast.t = toast.t - 1; if toast.t <= 0 then toast = nil end end
    return
  end
  t = t + 1
  if t % 20 == 1 then WorldScene.explore() end
  if t % 30 == 5 then
    local neu = Album.sichten(ctx)
    if neu > 0 and not toast then say("Album: " .. neu .. " neu eingetragen.", 90) end
  end
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
    day_banner = t + DAY_BANNER
    Days.new_day(ctx, clock.day)
    if #ctx.geburten > 0 then say("Fohlen geboren: " .. ctx.geburten[1], 300) end
    Market.refresh(ctx, clock.day)
    ctx.buyer = Buyers.visit(ctx.seed, clock.day)
    Buyers.sync(ctx, false)
    local od = Orders.tick(ctx, clock.day)
    if od.neu then say("Neue Bestellung von " .. od.neu.kunde .. ".", 150) end
    if #od.verfallen > 0 then say("Eine Bestellung ist verfallen.", 150) end
    local chaos = chaos_text()
    local neu = Fortschritt.neu(clock.day)[1]
    if neu then say(neu, 240)
    elseif chaos then say(chaos, 200)
    elseif ctx.nasse > 0 then say("Es hat geregnet: " .. ctx.nasse .. " Pferd(e) draußen sind schmutzig.", 180)
    end
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
  if a_release then
    -- Nach Auf- oder Absteigen zählt A erst nach dem Loslassen wieder (btnp wiederholt gehaltene Tasten)
    if not btn(BTN_A) then a_release, a_hold = false, 0 end
  elseif p.riding then
    -- Reiten (E3): A antippen = springen, A lange halten = absteigen
    if btn(BTN_A) then
      a_hold = a_hold + 1
      if a_hold == Ride.HOLD then
        local rh = p.riding
        Ride.dismount(ctx)
        a_free, a_release = false, true
        toast = {text = rh.state == "free" and ("Abgestiegen. Deine Leine ist belegt, " .. rh.data.name .. " wartet hier.") or "Abgestiegen.", t = rh.state == "free" and 150 or 60}
      end
    else
      if a_hold > 0 and a_hold < 20 and p.riding then Ride.jump(p) end
      a_hold = 0
    end
  elseif taming then
    -- Zähmen (Rückmeldung 1.2.1): A halten und stillstehen, bis der Balken voll ist
    local h = taming
    local r = wild:tame_step(h, btn(BTN_A))
    if r == "ok" then
      taming, a_release = nil, true
      local how = h.state == "follow" and "gezähmt, folgt dir." or h.state == "led" and "gezähmt, an der Leine."
        or "gezähmt. Deine Leine ist belegt, es wartet hier."
      toast = {text = h.data.name .. " ist " .. how .. " Bring es auf deinen Hof, sonst ist es wieder wild, wenn es sich losreißt.", t = 240}
      ctx.sfx.tame()
      log("ZAEHMEN " .. frame() .. " gezähmt: " .. h.data.name)
    elseif r == "weg" then
      taming = nil
      if h.state == "flee" then say("Es ist davongelaufen.", 90)
      elseif not btn(BTN_A) then say("Zu früh losgelassen. Halte A und bleib still stehen.", 120)
      else say("Abgebrochen: still stehen bleiben.", 90) end
    end
  elseif btnp(BTN_A) then
    a_hold, a_free = 0, false
    local h = wild:tame_target()
    if h then
      if wild:tame_begin(h) then taming = h
      else say("Es hat dich gesehen! Erst A drücken, wenn es wegschaut.", 150) end
    else
      local own = wild:nearest_own()
      local ripe = Farm.ripe_near(ctx)
      local at_rig = Reise.at_trailer(ctx) or Reise.at_station(ctx)
      local geladen, plaetze = Reise.geladen(ctx)
      if at_rig and #ctx.lead > 0 and Reise.trailer_box(ctx) and geladen < plaetze then
        -- Pferd an der Leine zum Anhänger geführt: einladen (Rückmeldung 0.5.8)
        local lh = ctx.lead[1]
        wild:house(lh, "anhaenger")
        ctx.sfx.ok()
        say(lh.data.name .. " steigt in den Anhänger (" .. geladen + 1 .. "/" .. plaetze .. ").")
      elseif at_rig then          -- Fahrzeug hat Vorrang vor dem Pferdemenü (die Pferde stehen immer daneben)
        nav.push(Screens.reise(ctx, function(nr) WorldScene.reise(nr) end))
        ctx.sfx.ok()
      elseif wild:at_stall_door() then
        -- Stall von innen (Rückmeldung 1.2.1): Boxen je nach Größe, Pferde pflegen, holen, einstellen, züchten.
        -- Vor dem Pferdemenü, sonst käme man mit einem Pferd an der Leine nicht hinein.
        nav.push(StallView.new(menu_env(), wild:at_stall_door()))
        ctx.sfx.select()
      elseif own then
        open_menu(own)
        ctx.sfx.select()
      elseif ripe then
        local item, n = Farm.harvest(ctx, ripe, clock.day)
        ctx.sfx.eat()
        say("Geerntet: " .. n .. "x " .. Farm.CROP_NAME[item] .. ".", 120)
      elseif wild:at_bed_door() then
        if clock:sleep() then
          day_banner = t + DAY_BANNER
          Days.new_day(ctx, clock.day)
          Market.refresh(ctx, clock.day)
          ctx.buyer = Buyers.visit(ctx.seed, clock.day)
          Buyers.sync(ctx, false)
          Orders.tick(ctx, clock.day)
          ctx.sfx.dawn()
          ctx.sfx.music("day")
          local saved = WorldScene.save()
          local fohlen = #ctx.geburten > 0 and (" Fohlen geboren: " .. ctx.geburten[1]) or ""
          say("Gut geschlafen." .. fohlen .. (saved and " Gespeichert." or ""), 200)
          local chaos = chaos_text()
          if chaos then say(chaos, 200) end
          local neu = Fortschritt.neu(clock.day)[1]
          if neu then say(neu, 240) end
          ctx.sfx.start()
        else
          say("Noch nicht müde. Ab dem Abend kannst du hier schlafen.", 150)
        end
      elseif ctx.buyer_ent and U.dist(p.x, p.y, ctx.buyer_ent.x, ctx.buyer_ent.y) <= 30 then
        nav.push(Screens.buyer(ctx, function(text) say(text, 150) end))
        ctx.sfx.ok()
      elseif ctx.area.places.jobbrett and U.dist(p.x, p.y, ctx.area.places.jobbrett[1] * 16 + 8, ctx.area.places.jobbrett[2] * 16 + 8) <= 26 then
        nav.push(Screens.jobs(ctx))
        ctx.sfx.ok()
      elseif ctx.area.places.turnier and U.dist(p.x, p.y, ctx.area.places.turnier[1] * 16 + 8, ctx.area.places.turnier[2] * 16 + 8) <= 30 then
        if Fortschritt.offen("turnier", clock.day) then
          nav.push(Screens.turnier(ctx))
          ctx.sfx.ok()
        else
          say("Der Turnierplatz öffnet an Tag " .. Fortschritt.AB.turnier .. ".", 120)
        end
      elseif ctx.area.places.laden and U.dist(p.x, p.y, ctx.area.places.laden[1] * 16 + 8, ctx.area.places.laden[2] * 16 + 8) <= 26 then
        nav.push(Screens.shop(ctx))
        ctx.sfx.ok()
      elseif ctx.area.places.markt and U.dist(p.x, p.y, ctx.area.places.markt[1] * 16 + 8, ctx.area.places.markt[2] * 16 + 8) <= 26 then
        Market.refresh(ctx, clock.day)
        nav.push(Screens.market(ctx))
        ctx.sfx.ok()
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
    local text = ctx.escaped_wild and (ctx.escaped.data.name .. " hat sich losgerissen und ist wieder wild!")
      or (ctx.escaped.data.name .. " ist ausgerissen!")
    toast = {text = text, t = 150}
    ctx.escaped, ctx.escaped_wild = nil, nil
  end
  if toast then
    toast.t = toast.t - 1
    if toast.t <= 0 then toast = nil end
  end
  Reformen.tiere(ctx, clock)
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
  -- Der Tag steht nicht mehr hier (Rückmeldung 1.3.4): groß in der Mitte, wenn er beginnt, und im Pausenmenü
  local icon, f = clock:face()
  ctx.S.draw(icon, 4, 3)
  rectfill(16, 5, 55, 8, C.panel_light)
  rectfill(16, 5, 16 + flr(39 * f), 8, icon == "icon_sun" and C.gold or C.dim)
  local money = ctx.money .. " G"
  print(money, SCREEN_W - textw(money) - 4, 3, C.gold)
  local name = (ctx.on_plot and ctx.on_plot()) and "Dein Hof" or ctx.area.name
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

-- Neuer Tag: „Tag N“ groß in der Mitte, mit Schatten
local function draw_day_banner()
  if not day_banner or t >= day_banner or #stack > 0 then return end
  local C = ctx.colors
  local text = "Tag " .. clock.day
  local old = font(2)
  local x, y = (SCREEN_W - textw(text)) // 2, 84
  for dx = -1, 1 do for dy = -1, 2 do print(text, x + dx, y + dy, C.panel) end end
  print(text, x, y, C.gold)
  font(old)
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
  Stage.draw_world(ctx, draw_rope)
  local p = ctx.player
  Stage.draw_dark(flr(p.x - ctx.camera.x), flr(p.y - 10 - ctx.camera.y), clock:darkness(), WorldScene.light())
  if Wetter.regnet(ctx, clock.day) and not clock:is_night() then Wetter.draw(t) end
  draw_hud()
  draw_day_banner()
  if menu then menu:draw(menu.horse.x - ctx.camera.x, menu.horse.y - ctx.camera.y) end
  if toast then
    -- Meldung: umgebrochen, der Kasten wächst mit; bei offenem Menü oben, damit es das Raster nicht verdeckt
    local C = ctx.colors
    if toast.lines == nil then toast.lines = U.wrap(toast.text, SCREEN_W - 40) end
    local n = #toast.lines
    local w = 0
    for _, l in ipairs(toast.lines) do w = max(w, textw(l)) end
    local h = n * 11 + 14
    local x0 = (SCREEN_W - w) // 2 - 12
    local y0 = (menu or #stack > 0) and 18 or (SCREEN_H - h - 12)
    Stage.panel(x0, y0, SCREEN_W - x0 - 1, y0 + h - 1)
    for i, l in ipairs(toast.lines) do Stage.center(l, y0 + 8 + (i - 1) * 11, C.gold) end
  end
  for i = 1, #stack do stack[i].draw() end
end

return WorldScene
