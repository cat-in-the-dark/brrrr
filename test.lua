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
KEY_F = 06
KEY_S = 19
KEY_Q = 17

pi=math.pi
rnd=math.random
cos=math.cos
sin=math.sin
min=math.min
max=math.max
abs=math.abs
sf=string.format

-- helpers

function printframe(text,x,y,c,fc,small)
    c = c or 15
    fc = fc or 0
    small = small or false
    print(text,x-1,y,fc,false,1,small)
    print(text,x+1,y,fc,false,1,small)
    print(text,x,y-1,fc,false,1,small)
    print(text,x,y+1,fc,false,1,small)
    print(text,x-1,y-1,fc,false,1,small)
    print(text,x+1,y-1,fc,false,1,small)
    print(text,x-1,y+1,fc,false,1,small)
    print(text,x+1,y+1,fc,false,1,small)
    print(text,x,y,c,false,1,small)
end

function safe1( f, arg )
    if f ~= nil then f(arg) end
end

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

function table.index(table, element)
    for i, value in pairs(table) do
      if value == element then
        return i
      end
    end
    return nil
end

-- buttons

Button={
    x=0,
    y=0,
    w=0,
    h=0,
    pressed=false,
    hover=false,
    color=0,
    sp={},
    offx=0,
    offy=0,
    text=nil,
    on_enter=nil,
    on_hover=nil,
    on_press=nil,
    on_release=nil,
    on_leave=nil
}


function g_press( btn )
    btn.color = 6
end

function g_release( btn )
    btn.color = 7
end

function g_hover( btn )
    btn.color = 8
end

function g_leave( btn )
    btn.color = btn.orig_c
end
  
function make_button( x, y, w, h, color, item, text, on_hover, on_leave, on_press, on_release, on_enter, sp, offx, offy, on_draw )
    local btn = deepcopy(Button)
    btn.x, btn.y = x,y
    btn.w, btn.h = w,h
    btn.color = color
    btn.orig_c = color
    btn.on_hover = on_hover
    btn.on_leave = on_leave
    btn.on_press = on_press
    btn.on_release = on_release
    btn.on_enter = on_enter
    btn.text=text
    btn.item=item
    btn.sp = sp
    btn.offx = offx
    btn.offy = offy
    btn.on_draw = on_draw
    return btn
end
  
function check_button( btn, mx, my, md )
    local x,y,r,d = btn.x, btn.y, btn.x + btn.w, btn.y + btn.h
    local old_hover = btn.hover
    local old_pressed = btn.pressed
    if x <= mx and r >= mx and y <= my and d >= my then
        btn.hover = true
        if md then
        btn.pressed = true
        else
        btn.pressed = false
        end
    else
        btn.hover = false
        btn.pressed = false
    end

    if btn.hover then
        safe1(btn.on_hover, btn)
    end

    if old_hover and not btn.hover then
        safe1(btn.on_leave, btn)
    elseif not old_hover and btn.hover then
        safe1(btn.on_enter, btn)
    end
    if old_pressed and not btn.pressed then
        safe1(btn.on_release, btn)
    elseif btn.pressed and not old_pressed then
        safe1(btn.on_press, btn)
    end
end
  
function draw_text_btn( btn,text )
    rect(btn.x, btn.y, btn.w, btn.h, btn.color)
    rectb(btn.x, btn.y, btn.w, btn.h, 2)
    local dx,dy=0,0
    if btn.pressed then
        rectb(btn.x + 1, btn.y + 1, btn.w - 1, btn.h - 1, 2)
        dx,dy=1,1
    else
        rectb(btn.x, btn.y, btn.w - 1, btn.h - 1, 2)
    end
    local tw,th = print(text, W,H),8
    printframe(text, btn.x + btn.w/2 - tw/2 + dx, btn.y + btn.h/2 - th/2 + dy, 6)
end

function draw_button( btn )
    if btn.on_draw ~= nil then
        btn.on_draw(btn)
        return
    end
    if btn.text ~= nil then
        draw_text_btn(btn, btn.text)
        return
    end
    rect(btn.x, btn.y, btn.w, btn.h, btn.color)
    rectb(btn.x, btn.y, btn.w, btn.h, 2)
    rectb(btn.x + 1, btn.y + 1, btn.w - 1, btn.h - 1, 2)
    if btn.item ~= nil then
        local item,x,y,w,h = btn.item,btn.x,btn.y,btn.w,btn.h
        local ent = {pos={x=x, y=y}, sp=item.sp, offx=btn.offx, offy=btn.offy}
        draw_ent(ent)
    end
end

-- minerals

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
    },
    OBSIDIAN={
        name="obsidian",
        hardness=-1
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
    [4]=BLOCKS.EMERALD,
    [5]=BLOCKS.OBSIDIAN
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

function intersect_circle_aabb(c, x, y, w, h)
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

function cargo_mass( pl )
    local mass=0
    for i,item in ipairs(pl.container_items) do
        mass = mass + item.mass
    end
    return mass
end

function burr(pl)
    local res = rot_poly(pl.burr_poly, pl.center.x, pl.center.y, pl.rot)
    res = move_poly(res, pl.pos)
    collide_tile_poly(res, function(x, y)
        if not MAP[y][x].dug then
            if pl.fuel <= 0 then
                trace("no fuel!")
                return
            end

            if cargo_mass(pl) > pl.container.value then
                trace("Overload!")
                return
            end

            -- dig tile
            local tile = mget(x, y)

            -- special edge tiles
            if TILES_TO_BLOCKS[tile].hardness == -1 then
                return
            end

            MAP[y][x].wear = MAP[y][x].wear - pl.engine.value / TILES_TO_BLOCKS[tile].hardness

            -- drain fuel
            pl.fuel = pl.fuel - pl.engine.value / 10
            if pl.fuel < 0 then pl.fuel = 0 end

            if MAP[y][x].wear <= 0 then
                MAP[y][x].dug = true
                local blk = MAP[y][x].block
                local res = blk.resource
                if res ~= nil then
                    if math.random() < blk.prob * pl.burr.value then
                        table.insert( pl.container_items, res )
                    end
                end
            end
        end
    end)
end

function refuel(pl)
    local cap = pl.fuel_tank.value - pl.fuel
    trace(cap)
    local cost = min(cap * FUEL_PRICE, pl.money)
    trace(cost)
    local amount = cost / FUEL_PRICE
    trace(amount)
    pl.fuel = pl.fuel + amount
    pl.money = pl.money - cost
end

function sell_resources(pl)
    local sum=0
    for i,item in ipairs(pl.container_items) do
        sum = sum + item.value
    end
    pl.money = pl.money + sum
    pl.container_items = {}
end

function check_shop(shop, pl)
    local x,y = shop.pos.x + shop.cr.x, shop.pos.y + shop.cr.y
    -- trace(sf("%f %f %f %f", x, y, shop.cr.w, shop.cr.h))
    local c = {x=pl.pos.x + pl.cc.x, y=pl.pos.y + pl.cc.y, r=pl.cc.r}
    -- trace(sf("%f %f %f", c.x, c.y, c.r))
    res,_,_,_,_ = intersect_circle_aabb(c, x, y, shop.cr.w, shop.cr.h)
    if res then MODE = MOD_SHOP end
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

    -- map discovery
    collide_tile_cicrle({x=pl.pos.x + pl.center.x, y=pl.pos.y + pl.center.y, r=pl.radar.value}, function(x, y, dist, angle, xn, yn)
        if MAP[y] ~= nil and MAP[y][x] ~= nil and not MAP[y][x].seen then
            MAP[y][x].seen=true
        end
    end)

    -- collision
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

    -- map bounds
    if pl.pos.y + pl.pos.h < GROUND_HEIGT then
        pl.pos.y = GROUND_HEIGT - pl.pos.h
    end
end

function draw_ent(e, cam)
    local i=1
    local dx,dy=0,0
    if cam ~= nil then dx,dy = -cam.x,-cam.y end
    if e.tex ~= nil then
        local cx,cy = e.pos.x + e.center.x, e.pos.y + e.center.y
        local x0,y0 = rot_2d(e.pos.x,           e.pos.y, cx, cy, e.rot)
        local x1,y1 = rot_2d(e.pos.x + e.pos.w, e.pos.y, cx, cy, e.rot)
        local x2,y2 = rot_2d(e.pos.x,           e.pos.y + e.pos.h, cx, cy, e.rot)
        local x3,y3 = rot_2d(e.pos.x + e.pos.w, e.pos.y + e.pos.h, cx, cy, e.rot)

        textri(x0+dx, y0+dy, x1+dx, y1+dy, x2+dx, y2+dy, e.tex.x, e.tex.y, e.tex.x + e.tex.w, e.tex.y, e.tex.x, e.tex.y+e.tex.h, false, 0)
        textri(x1+dx, y1+dy, x2+dx, y2+dy, x3+dx, y3+dy, e.tex.x + e.tex.w, e.tex.y, e.tex.x, e.tex.y+e.tex.h, e.tex.x + e.tex.w, e.tex.y + e.tex.h, false, 0)
    elseif e.sp ~= nil then
        local offx,offy = e.offx, e.offy
        if offx == nil then offx = 0 end
        if offy == nil then offy = 0 end
        for i,t in ipairs(e.sp) do
            for j,v in ipairs(t) do
                spr(v, e.pos.x+(j-1)*T + offx + dx, e.pos.y+(i-1)*T + offy + dy, 0)
            end
        end
    end
end

function drawHud( pl )
    local str = sf("$%.0f", pl.money)
    local w = print(str, W, H)
    print(str, W-w, H-8, 12)

    str = sf("fuel: %.1f/%.1f, cargo: %.0f/%.0f", pl.fuel, pl.fuel_tank.value, cargo_mass(pl), pl.container.value)
    w = print(str, W, H)
    print(str, W-w, H-16, 12)
end

function drawSky(cam)
    local sky_height = GROUND_HEIGT - cam.y
    if sky_height <= 0 then return end
    rect(0, 0, W, sky_height, 10)
end

SHOP={
    pos=v2((W*T)//2-80,48),
    sp=make_tex(336,6,4),
    cr={x=0,y=6,w=48,h=26}
}

function drawShop(cam)
    draw_ent(SHOP,cam)
end

function draw(cam, pl)
    drawSky(cam)
    drawShop(cam)
    drawMap(cam)
    for i,v in ipairs(ENTITIES) do
        draw_ent(v,cam)
    end
    drawHud(pl)
end

-- balance

FUEL_PRICE=1.0

FUEL_TANKS={
    [1]={value=100, name="basic", price=0},
    [2]={value=200, name="large" , price=400},
    [3]={value=300, name="XL", price=800}
}

BURRS={
    [1]={value=1.0, name="basic", price=0},
    [2]={value=1.1, name="fine", price=500},
    [3]={value=1.2, name="precise", price=1000}
}

CONTAINERS={
    [1]={value=100, name="basic", price=0},
    [2]={value=200, name="large", price=400},
    [3]={value=300, name="XL", price=800}
}

ENGINES={
    [1]={value=1.0, name="basic", price=0},
    [2]={value=2.0, name="v8", price=1000},
    [3]={value=3.0, name="greta", price=2000}
}

RADARS={
    [1]={value=32, name="basic", price=0},
    [2]={value=48, name="X-RAY penetrator", price=200},
    [3]={value=64, name="God's eye", price=800}
}

PLAYER={
    pos={x=0,y=0,w=32,h=16},
    center=v2(8, 8),
    cc={x=8,y=8,r=8},
    burr_poly={v2(16,1), v2(32,8), v2(16,15)},
    burr=BURRS[1],
    container=CONTAINERS[1],
    container_items={},
    engine=ENGINES[1],
    fuel_tank=FUEL_TANKS[1],
    fuel=FUEL_TANKS[1].value,
    radar=RADARS[1],
    money=0,
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

-- camera

CAM={
    x=0,y=0
}

function updateCam(cam,e)
    cam.x=e.pos.x-W//2
    cam.y=max(0, e.pos.y-H//2)
end

-- map

function drawMap( cam )
    local cx,cy = cam.x // T, cam.y // T
    local offx, offy = cx * T - cam.x, cy * T - cam.y
    map(cx,cy,31,18,offx,offy,0,1,function(tile,x,y)
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

    map(cx,cy,32,19,offx-2,offy-2,8,1,function(tile,x,y)
        local outTile,flip,rotate=tile,0,0
        if MAP[y][x].seen then
            outTile = 19 -- transparent
        else
            outTile = 18
        end
        return outTile
    end)
end

GROUND_HEIGT_T  = 10
GROUND_HEIGT    = GROUND_HEIGT_T * T
WALL_LEFT_T     = 4
WALL_LEFT       =WALL_LEFT_T * T
WALL_RIGHT_T    = W - 4
WALL_RIGHT      = WALL_RIGHT_T * T
WALL_DOWN_T     = H - 4

function generateMap()
    for y=0,MAP_H-1 do
        MAP[y] = {}
        for x=0,MAP_W-1 do
            tile = 1
            if y > GROUND_HEIGT_T then
                tile=rnd(1,4)
            end
            if x < WALL_LEFT_T or x > WALL_RIGHT_T or y > WALL_DOWN_T then
                tile=5
            end

            local map_tile=deepcopy(def_tile)
            map_tile.block=TILES_TO_BLOCKS[tile]
            if y <= GROUND_HEIGT_T and x >= WALL_LEFT_T and x <= WALL_RIGHT_T then
                map_tile.seen=true
                map_tile.dug=true
            elseif y < GROUND_HEIGT_T + RADARS[1].value // T then
                map_tile.seen=true
            end
            MAP[y][x]=map_tile
            mset(x, y, tile)
        end
    end
end

-- init

function init()
    generateMap()
    PLAYER.pos.x=(W*T)//2
    PLAYER.pos.y=H//2
    PLAYER.money=500
    PLAYER.fuel_tank=FUEL_TANKS[1]
    PLAYER.fuel=FUEL_TANKS[1].value
    PLAYER.container=CONTAINERS[1]
    PLAYER.container_items={}
    PLAYER.burr=BURRS[1]
    PLAYER.engine=ENGINES[1]
    PLAYER.radar=RADARS[1]
    MODE=MOD_GAME
    OLD_MODE=nil
end

function initGame()
    PLAYER.pos.x=(W*T)//2
    PLAYER.pos.y=H//2
end

function TICGame()
    cls(15)
    updateCam(CAM, PLAYER)
    draw(CAM, PLAYER)
    -- local x,y=mouse()
    -- local mx,my = (CAM.x + x)//T,(CAM.y + y)//T
    -- rectb(mx*T,my*T,T,T,1)
    -- local tile=MAP[my][mx]
    -- print(sf("%s %s", tile.block.name, tile.dug), mx*T+T, my*T+T, 12)
    if btn(BTN_X) then PLAYER.rot = PLAYER.rot - 0.02 end
    if btn(BTN_Z) then PLAYER.rot = PLAYER.rot + 0.02 end
    if keyp(KEY_S) then
        sell_resources(PLAYER)
    end
    if keyp(KEY_F) then
        refuel(PLAYER)
    end
    burr(PLAYER)
    move_player(PLAYER)
    -- animation
    -- gameTicks=gameTicks+1
    check_shop(SHOP, PLAYER)
end

function text_width(text, small)
    return print(text,W,H,15,false,1,small)
end

function on_upgrade_hover(btn)
    if btn.item ~= nil and btn.active_callback ~= nil and btn.active_callback(btn.item) then
        g_hover(btn)
        local mx,my = mouse()
        local dx,dy = 5, 5
        local value = sf(btn.format, btn.item.value)
        local text=sf("%s\n%s: %s\n$%d", btn.item.name, btn.target_spec, value, btn.item.price)
        local width = text_width(text,true)
        text=sf("%s\n%s: %s\n", btn.item.name, btn.target_spec, value)
        local x,y,w,h=math.min(W-width, mx + dx), my+dy, width+6, 24
        rect(x-4,y-4,w,h,8)
        rectb(x-3,y-3,w,h,2)
        printframe(text,x,y,15,0,true)
        -- price
        text=sf("$%d", btn.item.price)
        local w1=text_width(text,true)
        printframe(text, x+width-w1, y+13,6,0,true)
    end
end

function on_upgrade_click(btn)
    if btn.item ~= nil and btn.upgrade_callback ~= nil then
        g_press(btn)
        btn.upgrade_callback(btn.item)
    end
end

-- function make_button( x, y, w, h, color, item, text, on_hover, on_leave, on_press, on_release, on_enter, sp, offx, offy, on_draw )
function make_upgrade_button(x, y, upgrade, target_item, target_spec, format, upgrade_callback, active_callback)
    local btn = make_button(x, y, 16, 16, 1, upgrade, nil, on_upgrade_hover, g_leave, g_press, on_upgrade_click, nil, nil, 2, 2)
    btn.target_item = target_item
    btn.target_spec = target_spec
    btn.format = format
    btn.upgrade_callback = upgrade_callback
    btn.active_callback = active_callback
    return btn
end

SHOP_BUTTONS={}

function can_buy(pl, item, to_replace, items_container)
    if pl.money >= item.price then
        if item ~= pl[to_replace] then
            if table.index(items_container, item) > table.index(items_container, pl[to_replace]) then
                return true
            -- else
                -- trace("can't downgrade")
            end
        -- else
            -- trace("can't buy same item")
        end
    -- else
        -- trace("not enough money")
    end
    return false
end

function buy_item(pl, item, to_replace, items_container)
    if can_buy(pl, item, to_replace, items_container) then
        trace("here")
        pl.money = pl.money - item.price
        pl[to_replace] = item
    end
end

function initShopButtons(pl)
    SHOP_BUTTONS={}
    local startX, startY = 10, 8
    trace(#ENGINES)
    for i,v in ipairs(ENGINES) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY, v, pl.engine, "Power", "%.1fx", function(item)
            buy_item(pl, item, "engine", ENGINES)
        end, function(item)
            return can_buy(pl, item, "engine", ENGINES)
        end)
        table.insert(SHOP_BUTTONS, btn)
    end
    for i,v in ipairs(BURRS) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY + 24, v, pl.burr, "Recovery", "x%.1f", function(item)
            buy_item(pl, item, "burr", BURRS)
        end, function(item)
            return can_buy(pl, item, "burr", BURRS)
        end)
        table.insert(SHOP_BUTTONS, btn)
    end
    for i,v in ipairs(FUEL_TANKS) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY + 48, v, pl.fuel_tank, "Volume", "%d", function(item)
            buy_item(pl, item, "fuel_tank", FUEL_TANKS)
        end, function(item)
            return can_buy(pl, item, "fuel_tank", FUEL_TANKS)
        end)
        table.insert(SHOP_BUTTONS, btn)
    end
    for i,v in ipairs(CONTAINERS) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY + 72, v, pl.container, "Volume", "%d", function(item)
            buy_item(pl, item, "container", CONTAINERS)
        end, function(item)
            return can_buy(pl, item, "container", CONTAINERS)
        end)
        table.insert(SHOP_BUTTONS, btn)
    end
    for i,v in ipairs(RADARS) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY + 96, v, pl.radar, "Distance", "%d m", function(item)
            buy_item(pl, item, "radar", RADARS)
        end, function(item)
            return can_buy(pl, item, "radar", RADARS)
        end)
        table.insert(SHOP_BUTTONS, btn)
    end
end

function update_buttons(btns)
    local mx,my,md = mouse()
    for i,v in ipairs(btns) do
        draw_button(v)
    end
    for i,v in ipairs(btns) do
        check_button(v, mx, my, md)
    end
end

function initShop()
    initShopButtons(PLAYER)
end

function TICShop()
    cls()
    str = "Welcome to shop!"
    w = print(str, W, H)
    print(str, W//2 - w // 2, H // 2, 12)
    drawHud(PLAYER)
    update_buttons(SHOP_BUTTONS)
    if keyp(KEY_Q) then MODE=MOD_GAME end
end

MOD_GAME = 1
MOD_SHOP = 2

-- should be below function declarations

TIC_MODE={
    [MOD_GAME]=TICGame,
    [MOD_SHOP]=TICShop,
}

INITS={
    [MOD_SHOP]=initShop,
    [MOD_GAME]=initGame
}

init()
function TIC()
    if OLD_MODE ~= MODE then
        if INITS[MODE] ~= nil then
            INITS[MODE]()
        end
        OLD_MODE=MODE
    end
    TIC_MODE[MODE]()
end
