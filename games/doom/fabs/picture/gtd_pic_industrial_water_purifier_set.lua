PREFABS.Pic_gtd_water_purifier =
{
  file = "picture/gtd_pic_industrial_water_purifier_set.wad",
  map = "MAP01",

  prob = 100,
  engine = "zdoom",

  group = "gtd_water_purifier",

  where = "seeds",
  height = 96,
  deep = 16,

  seed_w = 2,
  seed_h = 1,

  bound_z1 = 0,
  bound_z2 = 96,

  x_fit = { 20,64 , 192,236 },
  y_fit = "top",
  z_fit = { 82,85 , 87,90 }
}

PREFABS.Pic_gtd_water_purifier_limit =
{
  template = "Pic_gtd_water_purifier",

  engine = "!zdoom",

  line_300 = 0
}
