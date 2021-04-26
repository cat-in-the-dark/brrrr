-- title:  Remap demo
-- author: AnastasiaDunbar, Lua translation by StinkerB06

DEBUG=false

W=240
H=136
T=8
INNER_R=4
OUTER_R=INNER_R * math.sqrt(2)

MAP_W=240
MAP_H=136

PALETTE_ADDR=0x03FC0

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

ALREADY_EQUIPPED="Already equipped"
NOT_ENOUGH="Not enough money"

CHANGING_COLORS={1,2,3,8,15}

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

function splittokens(s)
    local res = {}
    for w in s:gmatch("%S+") do
        res[#res+1] = w
    end
    return res
end

function textwrap(text, linewidth)
    if not linewidth then
        linewidth = 75
    end

    local spaceleft = linewidth
    local res = {}
    local line = {}

    for _, word in ipairs(splittokens(text)) do
        if #word + 1 > spaceleft then
            table.insert(res, table.concat(line, ' '))
            line = {word}
            spaceleft = linewidth - #word
        else
            table.insert(line, word)
            spaceleft = spaceleft - (#word + 1)
        end
    end

    table.insert(res, table.concat(line, ' '))
    return table.concat(res, "\n")
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

function pairsByKeys (t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
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
end

function g_release( btn )
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

function draw_button( btn )
    if btn.on_draw ~= nil then
        btn.on_draw(btn)
        return
    end

    rect(btn.x, btn.y, btn.w, btn.h, btn.color)
    rectb(btn.x, btn.y, btn.w, btn.h, 2)
    local dx,dy=0,0
    if btn.pressed then
        rectb(btn.x + 1, btn.y + 1, btn.w - 1, btn.h - 1, 2)
        dx,dy=1,1
    else
        rectb(btn.x, btn.y, btn.w - 1, btn.h - 1, 2)
    end

    if btn.text ~= nil then
        local tw,th = print(btn.text, W,H),8
        printframe(btn.text, btn.x + btn.w/2 - tw/2 + dx, btn.y + btn.h/2 - th/2 + dy, 6)
        return
    end

    if btn.item ~= nil then
        local item,x,y,w,h = btn.item,btn.x,btn.y,btn.w,btn.h
        local ent = {pos={x=x, y=y}, sp=item.sp, offx=btn.offx, offy=btn.offy}
        draw_ent(ent)
    end
end

-- minerals

DIRT        = 1
GRANITE     = 17
COAL        = 33
EMERALD     = 49
OBSIDIAN    = 65
BASALT      = 81
HEMATITE    = 97

RESOURCES={
    {
        name="iron",
        parent=HEMATITE,
        value=20,
        mass=12,
        cluster_len=50,
        clusters=100
    },
    {
        name="coal",
        parent=COAL,
        value=10,
        mass=10,
        cluster_len=60,
        clusters=100
    },
    {
        name="emerald",
        parent=EMERALD,
        value=100,
        mass=1,
        cluster_len=20,
        clusters=30
    }
}

BLOCKS={
    [DIRT]={
        name="dirt",
        hardness=10
    },
    [GRANITE]={
        name="granite",
        hardness=20
    },
    [COAL]={
        name="coal",
        hardness=10,
        resource=RESOURCES[2],
        prob=0.7
    },
    [EMERALD]={
        name="emerald",
        hardness=40,
        resource=RESOURCES[3],
        prob=0.2
    },
    [OBSIDIAN]={
        name="obsidian",
        hardness=-1
    },
    [BASALT]={
        name="basalt",
        hardness=25
    },
    [HEMATITE]={
        name="hematite",
        hardness=15,
        resource=RESOURCES[1],
        prob=0.5
    }
}

def_tile={
    block=BLOCKS[1],
    wear=1.0,
    seen=false,
    debug=false,
    dug=false
}

MAP={}

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

function getMap(x, y)
    return MAP[y % H][x % W]
end

function burr(pl)
    local res = rot_poly(pl.burr_poly, pl.center.x, pl.center.y, pl.rot)
    res = move_poly(res, pl.pos)
    collide_tile_poly(res, function(x, y)
        if not getMap(x,y).dug then
            if pl.fuel <= 0 then
                -- trace("no fuel!")
                return
            end

            if cargo_mass(pl) > pl.container.value then
                -- trace("Overload!")
                return
            end

            -- dig tile
            local tile = mget(x, y)

            -- special edge tiles
            if BLOCKS[tile].hardness == -1 then
                return
            end

            MAP[y][x].wear = MAP[y][x].wear - pl.engine.value / BLOCKS[tile].hardness

            -- drain fuel
            pl.fuel = pl.fuel - pl.engine.value / 10
            if pl.fuel < 0 then pl.fuel = 0 end

            if MAP[y][x].wear <= 0 then
                MAP[y][x].dug = true
                local blk = MAP[y][x].block
                local res = blk.resource
                if res ~= nil then
                    if math.random() < blk.prob * pl.burr.value then
                        table.insert( pl.container_items, deepcopy(res) )  -- fix mass and value changes in container when move between levels
                    end
                end
            end
        end
    end)
end

function refuel(pl)
    local cap = pl.fuel_tank.value - pl.fuel
    -- trace(cap)
    local cost = min(cap * FUEL_PRICE, pl.money)
    -- trace(cost)
    local amount = cost / FUEL_PRICE
    -- trace(amount)
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

fall_speed = 0
function world_bounds(pl)
    -- map bounds
    if pl.pos.y + pl.pos.h < GROUND_HEIGT or pl.pos.y >= (H-1) * T - pl.cc.r * 2 then
        pl.pos.y = pl.pos.y + fall_speed
        fall_speed = fall_speed + 0.07
    else
        fall_speed = 0
    end
    if pl.pos.y > H * T then  -- fall back on land
        pl.pos.y = 0
        MODE=MOD_NEXT_MAP
    end
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
            if not getMap(x,y).dug then
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
    local tw = text_width(str)
    local bg_clr=6
    rect(0, 0, tw+6,12,bg_clr)
    tri(tw+6,11, tw+6,0, tw+17,0, bg_clr)
    printframe(str, 3, 3, 12)
end

function drawSky(cam)
    local sky_height = GROUND_HEIGT - cam.y
    if sky_height <= 0 then return end
    rect(0, 0, W, sky_height, 10)
end

GROUND_HEIGT_T  = 12
GROUND_HEIGT    = GROUND_HEIGT_T * T

SHOP={
    pos=v2((W*T)//2-80,GROUND_HEIGT-32),
    sp=make_tex(336,6,4),
    cr={x=0,y=6,w=48,h=26}
}

function drawShop(cam)
    draw_ent(SHOP,cam)
end

SEEN=-1
function drawSign(cam)
    if SEEN ~= LVL then
        local str=""
        if LVL==0 then
            str = "Move: arrow keys\n - Dig & sell resources\n - Upgrade your drill\nDrill the worlds beneath!"
        else
            local unders={}
            for i=1,LVL do
                table.insert(unders, "under")
            end
            local cnc = table.concat(unders, " ")
            str = textwrap(sf("Welcome to the %sworld!", cnc), 40)
        end
        local w=text_width(str)
        local x,y = W*T//2-w//2-cam.x, 28-cam.y
        printframe(str,x,y,12)
        if y < -50 then SEEN=LVL end
    end
end

function draw(cam, pl)
    drawSky(cam)
    drawSign(cam)
    drawShop(cam)
    drawMap(cam)
    for i,v in ipairs(ENTITIES) do
        draw_ent(v,cam)
    end
    drawHud(pl)
    draw_cargo_bar(pl, false)
    draw_fuel_bar(pl)
    if pl.fuel <= 0 then
        local str = "NO FUEL!"
        local w = text_width(str, false)
        printframe(str, W//2-w//2, H//2-5, 2)
    end
    if cargo_mass(pl) > pl.container.value then
        local str = "OVERLOADED!"
        local w = text_width(str, false)
        printframe(str, W//2-w//2, H//2+5, 2)
    end
end

-- balance

FUEL_PRICE=1.0

HARDNESS_INCREMENT=1.2
MASS_INCREMENT=1.2
RESOURCE_VAL_INCREMENT=1.15
VALUE_INCREMENT=1.25
PRICE_INCREMENT=1.2

FT_GEN={
    names = {"Basic", "Big", "XLarge", "Ginormous", "SSET", "Baikal", "9^9*XL"},
    increment=500,
    round=50,
    idx=4
}

FUEL_TANKS={
    [1]={value=300, name=FT_GEN.names[1], price=0},
    [2]={value=500, name=FT_GEN.names[2] , price=400},
    [3]={value=700, name=FT_GEN.names[3], price=800}
}

BR_GEN={
    names = {"Basic", "Fine", "Neat", "Accurate", "Precise", "Gentle", "Jewelry drill"},
    increment=600,
    round_f=1,
    idx=4
}
BR_INCREMENT=600

BURRS={
    [1]={value=1.0, name=BR_GEN.names[1], price=0},
    [2]={value=1.1, name=BR_GEN.names[2], price=500},
    [3]={value=1.2, name=BR_GEN.names[3], price=1000}
}

CNT_GEN={
    names = {"Basic", "Large", "XL", "Giant", "Belaz", "Cyclopean", "Portable black hole"},
    increment=500,
    round=50,
    idx=4
}

CONTAINERS={
    [1]={value=300, name=CNT_GEN.names[1], price=0},
    [2]={value=500, name=CNT_GEN.names[2], price=400},
    [3]={value=700, name=CNT_GEN.names[3], price=800}
}

ENGINE_GEN={
    names={"Ant", "Termite", "Mole", "Digger", "Naked mole rat", "JackHammer", "EarthScrewer"},
    increment=1000,
    round_f=1,
    idx=4
}

ENGINES={
    [1]={value=1.0, name=ENGINE_GEN.names[1], price=0},
    [2]={value=1.2, name=ENGINE_GEN.names[2], price=1000},
    [3]={value=1.5, name=ENGINE_GEN.names[3], price=2000}
}

RDR_GEN={
    names = {"Blind", "Viy", "Beagle", "Advanced", "Tracker", "X-RAY Penetrator", "God's eye"},
    increment=1000,
    round=4,
    linear=true,
    inc=4,
    idx=4
}

RADARS={
    [1]={value=24, name=RDR_GEN.names[1], price=0},
    [2]={value=28, name=RDR_GEN.names[2], price=800},
    [3]={value=32, name=RDR_GEN.names[3], price=1600}
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
    cam.y=e.pos.y-H//2
end

-- map

function drawMap( cam )
    local frames=6
    local speed=0.1
    local cx,cy = cam.x // T, cam.y // T
    local offx, offy = cx * T - cam.x, cy * T - cam.y
    map(cx,cy,31,18,offx,offy,0,1,function(tile,x,y)
        local outTile,flip,rotate=tile,0,0
        if MAP[y][x].dug then
            outTile = 0
        elseif MAP[y][x].block.resource ~= nil then
        	outTile=outTile+math.floor(gameTicks*speed)%frames
        end
        return outTile,flip,rotate --or simply `return outTile`.
    end)

    map(cx,cy,32,19,offx-2,offy-2,8,1,function(tile,x,y)
        local outTile,flip,rotate=tile,0,0
        if MAP[y][x].seen then
            outTile = 16 -- transparent
        else
            outTile = 0 -- black
        end
        return outTile
    end)
end

WALL_LEFT_T     = 4
WALL_LEFT       = WALL_LEFT_T * T
WALL_RIGHT_T    = W - 4
WALL_RIGHT      = WALL_RIGHT_T * T

DEBUG_SPAWN_X = W//2
DEBUG_SPAWN_Y = H-8
DEBUG_SPAWN_W = 8
DEBUG_SPAWN_H = 6

HEIGHT_SOFT=20
HEIGHT_MIDSOFT=50
HEIGHT_MID=70
HEIGHT_HARDMID=100

function map_to_one( a, b, n )
    local dif,minN = abs(a-b), min(a,b)
    return (n - minN) / dif
end

function rnd_or(a, b, skew)
    skew = skew or 0.5
    local val=rnd()
    if val < skew then
        return a
    else
        return b
    end
end

function generateTile(x, y)
    local tile = DIRT
    if y > GROUND_HEIGT_T then
        if y < HEIGHT_SOFT then
            tile = DIRT
        elseif y < HEIGHT_MIDSOFT then
            tile = rnd_or(GRANITE,DIRT, map_to_one(HEIGHT_SOFT, HEIGHT_MIDSOFT, y))
        elseif y < HEIGHT_MID then
            tile=GRANITE
        elseif y < HEIGHT_HARDMID then
            tile = rnd_or(BASALT, GRANITE, map_to_one(HEIGHT_MID, HEIGHT_HARDMID, y))
        else
            tile=BASALT
        end
    end
    if x < WALL_LEFT_T or x > WALL_RIGHT_T then
        tile=OBSIDIAN
    end
    return tile
end

function generateMap(startY,endY)
    startY = startY or 0
    endY = endY or MAP_H-1
    for y=startY,endY do
        MAP[y] = {}
        for x=0,MAP_W-1 do
            local tile=generateTile(x, y)

            local map_tile=deepcopy(def_tile)
            map_tile.block=BLOCKS[tile]

            if DEBUG then
                if x >= DEBUG_SPAWN_X and x <= DEBUG_SPAWN_X + DEBUG_SPAWN_W and y >= DEBUG_SPAWN_Y and y <= DEBUG_SPAWN_Y + DEBUG_SPAWN_H then
                    map_tile.seen=true
                    map_tile.dug=true
                end
            end

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

function putCluster(tile, size, x, y)
    x = x or rnd(WALL_LEFT_T, WALL_RIGHT_T-1)
    y = y or rnd(GROUND_HEIGT_T, MAP_H-1)
    for i=1,size do
        if MAP[y] ~= nil and MAP[y][x] ~= nil and not MAP[y][x].dug and MAP[y][x].block ~= BLOCKS[OBSIDIAN] then
            local map_tile=deepcopy(def_tile)
            map_tile.block=BLOCKS[tile]
            map_tile.seen=MAP[y][x].seen
            MAP[y][x]=map_tile
            mset(x, y, tile)
            local x_inc,y_inc = rnd(-1,1), rnd(-1,1)
            x,y = x+x_inc, y+y_inc
        end
    end
end

-- init

function init()
    gameTicks=0
    local sky_clr=10
    ORIG_CLR={}
    ORIG_CLR[0]=peek(PALETTE_ADDR+(3*sky_clr))
    ORIG_CLR[1]=peek(PALETTE_ADDR+(3*sky_clr)+1)
    ORIG_CLR[2]=peek(PALETTE_ADDR+(3*sky_clr)+2)

    ORIG_COLORS={}
    for i,v in ipairs(CHANGING_COLORS) do
        ORIG_COLORS[v] = {
            peek(PALETTE_ADDR+(3*v)),
            peek(PALETTE_ADDR+(3*v)+1),
            peek(PALETTE_ADDR+(3*v)+2)
        }
    end

    generateMap()
    for i,res in ipairs(RESOURCES) do
        for j=1,res.clusters do
            putCluster(res.parent, res.cluster_len)
        end
    end

    putCluster(COAL, 20, W//2, GROUND_HEIGT_T+3)
    if DEBUG then
        PLAYER.pos.x=DEBUG_SPAWN_X*T
        PLAYER.pos.y=DEBUG_SPAWN_Y*T
    else
        PLAYER.pos.x=(W*T)//2
        PLAYER.pos.y=H//2
    end
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
    PREV_MODE=nil
    if DEBUG then
        PLAYER.engine=ENGINES[3]
    --     PLAYER.burr=BURRS[2]
        PLAYER.fuel=10000
    --     PLAYER.money=10000
    end
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
    -- if btn(BTN_X) then PLAYER.rot = PLAYER.rot - 0.02 end
    -- if btn(BTN_Z) then PLAYER.rot = PLAYER.rot + 0.02 end
    if DEBUG then
        if keyp(KEY_S) then
            sell_resources(PLAYER)
        end
        if keyp(KEY_F) then
            refuel(PLAYER)
        end
    end
    burr(PLAYER)
    move_player(PLAYER)
    world_bounds(PLAYER)
    -- animation
    gameTicks=gameTicks+1
    check_shop(SHOP, PLAYER)
end

function SCNGame(line)
    local sky_clr=10
    local off=LVL % 3
    local sky_height = GROUND_HEIGT - CAM.y
    if line < sky_height then
        local color=(0xff*line/H)
        poke(PALETTE_ADDR+(3*sky_clr)+off, color)
    else
        poke(PALETTE_ADDR+(3*sky_clr)+off, ORIG_CLR[off])
    end
end

function text_width(text, small)
    return print(text,W,H,15,false,1,small)
end

function on_upgrade_hover(btn)
    local res, msg = can_buy(btn.pl, btn.item, btn.target_item, btn.container)
    if res then btn.color = 5 else btn.color = 14 end
    local mx,my = mouse()
    local dx,dy = 5, 5
    local value = sf(btn.format, btn.item.value)
    local text=sf("%s\n%s: %s\n%s", btn.item.name, btn.target_spec, value, msg)
    local width = text_width(text,true)
    text=sf("%s\n%s: %s\n", btn.item.name, btn.target_spec, value)
    local x,y,w,h=math.min(W-width, mx + dx), my+dy, width+6, 24
    rect(x-4,y-4,w,h,8)
    rectb(x-3,y-3,w,h,2)
    printframe(text,x,y,11,0,true)
    -- price
    text=msg
    if msg == NOT_ENOUGH then
        text = sf("$%.0f", btn.item.price)
    end
    local w1=text_width(text,true)
    local text_clr = 6
    if not res then text_clr = 3 end
    printframe(text, x+width-w1, y+13,text_clr,0,true)
end

function on_upgrade_click(btn)
    g_press(btn)
    local res, msg = can_buy(btn.pl, btn.item, btn.target_item, btn.container)
    if res then
        buy_item(btn.pl, btn.item, btn.target_item, btn.container)
        initUiButtons(btn.pl)
        initShopButtons(btn.pl)
    end
end

function make_upgrade_button(x, y, upgrade, pl, target_item, target_spec, format, container)
    local res,_ = can_buy(pl, upgrade, target_item, container)
    local color = 15
    if res then color=6 end
    local btn = make_button(x, y, 16, 16, color, upgrade, nil, on_upgrade_hover, g_leave, g_press, on_upgrade_click, nil, nil, 2, 2)
    btn.pl = pl
    btn.target_item = target_item
    btn.target_spec = target_spec
    btn.format = format
    btn.container = container
    return btn
end

SHOP_BUTTONS={}
UI_BUTTONS={}

function can_buy(pl, item, to_replace, items_container)
    if item ~= pl[to_replace] then
        if table.index(items_container, item) > table.index(items_container, pl[to_replace]) then
            if pl.money >= item.price then
                return true, sf("$%.0f", item.price)
            else
                return false, NOT_ENOUGH
            end
        else
            return false, "Better equipped"
        end
    else
        return false, ALREADY_EQUIPPED
    end
    return false
end

function buy_item(pl, item, to_replace, items_container)
    if can_buy(pl, item, to_replace, items_container) then
        -- trace("here")
        pl.money = pl.money - item.price
        pl[to_replace] = item
    end
end

-- function make_upgrade_button(x, y, upgrade, pl, target_item, target_spec, format, container)
function initShopButtons(pl)
    SHOP_BUTTONS={}
    local startX, startY = 64, 16
    for i,v in ipairs(ENGINES) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY, v, pl, "engine", "Power", "%.1fx", ENGINES)
        table.insert(SHOP_BUTTONS, btn)
    end
    for i,v in ipairs(BURRS) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY + 20, v, pl, "burr", "Recovery", "x%.1f", BURRS)
        table.insert(SHOP_BUTTONS, btn)
    end
    for i,v in ipairs(FUEL_TANKS) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY + 40, v, pl, "fuel_tank", "Volume", "%d", FUEL_TANKS)
        table.insert(SHOP_BUTTONS, btn)
    end
    for i,v in ipairs(CONTAINERS) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY + 60, v, pl, "container", "Volume", "%d", CONTAINERS)
        table.insert(SHOP_BUTTONS, btn)
    end
    for i,v in ipairs(RADARS) do
        local offX = (i-1) * 24
        local btn = make_upgrade_button(startX + offX, startY + 80, v, pl, "radar", "Distance", "%d m", RADARS)
        table.insert(SHOP_BUTTONS, btn)
    end
end

function on_quit_press(btn)
    MODE=PREV_MODE
end

function on_sell_press(btn)
    sell_resources(PLAYER)
    initShopButtons(PLAYER)
    initUiButtons(PLAYER)
end

function on_buy_press(btn)
    refuel(PLAYER)
    initShopButtons(PLAYER)
    initUiButtons(PLAYER)
end

-- make_button( x, y, w, h, color, item, text, on_hover, on_leave, on_press, on_release, on_enter, sp, offx, offy, on_draw )
function initUiButtons(pl)
    UI_BUTTONS={}
    local quit = make_button(W-32, H-12, 32, 12, 3, nil, "Quit", g_hover, g_leave, on_quit_press)
    table.insert( UI_BUTTONS,quit )
    if cargo_mass(pl) > 0 then
        local sell_cargo = make_button(172, 0, 32, 12, 3, nil, "Sell", g_hover, g_leave, on_sell_press)
        table.insert( UI_BUTTONS,sell_cargo )
    end
    if pl.fuel < pl.fuel_tank.value then
        local buy_fuel = make_button(160, H-12, 32, 12, 3, nil, "Buy", g_hover, g_leave, on_buy_press)
        table.insert( UI_BUTTONS,buy_fuel )
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
    initUiButtons(PLAYER)
end

function draw_fuel_bar(pl)
    local total = pl.fuel_tank.value
    local fy=110
    local x,y,w,h = 15, 125, 150, 10
    local offX,offY=2,1
    local bg_clr=10
    local str="Fuel"
    local tw = text_width(str)
    rect(0,fy,tw,H-fy,bg_clr)
    tri(tw, fy, tw, H, tw+H-fy, H, bg_clr)
    rect(0,y-offY*2,w+offX*2,H-y+offY*2,bg_clr)
    rect(offX,y, pl.fuel * w / total, h, 2)
    rectb(offX,y,w,h,0)
    printframe(str, offX, fy+4, 12)
end

DCB_STATE=0
function draw_cargo_bar(pl, print_legend)
    local w,h = 10, 100
    local offX,offY=1,20
    local x,y = W-w-offX, offY

    local bg_clr=13
    local str="Cargo"
    local tw=text_width(str)
    rect(W-tw-offX*3, 0, tw+offX*3, 12, bg_clr)
    rect(x-offX, 0, W-(x-offX), h+offY+2, bg_clr)

    local total,current = pl.container.value, cargo_mass(pl)
    if current > total then total = current end  -- consider overload

    local tx_color = 12
    if not print_legend then
        if current >= total then
            DCB_STATE = DCB_STATE + 1
            if DCB_STATE < 20 then
                tx_color=12
            else
                tx_color=2
                if DCB_STATE >= 40 then
                    DCB_STATE = 0
                end
            end
        end
    end

    printframe(str,W-tw-offX,2,tx_color)

    local by_name = {}
    local colors={2,4,6,9}
    local c_idx=1
    for i,item in ipairs(pl.container_items) do
        if by_name[item.name] == nil then
            by_name[item.name] = {mass=item.mass, value=item.value, tile=item.parent, color=colors[c_idx]}
            c_idx = (c_idx + 1) % #colors
            if c_idx == 0 then c_idx = #colors end
        else
            by_name[item.name].mass = by_name[item.name].mass + item.mass
            by_name[item.name].value = by_name[item.name].value + item.value
        end
    end

    local drawY = y+h
    for k,v in pairs(by_name) do
        local barH = v.mass * h / total
        rect(x, drawY-barH, w, barH+1, v.color)

        if print_legend then
            local textH = barH/2+12/2
            local str=sf("%s -\n$%.0f", k, v.value)
            local tw = text_width(str,true)
            printframe(str, x-tw, drawY-textH, v.color, 0, true)
            spr(v.tile, x-tw-T-2, drawY-textH)
        end

        drawY=drawY-barH
    end

    rectb(x,y,w,h,0)
end

function TICShop()
    cls()
    print("Upgrades", 72, 2, 12)
    drawHud(PLAYER)
    local startX,startY=5,20
    print("ENGINE", startX, startY, 12)
    print("DRILL", startX, startY+20, 12)
    print("FUEL TANK", startX, startY+40, 12)
    print("CARGO BAY", startX, startY+60, 12)
    print("RADAR", startX, startY+80, 12)

    draw_cargo_bar(PLAYER, true)
    draw_fuel_bar(PLAYER)

    update_buttons(UI_BUTTONS)
    update_buttons(SHOP_BUTTONS)
    -- if keyp(KEY_Q) then MODE=MOD_GAME end
end

function finishShop()
    PLAYER.pos.x=(W*T)//2
    PLAYER.pos.y=H//2
end

function generateUpgrade(last, generator)
    local new_val = deepcopy(last)
    local fix_idx = generator.idx % #generator.names
    if fix_idx == 0 then
        fix_idx = #generator.names
    end

    local new_name = generator.names[fix_idx]
    local lvl = (generator.idx - 1) // #generator.names
    if lvl > 0 then
        new_name = sf("%s V%d", new_name, lvl+1)
    end
    generator.idx = generator.idx + 1
    new_val.name=new_name

    local new_price = last.price + generator.increment
    generator.increment = generator.increment * PRICE_INCREMENT
    new_val.price = new_price

    local new_value = last.value * VALUE_INCREMENT
    if last.linear then new_value = last.value + last.inc end
    if generator.round ~= nil then
        new_value = (new_value // generator.round) * generator.round
    elseif generator.round_f ~= nil then
        new_value = math.floor(math.pow(10,generator.round_f) * new_value) / math.pow(10,generator.round_f)
    end
    new_val.value=new_value
    return new_val
end

function shiftUpgrade(field, container, generator)
    local idx = table.index(container, PLAYER[field])
    local slots = #container
    local to_shift = idx-1
    if to_shift == 0 then return end

    if DEBUG then
        trace(sf("shift %s to %d", field, to_shift))
    end

    local start=1
    for i=idx,slots do
        container[start] = container[i]
        start=start+1
    end

    for i=start,slots do
        local old_name = container[i].name
        container[i] = generateUpgrade(container[i-1], generator)
    end

    PLAYER[field] = container[1]
end

-- name="dirt",
-- hardness=10,
-- resource=nil
function upgradeBlocks()
    for i,block in ipairs(BLOCKS) do
        if block.hardness ~= -1 then  -- obsidian
            local new_hardness = ((block.hardness * HARDNESS_INCREMENT // 5)) * 5
            if new_hardness == block.hardness then new_hardness = new_hardness + 1 end
            if DEBUG then trace(sf("new hardness %d: %d", i, new_hardness)) end
            block.hardness=new_hardness
            if block.resource ~= nil then
                local new_val = ((block.resource.value * RESOURCE_VAL_INCREMENT) // 5) * 5
                if new_val == block.resource.value then new_val = new_val + 1 end
                if DEBUG then trace(sf("new price: %d", new_val)) end
                block.resource.value = new_val
                local new_mass = math.floor(block.resource.mass * MASS_INCREMENT)
                if new_mass == block.resource.mass then new_mass = new_mass + 1 end
                if DEBUG then trace(sf("new mass[1] = %d", new_mass)) end
                block.resource.mass = new_mass
            end
        end
    end
end

function remapTextures()
    local amp=45
    local rdiff,gdiff,bdiff=rnd(-amp,amp),rnd(-amp,amp),rnd(-amp,amp)
    for i,clr in ipairs(CHANGING_COLORS) do
        local r = ORIG_COLORS[clr][1]
        local g = ORIG_COLORS[clr][2]
        local b = ORIG_COLORS[clr][3]
        r = (r + rdiff + 0xFF) % 0xFF
        g = (g + gdiff + 0xFF) % 0xFF
        b = (b + bdiff + 0xFF) % 0xFF
        poke(PALETTE_ADDR+(3*clr), r)
        poke(PALETTE_ADDR+(3*clr)+1, g)
        poke(PALETTE_ADDR+(3*clr)+2, b)
    end
end

LVL=0
function initNextMap()
    MAP_GEN_Y=0
    CLUSTER_GEN=0
    RES_GEN=1
    LVL=LVL+1

    remapTextures()

    shiftUpgrade("burr", BURRS, BR_GEN)
    shiftUpgrade("container", CONTAINERS, CNT_GEN)
    shiftUpgrade("engine", ENGINES, ENGINE_GEN)
    shiftUpgrade("fuel_tank", FUEL_TANKS, FT_GEN)
    shiftUpgrade("radar", RADARS, RDR_GEN)
    upgradeBlocks()
end

function TICNextMap()
    local increment = 5
    local cluster_increment=20
    if MAP_GEN_Y > H-1 then
        if RES_GEN > #RESOURCES then
            MODE=MOD_GAME
            return
        end

        local res = RESOURCES[RES_GEN]
        cluster_increment = min(cluster_increment, res.clusters - CLUSTER_GEN)
        for i=1,cluster_increment do
            putCluster(res.parent, res.cluster_len)
        end

        CLUSTER_GEN=CLUSTER_GEN + cluster_increment
        if CLUSTER_GEN >= res.clusters then
            CLUSTER_GEN=0
            RES_GEN = RES_GEN + 1
        end        
    else
        generateMap(MAP_GEN_Y, min(H-1, MAP_GEN_Y + increment))
        MAP_GEN_Y = MAP_GEN_Y + increment
    end

    TICGame()
end

MOD_GAME = 1
MOD_SHOP = 2
MOD_NEXT_MAP=3

-- should be below function declarations

TIC_MODE={
    [MOD_GAME]=TICGame,
    [MOD_SHOP]=TICShop,
    [MOD_NEXT_MAP]=TICNextMap
}

INITS={
    [MOD_SHOP]=initShop,
    [MOD_NEXT_MAP]=initNextMap
}

FINISHES={
    [MOD_SHOP]=finishShop
}

SCNS={
    [MOD_GAME]=SCNGame,
    [MOD_NEXT_MAP]=SCNGame
}

init()
function TIC()
    if OLD_MODE ~= MODE then
        if FINISHES[OLD_MODE] ~= nil then
            FINISHES[OLD_MODE]()
        end

        if INITS[MODE] ~= nil then
            INITS[MODE]()
        end

        if DEBUG then
            if OLD_MODE == nil then
                trace(sf("[nil] -> %d", MODE))
            else
                trace(sf("%d -> %d", OLD_MODE, MODE))
            end
        end
        PREV_MODE=OLD_MODE
        OLD_MODE=MODE
    end
    TIC_MODE[MODE]()
end

function SCN(line)
    if SCNS[MODE] ~= nil then
        SCNS[MODE](line)
    end
end
