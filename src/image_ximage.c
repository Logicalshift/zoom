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
 * Routines for turning images into XImages
 *
 * Groan, moan, grah, mutter, X.
 */

/*
 * Translated, that means that dealing with X format Images is a pain
 * in the arse. You can use the X-supplied routines, but that doesn't
 * solve the problem of calculating pixels, and is dog slow. So, we
 * have this rather nasty piece of code to deal with the various ways
 * we can create these images.
 *
 * If the X consortium knew what they were up to, they might have
 * provided a simple RGB image format, and required servers to support
 * it. But they didn't. They provided us with a crappy image format
 * and verrry slow functions for accessing it.
 */

#include "../config.h"

#if WINDOW_SYSTEM == 1

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ztypes.h"
#include "zmachine.h"
#include "image.h"
#include "image_ximage.h"

#include <X11/Xlib.h>

/*
 * 16 or 32-bit truecolour images.
 */
static inline int bottombit(unsigned long mask)
{
  int bit;

  bit = 3000;

  if ((mask&0xf))
    bit = 0;
  else if ((mask&0xf0))
    bit = 4;
  else if ((mask&0xf00))
    bit = 8;
  else if ((mask&0xf000))
    bit = 12;
  else if ((mask&0xf0000))
    bit = 16;
  else if ((mask&0xf00000))
    bit = 20;
  else if ((mask&0xf000000))
    bit = 24;
  else if ((mask&0xf0000000))
    bit = 28;
  mask >>= bit;
  mask &= 0xf;
  
  if ((mask&0x1))
    return bit;
  else if ((mask&0x2))
    return bit+1;
  else if ((mask&0x4))
    return bit+2;
  else if ((mask&0x8))
    return bit+3;

  return 0;
}

static inline int topbit(unsigned long mask)
{
  int bit;

  if (mask >= 0x10000000)
    bit = 28;
  else if (mask >= 0x1000000)
    bit = 24;
  else if (mask >= 0x100000)
    bit = 20;
  else if (mask >= 0x10000)
    bit = 16;
  else if (mask >= 0x1000)
    bit = 12;
  else if (mask >= 0x100)
    bit = 8;
  else if (mask >= 0x10)
    bit = 4;
  else if (mask >= 0x1)
    bit = 0;

  mask >>= bit;

  if ((mask&0x8))
    return bit+3;
  else if ((mask&0x4))
    return bit+2;
  else if ((mask&0x2))
    return bit+1;
  else if ((mask&0x1))
    return bit;

  return 0;
}

XImage* image_to_ximage_truecolour(image_data* img,
				   Display*    display,
				   Visual*     visual)
{
  XImage* xim;
  int depth;

  int rshift, gshift, bshift;
  int rshift2, gshift2, bshift2;

  int width, height;

  int x,y;
  unsigned char* imgdata;

  int bytes_per_pixel;

  depth = DefaultDepth(display, 0);

  width = image_width(img);
  height = image_height(img);

  xim = XCreateImage(display, visual,
		     depth,
		     ZPixmap,
		     0, NULL, 
		     width, height,
		     32,
		     0);

  /*
   * People with 15-bit displays that really *are* 15-bit can go stuff
   * themselves (or they could write a new imaging routine to sort out
   * their problems)
   */
  if (xim->bits_per_pixel != 16 &&
      xim->bits_per_pixel != 24 &&
      xim->bits_per_pixel != 32)
    {
      zmachine_warning("Unable to anything useful with your display: switch to a 16- or 32-bpp display (images won't display)");
      return xim;
    }
  
  rshift = bottombit(xim->red_mask);
  gshift = bottombit(xim->green_mask);
  bshift = bottombit(xim->blue_mask);
  
  rshift2 = 8 - (topbit(xim->red_mask)+1-rshift);
  gshift2 = 8 - (topbit(xim->green_mask)+1-gshift);
  bshift2 = 8 - (topbit(xim->blue_mask)+1-bshift);

  xim->data = malloc(xim->bytes_per_line * xim->height);

  imgdata = image_rgb(img);
  bytes_per_pixel = xim->bits_per_pixel/8;

  if (xim->byte_order == LSBFirst)
    {
      for (y=0; y<height; y++)
	{
	  /* Line iterator */
	  unsigned char* row;
	  
	  row = xim->data;
	  row += y * xim->bytes_per_line;
	  
	  for (x=0; x<width; x++)
	    {
	      /* Row iterator */
	      long int pixel;
	      int z;
	      
	      pixel = 
		((imgdata[0]>>rshift2)<<rshift)|
		((imgdata[1]>>gshift2)<<gshift)|
		((imgdata[2]>>bshift2)<<bshift);
	      
	      imgdata += 3;
	      
	      for (z=0; z<bytes_per_pixel; z++)
		{
		  *(row++) = pixel;
		  pixel >>= 8;
		}
	    }
	}
    }
  else
    {
      int s;

      s = bytes_per_pixel-1;

      for (y=0; y<height; y++)
	{
	  /* Line iterator */
	  unsigned char* row;
	  
	  row = xim->data;
	  row += y * xim->bytes_per_line;
	  
	  for (x=0; x<width; x++)
	    {
	      /* Row iterator */
	      long int pixel;
	      int z;
	      
	      pixel = 
		((imgdata[0]>>rshift2)<<rshift)|
		((imgdata[1]>>gshift2)<<gshift)|
		((imgdata[2]>>bshift2)<<bshift);
	      
	      imgdata += 3;
	      
	      for (z=s; z>=0; z--)
		{
		  row[z] = pixel;
		  pixel >>= 8;
		}
	      row += bytes_per_pixel;
	    }
	}
    }
  
  return xim;
}

#endif

