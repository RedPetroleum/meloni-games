-- Menü eines eigenen Pferds (E2): Streicheln, Füttern, Striegeln, Leine, Reiten, Zubehör, Ort, Info.
-- Die Welt öffnet es am Pferd, die Stallansicht (Rückmeldung 1.2.1) im Stall; dort heißt die Leine
-- „Holen“, Reiten fällt weg und „Zucht“ kommt dazu.
--
-- env: {ctx, wild, nav, say = function(text, frames), in_stall = true/nil,
--       on_mount = function() (Welt: A erst nach dem Loslassen), on_leave = function() (Stall: Pferd herausgeholt)}
local Menu = require("game.menu")
local Care = require("game.care")
local Farm = require("game.farm")
local Economy = require("game.economy")
local Breeding = require("game.breeding")
local Screens = require("game.screens")
local K = require("game.katalog")
local H = require("game.horse_model")

local HM = {}
HM.__index = HM

local FOODS = {"heu", "hafer", "karotte", "premiumfutter"}
local CROP_FOODS = {"apfel", "sonnenblumenkerne", "minze", "zuckerruebe", "luzerne", "drachenfrucht", "goldene_karotte"}

-- Bilder und Kurznamen im Futter-Raster (Ernte: Bild der reifen Pflanze)
local FOOD_ICON = {
  heu = "hay", hafer = "ico_hafer", karotte = "ico_karotte", premiumfutter = "ico_premium", apfel = "emo_apple",
  sonnenblumenkerne = "pflanze_sonnenblume_3", minze = "pflanze_minze_3", zuckerruebe = "pflanze_zuckerruebe_3",
  luzerne = "pflanze_luzerne_3", drachenfrucht = "pflanze_drachenfrucht_3", goldene_karotte = "pflanze_goldene_karotte_3",
}
local FOOD_SHORT = {
  heu = "Heu", hafer = "Hafer", karotte = "Karotte", premiumfutter = "Premium", apfel = "Apfel", sonnenblumenkerne = "Kerne",
  minze = "Minze", zuckerruebe = "Rübe", luzerne = "Luzerne", drachenfrucht = "Drachen", goldene_karotte = "Gold",
}

HM.HOUSE_NAMES = {stall = "Stall", weide = "Weide", frei = "Frei", anhaenger = "Anhänger", goepel = "Göpel"}
local HOUSE_ICONS = {stall = "ico_stall", weide = "ico_weide", frei = "ico_frei", goepel = "goepel"}

-- Zucht mit diesem Pferd: Liste der Partner oder nil und der Grund, warum es nicht geht.
function HM.partners(ctx, d)
  local day = ctx.clock and ctx.clock.day or 1
  if d.alter < 1 then return nil, "noch ein Fohlen" end
  if d.ort ~= "stall" then return nil, "nur im Stall" end
  if d.sex == "m" then
    local list = Breeding.mares(ctx.herd, day)
    if #list == 0 then return nil, "keine bereite Stute im Stall" end
    return list
  end
  if d.traechtig then return nil, "schon trächtig" end
  if (d.zucht_pause or 0) > day then return nil, "Pause bis Tag " .. d.zucht_pause end
  local list = Breeding.stallions(ctx.herd)
  if #list == 0 then return nil, "kein Hengst im Stall" end
  return list
end

function HM.open(env, h)
  local self = setmetatable({env = env, ctx = env.ctx, horse = h}, HM)
  self:main()
  return self
end

function HM:main()
  local h, ctx = self.horse, self.ctx
  local led = h.state == "led" or h.state == "follow"
  local items = {
    {label = "Streicheln", id = "stroke", icon = "ico_herz", short = "Kraulen"},
    {label = "Füttern", id = "feed", icon = "ico_karotte", short = "Futter"},
    {label = "Striegeln", id = "brush", dim = (ctx.inv.buerste or 0) < 1, icon = "ico_buerste", short = "Bürste"},
  }
  if self.env.in_stall then
    items[#items + 1] = {label = "Herausholen", id = "take", icon = "ico_leine", short = "Holen"}
    local partners, why = HM.partners(ctx, h.data)
    items[#items + 1] = {label = partners and "Zucht" or ("Zucht: " .. why), id = "breed", dim = not partners,
      icon = "ico_zucht", short = "Zucht"}
  else
    items[#items + 1] = {label = led and "Leine lösen" or "Anleinen", id = "leash", icon = "ico_leine", short = led and "Lösen" or "Leine"}
    items[#items + 1] = {label = "Aufsitzen", id = "mount", icon = "ico_reiten", short = "Reiten"}
  end
  items[#items + 1] = {label = "Ausrüsten", id = "gear", icon = "ico_hufeisen", short = "Zubehör"}
  items[#items + 1] = {label = "Unterbringen", id = "house", icon = "ico_stall", short = "Ort"}
  items[#items + 1] = {label = "Info", id = "info", icon = "ico_info", short = "Info"}
  self.stage, self.m = "main", Menu.new(items, h.data.name)
end

function HM:food()
  local ctx = self.ctx
  local items = {}
  for _, id in ipairs(FOODS) do
    local n = ctx.inv[id] or 0
    local name = id
    for _, f in ipairs(K.futter.kaufen) do if f.id == id then name = f.name end end
    items[#items + 1] = {label = name .. ": " .. Care.hunger_text(id), id = id, dim = n < 1, icon = FOOD_ICON[id], short = FOOD_SHORT[id] or name, badge = tostring(n)}
  end
  for _, id in ipairs(CROP_FOODS) do          -- Ernte nur, wenn welche da ist
    local n = ctx.inv[id] or 0
    if n > 0 then
      items[#items + 1] = {label = Farm.CROP_NAME[id] .. ": " .. Care.hunger_text(id), id = id, icon = FOOD_ICON[id], short = FOOD_SHORT[id], badge = tostring(n)}
    end
  end
  self.stage, self.m = "food", Menu.new(items, "Füttern")
end

-- Ausrüstung: anlegen aus dem Vorrat, ablegen was getragen wird.
local function gear_items(ctx, d)
  local items = {}
  local worn = {}
  if d.sattel then worn[#worn + 1] = d.sattel end
  if d.taschen then worn[#worn + 1] = d.taschen end
  if d.lampe then worn[#worn + 1] = "sattellampe" end
  for _, j in ipairs(Economy.JEWELRY) do if d.schmuck and d.schmuck[j] then worn[#worn + 1] = j end end
  for _, id in ipairs(worn) do
    items[#items + 1] = {label = "ab: " .. Economy.find(id).name, id = "ab:" .. id}
  end
  local all = {}
  for _, id in ipairs(Economy.SLOTS.sattel) do all[#all + 1] = id end
  for _, id in ipairs(Economy.SLOTS.taschen) do all[#all + 1] = id end
  all[#all + 1] = "sattellampe"
  for _, id in ipairs(Economy.JEWELRY) do all[#all + 1] = id end
  for _, id in ipairs(all) do
    local n = ctx.inv[id] or 0
    if n > 0 then items[#items + 1] = {label = "an: " .. Economy.find(id).name .. " x" .. n, id = "an:" .. id} end
  end
  if #items == 0 then items[1] = {label = "Nichts im Vorrat", id = "none", dim = true} end
  return items
end

-- Ort: zu Hause Stall, Weide, Frei, Göpel (wenn es einen gibt); Anhänger, wenn es einen gibt; unterwegs
-- Anhänger und Freilassen (E73).
function HM:house()
  local ctx, h = self.ctx, self.horse
  local Reise = require("game.reise")
  local items = {}
  if ctx.area.farm then
    local cap = Farm.capacity(ctx.area.farm)
    local orte = {"stall", "weide", "frei"}
    if cap.goepel > 0 then orte[#orte + 1] = "goepel" end
    for _, ort in ipairs(orte) do
      local n = Farm.count(ctx.herd, ort)
      local full = n >= cap[ort] and h.data.ort ~= ort
      local weak = (ort == "frei" and not Farm.may_roam(h.data, H)) or (ort == "goepel" and not Farm.may_pull(h.data, H))
      items[#items + 1] = {label = string.format("%s %d/%d", HM.HOUSE_NAMES[ort], n, cap[ort]), id = ort,
        dim = full or weak or h.data.ort == ort, icon = HOUSE_ICONS[ort], short = HM.HOUSE_NAMES[ort], badge = n .. "/" .. cap[ort]}
    end
  end
  if Reise.trailer_box(ctx) then
    local n, cap = Reise.geladen(ctx)
    items[#items + 1] = {label = string.format("Anhänger %d/%d", n, cap), id = "anhaenger", dim = n >= cap,
      icon = "ico_anhaenger", short = "Anhänger", badge = n .. "/" .. cap}
  end
  if not ctx.area.farm then
    items[#items + 1] = {label = "Freilassen", id = "freilassen", icon = "ico_freilassen", short = "Wildnis"}
  end
  self.stage, self.m = "house", Menu.new(items, "Wohin mit " .. h.data.name .. "?")
end

-- Partner für die Zucht wählen; Verwandtschaft steht gleich dabei (Inzucht-Malus).
function HM:breed()
  local d = self.horse.data
  local list = HM.partners(self.ctx, d)
  if not list then return self:main() end
  local items = {}
  for i, p in ipairs(list) do
    local pct, what = Breeding.verwandtschaft(d, p)
    items[i] = {label = p.name .. (pct > 0 and (" (" .. what .. ": -" .. pct .. " %)") or ""), id = i}
  end
  self.stage, self.list = "breed", list
  self.m = Menu.new(items, d.sex == "m" and ("Stute für " .. d.name) or ("Hengst für " .. d.name))
end

function HM:close() self.closed = true end

function HM:act(id)
  local env, ctx, h = self.env, self.ctx, self.horse
  local d, wild, say = h.data, env.wild, env.say
  if self.stage == "breed" then
    if id == "close" then return self:main() end
    local p = self.list[id]
    local stallion, mare = d, p
    if d.sex ~= "m" then stallion, mare = p, d end
    local day = ctx.clock and ctx.clock.day or 1
    local ok, why = Breeding.start(ctx, stallion, mare, day)
    local pct = Breeding.verwandtschaft(stallion, mare)
    say(ok and (stallion.name .. " und " .. mare.name .. ": Fohlen in " .. K.zeit.traechtig_tage .. " Tagen."
      .. (pct > 0 and (" Inzucht: Gen-Werte -" .. pct .. " %.") or "")) or ("Geht nicht: " .. tostring(why)), 180)
    if ok then ctx.sfx.pet() h:react("emo_heart", 120) end
    return self:close()
  end
  if self.stage == "gear" then
    if id == "close" then return self:main() end
    local kind, what = id:match("^(%a+):(.+)$")
    if kind == "an" then
      local ok, why = Economy.equip(ctx, d, what)
      say(ok and d.name .. " trägt: " .. Economy.find(what).name .. "." or "Geht nicht: " .. tostring(why) .. ".")
    elseif kind == "ab" then
      Economy.unequip(ctx, d, what)
      say(d.name .. " trägt " .. Economy.find(what).name .. " nicht mehr.")
    end
    return self:close()
  end
  if self.stage == "house" then
    if id == "close" then return self:main() end
    if id == "freilassen" then
      wild:free(h)
      say(d.name .. " läuft davon, zurück in die Wildnis.", 150)
      return self:close()
    end
    local ok, why = wild:house(h, id)
    local text = id == "anhaenger" and d.name .. " steigt in den Anhänger." or d.name .. " kommt in: " .. HM.HOUSE_NAMES[id] .. "."
    say(ok and text or "Geht nicht: " .. tostring(why) .. ".")
    return self:close()
  end
  if self.stage == "food" then
    if id == "close" then return self:main() end
    ctx.inv[id] = ctx.inv[id] - 1
    local _, bond = Care.feed(d, id)
    ctx.sfx.eat()
    h:react(bond > 0 and "emo_heart" or "emo_apple", 120)
    return self:close()
  end
  if id == "close" then return self:close() end
  if id == "stroke" then
    local add = Care.stroke(d)
    if add > 0 then ctx.sfx.pet() h:react("emo_heart", 120)
    else ctx.sfx.snort() h:react("emo_zzz", 90) end          -- heute schon genug gestreichelt
    self:close()
  elseif id == "feed" then
    self:food()
  elseif id == "house" then
    self:house()
  elseif id == "gear" then
    self.stage, self.m = "gear", Menu.new(gear_items(ctx, d), "Ausrüstung " .. d.name)
  elseif id == "breed" then
    self:breed()
  elseif id == "brush" then
    Care.brush(d)
    ctx.sfx.brush()
    h:react("emo_sparkle", 120)
    self:close()
  elseif id == "take" then
    if not wild:can_lead(h) then
      say("Du führst schon ein Pferd. " .. d.name .. " bleibt im Stall.")
    else
      wild:take_out(h)
      say(d.name .. (h.state == "follow" and " folgt dir." or " ist an der Leine."))
      if env.on_leave then env.on_leave() end
    end
    self:close()
  elseif id == "leash" then
    if h.state == "led" or h.state == "follow" then
      wild:release(h)
      say(d.name .. " ist frei.")
    elseif wild:attach(h) then
      say(d.name .. (h.state == "follow" and " folgt dir." or " ist an der Leine."))
    else
      say("Du führst schon ein Pferd. Mehr als eins passt nicht an die Leine.")
    end
    self:close()
  elseif id == "mount" then
    local r = wild:mount(h)
    if r == "ok" then
      if env.on_mount then env.on_mount() end
    elseif r == "frisch" then
      ctx.sfx.snort()
      h:react("emo_storm", 120)
      say(d.name .. " ist frisch gezähmt und lässt dich noch nicht aufsitzen. Füttern, striegeln und streicheln.", 180)
    else
      ctx.sfx.snort()
      h:react("emo_storm", 120)                                  -- verweigert das Reiten
    end
    self:close()
  elseif id == "info" then
    env.nav.push(Screens.info(ctx, d))
    self:close()
  end
end

function HM:update()
  local r = self.m:update()
  if r then self:act(r) end
  return self.closed
end

-- Raster unten mittig; Listen neben dem Pferd (sx, sy: Bildschirmlage des Pferds).
function HM:draw(sx, sy)
  if self.m.grid then self.m:draw() else self.m:draw(sx + 24, sy - 50) end
end

return HM
