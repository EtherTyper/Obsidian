//------------------------------------------------------------------------
//  Main defines
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

#ifndef __OBLIGE_MAIN_H__
#define __OBLIGE_MAIN_H__

#include <locale.h>

namespace std {
inline const char *setlocale(int a, const char* b) {
return ::setlocale(a, b);
}
}

#include <cstddef>
#include <fmt/format.h>
#include <fmt/ostream.h>
#include <iostream>
#include <vector>
#include <string>
#include <map>
#include <filesystem>
#include "hdr_fltk.h"
#include "ui_window.h"
#include "defines.h"
constexpr const char *OBSIDIAN_TITLE = "OBSIDIAN Level Maker";

constexpr const char *OBSIDIAN_VERSION = "Beta 20 Preview";
constexpr const char *OBSIDIAN_SHORT_VERSION = "Beta20";
constexpr unsigned int OBSIDIAN_HEX_VER = 0x014;
constexpr const char *OBSIDIAN_WEBSITE =
    "https://github.com/dashodanger/Obsidian/wiki";

constexpr const char *CONFIG_FILENAME = "CONFIG.txt";
constexpr const char *OPTIONS_FILENAME = "OPTIONS.txt";
constexpr const char *THEME_FILENAME = "THEME.txt";
constexpr const char *LOG_FILENAME = "LOGS.txt";

#ifdef _WIN32
ALWAYS_INLINE
inline int i_load_private_font(const char *path) {
    return AddFontResourceEx(path, FR_PRIVATE, nullptr);
}
ALWAYS_INLINE
inline int v_unload_private_font(const char *path) {
    return RemoveFontResourceEx(path, FR_PRIVATE, nullptr);
}
#else
#include <fontconfig/fontconfig.h>
ALWAYS_INLINE
inline int i_load_private_font(const char *path) {
    return static_cast<int>(FcConfigAppFontAddFile(
        nullptr, reinterpret_cast<const FcChar8 *>(path)));
}
ALWAYS_INLINE
inline int v_unload_private_font(const char *path) {
    FcConfigAppFontClear(nullptr);
    return 0;
}
#endif

extern std::filesystem::path home_dir;
extern std::filesystem::path install_dir;

extern std::filesystem::path options_file;
extern std::filesystem::path theme_file;
extern std::filesystem::path logging_file;

extern bool batch_mode;

extern std::filesystem::path batch_output_file;

extern unsigned long long next_rand_seed;

// this records the user action, e.g. Cancel or Quit buttons
enum main_action_kind_e {
    MAIN_NONE = 0,
    MAIN_BUILD,
    MAIN_CANCEL,
    MAIN_QUIT,
    MAIN_RESTART
};

extern int main_action;

// Misc Options
extern uchar text_red;
extern uchar text_green;
extern uchar text_blue;
extern uchar text2_red;
extern uchar text2_green;
extern uchar text2_blue;
extern uchar bg_red;
extern uchar bg_green;
extern uchar bg_blue;
extern uchar bg2_red;
extern uchar bg2_green;
extern uchar bg2_blue;
extern uchar button_red;
extern uchar button_green;
extern uchar button_blue;
extern uchar gradient_red;
extern uchar gradient_green;
extern uchar gradient_blue;
extern uchar border_red;
extern uchar border_green;
extern uchar border_blue;
extern uchar gap_red;
extern uchar gap_green;
extern uchar gap_blue;
extern Fl_Boxtype box_style;
extern Fl_Boxtype button_style;
extern Fl_Font font_style;
extern Fl_Color FONT_COLOR;
extern Fl_Color FONT2_COLOR;
extern Fl_Color WINDOW_BG;
extern Fl_Color SELECTION;
extern Fl_Color GAP_COLOR;
extern Fl_Color GRADIENT_COLOR;
extern Fl_Color BUTTON_COLOR;
extern Fl_Color BORDER_COLOR;
extern int color_scheme;
extern int font_theme;
extern int box_theme;
extern int button_theme;
extern int widget_theme;
extern int window_scaling;
extern int font_scaling;
extern int num_fonts;
extern int filename_prefix;
extern std::string custom_prefix;
extern bool single_pane;
extern bool use_system_fonts;
extern std::vector<std::map<std::string, int>> font_menu_items;

extern bool create_backups;
extern bool overwrite_warning;
extern bool debug_messages;
extern bool limit_break;
extern bool preserve_failures;
extern bool preserve_old_config;
extern bool did_randomize;
extern bool randomize_architecture;
extern bool randomize_monsters;
extern bool randomize_pickups;
extern bool randomize_misc;
extern int zip_output;

extern std::string def_filename;

extern std::filesystem::path last_directory;
extern std::string numeric_locale;
extern std::vector<std::string> batch_randomize_groups;

// Dialog Windows
void DLG_ShowError(const char *msg, ...);

std::filesystem::path DLG_OutputFilename(const char *ext,
                                         const char *preset = nullptr);

extern std::filesystem::path gif_filename;

void DLG_AboutText();
void DLG_OptionsEditor();
void DLG_ThemeEditor();
void DLG_SelectAddons();

void DLG_EditSeed();
void DLG_ViewLogs();
void DLG_ManageConfig();

namespace Main {

namespace Detail {
void Shutdown(bool error);
}

template <typename... Args>
[[noreturn]] void FatalError(std::string_view msg, Args &&...args) {
    auto buffer = fmt::format(msg, std::forward<Args>(args)...);
    DLG_ShowError("%s", buffer.c_str());
    Detail::Shutdown(true);

    if (batch_mode) {
        fmt::print(std::cerr, "ERROR!\n");
    }

    std::exit(9);
}

template <typename... Args>
void ProgStatus(std::string_view msg, Args &&...args) {
    const auto buffer = fmt::format(msg, std::forward<Args>(args)...);

    if (main_win) {
        main_win->build_box->SetStatus(buffer);
    } else if (batch_mode) {
        fmt::print(std::cerr, "{}\n", buffer);
    }
}
bool BackupFile(const std::filesystem::path &filename,
                const std::filesystem::path &ext);
#ifdef WIN32
void Blinker();
#endif
void Ticker();
bool LoadInternalFont(const char *fontpath, int fontnum, const char *fontname);
void PopulateFontMap();

}  // namespace Main

class game_interface_c {
    /* this is an abstract base class */

   public:
    game_interface_c() = default;

    virtual ~game_interface_c() = default;
    game_interface_c(const game_interface_c &) = default;
    game_interface_c &operator=(const game_interface_c &) = default;
    game_interface_c(game_interface_c &&) = default;
    game_interface_c &operator=(game_interface_c &&) = default;

    /*** MAIN ***/

    // this selects an output filename or directory and prepares
    // for building a set of levels.  Returns false if an error
    // occurs (or the user simply Cancel'd).
    //
    // when 'preset' parameter is not NULL, it is a filename to
    // use in the save dialog.
    virtual bool Start(const char *preset) = 0;

    // this is called after all levels are done.  The 'build_ok'
    // value is the result from the LUA script, and is false if
    // an error occurred or the user clicked Abort.
    //
    // For DOOM this will run glBSP node builder, for QUAKE it will
    // put all the BSP files into the final PAK file.
    //
    // Returns false on error.  Note that Finish() is never
    // called if Start() fails.
    virtual bool Finish(bool build_ok) = 0;

    /*** CSG2 ***/

    // this will set things up in preparation for the next level
    // being built.  It is called after the CSG2 code sets itself
    // up and hence could alter some CSG2 parameters, other than
    // that there is lttle need to do anything here.
    virtual void BeginLevel() = 0;

    // called when all the brushes and entities have been added
    // but before the CSG2 performs a cleanup.  Typically the
    // game-specific code will call CSG_BSP() and convert
    // the result to the game-specific level format.
    virtual void EndLevel() = 0;

    // sets a certain property, especially "level_name" which is
    // required by most games (like DOOM and QUAKE).  Unknown
    // properties are ignored.  May be called during startup too.
    virtual void Property(std::string key, std::string value) = 0;
};

extern game_interface_c *game_object;

/* interface for each game format */

game_interface_c *Doom_GameObject();
game_interface_c *Nukem_GameObject();
game_interface_c *Quake1_GameObject();
game_interface_c *Quake2_GameObject();
game_interface_c *Quake3_GameObject();

#endif /* __OBLIGE_MAIN_H__ */

//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
