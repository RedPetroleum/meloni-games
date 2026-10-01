-- Reiten (README §3, KATALOG §2/§8): Aufsteigen, Schritt und Galopp, Springen nach Stärke,
-- Energieverbrauch, Sattel-Bonus. Der Spieler trägt das Pferd: Position und Kollision gehören
-- dem Spieler, das Pferd wird mit Reiter gezeichnet (game/wild.lua, Horse:draw).
local K = require("game.katalog")
local H = require("game.horse_model")
local Care = require("game.care")
local SFX = require("game.sfx")
local Body = require("lib.body")
local U = require("lib.util")

local R = {}

R.JUMP_FRAMES = 30
R.REACH = 30                -- so nah muss man zum Aufsteigen sein
R.HOLD = 30                 -- A so lange halten: absteigen (E3; Menü kommt mit A13)
R.SADDLE_SLOWDOWN = 1.0

-- Tempo-Wert für die Geschwindigkeit: Gesamtwert + Sattel-Bonus (zählt über das Potenzial hinaus).
function R.tempo(data)
  local bonus = 0
  if data.sattel then bonus = K.artikel(data.sattel).wirkung.tempo or 0 end
  return Care.effective(data, "tempo") + bonus
end

-- Schritt und Galopp in Pixeln pro Frame (E30).
function R.speeds(data)
  local t = R.tempo(data)
  return 1.3 + t / 100 * 0.6, 2.0 + t / 100 * 1.4
end

-- Sprunghöhe in Pixeln aus der Stärke (E30): 6 + 0,3 × Stärke.
function R.jump_height(data)
  return 6 + 0.3 * Care.effective(data, "staerke")
end

-- Frisch gezähmt (data.reit_ab, beim Zähmen gesetzt): lässt sich erst reiten, wenn die Bindung um
-- FRESH_BOND gestiegen ist (ein paar Mal füttern, striegeln, streicheln; E71).
R.FRESH_BOND = 6

function R.fresh(data)
  if data.reit_ab and data.bindung >= data.reit_ab then data.reit_ab = nil end
  return data.reit_ab ~= nil
end

-- Verweigert das Pferd das Aufsteigen? Bindung < 20: zu 50 % (KATALOG §2).
function R.refuses(data, rng)
  local b = K.stats.bindung
  if data.bindung >= b.zickig then return false end
  local r = rng and rng:next() or rnd()
  return r < b.zickig_verweigert / 100
end

-- Steigt auf: Spieler übernimmt Position und Fußkasten des Pferds.
function R.mount(ctx, horse)
  local p = ctx.player
  for i, h in ipairs(ctx.lead) do
    if h == horse then table.remove(ctx.lead, i) break end
  end
  SFX.mount()
  horse.state, horse.rider, horse.moving = "ridden", p, false
  p.riding = horse
  p.x, p.y = horse.x, horse.y
  p.fw, p.fh = horse.fw, horse.fh
  p.jump_t, p.clear, p.energy_acc = 0, nil, 0
  ctx.trail:reset(p.x, p.y)
end

-- Steigt ab: der Spieler steht neben dem Pferd, das Pferd ist wieder an der Leine oder folgt.
function R.dismount(ctx)
  local p = ctx.player
  local h = p.riding
  if not h then return end
  p.riding, p.clear, p.jump_t = nil, nil, 0
  p.fw, p.fh = 8, 4
  h.rider = nil
  h.x, h.y = p.x, p.y
  for _, off in ipairs({{-14, 0}, {14, 0}, {0, 10}, {0, -10}}) do
    if Body.free(ctx.map, p.x + off[1], p.y + off[2], p.fw, p.fh) then
      p.x, p.y = p.x + off[1], p.y + off[2]
      break
    end
  end
  ctx.trail:reset(p.x, p.y)
  ctx.wild:attach(h)
end

-- Ein Frame Reiten für den Spieler p (ruft Player:update).
function R.update(p)
  local ctx, h = p.ctx, p.riding
  local d = h.data
  p.moving = false
  local dx, dy = 0, 0
  if btn(BTN_LEFT) then dx = dx - 1 end
  if btn(BTN_RIGHT) then dx = dx + 1 end
  if btn(BTN_UP) then dy = dy - 1 end
  if btn(BTN_DOWN) then dy = dy + 1 end
  if dx == 0 and dy == 0 then          -- 👃 und losgelassen: das Pferd läuft zum Fund (D3)
    local hx, hy = require("game.schaetze").heading(h, p.x, p.y)
    if hx then dx, dy = hx, hy end
  end
  local walk, gallop = R.speeds(d)
  local tired = d.energie <= 0
  p.running = btn(BTN_B) and not tired
  local speed = p.running and gallop or walk
  if tired then speed = walk * 0.7 end
  if p.jump_t > 0 then speed = max(speed, walk * 1.4) end   -- in der Luft nicht bremsen
  if dx ~= 0 and dy ~= 0 then speed = speed * 0.7071 end
  if dx ~= 0 or dy ~= 0 then
    p.clear = p.jump_t > 0 and p.clear or nil
    local ok_x, ok_y = Body.move(p, dx * speed, dy * speed, ctx.map)
    p.dir = U.facing(dx, dy, p.dir)
    p.moving = (ok_x and dx ~= 0) or (ok_y and dy ~= 0)
    if p.moving then
      p.anim = p.anim + (p.running and 0.18 or 0.11)
      -- Hufschlag: Galopp dichter und lauter als Schritt (nicht in der Luft)
      p.hoof_t = (p.hoof_t or 0) + 1
      local every = p.running and 8 or 15
      if p.hoof_t >= every and p.jump_t == 0 then
        p.hoof_t, p.hoof_n = 0, (p.hoof_n or 0) + 1
        SFX.hoof(p.running, p.hoof_n)
      end
      ctx.trail:push(p.x, p.y)
      -- Staub beim Galopp
      p.dust_t = p.dust_t - 1
      if p.running and p.dust_t <= 0 then
        p.dust_t = 7
        ctx.fx:spawn(p.x - dx * 8, p.y - 1, {sprite = "dust", ground = true, vx = -dx * 0.3, vy = -0.25, life = 16})
      end
    end
    -- Energie: 1 je 10 s Reiten, Galopp doppelt (E30)
    local cost = (p.running and 2 or 1) / (K.stats.energie.reiten_sek * 60) * K.stats.energie.reiten
    d.energie = max(0, d.energie - cost)
    -- Training (E31): Galopp trainiert Tempo (1 je Minute), Reiten Ausdauer (0,5 je Minute)
    if p.moving then
      if p.running then Care.train(d, "tempo", 1 / 3600) end
      Care.train(d, "ausdauer", 0.5 / 3600)
    end
  end
  -- Sprung: in der Luft Höhe nach Bogen; Hindernisse unter dieser Höhe zählen nicht
  if p.jump_t > 0 then
    p.jump_t = p.jump_t + 1
    local t = p.jump_t / R.JUMP_FRAMES
    p.air = math.sin(math.min(1, t) * math.pi) * R.jump_height(d)
    p.clear = max(p.air, 0.01)
    if p.jump_t > R.JUMP_FRAMES then
      -- Landen nur auf freiem Boden, sonst in der Luft weiterrutschen (höchstens 30 Frames)
      if Body.free(ctx.map, p.x, p.y, p.fw, p.fh) then
        SFX.land()
        p.jump_t, p.air, p.clear = 0, 0, nil
      elseif p.jump_t > R.JUMP_FRAMES + 30 then
        p.x, p.y = p.jump_x, p.jump_y
        p.jump_t, p.air, p.clear = 0, 0, nil
      else
        p.clear = R.jump_height(d) * 0.6
        if not Body.free(ctx.map, p.x, p.y, p.fw, p.fh, p.clear) then p.clear = 99 end
      end
    end
  end
end

-- Sprung auslösen (A angetippt). Kostet Energie; ohne Energie kein Sprung.
function R.jump(p)
  local d = p.riding.data
  if p.jump_t > 0 or d.energie < K.stats.energie.sprung then return false end
  d.energie = d.energie - K.stats.energie.sprung
  Care.train(d, "staerke", 0.2)        -- Sprung trainiert Stärke (E31)
  SFX.jump()
  p.jump_t, p.air = 1, 0
  p.jump_x, p.jump_y = p.x, p.y
  return true
end

return R
