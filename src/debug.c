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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "debug.h"
#include "zscii.h"

debug_breakpoint* debug_bplist = NULL;
int               debug_nbps    = 0;

int debug_set_breakpoint(int address)
{
  if (machine.memory[address] == 0xbc)
    return 0; /* Breakpoint already set */
  
  if (debug_get_breakpoint(address) != NULL)
    return 0; /* Breakpoint already set (shouldn't happen, but...) */

#ifdef DEBUG
  printf_debug("Setting BP @ %04x\n", address);
#endif

  debug_bplist = realloc(debug_bplist,
			 sizeof(debug_breakpoint)*(debug_nbps+1));
  debug_bplist[debug_nbps].address = address;
  debug_bplist[debug_nbps].original = machine.memory[address];

  machine.memory[address] = 0xbc; /* status_nop, our breakpoint */

  debug_nbps++;
  
  return 1;
}

debug_breakpoint* debug_get_breakpoint(int address)
{
  int x;

  for (x=0; x<debug_nbps; x++)
    {
      if (debug_bplist[x].address == address)
	return debug_bplist + x;
    }

  return NULL;
}
