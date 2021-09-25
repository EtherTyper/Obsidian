PREFABS.Switch_wall_tight =
{
  file   = "switch/tight.wad",

  map = "MAP01",
  game = { heretic=1,hacx=1,chex3=0,strife=1,harmony=1 },

  prob   = 18,

  where  = "seeds",
  seed_w = 1,
  seed_h = 1,

  deep   =  16,
  over   = -16,

  x_fit = "frame",
  y_fit = "top",

  tag_1 = "?switch_tag",

  sector_1  = { [0]=70, [1]=15, [2]=5, [3]=5, [8]=10, [12]=3, [13]=3 },

}

PREFABS.Switch_wall_tight_chex3 =
{
  file   = "switch/tight.wad",

  map = "MAP01",
  game = "chex3",


  prob   = 18,

  where  = "seeds",
  seed_w = 1,
  seed_h = 1,

  deep   =  16,
  over   = -16,

  x_fit = "frame",
  y_fit = "top",

  tag_1 = "?switch_tag",

  sector_1  = { [0]=70, [1]=15, [2]=5, [3]=5, [8]=10, [12]=3, [13]=3 },

  tex__SWITCH = "SW1SLAD",

  forced_offsets = 
  {
    [9] = { x=47,y=11 }
  }

}

PREFABS.Switch_wall_tight2 =
{
  template = "Switch_wall_tight",

  map = "MAP02",
}

PREFABS.Switch_wall_tight2_chex3 =
{
  template = "Switch_wall_tight_chex3",

  map = "MAP02",
}

PREFABS.Switch_wall_tight3 =
{
  template = "Switch_wall_tight",

  map = "MAP03",
}

PREFABS.Switch_wall_tight3_chex3 =
{
  template = "Switch_wall_tight_chex3",

  map = "MAP03",
}
