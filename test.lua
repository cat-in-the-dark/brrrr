-- title:  Remap demo
-- author: AnastasiaDunbar, Lua translation by StinkerB06

W=240
H=136
T=8
INNER_R=4
OUTER_R=INNER_R * math.sqrt(2)

MAP_W=240
MAP_H=136

UP=0
DOWN=1
LEFT=2
RIGHT=3
BTN_Z=4
BTN_X=5
KEY_SPACE=48

pi=math.pi
rnd=math.random
cos=math.cos
sin=math.sin
min=math.min
max=math.max
abs=math.abs
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
        mass=10
    },
    EMERALD={
        value=100,
        mass=1
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
        hardness=10,
        resource=nil,
    },
    COAL={
        name="coal",
        hardness=10,
        resource=RESOURCES.COAL,
        prob=0.5
    },
    EMERALD={
        name="emerald",
        hardness=40,
        resource=RESOURCES.EMERALD,
        prob=0.2
    }
}

def_tile={
    block=BLOCKS.DIRT,
    wear=1.0,
    seen=false,
    debug=false,
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

-- vectors

function sign(x) return x>0 and 1 or x<0 and -1 or 0 end

function sq( v )
    return v*v
end

function v2( x,y )
    return{x=x,y=y}
end

function v2add( v1,v2 )
    return {x=v1.x+v2.x,y=v1.y+v2.y}
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

function rot_poly( p,cx,cy,angle )
    local res = {}
    for i,v in ipairs(p) do
        res[i] = v2(rot_2d(v.x,v.y,cx,cy,angle))
    end
    return res
end

function move_poly( p, dv )
    local res = {}
    for i,v in ipairs(p) do
        res[i] = v2add(v, dv)
    end
    return res
end

polygon={v2(0,0), v2(0,1), v2(1,1), v2(1,0)}

function intersect_polygons(a, b)
    local polygons={a,b}
    local minA, maxA, projected, i, i1, j, minB, maxB
    for i,p in ipairs(polygons) do
        for i1,p1 in ipairs(p) do
            local i2 = (i1+1) % #p
            if i2 == 0 then i2 = #p end
            local p2 = p[i2]
            local normal = v2(p2.y-p1.y, p1.x-p2.x)
            minA,maxA=nil,nil
            for j,v in ipairs(a) do
                projected = normal.x * v.x + normal.y * v.y
                if minA == nil or projected < minA then minA = projected end
                if maxA == nil or projected > maxA then maxA = projected end
            end
            minB,maxB = nil,nil
            for j,v in ipairs(b) do
                projected = normal.x * v.x + normal.y * v.y
                if minB == nil or projected < minB then minB = projected end
                if maxB == nil or projected > maxB then maxB = projected end
            end
            if maxA < minB or maxB < minA then
                return false
            end
        end
    end
    return true
end

function tile_to_polygon(x,y)
    local tx,ty = x*T, y*T
    return {
        v2(tx, ty),
        v2(tx+T, ty),
        v2(tx+T, ty+T),
        v2(tx, ty+T)
    }
end

function ent_to_polygon(e)
    local cx,cy = e.pos.x + e.center.x, e.pos.y + e.center.y
    local x0,y0 = rot_2d(e.pos.x + e.cr.x,          e.pos.y + e.cr.y,           cx, cy, e.rot)
    local x1,y1 = rot_2d(e.pos.x + e.cr.x + e.cr.w, e.pos.y + e.cr.y,           cx, cy, e.rot)
    local x2,y2 = rot_2d(e.pos.x + e.cr.x + e.cr.w, e.pos.y + e.cr.y + e.cr.h,  cx, cy, e.rot)
    local x3,y3 = rot_2d(e.pos.x + e.cr.x,          e.pos.y + e.cr.y + e.cr.h,  cx, cy, e.rot)
    return {v2(x0,y0), v2(x1,y1), v2(x2, y2), v2(x3, y3)}
end

function aabb(point, x, y, w, h)
    return x < point.x and point.x < x + w and y < point.y and point.y < y + h
end

function intersect_circle_aabb(c, x, y, w, h, inner, outer)
    if inner == nil then inner = math.min(w, h) / 2 end
    if outer == nil then outer = math.sqrt(sq(w/2)+sq(h/2)) end
    local aabbC = v2(x+w/2, y+h/2)
    local dist = v2dist(c, aabbC)
    local angle = math.atan2(aabbC.y-c.y, aabbC.x-c.x)
    if aabb(c, x, y, w, h) then
        return true, dist, angle, nil, nil
    else
        local xn, yn = max(x, min(c.x, x+w)), max(y, min(c.y, y+h))
        local dst = v2dist(c, v2(xn, yn))
        if dst < c.r then
            return true, dist, angle, xn, yn
        else
            return false, dist, angle, xn, yn
        end
    end
end

function collide_tile_cicrle(c, callback)
    local minX, maxX = c.x - c.r, c.x + c.r
    local minY, maxY = c.y - c.r, c.y + c.r
    local startX,startY,endX,endY = minX // T, minY // T, maxX // T, maxY // T
    for x=startX,endX do
        for y=startY,endY do
            local tileX, tileY = x * T, y * T
            local res, dist, angle, xn, yn = intersect_circle_aabb(c, tileX, tileY, T, T)
            if res then callback(x, y, dist, angle, xn, yn) end
        end
    end
end

function collide_tile_poly( poly, callback )
    local minX, maxX, minY, maxY = nil,nil,nil,nil
    for i,v in ipairs(poly) do
        if minX == nil or minX > v.x then minX = v.x end
        if maxX == nil or maxX < v.x then maxX = v.x end
        if minY == nil or minY > v.y then minY = v.y end
        if maxY == nil or maxY < v.y then maxY = v.y end
    end

    local startX,startY,endX,endY = minX // T, minY // T, maxX // T, maxY // T
    for x=startX,endX do
        for y=startY,endY do
            local tp = tile_to_polygon(x,y)
            if intersect_polygons(tp, poly) then
                callback(x, y)
            end
        end
    end
end

function collide_tile(pos, cr, callback)
    -- no rotation
    local crx, cry = pos.x + cr.x, pos.y + cr.y
    local startX, startY = crx // T, cry // T
    local endX, endY = (crx + cr.w) // T, (cry + cr.h) // T
    for x=startX,endX do
        for y=startY,endY do
            callback(x, y)
        end
    end
end

function remaining_capacity( container )
    local mass=0
    for i,item in ipairs(container.items) do
        mass = mass + item.mass
    end
    return container.capacity - mass
end

function burr(pl)
    local res = rot_poly(pl.burr_poly, pl.center.x, pl.center.y, pl.rot)
    res = move_poly(res, pl.pos)
    collide_tile_poly(res, function(x, y)
        if not MAP[y][x].dug then
            local tile = mget(x, y)
            MAP[y][x].wear = MAP[y][x].wear - pl.power / TILES_TO_BLOCKS[tile].hardness
            if MAP[y][x].wear <= 0 then
                MAP[y][x].dug = true
                local blk = MAP[y][x].block
                local res = blk.resource
                if res ~= nil then
                    if math.random() < blk.prob then
                        if remaining_capacity(pl.container) > res.mass then
                            table.insert( pl.container.items, res )
                        end
                    end
                end
            end
        end
    end)
end

function move_player(pl)
    local dx,dy,rot,speed=0,0,0,1
    if btn(UP) then dy=-speed end
    if btn(DOWN) then dy=speed end
    if btn(LEFT) then dx=-speed end
    if btn(RIGHT) then dx=speed end

    if dx == 0 and dy == 0 then return end

    rot=math.atan2(dy,dx)
    dx=speed * cos(rot)
    dy=speed * sin(rot)

    local hit=false
    repeat
        hit = false
        local target = v2add(v2add(pl.pos, v2(dx,dy)), pl.cc)
        local tangle,txn,tyn
        local min_dist = nil
        collide_tile_cicrle({x=target.x, y=target.y, r=pl.cc.r}, function(x, y, dist, angle, xn, yn)
            if not MAP[y][x].dug then
                hit=true
                if min_dist == nil or dist < min_dist then
                    min_dist = dist
                    txn,tyn,tangle = xn,yn,angle
                end
            end
        end)

        if hit then
            if txn ~= nil and tyn ~= nil then
                local goal_dist = pl.cc.r
                local dist_to_xn = v2dist(target, v2(txn,tyn))
                local diff = goal_dist - dist_to_xn
                dx = dx - diff * cos(tangle)
                dy = dy - diff * sin(tangle)
            else
                dx=0
                dy=0
            end
        end
        -- if abs(dx) < 0.0001 and abs(dy) < 0.0001 then hit = false end
    until hit == false

    pl.rot=rot
    pl.pos.x = pl.pos.x + dx
    pl.pos.y = pl.pos.y + dy
end

function draw_ent(e, cam)
    local i=1
    local dx,dy=0,0
    local cx,cy = e.pos.x + e.center.x, e.pos.y + e.center.y
    local x0,y0 = rot_2d(e.pos.x,           e.pos.y, cx, cy, e.rot)
    local x1,y1 = rot_2d(e.pos.x + e.pos.w, e.pos.y, cx, cy, e.rot)
    local x2,y2 = rot_2d(e.pos.x,           e.pos.y + e.pos.h, cx, cy, e.rot)
    local x3,y3 = rot_2d(e.pos.x + e.pos.w, e.pos.y + e.pos.h, cx, cy, e.rot)

    if cam ~= nil then dx,dy = -cam.x,-cam.y end
    textri(x0+dx, y0+dy, x1+dx, y1+dy, x2+dx, y2+dy, e.tex.x, e.tex.y, e.tex.x + e.tex.w, e.tex.y, e.tex.x, e.tex.y+e.tex.h, false, 0)
    textri(x1+dx, y1+dy, x2+dx, y2+dy, x3+dx, y3+dy, e.tex.x + e.tex.w, e.tex.y, e.tex.x, e.tex.y+e.tex.h, e.tex.x + e.tex.w, e.tex.y + e.tex.h, false, 0)
end

function draw(cam)
    drawMap(cam)
    for i,v in ipairs(ENTITIES) do
        draw_ent(v,cam)
    end
end

PLAYER={
    pos={x=0,y=0,w=32,h=16},
    center=v2(8, 8),
    cc={x=8,y=8,r=8},
    burr_poly={v2(16,0), v2(32,8), v2(16,16)},
    container={capacity=100, items={}},
    power=1.0,
    rot=0,
    st=ST.IDLE,
    tex={x=0,y=128,w=32,h=16}
}

ENTITIES={
    PLAYER
}

CIRCLE = {
    x=50,
    y=50,
    r=25
}

AABB={
    x=120,
    y=70,
    w=20,
    h=20
}

CAM={
    x=0,y=0
}

function updateCam(cam,e)
    cam.x=e.pos.x-W//2
    cam.y=e.pos.y-H//2
end

function drawMap( cam )
    local cx,cy = cam.x // T, cam.y // T
    local offx, offy = cx * T - cam.x, cy * T - cam.y
    map(cx,cy,30,17,offx,offy,-1,1,function(tile,x,y)
        local outTile,flip,rotate=tile,0,0
        if MAP[y][x].dug then
            outTile = 0
        end
        if MAP[y][x].debug then
            outTile = 17
        end
        -- animation: 
        -- if tile==yourWaterfallTile then
        -- 	outTile=outTile+math.floor(gameTicks*speed)%frames
        -- end
        return outTile,flip,rotate --or simply `return outTile`.
    end)
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
            if x > 10 and x < 100 then
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

-- init

function init()
    generateMap()
    PLAYER.pos.x=W//2
    PLAYER.pos.y=H//2
end

init()
function TIC()
    cls()
    updateCam(CAM, PLAYER)
    draw(CAM)
    -- local x,y=mouse()
    -- local mx,my = (CAM.x + x)//T,(CAM.y + y)//T
    -- rectb(mx*T,my*T,T,T,1)
    -- local tile=MAP[my][mx]
    -- print(sf("%s %s", tile.block.name, tile.dug), mx*T+T, my*T+T, 12)
    if btn(BTN_X) then PLAYER.rot = PLAYER.rot - 0.02 end
    if btn(BTN_Z) then PLAYER.rot = PLAYER.rot + 0.02 end
    burr(PLAYER)
    move_player(PLAYER)
    -- animation
    -- gameTicks=gameTicks+1
end
