/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * The debugger
 */

#ifndef __DEBUG_H
#define __DEBUG_H

#include "zmachine.h"

/* === Debug data structures === */
typedef struct debug_breakpoint debug_breakpoint;

struct debug_breakpoint
{
  int address;
  int original;
};

extern debug_breakpoint* debug_bplist;
extern int               debug_nbps;

/* === Debug functions === */

/* Breakpoints */
int               debug_set_breakpoint  (int address);
int               debug_clear_breakpoint(int address);
debug_breakpoint* debug_get_breakpoint  (int address);

#endif

