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

#ifdef HAVE_XRENDER
# include <X11/extensions/Xrender.h>
#endif

struct x_data 
{
  Display* display;

  XImage* image;
  XImage* mask;

#ifdef HAVE_XRENDER
  Pixmap  pmap;
  Picture piccy;
#endif
};

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

#ifdef HAVE_XRENDER
static XRenderPictFormat* format = NULL;

XImage* image_to_ximage_render(image_data* img,
			       Display*    display,
			       Visual*     visual)
{
  XImage* xim;

  int rshift, gshift, bshift, ashift;
  int rshift2, gshift2, bshift2, ashift2;

  int width, height;

  int x,y;
  unsigned char* imgdata;

  int bytes_per_pixel;

  /* Find a suitable format... */
  if (format == NULL)
    {
      XRenderPictFormat pf;

      pf.depth = 32;
      pf.type  = PictTypeDirect;

      format = XRenderFindFormat(display,
				 PictFormatType|PictFormatDepth,
				 &pf, 0);
      if (format == NULL)
	{
	  zmachine_fatal("Unable to find a suitable format for XRender");
	  return NULL;
	}
    }

  width = image_width(img);
  height = image_height(img);

  /* Create an XImage of that format... */
  xim = XCreateImage(display, visual,
		     format->depth,
		     ZPixmap,
		     0, NULL, 
		     width, height,
		     32,
		     0);  

  /* This algorithm limits us to byte-boundaries, and a maximum of 32bpp */
  if (xim->bits_per_pixel != 16 &&
      xim->bits_per_pixel != 24 &&
      xim->bits_per_pixel != 32)
    {
      printf("Blech - %i\n", xim->bits_per_pixel);
      zmachine_warning("Unable to anything useful with your display: switch to a 16- or 32-bpp display (images won't display)");
      return xim;
    }

  /* Work out the shifts required to build our image... */  
  rshift = format->direct.red;
  gshift = format->direct.green;
  bshift = format->direct.blue;
  ashift = format->direct.alpha;
  
  /* 
   * ... I think. Damn Xrender spec is ambiguous on the meanings of the
   * masks (and it's trivial for 8888 formats)
   */
  rshift2 = 8 - (topbit(format->direct.redMask)+1);
  gshift2 = 8 - (topbit(format->direct.greenMask)+1);
  bshift2 = 8 - (topbit(format->direct.blueMask)+1);
  ashift2 = 8 - (topbit(format->direct.alphaMask)+1);

  /* Allocate image data */
  xim->data = malloc(xim->bytes_per_line * xim->height);

  imgdata = image_rgb(img);
  bytes_per_pixel = xim->bits_per_pixel/8;
  
  /* Two iterators, depending on byte order */
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
		((imgdata[2]>>bshift2)<<bshift)|
		((imgdata[3]>>ashift2)<<ashift);;
	      
	      imgdata += 4;
	      
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
		((imgdata[2]>>bshift2)<<bshift)|
		((imgdata[3]>>ashift2)<<ashift);
	      
	      imgdata += 4;
	      
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

  depth = DefaultDepth(display, (DefaultScreen(display)));

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
  
  /* Work out the shifts required to build our image... */  
  rshift = bottombit(xim->red_mask);
  gshift = bottombit(xim->green_mask);
  bshift = bottombit(xim->blue_mask);
  
  rshift2 = 8 - (topbit(xim->red_mask)+1-rshift);
  gshift2 = 8 - (topbit(xim->green_mask)+1-gshift);
  bshift2 = 8 - (topbit(xim->blue_mask)+1-bshift);

  /* Allocate image data */
  xim->data = malloc(xim->bytes_per_line * xim->height);

  imgdata = image_rgb(img);
  bytes_per_pixel = xim->bits_per_pixel/8;

  /* Two iterators, depending on byte order */
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
	      
	      imgdata += 4;
	      
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
	      
	      imgdata += 4;
	      
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

XImage* image_to_mask_truecolour(XImage*     orig,
				 image_data* img,
				 Display*    display,
				 Visual*     visual)
{
  XImage* xim;
  
  int depth, width, height;
  int bytes_per_pixel;

  int x,y;

  unsigned char* imgdata;
  
  depth = DefaultDepth(display, DefaultScreen(display));

  width = image_width(img);
  height = image_height(img);

  xim = XCreateImage(display, visual,
		     depth,
		     ZPixmap,
		     0, NULL, 
		     width, height,
		     32,
		     0);

  if (xim->bits_per_pixel != 16 &&
      xim->bits_per_pixel != 24 &&
      xim->bits_per_pixel != 32)
    {
      zmachine_warning("Unable to anything useful with your display: switch to a 16- or 32-bpp display (images won't display)");
      return xim;
    }

  xim->data = malloc(xim->bytes_per_line * xim->height);

  imgdata = image_rgb(img);
  bytes_per_pixel = xim->bits_per_pixel/8;

  for (y=0; y<height; y++)
    {
      unsigned char* row, *oldrow;

      row = xim->data + (y*xim->bytes_per_line);
      oldrow = orig->data + (y*orig->bytes_per_line);

      for (x=0; x<width; x++)
	{
	  int z;

	  if (imgdata[3] > 128)
	    {
	      for (z=0; z<bytes_per_pixel; z++)
		{
		  *(row++) = 0;
		  *(oldrow++) = 0;
		}
	    }
	  else
	    {
	      for (z=0; z<bytes_per_pixel; z++)
		*(row++) = 255;
	    }

	  imgdata += 4;
	}
    }

  return xim;
}

static void x_destruct(image_data* img, void* data)
{
  struct x_data* d;

  d = data;

  if (d->image != NULL)
    {
      XDestroyImage(d->image);
    }
  if (d->mask != NULL)
    {
      XDestroyImage(d->mask);
    }
#ifdef HAVE_XRENDER
  if (d->pmap != None)
    {
      XFreePixmap(d->display, d->pmap);
    }
  if (d->piccy != None)
    {
      XRenderFreePicture(d->display, d->piccy);
    }
#endif

  free(d);
}

void image_plot_X(image_data* img,
		  Display*  display,
		  Drawable  draw,
		  GC        gc,
		  int x, int y,
		  int n, int d)
{
  struct x_data* data;

  data = image_get_data(img);

  if (data == NULL)
    {
      data = malloc(sizeof(struct x_data));
      data->image = NULL;
      data->mask  = NULL;
      data->display = display;

#ifdef HAVE_XRENDER
      data->pmap = None;
      data->piccy = None;
#endif

      image_set_data(img, data, x_destruct);
    }

  if (data->image == NULL)
    {
      image_unload_rgb(img);
      if (n != d)
	image_resample(img, n, d);

      data->image = image_to_ximage_truecolour(img,
					       display,
					       DefaultVisual(display, DefaultScreen(display)));
    }
  if (data->mask == NULL)
    {
      data->mask = image_to_mask_truecolour(data->image,
					    img, display,
					    DefaultVisual(display, DefaultScreen(display)));
    }
  image_unload_rgb(img);

  XSetFunction(display, gc, GXand);
  XPutImage(display, draw, gc, data->mask, 0,0,0,0,
	    image_width(img), image_height(img));
  XSetFunction(display, gc, GXor);
  XPutImage(display, draw, gc, data->image, 0,0,0,0,
	    image_width(img), image_height(img));
  XSetFunction(display, gc, GXset);
}

#ifdef HAVE_XRENDER
void image_plot_Xrender(image_data* img,
			Display*  display,
			Picture   pic,
			int x, int y,
			int n, int d)
{
  struct x_data* data;

  data = image_get_data(img);

  if (data == NULL)
    {
      data = malloc(sizeof(struct x_data));
      data->image = NULL;
      data->mask  = NULL;
      data->display = display;

      data->pmap = None;
      data->piccy = None;

      image_set_data(img, data, x_destruct);
    }
  
  /* Get the format if necessary */
  if (format == NULL)
    {
      XRenderPictFormat pf;

      pf.depth = 32;
      pf.type  = PictTypeDirect;

      format = XRenderFindFormat(display,
				 PictFormatType|PictFormatDepth,
				 &pf, 0);
      if (format == NULL)
	{
	  zmachine_fatal("Unable to find a suitable format for XRender");
	  return;
	}
    }

  if (data->piccy == None)
    {
      if (data->pmap == None)
	{
	  XImage* xim;
	  GC      agc;

	  image_unload_rgb(img);
	  if (n != d)
	    image_resample(img, n, d);

	  /* Create a pixmap of the appropriate format */
	  data->pmap = XCreatePixmap(display,
				     RootWindow(display, DefaultScreen(display)),
				     image_width(img), image_height(img),
				     format->depth);
	  if (data->pmap == None)
	    return;

	  /* ... and create the XRender picture */
	  data->piccy = XRenderCreatePicture(display,
					     data->pmap,
					     format, 0, 0);

	  /* Now, create and render the image... */
	  xim = image_to_ximage_render(img, display, DefaultVisual(display, DefaultScreen(display)));

	  agc = XCreateGC(display, data->pmap, 0, NULL);
	  XPutImage(display, data->pmap, agc, xim,
		    0,0,0,0,
		    image_width(img), image_height(img));

	  XDestroyImage(xim);
	  XFreeGC(display, agc);

	  /* Destroy all data that's now unnecessary */
	  image_unload_rgb(img);
	}
    }
  
  XRenderComposite(display, PictOpOver,
		   data->piccy,
		   None,
		   pic,
		   0,0,0,0,
		   0,0,
		   image_width(img), image_height(img));
}
#endif

#endif

