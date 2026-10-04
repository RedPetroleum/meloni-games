-- Gebiete: erzeugt die Karte eines Gebiets aus Katalogwerten (Größe) und Seed und merkt sie sich,
-- damit Titel und Welt nicht zweimal rechnen.
local S = require("sprites")
local Map = require("lib.tilemap")
local Gen = require("game.mapgen")
local K = require("game.katalog")
local Farm = require("game.farm")
local Tiles = require("game.tiles")

local Area = {}

Area.DEFAULT_SEED = 1

-- Beschriftungen der Orte im Dorf (E12, E13): Text, Versatz in Pixeln zur Kachel des Orts
-- (über dem Dach bzw. Stand).
Area.LABELS = {
  laden = {"Laden", 0, -56}, markt = {"Pferdemarkt", 8, -40}, jobbrett = {"Jobbrett", 0, -34},
  turnier = {"Turnierplatz", 0, -12},
  -- blaues Haus: Garderobe (game/garderobe.lua), vorher ein Schild; Text als Funktion (ctx)
  wohnhaus = {function(ctx) return require("game.garderobe").offen(ctx) and "Mähne & Masche" or "Öffnet demnächst" end,
    0, -56},
}

local cache = {}

-- nr: Gebietsnummer (KATALOG §10), seed: Zahl. Gibt {nr, name, map, plot, places, …} zurück.
-- Stellt auch Farben und Sprites der Kacheln auf das Gebiet um (Tiles.set_palette).
function Area.get(nr, seed, farm)
  seed = seed or Area.DEFAULT_SEED
  local key = nr .. ":" .. seed .. (farm and ":farm" or "")
  local info = K.welt.gebiete[nr] or error("Gebiet " .. tostring(nr) .. " fehlt im Katalog")
  Tiles.set_palette(info.palette)
  if cache[key] then
    cache[key].map:prepare()
    return cache[key]
  end
  local def = Gen.generate(info, seed + nr * 1000)
  def.sprites = S
  local area = {
    nr = nr, seed = seed, name = info.name, info = info,
    map = Map.new(def):prepare(), plot = def.plot, places = def.places, village = def.village,
  }
  if nr == 1 then
    area.farm = farm or Farm.default(area.plot)
    area.plot = area.farm.plot       -- gespeicherte Höfe haben ein gewachsenes Grundstück
    Farm.apply(area.map, area.farm)
    area.map.changes = {}          -- der Hof gehört zum Grundzustand, nur spätere Änderungen werden gespeichert
    local home = area.farm.home or {area.plot.x + 10, area.plot.y + 8}
    area.places.start = {home[1], home[2]}   -- im Hof, zwischen Stall und Weide
    local d = Farm.stall_door(area.farm)
    area.places.stalltuer = {d[1], d[2]}
    local bd = Farm.bed_door(area.farm)
    area.places.bett = {bd[1], bd[2]}
  end
  cache = {[key] = area}   -- nur ein Gebiet im Speicher
  return area
end

-- Vergisst das gemerkte Gebiet (Tests, die mit demselben Seed frisch anfangen wollen).
function Area.clear()
  cache = {}
end

return Area
