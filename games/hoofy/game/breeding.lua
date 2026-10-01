-- Zucht (README §3, KATALOG §1, §4): Hengst und Stute im Stall, Trächtigkeit 2 Tage, danach 3 Tage
-- Pause für die Stute; das Fohlen wächst in 4 Tagen aus (Days). Vererbt werden die Gen-Stats (Mittel
-- der Eltern ± σ 6), Rasse 50:50, Farbe nach der Farbgenetik. Der Inzucht-Malus kommt mit B7.
local K = require("game.katalog")
local H = require("game.horse_model")
local Rng = require("lib.rng")
local U = require("lib.util")

local B = {}

local counter = 0

-- Eindeutige Kennung eines Pferds (für den Stammbaum). Kommt ohne rnd() aus, damit die Zufallsfolge
-- der Spiele gleich bleibt. Das Pferd selbst darf in taken stehen (sonst hing die Schleife endlos, wenn ein
-- gezähmtes Pferd ohne Kennung zur Zucht kam).
function B.ensure_id(data, taken)
  if data.id then return data.id end
  repeat
    counter = counter + 1
    data.id = string.format("%06d%03d", flr(U.hash(counter, frame(), 91) * 1000000), counter % 1000)
    local clash = false
    for _, d in ipairs(taken or {}) do if d ~= data and d.id == data.id then clash = true end end
  until not clash
  return data.id
end

-- ---- Voraussetzungen ----

local function adult(d) return d.alter >= 1 end

-- Hengst bereit? Ausgewachsen, im Stall.
function B.stallion_ok(d)
  return d.sex == "m" and adult(d) and d.ort == "stall"
end

-- Stute bereit? Ausgewachsen, im Stall, nicht trächtig, nicht in der Pause nach der Geburt.
function B.mare_ok(d, day)
  return d.sex == "w" and adult(d) and d.ort == "stall" and not d.traechtig and (d.zucht_pause or 0) <= day
end

function B.stallions(herd)
  local out = {}
  for _, d in ipairs(herd) do if B.stallion_ok(d) then out[#out + 1] = d end end
  return out
end

function B.mares(herd, day)
  local out = {}
  for _, d in ipairs(herd) do if B.mare_ok(d, day) then out[#out + 1] = d end end
  return out
end

-- ---- Stammbaum (E44): {id, name, rasse, farbe, v = Vater, m = Mutter}, höchstens 3 Ebenen ----

B.DEPTH = 3

-- Kürzt einen Stammbaumknoten auf `tiefe` Ebenen (Knoten selbst zählt mit).
local function trim(a, tiefe)
  if not a then return nil end
  local out = {id = a.id, name = a.name, rasse = a.rasse, farbe = a.farbe}
  if tiefe > 1 then
    out.v = trim(a.v, tiefe - 1)
    out.m = trim(a.m, tiefe - 1)
  end
  return out
end

-- Knoten eines Pferds mit seinen Eltern (aus d.ahnen), auf `tiefe` Ebenen gekürzt.
local function ahn(d, tiefe)
  local node = {id = d.id, name = d.name, rasse = d.rasse, farbe = d.farbe}
  if d.ahnen then node.v, node.m = d.ahnen.v, d.ahnen.m end
  return trim(node, tiefe)
end

-- Verwandtschaft zweier Pferde (Daten mit id und ahnen) und Inzucht-Malus in Prozent (KATALOG §4):
-- Eltern/Kind und Geschwister −15, Halbgeschwister und Großeltern/Enkel −8, Cousins −3.
-- Gibt Prozent und Bezeichnung zurück, 0 bei keiner bekannten Verwandtschaft.
function B.verwandtschaft(a, b)
  local I = K.farben.inzucht
  local function parents(d)
    local v, m = d.ahnen and d.ahnen.v, d.ahnen and d.ahnen.m
    return v and v.id, m and m.id
  end
  local function grand(d)
    local out = {}
    if d.ahnen then
      for _, p in ipairs({d.ahnen.v, d.ahnen.m}) do
        if p then
          if p.v then out[p.v.id] = true end
          if p.m then out[p.m.id] = true end
        end
      end
    end
    return out
  end
  local av, am = parents(a)
  local bv, bm = parents(b)
  if a.id and (a.id == bv or a.id == bm) or (b.id and (b.id == av or b.id == am)) then return I.eltern, "Eltern und Kind" end
  if av and am and av == bv and am == bm then return I.eltern, "Geschwister" end
  if (av and (av == bv or av == bm)) or (am and (am == bv or am == bm)) then return I.halb, "Halbgeschwister" end
  local ga, gb = grand(a), grand(b)
  if b.id and ga[b.id] or a.id and gb[a.id] then return I.halb, "Großeltern und Enkel" end
  for id in pairs(ga) do if gb[id] then return I.cousins, "Cousins" end end
  return 0, nil
end

-- Malus in Prozent für ein Fohlen von Vater-Daten f und Mutter m.
function B.inzucht_malus(f, m)
  return (B.verwandtschaft(f, m))
end

-- ---- Paarung und Geburt ----

-- Beginnt die Trächtigkeit der Stute mit dem Hengst. Gibt true oder false, Grund zurück.
function B.start(ctx, stallion, mare, day)
  if not B.stallion_ok(stallion) then return false, "Hengst nicht bereit" end
  if not B.mare_ok(mare, day) then return false, "Stute nicht bereit" end
  B.ensure_id(stallion, ctx.herd)
  B.ensure_id(mare, ctx.herd)
  -- Vom Vater werden die Erbdaten festgehalten (er kann bis zur Geburt verkauft sein).
  mare.traechtig = {
    tag = day + K.zeit.traechtig_tage,
    vater = {
      id = stallion.id, name = stallion.name, rasse = stallion.rasse, farbe = stallion.farbe,
      farbe2 = stallion.farbe2, gen = {tempo = stallion.gen.tempo, staerke = stallion.gen.staerke,
        spuer = stallion.gen.spuer, ausdauer = stallion.gen.ausdauer},
      ahnen = stallion.ahnen, zug = stallion.zug,
    },
  }
  return true
end

local CHILD_TIER_FROM = {}

-- Farbe eines Elternteils: sichtbare (70 %) oder versteckte (30 %).
local function parent_color(visible, hidden, rng)
  if rng:next() < K.farben.vererbung.sichtbar / 100 then return visible end
  return hidden
end

-- Zufällige Farbe der nächsten Stufe (Mutation); bleibt die Farbe, wenn es keine höhere Stufe gibt.
local function mutate(farbe, rng)
  local tier = K.farbe(farbe).stufe
  if tier >= #K.farben.stufen then return farbe end
  local list = K.farben.stufen[tier + 1].farben
  return list[rng:int(1, #list)]
end

-- Farben des Fohlens aus (Vater sichtbar/versteckt, Mutter sichtbar/versteckt): je Elternteil eine
-- Farbe ziehen, eine davon zeigt das Fohlen (50:50), die andere trägt es versteckt. 1 % Mutation der
-- gezeigten Farbe zur nächsten Stufe. Gibt sichtbar, versteckt zurück.
function B.foal_colors(father_v, father_h, mother_v, mother_h, rng)
  local a = parent_color(father_v, father_h, rng)
  local b = parent_color(mother_v, mother_h, rng)
  local shown, hidden = a, b
  if rng:next() < 0.5 then shown, hidden = b, a end
  if rng:next() < K.farben.vererbung.mutation / 100 then shown = mutate(shown, rng) end
  return shown, hidden
end

-- Ein Fohlen aus Vater-Daten f (Tabelle mit rasse, farbe, farbe2, gen, ahnen, name, id) und Mutter m.
function B.foal(f, m, rng, inzucht)
  local S = K.stats
  local rasse = K.rasse(rng:next() < K.farben.rasse_vater / 100 and f.rasse or m.rasse)
  local d = {
    rasse = rasse.id, alter = 0, sex = rng:next() < 0.5 and "m" or "w",
    zug = ({"verfressen", "schreckhaft", "faul", "eitel", "nachteule"})[rng:int(1, 5)],
    gen = {}, train = {}, pot = {},
  }
  local malus = 1 - (inzucht or 0) / 100
  for _, key in ipairs(H.STATS) do
    local lo, hi = S.gen_min, S.gen_max
    if key == "ausdauer" then lo, hi = S.ausdauer_min, S.ausdauer_max end
    local mean = (f.gen[key] + m.gen[key]) / 2
    local g = flr((mean + H.gauss(rng, S.fohlen_sigma)) * malus + 0.5)
    g = mid(lo, g, hi)
    local p = flr(g + rasse.spanne + H.gauss(rng, S.potenzial_sigma) + 0.5)
    d.gen[key], d.train[key], d.pot[key] = g, 0, mid(g, p, S.potenzial_max)
  end
  d.farbe, d.farbe2 = B.foal_colors(f.farbe, f.farbe2, m.farbe, m.farbe2, rng)
  d.bindung = mid(0, rasse.bindung + H.TRAIT_BOND[d.zug] + flr((rng:next() * 2 - 1) * 5 + 0.5), 100)
  d.hunger, d.gewicht, d.sauberkeit = S.hunger.start, S.gewicht.start, S.sauberkeit.start
  d.energie = d.gen.ausdauer
  d.name = H.fresh_name(rng)
  d.ahnen = {v = ahn(f, B.DEPTH), m = ahn(m, B.DEPTH)}
  return d
end

-- Tageswechsel (day = neuer Tag): Stuten, deren Zeit um ist, bekommen ihr Fohlen. Gibt die Fohlen
-- (Pferdedaten) zurück; die Stute hat danach 3 Tage Pause.
function B.tick(ctx, day)
  local born = {}
  local rng = Rng.new((ctx.seed or 1) * 71 + day * 17 + 1)
  for _, m in ipairs({table.unpack(ctx.herd)}) do
    if m.traechtig and day >= m.traechtig.tag then
      B.ensure_id(m, ctx.herd)
      local malus = B.inzucht_malus(m.traechtig.vater, m)
      local foal = B.foal(m.traechtig.vater, m, rng, malus)
      H.claim_name(foal, rng)
      B.ensure_id(foal, ctx.herd)
      m.traechtig = nil
      m.zucht_pause = day + K.zeit.stute_pause_tage
      born[#born + 1] = {foal = foal, mutter = m}
    end
  end
  return born
end

return B
