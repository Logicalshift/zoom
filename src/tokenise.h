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
 * Tokenise a word/string
 */

#ifndef __TOKENISE_H
#define __TOKENISE_H

#include "zmachine.h"

extern ZDictionary* dictionary_cache(const ZUWord dict_pos);
extern void tokenise_string(unsigned int* string,
			    ZUWord dct,
			    ZByte* tokbuf,
			    int flag,
			    int add);

#endif
