------------------------------------------------------------------------
--  PANEL: Monsters
------------------------------------------------------------------------
--
--  Copyright (C) 2016-2017 Andrew Apted
--  Copyright (C) 2019-2022 Armaetus
--  Copyright (C) 2019-2022 MsrSgtShooterPerson
--
--  This program is free software; you can redistribute it and/or
--  modify it under the terms of the GNU General Public License
--  as published by the Free Software Foundation; either version 2,
--  of the License, or (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
------------------------------------------------------------------------

UI_MONS = { }

UI_MONS.BOSSES =
{
  "none",   _("NONE"),
  "easier", _("Easier"),
  "medium", _("Average"),
  "harder", _("Harder"),
}

UI_MONS.TRAP_STYLE =
{
  "default",   _("DEFAULT"),
  "teleports", _("Teleports Only"),
  "closets",   _("Closets Only"),
  "20",        _("20% Closets - 80% Teleports"),
  "40",        _("40% Closets - 60% Teleports"),
  "60",        _("60% Closets - 40% Teleports"),
  "80",        _("80% Closets - 20% Teleports"),
}

UI_MONS.CAGE_STRENGTH =
{
  "weaker",    _("Weaker"),
  "easier",    _("Easier"),
  "default",   _("Average"),
  "tricky",    _("Tricky"),
  "treacherous", _("Treacherous"),
  "dangerous", _("Dangerous"),
  "deadly",    _("Deadly"),
  "lethal",    _("Lethal"),
  "crazy",     _("CRAZY"),
}

UI_MONS.SECRET_MONSTERS =
{
  "yesyes", _("Yes - Full Strength"),
  "yes",    _("Yes - Weak"),
  "no",     _("No"),
}

UI_MONS.MONSTER_KIND_JUMPSTART_CHOICES =
{
  "default", _("DEFAULT"),
  "harder", _("Harder"),
  "tougher", _("Tougher"),
  "fiercer", _("Fiercer"),
  "crazier", _("CRAZIER")
}

UI_MONS.BOSSREGULARS =
{
  "no",  _("Disabled"),
  "minor", _("Minor Bosses Only"),
  "nasty", _("Minor and Nasty Bosses Only"),
  "all", _("All Bosses"),
}

function UI_MONS.setup(self)
  -- these parameters have to be instantiated in this hook
  -- because begin_level happens *after* level size decisions
  for name,opt in pairs(self.options) do
    if OB_CONFIG.batch == "yes" then
      if opt.valuator then
        if opt.valuator == "slider" then 
          if opt.increment < 1 then
            PARAM[opt.name] = tonumber(OB_CONFIG[opt.name])
          else
            PARAM[opt.name] = int(tonumber(OB_CONFIG[opt.name]))
          end
        elseif opt.valuator == "button" then
          PARAM[opt.name] = tonumber(OB_CONFIG[opt.name])
        end
      else
        PARAM[opt.name] = OB_CONFIG[opt.name]
      end
      if RANDOMIZE_GROUPS then
        for _,group in pairs(RANDOMIZE_GROUPS) do
          if opt.randomize_group and opt.randomize_group == group then
            if opt.valuator then
              if opt.valuator == "button" then
                  PARAM[opt.name] = rand.sel(50, 1, 0)
                  goto done
              elseif opt.valuator == "slider" then
                  if opt.increment < 1 then
                    PARAM[opt.name] = rand.range(opt.min, opt.max)
                  else
                    PARAM[opt.name] = rand.irange(opt.min, opt.max)
                  end
                  goto done
              end
            else
              local index
              repeat
                index = rand.irange(1, #opt.choices)
              until (index % 2 == 1)
              PARAM[opt.name] = opt.choices[index]
              goto done
            end
          end
        end
      end
      ::done::
    else
	    if opt.valuator then
		    if opt.valuator == "button" then
		        PARAM[opt.name] = gui.get_module_button_value(self.name, opt.name)
		    elseif opt.valuator == "slider" then
		        PARAM[opt.name] = gui.get_module_slider_value(self.name, opt.name)      
		    end
      else
        PARAM[opt.name] = opt.value
	    end
	  end
  end
end

OB_MODULES["ui_mons"] =
{

  name = "ui_mons",

  label = _("Monsters"),

  hooks =
  {
    setup = UI_MONS.setup,
  },

  side = "right",
  priority = 103,
  engine = "!vanilla",
  options =
  {
    {
      name="float_mons",
      label=_("Quantity"),
      valuator = "slider",
      units = "",
      min = 0,
      max = 10.00,
      increment = .05,
      default = 1.0,
      nan = "Mix It Up,Progressive,",
      presets = "0:None," ..
      "0.15:0.15 (Trivial)," ..
      "0.35:0.35 (Sporadic)," ..
      "0.7:0.7 (Meager)," ..
      "1.0:1.0 (Easy)," ..
      "1.3:1.3 (Modest)," ..
      "1.5:1.5 (Bearable)," ..
      "2.0:2.0 (Rough)," ..
      "2.5:2.5 (Strenuous)," ..
      "3.0:3.0 (Formidable)," ..
      "3.5:3.5 (Harsh)," ..
      "4.0:4.0 (Painful)," ..
      "4.5:4.5 (Ferocious)," ..
      "5.0:5.0 (Unforgiving)," ..
      "5.5:5.5 (Punishing)," ..
      "6.0:6.0 (Murderous)," ..
      "6.5:6.5 (Grueling)," ..
      "7.0:7.0 (Unrelenting)," ..
      "7.5:7.5 (Arduous)," ..
      "8.0:8.0 (Barbaric)," ..
      "8.5:8.5 (Savage)," ..
      "9.0:9.0 (Brutal)," ..
      "9.5:9.5 (Draconian)," ..
      "10.0:10.00 (Merciless),",
      tooltip="Changes the amount of monsters placed in a map. Scales with level size.",
      longtip="For reference: Oblige 7.x's default for normal is 1.0.\n\n" ..
              "Mix It Up: Selects quantities specified between Upper and Lower " ..
              "Bound choices on a chosen by the user.\n\n" ..
              "Progressive: creates a curve of increasing monster population " ..
              "also based on the Fine Tune options below.\n\n" ..
              "It does not matter if your Upper/Lower Bound selections are reversed. " ..
              "Progressive will pick the min VS max quantities selected.\n\n" ..
              "None: No monsters. Why would you choose this option? \n" ..
              "Trivial: Very, very few monsters. Almost nothing to kill.\n" ..
              "Sporadic: Very few monsters. Not many things to kill.\n" ..
              "Meager: Fewer monsters. Not challenging for the average player.\n" ..
              "Easy: Oblige default quantity. Not too bad for casual players.\n" ..
              "Modest: Slightly above default. Still pretty easy for most. \n" ..
              "Bearable: Above average opposition. Getting warmer! \n" ..
              "Rough: Slightly difficult. Equivalent to late 90s megawads. \n" ..
              "Strenuous: Baby steps into big boy difficulty. Lots to kill! \n" ..
              "Formidable/Harsh: 'Easy' level of difficult. Considerable opposition. \n" ..
              "Painful/Ferocious: Getting into slaughterwad territory. Difficult! \n" ..
              "Unforgiving/Punishing: Slaughterwad level difficulty. Skill needed. \n" ..
              "Murderous/Grueling: Extremely high monster count. \n" ..
              "Unrelenting/Arduous: An uphill battle. Expect to reload saves often! \n" ..
              "Barbaric/Savage: Up into the hardest slaughterwads out there. \n" ..
              "Brutal/Draconian: Legions of demons await you on this setting. \n" ..
              "Merciless: Hell will throw everything at you at this setting, you masochist.",
    },

    {
      name="float_mix_it_up_upper_range",
      label=_("Upper Bound"),
      valuator = "slider",
      units = "",
      min = 0,
      max = 10.00,
      increment = .05,
      default = 10,
      presets = "0:None," ..
      "0.15:0.15 (Trivial)," ..
      "0.35:0.35 (Sporadic)," ..
      "0.7:0.7 (Meager)," ..
      "1.0:1.0 (Easy)," ..
      "1.3:1.3 (Modest)," ..
      "1.5:1.5 (Bearable)," ..
      "2.0:2.0 (Rough)," ..
      "2.5:2.5 (Strenuous)," ..
      "3.0:3.0 (Formidable)," ..
      "3.5:3.5 (Harsh)," ..
      "4.0:4.0 (Painful)," ..
      "4.5:4.5 (Ferocious)," ..
      "5.0:5.0 (Unforgiving)," ..
      "5.5:5.5 (Punishing)," ..
      "6.0:6.0 (Murderous)," ..
      "6.5:6.5 (Grueling)," ..
      "7.0:7.0 (Unrelenting)," ..
      "7.5:7.5 (Arduous)," ..
      "8.0:8.0 (Barbaric)," ..
      "8.5:8.5 (Savage)," ..
      "9.0:9.0 (Brutal)," ..
      "9.5:9.5 (Draconian)," ..
      "10.0:10.00 (Merciless),",
            tooltip="If you have Mix It Up or Progressive selected, you can define the upper bound here. Otherwise, this option is simply ignored.",
            longtip="For reference: Oblige 7.x's default for normal is 1.0.\n\n" ..
              "Mix It Up: Selects quantities specified between Upper and Lower " ..
              "Bound choices on a chosen by the user.\n\n" ..
              "Progressive: creates a curve of increasing monster population " ..
              "also based on the Fine Tune options below.\n\n" ..
              "It does not matter if your Upper/Lower Bound selections are reversed. " ..
              "Progressive will pick the min VS max quantities selected.\n\n" ..
              "None: No monsters. Why would you choose this option? \n" ..
              "Trivial: Very, very few monsters. Almost nothing to kill.\n " ..
              "Sporadic: Very few monsters. Not many things to kill.\n " ..
              "Meager: Fewer monsters. Not challenging for the average player.\n " ..
              "Easy: Oblige default quantity. Not too bad for casual players.\n " ..
              "Modest: Slightly above default. Still pretty easy for most. \n " ..
              "Bearable: Above average opposition. Getting warmer! \n" ..
              "Rough: Slightly difficult. Equivalent to late 90s megawads. \n" ..
              "Strenuous: Baby steps into big boy difficulty. Lots to kill! \n" ..
              "Formidable/Harsh: 'Easy' level of difficult. Considerable opposition. \n" ..
              "Painful/Ferocious: Getting into slaughterwad territory. Difficult! \n" ..
              "Unforgiving/Punishing: Slaughterwad level difficulty. Skill needed. \n" ..
              "Murderous/Grueling: Extremely high monster count. \n" ..
              "Unrelenting/Arduous: An uphill battle. Expect to reload saves often! \n" ..
              "Barbaric/Savage: Up into the hardest slaughterwads out there. \n" ..
              "Brutal/Draconian: Legions of demons await you on this setting. \n" ..
              "Merciless: Hell will throw everything at you at this setting, you masochist.",
    },

    {
      name="float_mix_it_up_lower_range",
      label=_("Lower Bound"),
      valuator = "slider",
      units = "",
      min = 0,
      max = 10.00,
      increment = .05,
      default = 0,
      presets = "0:None," ..
      "0.15:0.15 (Trivial)," ..
      "0.35:0.35 (Sporadic)," ..
      "0.7:0.7 (Meager)," ..
      "1.0:1.0 (Easy)," ..
      "1.3:1.3 (Modest)," ..
      "1.5:1.5 (Bearable)," ..
      "2.0:2.0 (Rough)," ..
      "2.5:2.5 (Strenuous)," ..
      "3.0:3.0 (Formidable)," ..
      "3.5:3.5 (Harsh)," ..
      "4.0:4.0 (Painful)," ..
      "4.5:4.5 (Ferocious)," ..
      "5.0:5.0 (Unforgiving)," ..
      "5.5:5.5 (Punishing)," ..
      "6.0:6.0 (Murderous)," ..
      "6.5:6.5 (Grueling)," ..
      "7.0:7.0 (Unrelenting)," ..
      "7.5:7.5 (Arduous)," ..
      "8.0:8.0 (Barbaric)," ..
      "8.5:8.5 (Savage)," ..
      "9.0:9.0 (Brutal)," ..
      "9.5:9.5 (Draconian)," ..
      "10.0:10.00 (Merciless),",
            tooltip="If you have Mix It Up or Progressive selected, you can define the lower bound here. Otherwise, this option is simply ignored.",
            longtip="For reference: Oblige 7.x's default for normal is 1.0.\n\n" ..
              "Mix It Up: Selects quantities specified between Upper and Lower " ..
              "Bound choices on a chosen by the user.\n\n" ..
              "Progressive: creates a curve of increasing monster population " ..
              "also based on the Fine Tune options below.\n\n" ..
              "It does not matter if your Upper/Lower Bound selections are reversed. " ..
              "Progressive will pick the min VS max quantities selected.\n\n" ..
              "None: No monsters. Why would you choose this option? \n" ..
              "Trivial: Very, very few monsters. Almost nothing to kill.\n " ..
              "Sporadic: Very few monsters. Not many things to kill.\n " ..
              "Meager: Fewer monsters. Not challenging for the average player.\n " ..
              "Easy: Oblige default quantity. Not too bad for casual players.\n " ..
              "Modest: Slightly above default. Still pretty easy for most. \n " ..
              "Bearable: Above average opposition. Getting warmer! \n" ..
              "Rough: Slightly difficult. Equivalent to late 90s megawads. \n" ..
              "Strenuous: Baby steps into big boy difficulty. Lots to kill! \n" ..
              "Formidable/Harsh: 'Easy' level of difficult. Considerable opposition. \n" ..
              "Painful/Ferocious: Getting into slaughterwad territory. Difficult! \n" ..
              "Unforgiving/Punishing: Slaughterwad level difficulty. Skill needed. \n" ..
              "Murderous/Grueling: Extremely high monster count. \n" ..
              "Unrelenting/Arduous: An uphill battle. Expect to reload saves often! \n" ..
              "Barbaric/Savage: Up into the hardest slaughterwads out there. \n" ..
              "Brutal/Draconian: Legions of demons await you on this setting. \n" ..
              "Merciless: Hell will throw everything at you at this setting, you masochist.",
      gap = 1,
    },

    {
      name="float_strength",
      label=_("Strength"),
      valuator = "slider",
      units = "",
      min = 0.55,
      max = 12,
      increment = .05,
      default = 1,
      presets = "0.55:0.55 (Weak),0.75:0.75 (Easier),1:1 (Average),1.3:1.3 (Harder),1.7:1.7 (Tough),2.5:2.5 (Fierce),12:12 (CRAZY),",
    },

    {
      name="float_ramp_up",
      label=_("Ramp Up"),
      valuator = "slider",
      units = "",
      min = 0.5,
      max = 3,
      increment = .05,
      default = 1,
      nan = "Episodic,",
      presets = "0.5:0.5 (Very Slow),0.75:0.75 (Slow),1:1 (Average),1.5:1.5 (Fast),2:2 (Very Fast),3:3 (Extra Fast),",
      tooltip = "Rate at which monster strength increases as you progress through levels.",
      gap = 1,
    },

    {
      name="bool_quiet_start",
      label=_("Quiet Start"),
      valuator = "button",
      default = 0,
      tooltip="Makes start rooms mostly safe - no enemies and all outlooking windows are removed. " ..
      "(windows are retained on Procedural Gotchas) Default Oblige behavior is 'no'.",
    },

    { name="mon_variety", label=_("Monster Variety"),choices=STYLE_CHOICES,
      tooltip= "Affects how many different monster types can " ..
               "appear in each room.\n" ..
               "Setting this to NONE will make each level use a single monster type",
    },
    {
      name="mon_variety_jumpstart", label=_("Monster Variety Jumpstart"),
      choices=UI_MONS.MONSTER_KIND_JUMPSTART_CHOICES,
      default = "default",
      tooltip = "Affects how many monster variations initially appear at the very first map.",
      gap = 1
    },

    { name="bosses",    label=_("Bosses"),    choices=UI_MONS.BOSSES },
    {
      name="bossesnormal",
      label=_("Bosses As Regulars"),
      choices=UI_MONS.BOSSREGULARS,
      default="no",
      tooltip="Normally Archviles/Barons/Cyberdemons and other big monsters are excluded from normal monster pool and only can appear as guard for important objective e.g. key. With this option enabled they are allowed to(rarely) spawn as a regular monster. \n\n WARNING: This CAN make maps much more difficult than normal.",
      gap = 1
    },
    { name="traps",     label=_("Traps"),     choices=STYLE_CHOICES },
    {
      name="trap_style",
      label=_("Trap Style"),
      choices=UI_MONS.TRAP_STYLE,
      default="default",
      tooltip="This option selects between using only teleport or closet traps. DEFAULT means both are used.",
    },
    {
      name="trap_qty",
      label=_("Trap Monsters"),
      choices=UI_MONS.CAGE_STRENGTH,
      default="default",
      tooltip="Changes the quantity of ambushing monsters from traps.",
      gap = 1,
    },

    { name="cages",     label=_("Cages"),     choices=STYLE_CHOICES },

    {
      name="cage_qty",
      label=_("Cage Monsters"),
      choices=UI_MONS.CAGE_STRENGTH,
      default="default",
      tooltip="Changes the quantity of monsters in cages.",
      gap=1,
    },

    {
      name="secret_monsters",
      label=_("Monsters in Secrets"),
      choices=UI_MONS.SECRET_MONSTERS,
      tooltip="I'm in your secret rooms, placing some monsters. Note: default is none.",
      default="no",
    },

  },
}
