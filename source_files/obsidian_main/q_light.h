//------------------------------------------------------------------------
//  QUAKE 1/2/3 LIGHTING
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

#ifndef Q_LIGHT_H_
#define Q_LIGHT_H_

#include <vector>
#include <array>

#include "lib_tga.h"  // for rgb_color_t
#include "q_common.h"
#include "sys_type.h"

class quake_face_c;
class uv_matrix_c;

// the maximum size of a face's lightmap in Quake I/II
constexpr int FLAT_LIGHTMAP_SIZE = 17 * 17;

class qLightmap_c {
   public:
    int width, height;
    int num_styles;

    rgb_color_t *samples;
    rgb_color_t *current_pos;

    // Q1 and Q2 only
    std::array<byte, 4> styles;

    // final offset in lightmap lump (if not flat)
    // for Q3 this is the block number
    int offset;

    // for Q3, position in light block
    int lx, ly;

    // for Q3, the matrix for computing coords
    uv_matrix_c *lm_mat;

   public:
    qLightmap_c(int w, int h, int value = -1);

    ~qLightmap_c();

    void Fill(rgb_color_t value);

    inline rgb_color_t &At(int s, int t) { return current_pos[t * width + s]; }

    bool hasStyle(byte style) const;

    // returns false if too many styles
    bool AddStyle(byte style);

    rgb_color_t CalcAverage() const;

    // true if all samples are zero
    bool isDark() const;

    // transfer from blocklights[] array
    void Store();

    void Write(qLump_c *lump);
};

enum quake_light_kind_e {
    LTK_Normal = 0,
    LTK_Sun,
};

struct quake_light_t {
    int kind;

    float x, y, z;
    float radius;
    float level;  // brightest level (at dist = 0)

    rgb_color_t color;
    int style;
};

// on-disk structure for Q3 light grid
#pragma pack(push, 1)
struct dlightgrid3_t {
    std::array<byte, 3> ambientLight;
    std::array<byte, 3> directedLight;
    byte lat, lng;  // direction to light (angles)
};
#pragma pack(pop)

/***** VARIABLES **********/

extern std::vector<quake_light_t> qk_all_lights;

extern bool q_mono_lighting;

/***** FUNCTIONS **********/

rgb_color_t QLIT_ParseColorString(std::string name);

void QLIT_InitProperties();
bool QLIT_ParseProperty(std::string key, std::string value);

void QLIT_FreeLightmaps();

void QLIT_BuildLightingLump(int lump, int max_size);
void QLIT_BuildQ3Lighting(int lump, int max_size);

void QLIT_LightAllFaces();

#endif

//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
