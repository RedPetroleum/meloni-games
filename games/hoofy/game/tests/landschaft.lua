-- Selbsttests für die Landschaft der Gebiete (Rückmeldung 1.5.2, E84): eigenes Aussehen je Gebiet, alles
-- erreichbar, Heimattal unverändert, Furt bremst, Kaktus stößt zurück, Schlucht nur im Sprung, Nebel braucht Licht.
local Gen = require("game.mapgen")
local K = require("game.katalog")
local Stage = require("game.stage")
local Area = require("game.area")
local Gebiet = require("game.gebiet")
local Reise = require("game.reise")
local C = require("game.tests.check")

local byte = string.byte

local function hash(def)
  local h = 0
  for _, rows in ipairs({def.ground, def.deco, def.coll}) do
    for _, r in ipairs(rows) do for i = 1, #r, 3 do h = (h * 31 + byte(r, i)) % 2147483647 end end
  end
  for _, o in ipairs(def.objects) do h = (h * 31 + #o[1] + o[2] * 7 + o[3] * 13) % 2147483647 end
  return h
end

-- Zählt Bodenarten und Objekte einer erzeugten Karte.
local function count(def)
  local n = {}
  for _, r in ipairs(def.ground) do
    for i = 1, #r do local c = r:sub(i, i) n[c] = (n[c] or 0) + 1 end
  end
  for _, o in ipairs(def.objects) do n[o[1]] = (n[o[1]] or 0) + 1 end
  return n
end

-- Sind alle begehbaren Kacheln vom Start aus erreichbar? Gibt erreichbar, begehbar zurück.
local function reach(def)
  local W, H = def.w, def.h
  local function walk(cx, cy)
    if cx < 0 or cy < 0 or cx >= W or cy >= H then return false end
    local g = def.grounds[def.ground[cy + 1]:sub(cx + 1, cx + 1)]
    return not g.solid and def.coll[cy + 1]:sub(cx + 1, cx + 1) == "."
  end
  local total = 0
  for cy = 0, H - 1 do for cx = 0, W - 1 do if walk(cx, cy) then total = total + 1 end end end
  local s = def.places.start
  local seen, stack, n = {[s[2] * W + s[1]] = true}, {s}, 1
  while #stack > 0 do
    local p = table.remove(stack)
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
      local x, y = p[1] + d[1], p[2] + d[2]
      if walk(x, y) and not seen[y * W + x] then
        seen[y * W + x] = true
        n = n + 1
        stack[#stack + 1] = {x, y}
      end
    end
  end
  return n, total
end

return {
  {"Heimattal bleibt Kachel für Kachel gleich (gespeicherte Höfe)", function()
    local want = {[1] = 858152214, [2] = 1466534395, [7] = 2028772318}
    for s, h in pairs(want) do C.eq(hash(Gen.generate(K.welt.gebiete[1], s + 1000)), h, "Seed " .. s) end
  end},
  {"Jedes Gebiet hat seine Landschaft, und alles Begehbare ist erreichbar", function()
    for _, seed in ipairs({1, 2, 3}) do
      local d1 = Gen.generate(K.welt.gebiete[1], seed + 1000)
      local n1 = count(d1)
      local wald1 = n1.F / (d1.w * d1.h)
      for nr = 2, 6 do
        local info = K.welt.gebiete[nr]
        local def = Gen.generate(info, seed + nr * 1000)
        local n = count(def)
        local r, total = reach(def)
        C.eq(r, total, info.name .. " Seed " .. seed .. ": alles erreichbar")
        local wald = (n.F or 0) / (def.w * def.h)
        if nr == 2 then
          C.ok(wald > wald1 + 0.1, "Birkenwald: mehr Wald (" .. string.format("%.2f gegen %.2f", wald, wald1) .. ")")
          C.ok((n.birke or 0) >= 15, "Birken: " .. tostring(n.birke))
        elseif nr == 3 then
          C.ok((n["~"] or 0) > (n1["~"] or 0) * 2, "Flussauen: viel mehr Wasser")
          C.ok((n.f or 0) >= 3, "Furten: " .. tostring(n.f))
          C.eq(n["="] or 0, 0, "keine Brücken, nur Furten")
        elseif nr == 4 then
          C.ok((n.kaktus or 0) >= 40, "Kakteen: " .. tostring(n.kaktus))
          C.eq(n["~"] or 0, 0, "Steppe: kein Wasser, nur ein Trockenbett")
          C.ok(wald < wald1, "Steppe: weniger Wald")
        elseif nr == 5 then
          C.ok((n.c or 0) > 300, "Schluchten: " .. tostring(n.c))
          C.ok((n["="] or 0) + (n.I or 0) >= 2, "Brücken über die Schluchten")
        elseif nr == 6 then
          C.eq(def.ground[1]:sub(def.w // 2, def.w // 2), "~", "Nebelinsel: Meer am Rand")
          C.eq(def.ground[def.h // 2]:sub(1, 1), "~", "Meer auch seitlich")
        end
      end
    end
  end},
  {"Furt bremst, Schlucht nur im Sprung, Kaktus stößt zurück", function()
    Area.clear()
    local ctx = Stage.build(3, 1)
    local map = ctx.map
    local fx, fy
    for cy = 0, map.h - 1 do
      local i = map.ground[cy + 1]:find("f", 1, true)
      if i then fx, fy = i - 1, cy break end
    end
    C.ok(fx, "Furt gefunden")
    C.ok(Gebiet.tempo(map, fx * 16 + 8, fy * 16 + 12) < 0.7, "langsamer in der Furt")
    C.ok(map:walkable(fx, fy), "Furt ist begehbar")

    Area.clear()
    ctx = Stage.build(5, 1)
    map = ctx.map
    local sx, sy
    for cy = 0, map.h - 1 do
      local i = map.ground[cy + 1]:find("c", 1, true)
      if i then sx, sy = i - 1, cy break end
    end
    local x0, y0 = sx * 16 + 4, sy * 16 + 4
    C.ok(map:blocked(x0, y0, x0 + 8, y0 + 4), "Schlucht ist zu Fuß fest")
    C.ok(map:blocked(x0, y0, x0 + 8, y0 + 4, 5), "zu flacher Sprung reicht nicht")
    C.ok(not map:blocked(x0, y0, x0 + 8, y0 + 4, 12), "hoch genug im Sprung: frei")
    C.ok(Gebiet.ueber_schlucht(map, x0, y0 + 4))

    Area.clear()
    ctx = Stage.build(4, 1)
    map = ctx.map
    local kx, ky
    for cy = 0, map.h - 1 do
      local i = map.coll[cy + 1]:find("C", 1, true)
      if i then kx, ky = i - 1, cy break end
    end
    C.ok(kx, "Kaktus gefunden")
    local p = ctx.player
    p.x, p.y = kx * 16 + 8 - 11, ky * 16 + 14           -- links neben dem Kaktus
    local before = p.x
    C.ok(Gebiet.kaktus(p), "piekst")
    C.ok(p.knock_t > 0 and p.kvx < 0, "Rückstoß nach links")
    for _ = 1, 20 do p:update() end
    C.ok(p.x < before - 8, "weggestoßen: " .. string.format("%.1f", before - p.x) .. " px")
    C.ok(not Gebiet.kaktus(p), "weit genug weg")
    Area.clear()
  end},
  {"Nebelinsel nur mit Licht erreichbar", function()
    Area.clear()
    local ctx = Stage.build(1, 12)
    ctx.inv.flugzeug, ctx.money = 1, 100000
    ctx.wild = require("game.wild").new(ctx, 3)
    local function ziel6()
      for _, z in ipairs(Reise.ziele(ctx)) do if z.nr == 6 then return z end end
    end
    C.ok(not ziel6().ok and ziel6().grund:find("Laterne"), "ohne Laterne nicht")
    ctx.inv.laterne = 1
    C.ok(ziel6().ok, "mit Laterne")
    ctx.inv.laterne = 0
    ctx.herd[1] = {lampe = true}
    C.ok(Gebiet.hat_licht(ctx), "Sattellampe reicht auch")
    C.ok(Gebiet.nebel_sicht(1.8) > Gebiet.nebel_sicht(1), "Sattellampe leuchtet weiter")
    Area.clear()
    Stage.build(1, 1)
  end},
}
