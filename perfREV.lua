-- @description perfREV - Tempo, delay, riverbero e stanza
-- @version 0.2.0
-- @author perfREV
-- @license MIT
-- @provides
--   [nomain] lib/perfrev_core.lua
--   [nomain] lib/perfrev_version.lua
--   [nomain] lib/perfrev_reverb.lua
--   [nomain] lib/perfrev_theme.lua
-- @about
--   Calcolatore non distruttivo: BPM progetto/manuali/TAP, delay, riverbero,
--   prime riflessioni di una stanza rettangolare e guida al mix.
--   Non elabora audio e non modifica tempo, tracce, routing o plugin.
--   REAPER 6.0+. Nessuna estensione obbligatoria.
-- Release header generated from lib/perfrev_version.lua by tools/project_version.py.

local _, script_path, section_id, command_id = reaper.get_action_context()
local directory = script_path:match("^(.*[/\\])") or ""
local loaded, core = pcall(dofile, directory .. "lib/perfrev_core.lua")
if not loaded then
  reaper.MB("Libreria mancante o non valida.\nCopia anche la cartella lib accanto allo script.\n\n"
    .. tostring(core), "perfREV", 0)
  return
end
local C, N = core, core.number
local function load_module(name)
  local ok, result = pcall(dofile, directory .. "lib/" .. name .. ".lua")
  if not ok or type(result) ~= "table" then
    reaper.MB("Libreria mancante o non valida: "..name.."\nReinstalla perfREV con tutta la cartella lib.",
      "perfREV",0)
    return nil
  end
  return result
end
local R = load_module("perfrev_reverb")
local theme = load_module("perfrev_theme")
if not R or not theme then return end
local version_ok, metadata = pcall(dofile, directory .. "lib/perfrev_version.lua")
if not version_ok or type(metadata) ~= "table" or type(metadata.version) ~= "string"
  or not metadata.version:match("^%d+%.%d+%.%d+$") or not C.finite(metadata.build)
  or metadata.build < 1 or metadata.build % 1 ~= 0 then
  reaper.MB("Metadati di versione mancanti o non validi.\nCopia anche lib/perfrev_version.lua.",
    "perfREV", 0)
  return
end
local release_label = "v" .. metadata.version .. " / build " .. metadata.build
-- Retain the original internal key so existing local preferences survive the rename.
local namespace = "calcoloRev_v1"
local defaults = {
  mode = "project", bpm = 120, follow = "cursor", tab = 1,
  numerator = 4, denominator = 4, predelay = 20, feedback = 30,
  delay_note = 4, variant = "straight", decay_q = 4,
  width = 6, length = 8, height = 3, temperature = 20,
  sx = 2, sy = 2, sz = 1.5, lx = 3, ly = 6, lz = 1.5,
  a1 = 0.2, a2 = 0.2, a3 = 0.2, a4 = 0.2, a5 = 0.3, a6 = 0.2,
  rev_profile = "generic", rev_route = "send", rev_type = 4, rev_custom_type = "Personalizzato",
  rev_time_mode = "musical", rev_time_s = 1.2,
  rev_size = 50, rev_diffusion = 75, rev_shape = 3.5,
  rev_early = -6, rev_tail = 0, rev_wet = 100, rev_gain = 0,
  rev_lf = 200, rev_lratio = 1, rev_hf = 6000, rev_hratio = 1,
  rev_eqlf = 200, rev_eqlgain = 0, rev_eqhf = 6000, rev_eqhgain = 0, rev_decorr = 0,
}
local state = {}
for key, value in pairs(defaults) do
  local stored = reaper.GetExtState(namespace, key)
  state[key] = type(value) == "number" and (tonumber(stored) or value) or (stored ~= "" and stored or value)
  if type(value) == "number" and not C.finite(state[key]) then state[key] = value end
end
if state.mode ~= "project" and state.mode ~= "manual" then state.mode = "project" end
if state.follow ~= "cursor" and state.follow ~= "play" then state.follow = "cursor" end
if not ({straight = true, dotted = true, triplet = true})[state.variant] then state.variant = "straight" end
state.bpm = C.clamp(state.bpm, 20, 400)
state.tab = C.clamp(math.floor(state.tab), 1, 5)
state.numerator = C.clamp(math.floor(state.numerator), 1, 32)
if not ({[1]=true,[2]=true,[4]=true,[8]=true,[16]=true,[32]=true})[state.denominator] then state.denominator = 4 end
state.predelay = C.clamp(state.predelay, -160, 500)
state.feedback = C.clamp(state.feedback, 1, 95)
state.decay_q = C.clamp(state.decay_q, 0.25, 32)
if not ({[1]=true,[2]=true,[4]=true,[8]=true,[16]=true,[32]=true,[64]=true})[state.delay_note] then state.delay_note = 4 end
if state.rev_profile ~= "rverb" then state.rev_profile = "generic" end
if state.rev_route ~= "insert" then state.rev_route = "send" end
if state.rev_time_mode ~= "free" then state.rev_time_mode = "musical" end
state.rev_type = C.clamp(math.floor(state.rev_type),1,#R.types)
local rev_ranges = {
  rev_time_s={0.1,60},rev_size={0,100},rev_diffusion={0,100},rev_shape={0.04,3.5},
  rev_early={-60,6},rev_tail={-60,6},rev_wet={0,100},rev_gain={-60,12},
  rev_lf={16,20000},rev_lratio={0.1,2},rev_hf={16,20000},rev_hratio={0.1,2},
  rev_eqlf={16,20000},rev_eqlgain={-24,12},rev_eqhf={16,20000},rev_eqhgain={-24,12},rev_decorr={0,6},
}
for key,range in pairs(rev_ranges) do state[key]=C.clamp(state[key],range[1],range[2]) end
state.rev_decorr=math.floor(state.rev_decorr)
state.rev_custom_type=state.rev_custom_type:gsub("[\r\n|]"," "):sub(1,40)

local function room_input()
  return {width = state.width, length = state.length, height = state.height, temperature = state.temperature,
    source = {x = state.sx, y = state.sy, z = state.sz},
    listener = {x = state.lx, y = state.ly, z = state.lz},
    absorption = {state.a1, state.a2, state.a3, state.a4, state.a5, state.a6}}
end
if not pcall(C.validate_room, room_input()) then
  for _, key in ipairs({"width","length","height","temperature","sx","sy","sz","lx","ly","lz","a1","a2","a3","a4","a5","a6"}) do
    state[key] = defaults[key]
  end
end

local tap = C.new_tap()
local status, status_until = "", 0
local mouse_was_down, pressed, down, drag, consumed = false, false, false, nil, false
local scale, scroll = 1, 0
local drawing_content = false
local content_bottom = 0
local bpm, numerator, denominator, project_position = 120, 4, 4, 0
local palette = theme.palette

local function color(name) gfx.set(table.unpack(palette[name] or palette.text)) end
local function rect(x,y,w,h,name)
  color(name) gfx.rect(x*scale,y*scale,w*scale,h*scale,1)
end
local function text(x,y,value,name,size)
  color(name) gfx.setfont(1,"Arial",math.floor((size or 15)*scale))
  gfx.x, gfx.y = x*scale, y*scale
  gfx.drawstr(tostring(value))
end
local function inside(x,y,w,h)
  local mx,my = gfx.mouse_x/scale,gfx.mouse_y/scale
  if drawing_content and (my<190 or my>content_bottom) then return false end
  return mx>=x and mx<=x+w and my>=y and my<=y+h
end
local function button(label,x,y,w,active,height)
  height=height or 29
  local hover = inside(x,y,w,height)
  rect(x,y,w,height,active and "accent" or "panel")
  color(active and "amber" or "stone")
  gfx.rect(x*scale,y*scale,w*scale,height*scale,0)
  if hover then
    gfx.set(1,1,1,0.08) gfx.rect(x*scale,y*scale,w*scale,height*scale,1)
  end
  text(x+9,y+6,label,active and "bg" or "text",14)
  if pressed and not consumed and hover then consumed = true return true end
  return false
end
local function paragraph(x,y,value,width,name,size)
  size=size or 14
  gfx.setfont(1,"Arial",math.floor(size*scale))
  local line=""
  for word in tostring(value):gmatch("%S+") do
    local next_line=line=="" and word or line.." "..word
    if line~="" and gfx.measurestr(next_line)>width*scale then
      text(x,y,line,name,size) y=y+size+5 line=word
    else line=next_line end
  end
  if line~="" then text(x,y,line,name,size) y=y+size+5 end
  return y
end
local function notice(message)
  status, status_until = message, reaper.time_precise()+5
end
local function copy(value)
  if reaper.CF_SetClipboard then
    reaper.CF_SetClipboard(tostring(value))
    notice("Copiato negli appunti.")
  elseif reaper.JS_Window_SetClipboard then
    reaper.JS_Window_SetClipboard(tostring(value))
    notice("Copiato negli appunti.")
  else
    -- Native-only fallback. No OS shell, extension or temporary file needed.
    reaper.GetUserInputs("Copia con Ctrl+C / Cmd+C",1,"Valore (seleziona e copia),extrawidth=240",tostring(value):gsub(",", ";"))
  end
end
local function report(value)
  reaper.ShowConsoleMsg("\n" .. value .. "\n")
  notice("Report aggiunto alla console REAPER (nessun file creato).")
end
local function input(title, fields)
  local captions, values = {}, {}
  for _, f in ipairs(fields) do captions[#captions+1],values[#values+1] = f[2],tostring(state[f[1]]) end
  local ok, csv = reaper.GetUserInputs(title,#fields,table.concat(captions,",")..",extrawidth=120",table.concat(values,","))
  if not ok then return false end
  local parsed = {}
  for token in (csv..","):gmatch("(.-),") do parsed[#parsed+1] = tonumber(token) or false end
  for i,f in ipairs(fields) do
    local v = parsed[i]
    if not C.finite(v) or v<f[3] or v>f[4] or (f[5] and not f[5](v)) then
      reaper.MB("Valore non valido: "..f[2].."\nIntervallo: "..f[3].." - "..f[4]
        .."\nUsa il punto per i decimali.", "perfREV",0)
      return false
    end
  end
  for i,f in ipairs(fields) do state[f[1]]=parsed[i] end
  return true
end
local function tap_now()
  local value = C.tap(tap,reaper.time_precise())
  state.mode = "manual"
  if value then state.bpm = C.clamp(value,20,400) end
end

local function tempo()
  project_position = state.follow=="play" and (reaper.GetPlayState()&1)==1
    and reaper.GetPlayPosition() or reaper.GetCursorPosition()
  local n,d,b = reaper.TimeMap_GetTimeSigAtTime(0,project_position)
  if state.mode=="project" then
    bpm,numerator,denominator = b,n,d
  else bpm,numerator,denominator = state.bpm,state.numerator,state.denominator end
  if not C.finite(bpm) or bpm<=0 then bpm=120 end
  if not numerator or numerator<=0 then numerator=4 end
  if not denominator or denominator<=0 then denominator=4 end
end

local function header()
  text(22,15,"perfREV","accent",25)
  text(190,23,"TEMPO / SPAZIO / CHIAREZZA","muted",13)
  if button("Progetto",22,58,105,state.mode=="project") then state.mode="project" end
  if button("Manuale / TAP",135,58,136,state.mode=="manual") then state.mode="manual" end
  text(292,58,N(bpm,2).." BPM","accent",23)
  text(488,65,numerator.."/"..denominator.."  |  quarto = "..N(60000/bpm,2).." ms","muted",14)
  if button("TAP [T]",729,57,106,false) then tap_now() end
  if button("Reset TAP",843,57,105,false) then tap=C.new_tap() end
  if button("BPM / metro...",22,96,155,false) then
    if input("BPM manuali (quarto) e metro",{
      {"bpm","BPM",20,400},{"numerator","Numeratore",1,32,function(v) return v%1==0 end},
      {"denominator","Denominatore",1,32,function(v) return ({[1]=true,[2]=true,[4]=true,[8]=true,[16]=true,[32]=true})[v] end},
    }) then state.mode="manual" tap=C.new_tap() end
  end
  if button(state.follow=="cursor" and "Lettura: cursore" or "Lettura: playback",187,96,170,false) then
    state.follow = state.follow=="cursor" and "play" or "cursor"
  end
  local tapinfo = #tap.times<2 and "TAP: almeno 2 tocchi; pausa >3 s = nuova sequenza"
    or (#tap.times.." tocchi | variabilita' "..N(tap.variation,1).."% | media max 8 intervalli")
  text(375,104,tapinfo,"muted",13)
  local tabs = {"Delay / tempo","Riverbero","Stanza","Guida al mix","Informazioni"}
  for i,name in ipairs(tabs) do
    if button(name,22+(i-1)*189,143,181,state.tab==i) then state.tab=i scroll=0 drag=nil end
  end
end

local function tempo_report()
  local lines = {"perfREV "..release_label.." | "..N(bpm,3).." BPM (quarto) | "..numerator.."/"..denominator,
    "Nota\tNormale ms\tPuntata ms\tTerzina ms"}
  for _,d in ipairs({1,2,4,8,16,32,64}) do
    lines[#lines+1] = string.format("1/%d\t%.3f\t%.3f\t%.3f",d,
      C.note_ms(bpm,d),C.note_ms(bpm,d,"dotted"),C.note_ms(bpm,d,"triplet"))
  end
  lines[#lines+1] = "Battuta (tempo locale costante): "..N(C.bar_ms(bpm,numerator,denominator),3).." ms"
  lines[#lines+1] = "Variazioni di tempo successive non integrate. Nessuna modifica al progetto."
  return table.concat(lines,"\n")
end

local function delay_page(y)
  text(24,y,"Divisioni musicali - clic su un valore per copiarlo","text",18)
  y=y+38
  for i,label in ipairs({"Nota","Normale (ms)","Puntata (ms)","Terzina (ms)"}) do text(28+(i-1)*230,y,label,"muted") end
  y=y+28
  for _,d in ipairs({1,2,4,8,16,32,64}) do
    text(30,y+6,"1/"..d,"text",16)
    for i,v in ipairs({"straight","dotted","triplet"}) do
      local value=C.note_ms(bpm,d,v)
      if button(N(value,3),258+(i-1)*230,y,215,state.delay_note==d and state.variant==v) then
        state.delay_note,state.variant=d,v
        copy(N(value,3))
      end
    end
    y=y+36
  end
  y=y+15
  local bar=C.bar_ms(bpm,numerator,denominator)
  text(28,y,"1 battuta: "..N(bar,2).." ms   |   2: "..N(bar*2,2).." ms   |   4: "..N(bar*4,2).." ms","accent",17)
  y=y+37
  if button("Feedback: "..N(state.feedback,0).."%...",24,y,192,false) then
    input("Feedback delay ideale",{{"feedback","Feedback percentuale",1,95}})
  end
  local delay=C.note_ms(bpm,state.delay_note,state.variant)
  text(232,y+6,"Delay scelto: "..N(delay,2).." ms  |  RT60 ideale: "
    ..N(C.feedback_rt60(delay,state.feedback/100),2).." s","text",16)
  y=y+42
  text(26,y,"Feedback ideale lineare: filtri, saturazione e controlli del plugin possono cambiare il risultato.","muted",14)
  text(26,y+25,"Puntata = x1.5; terzina = x2/3. BPM sempre riferiti al quarto, anche in 6/8.","muted",14)
  text(26,y+50,"Con tempo variabile sono durate locali, non un'integrazione della mappa tempo.","muted",14)
  if button("Report divisioni",24,y+83,180,false) then report(tempo_report()) end
  return y+130
end

local function reverb_report()
  local ms=R.time_ms(state,bpm)
  local label,meaning,use=R.category(ms/1000)
  local lines={"perfREV "..release_label.." | Riverbero | "..N(bpm,3).." BPM",
    label.." | "..N(ms/1000,3).." s | modalita' "..state.rev_time_mode,
    meaning,use,"Riferimento: "..state.rev_profile.." | routing: "..state.rev_route,
    "Parametro comune\tNome nel plugin\tValore\tSignificato"}
  for _,row in ipairs(R.rows(state,bpm)) do lines[#lines+1]=table.concat(row,"\t") end
  for _,warning in ipairs(R.warnings(state,bpm)) do lines[#lines+1]="ATTENZIONE: "..warning end
  lines[#lines+1]="Solo Time in modalita' musicale deriva dai BPM; gli altri sono valori scelti dall'utente."
  lines[#lines+1]="Nessuna impostazione applicata ai plugin. RT60 non e' una fine netta."
  return table.concat(lines,"\n")
end

local function reverb_page(y)
  text(24,y,"Scegli la coda, poi leggi cosa impostare nel tuo riverbero","text",18)
  text(24,y+29,"Corto <1 s | Medio 1-2 s | Lungo >2 s. Sono durate, NON dimensioni della stanza.","muted",14)
  y=y+59
  for i,q in ipairs({0.5,1,1.5,2,3,4,6,8}) do
    local ms=60000/bpm*q
    local label=R.category(ms/1000)
    local x,cy=24+((i-1)%4)*237,y+math.floor((i-1)/4)*79
    local active=state.rev_time_mode=="musical" and state.decay_q==q
    if button((active and "* " or "")..label.." | "..N(ms/1000,2).." s",x,cy,224,active,68) then
      state.decay_q=q state.rev_time_mode="musical"
    end
    text(x+10,cy+28,N(q,1).." quarti / "..N(ms,1).." ms",active and "bg" or "muted",13)
    text(x+10,cy+48,active and "SELEZIONATO" or "Seleziona per lo specchietto",active and "bg" or "muted",11)
  end
  y=y+168
  if button("Quarti personalizzati...",24,y,224,state.rev_time_mode=="musical") then
    if input("Tempo coda musicale",{{"decay_q","Numero di quarti",0.25,32}}) then state.rev_time_mode="musical" end
  end
  if button("Secondi liberi...",261,y,224,state.rev_time_mode=="free") then
    if input("Tempo coda libero",{{"rev_time_s","Secondi (indipendenti dai BPM)",0.1,60}}) then state.rev_time_mode="free" end
  end
  if button("Pre-delay: "..N(state.predelay,2).." ms...",498,y,224,false) then
    input("Pre-delay libero",{{"predelay","Pre-delay ms (-160..500)",-160,500}})
  end
  if button("Report / valori",735,y,211,false) then report(reverb_report()) end
  y=y+44
  local ms=R.time_ms(state,bpm)
  local label,meaning,use=R.category(ms/1000)
  text(26,y,label.." - "..N(ms/1000,3).." s / "..N(ms,2).." ms","accent",20)
  if button("Copia s",700,y,110,false) then copy(N(ms/1000,3)) end
  if button("Copia ms",820,y,126,false) then copy(N(ms,3)) end
  y=paragraph(26,y+32,meaning.." "..use,916,"text",14)+9
  text(26,y,"RT60: calo di 60 dB, non stop esatto. Un gate o un inviluppo possono troncare la coda.","amber",14)
  y=y+38
  if button("Generico",24,y,140,state.rev_profile=="generic") then state.rev_profile="generic" end
  if button("Esempio: RVerb",174,y,175,state.rev_profile=="rverb") then state.rev_profile="rverb" end
  if button(state.rev_route=="send" and "Routing: SEND" or "Routing: INSERT",359,y,184,false) then
    state.rev_route=state.rev_route=="send" and "insert" or "send"
  end
  if button("Tipo: "..R.type_name(state).."...",553,y,393,false) then
    local names={}
    for i,item in ipairs(R.types) do
      names[#names+1]=(state.rev_type==i and "!" or "")..item[1]
        ..(state.rev_profile=="rverb" and i>R.rverb_types and " (altro plugin)" or "")
    end
    gfx.x,gfx.y=553*scale,(y+29)*scale
    local choice=gfx.showmenu(table.concat(names,"|"))
    if choice>=1 and choice<=#R.types then
      if choice==#R.types then
        local ok,name=reaper.GetUserInputs("Nome algoritmo / IR personalizzato",1,"Nome,extrawidth=140",state.rev_custom_type)
        if ok and name:match("%S") then
          state.rev_custom_type=name:gsub("[\r\n|]"," "):sub(1,40)
          state.rev_type=choice
        end
      else state.rev_type=choice end
    end
  end
  y=y+44
  text(26,y,"Pre-delay musicale: clic = valore in ms, non segue i successivi cambi di BPM.","muted",13)
  y=y+25
  for i,d in ipairs({16,32,64}) do
    local pd=C.note_ms(bpm,d)
    if button("1/"..d.." = "..N(pd,2).." ms",24+(i-1)*237,y,224,false) then
      state.predelay=C.clamp(pd,0,500)
      if pd>500 then notice("Pre-delay limitato a 500 ms.") end
    end
  end
  if button("Copia pre-delay",735,y,211,false) then copy(N(state.predelay,3)) end
  y=y+43
  if button("Carattere / forma...",24,y,224,false) then
    input("Scelte creative, NON calcolate dai BPM",{
      {"rev_size","Size percentuale",0,100},{"rev_diffusion","Diffusion percentuale",0,100},
      {"rev_shape","RVerb Decay (3.5 lineare)",0.04,3.5},
      {"rev_decorr","RVerb Decorrelation 0-6",0,6,function(v) return v%1==0 end},
    })
  end
  if button("Livelli / wet / gain...",261,y,224,false) then
    input("Livelli e routing (send: consigliato wet 100)",{
      {"rev_early","Early reflections dB",-60,6},{"rev_tail","Tail dB",-60,6},
      {"rev_wet","Wet percentuale",0,100},{"rev_gain","Output gain dB",-60,12},
    })
  end
  if button("Damping...",498,y,224,false) then
    input("Damping (frequenze e rapporti dipendono dal plugin)",{
      {"rev_lf","LF Hz",16,20000},{"rev_lratio","LF ratio",0.1,2},
      {"rev_hf","HF Hz",16,20000},{"rev_hratio","HF ratio",0.1,2},
    })
  end
  if button("EQ...",735,y,211,false) then
    input("EQ della coda (shelf; non filtri universali)",{
      {"rev_eqlf","EQ low Hz",16,20000},{"rev_eqlgain","EQ low gain dB",-24,12},
      {"rev_eqhf","EQ high Hz",16,20000},{"rev_eqhgain","EQ high gain dB",-24,12},
    })
  end
  y=y+47
  for _,warning in ipairs(R.warnings(state,bpm)) do
    y=paragraph(26,y,warning,916,"amber",14)+5
  end
  text(26,y,"SPECCHIETTO - "..(state.rev_profile=="rverb" and "Waves Renaissance Reverb (esempio)" or "Parametri comuni, nomi indicativi"),"accent",17)
  y=paragraph(26,y+29,"Solo il tempo musicale e' calcolato dai BPM. Tutti gli altri valori sono scelte modificabili; non sono preset ottimali, conversioni universali o impostazioni applicate al VST.",916,"muted",14)+10
  for i,row in ipairs(R.rows(state,bpm)) do
    local row_top=y
    if i%2==1 then rect(23,y-3,925,82,"panel") end
    text(32,y,row[1],"text",15)
    text(32,y+25,row[2],"muted",12)
    if i<=2 then
      local v=i==1 and ms/1000 or state.predelay
      if button(row[3].."  [copia]",383,y,553,false) then copy(N(v,3)) end
    else text(390,y+4,row[3],"accent",15) end
    local end_y=paragraph(390,y+34,row[4],536,"muted",13)
    y=math.max(row_top+86,end_y+15)
  end
  text(26,y,"RVerb: Time = secondi; Decay = forma. Size non e' una stanza in metri.","amber",14)
  y=paragraph(26,y+27,"I limiti di frequenze, damping e controlli generici dipendono da plugin/versione. Verifica il manuale; perfREV conserva le scelte senza fingere compatibilita' universale.",916,"muted",14)
  if button("Report completo in console",24,y+12,300,false) then report(reverb_report()) end
  return y+65
end

local function edit_room_dimensions()
  local old={}
  for _,k in ipairs({"width","length","height","temperature"}) do old[k]=state[k] end
  if input("Stanza rettangolare (metri)",{
    {"width","Larghezza X (m)",1,100},{"length","Lunghezza Y (m)",1,100},
    {"height","Altezza Z (m)",1,50},{"temperature","Temperatura C",-20,50},
  }) then
    -- Preserve normalized positions when changing room dimensions.
    for _,p in ipairs({"s","l"}) do
      state[p.."x"]=state[p.."x"]/old.width*state.width
      state[p.."y"]=state[p.."y"]/old.length*state.length
      state[p.."z"]=state[p.."z"]/old.height*state.height
    end
    if not pcall(C.validate_room,room_input()) then
      for k,v in pairs(old) do state[k]=v end
      state.sx,state.sy,state.sz=state.width/3,state.length/4,state.height/2
      state.lx,state.ly,state.lz=state.width/2,state.length*0.75,state.height/2
      notice("Posizioni reimpostate per mantenere almeno 5 cm di distanza.")
    end
  end
end

local function edit_positions()
  local keys={"sx","sy","sz","lx","ly","lz"}
  local old={}
  for _,k in ipairs(keys) do old[k]=state[k] end
  if input("Coordinate (metri; ascoltatore rivolto verso Y=0)",{
    {"sx","Sorgente X",0.01,state.width-0.01},{"sy","Sorgente Y",0.01,state.length-0.01},
    {"sz","Sorgente Z",0.01,state.height-0.01},{"lx","Ascoltatore X",0.01,state.width-0.01},
    {"ly","Ascoltatore Y",0.01,state.length-0.01},{"lz","Ascoltatore Z",0.01,state.height-0.01},
  }) and not pcall(C.validate_room,room_input()) then
    for k,v in pairs(old) do state[k]=v end
    reaper.MB("Mantieni almeno 5 cm fra sorgente e ascoltatore.","Coordinate",0)
  end
end

local function edit_absorption()
  input("Assorbimento energetico (0 riflette; 1 assorbe)",{
    {"a1","Sinistra",0,1},{"a2","Destra",0,1},{"a3","Fronte",0,1},
    {"a4","Retro",0,1},{"a5","Pavimento",0,1},{"a6","Soffitto",0,1},
  })
end

local function room_report(r)
  local lines={
    "perfREV "..release_label.." | Stanza rettangolare ideale",
    string.format("Dimensioni X/Y/Z: %.3f / %.3f / %.3f m | T %.1f C | c %.2f m/s",
      state.width,state.length,state.height,state.temperature,r.speed),
    string.format("Sorgente: %.3f, %.3f, %.3f m | Ascoltatore: %.3f, %.3f, %.3f m (fronte Y=0)",
      state.sx,state.sy,state.sz,state.lx,state.ly,state.lz),
    "Assorbimento Sx/Dx/Fronte/Retro/Pavimento/Soffitto: "
      ..table.concat({state.a1,state.a2,state.a3,state.a4,state.a5,state.a6}," / "),
    "Diretto: "..N(r.distance,3).." m | "..N(r.direct_ms,3).." ms",
    "Superficie\tDelta dal diretto ms\tArrivo assoluto ms\tdB relativi al diretto\tAzimut gradi\tElevazione gradi",
  }
  for _,v in ipairs(r.reflections) do
    lines[#lines+1]=table.concat({v.name,N(v.delay_ms,3),N(v.arrival_ms,3),N(v.db,2),N(v.azimuth,1),N(v.elevation,1)},"\t")
  end
  lines[#lines+1]="RT60 Sabine: "..N(r.sabine,3).." s | Eyring: "..N(r.eyring,3).." s (stime diffuse)"
  lines[#lines+1]="Modi assiali (tre per asse; frequenze teoriche, non intensita' o EQ):"
  for _,v in ipairs(r.modes) do lines[#lines+1]=v.axis.." #"..v.order..": "..N(v.hz,2).." Hz" end
  lines[#lines+1]="Sorgente omnidirezionale puntiforme; riflessioni speculari di primo ordine."
  lines[#lines+1]="Assorbimento indipendente da frequenza/angolo; no diffusione, diffrazione, HRTF o risonanze simulate."
  lines[#lines+1]="Azimut: 0 fronte, +90 destra; non equivale al pan del plugin. Delta riferiti al dry NON ritardato."
  return table.concat(lines,"\n")
end

local function room_map(x,y,w,h,result)
  rect(x,y,w,h,"panel")
  local k=math.min((w-54)/state.width,(h-48)/state.length)
  local rw,rh=state.width*k,state.length*k
  local ox,oy=x+(w-rw)/2,y+(h-rh)/2
  color("muted") gfx.rect(ox*scale,oy*scale,rw*scale,rh*scale,0)
  text(ox+5,oy+3,"FRONTE / Y=0","muted",11)
  local function screen(p) return ox+p.x*k,oy+p.y*k end
  for _,v in ipairs(result.reflections) do
    local sx,sy=screen({x=state.sx,y=state.sy})
    local hx,hy=screen(v.hit)
    local lx,ly=screen({x=state.lx,y=state.ly})
    gfx.set(0.25,0.60,0.62,0.22)
    gfx.line(sx*scale,sy*scale,hx*scale,hy*scale)
    gfx.line(hx*scale,hy*scale,lx*scale,ly*scale)
  end
  for _,p in ipairs({{"s","S","accent"},{"l","A","amber"}}) do
    local px,py=screen({x=state[p[1].."x"],y=state[p[1].."y"]})
    color(p[3]) gfx.circle(px*scale,py*scale,9*scale,1)
    text(px+13,py-8,p[2],p[3],15)
    if pressed and not consumed and inside(px-13,py-13,26,26) then
      drag=p[1] consumed=true
    end
  end
  if drag and down then
    local oldx,oldy=state[drag.."x"],state[drag.."y"]
    state[drag.."x"]=C.clamp((gfx.mouse_x/scale-ox)/k,0.01,state.width-0.01)
    state[drag.."y"]=C.clamp((gfx.mouse_y/scale-oy)/k,0.01,state.length-0.01)
    if not pcall(C.validate_room,room_input()) then state[drag.."x"],state[drag.."y"]=oldx,oldy end
  end
end

local function room_page(y)
  if button("Dimensioni / temperatura",24,y,235,false) then edit_room_dimensions() end
  if button("Coordinate / altezze",273,y,218,false) then edit_positions() end
  if button("Assorbimento superfici",505,y,231,false) then edit_absorption() end
  local ok,r=pcall(C.room,room_input())
  if not ok then text(24,y+50,tostring(r),"amber",14) return y+100 end
  if button("Report stanza",750,y,196,false) then report(room_report(r)) end
  y=y+48
  text(24,y,N(state.width,1).." x "..N(state.length,1).." x "..N(state.height,1).." m | "
    ..N(state.temperature,1).." C | c = "..N(r.speed,1).." m/s","muted",15)
  y=y+31
  room_map(24,y,388,300,r)
  text(434,y,"Diretto: "..N(r.distance,2).." m / "..N(r.direct_ms,2).." ms","accent",19)
  text(434,y+36,"Livello diretto vs 1 m: "..N(r.direct_db_1m,2).." dB","text",15)
  text(434,y+67,"Campo libero, stessa sorgente; non e' un gain da applicare.","muted",12)
  text(434,y+99,"Volume: "..N(r.volume,1).." m3 | assorbimento medio: "..N(r.alpha,3),"text",15)
  text(434,y+135,"RT60 Sabine: "..N(r.sabine,2).." s","amber",18)
  text(434,y+167,"RT60 Eyring: "..N(r.eyring,2).." s","amber",18)
  text(434,y+202,"Stime statistiche: campo diffuso, non risposta misurata.","muted",13)
  text(434,y+227,"Meno affidabili in piccole stanze o con assorbimento estremo.","muted",12)
  text(434,y+261,"S = sorgente  |  A = ascoltatore (fronte Y=0)","text",14)
  y=y+313
  text(24,y,"Trascina S e A nella pianta. Altezze modificabili con Coordinate.","muted",14)
  y=y+34
  text(24,y,"Prime riflessioni - clic sul ritardo per copiarlo (riferito al diretto)","text",17)
  y=y+32
  text(28,y,"Superficie","muted")
  text(218,y,"Delta ms","muted")
  text(401,y,"Arrivo ms","muted")
  text(569,y,"dB vs diretto","muted")
  text(745,y,"Azimut","muted")
  text(851,y,"Elevazione","muted")
  y=y+25
  for _,v in ipairs(r.reflections) do
    text(28,y+6,v.name,"text",15)
    if button(N(v.delay_ms,3),214,y,158,false) then copy(N(v.delay_ms,3)) end
    text(401,y+6,N(v.arrival_ms,3),"text",15)
    text(569,y+6,N(v.db,2),"text",15)
    text(745,y+6,N(v.azimuth,1),"text",15)
    text(851,y+6,N(v.elevation,1),"text",15)
    y=y+35
  end
  y=y+20
  text(26,y,"Livelli: sorgente puntiforme omni, perdita 1/r e coefficiente sqrt(1-assorbimento).","muted",14)
  text(26,y+25,"Assorbimento costante con frequenza/angolo. -inf = superficie totalmente assorbente.","muted",14)
  text(26,y+50,"Angoli in gradi: azimut 0 fronte / +90 destra; elevazione + verso l'alto. Non sono valori di pan.","muted",13)
  text(26,y+77,"Non sommare il tempo del diretto ai delta se il segnale dry resta allineato alla traccia.","amber",14)
  y=y+118
  text(26,y,"Modi assiali: primi tre per asse (frequenze ideali, NON suggerimenti EQ)","text",17)
  y=y+33
  for i,v in ipairs(r.modes) do
    text(26+((i-1)%3)*313,y+math.floor((i-1)/3)*28,
      v.axis.." #"..v.order..": "..N(v.hz,1).." Hz","muted",14)
  end
  y=y+112
  text(26,y,"I modi non sono integrati nelle sei riflessioni. Non prediciamo picchi, nulli o risposta audio.","amber",14)
  text(26,y+26,"Geometria e BPM sono indipendenti: quantizzare le riflessioni cambia la stanza simulata.","muted",14)
  return y+75
end

local guide = {
  {"1. Prima il contesto","Scegli effetti ascoltando nel mix: densita' delle note, pause e cambi di accordo contano quanto i BPM.",
    "Un RT60 sincronizzato non chiude la coda sulla griglia. Serve ascolto; un gate puo' imporre una fine."},
  {"2. Davanti / dietro","La profondita' dipende da diretto/riflesso, livello, spettro e attacco, non soltanto dal decay.",
    "Piu' pre-delay puo' preservare la presenza del dry: non significa automaticamente piu' distanza."},
  {"3. Pulizia del riverbero","Su un ritorno parallelo usa normalmente 100% wet, evitando un secondo dry involontario.",
    "Filtra basse e alte se mascherano il mix. Prima del riverbero cambia l'eccitazione; dopo corregge la coda."},
  {"4. Voce leggibile","Un de-esser prima del riverbero limita le sibilanti che lo eccitano.",
    "Il ducking del ritorno lascia passare la frase e fa emergere lo spazio nelle pause."},
  {"5. Delay musicale","Normale, puntato e terzinato producono incastri diversi. Riduci il feedback se si accumulano note o accordi.",
    "Filtri e ducking sulle ripetizioni possono dare profondita' con meno densita' di un riverbero lungo."},
  {"6. Stereo e mono","Una copia ritardata brevemente puo' allargare, ma anche colorare il suono e cancellare frequenze in mono.",
    "Nessun tempo Haas garantisce compatibilita' mono: controlla sempre la somma e i livelli."},
  {"7. Coesione e movimento","Un ambiente condiviso puo' unire gli strumenti; effetti diversi restano una scelta creativa.",
    "Automatizza i send alle fine delle frasi e nei cambi sezione, invece di bagnare tutto in modo costante."},
  {"8. Stanza: ipotesi","Rettangolo, sorgente puntiforme omnidirezionale, sei riflessioni speculari di primo ordine.",
    "Niente HRTF, diffrazione, diffusione, ostacoli o simulazione della risposta modale. Valori da sperimentare."},
  {"9. RT60 e materiali","Sabine/Eyring sono stime di campo diffuso. I materiali reali hanno assorbimento dipendente dalla frequenza.",
    "Non usiamo nomi di materiali con coefficienti arbitrari: inserisci dati attendibili o trattali come ipotesi."},
  {"10. Sicurezza","Questo script non ascolta o elabora audio, non cambia BPM, plugin, tracce o routing.",
    "Salva solo preferenze locali. I report vanno in console; la copia nativa richiede selezione e Ctrl+C / Cmd+C."},
}
local function guide_page(y)
  for _,item in ipairs(guide) do
    text(26,y,item[1],"accent",18)
    text(26,y+29,item[2],"text",14)
    text(26,y+52,item[3],"muted",14)
    y=y+100
  end
  if button("Fonti e formule in console",24,y,270,false) then
    report("perfREV | Fonti\nhttps://www.sengpielaudio.com/calculator-soundpath.htm\n"
      .."https://www.sengpielaudio.com/calculator-RT60.htm\n"
      .."https://www.sengpielaudio.com/calculator-combfilter.htm\n"
      .."https://www.roomeqwizard.com/help/help_en-GB/html/modalsim.html\n"
      .."https://www.izotope.com/community/blog/what-is-reverb\n"
      .."https://www.izotope.com/community/blog/essential-tips-for-mixing-reverb\n"
      .."https://www.waves.com/1lib/pdf/plugins/renaissance-reverb.pdf\n"
      .."Nota ms = 60000/BPM * 4/denominatore. Puntata x1.5; terzina x2/3.\n"
      .."RT60 delay ideale = delay_secondi * ln(0.001)/ln(feedback).\n"
      .."Riflessione delta ms = (percorso riflesso - diretto)/c * 1000.\n"
      .."RT60 Sabine = (24 ln(10)/c) * V/somma(area*alpha).\n"
      .."RT60 Eyring = (24 ln(10)/c) * V/(-S*ln(1-alpha_media)).")
  end
  return y+70
end

local function save()
  for key in pairs(defaults) do reaper.SetExtState(namespace,key,tostring(state[key]),true) end
  local dock,x,y,w,h=gfx.dock(-1,0,0,0,0)
  for key,value in pairs({dock=dock,winx=x,winy=y,winw=w,winh=h}) do
    reaper.SetExtState(namespace,key,tostring(value),true)
  end
  if section_id and command_id and command_id>0 then
    reaper.SetToggleCommandState(section_id,command_id,0)
    reaper.RefreshToolbar2(section_id,command_id)
  end
  gfx.quit()
end
local function info_page(y)
  text(26,y,"perfREV","accent",23)
  text(26,y+43,"Versione "..metadata.version.."   |   Build "..metadata.build,"muted",15)
  text(26,y+82,"Calcolatore per tempo, delay, riverbero e prime riflessioni.","text",16)
  text(26,y+118,"Fonte ufficiale: lib/perfrev_version.lua. Nessuna richiesta online.","muted",14)
  text(26,y+151,"Le preferenze sono locali; il progetto e i plugin non vengono modificati.","muted",14)
  text(26,y+184,"Licenza MIT. Firma RS ecosystem.","muted",14)
  if button("Copia versione / build",26,y+228,240,false) then
    copy("perfREV "..release_label)
  end
  return y+290
end
local function window_value(key,default,lo,hi)
  local v=tonumber(reaper.GetExtState(namespace,key))
  return C.finite(v) and C.clamp(v,lo,hi) or default
end
gfx.init("perfREV - Tempo e spazio",window_value("winw",1000,600,3000),
  window_value("winh",820,450,2000),window_value("dock",0,0,65535),
  window_value("winx",100,-10000,10000),window_value("winy",100,-10000,10000))
reaper.atexit(save)
if section_id and command_id and command_id>0 then
  reaper.SetToggleCommandState(section_id,command_id,1)
  reaper.RefreshToolbar2(section_id,command_id)
end

local max_scroll=0
local function loop()
  local char=gfx.getchar()
  if char<0 or char==27 then return end
  if char==116 or char==84 then tap_now() end
  scale=math.max(0.6,math.min(1.6,gfx.w/980))
  down=(gfx.mouse_cap&1)==1
  pressed=down and not mouse_was_down
  consumed=false
  if not down then drag=nil end
  if gfx.mouse_wheel~=0 then
    scroll=C.clamp(scroll-gfx.mouse_wheel/120*55,0,max_scroll)
    gfx.mouse_wheel=0
  end
  if char==1685026670 then scroll=C.clamp(scroll+65,0,max_scroll) end -- down
  if char==30064 then scroll=C.clamp(scroll-65,0,max_scroll) end -- up
  tempo()
  theme.paint(scale,gfx.w,gfx.h)
  theme.surface(14,49,944,83,scale)
  local pages={delay_page,reverb_page,room_page,guide_page,info_page}
  -- Draw scrolling content into a separate image, then clip it below the fixed header.
  local top,bottom=190,gfx.h/scale-74
  content_bottom=bottom
  local view=math.max(1,bottom-top)
  gfx.setimgdim(1,gfx.w,gfx.h)
  gfx.dest=1
  theme.paint(scale,gfx.w,gfx.h)
  theme.surface(14,top,944,view,scale)
  -- Content coordinates remain window-relative for mouse hit testing.
  drawing_content=true
  local ending=pages[state.tab](top-scroll)
  drawing_content=false
  gfx.dest=-1
  gfx.blit(1,1,0,0,top*scale,gfx.w,view*scale,0,top*scale,gfx.w,view*scale)
  max_scroll=math.max(0,ending+scroll-bottom)
  scroll=C.clamp(scroll,0,max_scroll)
  -- Fixed header must own its input; content behind it is never interactive.
  header()
  rect(0,bottom+6,gfx.w/scale,68,"panel")
  text(24,bottom+17,reaper.time_precise()<status_until and status
    or "Solo calcoli | T = TAP | Rotella / frecce = scorri | Esc = chiudi | "..release_label,"muted",13)
  gfx.setfont(1,"Arial",math.floor(11*scale))
  local signature="RS ecosystem"
  local signature_width=gfx.measurestr(signature)
  text((gfx.w-signature_width)/(2*scale),bottom+46,signature,"muted",11)
  if max_scroll>0 then
    local track=math.max(10,bottom-top)
    local thumb=math.max(25,track*track/(track+max_scroll))
    rect(969,top,5,track,"panel")
    rect(969,top+(track-thumb)*scroll/max_scroll,5,thumb,"accent")
  end
  mouse_was_down=down
  gfx.update()
  reaper.defer(loop)
end
loop()
