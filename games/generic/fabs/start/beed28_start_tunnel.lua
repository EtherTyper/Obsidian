--
-- Start tunnel
--

PREFABS.Start_beed28_tunnel = -- Default offsets are for Doom
{
  file  = "start/beed28_start_tunnel.wad",

  prob  = 500,
  game = { chex3=0, doom1=1, doom2=1, hacx=0, harmony=0, heretic=0, strife=0 },
  map = "MAP01",

  where  = "seeds",
  seed_w = 1,
  seed_h = 2,

  deep  =  16,
  over  = -16,

  x_fit = "frame",
}

PREFABS.Start_beed28_tunnel_chex3 =
{
  template = "Start_beed28_tunnel",
  map = "MAP02",
  game = "chex3",
}

PREFABS.Start_beed28_tunnel_hacx =
{
  template = "Start_beed28_tunnel",
  game = "hacx",
  forced_offsets =
  {
    [20] = { x=0, y=96 }
  }
}

PREFABS.Start_beed28_tunnel_harmony =
{
  template = "Start_beed28_tunnel",
  game = "harmony",
  forced_offsets =
  {
    [20] = { x=16, y=80 }
  }
}

PREFABS.Start_beed28_tunnel_heretic =
{
  template = "Start_beed28_tunnel",
  game = "heretic",
  forced_offsets =
  {
    [20] = { x=-48, y=50 }
  }
}

PREFABS.Start_beed28_tunnel_strife =
{
  template = "Start_beed28_tunnel",
  game = "strife",
  forced_offsets =
  {
    [20] = { x=0, y=66 }
  }
}

