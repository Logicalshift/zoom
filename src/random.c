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
 * Random number generator
 */

#include <stdlib.h>

#include "zmachine.h"
#include "random.h"

/*
 * The lin_ functions form a linear congruential RNG. (X  = a*X    + c)
 *                                                      n      n-1
 * My choices for a and c may not be optimal, but we only use this to
 * generate the seed sequence for the additive generator below
 *
 * Note that lin_rand can return negative integers!
 */

static ZDWord ls = 1;
void lin_seed(ZDWord s)
{
  ls = s;
}

ZDWord lin_rand(void)
{
  ls = 8323199*ls + 1;

  return ls;
}

static ZDWord seq[55];
static int    n1 = 31;
static int    n2 = 0;

/*
 * These functions implement a Mitchell-Moore additive random number
 * generator. We generate the initial sequence of 55 numbers using the 
 * linear congruential RNG above
 */
void random_seed(int seed)
{
  int x, odd, even;

  lin_seed(seed);

  do
    {
      odd = even = 0;
      for (x=0; x<56; x++)
	{
	  seq[x] = lin_rand();
	  if (seq[x]&1)
	    odd++;
	  else
	    even++;
	}
    }
  while (odd < 5 || even < 5);

  n1 = 31;
  n2 = 0;
}

#define IncMod55(x) { x++; if (x>55) x=0; }

ZDWord random_number(void)
{
  ZDWord Xn;

  Xn = seq[n1] + seq[n2];

  seq[n2] = Xn;

  IncMod55(n1);
  IncMod55(n2);

  if (Xn < 0)
    Xn = -Xn;
  
  return Xn;
}
