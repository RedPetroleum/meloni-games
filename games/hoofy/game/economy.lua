-- Geld und Laden (KATALOG §7, §8, §9): Warenliste, Kaufen, Bauelemente zum Kaufpreis zurück,
-- Ausrüstung am Pferd. Alles auf ctx.money und ctx.inv (Vorrat, id → Anzahl).
local K = require("game.katalog")
local Farm = require("game.farm")

local E = {}

E.CATEGORIES = {
  {id = "futter", name = "Futter"},
  {id = "saettel", name = "Sättel"},
  {id = "zubehoer", name = "Zubehör"},
  {id = "schmuck", name = "Schmuck"},
  {id = "samen", name = "Samen"},
  {id = "fahrzeuge", name = "Fahrzeuge"},
}

local function item(cat, e, extra)
  local it = {id = e.id, name = e.name, preis = e.preis, text = e.text, kat = cat, einmalig = e.einmalig}
  for k, v in pairs(extra or {}) do it[k] = v end
  return it
end

-- Alle Waren im Laden eines Gebiets-Standes: maxgebiet = weitester erreichbarer Gebietsindex
-- (bestimmt, welche Samen es gibt).
function E.catalog(maxgebiet)
  local list = {}
  for _, f in ipairs(K.futter.kaufen) do list[#list + 1] = item("futter", f) end
  for _, a in ipairs(K.ausruestung.liste) do
    local cat
    if a.sattel and a.id ~= "sattellampe" then cat = "saettel"
    elseif a.id:find("^satteltaschen") or a.id == "sattellampe" then cat = "zubehoer"
    else cat = "schmuck" end
    list[#list + 1] = item(cat, a)
  end
  for _, p in ipairs(K.futter.anbau) do
    if p.gebiet <= (maxgebiet or 1) then
      list[#list + 1] = {id = "samen_" .. p.id, name = "Samen: " .. p.name, preis = p.samen, text = p.text,
        kat = "samen", einmalig = true, pflanze = p.id}
    end
  end
  -- Fahrzeuge (D1): Zugfahrzeuge brauchen Schuppen/Garage/Hangar, Anhänger nicht
  for _, f in ipairs(K.welt.fahrzeuge) do
    if f.preis > 0 then
      list[#list + 1] = {id = f.id, name = f.name, preis = f.preis, kat = "fahrzeuge", einmalig = true, fahrzeug = f,
        text = "Erreicht Gebiet 1–" .. f.gebiete .. ", Fahrtkosten " .. f.fahrtkosten .. " je Gebiet Entfernung."}
    end
  end
  for _, a in ipairs(K.welt.anhaenger) do
    list[#list + 1] = {id = "anhaenger_" .. a.plaetze, name = "Anhänger " .. a.plaetze .. " Platz" .. (a.plaetze > 1 and "e" or ""),
      preis = a.preis, kat = "fahrzeuge", einmalig = true, anhaenger = a.plaetze,
      text = "Nimmt " .. a.plaetze .. " Pferd" .. (a.plaetze > 1 and "e" or "") .. " mit auf die Reise."}
  end
  return list
end

-- Bestes Zugfahrzeug im Besitz (Eintrag aus K.welt.fahrzeuge, "zu Fuß" ohne) und Plätze des besten Anhängers.
function E.fahrzeug(ctx)
  local best = K.welt.fahrzeuge[1]
  for _, f in ipairs(K.welt.fahrzeuge) do
    if f.preis > 0 and (ctx.inv[f.id] or 0) > 0 and f.gebiete > best.gebiete then best = f end
  end
  return best
end

function E.plaetze(ctx)
  local n = 0
  for _, a in ipairs(K.welt.anhaenger) do
    if (ctx.inv["anhaenger_" .. a.plaetze] or 0) > 0 then n = math.max(n, a.plaetze) end
  end
  return n
end

-- Das weiteste erreichbare Gebiet nach dem Fahrzeug im Besitz.
function E.refresh_gebiet(ctx)
  ctx.max_gebiet = E.fahrzeug(ctx).gebiete
  return ctx.max_gebiet
end

function E.find(id, maxgebiet)
  for _, it in ipairs(E.catalog(maxgebiet or 6)) do if it.id == id then return it end end
  error("unbekannte Ware " .. tostring(id))
end

-- Preis mit Aufschlag (Hafersteuer: Futter +50 %, KATALOG §14): ctx.futter_aufschlag in Prozent.
function E.price(ctx, it)
  local p = it.preis
  if it.kat == "futter" and (ctx.futter_aufschlag or 0) > 0 then p = math.ceil(p * (1 + ctx.futter_aufschlag / 100)) end
  return p
end

function E.owned(ctx, id)
  return ctx.inv[id] or 0
end

-- Kaufen: 1 Stück. Gibt true oder false, Grund ("Geld", "schon da") zurück.
function E.buy(ctx, id)
  local it = E.find(id)
  if it.einmalig and E.owned(ctx, id) > 0 then return false, "schon da" end
  if it.fahrzeug then
    local farm = ctx.hof or ctx.area and ctx.area.farm
    if not (farm and Farm.garaged(farm)[id]) then return false, "Garage" end
  end
  local p = E.price(ctx, it)
  if ctx.money < p then return false, "Geld" end
  ctx.money = ctx.money - p
  ctx.inv[id] = E.owned(ctx, id) + 1
  if it.fahrzeug then E.refresh_gebiet(ctx) end
  return true
end

-- Hat der Spieler die Pflanze schon (Samen einmal gekauft oder gefunden)?
function E.has_seed(ctx, pflanze)
  return E.owned(ctx, "samen_" .. pflanze) > 0
end

-- Bauelement verkaufen: zum Kaufpreis zurück (KATALOG §9). id aus K.bau.liste, count Stück.
function E.refund_building(ctx, id, count)
  local b = K.bauteil(id)
  local sum = b.preis * (count or 1)
  ctx.money = ctx.money + sum
  return sum
end

-- Bauelement kaufen (Baumodus C1): bei zu wenig Geld false.
function E.buy_building(ctx, id, count)
  local b = K.bauteil(id)
  local sum = b.preis * (count or 1)
  if ctx.money < sum then return false, "Geld" end
  ctx.money = ctx.money - sum
  return true
end

-- Fund oder Gegenstand verkaufen, der einen Wert hat (z. B. Goldhufeisen 200, KATALOG §11).
function E.sell_find(ctx, wert, count)
  ctx.money = ctx.money + wert * (count or 1)
end

-- ---- Ausrüstung am Pferd ----

E.SLOTS = {
  sattel = {"einfacher_sattel", "sportsattel", "rennsattel", "goldsattel"},
  taschen = {"satteltaschen_s", "satteltaschen_m", "satteltaschen_l"},
}
E.JEWELRY = {"maehnenschleife", "blumenkranz", "glitzerdecke", "goldhufeisen"}

-- Rüstet id am Pferd (data) aus dem Vorrat aus und gibt das alte Stück zurück in den Vorrat.
-- Gibt true oder false, Grund zurück. Sättel: einer; Taschen: nur mit Sattel; Lampe und Schmuck: je einmal.
function E.equip(ctx, data, id)
  local function inv(i, d) ctx.inv[i] = (ctx.inv[i] or 0) + d end
  if (ctx.inv[id] or 0) < 1 then return false, "nicht im Vorrat" end
  for slot, ids in pairs(E.SLOTS) do
    for _, s in ipairs(ids) do
      if s == id then
        if slot == "taschen" and not data.sattel then return false, "braucht einen Sattel" end
        if data[slot] then inv(data[slot], 1) end
        data[slot] = id
        inv(id, -1)
        return true
      end
    end
  end
  if id == "sattellampe" then
    if data.lampe then return false, "schon an" end
    data.lampe = true
    inv(id, -1)
    return true
  end
  for _, j in ipairs(E.JEWELRY) do
    if j == id then
      data.schmuck = data.schmuck or {}
      if data.schmuck[id] then return false, "schon an" end
      data.schmuck[id] = true
      inv(id, -1)
      return true
    end
  end
  return false, "unbekannt"
end

-- Legt ein Stück ab (zurück in den Vorrat). Ohne Sattel verlieren die Taschen keinen Platz: sie
-- gehen mit ab.
function E.unequip(ctx, data, id)
  local function inv(i, d) ctx.inv[i] = (ctx.inv[i] or 0) + d end
  if data.sattel == id then
    data.sattel = nil
    inv(id, 1)
    if data.taschen then inv(data.taschen, 1); data.taschen = nil end
    return true
  end
  if data.taschen == id then data.taschen = nil inv(id, 1) return true end
  if id == "sattellampe" and data.lampe then data.lampe = nil inv(id, 1) return true end
  if data.schmuck and data.schmuck[id] then data.schmuck[id] = nil inv(id, 1) return true end
  return false
end

-- Plätze für Fundstücke in den Satteltaschen (KATALOG §8: S/M/L = 1/2/4).
function E.tasche_plaetze(data)
  if not data.taschen then return 0 end
  for _, a in ipairs(K.ausruestung.liste) do if a.id == data.taschen then return a.plaetze end end
  return 0
end

-- Schönheit aus Schmuck und Sattel (Goldsattel +20) für Wettbewerbe (E1) und den Hof.
function E.schoenheit(data)
  local sum = 0
  for _, a in ipairs(K.ausruestung.liste) do
    local worn = a.id == data.sattel or (data.schmuck and data.schmuck[a.id])
    if worn then sum = sum + (a.wirkung.schoenheit or 0) end
  end
  return sum
end

return E
