-- Gebiete: erzeugt die Karte eines Gebiets aus Katalogwerten (Größe) und Seed und merkt sie sich,
-- damit Titel und Welt nicht zweimal rechnen.
local S = require("sprites")
local Map = require("lib.tilemap")
local Gen = require("game.mapgen")
local K = require("game.katalog")
local Farm = require("game.farm")

local Area = {}

Area.DEFAULT_SEED = 1

-- Beschriftungen der Orte im Dorf (E12, E13): Text, Versatz in Pixeln zur Kachel des Orts
-- (über dem Dach bzw. Stand).
Area.LABELS = {
  laden = {"Laden", 0, -56}, markt = {"Pferdemarkt", 8, -40}, jobbrett = {"Jobbrett", 0, -34},
  turnier = {"Turnierplatz", 0, -12},
}

local cache = {}

-- nr: Gebietsnummer (KATALOG §10), seed: Zahl. Gibt {nr, name, map, plot, places, …} zurück.
function Area.get(nr, seed, farm)
  seed = seed or Area.DEFAULT_SEED
  local key = nr .. ":" .. seed .. (farm and ":farm" or "")
  if cache[key] then return cache[key] end
  local info = K.welt.gebiete[nr] or error("Gebiet " .. tostring(nr) .. " fehlt im Katalog")
  local def = Gen.generate(info, seed + nr * 1000)
  def.sprites = S
  local area = {
    nr = nr, seed = seed, name = info.name, info = info,
    map = Map.new(def):prepare(), plot = def.plot, places = def.places, village = def.village,
  }
  if nr == 1 then
    area.farm = farm or Farm.default(area.plot)
    Farm.apply(area.map, area.farm)
    area.map.changes = {}          -- der Hof gehört zum Grundzustand, nur spätere Änderungen werden gespeichert
    area.places.start = {area.plot.x + 10, area.plot.y + 8}   -- im Hof, zwischen Stall und Weide
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
