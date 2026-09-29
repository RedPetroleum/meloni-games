-- Bärger dich nicht! — Mensch-ärgere-dich-nicht-Variante mit Gummibärchen
-- D-pad: auswählen   A: bestätigen / würfeln   B: zurück   START: Startbildschirm

local S = require('sprites')

local COLORS = {
  {name='ROT',    c=8,  dark=2, start=0,  sprite='bear_red'},
  {name='GELB',   c=10, dark=9, start=10, sprite='bear_yellow'},
  {name='GRÜN',   c=11, dark=3, start=20, sprite='bear_green'},
  {name='BLAU',   c=12, dark=1, start=30, sprite='bear_blue'},
}

local TRACK = {}
local GOAL = {}
local HOME = {}

for i=0,9 do TRACK[#TRACK+1] = {70+i*18, 30} end
for i=0,9 do TRACK[#TRACK+1] = {250, 48+i*18} end
for i=0,9 do TRACK[#TRACK+1] = {232-i*18, 210} end
for i=0,9 do TRACK[#TRACK+1] = {52, 192-i*18} end

GOAL[1] = {{88,48},{106,66},{124,84},{142,102}}
GOAL[2] = {{232,48},{214,66},{196,84},{178,102}}
GOAL[3] = {{232,192},{214,174},{196,156},{178,138}}
GOAL[4] = {{88,192},{106,174},{124,156},{142,138}}

HOME[1] = {{79,72},{103,72},{79,96},{103,96}}
HOME[2] = {{217,72},{241,72},{217,96},{241,96}}
HOME[3] = {{217,144},{241,144},{217,168},{241,168}}
HOME[4] = {{79,144},{103,144},{79,168},{103,168}}

local screen = 'title'
local human_count = 1
local teams = {}
local current = 1
local roll = 0
local roll_attempt = 0
local moves = {}
local selected = 1
local message = ''
local winner = nil
local cpu_timer = 0
local last_player = nil
local extra_turn = false

local function center(text, y, c, scale)
  scale = scale or 1
  print(text, (SCREEN_W-textw(text,scale))//2, y, c or 7, scale)
end

local function reset_game()
  teams = {}
  for t=1,4 do
    teams[t] = {human = t <= human_count, pieces = {-1,-1,-1,-1}}
  end
  current = 1
  roll = 0
  roll_attempt = 0
  moves = {}
  selected = 1
  message = ''
  winner = nil
  cpu_timer = 0
  last_player = nil
  extra_turn = false
  screen = teams[current].human and 'pass' or 'turn'
end

local function all_finished(team)
  for i=1,4 do if teams[team].pieces[i] < 40 then return false end end
  return true
end

local function own_at(team, step, ignore_piece)
  for i=1,4 do
    if i ~= ignore_piece and teams[team].pieces[i] == step then return true end
  end
  return false
end

local function global_pos(team, step)
  if step < 0 or step >= 40 then return nil end
  return (COLORS[team].start + step) % 40
end

local function opponent_at_global(team, g)
  for t=1,4 do
    if t ~= team then
      for p=1,4 do
        local s = teams[t].pieces[p]
        if s >= 0 and s < 40 and global_pos(t,s) == g then return t,p end
      end
    end
  end
  return nil,nil
end

local function start_blocked_by_own(team)
  return own_at(team, 0, nil)
end

local function can_forward(team, piece, die)
  local s = teams[team].pieces[piece]
  if s < 0 then
    if die ~= 6 then return false end
    return not start_blocked_by_own(team)
  end
  local dest = s + die
  if dest > 43 then return false end
  if own_at(team, dest, piece) then return false end
  return true
end

local function add_move(piece, dir, dest, text)
  moves[#moves+1] = {piece=piece, dir=dir, dest=dest, text=text}
end

local function build_moves(team, die)
  moves = {}
  local has_home = false
  for p=1,4 do if teams[team].pieces[p] == -1 then has_home = true break end end

  if die == 6 and has_home then
    if not start_blocked_by_own(team) then
      for p=1,4 do
        if teams[team].pieces[p] == -1 then
          add_move(p, 'out', 0, 'Bär '..p..' raussetzen')
        end
      end
      return
    else
      for p=1,4 do
        if teams[team].pieces[p] == 0 and can_forward(team,p,die) then
          add_move(p, 'forward', 6, 'Start freimachen')
        end
      end
      if #moves > 0 then return end
    end
  end

  for p=1,4 do
    local s = teams[team].pieces[p]
    if can_forward(team,p,die) then
      local dest = (s < 0) and 0 or (s + die)
      add_move(p, s < 0 and 'out' or 'forward', dest, 'Bär '..p..' vor')
    end
    if s >= die and s < 40 then
      local back = s - die
      if not own_at(team, back, p) then
        local g = global_pos(team, back)
        local ot = opponent_at_global(team, g)
        if ot then add_move(p, 'backward', back, 'Bär '..p..' rückwärts SCHLAGEN!') end
      end
    end
  end
end

local function capture_at(team, piece)
  local s = teams[team].pieces[piece]
  if s < 0 or s >= 40 then return false end
  local g = global_pos(team,s)
  local ot,op = opponent_at_global(team,g)
  if ot then
    teams[ot].pieces[op] = -1
    tone(note('C3'),0.12,'noise',0.6)
    return true
  end
  return false
end

local function apply_move(m)
  teams[current].pieces[m.piece] = m.dest
  local hit = capture_at(current, m.piece)
  if hit then message = 'ZACK! RAUS MIT DIR!' else message = m.text end
  tone(note(hit and 'E5' or 'C5'),0.08,'square',0.45)

  if all_finished(current) then
    winner = current
    screen = 'win'
    tune('C5 E5 G5 C6:2',180,'triangle',0.45)
    return
  end

  if roll == 6 then
    extra_turn = true
    roll = 0
    roll_attempt = 0
    moves = {}
    selected = 1
    screen = 'turn'
    cpu_timer = 18
  else
    extra_turn = false
    last_player = current
    current = current % 4 + 1
    roll = 0
    roll_attempt = 0
    moves = {}
    selected = 1
    message = ''
    cpu_timer = 22
    if teams[current].human then screen = 'pass' else screen = 'turn' end
  end
end

local function choose_cpu_move()
  if #moves == 0 then return nil end
  local best = moves[1]
  local best_score = -999
  for _,m in ipairs(moves) do
    local score = 0
    if m.dir == 'backward' then score = score + 90 end
    if m.dir == 'out' then score = score + 70 end
    if m.dest >= 40 then score = score + 50 + m.dest end
    if m.dest < 40 then
      local g = global_pos(current,m.dest)
      if opponent_at_global(current,g) then score = score + 100 end
      score = score + m.dest
    end
    if score > best_score then best_score, best = score, m end
  end
  return best
end

local function do_roll()
  roll = flr(rnd(6)) + 1
  tone(note('A4'),0.05,'noise',0.35)
  build_moves(current,roll)

  if #moves == 0 then
    local no_piece_out = true
    for p=1,4 do
      local s = teams[current].pieces[p]
      if s >= 0 and s < 40 then no_piece_out = false break end
    end

    if no_piece_out and roll ~= 6 and roll_attempt < 2 then
      roll_attempt = roll_attempt + 1
      message = 'Nichts geht. Noch '..(3-roll_attempt)..' Versuch(e)!'
      roll = 0
      return
    end

    message = 'Kein gültiger Zug.'
    if roll == 6 then
      roll = 0
      roll_attempt = 0
      cpu_timer = 24
    else
      last_player = current
      current = current % 4 + 1
      roll = 0
      roll_attempt = 0
      cpu_timer = 28
      if teams[current].human then screen = 'pass' end
    end
    return
  end

  selected = 1
  if teams[current].human then
    screen = 'choose'
  else
    cpu_timer = 22
  end
end

local function update_title()
  if btnp(BTN_A) or btnp(BTN_START) then screen = 'setup' end
end

local function update_setup()
  if btnp(BTN_LEFT) then human_count = max(1,human_count-1) end
  if btnp(BTN_RIGHT) then human_count = min(4,human_count+1) end
  if btnp(BTN_A) or btnp(BTN_START) then reset_game() end
  if btnp(BTN_B) then screen = 'title' end
end

local function update_pass()
  if btnp(BTN_A) or btnp(BTN_START) then
    screen = 'turn'
    message = ''
    cpu_timer = 0
  end
end

local function update_turn()
  if teams[current].human then
    if btnp(BTN_A) then do_roll() end
  else
    if cpu_timer > 0 then cpu_timer = cpu_timer - 1 return end
    if roll == 0 then
      do_roll()
      if screen ~= 'turn' then return end
    end
    if #moves > 0 then
      local m = choose_cpu_move()
      if m then apply_move(m) end
    end
  end
end

local function update_choose()
  if #moves == 0 then screen = 'turn' return end
  if btnp(BTN_LEFT) or btnp(BTN_UP) then selected = selected - 1; if selected < 1 then selected = #moves end end
  if btnp(BTN_RIGHT) or btnp(BTN_DOWN) then selected = selected + 1; if selected > #moves then selected = 1 end end
  if btnp(BTN_A) then apply_move(moves[selected]) end
end

function _init()
  human_count = 1
  screen = 'title'
end

function _update()
  if btnp(BTN_START) and screen ~= 'title' and screen ~= 'setup' and screen ~= 'pass' then
    screen = 'title'
    return
  end
  if screen == 'title' then update_title()
  elseif screen == 'setup' then update_setup()
  elseif screen == 'pass' then update_pass()
  elseif screen == 'turn' then update_turn()
  elseif screen == 'choose' then update_choose()
  elseif screen == 'win' then
    if btnp(BTN_A) or btnp(BTN_START) then screen = 'setup' end
  end
end

local function draw_field(x,y,c,filled)
  if filled then circfill(x,y,7,c) else circfill(x,y,7,6); circ(x,y,7,c) end
end

local function draw_board()
  cls(rgb(251,244,225))
  rectfill(44,22,258,218,rgb(238,226,197))
  rect(44,22,258,218,rgb(117,92,70))

  for i=1,40 do
    local t = TRACK[i]
    local start_color = nil
    for team=1,4 do if COLORS[team].start == i-1 then start_color = COLORS[team].c end end
    draw_field(t[1],t[2],start_color or 5,start_color ~= nil)
  end

  for team=1,4 do
    for i=1,4 do
      local g = GOAL[team][i]
      draw_field(g[1],g[2],COLORS[team].c,true)
      local h = HOME[team][i]
      circ(h[1],h[2],8,COLORS[team].c)
    end
  end

  rectfill(137,107,165,135,7)
  rect(137,107,165,135,5)
  if roll > 0 then print(tostring(roll),145,111,COLORS[current].c,2)
  else print('?',145,111,5,2) end
end

local function piece_xy(team,piece)
  local s = teams[team].pieces[piece]
  if s < 0 then return HOME[team][piece][1]-7, HOME[team][piece][2]-8 end
  if s < 40 then
    local p = TRACK[global_pos(team,s)+1]
    return p[1]-7,p[2]-8
  end
  local g = GOAL[team][s-39]
  return g[1]-7,g[2]-8
end

local function draw_pieces()
  local chosen_piece = nil
  if screen == 'choose' and moves[selected] then chosen_piece = moves[selected].piece end
  for t=1,4 do
    for p=1,4 do
      local x,y = piece_xy(t,p)
      if t == current and p == chosen_piece then
        circ(x+7,y+8,10,7)
        circ(x+7,y+8,9,0)
      end
      S.draw(COLORS[t].sprite,x,y)
    end
  end
end

local function draw_status()
  rectfill(0,0,319,18,0)
  print(COLORS[current].name,4,5,COLORS[current].c)
  local who = teams[current].human and 'MENSCH' or 'CPU'
  print(who,70,5,6)
  if roll > 0 then print('WURF '..roll,244,5,7) end
end

local function draw_game()
  draw_board()
  draw_pieces()
  draw_status()
  if screen == 'turn' then
    local txt = teams[current].human and 'A = würfeln' or 'Computer denkt...'
    center(txt,221,0)
  elseif screen == 'choose' then
    rectfill(8,218,311,239,0)
    local m = moves[selected]
    print('< '..selected..'/'..#moves..' >',12,224,6)
    print(m.text,90,224,m.dir == 'backward' and 10 or 7)
  end
end

function _draw()
  if screen == 'title' then
    cls(rgb(255,241,218))
    center('BÄRGER',42,8,4)
    center('DICH NICHT!',76,12,3)
    S.draw('bear_red',83,125); S.draw('bear_yellow',127,125)
    S.draw('bear_green',171,125); S.draw('bear_blue',215,125)
    center('Mensch ärgere dich nicht',164,5)
    center('mit Gummibärchen + fieser Rückwärtsregel',180,5)
    center('A / START',208,0,2)
    return
  elseif screen == 'setup' then
    cls(rgb(255,241,218))
    center('WIE VIELE ECHTE SPIELER?',38,0,2)
    center('<   '..human_count..'   >',88,COLORS[human_count].c,4)
    local cpus = 4-human_count
    center(human_count..' Mensch(en) + '..cpus..' Computer',138,5)
    center('Farben: Rot, Gelb, Grün, Blau',158,5)
    center('A = los   B = zurück',202,0)
    return
  elseif screen == 'pass' then
    cls(COLORS[current].dark)
    center('NICHT SPICKEN!',42,7,3)
    center('Gamegirl weitergeben an',93,7)
    center(COLORS[current].name,116,COLORS[current].c,4)
    center('Nur '..COLORS[current].name..' darf jetzt gucken.',166,7)
    center('A / START wenn bereit',204,7)
    return
  elseif screen == 'win' then
    cls(COLORS[winner].dark)
    center('GEWONNEN!',50,7,4)
    center(COLORS[winner].name,100,COLORS[winner].c,4)
    for i=1,4 do S.draw(COLORS[winner].sprite,92+(i-1)*36,150) end
    center('A / START = neues Spiel',207,7)
    return
  end
  draw_game()
end
