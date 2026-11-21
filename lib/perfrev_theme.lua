-- Static, procedural stained-glass cathedral. No assets, network or timers.
local M = {}
M.palette = {
  bg={0.035,0.048,0.078}, panel={0.085,0.105,0.145}, text={0.94,0.94,0.91},
  muted={0.67,0.72,0.76}, accent={0.43,0.86,0.80}, amber={1,0.76,0.43},
  stone={0.43,0.40,0.36}, lead={0.075,0.095,0.13},
}
local glass = {
  {0.95,0.36,0.23},{1,0.65,0.18},{0.99,0.82,0.33},{0.69,0.34,0.64},
  {0.30,0.42,0.84},{0.20,0.69,0.82},{0.22,0.76,0.60},{0.65,0.77,0.32},
}
local cached = ""
local function rgba(c,a) gfx.set(c[1],c[2],c[3],a or 1) end
local function line(x1,y1,x2,y2,s) gfx.line(x1*s,y1*s,x2*s,y2*s) end
local function triangle(x1,y1,x2,y2,x3,y3,s)
  gfx.triangle(x1*s,y1*s,x2*s,y2*s,x3*s,y3*s)
end
local function rose(x,y,r,s,offset)
  rgba(M.palette.stone)
  gfx.circle(x*s,y*s,(r+3)*s,1)
  rgba(M.palette.lead) gfx.circle(x*s,y*s,r*s,1)
  for i=0,15 do
    local a,b=i*math.pi/8,(i+1)*math.pi/8
    rgba(glass[(i+(offset or 0))%#glass+1],0.87)
    triangle(x,y,x+math.cos(a)*(r-3),y+math.sin(a)*(r-3),
      x+math.cos(b)*(r-3),y+math.sin(b)*(r-3),s)
    rgba(M.palette.lead) line(x,y,x+math.cos(a)*(r-2),y+math.sin(a)*(r-2),s)
  end
  rgba(M.palette.stone)
  gfx.circle(x*s,y*s,r*0.54*s,0)
  rgba(glass[((offset or 0)+2)%#glass+1])
  gfx.circle(x*s,y*s,r*0.19*s,1)
end
function M.paint(s,w,h)
  local key=string.format("%.4f:%d:%d",s,w,h)
  local dest=gfx.dest
  if key~=cached then
    gfx.setimgdim(2,w,h)
    gfx.dest=2
    rgba(M.palette.bg) gfx.rect(0,0,w,h,1)
    local width,height=w/s,h/s
    -- Warm west light and cool east light. Geometry is deterministic.
    for side=0,1 do
      local x=side==0 and 0 or width
      local c=side==0 and glass[2] or glass[6]
      rgba(c,0.075)
      triangle(x,32,x+(side==0 and 390 or -390),height,x,height,s)
      rgba(c,0.045)
      triangle(x,170,x+(side==0 and 590 or -590),height,x+(side==0 and 110 or -110),height,s)
      rgba(M.palette.stone,0.45)
      for i=0,3 do
        local start=side==0 and -48+i*7 or width+48-i*7
        line(start,0,side==0 and 10+i*5 or width-10-i*5,height,s)
      end
    end
    -- Rose windows above the controls and round windows on the side aisles.
    for i=0,4 do rose(490+i*100,25,19,s,i*2) end
    for i=0,3 do
      rose(5,225+i*175,29,s,i)
      rose(width-5,225+i*175,29,s,i+4)
    end
    -- Ribbed vault, kept very subtle behind the title.
    rgba(M.palette.stone,0.3)
    for i=0,5 do
      local x=140+i*145
      line(x-85,0,x,45,s) line(x+85,0,x,45,s)
    end
    gfx.dest=dest
    cached=key
  end
  gfx.set(1,1,1,1)
  gfx.blit(2,1,0)
end
function M.surface(x,y,w,h,s)
  rgba(M.palette.panel,0.96)
  gfx.rect(x*s,y*s,w*s,h*s,1)
  rgba(M.palette.stone,0.48)
  gfx.rect(x*s,y*s,w*s,h*s,0)
end
return M
