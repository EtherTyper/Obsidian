PREFABS.Wall_gothic_ceilwall_arch =
{
  file   = "wall/gtd_wall_gothic_ceilwall_set.wad",
  map    = "MAP01",

  prob   = 50,
  env = "building",

  group = "gtd_wall_gothic_ceilwall_arch",

  where  = "edge",
  deep   = 16,
  height = 128,

  bound_z1 = 0,
  bound_z2 = 128,

  z_fit  = "top",
}

PREFABS.Wall_gothic_ceilwall_arch_diag =
{
  template = "Wall_gothic_ceilwall_arch",
  map = "MAP02",

  where = "diagonal"
}
