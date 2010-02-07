-------------------------------------------
--- Space Generation Test
-------------------------------------------


-- create a fake 'gui' module for the util code
gui =
{
  random = function() return math.random() end
}

require 'util'


SEED_W = 32
SEED_H = 32

SEEDS = array_2D(SEED_W, SEED_H)


DIVIDE_ODDS = { 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 }
DIVIDE_ODDS = { 0,  5, 10, 20, 40, 60, 70, 80, 90, 95, 98, 99, 100 }
-- DIVIDE_ODDS = { 0, 60, 60, 60, 60, 60, 60, 60, 60, 60, 100 }

ROOM = 1


function divide_horiz(x, y, w, h)
  local w2 = int(w / 2)

  recursive_fill(x, y, w2, h)
  recursive_fill(x+w-w2, y, w2, h)
end


function divide_vert(x, y, w, h)
  local h2 = int(h / 2)

  recursive_fill(x, y, w, h2)
  recursive_fill(x, y+h-h2, w, h2)
end


function recursive_fill(x, y, w, h)
  local d

-- print(x, y, w, h)

  if (w > h) or (w == h and rand_odds(50)) then
    d = math.min(w, #DIVIDE_ODDS)

    if rand_odds(DIVIDE_ODDS[d]) then
      return divide_horiz(x, y, w, h)
    end
  else
    d = math.min(h, #DIVIDE_ODDS)

    if rand_odds(DIVIDE_ODDS[d]) then
      return divide_vert(x, y, w, h)
    end
  end

  -- no subdivision, just fill the space
  for sy = y, y+h-1 do
    for sx = x, x+w-1 do
      SEEDS[sx][sy] = ROOM
    end
  end

  ROOM = ROOM + 1
end


function generate_rand()
  for y = 1,SEED_H do
    for x = 1,SEED_W do
      SEEDS[x][y] = rand_index_by_probs({ 80, 40, 20, 10, 5 }) - 1
    end
  end
end


function write_seeds()
  for y = 1,SEED_H do
    for x = 1,SEED_W do
      print(SEEDS[x][y] or 0)
    end
  end
end


math.randomseed(0 + 1 * os.time())

recursive_fill(1,1, SEED_W,SEED_H)

write_seeds()
