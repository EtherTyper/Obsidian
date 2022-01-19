//------------------------------------------------------------------------
//
//  AJ-Polygonator (C) 2000-2013 Andrew Apted
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//------------------------------------------------------------------------

#ifndef __AJPOLY_UTIL_H__
#define __AJPOLY_UTIL_H__

/* ----- FUNCTIONS ---------------------------------- */

// set message for certain errors
void SetErrorMsg(const char *str, ...);

// compute angle for a 2D vector
double ComputeAngle(double dx, double dy);

#endif /* __AJPOLY_UTIL_H__ */

//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
