-- Deterministic host stub: exercises the real script, not a second implementation.
local assertions = 0
local function check(ok,message)
  assertions=assertions+1
  assert(ok,message or ("UI assertion "..assertions))
end
local function host(initial)
  local h={ext={winw="980",winh="820"},draws={},inputs={},messages={},console="",now=0,position=0,play=0,
    tempo=100,numerator=4,denominator=4,playing=0,clipboard=nil,next_char=0}
  for k,v in pairs(initial or {}) do h.ext[k]=tostring(v) end
  local function noop() end
  reaper={
    get_action_context=function() return false,"./perfREV.lua",0,100 end,
    GetExtState=function(_,k) return h.ext[k] or "" end,
    SetExtState=function(_,k,v) h.ext[k]=v end,
    MB=function(msg) h.messages[#h.messages+1]=msg end,
    GetUserInputs=function(title,n,captions,values)
      h.last_dialog={title=title,n=n,captions=captions,values=values}
      local result=table.remove(h.inputs,1)
      if result then return true,result end
      return false,""
    end,
    time_precise=function() return h.now end,
    GetPlayState=function() return h.playing end,
    GetPlayPosition=function() return h.play end,
    GetCursorPosition=function() return h.position end,
    TimeMap_GetTimeSigAtTime=function(_,pos)
      h.last_tempo_position=pos
      return h.numerator,h.denominator,h.tempo
    end,
    ShowConsoleMsg=function(s) h.console=h.console..s end,
    atexit=function(fn) h.exit=fn end,
    SetToggleCommandState=function(_,_,value) h.toggle=value end,
    RefreshToolbar2=noop,
    defer=function(fn) h.next=fn end,
  }
  gfx={
    w=980,h=820,mouse_x=0,mouse_y=0,mouse_cap=0,mouse_wheel=0,dest=-1,
    init=function(_,w,height) gfx.w,gfx.h=w,height end,
    set=noop,rect=noop,line=noop,circle=noop,setimgdim=noop,blit=noop,update=noop,quit=noop,
    setfont=function(_,_,size) h.font=size end,
    measurestr=function(s) return #s*(h.font or 15)*0.5 end,
    drawstr=function(s) h.draws[#h.draws+1]={text=s,x=gfx.x,y=gfx.y,dest=gfx.dest,font=h.font} end,
    dock=function() return 0,100,100,gfx.w,gfx.h end,
    getchar=function() local c=h.next_char h.next_char=0 return c end,
  }
  function h.frame()
    h.draws={}
    local fn=h.next
    h.next=nil
    check(type(fn)=="function","No deferred frame")
    fn()
  end
  function h.click(x,y)
    gfx.mouse_x,gfx.mouse_y=x,y
    gfx.mouse_cap=1 h.frame()
    gfx.mouse_cap=0 h.frame()
  end
  function h.key(c) h.next_char=c h.frame() end
  function h.has(fragment)
    for _,d in ipairs(h.draws) do if d.text:find(fragment,1,true) then return true end end
    return false
  end
  function h.footer()
    local found
    for _,d in ipairs(h.draws) do
      if d.text=="RS ecosystem" then
        found=d
        check(d.dest==-1,"Signature must be on fixed main surface")
        check(d.font==11,"Signature must be small")
        local width=#d.text*d.font*0.5
        check(math.abs((d.x+width/2)-gfx.w/2)<1,"Signature must be centered")
        check(d.y>gfx.h-45 and d.y<gfx.h-12,"Signature must have bottom padding")
      end
    end
    check(found,"Signature missing")
  end
  dofile("perfREV.lua")
  check(h.toggle==1,"Toolbar not active")
  return h
end

local h=host()
check(h.has("100.00 BPM"))
h.footer()
h.click(300,150) -- riverbero
check(h.has("Decay in multipli"))
h.footer()
h.click(530,150) -- stanza
check(h.has("Diretto:"))
h.footer()
h.click(650,150) -- guida
check(h.has("1. Prima il contesto"))
h.footer()
h.click(850,150) -- informazioni
local metadata=dofile("lib/perfrev_version.lua")
check(h.has("Versione "..metadata.version.."   |   Build "..metadata.build),"Metadata not shown in info page")
h.footer()
h.click(650,150) -- guida
gfx.mouse_wheel=-1200 h.frame()
check(h.has("10. Sicurezza"))
h.footer()
h.click(30,150) -- back, scroll resets
check(h.has("Divisioni musicali"))
h.click(300,265) -- native copy, first whole-note cell
check(h.last_dialog and h.last_dialog.title=="Copia con Ctrl+C / Cmd+C")
check(h.last_dialog.values=="2400.000","Copy numeric ms")
reaper.CF_SetClipboard=function(value) h.clipboard=value end
h.click(500,265)
check(h.clipboard=="3600.000","Extension clipboard")

h.now=1 h.key(116)
h.now=1.5 h.key(116)
h.now=2 h.key(116)
check(h.has("120.00 BPM"),"TAP did not set manual BPM")
check(h.has("variabilita' 0.0%"))
check(h.tempo==100,"TAP modified project tempo")
h.click(40,65)
check(h.has("100.00 BPM"),"Project BPM not restored")
h.playing,h.play=1,42
h.click(220,110)
check(h.last_tempo_position==42,"Playback follow not used")
h.playing=0 h.position=17 h.frame()
check(h.last_tempo_position==17,"Stopped playback must use cursor")
h.numerator,h.denominator,h.tempo=6,8,120 h.frame()
check(h.has("6/8  |  quarto = 500.00 ms"))
check(h.has("1 battuta: 1500.00 ms"),"Wrong 6/8 interpretation")

h.inputs={"90,3,4"}
h.click(30,110)
check(h.has("90.00 BPM"))
check(h.has("3/4  |"))
h.inputs={"oops,3,4"}
h.click(30,110)
check(#h.messages==1 and h.has("90.00 BPM"),"Invalid numeric input was accepted")
h.click(530,150)
h.inputs={"7,9,4,22"}
h.click(50,205)
check(h.has("7.0 x 9.0 x 4.0 m"))
h.inputs={"0,0.2,0.2,0.2,0.3,1"}
h.click(520,205)
check(h.has("-inf"),"Absorbing surface handling")
h.click(780,205)
check(h.console:find("Delta dal diretto ms",1,true),"Room report missing")
check(h.console:find("Assorbimento Sx/Dx",1,true),"Reproducibility parameters missing")
h.inputs={"2,2,1,2,2,1"}
h.click(300,205)
check(#h.messages==2,"Coincident source/listener accepted")
h.exit()
check(h.toggle==0)
check(h.ext.width=="7" and h.ext.mode=="manual")
check(h.ext.winh=="820")

-- Header clicks must not trigger scrolled content behind the header.
h=host({tab=3})
gfx.mouse_wheel=-720 h.frame()
h.click(40,65)
check(not h.last_dialog,"Hidden content intercepted header click")
h.footer()
h.exit()

-- Corrupted saved preferences must not crash the app.
h=host({tab=9,bpm="nan",width=-1,variant="bad",delay_note=0,denominator=3,feedback=999})
check(h.has("Fonte ufficiale:"))
h.exit()
check(h.ext.width=="6")
check(h.ext.feedback=="95")
check(h.ext.denominator=="4")

-- All five pages work at narrow and wide sizes, footer remains fixed.
for tab=1,5 do
  h=host({tab=tab,winw=600,winh=450})
  check(h.has("RS ecosystem"))
  gfx.w,gfx.h=1568,1000 h.frame()
  check(h.has("RS ecosystem"))
  h.key(27)
  check(h.next==nil,"Escape scheduled another frame")
  h.exit()
end
print("UI: "..assertions.." assertions passed")
