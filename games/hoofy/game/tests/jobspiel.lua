-- Selbsttests für die Job-Minispiele (Rückmeldung 1.2.1): gut gespielt gibt es den vollen Lohn, jedes Spiel
-- dauert etwa 20 s, Danebenwerfen und Rumpeln kosten.
local JS = require("game.jobspiel")
local Jobs = require("game.jobs")
local H = require("game.horse_model")
local K = require("game.katalog")
local Rng = require("lib.rng")
local C = require("game.tests.check")

local function job(id)
  for _, j in ipairs(K.jobs.liste) do if j.id == id then return j end end
end

local function horse()
  local d = H.wild({rng = Rng.new(4), rasse = "noriker", zug = "faul"})
  d.bindung, d.alter, d.energie = 60, 1, 80
  d.gen.tempo, d.gen.staerke = 50, 60
  return d
end

-- Spielt bis zum Ende; bot(st) gibt die Eingabe zurück. Gibt Anteil und Frames zurück.
local function play(id, bot)
  local st = JS.new(job(id), horse(), Rng.new(3))
  for n = 1, 3000 do
    JS.update(st, bot(st) or {})
    if st.done then return JS.anteil(st), n end
  end
  error("endet nicht")
end

return {
  {"Postritt: im Rahmen werfen trifft alle, wildes Drücken nicht; etwa 20 s", function()
    local a, n = play("postritt", function(st)
      for _, b in ipairs(st.boxes) do
        if not b.done and st.cool == 0 and math.abs(b.x - st.x - JS.POST_X) <= 4 then return {a = true} end
      end
    end)
    C.eq(a, 1, "alle getroffen")
    C.between(n / 60, 12, 25, "Dauer in s")
    local wild = play("postritt", function(st) return {a = st.t % 7 == 0} end)
    C.ok(wild < 0.8, "Dauerfeuer: " .. wild)
  end},
  {"Kutschtaxi: Fahrgäste einsammeln, Hindernissen ausweichen; nichts tun bringt wenig", function()
    local a, n = play("kutschtaxi", function(st)
      local want = st.lane
      local best
      for _, o in ipairs(st.things) do
        local sx = o.x - st.x
        if not o.weg and sx > JS.TAXI_X - 8 and (not best or o.x < best.x) then best = o end
      end
      if best then
        if best.gast then want = best.lane
        elseif best.lane == st.lane then want = st.lane == 1 and 2 or st.lane - 1 end
      end
      return {up = want < st.lane, down = want > st.lane}
    end)
    C.ok(a >= 0.75, "gut gefahren: " .. a)
    C.between(n / 60, 12, 30, "Dauer in s")
    local lazy = play("kutschtaxi", function() end)
    C.ok(lazy < a, "nichts tun ist schlechter")
  end},
  {"Pflügen: A im Grünen schafft alle Furchen in der Zeit, sonst nichts; stärker = breiter", function()
    local a = play("pfluegen", function(st) return {a = math.abs(st.pos - 0.5) < 0.03} end)
    C.eq(a, 1)
    local none, n = play("pfluegen", function() end)
    C.eq(none, 0)
    C.eq(n, JS.PFLUG_TIME)
    local weak, strong = horse(), horse()
    weak.gen.staerke, strong.gen.staerke = 20, 90
    C.ok(JS.new(job("pfluegen"), strong).zone > JS.new(job("pfluegen"), weak).zone)
  end},
  {"Lohn: 40 % sicher, der Rest nach dem Ergebnis; Energie geht ab", function()
    local d, j = horse(), job("postritt")
    local full = Jobs.lohn(d, j)
    C.eq(Jobs.lohn(d, j, 1), full)
    C.eq(Jobs.lohn(d, j, 0), math.floor(full * 0.4 + 0.5))
    local ctx = {money = 0}
    local e = d.energie
    C.eq(Jobs.run(ctx, j, d, 1, 0.5), Jobs.lohn(d, j, 0.5))
    C.eq(d.energie, e - j.energie)
  end},
}
