----------------------------------------------------------------
--  DECK THE HALLS
----------------------------------------------------------------
--
--  Oblige Level Maker
--
--  Copyright (C) 2011 Andrew Apted
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
----------------------------------------------------------------

--[[ *** CLASS INFORMATION ***

class HALLWAY
{
  R1, K1  -- starting ROOM and SECTION
  R2, K2  -- ending ROOM and SECTION

  id : number (for debugging)

  path : list  -- the path between the start and the destination
               -- (not including either start or dest).
               -- each element contains: G (segment), next_dir, prev_dir

  sub_halls   -- number of hallways branching off this one
              -- (normally zero)

  wall_tex, floor_tex, ceil_tex 
}


class SEGMENT
{
  nx, ny    -- place in network map

  sx1, sy1, sx2, sy2  -- seed range

  link[DIR] : SEGMENT     -- links to neighboring segments

  section[DIR] : SECTION  -- bordering sections

  vert, horiz, junction : BOOL   -- general shape

  used : BOOL  -- has been used in a hallway (cannot use again)
}


--------------------------------------------------------------]]

require 'defs'
require 'util'


HALLWAY_CLASS = {}

function HALLWAY_CLASS.new()
  local H = { id=Plan_alloc_id("hall"), path={}, chunks={}, sub_halls=0 }
  table.set_class(H, HALLWAY_CLASS)
  return H
end


function HALLWAY_CLASS.tostr(H)
  return string.format("HALL_%d", H.id)
end


function HALLWAY_CLASS.reverse(H)
  H.R1, H.R2 = H.R2, H.R1
  H.K1, H.K2 = H.K2, H.K1

  if H.path then
    table.reverse(H.path)

    each P in H.path do
      P.next_dir, P.prev_dir = P.prev_dir, P.next_dir
    end
  end

  if H.chunks then
    table.reverse(H.chunks)
  end
end


----------------------------------------------------------------


function Hallway_place_em()

  -- Place hallways into the hallway channels.
  --
  -- First we setup a network of junctions and segments in the
  -- free hallway areas.  This includes what rooms / sections
  -- are bordering each segment.
  --
  -- Then we choose a starting place for a hallway and try to
  -- trace a valid hallway, stepping from junction to junction.
  -- If successful, the segments will be marked as used.

  local net_W
  local net_H
  local network


  local function is_valid(nx, ny)
    return (1 <= nx and nx <= net_W) and
           (1 <= ny and ny <= net_H)
  end


  local function is_free(sx1, sy1, sx2, sy2)
    for x = sx1,sx2 do for y = sy1,sy2 do
      local S = SEEDS[x][y]
      if S.room or S.hall then return false end
    end end

    return true
  end


  local function create_network()
    net_W = #LEVEL.network_X
    net_H = #LEVEL.network_Y

    network = table.array_2D(net_W, net_H)

    for nx = 1,net_W do for ny = 1,net_H do
      local XN = LEVEL.network_X[nx]
      local YN = LEVEL.network_Y[ny]

      if XN[2] > 0 and YN[2] > 0 and
         -- ignore section areas (an optimisation)
         ((not XN[3]) or (not YN[3]))
      then
        local sx1 = XN[1]
        local sy1 = YN[1]

        local sx2 = sx1 + XN[2] - 1
        local sy2 = sy1 + YN[2] - 1

        if is_free(sx1, sy1, sx2, sy2) then
          local SEG =
          {
            nx = nx, ny = ny,
            link = {}, section = {},
            sx1 = sx1, sy1 = sy1,
            sx2 = sx2, sy2 = sy2,
            horiz = (not YN[3]),
            vert  = (not XN[3]),
          }

          SEG.junction = SEG.horiz and SEG.vert

          network[nx][ny] = SEG
        end
      end
    end end
  end


  local function seg_to_char(SEG)
    if not SEG then return " " end
    if SEG.used then return "#" end
    if SEG.junction then return "+" end
    if SEG.vert then return "|" end
    if SEG.horiz then return "-" end
    return "?"
  end


  local function dump_network(title)
    gui.debugf(title or "Hall Network:\n")
    gui.debugf("\n")

    for ny = net_H,1,-1 do
      local line = " "
      for nx = 1,net_W do
        line = line .. seg_to_char(network[nx][ny])
      end
      gui.debugf("%s\n", line)
    end

    gui.debugf("\n")
  end


  local function section_neighbor(G, dir)
    local K

    -- check seeds
    local sx1, sy1, sx2, sy2 = geom.side_coords(dir, G.sx1, G.sy1, G.sx2, G.sy2)

    sx1, sy1 = geom.nudge(sx1, sy1, dir)
    sx2, sy2 = geom.nudge(sx2, sy2, dir)

    if not Seed_valid(sx1, sy1) then return nil end
    if not Seed_valid(sx2, sy2) then return nil end

    for sx = sx1,sx2 do for sy = sy1,sy2 do
      local S = SEEDS[sx][sy]

      -- require no empty seeds
      if not (S and S.section) then return nil end

      -- require same section (this test is probably unnecessary)
      if K and S.section != K then return nil end

      K = S.section
    end end

    return K
  end


  local function join_segments(G1, G2, dir)
    G1.link[dir]    = G2
    G2.link[10-dir] = G1
  end


  local function join_network()
    for nx = 1,net_W do for ny = 1,net_H do
      local G1 = network[nx][ny]

      for dir = 2,8,2 do
        local ox, oy = geom.nudge(nx, ny, dir)
        local G2

        if is_valid(ox, oy) then G2 = network[ox][oy] end
        
        if G1 and G2 then
          join_segments(G1, G2, dir)
        end

        if G1 and not G2 then
          G1.section[dir] = section_neighbor(G1, dir)
        end
      end
    end end
  end


  local function collect_starts()
    local starts = {}

    for nx = 1,net_W do for ny = 1,net_H do
      local G = network[nx][ny]
      if G then
        G.score = gui.random()  -- FIXME

        table.insert(starts, G)
      end
    end end

    table.sort(starts, function(A,B) return A.score > B.score end)

    return starts
  end


  local function dump_path(hall)
    gui.debugf("Path:\n")
    gui.debugf("{\n")
    for _,loc in ipairs(hall.path) do
      gui.debugf("  Segment @ (%d,%d) prev:%d next:%d\n", loc.G.sx1, loc.G.sy1,
                 loc.prev_dir or -1, loc.next_dir or -1)
    end
    gui.debugf("}\n")
  end


  local function fix_path_dirs(hall)
    -- sets the 'next_dir' fields in the path elements

    for idx = 1,#hall.path-1 do
      local L1 = hall.path[idx]
      local L2 = hall.path[idx+1]

      assert(L2.prev_dir)

      L1.next_dir = 10 - L2.prev_dir
    end
  end


  local function make_chunks(hall)
    hall.chunks = {}

    for _,loc in ipairs(hall.path) do
      local G = loc.G

      -- determine block range for segment

      local C = CHUNK_CLASS.new(G.sx1, G.sy1, G.sx2, G.sy2)

      loc.chunk = C

      C.hall = hall

      C:install()

      table.insert(hall.chunks, C)
    end
  end


  local function render_path(hall)
    for _,loc in ipairs(hall.path) do
      local G = loc.G

      -- mark segment as used
      assert(not G.used)
      G.used = true

      -- store hallway in seed map
      for sx = G.sx1,G.sx2 do for sy = G.sy1,G.sy2 do
        local S = SEEDS[sx][sy]
        assert(not S.room and not S.hall)
        S.hall = hall
      end end
    end
  end


  local function add_hall(hall)
    local R1 = hall.R1
    local R2 = hall.R2

    gui.debugf("Adding hallway %s --> %s\n", R1:tostr(), R2:tostr())

    fix_path_dirs(hall)
    dump_path(hall)

    Connect_merge_groups(R1.conn_group, R2.conn_group)

    local D = CONN_CLASS.new_R(R1, R2, "hallway")

    D.hall = hall

    table.insert(LEVEL.conns, D)

    table.insert(R1.conns, D)
    table.insert(R2.conns, D)

    if hall.K1 then hall.K1.num_conn = hall.K1.num_conn + 1 end
    if hall.K2 then hall.K2.num_conn = hall.K2.num_conn + 1 end

    render_path(hall)

    make_chunks(hall)
  end


  local function seg_in_path(path, G)
    for _,loc in ipairs(path) do
      if loc.G == G then return true end
    end

    return false
  end


  local function possible_terms(hall, G)
    local terms = {}

    for dir = 2,8,2 do
      local K = G.section[dir]
      if K and K.room then
        if not hall.R1 or Connect_possibility(hall.R1, K.room) >= 0 then
          table.insert(terms, { K=K, dir=dir })
        end
      end
    end

    return terms
  end


  local function possible_juncs(hall, G)
    local juncs = {}

    for dir = 2,8,2 do
      local G2 = G.link[dir]

      if G2 and not G2.used and not seg_in_path(hall.path, G2) then
        table.insert(juncs, { G=G2, dir=dir })
      end
    end

    return juncs
  end


  local function try_trace_hall(hall)
    local loc = hall.path[1]
    assert(loc and loc.G)

    local G = loc.G

    -- choose starting room off first segment
    local terms = possible_terms(hall, G)

    if #terms == 0 then return false end

    local T = rand.pick(terms)

    hall.K1 = T.K
    hall.R1 = T.K.room

    loc.prev_dir = T.dir


    -- make a path

    local TERMINATE_PROB = { 10,30,50,60,70,80,90,90,90,90 }

    while #hall.path < #TERMINATE_PROB do
      local terms = possible_terms(hall, G)
      local juncs = possible_juncs(hall, G)

      -- require at least one additional segment
      if #hall.path == 1 then terms = {} end

      -- nowhere to go?
      if #terms == 0 and #juncs == 0 then return false end

      if #terms > 0 and #juncs > 0 then
        if rand.odds(TERMINATE_PROB[#hall.path]) then
          juncs = {}
        else
          terms = {}
        end
      end

      --- TERMINATE ? ---

      if #terms > 0 then
        local T = rand.pick(terms)

        hall.K2 = T.K
        hall.R2 = T.K.room

        local last_loc = table.last(hall.path)
        last_loc.next_dir = T.dir

        return true
      end

      -- pick a junction and continue the hallway

      assert(#juncs > 0)
      local J = rand.pick(juncs)

      table.insert(hall.path, { G=J.G, prev_dir=J.dir })

      G = J.G
    end

    -- too many segments
    return false
  end


  local function trace_hall(G)
    if G.used then return false end

    for loop = 1,15 do
      local hall = HALLWAY_CLASS.new()

      table.insert(hall.path, {G=G})

      if try_trace_hall(hall) then
        add_hall(hall)
        return true
      end
    end

    return false
  end


  local function how_many()
    local perc = style_sel("hallways", 0, 15, 35, 100)

    local num = (SECTION_W + 1) * perc / 100

    return int(num + gui.random())
  end


  ---| Hallway_place_em |---

  if STYLE.hallways == "none" then return; end

  create_network()
  dump_network("Initial Hall Network:")
  join_network()

  local starts  = collect_starts()

  local count   = 0
  local max_num = how_many()

  -- FIXME: try special stuff (half-surrounded, etc)

  for _,G in ipairs(starts) do
    if count >= max_num then break; end

    if trace_hall(G) then
      count = count + 1
    end
  end

  gui.printf("Added %d hallways\n", count)

  dump_network("Final Hall Network:")
end


--------------------------------------------------------------------


-- TODO: hallway construction/layout stuff

