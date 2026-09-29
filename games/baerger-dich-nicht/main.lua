-- Bärger dich nicht! Vier Teams, frei wählbare Menschen und Rückwärts-Schlagen.
-- Steuerkreuz: wählen  A: bestätigen/würfeln  B: Namen löschen  START: Namen übernehmen
local S = require('sprites')

local COLORS = {
  {name='ROT', c=8, dark=2, start=0, sprite='bear_red'},
  {name='GELB', c=10, dark=9, start=10, sprite='bear_yellow'},
  {name='GRÜN', c=11, dark=3, start=20, sprite='bear_green'},
  {name='BLAU', c=12, dark=1, start=30, sprite='bear_blue'},
}
local GRID = {
  {0,4},{1,4},{2,4},{3,4},{4,4},{4,3},{4,2},{4,1},{4,0},{5,0},
  {6,0},{6,1},{6,2},{6,3},{6,4},{7,4},{8,4},{9,4},{10,4},{10,5},
  {10,6},{9,6},{8,6},{7,6},{6,6},{6,7},{6,8},{6,9},{6,10},{5,10},
  {4,10},{4,9},{4,8},{4,7},{4,6},{3,6},{2,6},{1,6},{0,6},{0,5},
}
local function cell(col,row) return {70+col*18,29+row*18} end
local TRACK, GOAL, HOME = {}, {}, {}
for i=1,40 do TRACK[i]=cell(GRID[i][1],GRID[i][2]) end
for t=1,4 do GOAL[t]={}; HOME[t]={} end
for i=1,4 do
  GOAL[1][i]=cell(i,5)
  GOAL[2][i]=cell(5,i)
  GOAL[3][i]=cell(10-i,5)
  GOAL[4][i]=cell(5,10-i)
end
HOME[1]={cell(1,1),cell(3,1),cell(1,3),cell(3,3)}
HOME[2]={cell(7,1),cell(9,1),cell(7,3),cell(9,3)}
HOME[3]={cell(7,7),cell(9,7),cell(7,9),cell(9,9)}
HOME[4]={cell(1,7),cell(3,7),cell(1,9),cell(3,9)}
local ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '
local screen='title'
local human_count, setup_player, setup_color, name_cursor = 1,1,1,1
local chosen_colors, player_names = {}, {}
local name_entry=''
local teams, current, roll, roll_attempt, moves, selected = {},1,0,0,{},1
local message, winner, cpu_timer, dice_timer, dice_face = '',nil,0,0,1

local function center(str,y,c,scale)
  scale=scale or 1
  print(str,(SCREEN_W-textw(str,scale))//2,y,c or 7,scale)
end
local function label_color(t)
  return t==2 and 9 or COLORS[t].c
end
local function bear_big(t,x,y,size)
  local r=S.rects[COLORS[t].sprite]
  sspr(S.img,r[1],r[2],r[3],r[4],x,y,size,size)
end
local function player_label(t)
  return teams[t].name..' ('..COLORS[t].name..')'
end
local function free_color(from,step)
  local t=from
  repeat
    t=(t-1+step+4)%4+1
    if not chosen_colors[t] then return t end
  until t==from
  return from
end
local function begin_setup()
  chosen_colors={}; player_names={}; setup_player=1; setup_color=1
  name_cursor=1; name_entry=''; screen='setup_color'
end
local function reset_game()
  teams={}
  for t=1,4 do
    teams[t]={human=chosen_colors[t]~=nil,
      name=chosen_colors[t] and player_names[t] or 'CPU',pieces={-1,-1,-1,-1}}
  end
  current=1; roll=0; roll_attempt=0; moves={}; selected=1
  message=''; winner=nil; cpu_timer=0; dice_timer=0; screen='turn'
end
local function all_finished(team)
  for i=1,4 do if teams[team].pieces[i]<40 then return false end end
  return true
end
local function own_at(team,step,ignore)
  for i=1,4 do if i~=ignore and teams[team].pieces[i]==step then return true end end
  return false
end
local function global_pos(team,step)
  if step<0 or step>=40 then return nil end
  return (COLORS[team].start+step)%40
end
local function opponent_at_global(team,g)
  for t=1,4 do if t~=team then
    for p=1,4 do
      local s=teams[t].pieces[p]
      if s>=0 and s<40 and global_pos(t,s)==g then return t,p end
    end
  end end
  return nil,nil
end
local function can_forward(team,piece,die)
  local s=teams[team].pieces[piece]
  if s<0 then return die==6 and not own_at(team,0,nil) end
  return s+die<=43 and not own_at(team,s+die,piece)
end
local function add_move(piece,dir,dest,label)
  moves[#moves+1]={piece=piece,dir=dir,dest=dest,text=label}
end
local function build_moves(team,die)
  moves={}
  local has_home=false
  for p=1,4 do if teams[team].pieces[p]==-1 then has_home=true end end
  if die==6 and has_home then
    if not own_at(team,0,nil) then
      for p=1,4 do if teams[team].pieces[p]==-1 then add_move(p,'out',0,'Bär '..p..' raussetzen') end end
      return
    end
    for p=1,4 do
      if teams[team].pieces[p]==0 and can_forward(team,p,die) then
        add_move(p,'forward',6,'Start freimachen')
      end
    end
    if #moves>0 then return end
  end
  for p=1,4 do
    local s=teams[team].pieces[p]
    if can_forward(team,p,die) then
      local dest=s<0 and 0 or s+die
      add_move(p,s<0 and 'out' or 'forward',dest,'Bär '..p..' vor')
    end
    if s>=die and s<40 then
      local back=s-die
      if not own_at(team,back,p) and opponent_at_global(team,global_pos(team,back)) then
        add_move(p,'backward',back,'Bär '..p..' rückwärts SCHLAGEN!')
      end
    end
  end
end
local function next_turn()
  current=current%4+1; roll=0; roll_attempt=0; moves={}; selected=1
  cpu_timer=teams[current].human and 0 or 35
  message=''; screen='turn'
end
local function capture_at(team,piece)
  local s=teams[team].pieces[piece]
  if s<0 or s>=40 then return false end
  local ot,op=opponent_at_global(team,global_pos(team,s))
  if ot then
    teams[ot].pieces[op]=-1
    tone(note('C3'),0.12,'noise',0.6)
    return true
  end
  return false
end
local function apply_move(m)
  teams[current].pieces[m.piece]=m.dest
  local hit=capture_at(current,m.piece)
  message=hit and 'ZACK! RAUS MIT DIR!' or m.text
  tone(note(hit and 'E5' or 'C5'),0.08,'square',0.45)
  if all_finished(current) then
    winner=current; screen='win'; tune('C5 E5 G5 C6:2',180,'triangle',0.45)
  elseif roll==6 then
    roll=0; roll_attempt=0; moves={}; selected=1; screen='turn'; cpu_timer=35
  else next_turn() end
end
local function choose_cpu_move()
  local best,best_score=nil,-999
  for _,m in ipairs(moves) do
    local score=0
    if m.dir=='backward' then score=score+90 end
    if m.dir=='out' then score=score+70 end
    if m.dest>=40 then score=score+50+m.dest end
    if m.dest<40 then
      if opponent_at_global(current,global_pos(current,m.dest)) then score=score+100 end
      score=score+m.dest
    end
    if score>best_score then best_score,best=score,m end
  end
  return best
end
local function finish_roll()
  roll=flr(rnd(6))+1
  tone(note('A4'),0.05,'noise',0.35)
  build_moves(current,roll)
  if #moves==0 then
    local no_piece_out=true
    for p=1,4 do
      local s=teams[current].pieces[p]
      if s>=0 and s<40 then no_piece_out=false; break end
    end
    if no_piece_out and roll~=6 and roll_attempt<2 then
      roll_attempt=roll_attempt+1
      message='Noch '..(3-roll_attempt)..' Versuch(e)!'
      roll=0; cpu_timer=30; return
    end
    if roll==6 then roll=0; roll_attempt=0; cpu_timer=35
    else next_turn() end
    return
  end
  selected=1
  if teams[current].human then screen='choose' else cpu_timer=26 end
end
local function start_roll()
  dice_timer=36; dice_face=1; message=''; screen='rolling'
end
local function update_roll()
  dice_timer=dice_timer-1
  if dice_timer%4==0 then
    dice_face=flr(rnd(6))+1
    tone(note('C5'),0.025,'noise',0.18)
  end
  if dice_timer<=0 then screen='turn'; finish_roll() end
end
function _init()
  human_count=1; screen='title'
end
function _update()
  if screen=='title' then
    if btnp(BTN_A) or btnp(BTN_START) then screen='setup_count' end
  elseif screen=='setup_count' then
    if btnp(BTN_LEFT) then human_count=max(1,human_count-1) end
    if btnp(BTN_RIGHT) then human_count=min(4,human_count+1) end
    if btnp(BTN_A) or btnp(BTN_START) then begin_setup() end
    if btnp(BTN_B) then screen='title' end
  elseif screen=='setup_color' then
    if btnp(BTN_LEFT) then setup_color=free_color(setup_color,-1) end
    if btnp(BTN_RIGHT) then setup_color=free_color(setup_color,1) end
    if btnp(BTN_A) or btnp(BTN_START) then
      chosen_colors[setup_color]=setup_player
      name_entry=''; name_cursor=1; screen='setup_name'
    end
    if btnp(BTN_B) then screen='setup_count' end
  elseif screen=='setup_name' then
    if btnp(BTN_LEFT) then name_cursor=(name_cursor-2)%#ALPHABET+1 end
    if btnp(BTN_RIGHT) then name_cursor=name_cursor%#ALPHABET+1 end
    if btnp(BTN_UP) then name_cursor=(name_cursor-1-6)%#ALPHABET+1 end
    if btnp(BTN_DOWN) then name_cursor=(name_cursor-1+6)%#ALPHABET+1 end
    if btnp(BTN_A) and #name_entry<10 then
      name_entry=name_entry..ALPHABET:sub(name_cursor,name_cursor)
      tone(note('C5'),0.04,'square',0.2)
    end
    if btnp(BTN_B) then name_entry=name_entry:sub(1,-2) end
    if btnp(BTN_START) then
      player_names[setup_color]=name_entry:match('^%s*(.-)%s*$')
      if player_names[setup_color]=='' then player_names[setup_color]='SPIELER '..setup_player end
      setup_player=setup_player+1
      if setup_player>human_count then reset_game()
      else setup_color=free_color(setup_color,1); screen='setup_color' end
    end
  elseif screen=='rolling' then update_roll()
  elseif screen=='turn' then
    if teams[current].human then
      if btnp(BTN_A) then start_roll() end
    else
      if cpu_timer>0 then cpu_timer=cpu_timer-1
      elseif roll==0 then start_roll()
      elseif #moves>0 then apply_move(choose_cpu_move()) end
    end
    if btnp(BTN_START) then screen='title' end
  elseif screen=='choose' then
    if btnp(BTN_LEFT) or btnp(BTN_UP) then selected=(selected-2)%#moves+1 end
    if btnp(BTN_RIGHT) or btnp(BTN_DOWN) then selected=selected%#moves+1 end
    if btnp(BTN_A) then apply_move(moves[selected]) end
  elseif screen=='win' then
    if btnp(BTN_A) or btnp(BTN_START) then screen='setup_count' end
  end
end
local function draw_field(x,y,c,filled)
  circfill(x,y,8,7)
  circ(x,y,8,c)
  if filled then circfill(x,y,6,c) else circfill(x,y,5,rgb(250,243,224)) end
end
local function draw_die(face)
  rectfill(150,109,170,129,7)
  rect(150,109,170,129,COLORS[current].c)
  local function pip(dx,dy) circfill(160+dx,119+dy,2,0) end
  if face==1 or face==3 or face==5 then pip(0,0) end
  if face>=2 then pip(-5,-5); pip(5,5) end
  if face>=4 then pip(5,-5); pip(-5,5) end
  if face==6 then pip(-5,0); pip(5,0) end
end
local function draw_board()
  cls(rgb(251,244,225))
  rectfill(51,21,269,217,rgb(238,226,197))
  rect(51,21,269,217,rgb(117,92,70))
  for i=1,40 do
    local p=TRACK[i]; local start=nil
    for t=1,4 do if COLORS[t].start==i-1 then start=COLORS[t].c end end
    draw_field(p[1],p[2],start or rgb(120,108,91),start~=nil)
  end
  for t=1,4 do
    for i=1,4 do
      local g=GOAL[t][i]
      draw_field(g[1],g[2],COLORS[t].c,true)
      local h=HOME[t][i]
      circfill(h[1],h[2],8,rgb(251,244,225)); circ(h[1],h[2],8,COLORS[t].c)
    end
  end
  -- Richtung auf den vier Startfeldern und auf dem Weg ins Ziel.
  print('>',TRACK[1][1]-4,TRACK[1][2]-4,7)
  print('v',TRACK[11][1]-4,TRACK[11][2]-4,0)
  print('<',TRACK[21][1]-4,TRACK[21][2]-4,7)
  print('^',TRACK[31][1]-4,TRACK[31][2]-4,7)
  if screen=='rolling' then draw_die(dice_face)
  elseif roll>0 then draw_die(roll)
  else
    rectfill(150,109,170,129,7); rect(150,109,170,129,5)
    print('?',157,111,5,2)
  end
end
local function piece_xy(team,piece)
  local s=teams[team].pieces[piece]
  local p
  if s<0 then p=HOME[team][piece]
  elseif s<40 then p=TRACK[global_pos(team,s)+1]
  else p=GOAL[team][s-39] end
  return p[1]-7,p[2]-8
end
local function draw_pieces()
  local chosen=screen=='choose' and moves[selected] and moves[selected].piece
  for t=1,4 do for p=1,4 do
    local x,y=piece_xy(t,p)
    if t==current and p==chosen then
      circ(x+7,y+8,10,0); circ(x+7,y+8,9,7)
    end
    S.draw(COLORS[t].sprite,x,y)
  end end
end
local function draw_game()
  draw_board(); draw_pieces()
  rectfill(0,0,319,19,0)
  print(player_label(current),4,5,COLORS[current].c)
  if roll>0 then print('WURF '..roll,246,5,7) end
  if screen=='turn' then
    center(teams[current].human and 'A = würfeln' or 'CPU würfelt ...',224,0)
  elseif screen=='rolling' then
    center(player_label(current)..' würfelt ...',223,0)
  elseif screen=='choose' then
    rectfill(0,218,319,239,0)
    local m=moves[selected]
    print('< '..selected..'/'..#moves..' >',5,224,6)
    print(m.text,85,224,m.dir=='backward' and 10 or 7)
  end
end
function _draw()
  if screen=='title' then
    cls(rgb(255,241,218))
    center('BÄRGER',42,8,4); center('DICH NICHT!',76,12,3)
    for t=1,4 do bear_big(t,63+(t-1)*52,121,30) end
    center('Vier Teams, 1 bis 4 Menschen',172,5)
    center('A / START',208,0,2)
  elseif screen=='setup_count' then
    cls(rgb(255,241,218))
    center('WIE VIELE MENSCHEN?',38,0,2)
    center('<   '..human_count..'   >',88,label_color(human_count),4)
    center(human_count..' Mensch(en) + '..(4-human_count)..' CPU',142,5)
    center('A = Farben wählen',186,0)
  elseif screen=='setup_color' then
    cls(rgb(255,241,218))
    center('SPIELER '..setup_player,24,0,2)
    center('FARBE WÄHLEN',48,0)
    bear_big(setup_color,140,78,40)
    center('< '..COLORS[setup_color].name..' >',128,label_color(setup_color),3)
    center('A = bestätigen',191,0)
  elseif screen=='setup_name' then
    cls(rgb(255,241,218))
    center('NAME FÜR '..COLORS[setup_color].name,12,label_color(setup_color),2)
    center(name_entry=='' and 'SPIELER '..setup_player or name_entry,46,0,2)
    for i=1,#ALPHABET do
      local col=(i-1)%6; local row=(i-1)//6
      local x=76+col*29; local y=83+row*18
      if i==name_cursor then rectfill(x-4,y-2,x+12,y+10,COLORS[setup_color].c) end
      print(ALPHABET:sub(i,i),x,y,i==name_cursor and 7 or 0)
    end
    center('A: Zeichen   B: löschen',211,0)
    center('START: Name übernehmen',225,0)
  elseif screen=='win' then
    cls(COLORS[winner].dark)
    center('GEWONNEN!',50,7,4)
    center(player_label(winner),108,7,2)
    for i=1,4 do S.draw(COLORS[winner].sprite,92+(i-1)*36,150) end
    center('A / START = neues Spiel',207,7)
  else draw_game() end
end
