local triangles,lines,blits,allocations=0,0,0,0
gfx={
  dest=-1,x=900,y=700,set=function() end,rect=function() end,circle=function() end,
  line=function() lines=lines+1 end,
  triangle=function() triangles=triangles+1 end,
  setimgdim=function() allocations=allocations+1 end,
  blit=function(img,s,r,sx,sy,sw,sh,dx,dy,dw,dh)
    assert(img==2 and dx==0 and dy==0,"Background must ignore stale gfx.x/y")
    assert(dw==sw and dh==sh)
    blits=blits+1
  end,
}
local theme=dofile("lib/perfrev_theme.lua")
theme.paint(1,980,820)
assert(triangles>100 and lines>100 and blits==1 and allocations==1)
local before=triangles
gfx.dest=1
theme.paint(1,980,820)
assert(triangles==before,"Static scene rebuilt without resize")
assert(gfx.dest==1,"Destination not preserved")
assert(blits==2 and allocations==1)
theme.paint(0.6,600,450)
assert(triangles>before and allocations==2)
assert(gfx.dest==1)
print("Theme: static cache, resizing and explicit origin verified")
