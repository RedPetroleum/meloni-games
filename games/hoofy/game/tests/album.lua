-- Selbsttests für das Sammelalbum (Aufgabe E5): Eintragen, Zählen, Sichten, Seiten.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Album = require("game.album")
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function setup()
  Area.clear()
  local ctx = Stage.build(1, 71)
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  return ctx
end

return {
  {"Neue Kombinationen werden eingetragen, doppelte nicht; Zähler nach Katalog", function()
    local ctx = setup()
    local d = H.wild({rng = Rng.new(2), rasse = "haflinger"})
    C.ok(Album.eintragen(ctx, d))
    C.ok(not Album.eintragen(ctx, d))
    local n, total = Album.zaehler(ctx)
    C.eq(n, 1)
    local want = 0
    for _, r in ipairs(K.rassen.liste) do want = want + #Album.farben(r.id) end
    C.eq(total, want)
    C.ok(total > 100)
    local n1, t1 = Album.zaehler(ctx, "haflinger")
    C.eq(n1, 1)
    C.eq(t1, #Album.farben("haflinger"))
    C.ok(Album.gefunden(ctx, "haflinger", d.farbe))
    C.ok(not Album.gefunden(ctx, "noriker", d.farbe))
  end},
  {"Jede Wild-Farbe jeder Rasse steht in der Albumliste der Rasse", function()
    local rng = Rng.new(11)
    for _, r in ipairs(K.rassen.liste) do
      local list = {}
      for _, f in ipairs(Album.farben(r.id)) do list[f] = true end
      for _ = 1, 40 do
        local d = H.wild({rng = rng, rasse = r.id, gebiet = 6})
        C.ok(list[d.farbe], r.id .. " " .. tostring(d.farbe))
      end
    end
  end},
  {"Sichten: eigene Pferde immer, Wildpferde nur im Bild", function()
    local ctx = setup()
    local own = ctx.wild:add_own({rasse = "noriker", name = "Eigen"})
    local nah = ctx.wild:spawn_at(ctx.player.x + 40, ctx.player.y, {rasse = "friese", rng = ctx.wild.rng})
    local fern = ctx.wild:spawn_at(ctx.player.x + 2000, ctx.player.y, {rasse = "araber", rng = ctx.wild.rng})
    ctx.camera:snap(ctx.player.x, ctx.player.y)
    local neu = Album.sichten(ctx)
    C.eq(neu, 2, "eigenes und nahes Wildpferd")
    C.ok(Album.gefunden(ctx, "friese", nah.data.farbe))
    C.ok(not Album.gefunden(ctx, "araber", fern.data.farbe))
    C.eq(Album.sichten(ctx), 0, "nichts Neues")
  end},
  {"Album-Bildschirm blättert und zeichnet leer und gefüllt", function()
    local Screens = require("game.screens")
    local ctx = setup()
    local nav = {stack = {}}
    function nav.pop() nav.stack[#nav.stack] = nil end
    local s = Screens.album(ctx)
    nav.stack[1] = s
    local old = btnp
    for _, k in ipairs({BTN_RIGHT, BTN_RIGHT, BTN_DOWN, BTN_LEFT, BTN_UP}) do
      btnp = function(b) return b == k end
      s.update(nav)
      s.draw()
    end
    for _, r in ipairs(K.rassen.liste) do for _, f in ipairs(Album.farben(r.id)) do ctx.album = ctx.album or {} ctx.album[r.id .. ":" .. f] = true end end
    s.draw()
    btnp = function(b) return b == BTN_B end
    s.update(nav)
    btnp = old
    C.eq(#nav.stack, 0)
    local n, total = Album.zaehler(ctx)
    C.eq(n, total)
  end},
}
