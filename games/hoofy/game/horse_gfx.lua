-- Pferde zeichnen: Körperform (KATALOG §3) × Fellfarbe (KATALOG §4) × Pose.
-- Sprites: horse_<körper>_<pose> ist der Braune, <farbe>_<körper>_<pose> die Recolors (sprites.txt),
-- muster_<muster>_<körper>_<pose> das Muster-Overlay (tools/hoofy_pferde.py).
local S = require("sprites")

local G = {}

G.BODIES = {"pony", "warmblut", "kaltblut", "einhorn"}
G.POSES = {"side", "side_walk", "gallop1", "gallop2", "graze", "down", "down_walk", "up", "up_walk"}

-- Farbe (id aus KATALOG §4) → {Grundfarbe (Sprite-Präfix), Muster oder nil}
G.COATS = {
  brauner = {"horse"}, fuchs = {"fuchs"}, dunkelbrauner = {"dunkelbrauner"}, hellfuchs = {"hellfuchs"},
  rappe = {"rappe"}, grauschimmel = {"grauschimmel"},
  falbe = {"falbe"}, isabell = {"isabell"}, schimmel = {"schimmel"}, dunkelfuchs = {"dunkelfuchs"},
  mausfalbe = {"mausfalbe"}, rotschimmel = {"rotschimmel"}, braunschecke = {"horse", "schecke"},
  palomino = {"palomino"}, rappschecke = {"rappe", "schecke"}, fuchsschecke = {"fuchs", "schecke"},
  apfelschimmel = {"grauschimmel", "apfel"}, fliegenschimmel = {"schimmel", "fliegen"},
  silberrappe = {"silberrappe"}, windfarben = {"windfarben"},
  tigerschecke = {"schimmel", "tupfen"}, cremello = {"cremello"}, perlino = {"perlino"},
  champagner = {"champagner"}, rosa = {"rosa"}, mintgruen = {"mintgruen"},
  gold = {"gold"}, regenbogen = {"regenbogen", "regenbogen"}, lila = {"lila"}, zebra = {"schimmel", "zebra"},
}

-- Namen einmal zusammensetzen statt in jedem Frame: cache[farbe][körper][pose] = {coat, muster, w, h}
local cache = {}

local function names(coat, body, pose)
  local c = cache[coat]
  if not c then c = {}; cache[coat] = c end
  local b = c[body]
  if not b then b = {}; c[body] = b end
  local n = b[pose]
  if not n then
    local def = G.COATS[coat] or error("unbekannte Fellfarbe " .. tostring(coat))
    local base = def[1] .. "_" .. body .. "_" .. pose
    local w, h = S.size(base)
    n = {base, def[2] and ("muster_" .. def[2] .. "_" .. body .. "_" .. pose), w, h}
    b[pose] = n
  end
  return n
end

-- Schmuck am Pferd (Rückmeldung 1.2.1): Overlays aus tools/hoofy_pferde.py, Lage in game/schmuck_pos.lua.
-- Reihenfolge = Zeichenreihenfolge (Decke unter dem Kranz).
G.SCHMUCK = {"glitzerdecke", "blumenkranz", "maehnenschleife", "goldhufeisen"}
local POS = require("game.schmuck_pos")
local jcache = {}

-- {Sprite, x, y, Breite} des Schmucks id für Körper und Pose, false wenn es keins gibt.
local function jewel(id, body, pose)
  local key = id .. body .. pose
  local j = jcache[key]
  if j == nil then
    local name = "schmuck_" .. id .. "_" .. body .. "_" .. pose
    local p = POS[name]
    j = p and {name, p[1], p[2], (S.size(name))} or false
    jcache[key] = j
  end
  return j
end

-- Zeichnet das Pferd mit dem Fußpunkt x, y (Mitte unten). flip: nach links schauen (Seitenposen).
-- schmuck (optional): Menge id → true des getragenen Schmucks (data.schmuck).
function G.draw(coat, body, pose, x, y, flip, schmuck)
  local n = names(coat, body, pose)
  local dx, dy = flr(x - n[3] / 2), flr(y - n[4])
  S.draw(n[1], dx, dy, flip)
  if n[2] then S.draw(n[2], dx, dy, flip) end
  if schmuck and next(schmuck) then
    for _, id in ipairs(G.SCHMUCK) do
      local j = schmuck[id] and jewel(id, body, pose)
      if j then S.draw(j[1], flip and (dx + n[3] - j[2] - j[4]) or (dx + j[2]), dy + j[3], flip) end
    end
  end
end

function G.size(coat, body, pose)
  local n = names(coat, body, pose)
  return n[3], n[4]
end

return G
