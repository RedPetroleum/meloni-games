-- Selbsttests für Pferdenamen (Rückmeldung 1.3.1): kein neues Pferd heißt wie eins, das es schon gab.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Days = require("game.days")
local Breeding = require("game.breeding")
local Market = require("game.market")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

return {
  {"Freie Namen: erst die Liste, dann zusammengesetzte, dann nummerierte; nie doppelt, immer passend zum Geschlecht", function()
    for _, sex in ipairs({"w", "m"}) do
      H.names_reset({})
      local seen, rng = {}, Rng.new(5)
      local list = H.names_for(sex)
      local ends = sex == "w" and H.NAMEN_HINTEN_W or H.NAMEN_HINTEN_M
      local other = {}
      for _, n in ipairs(sex == "w" and H.NAMES_M or H.NAMES_W) do other[n] = true end
      local in_list = {}
      for _, n in ipairs(list) do in_list[n] = true end
      for i = 1, #list + #H.NAMEN_VORN * #ends + 30 do
        local n = H.claim_name({sex = sex}, rng)
        C.ok(not seen[n], "doppelt: " .. n)
        seen[n] = true
        C.ok(not other[n:gsub(" [IVX]+$", "")], "falsches Geschlecht: " .. n)
        if i == #list then C.ok(H.name_used(list[1]) and H.name_used(list[#list]), "Liste aufgebraucht") end
        if i == #list + 1 then
          local fits = false
          for _, e in ipairs(ends) do if n:sub(-#e) == e then fits = true end end
          C.ok(not n:find(" ") and not in_list[n] and fits, "zusammengesetzt: " .. n)
        end
      end
      C.ok(seen[list[1] .. " II"] or next(seen), "nummeriert")
    end
    H.names_reset({})
  end},
  {"Wildpferde, Fohlen und Tauschpferde heißen passend zum Geschlecht; Texte passen sich an", function()
    H.names_reset({})
    local rng = Rng.new(3)
    for i = 1, 200 do
      local d = H.wild({rng = rng})
      C.ok(H.name_fits(d.name, d.sex), d.sex .. ": " .. d.name)
    end
    C.ok(not H.name_fits("Luna", "m") and not H.name_fits("Horst", "w") and H.name_fits("Keks", "m") and H.name_fits("Keks", "w"))
    -- Marktpferd aus älterem Spielstand mit unpassendem Namen bekommt beim Kauf einen passenden
    local d = {name = "Luna", sex = "m"}
    H.claim_name(d, rng)
    C.ok(d.name ~= "Luna" and H.name_fits(d.name, "m"), d.name)
    C.eq(H.gtext({sex = "w", alter = 1}, "{Die|Der} ist scheu, bring {sie|ihn} her."), "Die ist scheu, bring sie her.")
    C.eq(H.gtext({sex = "m", alter = 1}, "{Die|Der} ist scheu, bring {sie|ihn} her."), "Der ist scheu, bring ihn her.")
    C.eq(H.gtext({sex = "m", alter = 0.5}, "{die Stute|der Hengst|das Fohlen}, {sie|er}"), "das Fohlen, er")
    C.eq(require("game.orders").text({farbe = "brauner", sex = "m", stat = "tempo", min = 50, frist = 20}):match("^%S+ %S+"), "Brauner Hengst,")
    H.names_reset({})
  end},
  {"Wildpferd heißt nie wie ein früheres, Zähmen belegt den Namen, Spielstand merkt sich die Liste", function()
    Area.clear()
    local ctx = Stage.build(1, 5)
    ctx.clock = {day = 1}
    local w = Wild.new(ctx, 3)
    w.count = 0
    H.names_reset({})
    for _, n in ipairs(H.NAMES) do if n ~= "Momo" then H.reserve_name(n) end end
    local h = w:spawn_at(ctx.player.x + 20, ctx.player.y, {rng = Rng.new(9)})
    C.eq(h.data.name, "Momo", "der einzige freie Name")
    w:tame(h)
    C.ok(H.name_used("Momo"), "belegt")
    local h2 = w:spawn_at(ctx.player.x + 40, ctx.player.y, {rng = Rng.new(9)})
    C.ok(h2.data.name ~= "Momo", "nicht noch einmal: " .. h2.data.name)
    -- verkauft oder nicht: Name bleibt belegt, und er steht im Spielstand
    local snap = require("game.save").snapshot(ctx, require("game.clock").new(1, 0), 5)
    local found = false
    for _, n in ipairs(snap.namen) do if n == "Momo" then found = true end end
    C.ok(found, "namen im Spielstand")
    H.names_reset({})
  end},
  {"Fohlen und Marktpferde bekommen beim Einzug einen unbenutzten Namen", function()
    Area.clear()
    local ctx = Stage.build(1, 5)
    ctx.clock = {day = 10}
    local w = Wild.new(ctx, 3)
    w.count = 0
    H.names_reset({})
    local m = w:add_own({rasse = "haflinger", name = "Mutter"})
    local f = w:add_own({rasse = "haflinger", name = "Vater"})
    m.data.sex, f.data.sex, m.data.alter, f.data.alter = "w", "m", 1, 1
    w:house(m, "stall", true)
    w:house(f, "stall", true)
    Breeding.start(ctx, f.data, m.data, 10)
    for _, n in ipairs(H.NAMES) do H.reserve_name(n) end   -- alle einfachen Namen schon vergeben
    Days.new_day(ctx, 12)
    local foal = ctx.herd[#ctx.herd]
    C.ok(not foal.name:find(" ") and foal.name ~= "Mutter", "Fohlen mit neuem Namen: " .. foal.name)
    C.ok(H.name_used(foal.name))
    ctx.money = 100000
    ctx.market = {cycle = 0, horses = {{name = "Blitz", alter = 1, preis = 10, rasse = "haflinger", sex = "m", zug = "faul",
      farbe = "fuchs", farbe2 = "fuchs", gen = {tempo = 1, staerke = 1, spuer = 1, ausdauer = 50}, train = {tempo = 0, staerke = 0,
      spuer = 0, ausdauer = 0}, pot = {tempo = 1, staerke = 1, spuer = 1, ausdauer = 50}, bindung = 50, hunger = 0, gewicht = 50,
      sauberkeit = 50, energie = 50}}}
    local ok, h = Market.buy(ctx, 1)
    C.ok(ok)
    C.ok(h.data.name ~= "Blitz", "gekauftes Pferd umbenannt: " .. h.data.name)
    H.names_reset({})
  end},
}
