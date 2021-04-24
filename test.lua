-- title:  Remap demo
-- author: AnastasiaDunbar, Lua translation by StinkerB06

W=240
H=136
T=8

MAP_W=240
MAP_H=136

BTN_Z=4
BTN_X=5

rnd=math.random
cos=math.cos
sin=math.sin
sf=string.format

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
        copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

RESOURCES={
    COAL={
        value=10,
        weight=10
    },
    EMERALD={
        value=100,
        weight=1
    }
}

BLOCKS={
    DIRT={
        name="dirt",
        hardness=10,
        resource=nil
    },
    GRANITE={
        name="granite",
        hardness=30,
        resource=nil,
    },
    COAL={
        name="coal",
        hardness=20,
        resource=RESOURCES.COAL,
        prob=0.5
    },
    EMERALD={
        name="emerald",
        hardness=120,
        resource=RESOURCES.EMERALD,
        prob=0.2
    }
}

def_tile={
    block=BLOCKS.DIRT,
    seen=false,
    dug=false
}

MAP={}

TILES_TO_BLOCKS={
    [1]=BLOCKS.DIRT,
    [2]=BLOCKS.GRANITE,
    [3]=BLOCKS.COAL,
    [4]=BLOCKS.EMERALD
}

ST={
    IDLE=1,
    WORK=2
}

-- textures & animation

function make_tex(c0,w,h)
    tex={}
    for i=1,h do
        tex[i]={}
        for j=1,w do
            tex[i][j]=c0 + (j-1) + (i-1)*16
        end
    end
    return tex
end

-- map

function generateMap()
    for y=0,MAP_H-1 do
        MAP[y] = {}
        for x=0,MAP_W-1 do
            tile = 1
            if y > 10 then
                tile=rnd(1,4)
            end
            local map_tile=deepcopy(def_tile)
            map_tile.block=TILES_TO_BLOCKS[tile]
            if x > 10 and x < 16 then
                if y > 5 and y < 9 then
                    map_tile.seen=true
                    map_tile.dug=true
                end
            end
            MAP[y][x]=map_tile
            mset(x, y, tile)
        end
    end
end

-- vectors

function sq( v )
    return v*v
end

function v2( x,y )
    return{x=x,y=y}
end

function dist_2d(x0, y0, x1, y1)
    local p1,p2 = sq(x0-x1),sq(y0-y1)
    return math.sqrt(p1+p2)
end

function v2dist( v1,v2 )
    local p1,p2 = sq(v1.x-v2.x),sq(v1.y-v2.y)
    local res = math.sqrt(p1+p2)
    return res
end

function rot_2d( x0, y0, cx, cy, angle )
    local x1,y1,da,dist
    dist = dist_2d(cx, cy, x0, y0)
    da = math.atan(y0-cy, x0-cx)
    x1 = dist * cos(angle + da) + cx
    y1 = dist * sin(angle + da) + cy
    return x1,y1
end

function init()
    generateMap()
    PLAYER.x=88
    PLAYER.y=56
end

function remap(tile,x,y)
    local outTile,flip,rotate=tile,0,0
    if MAP[y][x].dug then
        outTile = 0
    end
    -- animation: 
    -- if tile==yourWaterfallTile then
    -- 	outTile=outTile+math.floor(gameTicks*speed)%frames
    -- end
    return outTile,flip,rotate --or simply `return outTile`.
end

PLAYER={
    x=0,y=0,
    w=40,h=16,
    rot=0,
    st=ST.IDLE,
    sp=make_tex(256,5,2),
    tex={x=0,y=128,w=40,h=16}
}

ENTITIES={
    PLAYER
}

function draw_ent(e, cam)
    local i=1
    local dx,dy=0,0
    local cx,cy = e.x + e.w / 2, e.y + e.h / 2
    local x0,y0 = rot_2d(e.x, e.y, cx, cy, e.rot)
    local x1,y1 = rot_2d(e.x + e.w, e.y, cx, cy, e.rot)
    local x2,y2 = rot_2d(e.x, e.y + e.h, cx, cy, e.rot)
    local x3,y3 = rot_2d(e.x + e.w, e.y + e.h, cx, cy, e.rot)

    if cam ~= nil then dx,dy = cam.x,cam.y end
    -- for i,t in ipairs(e.sp) do
    --     for j,v in ipairs(t) do
    --         if e.dir == nil or e.dir == DIR.R then
    --             spr(v, e.x+(j-1)*T+dx, e.y+(i-1)*T+dy, 0)
    --         else
    --             tlen = #t
    --             spr(v, e.x+(tlen-j)*T+dx, e.y+(i-1)*T+dy, 0, 1, 1)
    --         end
    --     end
    -- end

    textri(x0+dx, y0+dy, x1+dx, y1+dy, x2+dx, y2+dy, e.tex.x, e.tex.y, e.tex.x + e.tex.w, e.tex.y, e.tex.x, e.tex.y+e.tex.h, false, 0)
    textri(x1+dx, y1+dy, x2+dx, y2+dy, x3+dx, y3+dy, e.tex.x + e.tex.w, e.tex.y, e.tex.x, e.tex.y+e.tex.h, e.tex.x + e.tex.w, e.tex.y + e.tex.h, false, 0)
end

function draw()
    for i,v in ipairs(ENTITIES) do
        draw_ent(v)
    end
end

init()
function TIC()
    cls()
    map(0,0,30,17,0,0,-1,1,remap) --The `remap()` function is used here.
    local x,y=mouse()
    local mx,my = x//T,y//T
    rectb(mx*T,my*T,T,T,1)
    local tile=MAP[my][mx]
    print(sf("%s %s", tile.block.name, tile.dug), mx*T+T, my*T+T, 12)
    draw()
    if btn(BTN_X) then PLAYER.rot = PLAYER.rot - 0.02 end
    if btn(BTN_Z) then PLAYER.rot = PLAYER.rot + 0.02 end
    -- animation
    -- gameTicks=gameTicks+1
end
