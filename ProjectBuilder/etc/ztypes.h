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
 * Data types that are used to help describe the Z-Machine
 * src/ztypes.h.  Generated from ztypes.h.in by configure.
 */

#ifndef __ZTYPES_H
#define __ZTYPES_H

#include "../config.h"

typedef unsigned char  ZByte;
typedef signed short int  ZWord;
typedef unsigned short int ZUWord;
typedef int ZDWord;

#if 0==1
# define ZWORD(x) ((ZWord) ((ZUWord)x>>8)|((ZUWord)x<<8))
#else
# define ZWORD(x) x
#endif

#endif
