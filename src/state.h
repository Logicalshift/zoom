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
 * Functions to do with the game state (save, load & undo)
 */

#ifndef __STATE_H
#define __STATE_H

#include "ztypes.h"
#include "zmachine.h"

extern ZByte* state_compile  (ZStack* stack,
			      ZDWord pc,
			      ZDWord* len,
			      int compress);
extern int    state_decompile(ZByte*  state,
			      ZStack* stack,
			      ZDWord* pc,
			      ZDWord  len);
extern int    state_save     (char* filename, ZStack* stack, ZDWord  pc);
extern int    state_load     (char* filename, ZStack* stack, ZDWord* pc);
extern char*  state_fail     (void);

#endif
