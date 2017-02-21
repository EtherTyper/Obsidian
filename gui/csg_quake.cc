//------------------------------------------------------------------------
//  CSG : QUAKE I, II and III
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

#include "headers.h"

#include <algorithm>

#include "hdr_fltk.h"
#include "hdr_lua.h"
#include "hdr_ui.h"

#include "lib_file.h"
#include "lib_util.h"

#include "main.h"
#include "m_lua.h"

#include "q_common.h"
#include "q_light.h"
#include "q_vis.h"

#include "csg_main.h"
#include "csg_local.h"
#include "csg_quake.h"


#define FACE_MAX_SIZE  (qk_game < 3 ? 240 : 768)

#define NODE_DEBUG  0


//------------------------------------------------------------------------
//  NEW LOGIC
//------------------------------------------------------------------------

quake_node_c * qk_bsp_root;
quake_leaf_c * qk_solid_leaf;

std::vector<quake_face_c *>     qk_all_faces;
std::vector<quake_mapmodel_c *> qk_all_mapmodels;


class quake_side_c
{
public:
	snag_c *snag;

	quake_node_c * on_node;

	int node_side;  // 0 = front, 1 = back

	double x1, y1;
	double x2, y2;

public:
	// this is only for partitions
	quake_side_c() : snag(NULL), on_node(NULL), node_side(-1)
	{ }

	quake_side_c(snag_c *S) :
		snag(S), on_node(NULL), node_side(-1),
		x1(S->x1), y1(S->y1), x2(S->x2), y2(S->y2)
	{ }

	quake_side_c(const quake_side_c *other) :
		snag(other->snag), on_node(other->on_node), node_side(other->node_side),
		x1(other->x1), y1(other->y1), x2(other->x2), y2(other->y2)
	{ }

	// make a "mini side"
	quake_side_c(quake_node_c *node, int _node_side,
			     const quake_side_c *part,
			     double along1, double along2) :
	  snag(NULL), on_node(node), node_side(_node_side)
	{
		double sx, sy;
		double ex, ey;

		AlongCoord(along1, part->x1,part->y1, part->x2,part->y2, &sx, &sy);
		AlongCoord(along2, part->x1,part->y1, part->x2,part->y2, &ex, &ey);

		x1 = sx; y1 = sy;
		x2 = ex; y2 = ey;
	}

	~quake_side_c()
	{ }

public:
	double Length() const
	{
		return ComputeDist(x1,y1, x2,y2);
	}

	bool TwoSided() const
	{
		if (! snag->partner)
			return false;

		if (! snag->partner->region)
			return false;

		if (snag->partner->region->gaps.empty())
			return false;

		return true;
	}

	void ToPlane(quake_plane_c *plane)
	{
		plane->x = x1;
		plane->y = y1;
		plane->z = 0;

		plane->nx = (y2 - y1);
		plane->ny = (x1 - x2);
		plane->nz = 0;

		plane->Normalize();
	}

	void Dump(unsigned int index) const
	{
		DebugPrintf("Side %u : (%1.1f %1.1f) -> (%1.1f %1.1f) snag:%p  on_node:%p/%d\n",
				index, x1, y1, x2, y2, snag, on_node, node_side);
	}
};


class quake_group_c
{
public:
	std::vector<quake_side_c *> sides;

	std::vector<csg_brush_c *> brushes;

public:
	quake_group_c() : sides(), brushes()
	{ }

	~quake_group_c()
	{ }

	void AddSide(quake_side_c *S)
	{
		sides.push_back(S);
	}

	void AddBrush(csg_brush_c *B)
	{
		brushes.push_back(B);
	}

	bool IsEmpty() const
	{
		return sides.empty();
	}

	void CalcMid(double *mid_x, double *mid_y) const
	{
		SYS_ASSERT(! IsEmpty());

		*mid_x = 0;
		*mid_y = 0;

		for (unsigned int i = 0 ; i < sides.size() ; i++)
		{
			*mid_x += sides[i]->x1;
			*mid_y += sides[i]->y1;
		}

		*mid_x /= (double)sides.size();
		*mid_y /= (double)sides.size();
	}

	void GetGroupBounds(double *min_x, double *min_y,
			double *max_x, double *max_y) const
	{
		*min_x = +9e9;  *max_x = -9e9;
		*min_y = +9e9;  *max_y = -9e9;

		for (unsigned int i = 0 ; i < sides.size() ; i++)
		{
			const quake_side_c *S = sides[i];

			double x1 = MIN(S->x1, S->x2);
			double y1 = MIN(S->y1, S->y2);
			double x2 = MAX(S->x1, S->x2);
			double y2 = MAX(S->y1, S->y2);

			*min_x = MIN(*min_x, x1);
			*min_y = MIN(*min_y, y1);
			*max_x = MAX(*max_x, x2);
			*max_y = MAX(*max_y, y2);
		}
	}

	region_c * FinalRegion()
	{
		// determine region when we reach a 2D leaf
		// (result is not valid any other time)

		for (unsigned int i = 0 ; i < sides.size() ; i++)
		{
			quake_side_c *S = sides[i];

			if (S->snag && S->snag->region)
				return S->snag->region;
		}

		// failed to find one, because all the sides were "mini sides".
		// to handle this we perform a point-to-region lookup, which is
		// currently very slow, so hopefully this occurs rarely.

		double mid_x, mid_y;

		CalcMid(&mid_x, &mid_y);

		return CSG_PointInRegion(mid_x, mid_y);
	}

	void Dump() const
	{
		DebugPrintf("Group %p : %u sides, %u brushes\n", this,
				sides.size(), brushes.size());

		for (unsigned int i = 0 ; i < sides.size() ; i++)
		{
			const quake_side_c *S = sides[i];

			S->Dump(i);
		}
	}
};


void quake_plane_c::SetPos(double ax, double ay, double az)
{
	x = ax;
	y = ay;
	z = az;
}


double quake_plane_c::CalcDist() const
{
	return (x * (double)nx) + (y * (double)ny) + (z * (double)nz);
}


void quake_plane_c::Flip()
{
	nx = -nx;
	ny = -ny;
	nz = -nz;
}


void quake_plane_c::Normalize()
{
	double len = sqrt(nx*nx + ny*ny + nz*nz);

	if (len > 0.000001)
	{
		nx /= len;
		ny /= len;
		nz /= len;
	}
}


float quake_plane_c::PointDist(float ax, float ay, float az) const
{
	return (ax - x) * nx + (ay - y) * ny + (az - z) * nz;
}


int quake_plane_c::BrushSide(csg_brush_c *B, float epsilon) const
{
	float min_d = +9e9;
	float max_d = -9e9;

	for (unsigned int i = 0 ; i < B->verts.size() ; i++)
	{
		brush_vert_c *V = B->verts[i];

		for (unsigned int k = 0 ; k < 2 ; k++)
		{
			// TODO : compute proper z coord
			// [ though unlikely to make much difference, due to the
			//   2D-ish nature of our BSP tree... ]

			float x = V->x;
			float y = V->y;
			float z = k ? B->b.z : B->t.z;

			float d = PointDist(x, y, z);

			min_d = MIN(min_d, d);
			max_d = MAX(max_d, d);
		}
	}

	if (min_d > -epsilon) return +1;
	if (max_d <  epsilon) return -1;

	return 0;
}


double quake_plane_c::CalcZ(double ax, double ay) const
{
	if (fabs(nz) < 0.01)
		return 0;

	if (fabs(nz) > 0.999)
		return z;

	// solve the plane equation:
	//    nx*(ax-x) + ny*(ay-y) + nz*(az-z) = 0

	double tx = (double)nx * (ax - (double)x);
	double ty = (double)ny * (ay - (double)y);

	double dz = (tx + ty) / (double)nz;

	return (double)z - dz;
}


void quake_leaf_c::AddFace(quake_face_c *F)
{
	F->leaf = this;

	faces.push_back(F);
}


void quake_leaf_c::AddSolid(csg_brush_c *B)
{
	solids.push_back(B);
}


quake_node_c::quake_node_c() :
	front_N(NULL), front_L(NULL),
	back_N(NULL),  back_L(NULL),
	faces(), index(-1)
{ }

quake_node_c::quake_node_c(const quake_plane_c& P) :
	plane(P),
	front_N(NULL), front_L(NULL),
	 back_N(NULL),  back_L(NULL),
	faces(), index(-1)
{ }


quake_node_c::~quake_node_c()
{
	// free child leafs
	if (front_L && front_L != qk_solid_leaf) delete front_L;
	if ( back_L &&  back_L != qk_solid_leaf) delete  back_L;

	// free child nodes
	if (front_N) delete front_N;
	if ( back_N) delete  back_N;
}


void quake_node_c::AddFace(quake_face_c *F)
{
	F->node = this;

	faces.push_back(F);
}


int quake_node_c::CountNodes() const
{
	int count = 1;

	if (front_N) count += front_N->CountNodes();
	if ( back_N) count +=  back_N->CountNodes();

	return count;
}


int quake_node_c::CountLeafs() const
{
	int count = 0;

	if (front_N)
		count += front_N->CountLeafs();
	else if (front_L != qk_solid_leaf)
		count += 1;

	if (back_N)
		count += back_N->CountLeafs();
	else if (back_L != qk_solid_leaf)
		count += 1;

	return count;
}


quake_mapmodel_c::quake_mapmodel_c() :
	x1(0), y1(0), z1(0),
	x2(0), y2(0), z2(0),
	x_face(), y_face(), z_face(),
	firstface(0), numfaces(0), numleafs(0),
	firstBrush(0), numBrushes(0),
	light(64)
{
	for (int i = 0 ; i < 6 ; i++)
		nodes[i] = 0;
}


quake_mapmodel_c::~quake_mapmodel_c()
{ }


static void CreateSides(quake_group_c & group)
{
	for (unsigned int i = 0 ; i < all_regions.size() ; i++)
	{
		region_c *R = all_regions[i];

		if (R->gaps.empty())
			continue;

		for (unsigned int k = 0 ; k < R->snags.size() ; k++)
		{
			snag_c *snag = R->snags[k];

			region_c *N = snag->partner ? snag->partner->region : NULL;

			if (N && R->HasSameBrushes(N))
				continue;

			quake_side_c *S = new quake_side_c(snag);

			group.AddSide(S);
#if 0
			fprintf(stderr, "New Side: %p %s (%1.0f %1.0f) .. (%1.0f %1.0f)\n",
					S, S->TwoSided() ? "2S" : "1S",
					S->x1, S->y1, S->x2, S->y2);
#endif
		}
	}
}


static void CreateBrushes(quake_group_c & group)
{
	for (unsigned int i = 0 ; i < all_regions.size() ; i++)
	{
		region_c *R = all_regions[i];

		for (unsigned int k = 0 ; k < R->brushes.size() ; k++)
		{
			csg_brush_c *B = R->brushes[k];

			if (B->bflags & BRU_IF_Seen)
				continue;

			if (B->bkind == BKIND_Solid || B->bkind == BKIND_Sky)
			{
				group.AddBrush(R->brushes[k]);

				B->bflags |= BRU_IF_Seen;
			}
		}
	}
}


// an "intersection" remembers the vertex that touches a BSP divider
// line (including a new vertex that is created at a seg split).

#define K1_NORMAL   4
#define K1_SITTING  5

// these bitflags are used after MergeIntersections()
#define K2F_OPEN_FORWARD   1
#define K2F_OPEN_BACKWARD  2

typedef struct
{
	// how far along the partition line the vertex is.
	// bigger value are further along the partition line.
	double along;

	// quantized along value
	int q_dist;

	// before merging, this is either K1_NORMAL or K1_SITTING.
	// after merging, this is a bitflag using K2F_XXX values.
	int kind;

	// for K1_NORMAL  : this is direction toward OPEN space
	// for K1_SITTING : this is direction away from touching point
	// values can be: +1 = forward along partition, -1 = backwards.
	int dir;

	// this is the angle between the seg and the partition
	// it ranges between (0..180) or (-0..-180) exclusive
	double angle;
}
intersect_t;


struct intersect_qdist_Cmp
{
	inline bool operator() (const intersect_t& A, const intersect_t& B) const
	{
		return A.q_dist < B.q_dist;
	}
};


void DumpIntersections(std::vector<intersect_t> & cuts, const char *title)
{
	DebugPrintf("%s:\n", title);

	for (unsigned int i = 0 ; i < cuts.size() ; i++)
	{
		DebugPrintf("  %03d : along:%1.3f dir:%+d %s angle:%1.2f\n", i,
					cuts[i].along, cuts[i].dir,
					(cuts[i].kind == K1_NORMAL) ? "NORM" :
					(cuts[i].kind == K1_SITTING) ? "SITT" :
					(cuts[i].kind == 0) ? "C==C" :
					(cuts[i].kind == K2F_OPEN_FORWARD)  ? "C->O" :
					(cuts[i].kind == K2F_OPEN_BACKWARD) ? "O<-C" :
					(cuts[i].kind == 3) ? "O--O" : "???",
					cuts[i].angle);
	}
}


static void AddIntersection(std::vector<intersect_t> & cut_list,
                            double along, int dir, int kind, double angle)
{
	intersect_t new_cut;

	new_cut.along  = along;
	new_cut.q_dist = I_ROUND(along * 21.6f);

	new_cut.dir   = dir;
	new_cut.kind  = kind;
	new_cut.angle = angle;

	cut_list.push_back(new_cut);
}


// vert: 0 if the start touches partition
//       1 if the end touches partition
static void AddIntersection(std::vector<intersect_t> & cut_list,
                            const quake_side_c *part, const quake_side_c *S,
                            int vert, int dir, int kind)
{
	double along;

	if (vert == 0)
		along = AlongDist(S->x1, S->y1, part->x1, part->y1, part->x2, part->y2);
	else
		along = AlongDist(S->x2, S->y2, part->x1, part->y1, part->x2, part->y2);

	// compute the angle between the two vectors
	double s_angle = 0;
	double p_angle;

	if (kind != K1_SITTING)
	{
		if (vert == 0)
			s_angle = CalcAngle(S->x1, S->y1, S->x2, S->y2);
		else
			s_angle = CalcAngle(S->x2, S->y2, S->x1, S->y1);

		p_angle = CalcAngle(part->x1, part->y1, part->x2, part->y2);

		// DebugPrintf("\nPART = (%1.0f %1.0f) .. (%1.0f %1.0f) along:%1.0f  raw_angle: %1.1f\n", part->x1, part->y1, part->x2, part->y2, along, p_angle);
		// DebugPrintf("SEG = (%1.0f %1.0f) .. (%1.0f %1.0f) vert:%d dir:%+d raw_angle: %1.1f\n", S->x1, S->y1, S->x2, S->y2, vert, dir, s_angle);

		s_angle = s_angle - p_angle;

		if (s_angle > 180.0)
			s_angle -= 360.0;
		else if (s_angle < -180.0)
			s_angle += 360.0;

		// DebugPrintf("angle_diff ---> %1.2f\n", s_angle);
	}

	AddIntersection(cut_list, along, dir, kind, s_angle);
}


static bool TestIntersectionOpen(std::vector<intersect_t> & cuts,
                                 unsigned int first, unsigned int last, int dir)
{
	unsigned int i;

	const double ANG_EPSILON = 1e-5;

	// if have sitting with same dir : not open
	for (i = first ; i <= last ; i++)
		if (cuts[i].kind == K1_SITTING && cuts[i].dir == dir)
			return false;

	// find intersection with closest angle along dir
	unsigned int closest = -1;
	double cl_angle = 999.0;

	for (i = first ; i <= last ; i++)
	{
		if (cuts[i].kind == K1_SITTING)
			continue;

		double angle = cuts[i].angle;

		// angles are relative to forward direction on partition,
		// so adjust them for the backward direction.
		if (dir < 0)
		{
			if (angle < 0)
				angle = -180 - angle;
			else
				angle = 180 - angle;
		}

		if (fabs(angle) + ANG_EPSILON < fabs(cl_angle))
		{
			closest  = i;
			cl_angle = angle;
		}

		// it is normal for two segs to touch at a partition at the same
		// place but facing opposite directions.  The _vital_ thing here
		// is to pick the OPEN one.
		else if (fabs(angle - cl_angle) < ANG_EPSILON && cuts[i].dir == dir)
		{
			closest = i;
		}
	}

	// none?? (should not happen)
	if (closest < 0)
		return false;

	// check if closest seg is open towards given dir

	return cuts[closest].dir == dir;
}


static void MergeIntersections(std::vector<intersect_t> & cuts,
                               std::vector<intersect_t> & merged)
{
	unsigned int i = 0;

	while (i < cuts.size())
	{
		unsigned int first = i;
		unsigned int last  = first;

		while (last+1 < cuts.size() && cuts[last+1].q_dist == cuts[first].q_dist)
			last++;

		/// LogPrintf("DIST %1.0f [%d..%d]\n", cuts[first].along, first, last);

		bool backward = TestIntersectionOpen(cuts, first, last, -1);
		bool forward  = TestIntersectionOpen(cuts, first, last, +1);

		/// LogPrintf("--> backward:%s forward:%s\n",
		///          backward ? "OPEN" : "closed",
		///           forward ? "OPEN" : "closed");

		intersect_t new_cut;

		new_cut.along = cuts[first].along;
		new_cut.kind  = (backward ? K2F_OPEN_BACKWARD : 0) |
			( forward ? K2F_OPEN_FORWARD  : 0);
		new_cut.dir   = 0;
		new_cut.angle = 0;

		merged.push_back(new_cut);

		// move pointer to next group
		i = last + 1;
	}
}


static void CreateMiniSides(std::vector<intersect_t> & cuts,
                            quake_node_c *node,
                            const quake_side_c *part,
                            quake_group_c & front, quake_group_c & back)
{
	std::sort(cuts.begin(), cuts.end(), intersect_qdist_Cmp());

	///   DumpIntersections(cuts, "Intersection List");

	std::vector<intersect_t> merged;

	MergeIntersections(cuts, merged);

	///   DumpIntersections(merged, "Merged List");

	for (unsigned int i = 0 ; i+1 < merged.size() ; i++)
	{
		if ((merged[i  ].kind & K2F_OPEN_FORWARD) &&
				(merged[i+1].kind & K2F_OPEN_BACKWARD))
		{
			double along1 = merged[i  ].along;
			double along2 = merged[i+1].along;

			SYS_ASSERT(along1 < along2);

			quake_side_c *F = new quake_side_c(node, 0, part, along1, along2);
			quake_side_c *B = new quake_side_c(node, 1, part, along2, along1);

			front.AddSide(F);
			back.AddSide(B);
		}
	}
}


static void CheckClusterEdges(quake_group_c & group, int cx, int cy)
{
	// see whether each edge (N/S/E/W) is open or closed

	bool closed_N = true;
	bool closed_S = true;
	bool closed_W = true;
	bool closed_E = true;

	double x1 = (cluster_X + cx) * CLUSTER_SIZE;
	double y1 = (cluster_Y + cy) * CLUSTER_SIZE;

	double x2 = x1 + CLUSTER_SIZE;
	double y2 = y1 + CLUSTER_SIZE;

	for (unsigned int i = 0 ; i < group.sides.size() ; i++)
	{
		quake_side_c *S = group.sides[i];

		if (S->snag && ! S->TwoSided())
			continue;

		if (MAX(S->y1, S->y2) > y2 - 2) closed_N = false;
		if (MIN(S->y1, S->y2) < y1 + 2) closed_S = false;

		if (MAX(S->x1, S->x2) > x2 - 2) closed_E = false;
		if (MIN(S->x1, S->x2) < x1 + 2) closed_W = false;
	}

	// send data to vis code
	if (closed_N) QCOM_VisMarkWall(cx, cy, 8);
	if (closed_S) QCOM_VisMarkWall(cx, cy, 2);
	if (closed_E) QCOM_VisMarkWall(cx, cy, 6);
	if (closed_W) QCOM_VisMarkWall(cx, cy, 4);
}


static int Brush_TestSide(const csg_brush_c *B, const quake_side_c *part)
{
	bool on_front = false;
	bool on_back  = false;

	for (unsigned int i = 0 ; i < B->verts.size() ; i++)
	{
		brush_vert_c * V = B->verts[i];

		double d = PerpDist(V->x,V->y, part->x1,part->y1, part->x2,part->y2);

		if (d >  Q_EPSILON) on_front = true;
		if (d < -Q_EPSILON) on_back  = true;

		// early out
		if (on_front && on_back)
			return 0;
	}

	return on_back ? -1 : +1;
}


static quake_side_c * SplitSideAt(quake_side_c *S, float new_x, float new_y)
{
	quake_side_c *T = new quake_side_c(S);

	S->x2 = T->x1 = new_x;
	S->y2 = T->y1 = new_y;

	return T;
}


static void Split_XY(quake_group_c & group,
                     quake_node_c *node, const quake_side_c *part,
                     quake_group_c & front, quake_group_c & back)
{
	std::vector<intersect_t> cut_list;

	std::vector<quake_side_c *> local_sides;
	std::vector<csg_brush_c  *> local_brushes;

	local_sides.  swap(group.sides);
	local_brushes.swap(group.brushes);

	for (unsigned int k = 0 ; k < local_sides.size() ; k++)
	{
		quake_side_c *S = local_sides[k];

		// get relationship of this side to the partition line
		double a = PerpDist(S->x1, S->y1,
				part->x1,part->y1, part->x2,part->y2);

		double b = PerpDist(S->x2, S->y2,
				part->x1,part->y1, part->x2,part->y2);

		int a_side = (a < -Q_EPSILON) ? -1 : (a > Q_EPSILON) ? +1 : 0;
		int b_side = (b < -Q_EPSILON) ? -1 : (b > Q_EPSILON) ? +1 : 0;

		// side sits on the partition?
		if (a_side == 0 && b_side == 0)
		{
			S->on_node = node;

			if (VectorSameDir(part->x2 - part->x1, part->y2 - part->y1,
						S->x2 - S->x1, S->y2 - S->y1))
			{
				front.AddSide(S);

				S->node_side = 0;

				AddIntersection(cut_list, part, S, 0, +1, K1_SITTING);
				AddIntersection(cut_list, part, S, 1, -1, K1_SITTING);
			}
			else
			{
				back.AddSide(S);

				S->node_side = 1;

				AddIntersection(cut_list, part, S, 0, -1, K1_SITTING);
				AddIntersection(cut_list, part, S, 1, +1, K1_SITTING);
			}
			continue;
		}

		// completely on the front of the partition?
		if (a_side >= 0 && b_side >= 0)
		{
			front.AddSide(S);

			if (a_side == 0)
				AddIntersection(cut_list, part, S, 0, -1, K1_NORMAL);
			else if (b_side == 0)
				AddIntersection(cut_list, part, S, 1, +1, K1_NORMAL);

			continue;
		}

		// completely on the back of the partition?
		if (a_side <= 0 && b_side <= 0)
		{
			back.AddSide(S);

			if (a_side == 0)
				AddIntersection(cut_list, part, S, 0, +1, K1_NORMAL);
			else if (b_side == 0)
				AddIntersection(cut_list, part, S, 1, -1, K1_NORMAL);

			continue;
		}

		/* need to split it */

		// determine the intersection point
		double along = a / (a - b);

		double ix = S->x1 + along * (S->x2 - S->x1);
		double iy = S->y1 + along * (S->y2 - S->y1);

		quake_side_c *T = SplitSideAt(S, ix, iy);

		// the new segs are: S = a .. i  |  T = i .. b

		front.AddSide((a_side > 0) ? S : T);
		 back.AddSide((a_side > 0) ? T : S);

		AddIntersection(cut_list, part, S, 1, a_side, K1_NORMAL);
		AddIntersection(cut_list, part, T, 0, a_side, K1_NORMAL);
	}

	for (unsigned int n = 0 ; n < local_brushes.size() ; n++)
	{
		csg_brush_c *B = local_brushes[n];

		int side = Brush_TestSide(B, part);

		if (side <= 0)  back.AddBrush(B);
		if (side >= 0) front.AddBrush(B);
	}

	CreateMiniSides(cut_list, node, part, front, back);
}


static bool FindPartition_XY(quake_group_c & group, quake_side_c *part,
                             qCluster_c ** reached_cluster)
{
	if (! *reached_cluster)
	{
		// seed-based sub-division party trick
		//
		// When the group extends (horizontally or vertically) into more
		// than a single seed, we need to split the group along a seed
		// boundary.  This is not really for the sake of speed, but for
		// the sake of the Visibility algorithm.

		double gx1, gy1, gx2, gy2;

		group.GetGroupBounds(&gx1, &gy1, &gx2, &gy2);

		int sx1 = floor(gx1 / CLUSTER_SIZE + SNAG_EPSILON);
		int sy1 = floor(gy1 / CLUSTER_SIZE + SNAG_EPSILON);
		int sx2 =  ceil(gx2 / CLUSTER_SIZE - SNAG_EPSILON);
		int sy2 =  ceil(gy2 / CLUSTER_SIZE - SNAG_EPSILON);

		int sw  = sx2 - sx1;
		int sh  = sy2 - sy1;

		if (sw >= 2 || sh >= 2)
		{
			if (sw >= sh)
			{
				part->x1 = (sx1 + sw/2) * CLUSTER_SIZE;
				part->y1 = gy1;
				part->x2 = part->x1;
				part->y2 = MAX(gy2, gy1+4);
			}
			else
			{
				part->x1 = gx1;
				part->y1 = (sy1 + sh/2) * CLUSTER_SIZE;
				part->x2 = MAX(gx2, gx1+4);
				part->y2 = part->y1;
			}

			return true;
		}

		// we have now reached a cluster
		{
			int cx = sx1 - cluster_X;
			int cy = sy1 - cluster_Y;

			SYS_ASSERT(0 <= cx && cx < cluster_W);
			SYS_ASSERT(0 <= cy && cy < cluster_H);

			*reached_cluster = qk_clusters[cy * cluster_W + cx];

			SYS_ASSERT(*reached_cluster);

			CheckClusterEdges(group, cx, cy);

			///   DebugPrintf("Reached cluster (%d %d) @ (%1.1f %1.1f) .. (%1.1f %1.1f)\n",
			///               cx, cy, gx1, gy1, gx2, gy2);
			///   group.Dump();
		}
	}

	// inside a single cluster : find a side normally

	quake_side_c *poss1 = NULL;
	quake_side_c *poss2 = NULL;

	for (unsigned int i = 0 ; i < group.sides.size() ; i++)
	{
		quake_side_c *S = group.sides[i];

		if (S->on_node)
			continue;

		bool axis_aligned = (S->x1 == S->x2) || (S->y1 == S->y2);

		// MUST choose 2-sided snag BEFORE any 1-sided snag

		if (! S->TwoSided())
		{
			if (! poss1 || axis_aligned)
				poss1 = S;

			continue;
		}

		poss2 = S;

		// we prefer an axis-aligned node
		if (axis_aligned)
		{
			break;  // look no further
		}
	}

	quake_side_c *best = poss2 ? poss2 : poss1;

	if (! best)
		return false;

	part->x1 = best->x1;  part->y1 = best->y1;
	part->x2 = best->x2;  part->y2 = best->y2;

	return true;
}


struct floor_angle_Cmp
{
	double *angles;

	 floor_angle_Cmp(double *p) : angles(p) { }
	~floor_angle_Cmp() { }

	inline bool operator() (int A, int B) const
	{
		return angles[A] < angles[B];
	}
};


static void CollectWinding(quake_group_c & group,
                           std::vector<quake_vertex_c> & winding,
                           quake_bbox_c & bbox)
{
	// create a winding for the current leaf, which serves as a
	// template for the floor and ceiling faces in the leaf.
	// only XY coordinates are handled here.
	//
	// result is CLOCKWISE when looking DOWN at the winding.
	//

	int v_num = (int)group.sides.size();

	SYS_ASSERT(v_num >= 3);

	double mid_x, mid_y;

	group.CalcMid(&mid_x, &mid_y);

	// determine angles, then sort

	std::vector<double> angles (v_num);
	std::vector<int>    mapping(v_num);

	for (int a = 0 ; a < v_num ; a++)
	{
		quake_side_c *S = group.sides[a];

		angles[a]  = 0 - CalcAngle(mid_x, mid_y, S->x1, S->y1);
		mapping[a] = a;
	}

	std::sort(mapping.begin(), mapping.end(), floor_angle_Cmp(&angles[0]));

	// grab sorted vertices

	bbox.Begin();

	for (int i = 0 ; i < v_num ; i++)
	{
		int k = mapping[i];

		quake_side_c *S = group.sides[k];

		winding.push_back(quake_vertex_c(S->x1, S->y1, 0));

		// we don't handle bounding Z here
		bbox.Add_X(S->x1);
		bbox.Add_Y(S->y1);
	}

	bbox.End();
}


void quake_face_c::AddVert(float x, float y, float z)
{
	verts.push_back(quake_vertex_c(x, y, z));
}


void quake_face_c::StoreWinding(const std::vector<quake_vertex_c>& winding,
                                const quake_plane_c *plane,
                                bool reverse)
{
	for (unsigned int i = 0 ; i < winding.size() ; i++)
	{
		unsigned int k = reverse ? (winding.size() - 1 - i) : i;

		const quake_vertex_c& V = winding[k];

		double z = plane->CalcZ(V.x, V.y);

		AddVert(V.x, V.y, z);
	}
}


void quake_face_c::SetupMatrix(const quake_plane_c *plane)
{
	s[0] = s[1] = s[2] = s[3] = 0;
	t[0] = t[1] = t[2] = t[3] = 0;

	if (fabs(plane->nx) > 0.5)
	{
		s[1] =  1;  // PLANE_X
		t[2] = -1;
	}
	else if (fabs(plane->ny) > 0.5)
	{
		s[0] =  1;  // PLANE_Y
		t[2] = -1;
	}
	else
	{
		s[0] = 1;  // PLANE_Z
		t[1] = 1;
	}
}


void quake_face_c::GetBounds(quake_bbox_c *bbox) const
{
	bbox->Begin();

	for (unsigned int i = 0 ; i < verts.size() ; i++)
	{
		const quake_vertex_c& V = verts[i];

		bbox->AddPoint(V.x, V.y, V.z);
	}

	bbox->End();
}


float quake_face_c::Calc_S(float x, float y, float z) const
{
	return s[0] * x + s[1] * y + s[2] * z + s[3];
}

float quake_face_c::Calc_S(const quake_vertex_c *V) const
{
	return s[0] * V->x + s[1] * V->y + s[2] * V->z + s[3];
}


float quake_face_c::Calc_T(float x, float y, float z) const
{
	return t[0] * x + t[1] * y + t[2] * z + t[3];
}

float quake_face_c::Calc_T(const quake_vertex_c *V) const
{
	return t[0] * V->x + t[1] * V->y + t[2] * V->z + t[3];
}


void quake_face_c::ST_Bounds(double *min_s, double *min_t,
                             double *max_s, double *max_t) const
{
	*min_s = +9e9;  *max_s = -9e9;
	*min_t = +9e9;  *max_t = -9e9;

	for (unsigned int i = 0 ; i < verts.size() ; i++)
	{
		double ss = Calc_S(&verts[i]);
		double tt = Calc_T(&verts[i]);

		*min_s = MIN(*min_s, ss);  *max_s = MAX(*max_s, ss);
		*min_t = MIN(*min_t, tt);  *max_t = MAX(*max_t, tt);
	}

	if (*min_s > *max_s) *min_s = *max_s = 0;
	if (*min_t > *max_t) *min_t = *max_t = 0;
}


void quake_face_c::ComputeMidPoint(float *mx, float *my, float *mz)
{
	double sum_x = 0;
	double sum_y = 0;
	double sum_z = 0;

	int num = (int)verts.size();

	for (int i = 0 ; i < num ; i++)
	{
		sum_x += verts[i].x;
		sum_y += verts[i].y;
		sum_z += verts[i].z;
	}

	if (num == 0)
		num = 1;

	*mx = sum_x / (double)num;
	*my = sum_y / (double)num;
	*mz = sum_z / (double)num;
}


void quake_face_c::GetNormal(float *vec3) const
{
	SYS_ASSERT(node);

	float mul = (node_side > 0) ? -1.0 : +1.0;

	vec3[0] = node->plane.nx * mul;
	vec3[1] = node->plane.ny * mul;
	vec3[2] = node->plane.nz * mul;
}


static void DoAddFace(quake_face_c *F, csg_property_set_c *props,
					  quake_node_c *node, quake_leaf_c *leaf)
{
	F->texture = props->getStr("tex", "missing");

	F->SetupMatrix(&node->plane);

	node->AddFace(F);
	leaf->AddFace(F);

	qk_all_faces.push_back(F);
}


static void FloorOrCeilFace(quake_node_c *node, quake_leaf_c *leaf,
                            const gap_c *G, bool is_ceil,
                            std::vector<quake_vertex_c> & winding)
{
	// get node splitting plane

	csg_brush_c *B = is_ceil ? G->top : G->bottom;

	brush_plane_c& BP = is_ceil ? B->b : B->t;

	if (BP.slope)
	{
		node->plane = *BP.slope;

		if (node->plane.nz < 0)
			node->plane.Flip();
	}
	else
	{
		node->plane.x  = node->plane.y  = 0;
		node->plane.nx = node->plane.ny = 0;

		node->plane.z  = BP.z;
		node->plane.nz = +1;
	}

	quake_face_c *F = new quake_face_c;

	F->node_side = is_ceil ? 1 : 0;

	F->StoreWinding(winding, &node->plane, is_ceil);

	if (B->bkind == BKIND_Sky)
		F->flags |= FACE_F_Sky;

	DoAddFace(F, &BP.face, node, leaf);
}


// FIXME : re-use the above function
static void CreateLiquidFace(quake_node_c *node, quake_leaf_c *leaf,
                             csg_brush_c *B, bool is_ceil,
                             std::vector<quake_vertex_c> & winding)
{
	node->plane.x  = node->plane.y  = 0;
	node->plane.nx = node->plane.ny = 0;
	node->plane.z  = B->t.z;
	node->plane.nz = +1;

	quake_face_c *F = new quake_face_c;

	F->node_side = is_ceil ? 1 : 0;

	F->flags |= FACE_F_Liquid;

	F->StoreWinding(winding, &node->plane, is_ceil);

	DoAddFace(F, &B->t.face, node, leaf);
}


static void WallFace_Quad(quake_node_c *node, quake_leaf_c *leaf,
						  quake_side_c *S, brush_vert_c *bvert,
						  double L_bz, double L_tz,
						  double R_bz, double R_tz, int tri_side)
{
	quake_face_c *F = new quake_face_c();

	F->node_side = S->node_side;

	F->AddVert(S->x1, S->y1, L_bz);

	if (tri_side >= 0)
		F->AddVert(S->x1, S->y1, L_tz);

	F->AddVert(S->x2, S->y2, R_tz);

	if (tri_side <= 0)
		F->AddVert(S->x2, S->y2, R_bz);

	SYS_ASSERT(F->verts.size() >= 3);

	if (bvert->parent->bkind == BKIND_Sky)
		F->flags |= FACE_F_Sky;

	DoAddFace(F, &bvert->face, node, leaf);
}


static int CheckEdgeIntersect(double g_z1, double g_z2,
							  double f_z1, double f_z2,
							  double *along = NULL)
{
	// returns:  0 if intersects
	//          +1 if face edge completely above gap edge
	//          -1 if face edge completely below gap edge

	if ((f_z1 > g_z1 - Z_EPSILON) && (f_z2 > g_z2 - Z_EPSILON))
		return +1;

	if ((f_z1 < g_z1 + Z_EPSILON) && (f_z2 < g_z2 + Z_EPSILON))
		return -1;

	// find the intersection point
	if (along)
	{
		double den = (g_z2 - g_z1) - (f_z2 - f_z1);

		*along = (f_z1 - g_z1) / den;
	}

	return 0;
}


static void DoAddVertex(quake_face_c *F, quake_side_c *S,
						double along, double Lz, double Rz)
{
	double x = S->x1 + (S->x2 - S->x1) * along;
	double y = S->y1 + (S->y2 - S->y1) * along;
	double z =    Lz + (   Rz -    Lz) * along;

	F->AddVert(x, y, z);
}


static void ClipWallFace(quake_node_c *node, quake_leaf_c *leaf,
						 quake_side_c *S, brush_vert_c *bvert,
						 double g_Lz1, double g_Lz2, /* gap */
						 double g_Rz1, double g_Rz2,
						 double f_Lz1, double f_Lz2, /* face */
						 double f_Rz1, double f_Rz2)
{
	// ensure the face is sane  [ triangles are Ok ]
	if ((f_Lz1 > f_Lz2 - Z_EPSILON) && (f_Rz1 > f_Rz2 - Z_EPSILON))
		return;

	if (f_Lz1 > f_Lz2) f_Lz1 = f_Lz2 = (f_Lz1 + f_Lz2) * 0.5;
	if (f_Rz1 > f_Rz2) f_Rz1 = f_Rz2 = (f_Rz1 + f_Rz2) * 0.5;


	// trivial reject
	if ((f_Lz1 > g_Lz2 - Z_EPSILON) && (f_Rz1 > g_Rz2 - Z_EPSILON)) return;
	if ((f_Lz2 < g_Lz1 + Z_EPSILON) && (f_Rz2 < g_Rz1 + Z_EPSILON)) return;

	// subdivide faces which are too tall  [ recursively... ]
	float len1 = MIN(f_Lz2, g_Lz2) - MAX(f_Lz1, g_Lz1);
	float len2 = MIN(f_Rz2, g_Rz2) - MAX(f_Rz1, g_Rz1);

	if (MAX(len1, len2) > FACE_MAX_SIZE)
	{
		double f_Lmz = (f_Lz1 + f_Lz2) * 0.5;
		double f_Rmz = (f_Rz1 + f_Rz2) * 0.5;

		ClipWallFace(node, leaf, S, bvert,
					 g_Lz1, g_Lz2, g_Rz1, g_Rz2,
					 f_Lz1, f_Lmz, f_Rz1, f_Rmz);

		ClipWallFace(node, leaf, S, bvert,
					 g_Lz1, g_Lz2, g_Rz1, g_Rz2,
					 f_Lmz, f_Lz2, f_Rmz, f_Rz2);
		return;
	}


	// determine relationship of edges

	double a_bb, a_bt, a_tb, a_tt;

	int bb = CheckEdgeIntersect(g_Lz1, g_Rz1, f_Lz1, f_Rz1, &a_bb);
	int bt = CheckEdgeIntersect(g_Lz1, g_Rz1, f_Lz2, f_Rz2, &a_bt);
	int tb = CheckEdgeIntersect(g_Lz2, g_Rz2, f_Lz1, f_Rz1, &a_tb);
	int tt = CheckEdgeIntersect(g_Lz2, g_Rz2, f_Lz2, f_Rz2, &a_tt);

	// full-reject cases  [ checked earlier, but handle it again ]
	if (bt < 0 || tb > 0)
		return;

	if (! (bb == 0 || bt == 0 || tb == 0 || tt == 0))
	{
		// handle the simple cases (no intersections)

		if (bb < 0)
		{
			f_Lz1 = g_Lz1;
			f_Rz1 = g_Rz1;
		}

		if (tt > 0)
		{
			f_Lz2 = g_Lz2;
			f_Rz2 = g_Rz2;
		}

		int tri_side = 0;

		if (fabs(f_Lz1 - f_Lz2) < Z_EPSILON) tri_side = -1;
		if (fabs(f_Rz1 - f_Rz2) < Z_EPSILON) tri_side = +1;

		WallFace_Quad(node, leaf, S, bvert, f_Lz1, f_Lz2, f_Rz1, f_Rz2, tri_side);
		return;
	}


	/* full clip! */

	// basic idea is two produce a winding using all the intercept
	// points (including at corners of the gap), but omit all the
	// vertices which lie completely outside of the gap.

	quake_face_c *F = new quake_face_c();

	// left edge

	if ((f_Lz2 < g_Lz1 - Z_EPSILON) || (f_Lz1 > g_Lz2 + Z_EPSILON))
	{
		// none
	}
	else
	{
		double z1 = MAX(f_Lz1, g_Lz1);
		double z2 = MIN(f_Lz2, g_Lz2);

		F->AddVert(S->x1, S->y1, z1);

		if (z2 > z1 + Z_EPSILON)
			F->AddVert(S->x1, S->y1, z2);
	}

	// top edge

	if (bt == 0 && tt == 0)
	{
		// two intersects, ensure order is correct
		if (a_bt > a_tt)
			std::swap(a_bt, a_tt);
	}

	if (bt == 0) DoAddVertex(F, S, a_bt, g_Lz2, g_Rz2);
	if (tt == 0) DoAddVertex(F, S, a_tt, g_Lz2, g_Rz2);

	// right edge

	if ((f_Rz2 < g_Rz1 - Z_EPSILON) || (f_Rz1 > g_Rz2 + Z_EPSILON))
	{
		// none
	}
	else
	{
		double z1 = MAX(f_Rz1, g_Rz1);
		double z2 = MIN(f_Rz2, g_Rz2);

		F->AddVert(S->x2, S->y2, z2);

		if (z1 < z2 - Z_EPSILON)
			F->AddVert(S->x2, S->y2, z1);
	}

	// bottom edge

	if (bb == 0 && tb == 0)
	{
		// two intersects, ensure order is correct
		if (a_bb < a_tb)
			std::swap(a_bb, a_tb);
	}

	if (bb == 0) DoAddVertex(F, S, a_bb, g_Lz1, g_Rz1);
	if (tb == 0) DoAddVertex(F, S, a_tb, g_Lz1, g_Rz1);


	// check face is OK
	// [ this should not happen, but just in case... ]

	if (F->verts.size() < 3)
	{
		delete F;
		return;
	}

	F->node_side = S->node_side;

	DoAddFace(F, &bvert->face, node, leaf);
}


static void CreateWallFaces(quake_group_c & group, quake_leaf_c *leaf,
                            quake_side_c *S, gap_c *G)
{
	SYS_ASSERT(S->on_node);

	if (! S->snag)  // "mini sides" never have faces
		return;

	SYS_ASSERT(S->node_side >= 0);


	double g_Lz1 = G->bottom->t.CalcZ(S->x1, S->y1);
	double g_Lz2 = G->   top->b.CalcZ(S->x1, S->y1);

	double g_Rz1 = G->bottom->t.CalcZ(S->x2, S->y2);
	double g_Rz2 = G->   top->b.CalcZ(S->x2, S->y2);

	// ensure the gap is sane
	if ((g_Lz1 > g_Lz2 - Z_EPSILON) && (g_Rz1 > g_Rz2 - Z_EPSILON))
		return;

	if (g_Lz1 > g_Lz2) g_Lz1 = g_Lz2 = (g_Lz1 + g_Lz2) * 0.5;
	if (g_Rz1 > g_Rz2) g_Rz1 = g_Rz2 = (g_Rz1 + g_Rz2) * 0.5;


	double mid_z = (g_Lz1 + g_Lz2 + g_Rz1 + g_Rz2) * 0.25;


	// one-sided walls are the easiest to handle

	if (! S->TwoSided())
	{
		brush_vert_c *bvert = NULL;

		// Note: the brush sides we are interested in are on the OPPOSITE
		//       side of the snag, since regions are created from *inward*
		//       facing snags, but brush sides face outward.
		if (S->snag->partner)
			bvert = S->snag->partner->FindOneSidedVert(mid_z);

		// fallback to something safe
		// TODO : pick brushvert with closest normal to snag
		if (! bvert)
			bvert = G->bottom->verts[0];

		ClipWallFace(S->on_node, leaf, S, bvert,
					 g_Lz1, g_Lz2, g_Rz1, g_Rz2,
					 g_Lz1, g_Lz2, g_Rz1, g_Rz2);
		return;
	}


	// two sided : check for which solid areas touch this gap

	SYS_ASSERT(S->snag->partner);

	region_c *back = S->snag->partner->region;

	unsigned int numgaps = back->gaps.size();

	// k is not really a gap number here, but the solids in-between
	for (unsigned int k = 0 ; k <= numgaps ; k++)
	{
		// the side of this brush will supply the face
		// [ we do not support a group of stacked brushes ]
		csg_brush_c *B;

		if (k < numgaps)
			B = back->gaps[k]->bottom;
		else
			B = back->gaps[k-1]->top;

		// get the brush's side
		brush_vert_c *bvert = S->snag->partner->FindBrushVert(B);

		// fallback to something safe
		// TODO : pick brushvert with closest normal to snag
		if (! bvert)
			bvert = B->verts[0];

		// get the quad
		double f_Lz1 = B->b.CalcZ(S->x1, S->y1);
		double f_Lz2 = B->t.CalcZ(S->x1, S->y1);

		double f_Rz1 = B->b.CalcZ(S->x2, S->y2);
		double f_Rz2 = B->t.CalcZ(S->x2, S->y2);

		ClipWallFace(S->on_node, leaf, S, bvert,
					 g_Lz1, g_Lz2, g_Rz1, g_Rz2,
					 f_Lz1, f_Lz2, f_Rz1, f_Rz2);
	}
}


void quake_leaf_c::BBoxFromSolids()
{
	bbox.Begin();

	for (unsigned int i = 0 ; i < solids.size() ; i++)
	{
		csg_brush_c *B = solids[i];

		bbox.Add_Z(B->t.z);
		bbox.Add_Z(B->b.z);

		for (unsigned int k = 0 ; k < B->verts.size() ; k++)
		{
			brush_vert_c * V = B->verts[k];

			bbox.Add_X(V->x);
			bbox.Add_Y(V->y);
		}
	}

	bbox.End();
}


void quake_leaf_c::FilterClipBrush(csg_brush_c *B)
{
	if (medium == MEDIUM_SOLID)
		return;

	AddSolid(B);
}


static int ParseLiquidMedium(csg_property_set_c *props)
{
	const char *str = props->getStr("medium");

	if (str)
	{
		if (StringCaseCmp(str, "water") == 0)
			return MEDIUM_WATER;

		if (StringCaseCmp(str, "slime") == 0)
			return MEDIUM_SLIME;

		if (StringCaseCmp(str, "lava") == 0)
			return MEDIUM_LAVA;

		LogPrintf("WARNING: unknown liquid medium '%s'\n", str);
	}

	return MEDIUM_WATER;  // the default
}


static quake_leaf_c * Solid_Leaf(quake_group_c & group)
{
	// Quake 1 and related games have a shared solid leaf
	if (qk_game == 1)
		return qk_solid_leaf;

	// optimisation -- VALID ???
	if (group.brushes.empty())
		return qk_solid_leaf;

	quake_leaf_c *leaf = new quake_leaf_c(MEDIUM_SOLID);

	for (unsigned int i = 0 ; i < group.brushes.size() ; i++)
	{
		csg_brush_c *B = group.brushes[i];

		leaf->AddSolid(B);
	}

	leaf->BBoxFromSolids();

	return leaf;
}


static quake_leaf_c * Solid_Leaf(region_c *R, unsigned int g, int is_ceil,
                                 quake_group_c& group)
{
	if (qk_game == 1)
		return qk_solid_leaf;

	quake_leaf_c *leaf = new quake_leaf_c(MEDIUM_SOLID);

	// add _all_ solid brushes for the floor/ceiling (Quake II)
	double brush_z1 = -9e9;
	double brush_z2 = +9e9;

	if (g > 0)
		brush_z1 = R->gaps[g-1]->top->b.z - 2;

	if (g+1 < R->gaps.size())
		brush_z2 = R->gaps[g+1]->bottom->t.z + 2;

	for (unsigned int i = 0 ; i < group.brushes.size() ; i++)
	{
		csg_brush_c *B = group.brushes[i];

		if (brush_z1 < B->b.z && B->t.z < brush_z2)
			leaf->AddSolid(B);
	}

	// this should not happen..... but handle it anyway
	if (leaf->solids.empty())
	{
		LogPrintf("WARNING: solid brush for floor/ceiling is AWOL!\n");

		leaf->AddSolid(is_ceil ? R->gaps[g]->top : R->gaps[g]->bottom);
	}

	leaf->BBoxFromSolids();

	return leaf;
}


static quake_node_c * Solid_Node(quake_group_c & group)
{
	quake_node_c * node = new quake_node_c();

	node->plane.x  = node->plane.y  = 0;
	node->plane.nx = node->plane.ny = 0;
	node->plane.z  = 0;
	node->plane.nz = +1;

	node->front_L = Solid_Leaf(group);
	node-> back_L = Solid_Leaf(group);

	return node;
}


static int GapForLiquid(region_c * R)
{
	// returns gap number * 2, plus 1 if the gap is completely
	// filled by the liquid (i.e. the surface is eaten by the
	// solid area above the gap).
	//
	// returns -1 if no liquid, or surface is below lowest floor.
	//
	if (R->liquid)
	{
		for (int g = (int)R->gaps.size()-1 ; g >= 0 ; g--)
		{
			gap_c *gap = R->gaps[g];

			// FIXME : for sloped solids and sloped liquids

			if (R->liquid->t.z > gap->top->b.z - 1)
				return g*2 + 1;

			if (R->liquid->t.z > gap->bottom->t.z + 1)
				return g*2;
		}
	}

	return -1;
}


static quake_node_c * CreateLeaf(region_c * R, int g /* gap */,
                                 quake_group_c & group,
                                 std::vector<quake_vertex_c> & winding,
                                 quake_bbox_c & bbox,
								 qCluster_c *cluster,
                                 quake_node_c * prev_N,
								 quake_leaf_c * prev_L,
								 int liq_gap)
{
	gap_c *gap = R->gaps[g];

	quake_leaf_c *leaf = new quake_leaf_c(MEDIUM_AIR);

	cluster->AddLeaf(leaf);

	// create faces for the walls in this leaf
	for (unsigned int s = 0 ; s < group.sides.size() ; s++)
	{
		CreateWallFaces(group, leaf, group.sides[s], gap);
	}

	quake_node_c *F_node = new quake_node_c;
	quake_node_c *C_node = new quake_node_c;

	// copy XY bbox and determine Z coord
	leaf->bbox = bbox;

	leaf->bbox.mins[2] = gap->bottom->t.z;
	leaf->bbox.maxs[2] = gap->top->b.z;

	// TODO : this is hacky, determine proper Z value
	if (gap->bottom->t.slope) leaf->bbox.mins[2] = gap->bottom->b.z;
	if (gap->top   ->b.slope) leaf->bbox.maxs[2] = gap->top->t.z;

	// --- handle liquids ---

	quake_node_c *L_node = NULL;
	quake_leaf_c *L_leaf = NULL;

	if (liq_gap >= 0)
	{
		int medium = ParseLiquidMedium(&R->liquid->props);

		if (g*2 < liq_gap || g*2+1 == liq_gap)
		{
			// the liquid covers the whole gap : don't need an extra leaf/node
			leaf->medium = medium;

			if (qk_game >= 2)
				leaf->AddSolid(R->liquid);

			cluster->MarkAmbient(AMBIENT_WATER);
		}
		else if (g*2 == liq_gap)
		{
			// this liquid surface lies within this gap
			// (above the floor and below the ceiling)

			// TODO: share faces between the AIR leaf and LIQUID leaf
			// [ but engine will always draw both leafs, so not essential ]

			L_node = new quake_node_c;
			L_leaf = new quake_leaf_c(medium);

			L_leaf->bbox = leaf->bbox;

			if (qk_game >= 2)
				L_leaf->AddSolid(R->liquid);

			cluster->AddLeaf(L_leaf);
			cluster->MarkAmbient(AMBIENT_WATER);

			CreateLiquidFace(L_node,   leaf, R->liquid, false, winding);
			CreateLiquidFace(L_node, L_leaf, R->liquid, true,  winding);
		}
	}

	FloorOrCeilFace(C_node, leaf, gap, true,  winding);
	FloorOrCeilFace(F_node, L_leaf ? L_leaf : leaf, gap, false, winding);

	// link nodes together

	// Note that floor and ceiling node planes always face upwards (nz > 0)

	C_node->front_N = prev_N;
	C_node->front_L = prev_L;

	F_node->front_N = L_node ? L_node : C_node;

	C_node->back_L = leaf;
	F_node->back_L = Solid_Leaf(R, g, 0, group);

	if (L_node)
	{
		L_node->front_N = C_node;
		L_node->back_L  = L_leaf;
	}

	return F_node;
}


static quake_node_c * Partition_Z(quake_group_c & group, qCluster_c *cluster)
{
	region_c *R = group.FinalRegion();

	SYS_ASSERT(R);

	// THIS SHOULD NOT HAPPEN -- but handle it just in case
	if (R->gaps.size() == 0 || group.sides.size() < 3)
	{
		LogPrintf("WARNING: bad group at Partition_Z\n");
		return Solid_Node(group);
	}

	SYS_ASSERT(R->gaps.size() > 0);

	// if region has a liquid, find the gap containing it
	int liq_gap = GapForLiquid(R);

	// create the bbox and vertex winding, 2D only
	quake_bbox_c bbox;
	std::vector<quake_vertex_c> winding;

	CollectWinding(group, winding, bbox);

	quake_node_c *cur_node = NULL;
	quake_leaf_c *cur_leaf = Solid_Leaf(R, R->gaps.size()-1, 1, group);

	for (int i = (int)R->gaps.size()-1 ; i >= 0 ; i--)
	{
		cur_node = CreateLeaf(R, i, group, winding, bbox, cluster, cur_node, cur_leaf, liq_gap);
		cur_leaf = NULL;
	}

	SYS_ASSERT(cur_node);

	return cur_node;
}


#if (NODE_DEBUG == 1)
static const char * leaf_to_string(quake_leaf_c *L, quake_node_c *N)
{
	if (L == qk_solid_leaf)
		return "SOLID";

	// this doesn't actually occur
	if (L)
		return "WTF";

	// for the nodeviewer, a "leaf" is when we hit Partition_Z
	if (fabs(N->plane.nz) > 0.5)
		return StringPrintf("LEAF");

	return StringPrintf("N:%p", N);
}
#endif


static quake_node_c * Partition_Group(quake_group_c & group,
                                      qCluster_c *reached_cluster = NULL,
                                      quake_node_c *parent = NULL,
                                      int parent_side = 0)
{
	SYS_ASSERT(! group.sides.empty());

	quake_side_c part;
	quake_plane_c p_plane;

	if (FindPartition_XY(group, &part, &reached_cluster))
	{
		part.ToPlane(&p_plane);

		quake_node_c * new_node = new quake_node_c(p_plane);

		// divide the group
		quake_group_c front;
		quake_group_c back;

		Split_XY(group, new_node, &part, front, back);

		// the front should never be empty
		SYS_ASSERT(! front.sides.empty());

#if (NODE_DEBUG == 1)
		LogPrintf("partition %p (%1.2f %1.2f) (%1.2f %1.2f)\n", new_node,
				part.x1, part.y1, part.x2, part.y2);
#endif

		new_node->front_N = Partition_Group(front, reached_cluster, new_node, 0);

		if (back.sides.empty())
			new_node->back_L = Solid_Leaf(back);
		else
			new_node->back_N = Partition_Group(back, reached_cluster, new_node, 1);

#if (NODE_DEBUG == 1)
		LogPrintf("part_info %p = %s / %s\n", new_node,
				leaf_to_string(new_node->front_L, new_node->front_N),
				leaf_to_string(new_node-> back_L, new_node-> back_N));
#endif

		// input group has been consumed now

		return new_node;
	}
	else
	{
		SYS_ASSERT(reached_cluster);

#if (NODE_DEBUG == 1)
		SYS_ASSERT(parent);
		LogPrintf("side_group @ %p : %d = %u\n", parent, parent_side, group.sides.size());

		for (unsigned int i = 0 ; i < group.sides.size() ; i++)
		{
			const quake_side_c *S = group.sides[i];
			LogPrintf("  side %p : (%1.2f %1.2f) (%1.2f %1.2f) in %p\n",
					S, S->x1, S->y1, S->x2, S->y2, S->snag ? S->snag->region : NULL);
		}
#endif

		return Partition_Z(group, reached_cluster);
	}
}


//------------------------------------------------------------------------

void quake_bbox_c::Begin()
{
	for (int b = 0 ; b < 3 ; b++)
	{
		mins[b] = +9e9;
		maxs[b] = -9e9;
	}
}

void quake_bbox_c::End()
{
	for (int b = 0 ; b < 3 ; b++)
		if (mins[b] > maxs[b])
			mins[b] = maxs[b] = 0;
}


void quake_bbox_c::Add_X(float x)
{
	if (x < mins[0]) mins[0] = x;
	if (x > maxs[0]) maxs[0] = x;
}

void quake_bbox_c::Add_Y(float y)
{
	if (y < mins[1]) mins[1] = y;
	if (y > maxs[1]) maxs[1] = y;
}

void quake_bbox_c::Add_Z(float z)
{
	if (z < mins[2]) mins[2] = z;
	if (z > maxs[2]) maxs[2] = z;
}

void quake_bbox_c::AddPoint(float x, float y, float z)
{
	if (x < mins[0]) mins[0] = x;
	if (x > maxs[0]) maxs[0] = x;

	if (y < mins[1]) mins[1] = y;
	if (y > maxs[1]) maxs[1] = y;

	if (z < mins[2]) mins[2] = z;
	if (z > maxs[2]) maxs[2] = z;
}


void quake_bbox_c::Merge(const quake_bbox_c& other)
{
	for (int b = 0 ; b < 3 ; b++)
	{
		mins[b] = MIN(mins[b], other.mins[b]);
		maxs[b] = MAX(maxs[b], other.maxs[b]);
	}
}


bool quake_bbox_c::Touches(float x, float y, float z, float r) const
{
	if (x > maxs[0] + r) return false;
	if (x < mins[0] - r) return false;

	if (y > maxs[1] + r) return false;
	if (y < mins[1] - r) return false;

	if (z > maxs[2] + r) return false;
	if (z < mins[2] - r) return false;

	return true;
}


void quake_node_c::ComputeBBox()
{
	// NOTE: assumes bbox of all children (nodes/leafs) are valid

	bbox.Begin();

	if (front_N)
		bbox.Merge(front_N->bbox);
	else if (front_L != qk_solid_leaf)
		bbox.Merge(front_L->bbox);

	if (back_N)
		bbox.Merge(back_N->bbox);
	else if (back_L != qk_solid_leaf)
		bbox.Merge(back_L->bbox);

	bbox.End();
}


void quake_node_c::FilterClipBrush(csg_brush_c *B)
{
	int side = plane.BrushSide(B);

	if (side >= 0)
	{
		if (front_N)
			front_N->FilterClipBrush(B);
		else if (front_L != qk_solid_leaf)
			front_L->FilterClipBrush(B);
	}

	if (side <= 0)
	{
		if (back_N)
			back_N->FilterClipBrush(B);
		else if (back_L != qk_solid_leaf)
			back_L->FilterClipBrush(B);
	}
}


static void AssignLeafIndex(quake_leaf_c *leaf, int *cur_leaf)
{
	SYS_ASSERT(leaf);

	if (leaf == qk_solid_leaf)
		return;

	// must add 1 because leaf #0 is the SOLID_LEAF
	leaf->index = 1 + *cur_leaf;

	*cur_leaf += 1;
}


void CSG_AssignIndexes(quake_node_c *node, int *cur_node, int *cur_leaf)
{
	node->index = *cur_node;

	*cur_node += 1;

	if (node->front_N)
		CSG_AssignIndexes(node->front_N, cur_node, cur_leaf);
	else
		AssignLeafIndex(node->front_L, cur_leaf);

	if (node->back_N)
		CSG_AssignIndexes(node->back_N, cur_node, cur_leaf);
	else
		AssignLeafIndex(node->back_L, cur_leaf);

	// determine node's bounding box now
	node->ComputeBBox();
}


static void CreateClusters(quake_group_c & group)
{
	QCOM_FreeClusters();

	double min_x, min_y;
	double max_x, max_y;

	group.GetGroupBounds(&min_x, &min_y, &max_x, &max_y);

	QCOM_CreateClusters(min_x, min_y, max_x, max_y);
}


static void RemoveSolidNodes(quake_node_c * node)
{
	// this is mainly for Darkplaces, which throws a wobbly fit if a
	// node has the same front and back (even if it's the solid leaf).

	if (node->front_N)
	{
		RemoveSolidNodes(node->front_N);

		if (node->front_N->front_L == qk_solid_leaf &&
			node->front_N->back_L  == qk_solid_leaf)
		{
			node->front_L = qk_solid_leaf;
			node->front_N = NULL;
		}
	}

	if (node->back_N)
	{
		RemoveSolidNodes(node->back_N);

		if (node->back_N->front_L == qk_solid_leaf &&
			node->back_N->back_L  == qk_solid_leaf)
		{
			node->back_L = qk_solid_leaf;
			node->back_N = NULL;
		}
	}
}


static void FilterClipBrushes()
{
	// find all the BKIND_Clip brushes, which so far have been
	// completely ignored, and insert them into the leafs of our
	// quakey BSP tree.  [ Quake 3 only ]

	for (unsigned int k = 0 ; k < all_brushes.size() ; k++)
	{
		csg_brush_c *B = all_brushes[k];

		if (B->bkind == BKIND_Clip)
			qk_bsp_root->FilterClipBrush(B);
	}
}


void CSG_QUAKE_Build()
{
	LogPrintf("QUAKE CSG...\n");

	if (main_win)
		main_win->build_box->Prog_Step("CSG");

	CSG_BSP(1.0);

	if (main_win)
		main_win->build_box->Prog_Step("BSP");


	quake_group_c GROUP;

	CreateSides(GROUP);

	if (qk_game >= 2)
		CreateBrushes(GROUP);

	CreateClusters(GROUP);


	qk_solid_leaf = new quake_leaf_c(MEDIUM_SOLID);
	qk_solid_leaf->index = 0;

#if (NODE_DEBUG == 1)
	LogPrintf("begin_node_stuff\n");
#endif

	qk_bsp_root = Partition_Group(GROUP, NULL, NULL, 0);

#if (NODE_DEBUG == 1)
	LogPrintf("root = %p\n", qk_bsp_root);
#endif

	RemoveSolidNodes(qk_bsp_root);

	SYS_ASSERT(qk_bsp_root);

	if (qk_game == 3)
		FilterClipBrushes();
}


void CSG_QUAKE_Free()
{
	unsigned int i;

	// Note: must delete bsp tree _before_ the solid leaf

	delete qk_bsp_root;   qk_bsp_root   = NULL;
	delete qk_solid_leaf; qk_solid_leaf = NULL;

	for (i = 0 ; i < qk_all_faces.size() ; i++)
		delete qk_all_faces[i];

	for (i = 0 ; i < qk_all_mapmodels.size() ; i++)
		delete qk_all_mapmodels[i];

	qk_all_faces.    clear();
	qk_all_mapmodels.clear();
}


//------------------------------------------------------------------------

extern int Grab_Properties(lua_State *L, int stack_pos,
                           csg_property_set_c *props,
                           bool skip_singles = false);

int Q1_add_mapmodel(lua_State *L)
{
	// LUA: q1_add_mapmodel(info)
	//
	// info is a table containing these fields:
	//   x1, x2  : X coordinates
	//   y1, y2  : Y coordinates
	//   z1, z2  : Z coordinates
	//
	//   x_face  : face table for X sides
	//   y_face  : face table for Y sides
	//   z_face  : face table for top and bottom

	if (lua_type(L, 1) != LUA_TTABLE)
		return luaL_argerror(L, 1, "missing table: mapmodel info");

	quake_mapmodel_c *model = new quake_mapmodel_c;

	qk_all_mapmodels.push_back(model);

	lua_getfield(L, 1, "x1");
	lua_getfield(L, 1, "y1");
	lua_getfield(L, 1, "z1");

	model->x1 = luaL_checknumber(L, -3);
	model->y1 = luaL_checknumber(L, -2);
	model->z1 = luaL_checknumber(L, -1);

	lua_pop(L, 3);

	lua_getfield(L, 1, "x2");
	lua_getfield(L, 1, "y2");
	lua_getfield(L, 1, "z2");

	model->x2 = luaL_checknumber(L, -3);
	model->y2 = luaL_checknumber(L, -2);
	model->z2 = luaL_checknumber(L, -1);

	lua_pop(L, 3);

	lua_getfield(L, 1, "x_face");
	lua_getfield(L, 1, "y_face");
	lua_getfield(L, 1, "z_face");

	Grab_Properties(L, -3, &model->x_face);
	Grab_Properties(L, -2, &model->y_face);
	Grab_Properties(L, -1, &model->z_face);

	lua_pop(L, 3);

	// create model reference (for entity)
	char ref_name[32];
	sprintf(ref_name, "*%lu", (long unsigned int)qk_all_mapmodels.size());

	lua_pushstring(L, ref_name);
	return 1;
}


//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
