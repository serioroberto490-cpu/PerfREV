local C = dofile("lib/perfrev_core.lua")
local count = 0
local function check(condition, message)
  count = count + 1
  assert(condition, message or ("Test " .. count .. " failed"))
end
local function near(a,b,eps)
  check(math.abs(a-b)<(eps or 1e-8),tostring(a).." != "..tostring(b))
end
local function rejects(fn) check(not pcall(fn), "Expected rejection") end

near(C.note_ms(100,4),600)
near(C.note_ms(120,8,"dotted"),375)
near(C.note_ms(120,8,"triplet"),500/3)
near(C.bar_ms(120,6,8),1500)
near(C.bar_ms(120,3,4),1500)
rejects(function() C.note_ms(0,4) end)
rejects(function() C.note_ms(0/0,4) end)
rejects(function() C.note_ms(120,0) end)
rejects(function() C.note_ms(120,4,"bad") end)
check(C.decay_label(0.9)=="Breve")
check(C.decay_label(1)=="Medio")
check(C.decay_label(2)=="Medio")
check(C.decay_label(2.01)=="Lungo")
near(C.feedback_rt60(500,0.5),4.982892142331043)
rejects(function() C.feedback_rt60(500,1) end)
rejects(function() C.feedback_rt60(500,0) end)
near(C.speed(20),343.215,0.02)
rejects(function() C.speed(100) end)

local tap=C.new_tap()
check(C.tap(tap,0)==nil)
near(C.tap(tap,0.5),120)
near(C.tap(tap,1),120)
near(tap.variation,0)
near(C.tap(tap,1.01),120) -- ignore accidental double tap
check(#tap.times==3)
for i=3,20 do C.tap(tap,i*0.5) end
check(#tap.times==9)
near(tap.bpm,120)
check(C.tap(tap,20)==nil) -- reset after pause
check(#tap.times==1)
check(C.tap(tap,19)==nil) -- nonmonotonic clock resets

local room={
  width=6,length=8,height=3,temperature=20,
  source={x=2,y=2,z=1.5},listener={x=3,y=6,z=1.5},
  absorption={0.2,0.2,0.2,0.2,0.3,0.2},
}
local r=C.room(room)
near(r.distance,math.sqrt(17))
near(r.volume,144)
near(r.area,180)
near(r.alpha,(132*0.2+48*0.3)/180)
check(#r.reflections==6)
check(#r.modes==9)
check(r.eyring<r.sabine)
for i,v in ipairs(r.reflections) do
  near(v.delay_ms,(v.path-r.distance)/r.speed*1000)
  near(v.arrival_ms,r.direct_ms+v.delay_ms)
  check(v.db<0)
  check(v.hit.x>=-1e-9 and v.hit.x<=6+1e-9)
  check(v.hit.y>=-1e-9 and v.hit.y<=8+1e-9)
  check(v.hit.z>=-1e-9 and v.hit.z<=3+1e-9)
  if i>1 then check(v.delay_ms>=r.reflections[i-1].delay_ms) end
  if v.name=="Sinistra" then
    near(v.path,math.sqrt(41))
    near(v.hit.x,0)
    near(v.amplitude,math.sqrt(0.8)*math.sqrt(17)/math.sqrt(41))
    check(v.azimuth<0)
  elseif v.name=="Destra" then near(v.hit.x,6)
  elseif v.name=="Fronte" then near(v.hit.y,0)
  elseif v.name=="Retro" then near(v.hit.y,8)
  elseif v.name=="Pavimento" then near(v.hit.z,0) check(v.elevation<0)
  elseif v.name=="Soffitto" then near(v.hit.z,3) check(v.elevation>0) end
end
for i=1,6 do room.absorption[i]=0 end
r=C.room(room)
check(r.sabine==math.huge and r.eyring==math.huge)
for i=1,6 do room.absorption[i]=1 end
r=C.room(room)
near(r.eyring,0)
for _,v in ipairs(r.reflections) do check(v.db==-math.huge) end
room.source.x=room.listener.x
room.source.y=room.listener.y
rejects(function() C.room(room) end)
room.source.x=-1
rejects(function() C.room(room) end)
room.source.x=1
room.absorption[2]=1.1
rejects(function() C.room(room) end)

-- Randomized geometry: reflection point lies on a surface and broken path
-- equals the unfolded image-source path.
math.randomseed(437)
for _=1,100 do
  local width,length,height=2+math.random()*15,2+math.random()*15,2+math.random()*5
  room={
    width=width,length=length,height=height,temperature=-20+math.random()*70,
    source={x=width*(0.1+math.random()*0.8),y=length*(0.1+math.random()*0.8),z=height*0.3},
    listener={x=width*(0.1+math.random()*0.8),y=length*(0.1+math.random()*0.8),z=height*0.7},
    absorption={0.1,0.2,0.3,0.4,0.5,0.6},
  }
  r=C.room(room)
  for _,v in ipairs(r.reflections) do
    near(C.distance(room.source,v.hit)+C.distance(v.hit,room.listener),v.path)
    check(v.delay_ms>=0)
    check(v.amplitude>=0 and v.amplitude<=1)
  end
end
print("Core: "..count.." assertions passed")
