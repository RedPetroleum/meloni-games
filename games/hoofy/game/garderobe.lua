-- Garderobe im blauen Haus im Dorf („Mähne & Masche“, Wunsch nach 1.6.1): Hut, Haarfarbe, Frisur, Oberteil
-- und Unterteil mit Farben wählen und kaufen. Öffnet, sobald Gebiet OFFEN_AB erreichbar ist (Mofa); davor steht
-- ein Schild vor der Tür. Wilde Sachen gibt es erst ab einem weiteren Gebiet und sie kosten viel.
-- Die Grafik dazu: figur.txt (Schichten), game/figur.lua (Zeichnen).
local K = require("game.katalog")
local Pos = require("game.figur_pos")

local G = {}

G.OFFEN_AB = 3

-- Kategorien in der Reihenfolge des Editors. art: Sprite-Art der Stile, farbe: Art, deren Farbe gewählt wird.
-- Einträge: id, Name, Preis (0 = hat man von Anfang an), ab = erst ab diesem Gebiet kaufbar.
-- Frisuren: hut = so viele Pixel sitzt ein Hut höher (große Haare).
G.KATEGORIEN = {
  {id = "hut", name = "Hut", art = "fhut", liste = {
    {id = "ohne", name = "Kein Hut", preis = 0},
    {id = "kappe", name = "Schirmmütze", preis = 40},
    {id = "strohhut", name = "Strohhut", preis = 60},
    {id = "bommel", name = "Bommelmütze", preis = 80},
    {id = "blumen", name = "Blumenkranz", preis = 120},
    {id = "cowboy", name = "Cowboyhut", preis = 150},
    {id = "reithelm", name = "Reithelm", preis = 200},
    {id = "zylinder", name = "Zylinder", preis = 900, ab = 4},
    {id = "krone", name = "Krone", preis = 5000, ab = 5},
    {id = "einhorn", name = "Einhorn-Horn", preis = 9000, ab = 6},
  }},
  {id = "haarfarbe", name = "Haarfarbe", farbe = "fhaar", liste = {
    {id = "braun", name = "Braun", preis = 0},
    {id = "dunkelbraun", name = "Dunkelbraun", preis = 0},
    {id = "schwarz", name = "Schwarz", preis = 0},
    {id = "blond", name = "Blond", preis = 0},
    {id = "platin", name = "Platinblond", preis = 30},
    {id = "rot", name = "Rot", preis = 30},
    {id = "grau", name = "Silbergrau", preis = 30},
    {id = "rosa", name = "Rosa", preis = 400, ab = 4},
    {id = "blau", name = "Blau", preis = 400, ab = 4},
    {id = "gruen", name = "Grün", preis = 900, ab = 5},
    {id = "lila", name = "Lila", preis = 900, ab = 5},
    {id = "feuer", name = "Feuerrot", preis = 3000, ab = 6},
    {id = "gold", name = "Gold", preis = 5000, ab = 6},
  }},
  {id = "frisur", name = "Frisur", art = "fhaar", liste = {
    {id = "kurz", name = "Kurz", preis = 0},
    {id = "glatze", name = "Glatze", preis = 30},
    {id = "igel", name = "Igel", preis = 40, hut = 1},
    {id = "dutt", name = "Dutt", preis = 60},
    {id = "lang", name = "Lang", preis = 60},
    {id = "zopf", name = "Pferdeschwanz", preis = 80},
    {id = "zoepfe", name = "Zöpfe", preis = 80},
    {id = "locken", name = "Locken", preis = 120, hut = 2},
    {id = "tolle", name = "Tolle", preis = 250, hut = 1},
    {id = "irokese", name = "Irokese", preis = 700, ab = 4},
    {id = "maehne", name = "Löwenmähne", preis = 3000, ab = 5, hut = 3},
  }},
  {id = "oberteil", name = "Oberteil", art = "foben", liste = {
    {id = "hemd", name = "Hemd", preis = 0},
    {id = "tanktop", name = "Tanktop", preis = 20},
    {id = "ringel", name = "Ringelshirt", preis = 50},
    {id = "kapuze", name = "Kapuzenpulli", preis = 90},
    {id = "reitjacke", name = "Reitjacke", preis = 150},
    {id = "hawaii", name = "Hawaiihemd", preis = 250},
    {id = "frack", name = "Frack", preis = 1500, ab = 4},
    {id = "umhang", name = "Heldenumhang", preis = 4000, ab = 5},
    {id = "ruestung", name = "Ritterrüstung", preis = 12000, ab = 6},
  }},
  {id = "ofarbe", name = "Farbe Oberteil", farbe = "foben", liste = {
    {id = "blau", name = "Blau", preis = 0},
    {id = "rot", name = "Rot", preis = 0},
    {id = "gruen", name = "Grün", preis = 0},
    {id = "gelb", name = "Gelb", preis = 0},
    {id = "weiss", name = "Weiß", preis = 20},
    {id = "schwarz", name = "Schwarz", preis = 20},
    {id = "braun", name = "Braun", preis = 20},
    {id = "orange", name = "Orange", preis = 30},
    {id = "rosa", name = "Rosa", preis = 30},
    {id = "lila", name = "Lila", preis = 30},
    {id = "tuerkis", name = "Türkis", preis = 30},
    {id = "neon", name = "Neongrün", preis = 600, ab = 4},
    {id = "gold", name = "Gold", preis = 2500, ab = 5},
  }},
  {id = "unterteil", name = "Unterteil", art = "funten", liste = {
    {id = "hose", name = "Hose", preis = 0},
    {id = "shorts", name = "Shorts", preis = 30},
    {id = "rock", name = "Rock", preis = 40},
    {id = "reithose", name = "Reithose", preis = 120},
    {id = "pluder", name = "Pluderhose", preis = 700, ab = 4},
    {id = "tutu", name = "Tutu", preis = 2000, ab = 5},
  }},
  {id = "ufarbe", name = "Farbe Unterteil", farbe = "funten", liste = {
    {id = "braun", name = "Braun", preis = 0},
    {id = "jeans", name = "Jeansblau", preis = 0},
    {id = "schwarz", name = "Schwarz", preis = 0},
    {id = "beige", name = "Beige", preis = 0},
    {id = "grau", name = "Grau", preis = 20},
    {id = "oliv", name = "Oliv", preis = 20},
    {id = "rot", name = "Rot", preis = 30},
    {id = "weiss", name = "Weiß", preis = 30},
    {id = "pink", name = "Pink", preis = 500, ab = 4},
    {id = "gold", name = "Gold", preis = 2500, ab = 5},
  }},
}

local BY_ID = {}
for _, kat in ipairs(G.KATEGORIEN) do
  BY_ID[kat.id] = kat
  kat.index = {}
  for i, it in ipairs(kat.liste) do kat.index[it.id] = i end
end

function G.kategorie(id) return BY_ID[id] end

function G.eintrag(kat_id, id)
  local kat = BY_ID[kat_id]
  return kat.liste[kat.index[id] or 1]
end

-- Was man am Anfang trägt (sieht aus wie die alte Figur player_down).
function G.neu()
  return {an = {hut = "ohne", haarfarbe = "braun", frisur = "kurz", oberteil = "hemd", ofarbe = "blau",
    unterteil = "hose", ufarbe = "braun"}, hat = {}}
end

-- Ergänzt fehlende oder unbekannte Felder (ältere Spielstände, Katalog geändert).
function G.pruefen(o)
  if type(o) ~= "table" then return G.neu() end
  o.an, o.hat = type(o.an) == "table" and o.an or {}, type(o.hat) == "table" and o.hat or {}
  local d = G.neu().an
  for k, v in pairs(d) do
    if not (BY_ID[k].index[o.an[k]]) then o.an[k] = v end
  end
  return o
end

-- Gehört der Eintrag schon dazu? Kostenlose immer.
function G.besitzt(o, kat_id, id)
  local it = G.eintrag(kat_id, id)
  return it.preis == 0 or o.hat[kat_id .. ":" .. id] == true
end

-- Hat der Laden auf? (ctx.max_gebiet = weitestes erreichbares Gebiet)
function G.offen(ctx)
  return (ctx.max_gebiet or 1) >= G.OFFEN_AB
end

-- Ist der Eintrag schon freigeschaltet?
function G.frei(ctx, it)
  return (ctx.max_gebiet or 1) >= (it.ab or 1)
end

function G.gebiet_name(nr)
  local g = K.welt.gebiete[nr]
  return g and g.name or ("Gebiet " .. nr)
end

-- Kaufen: true oder false, Grund ("hat", "gesperrt", "geld"). Gekauftes wird gleich angezogen.
function G.kaufen(ctx, kat_id, id)
  local o = ctx.outfit
  local it = G.eintrag(kat_id, id)
  if G.besitzt(o, kat_id, id) then return false, "hat" end
  if not G.frei(ctx, it) then return false, "gesperrt" end
  if ctx.money < it.preis then return false, "geld" end
  ctx.money = ctx.money - it.preis
  o.hat[kat_id .. ":" .. id] = true
  o.an[kat_id] = id
  return true
end

-- Musterfarbe einer Farbvariante (rgb-Wert) für Farbfelder im Editor, nil für Stile.
function G.farbe(kat_id, id)
  local kat = BY_ID[kat_id]
  if not kat.farbe then return nil end
  local c = Pos.farbe[kat.farbe .. "_" .. id]      -- "Ld9b04a…": erstes Zeichen mit RRGGBB ist die Musterfarbe
  if not c then return nil end
  local v = tonumber(c:sub(2, 7), 16)
  return rgb(v >> 16, (v >> 8) & 255, v & 255)
end

-- Wie viel Pixel ein Hut zur Frisur höher sitzt.
function G.hut_hoehe(frisur)
  return G.eintrag("frisur", frisur).hut or 0
end

return G
