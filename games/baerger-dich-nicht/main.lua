-- Bärger dich nicht! Vier Teams, frei wählbare Menschen und Rückwärts-Schlagen.
-- Im Spiel: A würfeln, links/rechts Bär 1–4 wählen, hoch: vor, runter: zurück (nur zum Schlagen)
-- Einrichten: Steuerkreuz wählen, A bestätigen, B zurück/löschen, START Namen übernehmen
local S = require('sprites')

local COLORS = {
  {name='ROT', c=8, dark=2, start=0, sprite='bear_red', fill=rgb(217,74,74), light=rgb(255,218,212)},
  {name='GELB', c=10, dark=9, start=10, sprite='bear_yellow', fill=rgb(240,189,54), light=rgb(255,240,194)},
  {name='GRÜN', c=11, dark=3, start=20, sprite='bear_green', fill=rgb(80,168,90), light=rgb(212,240,210)},
  {name='BLAU', c=12, dark=1, start=30, sprite='bear_blue', fill=rgb(77,120,216), light=rgb(212,224,255)},
}
local BG, INK = rgb(255,241,218), rgb(58,39,50)
local WOOD, BOARD = rgb(150,104,68), rgb(243,228,194)
local FIELD, RIM, SHADOW = rgb(255,251,240), rgb(128,101,80), rgb(204,180,140)
local GRID = {
  {0,4},{1,4},{2,4},{3,4},{4,4},{4,3},{4,2},{4,1},{4,0},{5,0},
  {6,0},{6,1},{6,2},{6,3},{6,4},{7,4},{8,4},{9,4},{10,4},{10,5},
  {10,6},{9,6},{8,6},{7,6},{6,6},{6,7},{6,8},{6,9},{6,10},{5,10},
  {4,10},{4,9},{4,8},{4,7},{4,6},{3,6},{2,6},{1,6},{0,6},{0,5},
}
local function cell(col,row) return {65+col*19,15+row*19} end
local TRACK, GOAL, HOME = {}, {}, {}
for i=1,40 do TRACK[i]=cell(GRID[i][1],GRID[i][2]) end
for t=1,4 do GOAL[t]={}; HOME[t]={} end
for i=1,4 do
  GOAL[1][i]=cell(i,5)
  GOAL[2][i]=cell(5,i)
  GOAL[3][i]=cell(10-i,5)
  GOAL[4][i]=cell(5,10-i)
end
-- Häuser: vier Plätze eng beieinander, Richtung Ecke
for t,c in ipairs({{1.7,1.7},{8.3,1.7},{8.3,8.3},{1.7,8.3}}) do
  local m=cell(c[1],c[2]); m[1]=flr(m[1]+0.5); m[2]=flr(m[2]+0.5)
  HOME[t]={{m[1]-10,m[2]-10},{m[1]+10,m[2]-10},{m[1]-10,m[2]+10},{m[1]+10,m[2]+10}}
end
local ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '
local MAX_SAVED=8

local screen='title'
local human_count, setup_player, setup_color, name_cursor, pick_index = 1,1,1,1,1
local chosen_colors, player_names, pick_list = {}, {}, {}
local name_entry=''
local saved={recent={}, by_color={}}
local teams, current, roll, shown_roll, roll_attempt, moves, selected = {},1,0,0,0,{},1
local message, sub, winner, timer, dice_timer, dice_face = '','',nil,0,0,1
local hint, hint_timer, shake = '',0,0
local anim, cap, cpu_move, after_info = nil,nil,nil,nil

local function center(str,y,c,scale)
  scale=scale or 1
  print(str,(SCREEN_W-textw(str,scale))//2,y,c or 7,scale)
end
local function center_at(str,cx,y,c)
  print(str,cx-textw(str)//2,y,c)
end
local function rrect(x0,y0,x1,y1,r,c)
  rectfill(x0+r,y0,x1-r,y1,c); rectfill(x0,y0+r,x1,y1-r,c)
  circfill(x0+r,y0+r,r,c); circfill(x1-r,y0+r,r,c)
  circfill(x0+r,y1-r,r,c); circfill(x1-r,y1-r,r,c)
end
local function label_color(t)
  return t==2 and 9 or COLORS[t].c
end
local function bear_big(t,x,y,size,flip)
  local r=S.rects[COLORS[t].sprite]
  sspr(S.img,r[1],r[2],r[3],r[4],x,y,size,size,flip,flip)
end
local function player_label(t)
  return teams[t].name..' ('..COLORS[t].name..')'
end

-- Einrichten ----------------------------------------------------------------

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
local function back_to_color()
  chosen_colors[setup_color]=nil; screen='setup_color'
end
-- Liste gespeicherter Namen, die in diesem Spiel noch frei sind. false = neuen Namen eingeben.
local function begin_pick()
  local taken={}
  for t=1,4 do if player_names[t] then taken[player_names[t]]=true end end
  pick_list={}
  for _,n in ipairs(saved.recent) do if not taken[n] then pick_list[#pick_list+1]=n end end
  if #pick_list==0 then return false end
  pick_index=1
  for i,n in ipairs(pick_list) do if n==saved.by_color[setup_color] then pick_index=i end end
  pick_list[#pick_list+1]=false
  screen='setup_pick'
  return true
end
local function begin_name()
  name_entry=''; name_cursor=1; screen='setup_name'
end
local function remember_names()
  for t=1,4 do
    local n=chosen_colors[t] and player_names[t]
    if n and not n:match('^MENSCH %d$') then
      for i=#saved.recent,1,-1 do if saved.recent[i]==n then table.remove(saved.recent,i) end end
      table.insert(saved.recent,1,n)
      saved.by_color[t]=n
    end
  end
  while #saved.recent>MAX_SAVED do table.remove(saved.recent) end
  savedata({recent=saved.recent, by_color=saved.by_color})
end

-- Regeln ----------------------------------------------------------------------

local function reset_game()
  remember_names()
  teams={}
  for t=1,4 do
    teams[t]={human=chosen_colors[t]~=nil,
      name=chosen_colors[t] and player_names[t] or 'CPU',pieces={-1,-1,-1,-1}}
  end
  current=1; roll=0; shown_roll=0; roll_attempt=0; moves={}; selected=1
  message=''; sub=''; winner=nil; timer=teams[1].human and 0 or 35; dice_timer=0
  anim=nil; cap=nil; cpu_move=nil; hint_timer=0; screen='turn'
end
local function all_finished(team)
  for i=1,4 do if teams[team].pieces[i]<40 then return false end end
  return true
end
local function in_goal(team)
  local n=0
  for i=1,4 do if teams[team].pieces[i]>=40 then n=n+1 end end
  return n
end
local function has_home(team)
  for i=1,4 do if teams[team].pieces[i]<0 then return true end end
  return false
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
-- Mittelpunkt des Feldes, auf dem Bär `piece` von `team` bei Schritt s steht.
local function field_xy(team,piece,s)
  local p
  if s<0 then p=HOME[team][piece]
  elseif s<40 then p=TRACK[global_pos(team,s)+1]
  else p=GOAL[team][s-39] end
  return p[1],p[2]
end
local function can_forward(team,piece,die)
  local s=teams[team].pieces[piece]
  if s<0 then return die==6 and not own_at(team,0,nil) end
  return s+die<=43 and not own_at(team,s+die,piece)
end
local function add_move(piece,dir,dest)
  moves[#moves+1]={piece=piece,dir=dir,dest=dest}
end
local function build_moves(team,die)
  moves={}
  if die==6 and has_home(team) then
    if not own_at(team,0,nil) then
      for p=1,4 do if teams[team].pieces[p]==-1 then add_move(p,'out',0) end end
      return
    end
    for p=1,4 do
      if teams[team].pieces[p]==0 and can_forward(team,p,die) then add_move(p,'forward',6) end
    end
    if #moves>0 then return end
  end
  for p=1,4 do
    local s=teams[team].pieces[p]
    if can_forward(team,p,die) then add_move(p,s<0 and 'out' or 'forward',s<0 and 0 or s+die) end
    if s>=die and s<40 then
      local back=s-die
      if not own_at(team,back,p) and opponent_at_global(team,global_pos(team,back)) then
        add_move(p,'backward',back)
      end
    end
  end
end
local function find_move(piece,dir)
  for _,m in ipairs(moves) do
    if m.piece==piece and (m.dir==dir or (dir=='forward' and m.dir=='out')) then return m end
  end
  return nil
end
-- Warum Bär `piece` nicht in Richtung `dir` ziehen darf (nil: er darf).
local function why_not(piece,dir)
  if find_move(piece,dir) then return nil end
  local team=current; local s=teams[team].pieces[piece]
  if dir=='forward' then
    if s<0 and roll~=6 then return 'Raus kommt ein Bär nur mit einer 6.' end
    if s<0 then return 'Dein Startfeld ist besetzt.' end
    if s+roll>43 then return 'Zu weit, das passt nicht ins Ziel.' end
    if own_at(team,s+roll,piece) then return 'Da steht schon ein eigener Bär.' end
  else
    if s<0 then return 'Der Bär ist noch zu Hause.' end
    if s>=40 then return 'Aus dem Ziel geht es nicht zurück.' end
    if s<roll then return 'So weit zurück geht es nicht.' end
    if own_at(team,s-roll,piece) then return 'Da steht schon ein eigener Bär.' end
    if not opponent_at_global(team,global_pos(team,s-roll)) then return 'Zurück nur, wenn du schlägst.' end
  end
  -- Der Zug ginge, aber eine Pflicht geht vor.
  if roll==6 and has_home(team) then
    if own_at(team,0,nil) then return 'Erst das Startfeld frei machen!' end
    return 'Bei einer 6 musst du raussetzen!'
  end
  return 'Dieser Zug geht nicht.'
end
local function next_turn()
  current=current%4+1; roll=0; shown_roll=0; roll_attempt=0; moves={}; selected=1
  timer=teams[current].human and 0 or 35
  message=''; sub=''; cpu_move=nil; screen='turn'
end
local function roll_again()
  roll=0; roll_attempt=0; moves={}; cpu_move=nil
  timer=teams[current].human and 0 or 35; screen='turn'
end
local function info(msg,below,after)
  message=msg; sub=below; after_info=after; timer=90; screen='info'
end
local function after_move()
  if all_finished(current) then
    winner=current; screen='win'; tune('C5 E5 G5 C6:2',180,'triangle',0.45)
  elseif roll==6 then
    roll_again(); message='Eine 6! Nochmal würfeln.'; sub=''
  else next_turn() end
end
local function start_capture(ot,op)
  local x,y=field_xy(ot,op,teams[ot].pieces[op])
  local hx,hy=field_xy(ot,op,-1)
  teams[ot].pieces[op]=-1
  cap={team=ot,piece=op,x=x,y=y,hx=hx,hy=hy,t=0}
  message='ZACK! '..COLORS[current].name..' schlägt '..COLORS[ot].name..'!'
  sub=teams[ot].name..' muss zurück nach Hause.'
  tone(note('C3'),0.2,'noise',0.7); tone(note('G5'),0.12,'square',0.4)
  screen='capture'
end
local function finish_move()
  local m=anim.m
  anim=nil
  teams[current].pieces[m.piece]=m.dest
  if m.dest<40 then
    local ot,op=opponent_at_global(current,global_pos(current,m.dest))
    if ot then start_capture(ot,op); return end
  end
  after_move()
end
local function start_move(m)
  local team=current; local from=teams[team].pieces[m.piece]
  local path={{field_xy(team,m.piece,from)}}
  if m.dir=='out' then path[2]={field_xy(team,m.piece,0)}
  else
    local step=m.dir=='backward' and -1 or 1
    for s=from+step,m.dest,step do path[#path+1]={field_xy(team,m.piece,s)} end
  end
  anim={m=m,path=path,i=1,t=0,len=m.dir=='out' and 18 or 10}
  selected=m.piece; hint_timer=0
  message=m.dir=='out' and 'Bär '..m.piece..' kommt raus!'
    or 'Bär '..m.piece..(m.dir=='backward' and ' zieht '..roll..' zurück' or ' zieht '..roll..' vor')
  sub=''
  screen='moving'
end
local function update_move()
  anim.t=anim.t+1
  if anim.t>=anim.len then
    anim.t=0; anim.i=anim.i+1
    tone(360+anim.i*50,0.05,'triangle',0.35)
    if anim.i>=#anim.path then finish_move() end
  end
end
local function update_capture()
  cap.t=cap.t+1
  if cap.t==20 then tune('C6:0.5 A5:0.5 F5:0.5 D5:0.5 B4:0.5 G4:1',420,'triangle',0.4) end
  if cap.t>=64 then
    cap=nil; tone(note('C4'),0.1,'square',0.3)
    after_move()
  end
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
  roll=flr(rnd(6))+1; shown_roll=roll
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
      local left=3-roll_attempt
      message=roll..' gewürfelt, keine 6.'
      sub='Noch '..left..(left==1 and ' Versuch.' or ' Versuche.')
      roll=0; timer=teams[current].human and 0 or 50; screen='turn'; return
    end
    if roll==6 then info('6 gewürfelt, aber kein Zug möglich.','Nochmal würfeln!',roll_again)
    elseif no_piece_out then roll_attempt=3; info(roll..' gewürfelt, wieder keine 6.','Der Nächste ist dran.',next_turn)
    else info(roll..' gewürfelt: kein Zug möglich.','Der Nächste ist dran.',next_turn) end
    return
  end
  message=roll..' gewürfelt!'; sub=''
  if teams[current].human then
    selected=moves[1].piece; hint_timer=0; screen='choose'
  else
    cpu_move=nil; timer=30; screen='cpu'
  end
end
local function start_roll()
  dice_timer=36; dice_face=1; message=''; sub=''; screen='rolling'
end
local function update_roll()
  dice_timer=dice_timer-1
  if dice_timer%4==0 then
    dice_face=flr(rnd(6))+1
    tone(note('C5'),0.025,'noise',0.18)
  end
  if dice_timer<=0 then finish_roll() end
end
local function try_move(dir)
  local m=find_move(selected,dir)
  if m then start_move(m); return end
  hint=why_not(selected,dir); hint_timer=150; shake=14
  tone(note('C3'),0.12,'saw',0.3)
end

-- Ablauf ----------------------------------------------------------------------

function _init()
  human_count=1; screen='title'
  local d=loaddata()
  if type(d)=='table' then
    if type(d.recent)=='table' then saved.recent=d.recent end
    if type(d.by_color)=='table' then saved.by_color=d.by_color end
  end
end
function _update()
  -- Wann jemand drückt, mischt den Zufall: sonst würfelt die Konsole nach jedem Start gleich.
  rnd()
  if hint_timer>0 then hint_timer=hint_timer-1 end
  if shake>0 then shake=shake-1 end
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
      if not begin_pick() then begin_name() end
    end
    if btnp(BTN_B) then screen='setup_count' end
  elseif screen=='setup_pick' or screen=='setup_name' then
    local name=nil
    if screen=='setup_pick' then
      if btnp(BTN_UP) then pick_index=(pick_index-2)%#pick_list+1 end
      if btnp(BTN_DOWN) then pick_index=pick_index%#pick_list+1 end
      if btnp(BTN_A) or btnp(BTN_START) then
        if pick_list[pick_index] then name=pick_list[pick_index] else begin_name() end
      elseif btnp(BTN_B) then back_to_color() end
    else
      if btnp(BTN_LEFT) then name_cursor=(name_cursor-2)%#ALPHABET+1 end
      if btnp(BTN_RIGHT) then name_cursor=name_cursor%#ALPHABET+1 end
      if btnp(BTN_UP) then name_cursor=(name_cursor-1-6)%#ALPHABET+1 end
      if btnp(BTN_DOWN) then name_cursor=(name_cursor-1+6)%#ALPHABET+1 end
      if btnp(BTN_A) and #name_entry<10 then
        name_entry=name_entry..ALPHABET:sub(name_cursor,name_cursor)
        tone(note('C5'),0.04,'square',0.2)
      end
      if btnp(BTN_B) then
        if name_entry~='' then name_entry=name_entry:sub(1,-2)
        elseif not begin_pick() then back_to_color() end
      end
      if btnp(BTN_START) then
        name=name_entry:match('^%s*(.-)%s*$')
        if name=='' then name='MENSCH '..setup_player end
      end
    end
    if name then
      player_names[setup_color]=name
      setup_player=setup_player+1
      if setup_player>human_count then reset_game()
      else setup_color=free_color(setup_color,1); screen='setup_color' end
    end
  elseif screen=='rolling' then update_roll()
  elseif screen=='turn' then
    if teams[current].human then
      if btnp(BTN_A) then start_roll() end
    elseif timer>0 then timer=timer-1
    else start_roll() end
    if btnp(BTN_START) then screen='title' end
  elseif screen=='choose' then
    if btnp(BTN_LEFT) then selected=(selected-2)%4+1; hint_timer=0 end
    if btnp(BTN_RIGHT) then selected=selected%4+1; hint_timer=0 end
    if btnp(BTN_UP) then try_move('forward')
    elseif btnp(BTN_DOWN) then try_move('backward') end
  elseif screen=='cpu' then
    if timer>0 then timer=timer-1
    elseif not cpu_move then cpu_move=choose_cpu_move(); selected=cpu_move.piece; timer=28
    else start_move(cpu_move); cpu_move=nil end
  elseif screen=='moving' then update_move()
  elseif screen=='capture' then update_capture()
  elseif screen=='info' then
    timer=timer-1
    if timer<=0 or (teams[current].human and btnp(BTN_A)) then after_info() end
  elseif screen=='win' then
    if btnp(BTN_A) or btnp(BTN_START) then screen='setup_count' end
  end
end

-- Zeichnen --------------------------------------------------------------------

-- kurzer Strich zwischen zwei Nachbarfeldern (die Felder decken den Rest ab)
local function link(a,b,c)
  rectfill(min(a[1],b[1]),min(a[2],b[2]),max(a[1],b[1])+1,max(a[2],b[2])+1,c)
end
local function draw_field(x,y,c,gloss)
  circfill(x,y,8,RIM)
  circfill(x,y,7,c)
  if gloss then circfill(x-2,y-3,2,gloss) end
end
local function draw_board()
  cls(BG)
  rrect(54,3,269,218,7,SHADOW)
  rrect(52,1,267,216,7,WOOD)
  rrect(55,4,264,213,5,BOARD)
  -- Häuser
  for t=1,4 do
    local a,b=HOME[t][1],HOME[t][4]
    rrect(a[1]-11,a[2]-11,b[1]+11,b[2]+11,6,COLORS[t].fill)
    rrect(a[1]-9,a[2]-9,b[1]+9,b[2]+9,4,COLORS[t].light)
  end
  -- Schatten, dann Striche, dann Felder: O-O-O, mit Abzweigung ins Ziel
  for i=1,40 do circfill(TRACK[i][1]+1,TRACK[i][2]+2,8,SHADOW) end
  for t=1,4 do for i=1,4 do circfill(GOAL[t][i][1]+1,GOAL[t][i][2]+2,8,SHADOW) end end
  for i=1,40 do link(TRACK[i],TRACK[i%40+1],RIM) end
  for t=1,4 do
    link(TRACK[(COLORS[t].start+39)%40+1],GOAL[t][1],COLORS[t].fill)
    for i=1,3 do link(GOAL[t][i],GOAL[t][i+1],COLORS[t].fill) end
  end
  for i=1,40 do
    local p=TRACK[i]; local start=nil
    for t=1,4 do if COLORS[t].start==i-1 then start=t end end
    if start then draw_field(p[1],p[2],COLORS[start].fill,COLORS[start].light)
    else draw_field(p[1],p[2],FIELD) end
  end
  for t=1,4 do
    for i=1,4 do
      local g=GOAL[t][i]
      draw_field(g[1],g[2],COLORS[t].fill,COLORS[t].light)
      local h=HOME[t][i]
      circfill(h[1],h[2],7,COLORS[t].fill); circfill(h[1],h[2],5,FIELD)
    end
  end
  -- Richtung auf den vier Startfeldern
  print('>',TRACK[1][1]-3,TRACK[1][2]-3,7)
  print('v',TRACK[11][1]-3,TRACK[11][2]-4,INK)
  print('<',TRACK[21][1]-4,TRACK[21][2]-3,7)
  print('^',TRACK[31][1]-3,TRACK[31][2]-2,7)
  -- Mitte: Blume in den vier Farben
  local m=cell(5,5)
  circfill(m[1],m[2],8,RIM); circfill(m[1],m[2],7,FIELD)
  circfill(m[1]-3,m[2]-3,3,COLORS[1].fill); circfill(m[1]+3,m[2]-3,3,COLORS[2].fill)
  circfill(m[1]+3,m[2]+3,3,COLORS[3].fill); circfill(m[1]-3,m[2]+3,3,COLORS[4].fill)
  circfill(m[1],m[2],1,7)
end
local function draw_die(x,y,face)
  rrect(x+2,y+3,x+37,y+38,6,SHADOW)
  rrect(x,y,x+35,y+35,6,INK)
  rrect(x+2,y+2,x+33,y+33,5,7)
  if not face then print('?',x+10,y+10,5,2); return end
  local cx,cy=x+17,y+17
  local function pip(dx,dy) circfill(cx+dx,cy+dy,3,INK) end
  if face==1 or face==3 or face==5 then pip(0,0) end
  if face>=2 then pip(-9,-9); pip(9,9) end
  if face>=4 then pip(9,-9); pip(-9,9) end
  if face==6 then pip(-9,0); pip(9,0) end
end
local function arrow_down(x,y,c)
  for i=0,7 do line(x-7+i,y+i,x+7-i,y+i,INK) end
  for i=0,5 do line(x-5+i,y+1+i,x+5-i,y+1+i,c or 7) end
end
-- Bär vergrößert, Mittelpunkt bei x, y
local function bear_at(t,x,y,w,h,flip)
  local r=S.rects[COLORS[t].sprite]
  sspr(S.img,r[1],r[2],r[3],r[4],x-w//2,y-h//2,w,h,flip,flip)
end
local function target_ring(team,piece,dir)
  local m=find_move(piece,dir)
  if not m then return end
  local x,y=field_xy(team,piece,m.dest)
  local hit=m.dest<40 and opponent_at_global(team,global_pos(team,m.dest))
  local r=9+(frame()//8)%2
  circ(x,y,r,hit and 8 or 11); circ(x,y,r+1,hit and 8 or 11); circ(x,y,r+2,INK)
end
local function draw_pieces()
  local chosen=(screen=='choose' or (screen=='cpu' and cpu_move)) and selected
  if screen=='choose' then
    target_ring(current,selected,'forward'); target_ring(current,selected,'backward')
  end
  for t=1,4 do for p=1,4 do
    local moving=anim and t==current and p==anim.m.piece
    local flying=cap and t==cap.team and p==cap.piece
    if not moving and not flying then
      local x,y=field_xy(t,p,teams[t].pieces[p])
      if t==current and p==chosen then
        -- ausgewählter Bär: leuchtender Kreis, größer, hüpft, Pfeil darüber
        local r=12+(frame()//8)%2
        circfill(x,y,r+1,INK); circfill(x,y,r,rgb(255,232,110)); circ(x,y,r-3,7)
        if shake>0 then x=x+(shake%4<2 and -3 or 3) end
        local bob=(frame()//10)%2
        arrow_down(x,max(0,y-25-(frame()//6)%4),COLORS[t].fill)
        bear_at(t,x,y-1-bob,21,20)
      else
        S.draw(COLORS[t].sprite,x-8,y-8)
      end
      if t==current and (screen=='choose' or chosen) then
        -- Nummer des Bären; im Haus nach außen, damit sich die Schilder nicht verdecken
        local tx,ty=x+3,y+2
        if teams[t].pieces[p]<0 then
          tx=x+(p%2==1 and -20 or 12); ty=y+(p<=2 and -12 or 3)
        end
        rectfill(tx,ty,tx+8,ty+9,INK); print(tostring(p),tx+1,ty+1,7)
      end
    end
  end end
  if anim then
    local a,b=anim.path[anim.i],anim.path[anim.i+1]
    local f=anim.t/anim.len
    local x=a[1]+(b[1]-a[1])*f; local y=a[2]+(b[2]-a[2])*f
    local hop=math.sin(math.pi*f)*(anim.len>12 and 16 or 7)
    rectfill(x-5,y+6,x+5,y+7,SHADOW)
    arrow_down(x,max(0,y-hop-26),COLORS[current].fill)
    bear_at(current,x,y-hop,21,20)
  end
  if cap then
    local t=cap.t
    if t<20 then
      -- Aufprall: Sterne, Wackeln, großes ZACK!
      local r=5+t*1.5
      if t<8 then circfill(cap.x,cap.y,14-t,10) end
      circ(cap.x,cap.y,r,8); circ(cap.x,cap.y,r+1,10)
      for k=0,7 do
        local w=k*math.pi/4+t*0.05
        local c=k%2==0 and 8 or INK
        line(cap.x+math.cos(w)*(r+3),cap.y+math.sin(w)*(r+3),cap.x+math.cos(w)*(r+9),cap.y+math.sin(w)*(r+9),c)
      end
      S.draw(COLORS[cap.team].sprite,cap.x-8+(t%4<2 and -3 or 3),cap.y-8,false,t>=10)
    else
      local f=(t-20)/44
      local x=cap.x+(cap.hx-cap.x)*f
      local y=cap.y+(cap.hy-cap.y)*f-math.sin(math.pi*f)*40
      local spin=(t//4)%4
      bear_at(cap.team,x,y,20,19,spin>=2)
      if spin%2==1 then circ(x,y,10,7) end
    end
    if t<44 then
      local ty=max(4,cap.y-38)
      local tx=mid(56,cap.x-textw('ZACK!',2)//2,262-textw('ZACK!',2))
      print('ZACK!',tx+2,ty+2,INK,2)
      print('ZACK!',tx,ty,t%6<3 and 8 or 10,2)
    end
  end
end
local function draw_panels()
  -- links: wer dran ist, rechts: der Würfel
  center_at('AM ZUG',26,52,5)
  -- Name in bis zu zwei Zeilen, möglichst am Leerzeichen getrennt
  local name=teams[current].name
  local a,b=name:match('^(%S+)%s+(.+)$')
  if not (a and #a<=6 and #b<=6) then a,b=name:sub(1,6),name:sub(7) end
  center_at(a,26,64,label_color(current)); center_at(b,26,74,label_color(current))
  local bob=(screen=='rolling' or screen=='turn') and (frame()//12)%2 or 0
  bear_big(current,10,92-bob,32)
  center_at('ZIEL',26,140,5)
  center_at(in_goal(current)..'/4',26,152,INK)
  center_at('WURF',294,78,INK)
  local dx,dy=0,0
  if screen=='rolling' then dx=(dice_timer%4<2) and -2 or 2; dy=-math.abs(math.sin(dice_timer*0.35))*6 end
  local face=screen=='rolling' and dice_face or (shown_roll>0 and shown_roll or nil)
  draw_die(276+dx,92+dy,face)
  if roll_attempt>0 then
    -- drei Versuche, eine 6 zu würfeln
    for i=1,3 do
      local x=282+(i-1)*12
      if i<=roll_attempt then circfill(x,142,4,INK) else circ(x,142,4,INK) end
    end
  end
end
local function draw_bar()
  rectfill(0,218,319,239,INK)
  local human=teams[current].human
  local l1,c1,l2,c2=message,7,sub,6
  if screen=='turn' then
    if message=='' then l1=player_label(current)..' ist dran.' end
    if human then l2=sub~='' and sub..'   A = würfeln' or 'A = würfeln'; c2=10 end
  elseif screen=='rolling' then l1=player_label(current)..' würfelt ...'; l2=''
  elseif screen=='cpu' then l2='CPU überlegt ...'
  elseif screen=='choose' then
    local x=print('BÄR '..selected..':',6,221,7)
    local fwd=find_move(selected,'forward')
    local back=find_move(selected,'backward')
    x=print('  ^ VOR',x,221,fwd and 11 or 5)
    x=print(fwd and ' ok' or ' nein',x,221,fwd and 11 or 5)
    x=print('   v ZURÜCK',x,221,back and 8 or 5)
    print(back and ' ok' or ' nein',x,221,back and 8 or 5)
    if hint_timer>0 then print(hint,6,231,14)
    else print('< > anderer Bär   ^ v ziehen',6,231,6) end
    return
  elseif screen=='info' and human then l2=sub..'  (A)' end
  print(l1,6,221,c1); print(l2,6,231,c2)
end
local function draw_game()
  draw_board(); draw_pieces(); draw_panels(); draw_bar()
end
function _draw()
  if screen=='title' then
    cls(BG)
    center('BÄRGER',42,8,4); center('DICH NICHT!',76,12,3)
    for t=1,4 do bear_big(t,63+(t-1)*52,121,30) end
    center('Vier Teams, 1 bis 4 Menschen',172,5)
    center('A / START',208,0,2)
  elseif screen=='setup_count' then
    cls(BG)
    center('WIE VIELE MENSCHEN?',38,0,2)
    center('<   '..human_count..'   >',88,label_color(human_count),4)
    center(human_count..' Mensch(en) + '..(4-human_count)..' CPU',142,5)
    center('A = Farben wählen',186,0)
  elseif screen=='setup_color' then
    cls(BG)
    center('SPIELER '..setup_player,24,0,2)
    center('FARBE WÄHLEN',48,0)
    bear_big(setup_color,140,78,40)
    center('< '..COLORS[setup_color].name..' >',128,label_color(setup_color),3)
    center('A = bestätigen   B = zurück',191,0)
  elseif screen=='setup_pick' then
    cls(BG)
    center('NAME FÜR '..COLORS[setup_color].name,12,label_color(setup_color),2)
    center('SPIELER '..setup_player..': gespeicherte Namen',36,5)
    bear_big(setup_color,30,90,48)
    for i,n in ipairs(pick_list) do
      local y=56+(i-1)*16
      local text=n or '+ NEUER NAME'
      if i==pick_index then
        rrect(96,y-4,256,y+11,4,COLORS[setup_color].fill)
        print('>',102,y,7); print(text,116,y,7)
      else print(text,116,y,n and INK or 5) end
    end
    center('^ v wählen   A = OK   B = zurück',218,0)
  elseif screen=='setup_name' then
    cls(BG)
    center('NAME FÜR '..COLORS[setup_color].name,12,label_color(setup_color),2)
    center(name_entry=='' and 'MENSCH '..setup_player or name_entry,46,0,2)
    for i=1,#ALPHABET do
      local col=(i-1)%6; local row=(i-1)//6
      local x=76+col*29; local y=83+row*18
      if i==name_cursor then rectfill(x-4,y-2,x+12,y+10,COLORS[setup_color].c) end
      print(ALPHABET:sub(i,i),x,y,i==name_cursor and 7 or 0)
    end
    center('A: Zeichen   B: löschen / zurück',211,0)
    center('START: Name übernehmen',225,0)
  elseif screen=='win' then
    cls(COLORS[winner].dark)
    center('GEWONNEN!',50,7,4)
    center(player_label(winner),108,7,2)
    for i=1,4 do S.draw(COLORS[winner].sprite,92+(i-1)*36,150) end
    center('A / START = neues Spiel',207,7)
  else draw_game() end
end
