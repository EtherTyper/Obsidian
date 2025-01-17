--
-- 2-seed-wide hallway : locked terminators
--

PREFABS.Hallway_deuce_locked_key1 =
{
  file   = "hall/deuce_k.wad",
  map    = "MAP01",

  kind   = "terminator",
  group  = "deuce",
  key    = "k_one",

  prob   = 50,

  where  = "seeds",
  shape  = "I",

  seed_w = 2,
  seed_h = 1,

  deep   = 16,
}

PREFABS.Hallway_deuce_locked_key2 =
{
  file   = "hall/deuce_k.wad",
  map    = "MAP02",

  kind   = "terminator",
  group  = "deuce",
  key    = "k_two",

  prob   = 50,

  where  = "seeds",
  shape  = "I",

  seed_w = 2,
  seed_h = 1,

  deep   = 16,
}


PREFABS.Hallway_deuce_locked_key3 =
{
  file   = "hall/deuce_k.wad",
  map    = "MAP03",

  kind   = "terminator",
  group  = "deuce",
  key    = "k_three",

  prob   = 50,

  where  = "seeds",
  shape  = "I",

  seed_w = 2,
  seed_h = 1,

  deep   = 16,
}


----------------------------------------------------------------

PREFABS.Hallway_deuce_barred =
{
  file   = "hall/deuce_k.wad",
  map    = "MAP03",

  kind   = "terminator",
  group  = "deuce",
  key    = "barred",

  prob   = 50,

  where  = "seeds",
  shape  = "I",

  seed_w = 2,
  seed_h = 1,
  deep   = 16,

  tag_1  = "?door_tag",
  door_action = "S1_LowerFloor",
}
