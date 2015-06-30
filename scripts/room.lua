------------------------------------------------------------------------
--  ROOM MANAGEMENT
------------------------------------------------------------------------
--
--  Oblige Level Maker
--
--  Copyright (C) 2006-2015 Andrew Apted
--
--  This program is free software; you can redistribute it and/or
--  modify it under the terms of the GNU General Public License
--  as published by the Free Software Foundation; either version 2
--  of the License, or (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
------------------------------------------------------------------------

--class ROOM
--[[
    kind : keyword  -- "building" (layout-able room)
                    -- "outdoor", "cave"
                    -- "hallway", "stairwell"
                    -- "scenic" (unvisitable room)

    is_outdoor : bool  -- true for outdoor rooms / caves


    areas = list(AREA)

    seeds = list(SEED)

    sx1, sy1, sx2, sy2  -- \ Seed range
    sw, sh, svolume     -- /


    ext_conns = list(CONNS)   -- connections which go "external" to another room

    quest : QUEST

    zone : ZONE


    hallway : HALLWAY_INFO   -- for hallways only

    symmetry : keyword   -- symmetry of room, or NIL
                         -- keywords are "x", "y", "xy"
--]]


--class HALLWAY_INFO
--[[
    height : number   -- space between floor and ceiling

--]]


--------------------------------------------------------------]]


ROOM_CLASS = {}

function ROOM_CLASS.new()
  local id = alloc_id("room")

  local R =
  {
    id = id
    kind = "UNSET"
    svolume = 0
    total_inner_points = 0
    num_windows = 0

    areas = {}
    seeds = {}

    sections = {}
    weapons = {}
    items = {}

    mon_spots  = {}
    item_spots = {}
    big_spots  = {}
    cage_spots = {}
    trap_spots = {}
    important_spots = {}   -- NOT USED ATM

    goals = {}
    importants = {}
    teleporters = {}

    closets = {}
    chunks  = {}    -- NOT USED
    floors  = {}    -- NOT USED
    decor   = {}

    sky_rects = {}
    exclusions = {}
    neighbors = {}  -- USED???

    hazard_health = 0
  }

  table.set_class(R, ROOM_CLASS)
  table.insert(LEVEL.rooms, R)
  return R
end


function ROOM_CLASS.kind_str(R)
  if R.kind == "DEAD" then return "DEAD_DEAD_DEAD" end
  if R.kind == "hallway" then return "HALLWAY" end
  if R.kind == "stairwell" then return "STAIRWELL" end
  if R.kind == "scenic" then return "SCENIC" end
  if R.parent then return "SUBROOM" end
  return "ROOM"
end


function ROOM_CLASS.tostr(R)
  return string.format("%s_%d", R:kind_str(), R.id)
end


function ROOM_CLASS.add_area(R, A)
  A.room = R

  table.insert(R.areas, A)

  R.svolume = R.svolume + A.svolume
  R.total_inner_points = R.total_inner_points + #A.inner_points
end


function ROOM_CLASS.kill_it(R)
  -- sanity check
  each C in LEVEL.conns do
    if (C.A1.room == R and C.A2.room != R) or
       (C.A2.room == R and C.A1.room != R)
    then
      error("Killed a connected room!")
    end
  end

  each A in R.areas do
    A.mode = "void"
    A.room = nil

    each S in A.seeds do
      S.room = nil

      each dir in geom.ALL_DIRS do
        if S.border[dir] then S.border[dir].kind = "nothing" end
      end
    end

    each C in A.conns do
      table.kill_elem(LEVEL.conns, C)
    end

    A.conns = nil
  end

  table.kill_elem(LEVEL.rooms, R)

  R.kind = "DEAD"
  R.hallway = nil

  R.sx1   = nil
  R.areas = nil
end


function ROOM_CLASS.contains_seed(R, x, y)
  if x < R.sx1 or x > R.sx2 then return false end
  if y < R.sy1 or y > R.sy2 then return false end
  return true
end


function ROOM_CLASS.get_bbox(R)
  local S1 = SEEDS[R.sx1][R.sy1]
  local S2 = SEEDS[R.sx2][R.sy2]

  return S1.x1, S1.y1, S2.x2, S2.y2
end


---## function ROOM_CLASS.has_lock(R, lock)
---##   each C in R.conns do
---##     if C.lock == lock then return true end
---##   end
---##   return false
---## end


function ROOM_CLASS.has_any_lock(R)
  each A in R.areas do
  each C in A.conns do
    if C.lock then return true end
  end
  end
  return false
end


---## function ROOM_CLASS.has_lock_kind(R, kind)
---##   each C in R.conns do
---##     if C.lock and C.lock.kind == kind then return true end
---##   end
---##   return false
---## end


function ROOM_CLASS.has_sky_neighbor(R)
  each A in R.areas do
  each C in A.conns do
    if C.A1.room == C.A2.room then continue end
    local N = C:neighbor(A)
    if N.is_outdoor and N.mode != "void" then return true end
  end
  end

  return false
end


function ROOM_CLASS.has_teleporter(R)
  each A in R.areas do
    each C in A.conns do
      if C.kind == "teleporter" then return true end
    end
  end

  return false
end


function ROOM_CLASS.collect_ext_conns(R)
  R.ext_conns = {}

  each A in R.areas do
    each C in A.conns do
      if C.A1.room != C.A2.room then
        table.insert(R.ext_conns, C)
      end
    end
  end
end


function ROOM_CLASS.total_conns(R, ignore_secrets)
  local count = 0

  each A in R.areas do
  each C in A.conns do
    if ignore_secrets and C.kind == "secret" then
      continue
    end

    if C.A1.room != C.A2.room then
      count = count + 1
    end
  end
  end

  return count
end


function ROOM_CLASS.is_unused_leaf(R)
  if R.kind == "hallway"   then return false end
  if R.kind == "stairwell" then return false end

  if R.is_secret  then return false end
  if R.is_start   then return false end

  if R:total_conns("ignore_secrets") >= 2 then return false end

  if #R.goals > 0 then return false end
  if #R.weapons > 0 then return false end

  return true
end


function secret_entry_conn(R, skip_room)
  -- find entry connection for a potential secret room
  -- skip_room is usually NIL

  each A in R.areas do
  each C in A.conns do
    if C.A1.room != C.A2.room and
       C.A1.room != skip_room and
       C.A2.room != skip_room
    then
      return C
    end
  end
  end

  error("Cannot find entry conn for secret room")
end


function ROOM_CLASS.valid_T(R, x, y)
  if x < R.tx1 or x > R.tx2 then return false end
  if y < R.ty1 or y > R.ty2 then return false end
  return true
end


function ROOM_CLASS.OLD__get_exits(R)
  local exits = {}

  each A in R.areas do
  each C in A.conns do
    if C.A1 == A and C.A2.room != R and
       not (C.kind == "double_R" or C.kind == "closet")
    then
      table.insert(exits, C)
    end
  end
  end

  return exits
end


---??? function ROOM_CLASS.conn_area(R)
---???   local lx, ly = 999,999
---???   local hx, hy = 0,0
---??? 
---???   each C in R.conns do
---???     if C.kind == "teleporter" then continue end
---???     local S = C:get_seed(R)
---???     lx = math.min(lx, S.sx)
---???     ly = math.min(ly, S.sy)
---???     hx = math.max(hx, S.sx)
---???     hy = math.max(hy, S.sy)
---???   end
---??? 
---???   assert(lx <= hx and ly <= hy)
---??? 
---???   return lx,ly, hx,hy
---??? end


---??? function ROOM_CLASS.is_near_exit(R)
---???   if R.purpose == "EXIT" then return true end
---???   each C in R.conns do
---???     local N = C:neighbor(R)
---???     if N.purpose == "EXIT" then return true end
---???   end
---???   return false
---??? end


function ROOM_CLASS.furthest_dist_from_entry(R)
  if not R.entry_coord then
    -- rough guess
    local S1 = SEEDS[R.sx1][R.sy1]
    local S2 = SEEDS[R.sx2][R.sy2]

    local w = S2.x2 - S1.x1
    local h = S2.y2 - S1.y1

    return math.max(w, h)
  end

  local result = 512

  local ex = R.entry_coord.x
  local ey = R.entry_coord.y

  for sx = R.sx1, R.sx2 do
  for sy = R.sy1, R.sy2 do
    local S = SEEDS[sx][sy]

    if S.room != R then continue end

    local ox = sel(S.x1 < ex, S.x1, S.x2)
    local oy = sel(S.y1 < ey, S.y1, S.y2)

    local dist = geom.dist(ex, ey, ox, oy)

    result = math.max(result, dist)
  end
  end

  return result
end



function ROOM_CLASS.add_decor(R, name, x, y, z)
  local info = GAME.ENTITIES[name]

  if not info then
    warning("Unknown decor entity: %s\n", tostring(name))

    info = { r=32, h=96 }
  end

  local DECOR =
  {
    name = name
    x = x
    y = y
    z = z

    r = info.r
    h = info.h
    pass = info.pass
  }

  table.insert(R.decor, DECOR)
end


function ROOM_CLASS.spots_do_decor(R, floor_h)
  local low_h  = PARAM.spot_low_h
  local high_h = PARAM.spot_high_h

  each D in R.decor do
    -- not solid?
    if D.pass then continue end

    local z1 = D.z
    local z2 = D.z + D.h

    if z1 >= floor_h + high_h then continue end
    if z2 <= floor_h then continue end

    local content = SPOT_LEDGE
    if z1 >= floor_h + low_h then content = SPOT_LOW_CEIL end

    local x1, y1 = D.x - D.r, D.y - D.r
    local x2, y2 = D.x + D.r, D.y + D.r

    gui.spots_fill_box(x1, y1, x2, y2, content)
  end
end


function ROOM_CLASS.add_exclusion(R, kind, x1, y1, x2, y2, extra_dist)
  local area =
  {
    kind = kind
    x1 = x1 - (extra_dist or 0)
    y1 = y1 - (extra_dist or 0)
    x2 = x2 + (extra_dist or 0)
    y2 = y2 + (extra_dist or 0)
  }

  table.insert(R.exclusions, area)
end


function ROOM_CLASS.clip_spot_list(R, list, x1, y1, x2, y2, strict_mode)
  local new_list = {}

  each spot in list do
    if (spot.x2 <= x1) or (spot.x1 >= x2) or
       (spot.y2 <= y1) or (spot.y1 >= y2)
    then
      -- unclipped

    elseif strict_mode then
      -- drop this spot
      continue

    else
      local w1 = x1 - spot.x1
      local w2 = spot.x2 - x2

      local h1 = y1 - spot.y1
      local h2 = spot.y2 - y2

      -- totally clipped?
      if math.max(w1, w2, h1, h2) < 8 then
        continue
      end

      -- shrink the existing box (keep side with most free space)

      if w1 >= math.max(w2, h1, h2) then
        spot.x2 = spot.x1 + w1
      elseif w2 >= math.max(w1, h1, h2) then
        spot.x1 = spot.x2 - w2
      elseif h1 >= math.max(w1, w2, h2) then
        spot.y2 = spot.y1 + h1
      else
        spot.y1 = spot.y2 - h2
      end

      assert(spot.x2 > spot.x1)
      assert(spot.y2 > spot.y1)
    end

    table.insert(new_list, spot)
  end

  return new_list
end


function ROOM_CLASS.clip_spots(R, x1, y1, x2, y2)
  -- the given rectangle is where we _cannot_ have a spot

  assert(x1 < x2)
  assert(y1 < y2)

  -- enlarge the area a bit
  x1, y1 = x1 - 4, y1 - 4
  x2, y2 = x2 + 4, y2 + 4

  R.mon_spots  = R:clip_spot_list(R.mon_spots,  x1, y1, x2, y2)

---??  R.item_spots = R:clip_spot_list(R.item_spots, x1, y1, x2, y2)
---??  R.big_spots  = R:clip_spot_list(R.big_spots,  x1, y1, x2, y2, "strict")
end


function ROOM_CLASS.exclude_monsters(R)
  each box in R.exclusions do
    if box.kind == "empty" then
      R:clip_spots(box.x1, box.y1, box.x2, box.y2)
    end
  end
end


------------------------------------------------------------------------


function Room_create_sky_groups()
  --
  -- This makes sure that any two outdoor rooms which touch will belong
  -- to the same 'sky_group' and hence get the same sky height.
  --
  -- Note: actual sky heights are determined later.
  --

  local function new_sky_add_h()
    if rand.odds(2)  then return 320 end

    return rand.pick({ 144, 160, 176, 192, 208 })
  end


  ---| Room_create_sky_groups |---

  each Z in LEVEL.zones do
    Z.sky_add_h = new_sky_add_h()
  end
end



function Room_reckon_doors()

  local  indoor_prob = style_sel("doors", 0, 10, 30,  90)
  local outdoor_prob = style_sel("doors", 0, 30, 90, 100)

  local woody = rand.odds(25)


  local DEFAULT_PROBS = {}

  local function door_chance(R1, R2)  -- NOTE : NOT USED ATM
    local door_probs = THEME.door_probs or
                       GAME.door_probs or
                       DEFAULT_PROBS

    if R1.is_outdoor and R2.is_outdoor then
      return door_probs.out_both or 0

    elseif R1.is_outdoor or R2.is_outdoor then
      return door_probs.out_diff or 80

    elseif R1.kind == "stairwell" or R2.kind == "stairwell" then
      return door_probs.stairwell or 1

    elseif R1.hallway and R2.hallway then
      return door_probs.hall_both or 2

    elseif R1.hallway or R2.hallway then
      return door_probs.hall_diff or 60

    elseif R1.main_tex != R2.main_tex then
      return door_probs.combo_diff or 40

    else
      return door_probs.normal or 20
    end
  end


  local function visit_conn(C)
    if C.kind == "teleporter" then return end
    if C.kind == "closet"     then return end

    local S = C.S1
    local N = C.S2
    local dir = C.dir

    local B  = S.border[dir]
    local B2 = N.border[10 - dir]

    if B.kind != "arch" then
      S, N  = N, S
      B, B2 = B2, B
      dir = 10 - dir
    end

    assert(B.kind == "arch")


    S.thick[     dir] = 40
    N.thick[10 - dir] = 40

    -- locked door?

    if C.lock then
      B.kind = "lock_door"
      B.conn = C
      B.lock = C.lock

      C.is_door = true

      -- FIXME: smells like a hack!!
      if B.lock.switch and string.sub(B.lock.switch, 1, 4) == "bar_" then
        B.kind = "bars"
      end

      C.fresh_floor = true
      return
    end

    -- secret door ?

    if S.room.is_secret != N.room.is_secret then
      -- TODO: if both rooms are outdoor, make a ''secret fence''

      B.kind = "secret_door"
      C.is_door = true

      -- mark the first seed so it can have the secret special
      C.S2.mark_secret = true
      return
    end


    -- same room?
    if C.A1.room == C.A2.room then
      B.kind  = "nothing"
      B2.kind = "nothing"
      return
    end


    -- don't need anything between two outdoor rooms
    -- [ the style check prevents silly "free standing" arches ]
    if (S.room.is_outdoor and N.room.is_outdoor) and
       (rand.odds(90) or STYLE.fences == "none")
    then
      B.kind  = "nothing"
      B2.kind = "nothing"
      return
    end


--!!!!!!1 DISABLED NORMAL DOORS (etc) FOR NOW
do return end


    -- apply the random check
    local prob = indoor_prob
    if (S.room.is_outdoor and N.room.kind != "cave") or
       (N.room.is_outdoor and S.room.kind != "cave")
    then
      prob = outdoor_prob
    end

    if rand.odds(prob) then
      B.kind = "door"
      C.is_door = true

      if rand.odds(30) then
        C.fresh_floor = true
      end

      return
    end


    -- special archways for caves
    local R1 = S.room
    local R2 = N.room

    if R2.kind == "cave" and not R2.is_outdoor then
      R1, R2 = R2, R1
    end

    if R1.kind == "cave" and not R1.is_outdoor then
      if R2.kind != "building" then
        B.fab_name = sel(woody, "Arch_woody", "Arch_viney")
        return
      end
    end

    -- support arches which have a step in them
    if (S.room.is_outdoor != N.room.is_outdoor) or rand.odds(50) then
      if THEME.archy_arches then return end
      if STYLE.steepness == "none" then return end

      if not (S.room.hallway or N.room.hallway) then
        if S == C.S1 then
          C.diff_h = 16
        else
          C.diff_h = -16
        end
        C.fresh_floor = true
      end
    end
  end


  ---| Room_reckon_doors |---

  each C in LEVEL.conns do
    visit_conn(C)
  end
end



function Room_detect_porches(R)
  --
  -- A "porch" is typically an area of an outdoor room that neighbors a
  -- building and will be given a solid low ceiling and some pillars to
  -- hold it up, and a floor higher than any nearby areas of the room.
  --
  -- It can also be used indoors (what previous code called a "periph").
  --
  -- Another use case is an outdoor hallway which is mostly surrounded
  -- by outdoor areas, and is higher than those areas.
  --

  local best_A
  local best_score


  local function set_as_porch(A)
    A.is_porch = true

    -- Note : keeping 'is_outdoor' on the area
  end


  local function detect_hallway_porch()
    -- keep it simple, ignore merged hallways
    if #R.areas > 1 then return false end

    local HA = R.areas[1]

    each edge in HA.edge_loops[1] do
      local N = edge.S:neighbor(edge.dir)

      if not (N and N.area) then return false end

      local A2 = N.area

      if A2.mode == "scenic" then
        -- ok
        continue
      end

      local R2 = A2.room
      assert(R2 != R)

      if not R2 then
        -- no void, thanks
        return false
      end

      -- same zone?
      if R2.zone != R.zone then
        -- ok
        continue
      end

      -- TODO : if hallway is large, allow a few edges
      if not R2.is_outdoor then
         return false
      end

      -- floor check
      if HA.floor_h + 64 < (A2.floor_h or 0) then
        return false
      end
    end

    gui.debugf("Hallway %s is now a PORCH\n", R:tostr())

    set_as_porch(HA)
    
    return true
  end


  local function eval_porch(A, mode)
    -- mode is either "indoor" or "outdoor"

    -- size check : never too much of room
    if A.svolume > R.svolume / 2 then return -1 end

    -- shape check : we want high twistiness, low openness
    if A.openness > 0.3 then return -1 end

    -- FIXME.....
    
    local score = 100 + A.svolume - A.openness * 100

    -- tie break
    return score + gui.random()
  end


  local function detect_normal_porch(mode)
    -- only one per room, so pick best
    best_A = nil
    best_score = 0

    each A in R.areas do
      local score = eval_porch(A, "indoor")

      if score > best_score then
        best_A = A
        best_score = score
      end
    end

    if best_A then
      set_as_porch(best_A)

      gui.debugf("Made %s into a PORCH\n", best_A.name)
    end
  end


  ---| Room_detect_porches |---

  if R.kind == "stairwell" then
    -- never

  elseif R.kind == "hallway" then
    detect_hallway_porch()

  elseif R.is_outdoor then
    detect_normal_porch("outdoor")

  else
    detect_normal_porch("indoor")
  end
end



function Room_border_up()

  local function visit_area_pair(junc, A1, A2)
    assert(A1 != A2)


    -- handle edge of map
    -- [ normal rooms generally don't touch the edge ]

    if A2 == "map_edge" then
      if A1.room or A1.mode == "cage" or A1.mode == "trap" or A1.mode == "pool" then
        junc.kind = "wall"
      else
        junc.kind = "nothing"
      end

      return
    end


    -- zones : gotta keep 'em separated

    if A1.zone != A2.zone then
      junc.kind = "wall"
      return
    end


    -- already decided?  [ outdoor borders ]
    if junc.kind then return end


    -- void --

    if A1.mode == "void" or A2.mode == "void" or
       A1.mode == "trap" or A2.mode == "trap"
    then
      junc.kind = "wall"
      return
    end

    if A2.room and not A1.room then
      A1, A2 = A2, A1
    end

    -- scenic to scenic --

    if not A1.room then
      -- nothing needed if both building or both outdoor
      if A1.is_outdoor == A2.is_outdoor then return end

      junc.kind = "wall"
      return
    end

    -- room to scenic --

    if not A2.room then
      -- FIXME
      junc.kind = "window"
      return
    end

    -- room to room --
 
    if A1.room == A2.room then
      -- nothing absolutely needed if same room
      -- FIXME : too simplistic!

      if A1.is_porch or A2.is_porch then
        junc.kind = "pillar"
        return
      end

-- STEP TEST
local z1 = math.min(A1.floor_h, A2.floor_h)
local z2 = math.max(A1.floor_h, A2.floor_h)
if (z2 - z1) >  65 and (z2 - z1) <= 72 then
  junc.kind = "steps"
  junc.steps_mat = "FLAT1"

  if not A1.is_outdoor then
    junc.kind2 = "pillar"
  end
end

      return
    end


--[[
--!!!!!!  DEBUG FOR CTF MAPS
junc.kind = "fence"
junc.fence_mat = LEVEL.fence_mat
junc.fence_top_z = 32
do return end
--]]


    -- blended hallways --

    if A1.mode == "hallway" and
       A1.room.hallway.parent and
       A1.room.hallway.parent == A2.room
    then
      junc.kind = "nothing"
      return
    end

    if A2.mode == "hallway" and
       A2.room.hallway.parent and
       A2.room.hallway.parent == A1.room
    then
      junc.kind = "nothing"
      return
    end


    -- outdoor to outdoor
    if A1.is_outdoor and A2.is_outdoor then
      junc.kind = "fence"
      junc.fence_mat = LEVEL.fence_mat
      junc.fence_top_z = math.max(A1.floor_h, A2.floor_h) + 32

      if A1.is_porch or A2.is_porch then
        junc.kind2 = "pillar"
      end

      return
    end


    -- FIXME

    junc.kind = "wall"
    return
  end


  ---| Room_border_up |---

  each _,junc in LEVEL.area_junctions do
    visit_area_pair(junc, junc.A1, junc.A2)
  end

end



function Room_tizzy_up()

  ---| Room_tizzy_up |---

  each R in LEVEL.rooms do
--    Room_add_crates(R)
  end
end



function Room_distribute_spots(R, list)
  local seen = {}

  -- TODO : move this into Fab_process_spots()

  each spot in list do
    seen[spot.kind] = 1

    if spot.kind == "cage" then
      table.insert(R.cage_spots, spot)
    elseif spot.kind == "trap" then
      table.insert(R.trap_spots, spot)
    elseif spot.kind == "pickup" or spot.kind == "big_item" then
      table.insert(R.item_spots, spot)
    elseif spot.kind == "important" then
      table.insert(R.important_spots, spot)
    else
      table.insert(R.mon_spots, spot)
    end
  end

  -- FIXME : do this ONCE (perhaps in item.lua) !!!

  -- 1. when no big item spots, convert important spots
  -- 2. when no small item spots, convert monster spots

  each spot in list do

    if not seen["big_item"] and spot.kind == "important" then
      local new_spot = table.copy(spot)
      new_spot.kind = "big_item"
      table.insert(R.item_spots, new_spot)
    end

    if not seen["pickup"] and spot.kind == "monster" then
      local new_spot = table.copy(spot)
      new_spot.kind = "pickup"
      table.insert(R.item_spots, new_spot)
    end

  end
end



function Room_find_ambush_focus(R)
  -- Note: computes 'entry_coord' too

  -- FIXME: handle teleporter entry

  if R.kind == "stairwell" then return end

  if R.kind == "cave" then return end

  local C = R.entry_conn

  if not C then return end
  if C.kind == "teleporter" then return end

  local S, side
  if C.R1 == R then
    S = C.S1
    side = C.dir
  else
    S = C.S2
    side = 10 - C.dir
  end

  assert(S)
  assert(S.floor_h)


  local mx, my = S:mid_point()

  local dx, dy = geom.delta(side)
  local angle  = geom.ANGLES[10 - side]

  mx = mx + dx * 48
  my = my + dy * 48

  R.entry_coord = { x=mx, y=my, z=S.floor_h + 40, angle=angle }

  R.ambush_focus = R.entry_coord
end



function Room_run_builders()
  each R in LEVEL.scenic_rooms do
    Room_build_seeds(R)
  end

  each R in LEVEL.rooms do
    Room_build_seeds(R)

    Room_find_ambush_focus(R)
  end
end



function Room_determine_spots()
  
  -- Algorithm:
  --
  -- For each area of each room:
  --
  --   1. initialize grid to be LEDGE.
  --
  --   2. CLEAR the polygons for area's floor.  This will produce areas
  --      which are somewhat too large.
  --
  --   3. use draw_line to set edges of area to LEDGE again, fixing the
  --      "too large" problem of the above step.
  --
  --   4. use the CSG code to kill any blocking brushes.
  --      This step creates the WALL cells.
  --


  local function spots_for_area(R, A, mode)
    -- the 'mode' is normally NIL, can also be "cage" or "trap"

    -- get bbox of room
    local rx1, ry1, rx2, ry2 = area_get_bbox(A)

    -- initialize grid to "ledge"
    gui.spots_begin(rx1 - 48, ry1 - 48, rx2 + 48, ry2 + 48, A.floor_h, SPOT_LEDGE)

    -- clear polygons making up the floor
    each brush in A.floor_brushes do
      gui.spots_fill_poly(brush, SPOT_CLEAR)
    end

    -- set the edges of the area
    each E in A.side_edges do
      gui.spots_draw_line(E.x1, E.y1, E.x2, E.y2, SPOT_LEDGE)
    end

    -- remove decoration entities
    R:spots_do_decor(A.floor_h)

    -- remove walls and blockers (using nearby brushes)
    gui.spots_apply_brushes()

    -- add the spots to the room

    local item_spots = {}
    local  mon_spots = {}

    gui.spots_get_items(item_spots)
    gui.spots_get_mons(mon_spots)

--  stderrf("mon_spots @ %s floor:%d : %d\n", R:tostr(), f_h, #mon_spots)

    -- this is mainly for traps
    if A.mon_focus then
      each spot in mon_spots do
        spot.face = A.mon_focus
      end
    end

    if mode == "cage" then
      table.append(R.cage_spots, mon_spots)

    elseif mode == "trap" then
      table.append(R.trap_spots, mon_spots)
      table.append(R.item_spots, item_spots)

    else
      table.append(R.mon_spots,  mon_spots)
      table.append(R.item_spots, item_spots)
    end

    gui.spots_end()

--- DEBUG:
--- stderrf("AREA_%d has %d mon spots, %d item spots\n", A.id, #mon_spots, #item_spots)
  end


  local function spots_in_room(R)
    if R.kind == "stairwell" then return end
    if R.kind == "smallexit" then return end

    each A in R.areas do
      spots_for_area(R, A)
    end
  end


  ---| Room_determine_spots |---

  each R in LEVEL.rooms do
    spots_in_room(R)

    R:exclude_monsters()
  end

  -- handle cages and traps

  each A in LEVEL.areas do
    if A.mode == "cage" or A.mode == "trap" then
      local R = assert(A.face_room)
      spots_for_area(R, A, A.mode)
    end
  end
end


------------------------------------------------------------------------


function walkable_svolume()
  local vol = 0

  each A in LEVEL.areas do
    -- in CTF mode, don't count the mirrored parts
    if A.brother then continue end

    if A.mode == "normal" then
      vol = vol + A.svolume
    end
  end

  return vol
end


function sort_areas_by_volume()
  -- biggest first

  local list = table.copy(LEVEL.areas)

  each A in list do A.sort_rand = gui.random() end

  table.sort(list, function(A, B) return A.svolume + A.sort_rand > B.svolume + B.sort_rand end)

  return list
end



function Room_assign_voids()
  --
  -- Void areas are useful, the "unused" space can become closets, cages
  -- or even just something decorative.
  --

  local largest

  local visit_list


  local function flood_fill(A, visited)
    visited[A.id] = true

    each N in A.neighbors do
      if N.zone != A.zone then continue end

      if N.mode == "normal" and not visited[N.id] then
        flood_fill(N, visited)
      end
    end

    return visited
  end


  local function check_visited(visited)
    each A in LEVEL.areas do
      if A.zone != largest.zone then continue end

      if A.mode == "normal" then
        if not visited[A.id] then return false end
      end
    end

    return true -- OK --
  end


  local function can_void_area(A)
    -- this checks that if 'A' is voided, all other areas remain reachable
    
    A.mode = "void"

    -- in CTF maps, must void the mirrored area too
    if A.sister then A.sister.mode = "void" end

    -- we flood fill starting from a known, never-void area
    local visited = flood_fill(largest, {})

    -- leave as void if check succeeded
    if check_visited(visited) then
      -- sometimes reserve void area for closets
      -- [ i.e. never use it for big traps or cages ]
      if rand.odds(25) then
        A.is_closety = true
      end

      return true
    end

    A.mode = "normal"
    if A.sister then A.sister.mode = "normal" end

    return false
  end


  local function eval_void(A)
    if A.mode != "normal" then return -1 end

    -- CTF check (only visit areas in first half)
    if A.brother then return -1 end

    -- size check
    local too_big = 15
    if OB_CONFIG.mode == "dm" then too_big = 5 end

    if A.svolume >= too_big then return -1 end

    -- compute score (smaller is better)
    local score = 10 - A.svolume / 3.0

    if A.prefer_mode then
      if A.prefer_mode == "void" then
        score = score + 2.5
      else
        score = score - 2.5
      end
    end

    if rand.odds(5) then score = score * 2 end

    -- tie breaker
    return score + gui.random()
  end


  local function pick_area_to_void()
    while not table.empty(visit_list) do
      local A = table.remove(visit_list, 1)

      -- this test is expensive, so do it here where usage is limited
      if can_void_area(A) then return A end
    end

    return nil  -- nothing was possible    
  end


  local function handle_zone(Z)
    local quota = Z.num_areas / 6 + rand.range(0, 2.5)

    if OB_CONFIG.mode == "dm" or rand.odds(10) then
      quota = quota * 0.7
    end
 
    -- the largest area can never become VOID
    largest = Area_largest_area(Z)

    largest.no_void = true

    if largest.sister  then largest.sister .no_void = true end
    if largest.brother then largest.brother.no_void = true end

    -- evaluate each area, sort from best to worst
    visit_list = {}

    each A in LEVEL.areas do
      if A.zone != Z then continue end

      -- this also skips areas with a zone connection
      if A.no_void then continue end

      local score = eval_void(A)

      if score > 0 then
        A.void_score = score
        table.insert(visit_list, A)
      end
    end

    table.sort(visit_list,
        function(A, B) return A.void_score > B.void_score end)

    for i = 1, quota do
      if not pick_area_to_void() then
        break;
      end
    end
  end


  ---| Room_assign_voids |---

  each Z in LEVEL.zones do
    handle_zone(Z)
  end
end



STAIRWELL_SHAPES =
{
  --
  -- each shape is a list of directions
  -- direction has 10 added for the entry/exit of the stairwell (20 for DOUBLE width)
  -- we only store a single rotation [ don't need to mirror either ]
  --
  -- fallback shapes are ones which don't make good use of the space
  -- [ we auto-detect 1x1 curve and 1x2 straight fallbacks ]
  --
  -- scx,scy and lcx,lcy are coordinates to override control points
  -- (on "short" and "long" side, respectively).  the four lines which
  -- join the bezier start/end points form the coordinate space.
  --

  -- single seed
  A1 = { dirs={ 12,  6, 18,  4 }, steps=4, straight=1 }
  A2 = { dirs={ 12, 16,  8,  4 }, steps=4 }

  -- two seeds
  B1 = { dirs={ 12, 6, 6, 18, 4, 4 }, steps=6, straight=1 }
  B2 = { dirs={ 22, 6, 28, 4 }, steps=4, straight=1 }

  -- 2x2 box
  C1 = { dirs={ 12, 2, 6, 16, 8, 8,  4, 4 }, steps=6 }

  C2 = { dirs={ 22,  6, 6, 28, 4, 4 }, steps=6, straight=1 }
  C3 = { dirs={ 22, 26, 8,  8, 4, 4 }, steps=6 }

  C4 = { dirs={ 22, 6, 16, 8, 8,  4, 4 }, steps=6 }  -- fat to thin

  -- diamond box
  D1 = { dirs={ 11,  3, 19,  7 }, steps=6, straight=1 }
  D2 = { dirs={ 11, 13,  9,  7 }, steps=4 }

  -- other 2x2 seed shapes
  
  E1 = { dirs={  1, 12,  6,  9, 17 }, steps=6, scx=0.4, scy=0.5 }
  E2 = { dirs={ 11,  2,  6, 19,  7 }, steps=4, fallback=1, straight=1 }
  E3 = { dirs={ 11,  2,  6,  9, 17 }, steps=4 }

  F1 = { dirs={  1, 12, 6,  9, 8, 14 }, steps=6 }
  F2 = { dirs={ 11,  2, 6, 19, 8,  4 }, steps=4, fallback=1, straight=1 }

  G1 = { dirs={ 12,  2, 6, 19,  7, 4 }, steps=6, scx=0.4, scy=0.5 }
  G2 = { dirs={ 22, 6, 19, 7, 4 }, steps=6 } -- fat to thin

  H1 = { dirs={ 12,  2,  6, 19,  8,  4,  4 }, steps=6 }
  H2 = { dirs={  2,  2, 16,  9, 18,  4,  4 }, steps=6 }
  H3 = { dirs={  2, 12,  6,  9,  8, 14,  4 }, steps=6 }

  H4 = { dirs={ 22, 6, 19, 8, 4, 4 }, steps=6 }  -- fat to thin
  H5 = { dirs={ 2, 2, 6, 19, 8, 24 }, steps=6 }  --

  -- larger (2x3 and 3x3) shapes

  I1 = { dirs={ 1, 2, 2, 16, 8, 9, 17 }, steps=6, scx=0.85, scy=0.35 }
  I2 = { dirs={ 11, 2, 2, 6, 8, 19, 7 }, steps=4, fallback=1, straight=1 }
  I3 = { dirs={ 1, 12, 2, 6, 8, 9, 17 }, steps=6, fallback=1 }
  I4 = { dirs={ 11, 2, 2, 6, 8, 9, 17 }, steps=6, fallback=1 } 

  J1 = { dirs={ 1, 2, 2, 16, 8, 9, 18, 4 }, steps=6, scx=1.6, scy=0.5 }
  J2 = { dirs={ 11, 2, 2, 6, 8, 19, 8, 4 }, steps=4, fallback=1, straight=1 }
  J3 = { dirs={ 1, 12, 2, 6, 8, 9, 8, 14 }, steps=6, fallback=1 }

  K1 = { dirs={ 1, 2, 2, 16, 9, 8, 18, 4 }, steps=6 }
  K2 = { dirs={ 1, 22, 6, 9, 8, 8, 14 },    steps=6 }
  K3 = { dirs={ 11, 2, 2, 6, 19, 8, 8, 4 }, steps=6, straight=1 }

  K4 = { dirs={ 1, 12, 2, 6, 9, 8, 8, 14 }, steps=6, fallback=1 }
  K5 = { dirs={ 1, 12, 2, 6, 19, 8, 8, 4 }, steps=6, fallback=1 }

  -- any larger shapes are very rare (not worth supporting)
}


function Test_stairwell_shapes()
  --
  -- check all the shapes are actually closed and have two exits
  --

  local function test_shape(name, shape)
    local px = 9
    local py = 9

    local exits = {}

    each dir in shape.dirs do
      local is_wide = (dir >= 20)
      local is_exit = (dir >= 10)

      local d2 = dir % 10

      if d2 == 0 or d2 == 5 or dir >= 30 then
        error("Bad direction in shape " .. name)
      end

      if is_exit then
        table.insert(exits, d2)
      end

      local dx, dy = geom.delta(geom.LEFT[d2])

      if is_wide then
        dx = dx * 2
        dy = dy * 2
      end

      px = px + dx
      py = py + dy
    end

    -- check final position

    if px != 9 or py != 9 then
      error("Unclosed shape : " .. name)
    end

    -- check exits

    if #exits != 2 then
      error("Bad exits in shape " .. name)
    end

    if exits[1] == exits[2] then
      error("180 degree found in shape " .. name)
    end

    -- OK --
  end

  
  each name,shape in STAIRWELL_SHAPES do
    if not shape.dirs then
      error("Missing dirs in shape " .. name)
    end

    test_shape(name, shape)
  end
end



function Room_assign_hallways()
  -- pick some areas to become hallways
  -- [ does not actually connect them here ]

  local visit_list


  local function num_neighbor_with_mode(A, mode)
    local count = 0

    each N in A.neighbors do
      if N.mode == mode then count = count + 1 end
    end

    return count
  end


  local function eval_hallway(A)
    -- ignore scenic or void areas
    if A.mode != "normal" then return -1 end

    -- too big?
    if A.svolume > 24 then return -1 end

    -- too open?
    if A.openness > 0.4 then return -1 end

    -- CTF: ignore the mirrored half of the map
    if A.brother then return -1 end

    -- CTF: never use a non-peered area
    -- (because it is a pain to ensure the connection points are mirrored)
    if A.no_ctf_peer then return -1 end

    -- compute score (the less "open" the better)
    local score = 10 + (1.0 - A.openness) * 10

    if A.prefer_mode == "hallway" then
      score = score + 3.5
    elseif A.prefer_mode == "room" then
      score = score - 3.5
    end

    -- tie breaker
    return score + gui.random()
  end


  local function check_hallway_possible(A)
    -- need at least two normal neighbors
    if num_neighbor_with_mode(A, "normal") < 2 then return false end

      -- never touch an existing hallway
    if num_neighbor_with_mode(A, "hallway") > 0 then return false end

    if A.sister then
      if num_neighbor_with_mode(A.sister, "hallway") > 0 then return false end
    end

    -- CTF: prevent a mirrored hallway from touching its peer
    if A.sister and table.has_elem(A.neighbors, A.sister) then return false end

    return true
  end


  local function pick_area_for_hallway()
    while not table.empty(visit_list) do
      local A = table.remove(visit_list, 1)

      if check_hallway_possible(A) then return A end
    end

    return nil  -- nothing else possible
  end


  local function calc_shape_len(shape)
    local count = 0

    each dir in shape.dirs do
      if dir >= 20 then
        count = count + 2
      else
        count = count + 1
      end
    end

    return count
  end


  local function mirror_stairwell(shape)
    if not shape.mirror_dirs then
      shape.mirror_dirs = {}

      each dir in shape.dirs do
        local base = int(dir / 10) * 10
        table.insert(shape.mirror_dirs, 1, base + geom.MIRROR_X[dir % 10])
      end
    end

    return shape.mirror_dirs
  end


  local function compare_transformed_shape(A, A_edges, shape, ofs, mir, rot)
    local src_dirs

    if mir == 1 then
      src_dirs = mirror_stairwell(shape)
    else
      src_dirs = shape.dirs
    end

    local A_idx = 1 + ofs
    assert(A_idx <= #A_edges)

    local exits = {}
    local wides = {}

    each dir in src_dirs do
      local is_wide = (dir >= 20)
      local is_exit = (dir >= 10)

      -- TODO : support WIDE exit/entry
      if is_wide then return false end

      -- remember exit spot
      if is_exit then
        table.insert(exits, A_idx)
        table.insert(wides, is_wide)
      end

      local rot_dir = geom.ROTATE[rot][dir % 10]

      if rot_dir != A_edges[A_idx].dir then
        return false -- NO --
      end

      A_idx = A_idx + 1
      if A_idx > #A_edges then A_idx = 1 end
    end

    -- YES --

---DEBUG:
--- stderrf("AREA_%d matched shape %s (ofs:%d mir:%d rot:%d)\n", A.id, shape.name, ofs, mir, rot)
 
    -- store into list of possible stairwells

    assert(#exits == 2)

    local WELL =
    {
      edge1 = exits[1]
      edge2 = exits[2]

      info = shape
    }

    table.insert(A.stairwells, WELL)

    return true
  end


  local function test_stairwell_shape(A, shape)
    local outer_edges = A.edge_loops[1]

    -- quick reject : check number of edges
    if #outer_edges != calc_shape_len(shape) then
      return
    end

    for ofs = 0, #outer_edges - 1 do
    for mir = 0, 1 do
    for rot = 0, 6, 2 do
      compare_transformed_shape(A, outer_edges, shape, ofs, mir, rot)
    end
    end
    end
  end


  local function detect_stairwells(A)
    each name, shape in STAIRWELL_SHAPES do
      shape.name = name

      test_stairwell_shape(A, shape)
    end
  end


  local function handle_zone(Z)
    local quota = Z.num_areas / 8 + rand.range(0, 2.5)

    -- TODO : adjust quota for hallway style

    local largest = Area_largest_area(Z)

    largest.no_hallway = true

    if largest.sister  then largest.sister .no_hallway = true end
    if largest.brother then largest.brother.no_hallway = true end

    -- evaluate each area, sort from best to worst
    visit_list = {}

    each A in LEVEL.areas do
      if A.zone != Z  then continue end
      if A.no_hallway then continue end

      local score = eval_hallway(A)

      if score > 0 then
        A.hall_score = score
        table.insert(visit_list, A)
      end
    end

    table.sort(visit_list,
        function(A, B) return A.hall_score > B.hall_score end)

    for i = 1, quota do
      local A = pick_area_for_hallway()
      if not A then break; end

      A:make_hallway()

      detect_stairwells(A)
    end
  end


  ---| Room_assign_hallways |---

  each Z in LEVEL.zones do
    handle_zone(Z)
  end
end



function Room_choose_area_kinds()

  local resolve_outdoor_prob

  local POSITIONS = { 1,3,7,9, 5, 2,4,6,8 }


  local function kind_for_small_area__OLD(A)
    rand.shuffle(A.neighbors)

    each N in A.neighbors do
      if N.kind then
        A.kind = N.kind

        if A.mode != "hallway" then
          A.is_outdoor = N.is_outdoor
        end
        return true
      end
    end

    return false
  end


  local function waterify_some_areas()
    local list = table.copy(LEVEL.areas)
    rand.shuffle(list)

    each A in list do
      if A.mode == "normal" and rand.odds(30) then
        if A.kind == "cave" or A.kind == "landscape" then
          A.mode = "water"
        end
      end
    end
  end


  local function starts_from_quota(seed_quota)
    if rand.odds(25) then return 1 end

    -- in CTF mode everything is mirrored, so only need one start
    if OB_CONFIG.mode == "ctf" then return 1 end

    local rough_size = 200 * rand.skew(1.0, 0.4)

    local num = rand.int(seed_quota / rough_size)

    return math.clamp(1, num, 4)
  end


  local function area_for_position(pos)
    local dx, dy = geom.delta(pos)

    local sx = 0.5 + dx * rand.sel(50, 0.25, 0.4)
    local sy = 0.5 + dy * rand.sel(50, 0.25, 0.4)

    if pos == 5 then
      sx = sx + rand.pick({ -0.1, 0, 0.1 })
      sy = sy + rand.pick({ -0.1, 0, 0.1 })
    end

    sx = int(sx * SEED_W)
    sy = int(sy * SEED_H)

    assert(Seed_valid(sx, sy))

    local S = SEEDS[sx][sy]
    assert(S)

    if S.top and rand.odds(50) then
      S = S.top
    end

    -- for this, void and hallways are OK
    return assert(S.area)
  end


  local function already_set(A, what)
    if what == "outdoor" then return A.is_outdoor end
    if what == "cave"    then return A.is_cave end

    error("internal error: unknown area what: " .. tostring(what))
  end


  local function raw_set_kind(L, A, what)
    if what == "outdoor" then A.is_outdoor = true end
    if what == "cave"    then A.is_cave    = true end

    L.quota = L.quota - A.svolume
  end


  local function raw_clear_kind(A, what)
    if what == "outdoor" then A.is_outdoor = nil end
    if what == "cave"    then A.is_cave    = nil end
  end


  local function set_area(L, A, what)
    raw_set_kind(L, A, what)

    table.insert(L.areas, A)

    -- CTF mirroring
    local A2 = A.sister or A.brother

    if A2 then
      raw_set_kind(L, A2, what)
    end
  end


  local function set_area_or_room(L, A, what)
    if A.room then
      each B in A.room.areas do
        set_area(L, B, what)
      end

    else
      set_area(L, A, what)
    end
  end


  local function pick_area(L, what)
    -- collect possible neighbors
    local poss = {}

    local emerg_poss = {}

    each A in L.areas do
    each N in A.neighbors do
      if already_set(N, what) then continue end

      -- quota check (rather lax)
      if N.svolume > 5 + L.quota * 1.5 then continue end

      -- try to avoid conflicts  [this assumes outdoors are done first]
      if what == "cave" and N.is_outdoor then
        table.insert(emerg_poss, N)
      else
        -- could use 'add_unique' here, but this favors common neighbors
        -- (which should make these groups more "clumpy" -- what we want)
        table.insert(poss, N)
      end
    end
    end

    if table.empty(poss) then
      poss = emerg_poss
    end

    -- poss may be empty (returns nil)
    return rand.pick(poss)
  end


  local function spread_kind(what, start_num, seed_quota)
gui.printf("spread_kind '%s' : starts=%d  quota=%d\n", what, start_num, seed_quota)
    if start_num  < 1 then return end
    if seed_quota < 1 then return end


    local list = {}

    for i = 1, start_num do
      local quota = seed_quota / start_num
      quota = quota * rand.skew(1.0, 0.5)

      list[i] = { quota=quota, areas={} }

      -- pick start area
      assert(not table.empty(POSITIONS))

      local pos = table.remove(POSITIONS, 1)

      local A = area_for_position(pos)
      assert(A)

      set_area_or_room(list[i], A, what)
    end


    -- spread stuff round-robin until quotas are reached

    for loop = 1, 999 do
      if table.empty(list) then
        break;
      end

      for i = #list, 1, -1 do
        local L = list[i]

        if L.quota < 1 then
          table.remove(list, i)
          continue
        end

        local A = pick_area(L, what)

        -- nothing possible
        if not A then
          L.quota = -1
          continue
        end

        set_area_or_room(L, A, what)
      end
    end
  end


  local function clear_kind_in_room(R, what)
    each A in R.areas do
      raw_clear_kind(A, what)

      if A.sister then
        raw_clear_kind(A.sister, what)
      end
    end
  end


  local function resolve_conflicts()
    each R in LEVEL.rooms do
      local A1 = R.areas[1]

      -- CTF: only need to handle one of the mirrored rooms
      if A1.brother then continue end

      if A1.is_outdoor and A1.is_cave then
        if rand.odds(resolve_outdoor_prob) then
          clear_kind_in_room(R, "cave")
        else
          clear_kind_in_room(R, "outdoor")
        end
      end
    end

    -- for scenic areas, cave always overrides
    -- [ seems better than having a messy mixture of the two ]

    each A in LEVEL.areas do
      if A.is_outdoor and A.is_cave then
        A.is_outdoor = nil
      end
    end
  end


  local function convert_to_proper_kinds()
    -- converts 'is_outdoor' / 'is_cave' fields to a kind value

    each A in LEVEL.areas do
      if A.is_cave then
        A.kind = "cave"
      elseif A.is_outdoor then
        A.kind = rand.sel(50, "landscape", "courtyard")

        local A2 = A.sister or A.brother
        if A2 then A2.kind = A.kind end
      else
        A.kind = "building"
      end
    end

    -- assign to rooms now

    each R in LEVEL.rooms do
      local A = R.areas[1]

      R.is_outdoor = A.is_outdoor

      if R.kind == "UNSET" then
        R.kind = sel(A.is_outdoor, "outdoor", A.kind)
      end
    end   
  end


  ---| Room_choose_area_kinds |---

  local total_seeds = SEED_W * SEED_H

  -- skip = probability to not use it on this level (at all)

  local out_skip = style_sel("outdoors", 100, 40,  0, 0)
  local cav_skip = style_sel("caves",    100, 75, 25, 0)

  local out_quota = style_sel("outdoors", 0, 18, 30, 70)
  local cav_quota = style_sel("caves",    0, 40, 50, 70)

  out_quota = total_seeds * out_quota / 100
  cav_quota = total_seeds * cav_quota / 100

  if rand.odds(out_skip) then out_quota = 0 end
  if rand.odds(cav_skip) then cav_quota = 0 end

  local out_starts = starts_from_quota(out_quota)
  local cav_starts = starts_from_quota(cav_quota)

  if rand.odds(50) then
    out_starts = out_starts + 1
  end

  gui.printf("Outdoor starts: %d (quota %d, skip %d%%)\n", out_starts, out_quota, out_skip)
  gui.printf("Cave starts: %d (quota %d, skip %d%%)\n",    cav_starts, cav_quota, cav_skip)

  assert(out_starts + cav_starts <= 9)

  -- if rooms become both cave + outdoor, use this chance to pick one
  resolve_outdoor_prob = 50

  local out_comp = style_sel("outdoors", 0, 1, 2, 3)
  local cav_comp = style_sel("caves",    0, 1, 2, 3)

  if out_comp > cav_comp then resolve_outdoor_prob = 75 end
  if out_comp < cav_comp then resolve_outdoor_prob = 25 end

  -- with small # of starts, use less positions (which are further apart)
  if out_starts + cav_starts <= 5 then
    POSITIONS = { 1,3,7,9, 5 }
  end

  rand.shuffle(POSITIONS)

  spread_kind("outdoor", out_starts, out_quota)
  spread_kind("cave",    cav_starts, cav_quota)

  resolve_conflicts()
  convert_to_proper_kinds()

--???  fixup_small_areas()

---  waterify_some_areas()
end


------------------------------------------------------------------------


function Room_floor_heights()

  -- the 'entry_h' field of rooms also serves as a "visited already" flag


  local function raw_set_floor(A, floor_h)
    A.floor_h = floor_h
  end


  local function set_floor(A, floor_h)
    raw_set_floor(A, floor_h)

    -- floor heights are mirrored in CTF mode
    local A2 = A.sister or A.brother

    if A2 then
      assert(not A2.floor_h)
      raw_set_floor(A2, floor_h)
    end
  end


  local function pick_delta_h(min_d, max_d, up_chance)
    if rand.odds(up_chance) then
      return max_d + 8
    else
      return min_d - 8
    end
  end


  local function area_assign_delta(A, up_chance)
    local min_d, max_d

    each N in A.neighbors do
      if N.room == A.room and N.delta_h then
        min_d = math.N_min(N.delta_h, min_d)
        max_d = math.N_max(N.delta_h, max_d)
      end
    end

    if not min_d then
      A.delta_h = 0
    else
      A.delta_h = pick_delta_h(min_d, max_d, up_chance)
    end

    each N in A.neighbors do
      if N.room == A.room and not N.delta_h then
        area_assign_delta(N, up_chance)
      end
    end
  end


  local function process_room(R, entry_area)
    local start_area = rand.pick(R.areas)

    local up_chance = rand.pick({ 10, 50, 90 })

    -- recursively flow delta heights from a random starting area
    -- FIXME : use the conns, Luke!
    area_assign_delta(start_area, up_chance)

    local adjust_h = 0
    if entry_area then adjust_h = entry_area.delta_h end

    each A in R.areas do
      -- check each area got a delta_h
      assert(A.delta_h)

      set_floor(A, R.entry_h + A.delta_h - adjust_h)
    end
  end


  local function categorize_hall_shape(S, enter_dir, leave_dir, z_dir, z_size)
    local info =
    {
      dir = enter_dir
      delta_h = sel(z_size == "big", 48, 24)

      z_dir = z_dir
      z_size = z_size
      z_offset = 0
    }

    if leave_dir == enter_dir then
      info.shape = "I"

    elseif leave_dir == geom.LEFT[enter_dir] then
      info.shape = "C"
      info.mirror = false

    elseif leave_dir == geom.RIGHT[enter_dir] then
      info.shape = "C"
      info.mirror = true

    else
      error("weird hallway dirs")
    end

    if z_dir < 0 then
      if info.shape == "I" then
        info.dir = 10 - info.dir
      else
        if info.mirror then
          info.dir = geom.LEFT[info.dir]
        else
          info.dir = geom.RIGHT[info.dir]
        end

        info.mirror = not info.mirror
      end

      info.z_offset = - info.delta_h
    end

    return info
  end


  local function flow_through_hallway(R, S, enter_dir, floor_h)

-- stderrf("flow_through_hallway @ %s : %s\n", S:tostr(), R:tostr())

    table.insert(R.hallway.path, S)

    S.floor_h = floor_h
    S.hall_visited = true

    R.hallway.max_h = math.max(R.hallway.max_h, floor_h)
    R.hallway.min_h = math.min(R.hallway.min_h, floor_h)

    -- collect where we can go next + where can exit
    local next_dirs = {}
    local exit_dirs = {}

    local saw_fixed = false

    each dir in geom.ALL_DIRS do
      local N = S:neighbor(dir)
      
      if not (N and N.area) then continue end

      if N.area.room != R then
        if N.area.room == R.hallway.R1 then R.hallway.touch_R1 = R.hallway.touch_R1 + 1 end
        if N.area.room == R.hallway.R2 then R.hallway.touch_R2 = R.hallway.touch_R2 + 1 end

        if S.border[dir].conn and not N.area.room.entry_h then
          table.insert(exit_dirs, dir)
        end
        continue
      end

      if N.not_path then continue end
      if N.hall_visited then continue end

      -- Note: this assume fixed diagonals never branch elsewhere
      if N.fixed_diagonal then
        if not N.floor_h then
          table.insert(R.hallway.path, N)  -- needed for ceilings
          N.floor_h = floor_h
          N.hall_visited = true
        end

        saw_fixed = true
        continue
      end

      table.insert(next_dirs, dir)
    end

    -- all done?
    local total = #next_dirs + #exit_dirs

    if total == 0 then
      return
    end
    
    -- branching?
    if total > 1 then
      R.hallway.branched = true

      each dir in next_dirs do
        flow_through_hallway(R, S:neighbor(dir), dir, floor_h)
      end

      return
    end

    -- a single direction --

    local dir = next_dirs[1] or exit_dirs[1]

    -- FIXME : check for "door" (entry or exit)

    if not S.diagonal and not saw_fixed then
      S.hall_piece = categorize_hall_shape(S, enter_dir, dir, R.hallway.z_dir, R.hallway.z_size)

      floor_h = floor_h + S.hall_piece.delta_h * S.hall_piece.z_dir

      R.hallway.max_h = math.max(R.hallway.max_h, floor_h)
      R.hallway.min_h = math.min(R.hallway.min_h, floor_h)
    end

    if #next_dirs > 0 then
      return flow_through_hallway(R, S:neighbor(dir), dir, floor_h)
    end
  end


  local function hallway_other_end(R, entry_R)
    -- if the hallway has multiple exits, then one is picked arbitrarily

    each C in R.ext_conns do
      local R2 = sel(C.A1.room == R, C.A2.room, C.A1.room)

      if R2 != entry_R then return R2 end
    end

    error("hallway error : cannot find other end")
  end


  local function try_blend_hallway(R, which)
    -- which is either 1 or 2 (entry or exit)

    if R.hallway.no_blend then return end

    -- already blended?
    if R.hallway.parent then return end

    -- random chance
    if not rand.odds(sel(which == 1, 75, 25)) then return end

    local parent  = sel(which == 1, R.hallway.R1, R.hallway.R2)
    local touches = sel(which == 1, R.hallway.touch_R1, R.hallway.touch_R2)

    -- FIXME : check for a door  [ via junction ]

    -- different quest? (hence locked door)
    if R.quest != parent.quest then return end

    -- enough joinage?
    if touches < 3 then return end
    if (touches - 1) / #R.hallway.path < 0.48 then return end

    -- OK --

    R.hallway.parent = parent

    -- copy some parent properties, especially outdoors-ness
    R.is_outdoor = R.hallway.parent.is_outdoor

    each A in R.areas do
      A.is_outdoor = R.is_outdoor
    end
  end


  local function do_hallway_ceiling(R)
    if R.is_outdoor then
      -- will be zone.sky_h
      return
    end

    R.areas[1].ceil_h = R.areas[1].floor_h + R.hallway.height

    each S in R.hallway.path do
      if R.hallway.parent then
        S.ceil_h = R.areas[1].ceil_h
      else
        S.ceil_h = S.floor_h + R.hallway.height
      end
    end
  end


  local function process_hallway(R, conn)
    -- Note: this would be a problem if player starts could exist in a hallway
    assert(conn)

    R.hallway.max_h = R.entry_h
    R.hallway.min_h = R.entry_h

    local S, S_dir
    local from_A

    if conn.A1.room == R then
      S = conn.S1
      S_dir = 10 - conn.dir
      from_A = conn.A2
    else
      assert(conn.A2.room == R)
      S = conn.S2
      S_dir = conn.dir
      from_A = conn.A1
    end

    assert(S)
    assert(S_dir)

    R.hallway.height = 96

    R.hallway.path = {}

    R.hallway.R1 = from_A.room
    R.hallway.R2 = hallway_other_end(R, from_A.room)

    R.hallway.touch_R1 = 0
    R.hallway.touch_R2 = 0


    local flat_prob = sel(R.is_outdoor, 5, 20)

    if #R.areas > 1 or rand.odds(flat_prob) then
      -- our flow logic cannot handle multiple areas [ which is not common ]
      -- hence these cases become a single flat hallway

      each A in R.areas do
        A.floor_h = R.entry_h

        if not A.is_outdoor then
          A.ceil_h = A.floor_h + R.hallway.height
        end
      end

      R.hallway.flat = true
      return
    end


    -- decide vertical direction and steepness

    R.hallway.z_dir  = rand.sel(R.zone.hall_up_prob, 1, -1)
    R.hallway.z_size = rand.sel(3, "big", "small")

    if R.hallway.z_size == "big" then
      -- steep stairs need a bit more headroom
      R.hallway.height = R.hallway.height + 24
    end


    flow_through_hallway(R, S, S_dir, R.entry_h)

    -- check all parts got a height
    each S in R.areas[1].seeds do
      if S.not_path then continue end
      assert(S.floor_h)
    end

    -- transfer heights to neighbors
    each C in R.areas[1].conns do
      local N

      if C.A1.room == C.A2.room then continue end

      if C.A1.room == R then
        S = C.S1
        N = C.S2
      else
        assert(C.A2.room == R)
        S = C.S2
        N = C.S1
      end

      if not N.area.room.entry_h then
        local next_f = assert(S.floor_h)
        if S.hall_piece then next_f = next_f + S.hall_piece.delta_h * S.hall_piece.z_dir end
        N.area.room.next_f = next_f
      end
    end

    -- use highest floor for "the" floor_h (so that fences are high enough)
    set_floor(R.areas[1], R.hallway.max_h)

    -- check if can make hallway "blend" into one of connecting rooms
    try_blend_hallway(R, 1)
    try_blend_hallway(R, 2)

    -- set ceiling heights
    do_hallway_ceiling(R)
  end


  local function process_stairwell(R, prev_room)
    local A = R.areas[1]
    local well = A.is_stairwell

    local num_steps = well.info.steps

    local diff_h

    -- stairwells are never locked [ they are "downgraded" in quest code ]
    assert(not R:has_any_lock())

    do
      -- TODO : better logic to decide Z direction
      local z_dir = rand.sel(70, 1, -1)

      diff_h = rand.sel(50, 8, 12)
      if rand.odds(10) then diff_h = 16 end

      diff_h = diff_h * z_dir
    end

    -- with this logic, last step is same height as next room
    R.exit_h = R.entry_h + num_steps * diff_h

    A.floor_h = math.min(R.entry_h, R.exit_h)
    A.ceil_h  = A.floor_h + 192  -- dummy

    -- update the STAIRWELL information

    well.start_z    = R.entry_h
    well.num_steps  = num_steps
    well.diff_h     = diff_h

    assert(prev_room)

    if prev_room == well.room1 then
      -- OK
    elseif prev_room == well.room2 then
      well.edge1, well.edge2 = well.edge2, well.edge1
      well.wide1, well.wide2 = well.wide2, well.wide1
    else
      error("Bad stairwell (no match for prev_room)")
    end
  end


  local function visit_room(R, entry_h, entry_area, prev_room, via_conn)
    -- get peered room (for CTF mode)
    local R2 = R.sister or R.brother

    if entry_area then
      assert(entry_area.room == R)
    end

    -- handle start rooms and teleported-into rooms
    if not entry_h then
      entry_h = rand.irange(0, 4) * 64
    end

    R.entry_h = entry_h

    if R2 then
      R2.entry_h = entry_h
    end

    if not (R.kind == "hallway" or R.kind == "stairwell") then
      Room_detect_porches(R)
    end

    if R.kind == "stairwell" then
      process_stairwell(R, prev_room)
    elseif R.kind == "hallway" then
      process_hallway(R, via_conn, entry_h)
    else
      process_room(R, entry_area)
    end

    -- recurse to neighbors
    each A in R.areas do
    each C in A.conns do
      if C.is_cycle then continue end

      local A2 = C:neighbor(A)

      if A2.room == R then continue end

      -- already visited it?
      if A2.room.entry_h then continue end

      assert(A.floor_h)

      local next_f = R.exit_h or A.floor_h

      -- hallway crud (FIXME : HACKY)
      if A2.room.next_f then next_f = A2.room.next_f end

      visit_room(A2.room, next_f, A2, R, C)
    end
    end
  end


  ---| Room_floor_heights |---

  -- give each zone a preferred hallway z_dir
  each Z in LEVEL.zones do
    Z.hall_up_prob = rand.sel(70, 80, 20)
  end

  local first = LEVEL.start_room or LEVEL.blue_base or LEVEL.rooms[1]

  -- recursively visit all rooms
  visit_room(first)

  -- do hallway porches when all heights are known [ Hmmmm... ]
  each R in LEVEL.rooms do
    -- sanity check : all rooms were visited

--[[ "fubar" debug stuff
if not R.entry_h then
R.entry_h = -77
each A in R.areas do A.floor_h = R.entry_h end
end
--]]

    assert(R.entry_h)

    if R.kind == "hallway" then
--!!!!      Room_detect_porches(R)
    end
  end
end



function Room_update_sky_groups()

  local function do_area(A)
    local sky_h = A.floor_h + A.zone.sky_add_h

    A.zone.sky_h = math.N_max(A.zone.sky_h, sky_h)
  end


  ---| Room_update_sky_groups |---

  each A in LEVEL.areas do
    -- visit all normal, outdoor areas
    if A.floor_h and A.is_outdoor and not A.is_boundary then
      do_area(A)

      -- include nearby buildings in same zone
      -- [ TODO : perhaps limit to where areas share a window or doorway ]
      each N in A.neighbors do
        if N.zone == A.zone and N.floor_h and not N.is_outdoor and not N.is_boundary then
          do_area(N)
        end
      end
    end
  end
  
  -- ensure every zone gets a sky_h
  each Z in LEVEL.zones do
    if not Z.sky_h then
      Z.sky_h = 0
      Z.no_outdoors = true
    end
  end

  -- transfer final results into areas

  each A in LEVEL.areas do
    if A.floor_h and A.is_outdoor then
      A.ceil_h = A.zone.sky_h
    end
  end
end



function Room_add_sun()
  -- game check
  if not GAME.ENTITIES["sun"] then return end

  local sun_r = 25000
  local sun_h = 40000

  -- nine lights in the sky, one is "the sun" and the rest provide
  -- ambient light (to keep outdoor areas from getting too dark).

  local dim = 4
  local bright = 40

  for i = 1,10 do
    local angle = i * 36 - 18

    local x = math.sin(angle * math.pi / 180.0) * sun_r
    local y = math.cos(angle * math.pi / 180.0) * sun_r

    local level = sel(i == 2, bright, dim)

    Trans.entity("sun", x, y, sun_h, { light=level })
  end

  Trans.entity("sun", 0, 0, sun_h, { light=dim })
end



------------------------------------------------------------------------


function Room_build_all()
  
  gui.printf("\n---=====  Build Rooms =====---\n\n")

  Area_prune_hallways()

  Room_reckon_doors()
  Room_floor_heights()

  -- place importants -- done early as traps need to know where they are.
  -- it also sets LEVEL.player1_z -- needed for monster depots.
  each R in LEVEL.rooms do
    Layout_place_importants(R)
  end

  Layout_traps_and_cages()
  Layout_map_borders()
  Layout_liquid_stuff()

  -- this must be done _after_ cages and outdoor borders
  Room_create_sky_groups()

  Layout_update_cages()

  Room_border_up()
  Room_update_sky_groups()

  Layout_handle_corners()
  Layout_outdoor_shadows()

  Render_all_areas()
  Render_importants()

  Room_determine_spots()

  Room_add_sun()
  -- TODO intermission camera
end

