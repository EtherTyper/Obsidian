//------------------------------------------------------------------------
//  Debugging support
//------------------------------------------------------------------------
//
//  Oblige Level Maker
//
//  Copyright (C) 2006-2017 Andrew Apted
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

#include <fstream>
#include <iostream>
#include "headers.h"
#include "lib_util.h"
#include "main.h"

#define DEBUG_BUF_LEN 20000

std::fstream log_file;
static std::filesystem::path log_filename;

bool debugging = false;
bool terminal = false;

bool LogInit(const std::filesystem::path &filename) {
    if (!filename.empty()) {
        log_filename = filename;

        log_file.open(log_filename, std::ios::out);

        if (!log_file.is_open()) {
            return false;
        }
    }

    LogPrintf("====== START OF OBSIDIAN LOGS ======\n");

    return true;
}

void LogEnableDebug(bool enable) {
    if (debugging == enable) {
        return;
    }

    debugging = enable;

    if (debugging) {
        LogPrintf("===  DEBUGGING ENABLED  ===\n\n");
    } else {
        LogPrintf("===  DEBUGGING DISABLED  ===\n\n");
    }
}

void LogEnableTerminal(bool enable) { terminal = enable; }

void LogClose(void) {
    LogPrintf("\n====== END OF OBSIDIAN LOGS ======\n\n");

    log_file.close();
    log_filename.clear();
}

void LogReadLines(log_display_func_t display_func, void *priv_data) {
    if (!log_file) {
        return;
    }

    // we close the log file so we can read it, and then open it
    // again when finished.  That is because Windows OSes can be
    // fussy about opening already open files (in Linux it would
    // not be an issue).

    log_file.close();

    log_file.open(log_filename, std::ios::in);

    // this is very unlikely to happen, but check anyway
    if (!log_file.is_open()) {
        return;
    }

    std::string buffer;
    while (std::getline(log_file, buffer)) {
        // remove any newline at the end (LF or CR/LF)
        StringRemoveCRLF(&buffer);

        // remove any DEL characters (mainly to workaround an FLTK bug)
        StringReplaceChar(&buffer, 0x7f, 0);

        std::cout << buffer << std::endl;

        display_func(buffer, priv_data);
    }

    // close the log file after current contents are read
    log_file.close();

    // open the log file for writing again
    // [ it is unlikely to fail, but if it does then no biggie ]
    log_file.open(log_filename, std::ios::app);
}

//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
