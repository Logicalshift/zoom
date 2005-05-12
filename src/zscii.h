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
 * Convert ZSCII strings to ASCII
 */

#ifndef __ZSCII_H
#define __ZSCII_H

#include "ztypes.h"

#ifdef DEBUG
extern char* zscii_to_ascii        (ZByte* string, int* len);
#endif

extern int*  zscii_to_unicode      (ZByte* string, int* len);
extern int   zstrlen               (ZByte* string);
extern void  pack_zscii            (int*   string,
				   int strlen,
				   ZByte* packed,
			           int packlen);
extern void  zscii_install_alphabet(void);

extern int* zscii_unicode;

static inline unsigned char zscii_get_char(int unicode)
{
  if ((unicode >= 32 && unicode <= 127) ||
      (unicode == 10 || unicode == 13))
    return unicode;
  else if (unicode > 127)
    {
      int x;

      for (x=128; x<255; x++)
	if (zscii_unicode[x] == unicode)
	  return x;
    }
  else
    {
      int x;

      for (x=0; x<32; x++)
	if (zscii_unicode[x] == unicode)
	  return x;
    }
  
  return '?';
}

#endif
