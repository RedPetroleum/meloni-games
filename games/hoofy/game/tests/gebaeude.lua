-- Selbsttests für Gebäude (Aufgabe C3): Ställe, Häuschen/Villa, Schuppen/Garage/Hangar.
local Stage = require("game.stage")
local Area = require("game.area")
local Wild = require("game.wild")
local Farm = require("game.farm")
local Days = require("game.days")
local K = require("game.katalog")
local C = require("game.tests.check")

local function setup(money)
  Area.clear()
  local ctx = Stage.build(1, 8)
  ctx.money = money or 100000
  local p = ctx.area.plot
  ctx.player.x, ctx.player.y = (p.x + 10) * 16, (p.y + 9) * 16 + 12
  ctx.wild = Wild.new(ctx, 3)
  ctx.wild.count = 0
  return ctx, p
end

local LAYOUT = {{"hangar", 0, 5}, {"stall_xl", 6, 5}, {"garage", 16, 5}, {"stall_l", 12, 0},
  {"villa", 14, 10}, {"schuppen", 13, 14}, {"haeuschen", 17, 14}, {"stall_m", 0, 17}}

return {
  {"Alle Gebäude lassen sich bauen, Preise nach Katalog, Grundflächen ohne Überlappung", function()
    local ctx, p = setup()
    local total = 0
    for _, b in ipairs(LAYOUT) do
      local ok, why = Farm.place(ctx, b[1], p.x + b[2], p.y + b[3])
      C.ok(ok, b[1] .. ": " .. tostring(why))
      total = total + K.bauteil(b[1]).preis
    end
    C.eq(ctx.money, 100000 - total)
    C.eq(total, 67000, "Hangar 40 000 + Stall XL 6 000 + Garage 8 000 + Stall L 2 500 + Villa 8 000 + Schuppen 600 + Häuschen 1 000 + Stall M 900")
    local second, why = Farm.place(ctx, "garage", p.x + 16, p.y + 5)
    C.ok(not second and why == "schon belegt")
    local ok, why2 = Farm.place(ctx, "hangar", p.x + 17, p.y + 17)
    C.ok(not ok, "Hangar passt nicht mehr: " .. tostring(why2))
  end},
  {"Stallplätze: S 2 + M 4 + L 8 + XL 12, Summe aller Ställe", function()
    local ctx, p = setup()
    C.eq(Farm.capacity(ctx.area.farm).stall, 2, "Stall S am Start")
    Farm.place(ctx, "stall_m", p.x + 0, p.y + 17)
    C.eq(Farm.capacity(ctx.area.farm).stall, 6)
    Farm.place(ctx, "stall_l", p.x + 12, p.y + 0)
    C.eq(Farm.capacity(ctx.area.farm).stall, 14)
    Farm.place(ctx, "stall_xl", p.x + 6, p.y + 5)
    C.eq(Farm.capacity(ctx.area.farm).stall, 26)
    Farm.place(ctx, "stall_s", p.x + 0, p.y + 5)
    C.eq(Farm.capacity(ctx.area.farm).stall, 28, "noch ein Stall S")
    -- Pferde in den Stall: bis zur Summe
    local w = ctx.wild
    local inside = {}
    for i = 1, 30 do
      local h = w:add_own({name = "P" .. i})
      if w:house(h, "stall") then inside[#inside + 1] = h end
    end
    C.eq(#inside, 28)
    -- Stall S abreißen: erst wenn die übrigen alle Stallpferde fassen (E69), dann sinkt die Kapazität
    C.ok(not Farm.remove(ctx, p.x + 0, p.y + 5), "28 Pferde, 26 Plätze")
    w:take_out(inside[1])
    w:take_out(inside[2])
    Farm.remove(ctx, p.x + 0, p.y + 5)
    C.eq(Farm.capacity(ctx.area.farm).stall, 26)
  end},
  {"Stall-Bindung pro Tag: der beste Stall zählt (S 1, M 2, L 3, XL 4)", function()
    local ctx, p = setup()
    local w = ctx.wild
    local h, frei = w:add_own({name = "Drin"}), w:add_own({name = "Draussen"})
    w:house(h, "stall")
    h.data.bindung, frei.data.bindung = 50, 50
    h.data.hunger, frei.data.hunger = 30, 30
    C.eq(Farm.stall_bonus(ctx.area.farm), 1)
    Days.new_day(ctx, 2)
    C.eq(h.data.bindung, 51, "Stall S +1")
    C.eq(frei.data.bindung, 50, "an der Leine nichts")
    Farm.place(ctx, "stall_m", p.x + 0, p.y + 17)
    C.eq(Farm.stall_bonus(ctx.area.farm), 2)
    Farm.place(ctx, "stall_xl", p.x + 6, p.y + 5)
    C.eq(Farm.stall_bonus(ctx.area.farm), 4)
    h.data.bindung, h.data.hunger = 50, 0
    Days.new_day(ctx, 3)
    C.eq(h.data.bindung, 54, "XL +4")
    h.data.bindung, h.data.hunger = 98, 0
    Days.new_day(ctx, 4)
    C.eq(h.data.bindung, 100, "höchstens 100")
  end},
  {"Türen: jeder Stall hat eine, Stalltür-Menü und Schlafen an Wohnwagen, Häuschen und Villa", function()
    local ctx, p = setup()
    C.eq(#Farm.stall_doors(ctx.area.farm), 1)
    Farm.place(ctx, "stall_l", p.x + 12, p.y + 0)
    local doors = Farm.stall_doors(ctx.area.farm)
    C.eq(#doors, 2)
    -- Tür des großen Stalls: Mitte der Unterkante (w = 8 → Spalte 3)
    local found = false
    for _, d in ipairs(doors) do if d.id == "stall_l" and d[1] == p.x + 12 + 3 and d[2] == p.y + 4 then found = true end end
    C.ok(found, "Tür des großen Stalls")
    ctx.player.x, ctx.player.y = (p.x + 15) * 16 + 8, (p.y + 4) * 16 + 8
    C.ok(ctx.wild:at_stall_door(), "vor der neuen Stalltür")
    ctx.player.x, ctx.player.y = (p.x + 1) * 16 + 8, (p.y + 12) * 16 + 8
    C.ok(not ctx.wild:at_stall_door())
    C.eq(#Farm.bed_doors(ctx.area.farm), 1, "nur der Wohnwagen")
    Farm.place(ctx, "haeuschen", p.x + 17, p.y + 14)
    Farm.place(ctx, "villa", p.x + 14, p.y + 10)
    C.eq(#Farm.bed_doors(ctx.area.farm), 3)
    ctx.player.x, ctx.player.y = (p.x + 18) * 16 + 8, (p.y + 16) * 16 + 8
    C.ok(ctx.wild:at_bed_door(), "vor der Haustür")
  end},
  {"Unterstellen: Schuppen Fahrrad + Mofa, Garage Kleinwagen + SUV, Hangar Flugzeug", function()
    local ctx, p = setup()
    local g = Farm.garaged(ctx.area.farm)
    C.ok(not (g.fahrrad or g.mofa or g.kleinwagen or g.suv or g.flugzeug), "am Start nichts")
    Farm.place(ctx, "schuppen", p.x + 13, p.y + 14)
    g = Farm.garaged(ctx.area.farm)
    C.ok(g.fahrrad and g.mofa and not g.kleinwagen)
    Farm.place(ctx, "garage", p.x + 16, p.y + 5)
    g = Farm.garaged(ctx.area.farm)
    C.ok(g.kleinwagen and g.suv and not g.flugzeug)
    Farm.place(ctx, "hangar", p.x + 0, p.y + 5)
    g = Farm.garaged(ctx.area.farm)
    C.ok(g.flugzeug)
    Farm.remove(ctx, p.x + 13, p.y + 14)
    g = Farm.garaged(ctx.area.farm)
    C.ok(not g.fahrrad, "Schuppen abgerissen")
  end},
  {"Schönheit: Häuschen +20, Villa +100, Hof-Summe; Abreißen erstattet den vollen Preis", function()
    local ctx, p = setup()
    local start = ctx.money
    Farm.place(ctx, "haeuschen", p.x + 17, p.y + 14)
    C.eq(Farm.schoenheit(ctx.area.farm), 20)
    Farm.place(ctx, "villa", p.x + 14, p.y + 10)
    C.eq(Farm.schoenheit(ctx.area.farm), 120)
    Farm.place(ctx, "bank", p.x + 10, p.y + 7)
    C.eq(Farm.schoenheit(ctx.area.farm), 123)
    C.eq(Farm.remove(ctx, p.x + 15, p.y + 11), 8000, "Villa zurück")
    C.eq(Farm.remove(ctx, p.x + 18, p.y + 15), 1000, "Häuschen zurück")
    Farm.remove(ctx, p.x + 10, p.y + 7)
    C.eq(ctx.money, start)
    C.eq(Farm.schoenheit(ctx.area.farm), 0)
  end},
  {"Abreißen: Haus und Stall nur mit einem zweiten, Startbauten bringen nichts zurück (E69)", function()
    local ctx, p = setup()
    local farm = ctx.area.farm
    local sum, why = Farm.remove(ctx, p.x + 3, p.y + 3)
    C.ok(not sum and why == "erst ein zweites Haus bauen", "Wohnwagen allein: " .. tostring(why))
    sum, why = Farm.remove(ctx, p.x + 9, p.y + 3)
    C.ok(not sum and why == "erst einen zweiten Stall bauen", "Stall S allein: " .. tostring(why))
    Farm.place(ctx, "haeuschen", p.x + 17, p.y + 14)
    local money = ctx.money
    C.eq(Farm.remove(ctx, p.x + 3, p.y + 3), 0, "Wohnwagen weg, nichts zurück")
    C.eq(ctx.money, money)
    C.ok(ctx.map:walkable(p.x + 3, p.y + 3), "Platz frei")
    C.eq(#Farm.bed_doors(farm), 1, "Häuschen bleibt")
    sum, why = Farm.remove(ctx, p.x + 18, p.y + 15)
    C.ok(not sum and why == "erst ein zweites Haus bauen", "Häuschen jetzt allein")
    -- Ställe: die übrigen müssen alle Stallpferde fassen
    Farm.place(ctx, "stall_m", p.x + 0, p.y + 17)
    local w = ctx.wild
    for i = 1, 3 do w:house(w:add_own({name = "S" .. i}), "stall") end
    sum, why = Farm.remove(ctx, p.x + 1, p.y + 18)
    C.ok(not sum and why == "erst Pferde aus dem Stall holen", "Stall M: " .. tostring(why))
    C.eq(Farm.remove(ctx, p.x + 9, p.y + 3), 0, "Stall S weg")
    C.eq(Farm.capacity(farm).stall, 4)
    C.ok(Farm.stall_door(farm), "Stalltür am Stall M")
  end},
  {"Abreißen: Garage nur mit einer zweiten, und das Fahrzeug muss woanders unterkommen (E69)", function()
    local ctx, p = setup()
    Farm.place(ctx, "schuppen", p.x + 13, p.y + 14)
    local sum, why = Farm.remove(ctx, p.x + 13, p.y + 14)
    C.ok(not sum and why == "erst eine zweite Garage bauen", "Schuppen allein: " .. tostring(why))
    Farm.place(ctx, "garage", p.x + 16, p.y + 5)
    ctx.inv.mofa = 1
    sum, why = Farm.remove(ctx, p.x + 13, p.y + 14)
    C.ok(not sum and why == "Mofa braucht sie", "Mofa: " .. tostring(why))
    C.eq(Farm.remove(ctx, p.x + 16, p.y + 5), 8000, "Garage zurück")
    Farm.place(ctx, "garage", p.x + 16, p.y + 5)
    Farm.place(ctx, "schuppen", p.x + 0, p.y + 5)
    C.eq(Farm.remove(ctx, p.x + 13, p.y + 14), 200, "zweiter Schuppen nimmt das Mofa")
  end},
  {"Spielstand ohne Wohnwagen: Hof lädt, Schlafen am Häuschen (E69)", function()
    local Save = require("game.save")
    local Clock = require("game.clock")
    local ctx, p = setup()
    Farm.place(ctx, "haeuschen", p.x + 17, p.y + 14)
    Farm.place(ctx, "stall_m", p.x + 0, p.y + 17)
    Farm.remove(ctx, p.x + 3, p.y + 3)
    Farm.remove(ctx, p.x + 9, p.y + 3)
    local back = load("return " .. Save.encode(Save.snapshot(ctx, Clock.new(1, 0), 8)), "=x", "t", {})()
    Area.clear()
    local ctx2 = Stage.build(1, 8, back.hof)
    C.eq(#ctx2.area.farm.buildings, 0, "keine Startbauten mehr")
    C.ok(ctx2.map:walkable(p.x + 3, p.y + 3) and ctx2.map:walkable(p.x + 9, p.y + 3), "Plätze frei")
    C.eq(ctx2.area.places.bett[1], p.x + 18, "Bett am Häuschen")
    C.eq(Farm.capacity(ctx2.area.farm).stall, 4)
  end},
  {"Spielstand: Gebäude bleiben und werden neu aufgebaut", function()
    local Save = require("game.save")
    local Clock = require("game.clock")
    local ctx, p = setup()
    for _, b in ipairs(LAYOUT) do Farm.place(ctx, b[1], p.x + b[2], p.y + b[3]) end
    local snap = Save.snapshot(ctx, Clock.new(1, 0), 8)
    local text = Save.encode(snap)
    local back = load("return " .. text, "=x", "t", {})()
    Area.clear()
    local ctx2 = Stage.build(1, 8, back.hof)
    C.eq(Farm.capacity(ctx2.area.farm).stall, 2 + 12 + 8 + 4)
    C.ok(Farm.garaged(ctx2.area.farm).flugzeug)
    C.ok(not ctx2.map:walkable(p.x + 1, p.y + 6), "Hangar im Weg")
    log("GEBAEUDE Spielstand mit 8 Gebäuden: " .. #text .. " Bytes")
  end},
}
