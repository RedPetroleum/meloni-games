-- Spielstand: freigeschaltete Level und beste Restzeit pro Level (in Frames).
local Save = {}

local data

local function load()
  if not data then
    data = loaddata() or {}
    data.unlocked = data.unlocked or 1
    data.best = data.best or {}
  end
  return data
end

function Save.unlocked() return load().unlocked end

function Save.best(n) return load().best[n] end

function Save.level_done(n, frames_left, level_count)
  local d = load()
  d.unlocked = max(d.unlocked, min(n + 1, level_count))
  if not d.best[n] or frames_left > d.best[n] then d.best[n] = frames_left end
  savedata(d)
end

return Save
