-- Käufer (README §4, KATALOG §6): täglich kommt ein zufälliger Käufer zum Hof. Jeder gewichtet die
-- Stats anders, zahlt nach seiner Formel und hat Folgen für die übrigen Pferde. Sprüche passen zum
-- angebotenen Pferd.
local K = require("game.katalog")
local H = require("game.horse_model")
local V = require("game.value")
local Rng = require("lib.rng")
local U = require("lib.util")
local Bubbles = require("game.bubbles")

local B = {}

B.TYPES = {"sammlerin", "reithof", "zuechter", "schlachter"}

B.INFO = {
  sammlerin = {name = "Reiche Sammlerin", kurz = "Sammlerin", sie = true},
  reithof = {name = "Netter Reithof", kurz = "Reithof"},
  zuechter = {name = "Züchter", kurz = "Züchter"},
  schlachter = {name = "Schlachter", kurz = "Schlachter"},
}

local function clamp(v, lo, hi) return mid(lo, v, hi) end

-- Preis, den der Käufer für das Pferd d zahlt, oder nil und der Grund (Text), wenn er es nicht nimmt.
function B.offer(typ, d)
  local W = K.wert.kaeufer
  local wert = V.wert_roh(d)
  if typ == "sammlerin" then
    local c = W.sammlerin
    if d.sauberkeit < c.min_sauberkeit then return nil, "zu schmutzig (ab " .. c.min_sauberkeit .. ")" end
    return flr(wert * (c.basis + V.farbfaktor(d) * c.farbe) + 0.5)
  elseif typ == "reithof" then
    local c = W.reithof
    return flr(wert * c.faktor * (c.basis + d.bindung / c.teiler) + 0.5)
  elseif typ == "zuechter" then
    local c = W.zuechter
    local t, s, a = H.stat(d, "tempo"), H.stat(d, "staerke"), H.stat(d, "ausdauer")
    local p = wert * (c.basis + (t + s + (a - K.wert.ausdauer_basis) * K.wert.ausdauer_faktor) / c.teiler)
    if d.sex == "m" then p = p * c.hengst end
    return flr(p + 0.5)
  elseif typ == "schlachter" then
    local c = W.schlachter
    return flr(wert * c.faktor * d.gewicht / c.teiler + 0.5)
  end
  error("unbekannter Käufer " .. tostring(typ))
end

-- „sie“ oder „er“ für den Käufer (groß am Satzanfang: gross = true)
function B.pronoun(typ, gross)
  local p = B.INFO[typ].sie and "sie" or "er"
  return gross and (p:sub(1, 1):upper() .. p:sub(2)) or p
end

-- Bindungsänderung für die übrigen Pferde nach einem Verkauf an diesen Käufer.
function B.folge(typ)
  local W = K.wert.kaeufer
  if typ == "reithof" then return W.reithof.bindung_andere end
  if typ == "zuechter" then return W.zuechter.bindung_andere end
  if typ == "schlachter" then return W.schlachter.bindung_andere end
  return 0
end

-- ---- Sprüche (mehrere je Pferdetyp) ----

-- {sie|er} bzw. {die Stute|der Hengst|das Fohlen}: Form passend zum Pferd (H.gtext).
local SPRUECHE = {
  sammlerin = {
    selten = {"Diese Farbe! Die fehlt mir noch in der Sammlung.", "Ach, wie außergewöhnlich. {Die|Den} muss ich haben.", "Darling, dieses Fell ist ein Gedicht."},
    schmutzig = {"Also bitte, {die Stute|der Hengst|das Fohlen} ist ja völlig verdreckt.", "So kann ich {sie|ihn} nicht mitnehmen. Striegeln Sie {sie|ihn} erst!"},
    fohlen = {"Ein Fohlen! Wie süß. {Sie|Er} wächst ja noch.", "Hach, so klein. Und trotzdem mit Stammbaum?"},
    hengst = {"Ein stattlicher Hengst. Er passt zu meinem Salon.", "Ein Hengst mit Haltung. Sehr schön."},
    stute = {"Eine elegante Dame. Ich bin entzückt.", "Die Stute hat Stil. Gut, gut."},
    normal = {"Nett. Nicht aufregend, aber nett.", "Hm, ich hatte mir etwas Bunteres vorgestellt."},
  },
  reithof = {
    zahm = {"Ach, {die|der} ist ja richtig zutraulich. Das ist genau das, was unsere Kinder brauchen.", "So ein braves Pferd! {Die|Den} nehmen wir."},
    scheu = {"{Die|Der} ist ein bisschen scheu, oder? Na, wir haben Geduld.", "Ein bisschen {zickig|bockig}, aber wir kriegen das hin."},
    fohlen = {"Ein Fohlen? Das können die Kinder gleich mit aufziehen.", "Noch klein, aber sehr lieb. Wir kümmern uns um {sie|ihn}."},
    hengst = {"Ein Hengst? Na, wir haben einen Extra-Paddock.", "Hoffentlich ist er verträglich."},
    stute = {"Eine nette Stute, sie passt zu unserer Herde.", "Die Mädels im Stall freuen sich schon."},
    normal = {"Ordentliches Pferd, danke.", "Das nehmen wir gern für den Reitunterricht."},
  },
  zuechter = {
    schnell = {"Was für Beine! Mit der Geschwindigkeit gewinnt man Rennen.", "Schnell. Sehr schnell. {Die|Den} merke ich mir."},
    stark = {"{Kräftige Stute|Kräftiger Hengst|Kräftiges Fohlen}. Die Linie lässt sich sehen.", "{Die|Der} hat Muskeln! Damit züchte ich Zugpferde."},
    fohlen = {"Ein Fohlen mit Potenzial, das schaue ich mir an.", "Jung, aber gute Anlagen."},
    hengst = {"Ein Hengst! Den brauche ich für meine Stuten.", "Endlich ein Deckhengst mit Qualität."},
    stute = {"Eine Stute mit guten Werten. Nicht schlecht.", "Die bringt solide Fohlen."},
    normal = {"Hm. Durchschnitt. Aber für die Zucht tut es das.", "Keine Wunder, aber verwertbar."},
  },
  schlachter = {
    dick = {"Ordentlich Substanz! So ein Gewicht sieht man selten.", "Schwer, schwer. Das lohnt sich."},
    duenn = {"Da ist ja nichts dran. Mager, mager.", "{Die|Der} ist ja ein Hungerhaken."},
    fohlen = {"Zu jung. Aber ich nehme es, wenn der Preis stimmt.", "Hm, klein. Naja, Kleinvieh macht auch Mist."},
    hengst = {"Ein Hengst, sehr kräftig. Mein Metzger freut sich.", "Kräftig gebaut. Abgemacht."},
    stute = {"Eine kräftige Stute. Ich nehme sie.", "Ordentlicher Körperbau, ja."},
    normal = {"Ich sag mal: geht so.", "Ein bisschen Fleisch ist dran. Passt."},
  },
}

-- Kategorien in der Reihenfolge, in der sie geprüft werden.
local ORDER = {
  sammlerin = {"schmutzig", "selten", "fohlen", "hengst", "stute"},
  reithof = {"zahm", "scheu", "fohlen", "hengst", "stute"},
  zuechter = {"fohlen", "schnell", "stark", "hengst", "stute"},
  schlachter = {"dick", "duenn", "fohlen", "hengst", "stute"},
}

local function category(typ, d)
  local checks = {
    schmutzig = d.sauberkeit < 70,
    selten = K.farbe(d.farbe).stufe >= 3,
    fohlen = d.alter < 1,
    hengst = d.sex == "m",
    stute = d.sex == "w",
    zahm = d.bindung >= 60,
    scheu = d.bindung < 30,
    schnell = H.stat(d, "tempo") >= 55,
    stark = H.stat(d, "staerke") >= 55,
    dick = d.gewicht >= 60,
    duenn = d.gewicht <= 40,
  }
  for _, c in ipairs(ORDER[typ]) do if checks[c] then return c end end
  return "normal"
end

-- Ein Spruch zu Käufer und Pferd. Der Spruch bleibt für dasselbe Pferd am selben Tag gleich.
function B.spruch(typ, d, day)
  local list = SPRUECHE[typ][category(typ, d)]
  local i = 1 + flr(U.hash(#d.name, flr(H.stat(d, "tempo")) + flr(H.stat(d, "staerke")), (day or 1) + 17) * #list)
  return H.gtext(d, list[i]), category(typ, d)
end

-- ---- Besuch ----

-- Der Käufer des Tages (deterministisch aus Seed und Tag). Gibt {typ, tag, verkauft} zurück, vor
-- Fortschritt.AB.kaeufer nil; die Sammlerin kommt erst ab Fortschritt.AB.sammlerin.
function B.visit(seed, day)
  local F = require("game.fortschritt")
  if not F.offen("kaeufer", day) then return nil end
  local rng = Rng.new((seed or 1) * 977 + day * 13 + 3)
  local typ = B.TYPES[rng:int(1, #B.TYPES)]
  if typ == "sammlerin" and not F.offen("sammlerin", day) then typ = B.TYPES[rng:int(2, #B.TYPES)] end
  return {typ = typ, tag = day, verkauft = false}
end

-- Verkauf von Pferd d (Daten) an den Käufer: entfernt das Pferd und zahlt. Gibt Preis oder nil, Grund.
function B.sell(ctx, typ, d)
  local price, why = B.offer(typ, d)
  if not price then return nil, why end
  local idx
  for i, e in ipairs(ctx.herd) do if e == d then idx = i end end
  if not idx then return nil, "nicht im Bestand" end
  -- Pferd aus der Welt nehmen
  for i, h in ipairs(ctx.herd_horses) do
    if h.data == d then
      if h.state == "ridden" then return nil, "wird geritten" end
      h.dead = true
      table.remove(ctx.herd_horses, i)
      break
    end
  end
  for i, h in ipairs(ctx.lead) do if h.data == d then table.remove(ctx.lead, i) break end end
  table.remove(ctx.herd, idx)
  require("game.economy").strip(ctx, d)       -- Sattel, Schmuck … bleiben bei dir (Rückmeldung 1.3.1)
  ctx.money = ctx.money + price
  local delta = B.folge(typ)
  for _, e in ipairs(ctx.herd) do e.bindung = clamp(e.bindung + delta, 0, 100) end
  if ctx.buyer then ctx.buyer.verkauft = true end
  return price, delta
end

-- ---- Figur im Dorf ----

local Buyer = {}
Buyer.__index = Buyer

function Buyer:draw_shadow()
  local x, y = flr(self.x), flr(self.y)
  rectfill(x - 5, y - 1, x + 5, y, self.shadow)
  rectfill(x - 3, y - 2, x + 3, y + 1, self.shadow)
end

function Buyer:draw()
  local step = (flr(frame() / 30) % 2 == 0) and "" or "_walk"
  self.ctx.S.draw(self.typ .. "_down", flr(self.x) - 6, flr(self.y) - 19)
end

function Buyer:draw_over()
  Bubbles.draw(self.ctx.S, "emo_bang", self.x, self.y - 33, frame())
end

-- Platz der Figur (Rückmeldung 0.5.2): im Dorf vor dem Wohnhaus, die erste freie Kachel in der Nähe; ohne
-- Dorf am Hoftor.
local function spot(ctx)
  local pl, map = ctx.area.places, ctx.map
  if pl.wohnhaus then
    local bx, by = pl.wohnhaus[1] + B.SPOT[1], pl.wohnhaus[2] + B.SPOT[2]
    for r = 0, 5 do
      for dy = -r, r do
        for dx = -r, r do
          if math.max(math.abs(dx), math.abs(dy)) == r then
            local cx, cy = bx + dx, by + dy
            local x, y = cx * 16 + 8, cy * 16 + 14
            if map:walkable(cx, cy) and not map:blocked(x - 8, y - 6, x + 8, y) then return x, y end
          end
        end
      end
    end
  end
  local g, p = pl.hoftor, ctx.area.plot
  local inward = (g[1] < p.x + p.w // 2) and 1 or -1
  return (g[1] + inward * 2) * 16 + 8, g[2] * 16 + 14
end
B.SPOT = {-3, 3}          -- Kachel relativ zum Wohnhaus, von dort wird gesucht

-- Stellt die Figur des Tages hin (oder nimmt sie weg): sie steht im Dorf, solange der Käufer da
-- ist, also tagsüber und bis er etwas gekauft hat.
function B.sync(ctx, night)
  local want = ctx.buyer and not ctx.buyer.verkauft and not night and ctx.area.village   -- nur im Dorf daheim
  local ent = ctx.buyer_ent
  if ent and (not want or ent.typ ~= ctx.buyer.typ) then
    ent.dead = true
    ctx.buyer_ent = nil
    ent = nil
  end
  if want and not ent then
    local x, y = spot(ctx)
    local shadow = ctx.map:ground_at(x, y)
    local e = setmetatable({
      ctx = ctx, typ = ctx.buyer.typ, x = x, y = y,
      reach = 40, shadow = shadow and shadow.shadow or 0, is_buyer = true,
    }, Buyer)
    ctx.world:add(e)
    ctx.buyer_ent = e
  end
end

return B
