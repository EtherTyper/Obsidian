--
-- Keyed doors, door size
--

PREFABS.Locked_door_key1 =
{
  file   = "door/key_door.wad",
  map    = "MAP01",
  game   = "!heretic",

  prob   = 50,

  where  = "edge",
  key    = "k_one",

  seed_w = 2,

  deep   = 32,
  over   = 32,

  x_fit  = "frame",

}

PREFABS.Locked_door_key1_heretic =
{
  file   = "door/key_door.wad",
  map    = "MAP01",
  game   = "heretic",

  prob   = 50,

  where  = "edge",
  key    = "k_one",

  seed_w = 2,

  deep   = 32,
  over   = 32,

  x_fit  = "frame",

  forced_offsets = 
  {
    [21] = { x=24, y=0 },
    [23] = { x=24, y=0 },
    [29] = { x=24, y=0 },
    [31] = { x=24, y=0 },
    [14] = { x=39, y=1 },
    [16] = { x=39, y=1 },
    [12] = { x=14, y=1 },
    [18] = { x=14, y=1 },
  }
}


PREFABS.Locked_door_key1_diag =
{
  file   = "door/key_door.wad",
  map    = "MAP02",
  game   = "!heretic",

  key    = "k_one",

  prob   = 50,

  where  = "diagonal",

  seed_w = 2,
  seed_h = 2,
}

PREFABS.Locked_door_key1_diag_heretic =
{
  file   = "door/key_door.wad",
  map    = "MAP02",
  game   = "heretic",

  key    = "k_one",

  prob   = 50,

  where  = "diagonal",

  seed_w = 2,
  seed_h = 2,

  forced_offsets = 
  {
    [21] = { x=24, y=0 },
    [23] = { x=24, y=0 },
    [29] = { x=24, y=0 },
    [31] = { x=24, y=0 },
    [14] = { x=39, y=1 },
    [16] = { x=39, y=1 },
    [12] = { x=14, y=1 },
    [18] = { x=14, y=1 },
  }
}


----------------------------------------------


PREFABS.Locked_door_key2 =
{
  file   = "door/key_door.wad",
  map    = "MAP03",

  prob   = 50,

  where  = "edge",
  key    = "k_two",

  seed_w = 2,

  deep   = 32,
  over   = 32,

  x_fit  = "frame",
}


PREFABS.Locked_door_key2_diag =
{
  file   = "door/key_door.wad",
  map    = "MAP04",

  prob   = 50,

  key    = "k_two",
  where  = "diagonal",

  seed_w = 2,
  seed_h = 2,
}


----------------------------------------------


PREFABS.Locked_door_key3 =
{
  file   = "door/key_door.wad",
  map    = "MAP05",

  prob   = 50,

  where  = "edge",
  key    = "k_three",

  seed_w = 2,

  deep   = 32,
  over   = 32,

  x_fit  = "frame",
}


PREFABS.Locked_door_key3_diag =
{
  file   = "door/key_door.wad",
  map    = "MAP06",

  prob   = 50,

  key    = "k_three",
  where  = "diagonal",

  seed_w = 2,
  seed_h = 2,
}

