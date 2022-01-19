//------------------------------------------------------------------------
//  ARCHIVE Handling - WAD files
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

#ifndef LIB_WAD_H_
#define LIB_WAD_H_

/* WAD reading */

#include <filesystem>
#include <string_view>
#include "sys_type.h"

bool WAD_OpenRead(std::filesystem::path filename);
void WAD_CloseRead();

int WAD_NumEntries();
int WAD_FindEntry(const char *name);
int WAD_EntryLen(int entry);
const char *WAD_EntryName(int entry);

bool WAD_ReadData(int entry, int offset, int length, void *buffer);

void WAD_ListEntries();

/* WAD writing */

bool WAD_OpenWrite(std::filesystem::path filename);
void WAD_CloseWrite();

void WAD_NewLump(std::string_view name);
bool WAD_AppendData(const void *data, int length);
void WAD_FinishLump();

/* WAD2 reading */

bool WAD2_OpenRead(const char *filename);
void WAD2_CloseRead();

int WAD2_NumEntries();
int WAD2_FindEntry(const char *name);
int WAD2_EntryLen(int entry);
int WAD2_EntryType(int entry);
const char *WAD2_EntryName(int entry);

bool WAD2_ReadData(int entry, int offset, int length, void *buffer);

void WAD2_ListEntries();

/* WAD2 writing */

bool WAD2_OpenWrite(const char *filename);
void WAD2_CloseWrite();

void WAD2_NewLump(const char *name, int type = 0);
bool WAD2_AppendData(const void *data, int length);
void WAD2_FinishLump();

/* ----- WAD structure (Doom) ---------------------- */

#pragma pack(push, 1)
struct raw_wad_header_t {
    char magic[4];

    u32_t num_lumps;
    u32_t dir_start;
};
#pragma pack(pop)

#pragma pack(push, 1)
struct raw_wad_lump_t {
    u32_t start;
    u32_t length;

    char name[8];
};
#pragma pack(pop)

/* ----- WAD2 structures (Quake) ---------------------- */

#pragma pack(push, 1)
struct raw_wad2_header_t {
    char magic[4];

    u32_t num_lumps;
    u32_t dir_start;
};
#pragma pack(pop)

constexpr const char *WAD2_MAGIC = "WAD2";

#pragma pack(push, 1)
struct raw_wad2_lump_t {
    u32_t start;
    u32_t length;  // compressed
    u32_t u_len;   // uncompressed

    u8_t type;
    u8_t compression;
    u8_t _pad[2];

    char name[16];  // must be null terminated
};
#pragma pack(pop)

// compression method (from Quake1 source)
enum {
    CMP_NONE,
    CMP_LZSS,
};

// lump types (from Quake1 source)
enum {
    TYP_NONE,
    TYP_LABEL,
    TYP_PALETTE = 64,
    TYP_QTEX,
    TYP_QPIC,
    TYP_SOUND,
    TYP_MIPTEX,
    // this value is only returned from WAD2_EntryType()
    TYP_COMPRESSED = 256,
};

#endif

//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
