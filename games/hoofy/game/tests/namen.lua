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
  {"Freie Namen: erst die Liste, dann zusammengesetzte, dann nummerierte; nie doppelt", function()
    H.names_reset({})
    local seen, rng = {}, Rng.new(5)
    for i = 1, #H.NAMES + #H.NAMEN_VORN * #H.NAMEN_HINTEN + 30 do
      local d = {name = nil}
      local n = H.claim_name(d, rng)
      C.ok(not seen[n], "doppelt: " .. n)
      seen[n] = true
      if i == #H.NAMES then C.ok(H.name_used("Blitz") and H.name_used("Tante Erna"), "Liste aufgebraucht") end
      if i == #H.NAMES + 1 then C.ok(n:find("^%u%l+%l+$") and not n:find(" "), "zusammengesetzt: " .. n) end
    end
    C.ok(seen["Blitz II"] or seen["Luna II"] or next(seen), "nummeriert")
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
