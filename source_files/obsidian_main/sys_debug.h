//------------------------------------------------------------------------
//  Debugging support
//------------------------------------------------------------------------
//
//  Oblige Level Maker
//
//  Copyright (C) 2006-2016 Andrew Apted
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

#ifndef __SYS_DEBUG_H__
#define __SYS_DEBUG_H__

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <string>
#include <fmt/core.h>
#include <fmt/ostream.h>
extern bool terminal;
extern bool debugging;
extern std::fstream log_file;
bool LogInit(const std::filesystem::path &filename);  // NULL for none
void LogClose(void);

void LogEnableDebug(bool enable);
void LogEnableTerminal(bool enable);

template <typename... Args>
void LogPrintf(std::string_view str, Args &&...args) {
    fmt::print(log_file, str, args...);

    // show on the Linux terminal too
    if (terminal) {
        fmt::print(str, args...);
    }
}
template <typename... Args>
void DebugPrintf(std::string_view format, Args &&...args) {
    if (debugging) {
        std::string buffer = fmt::format(format, args...);
        auto next = std::find(buffer.begin(), buffer.end(), '\n');
        for (auto pos = buffer.begin(); pos != buffer.end();) {
            LogPrintf("{}", std::string{pos, next});
            pos = next;
            next = std::find(pos + 1, buffer.end(), '\n');
        }
    }
}

using log_display_func_t = void (*)(std::string_view line, void *priv_data);

void LogReadLines(log_display_func_t display_func, void *priv_data);

#endif /* __SYS_DEBUG_H__ */

//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
