-- Selbsttests für die Garderobe im blauen Haus (Wunsch nach 1.6.1): Grafik zu jedem Eintrag, Kaufen,
-- Freischalten, Speichern, Editor.
local Stage = require("game.stage")
local Clock = require("game.clock")
local Save = require("game.save")
local Garderobe = require("game.garderobe")
local Figur = require("game.figur")
local Boutique = require("game.boutique")
local Pos = require("game.figur_pos")
local S = require("sprites")
local C = require("game.tests.check")

local VIEWS = {"down", "down_walk", "up", "up_walk", "side", "side_walk"}

local function ctx_new(money, gebiet)
  local ctx = Stage.build(1)
  ctx.money = money or 0
  ctx.max_gebiet = gebiet or 1
  return ctx
end

-- Drückt im Editor die Tasten: Liste von Tastenmengen je Frame (nil = nichts gedrückt). Ersetzt btn/btnp kurz.
local function press(screen, frames)
  local old_btn, old_btnp = btn, btnp
  local now = {}
  btn = function(b) return now[b] == true end
  btnp = function(b) return now[b] == true end
  local nav = {popped = false}
  function nav.pop() nav.popped = true end
  local ok, err = pcall(function()
    for _, keys in ipairs(frames) do
      now = {}
      for _, k in ipairs(keys) do now[k] = true end
      screen.update(nav)
    end
  end)
  btn, btnp = old_btn, old_btnp
  if not ok then error(err, 0) end
  return nav
end

return {
  {"Jeder Eintrag hat Grafik in jeder Ansicht und Farbe, die Figur hat 5–6 Schichten", function()
    local an = Garderobe.neu().an
    local function check(field, kat_id)
      for _, it in ipairs(Garderobe.kategorie(kat_id).liste) do
        local a = {}
        for k, v in pairs(an) do a[k] = v end
        a[field] = it.id
        for _, v in ipairs(VIEWS) do
          local list = Figur.layers(a, v)
          for _, l in ipairs(list) do C.ok(not l[1] or S.rects[l[1]], "Sprite fehlt: " .. tostring(l[1])) end
          C.ok(#list >= 4, field .. " " .. it.id .. " " .. v .. ": nur " .. #list .. " Schichten")
        end
      end
    end
    for _, k in ipairs(Garderobe.KATEGORIEN) do check(k.id, k.id) end
    -- jede Frisur in jeder Haarfarbe, jedes Oberteil in jeder Farbe, jedes Unterteil in jeder Farbe
    for _, pair in ipairs({{"frisur", "haarfarbe"}, {"oberteil", "ofarbe"}, {"unterteil", "ufarbe"}}) do
      for _, st in ipairs(Garderobe.kategorie(pair[1]).liste) do
        for _, f in ipairs(Garderobe.kategorie(pair[2]).liste) do
          local a = {}
          for k, v in pairs(an) do a[k] = v end
          a[pair[1]], a[pair[2]] = st.id, f.id
          for _, v in ipairs(VIEWS) do
            local list = Figur.layers(a, v)
            C.ok(#list >= 4, "Schichten fehlen: " .. st.id .. " " .. f.id .. " " .. v)
            for _, l in ipairs(list) do C.ok(not l[1] or S.rects[l[1]], "Sprite fehlt: " .. tostring(l[1])) end
          end
        end
      end
    end
    -- Grundausstattung: Körper, Hose, Hemd, Haare; Glatze ohne Hut hat nur den Glanzpunkt
    C.eq(#Figur.layers(an, "down"), 4, "kurz/Hemd/Hose ohne Hut")
    local cape = {}
    for k, v in pairs(an) do cape[k] = v end
    cape.oberteil, cape.hut = "umhang", "krone"
    C.eq(#Figur.layers(cape, "down"), 6, "Umhang dahinter + Krone")
    C.eq(Figur.layers(cape, "down")[1][1], "foben_umhang_down_b", "Umhang zuerst")
    -- Unterteil von hinten: Ansicht von vorn, beim Gehen gespiegelt
    local up = Figur.layers(an, "up_walk")
    C.eq(up[2][1], "funten_hose_down_walk")
    C.ok(up[2][6], "gespiegelt")
  end},
  {"Farben im Katalog gibt es als Sprite-Farbe und umgekehrt", function()
    local n = 0
    for _, k in ipairs(Garderobe.KATEGORIEN) do
      if k.farbe then
        for _, it in ipairs(k.liste) do
          C.ok(Pos.farbe[k.farbe .. "_" .. it.id], "Farbe fehlt in figur.txt: " .. k.farbe .. " " .. it.id)
          n = n + 1
        end
      end
    end
    local m = 0
    for _ in pairs(Pos.farbe) do m = m + 1 end
    C.eq(n, m, "jede Farbe aus figur.txt steht im Katalog")
    C.eq(Garderobe.neu().an.haarfarbe, Pos.basis.fhaar)
    C.eq(Garderobe.neu().an.ofarbe, Pos.basis.foben)
    C.eq(Garderobe.neu().an.ufarbe, Pos.basis.funten)
  end},
  {"Offen ab Gebiet 3; Kaufen kostet, zieht an, gesperrte und zu teure gehen nicht", function()
    local ctx = ctx_new(500, 2)
    C.ok(not Garderobe.offen(ctx), "Gebiet 2: noch zu")
    ctx.max_gebiet = 3
    C.ok(Garderobe.offen(ctx), "Gebiet 3: offen")
    C.ok(Garderobe.besitzt(ctx.outfit, "hut", "ohne"), "kostenlos gehört dazu")
    C.ok(not Garderobe.besitzt(ctx.outfit, "hut", "strohhut"))
    local ok = Garderobe.kaufen(ctx, "hut", "strohhut")
    C.ok(ok)
    C.eq(ctx.money, 440)
    C.eq(ctx.outfit.an.hut, "strohhut", "gleich angezogen")
    C.ok(Garderobe.besitzt(ctx.outfit, "hut", "strohhut"))
    local _, why = Garderobe.kaufen(ctx, "hut", "strohhut")
    C.eq(why, "hat")
    _, why = Garderobe.kaufen(ctx, "hut", "zylinder")
    C.eq(why, "gesperrt", "Zylinder erst ab Gebiet 4")
    ctx.max_gebiet = 6
    _, why = Garderobe.kaufen(ctx, "hut", "einhorn")
    C.eq(why, "geld", "9000 G")
    C.eq(ctx.money, 440)
    -- wilde Sachen: erst ab Gebiet 4 und teurer als alles Normale
    local cheapest_wild, priciest_normal = math.huge, 0
    for _, k in ipairs(Garderobe.KATEGORIEN) do
      for _, it in ipairs(k.liste) do
        if it.ab then cheapest_wild = math.min(cheapest_wild, it.preis) else priciest_normal = math.max(priciest_normal, it.preis) end
        if it.ab then C.ok(it.ab > Garderobe.OFFEN_AB, it.id .. ": ab nach dem Öffnen") end
      end
    end
    C.ok(cheapest_wild > priciest_normal, "wild teurer als normal")
  end},
  {"Prüfen repariert alte oder kaputte Daten", function()
    local o = Garderobe.pruefen(nil)
    C.eq(o.an.frisur, "kurz")
    o = Garderobe.pruefen({an = {frisur = "gibtsnicht", hut = "krone"}, hat = {["hut:krone"] = true}})
    C.eq(o.an.frisur, "kurz")
    C.eq(o.an.hut, "krone")
    C.eq(o.an.oberteil, "hemd")
  end},
  {"Spielstand: Kleidung und Gekauftes bleiben", function()
    local ctx = ctx_new(1000, 3)
    Garderobe.kaufen(ctx, "frisur", "locken")
    Garderobe.kaufen(ctx, "ofarbe", "lila")
    local snap = Save.snapshot(ctx, Clock.new(3, 100), 5)
    local back = load("return " .. Save.encode(snap), "=save", "t", {})()
    local o = Garderobe.pruefen(back.outfit)
    C.eq(o.an.frisur, "locken")
    C.eq(o.an.ofarbe, "lila")
    C.ok(Garderobe.besitzt(o, "frisur", "locken"))
    log("GARDEROBE Spielstand " .. #Save.encode(back.outfit) .. " Zeichen, Lua " .. flr(collectgarbage("count")) .. " KB")
  end},
  {"Editor: Anprobieren, Kaufen, B zieht nicht Gekauftes wieder aus", function()
    local ctx = ctx_new(100, 3)
    local scr = Boutique.new(ctx)
    -- Hut: zweimal rechts = Strohhut (60 G), nur anprobiert
    press(scr, {{BTN_RIGHT}, {}, {BTN_RIGHT}, {}})
    C.eq(scr.probe().hut, "strohhut")
    C.eq(ctx.outfit.an.hut, "ohne", "nicht gekauft: nicht angezogen")
    -- runter zur Haarfarbe, rechts = Dunkelbraun (kostenlos): gleich angezogen
    press(scr, {{BTN_DOWN}, {}, {BTN_RIGHT}, {}})
    C.eq(ctx.outfit.an.haarfarbe, "dunkelbraun")
    -- zurück zum Hut, A kauft den Strohhut
    press(scr, {{BTN_UP}, {}, {BTN_A}, {}})
    C.eq(ctx.money, 40)
    C.eq(ctx.outfit.an.hut, "strohhut")
    -- Frisur Locken (120 G) anprobieren, zu teuer, B: wieder kurz
    press(scr, {{BTN_DOWN}, {}, {BTN_DOWN}, {}})
    for _ = 1, 7 do press(scr, {{BTN_RIGHT}, {}}) end
    C.eq(scr.probe().frisur, "locken")
    press(scr, {{BTN_A}, {}})
    C.eq(ctx.money, 40, "zu wenig Geld")
    local nav = press(scr, {{BTN_B}})
    C.ok(nav.popped)
    C.eq(ctx.outfit.an.frisur, "kurz")
    C.eq(ctx.outfit.an.hut, "strohhut")
  end},
}
