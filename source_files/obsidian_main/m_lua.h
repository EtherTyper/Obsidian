//------------------------------------------------------------------------
//  LUA interface
//------------------------------------------------------------------------
//
//  Oblige Level Maker
//
//  Copyright (C) 2006-2009 Andrew Apted
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//------------------------------------------------------------------------

#ifndef __SCRIPTING_HEADER__
#define __SCRIPTING_HEADER__

#include <string>
#include <vector>

#include "../lua/lua.hpp"
#include "sys_type.h"

typedef struct lua_State lua_State;

void Script_Open();
void Script_Close();

#define MAX_COLOR_MAPS 9  // 1 to 9 (from Lua)
#define MAX_COLORS_PER_MAP 260

typedef struct {
    byte colors[MAX_COLORS_PER_MAP];
    int size;
} color_mapping_t;

extern color_mapping_t color_mappings[MAX_COLOR_MAPS];

// Wrappers which call Lua functions:

bool ob_set_config(std::string_view key, std::string_view value);
bool ob_set_mod_option(std::string module, std::string option,
                       std::string value);

bool ob_read_all_config(std::vector<std::string> *lines, bool need_full);

std::string ob_get_param(std::string parameter);
void ob_invoke_hook(std::string hookname);

std::string ob_game_format();
std::string ob_default_filename();

bool ob_build_cool_shit();

#endif /* __SCRIPTING_HEADER__ */

//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
