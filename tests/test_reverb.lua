local R=dofile("lib/perfrev_reverb.lua")
local count=0
local function check(value,message) count=count+1 assert(value,message or ("Reverb assertion "..count)) end
check(R.category(0.99)=="Corto")
check(R.category(1)=="Medio")
check(R.category(2)=="Medio")
check(R.category(2.01)=="Lungo")
check(#R.types==16 and R.rverb_types==12)
local s={
  decay_q=2,rev_time_mode="musical",rev_time_s=25,predelay=20,rev_profile="generic",
  rev_route="send",rev_type=4,rev_size=50,rev_diffusion=75,rev_shape=3.5,
  rev_early=-6,rev_tail=0,rev_wet=100,rev_gain=0,rev_lf=200,rev_lratio=1,
  rev_hf=6000,rev_hratio=1,rev_eqlf=200,rev_eqlgain=0,rev_eqhf=6000,rev_eqhgain=0,rev_decorr=0,
}
check(R.time_ms(s,100)==1200)
check(R.time_ms(s,200)==600)
check(#R.warnings(s,100)==0)
s.rev_time_mode="free"
check(R.time_ms(s,100)==25000 and R.time_ms(s,200)==25000)
check(#R.warnings(s,100)==0)
s.rev_profile="rverb"
check(#R.warnings(s,100)==1)
s.rev_time_s=1.2
local rows=R.rows(s,100)
check(#rows==15)
check(rows[1][2]=="Time" and rows[1][3]:find("1.200 s",1,true))
check(rows[6][2]=="Decay" and rows[6][3]:find("linear",1,true))
check(rows[2][4]:find("dry + ER",1,true))
for i=1,12 do
  s.rev_type=i
  check(R.type_name(s)==R.types[i][1])
end
s.rev_type=13
check(#R.warnings(s,100)>0)
s.rev_type=4 s.predelay=200
check(#R.warnings(s,100)==1)
check(s.predelay==200,"Warning must not mutate input")
s.predelay=-20
check(R.warnings(s,100)[1]:find("negativo",1,true))
s.predelay=20 s.rev_wet=30
check(#R.warnings(s,100)==1)
s.rev_route="insert"
check(#R.warnings(s,100)==0)
s.rev_early=-50 s.rev_tail=4 s.rev_gain=2 s.rev_size=0 s.rev_diffusion=0
check(#R.warnings(s,100)==3)
s.rev_profile="generic"
check(#R.warnings(s,100)==0,"RVerb-specific caps must not constrain generic plugins")
s.rev_type=16 s.rev_custom_type="IR studio personale"
check(R.type_name(s)=="IR studio personale")
print("Reverb: "..count.." assertions passed")
