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
 * Generic image routines, using libpng
 */

#include "../config.h"

#ifdef HAVE_LIBPNG

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <png.h>

#include "image.h"

struct image_data
{
  ZFile* file;
  int offset;

  png_uint_32 width, height;
  int depth, colour;

  png_bytep  image;
  png_bytep* row;

  void (*data_destruct)(image_data*, void*);
  void* data;
};

struct file_data
{
  ZFile* file;
  int    pos;
};

static void image_read(png_structp png_ptr,
		       png_bytep   data,
		       png_size_t len)
{
  struct file_data* fl;
  void* stuff;

  fl = png_get_io_ptr(png_ptr);

  stuff = read_block(fl->file, fl->pos, fl->pos+len);
  fl->pos += len;
  memcpy(data, stuff, len);
  free(stuff);
}

static image_data* iload(image_data* resin, ZFile* file, int offset, int realread)
{
  struct file_data fl;

  image_data* res;
  png_structp png;
  png_infop   png_info;
  png_infop   end_info;

  int x;

  res = resin;

  png = png_create_read_struct(PNG_LIBPNG_VER_STRING,
			       (png_voidp)NULL,
			       NULL,
			       NULL);
  if (!png)
    return NULL;
  
  png_info = png_create_info_struct(png);
  if (!png_info)
    {
      png_destroy_read_struct(&png, NULL, NULL);
      return NULL;
    }

  end_info = png_create_info_struct(png);
  if (!end_info)
    {
      png_destroy_read_struct(&png, &png_info, NULL);
      return NULL;
    }
  
  fl.file = file;
  fl.pos  = offset;
  png_set_read_fn(png, &fl, image_read);

  if (res == NULL)
    res = malloc(sizeof(image_data));

  res->file   = file;
  res->offset = offset;
  res->row    = NULL;
  res->image  = NULL;

  res->data          = NULL;
  res->data_destruct = NULL;

  png_read_info(png, png_info);
  png_get_IHDR(png, png_info,
	       &res->width, &res->height,
	       &res->depth, &res->colour,
	       NULL, NULL, NULL);

  /* We want 8-bit RGB data only */
  if (res->colour == PNG_COLOR_TYPE_GRAY ||
      res->colour == PNG_COLOR_TYPE_GRAY_ALPHA)
    png_set_gray_to_rgb(png);
  if (res->depth <= 8)
    png_set_expand(png);
  if (png_get_valid(png, png_info, PNG_INFO_tRNS)) 
    png_set_expand(png);
  if (res->depth == 16)
    png_set_strip_16(png);

  /* Update our information accordingly */
  png_read_update_info(png, png_info);
  png_get_IHDR(png, png_info,
	       &res->width, &res->height,
	       &res->depth, &res->colour,
	       NULL, NULL, NULL);

  if (realread)
    {
      res->row = malloc(sizeof(png_bytep)*res->height);
      res->image = malloc(sizeof(png_byte)*png_get_rowbytes(png, png_info)*res->height);
      
      for (x=0; x<res->height; x++)
	{
	  res->row[x] = res->image + (x*png_get_rowbytes(png, png_info));
	}
      
      png_read_image(png, res->row);

      if ((res->colour&PNG_COLOR_MASK_ALPHA) == 0)
	{
	  int old, new;

	  /* Add an alpha channel */
	  /* (png_set_filler seems to cause segfaults) */
	  res->image = realloc(res->image,
			       res->width*res->height*4);

	  new = res->width*res->height*4;
	  for (old = (res->width*res->height-1)*3; old >= 0; old-=3)
	    {
	      new-=4;

	      res->image[new]   = res->image[old];
	      res->image[new+1] = res->image[old+1];
	      res->image[new+2] = res->image[old+2];
	      res->image[new+3] = 255;
	    }

	  for (x=0; x<res->height; x++)
	    {
	      res->row[x] = res->image + (x*res->width*4);
	    }
	}
      
      png_read_end(png, end_info);
    }
  else
    {
      res->row = NULL;
      res->image = NULL;
    }
      
  png_destroy_read_struct(&png, &png_info, &end_info);

  return res;
}

image_data* image_load(ZFile* file, int offset, int length)
{
  return iload(NULL, file, offset, 0);
}

void image_unload(image_data* data)
{
  if (data == NULL)
    return;

  if (data->data != NULL)
    {
      (data->data_destruct)(data, data->data);
    }

  if (data->image != NULL)
    free(data->image);
  if (data->row != NULL)
    free(data->row);

  free(data);
}

void image_unload_rgb(image_data* data)
{
  if (data == NULL)
    return;

  if (data->image != NULL)
    free(data->image);
  if (data->row != NULL)
    free(data->row);

  data->image = NULL;
  data->row   = NULL;
}

int image_width(image_data* data)
{
  return data->width;
}

int image_height(image_data* data)
{
  return data->height;
}

unsigned char* image_rgb(image_data* data)
{
  if (data->image == NULL)
    {
      if (iload(data, data->file, data->offset, 1) == NULL)
	{
	  return NULL;
	}
    }

  return data->image;
}

void image_resample(image_data* data, int n, int d)
{
  unsigned char* newimage, *ip;
  int ny;

  int newwidth, newheight;

  int filter[3][3] =
    { { 1, 2, 1 },
      { 2, 4, 2 },
      { 1, 2, 1 } };
  
  if (data->image == NULL)
    {
      if (iload(data, data->file, data->offset, 1) == NULL)
	{
	  return;
	}
    }

  /*
   * Not a very complicated resampling w/filter routine. We use bresenham
   * to generate pixels and a 3x3 filter. The results are usually OK.
   *
   * The filtering could *definately* be better, and the resampling
   * sometimes produces the odd pixel error. Ho-hum. The aliasing
   * is usually unnoticable - dithering is the place where you'll
   * see it the most, and it's damn hard to resample dithered areas
   * properly anyway. At least, it is in reasonable time.
   */
   
  newwidth  = (data->width*n)/d;
  newheight = (data->height*n)/d;

  ip = newimage = malloc(newwidth*newheight*4);

  n *= 3; /* 3x3 filter, y'see */

  if (n >= d) /* Far more likely to happen... */
    {
      int dfx, dfy, E, NE;
      unsigned char* xp[3];
      int yp, dstx, dsty;

      int i;

      /* Minor adjustment (ensures we don't overrun) */
      if (newwidth < newheight)
	{ n = newwidth*3; d = data->width-1; }
      else
	{ n = newheight*3; d = data->height-1; }

      /* Set up for bresenham */
      dfx = dfy = 2*d-n;
      E = 2*d;
      NE = 2*(d-n);

      /* Calculate our 3 initial y positions */
      yp = 0;
      for (i=0; i<3; i++)
	{
	  xp[i] = data->row[yp];

	  /* Next position */
	  if (dfy <= 0)
	    {
	      dfy += E;
	    }
	  else
	    {
	      dfy += NE;
	      yp++;
	    }
	}

      ip = newimage; /* Current position */

      for (dsty = 0; dsty<newheight; dsty++)
	{
	  for (dstx = 0; dstx<newwidth; dstx++)
	    {
	      int rs, gs, bs, as;

	      /* Do the sampling */
	      rs = gs = bs = as = 0;

	      for (i=0; i<3; i++)
		{
		  int j;

		  for (j=0; j<3; j++)
		    {
		      rs += xp[j][0]*filter[i][j];
		      gs += xp[j][1]*filter[i][j];
		      bs += xp[j][2]*filter[i][j];
		      as += xp[j][3]*filter[i][j];
		    }

		  /* Next X */
		  if (dfx <= 0)
		    {
		      dfx += E;
		    }
		  else
		    {
		      for (j=0; j<3; j++)
			xp[j] += 4;
		      dfx += NE;
		    }
		}

	      /* Scale the sample */
	      rs >>= 4; gs >>= 4; bs >>= 4; as >>= 4;

	      /* store the sample */
	      (*ip++) = rs;
	      (*ip++) = gs;
	      (*ip++) = bs;
	      (*ip++) = as;
	    }

	  /* Next 3 y positions */
	  for (i=0; i<3; i++)
	    {
	      xp[i] = data->row[yp];

	      /* Next position */
	      if (dfy <= 0)
		{
		  dfy += E;
		}
	      else
		{
		  dfy += NE;
		  yp++;
		}
	    }

	  dfx = 2*d-n;
	}
    }
  else
    {
      /* 
       * Less likely: the new image is less than 1/3 of the size of
       * the original.
       */
      int dfx, dfy, E, NE;
      unsigned char* xp[3];
      int yp, dstx, dsty;
      int subyp;

      int i;

      /*
       * What's going on here?
       *
       * In a word - downscaling. This code won't be executed much...
       *
       * Well, bresenham's algorithm only works for slopes <= 1. So, we
       * consider the mapping this way: Bresenham tells us when we should
       * move on a pixel in the *smaller* of the two images. Now, matters
       * are complicated somewhat here, because the 'larger' image we're
       * considering is in fact 3 times larger than the 'smaller' one
       * (for the filter).
       *
       * So, to find X, the number of pixels to move in the larger image
       * for one in the smaller, we run bresenham's algorithm until it
       * moves up a pixel - each iteration indicates to move on a pixel
       * in the larger image (as above). This event indicates we should
       * move on a pixel in the smaller image (note: as well as the
       * larger). A spot of extra code to deal with the whole *3 problem,
       * and bob's yer uncle.
       *
       * Note that, as we aren't considering every pixel in the source image
       * anymore, we could introduce aliasing. But, the filtering is far
       * from perfect, so you get some aliasing anyway.
       */

      /* Minor adjustment (ensures we don't overrun) */
      if (newwidth < newheight)
	{ n = newwidth*3; d = data->width+1; }
      else
	{ n = newheight*3; d = data->height+1; }

      /* Set up for bresenham */
      dfx = dfy = 2*n-d;
      E = 2*n;
      NE = 2*(n-d);

      /* Set up initial 3 y positions*/
      yp = 0;
      subyp = 0;
      for (i=0; i<3; i++)
	{
	  xp[i] = data->row[yp];

	  /* Next position */
	  while (dfy > 0)
	    {
	      dfy += NE;
	      subyp++;
	      if (subyp >= 3)
		{ subyp = 0; yp++; }
	    }
	  subyp++; if (subyp >= 3)  { subyp = 0; yp++; }

	  dfy += E;
	}

      ip = newimage; /* Current position */

      for (dsty = 0; dsty<newheight; dsty++)
	{
	  int subx;

	  subx = 0;

	  for (dstx = 0; dstx<newwidth; dstx++)
	    {
	      int rs, gs, bs, as;

	      /* Do the sampling */
	      rs = gs = bs = 0;

	      for (i=0; i<3; i++)
		{
		  int j,k;

		  for (j=0; j<3; j++)
		    {
		      rs += xp[j][0]*filter[i][j];
		      gs += xp[j][1]*filter[i][j];
		      bs += xp[j][2]*filter[i][j];
		      as += xp[j][3]*filter[i][j];
		    }

		  /* Next X */
		  j = 0;
		  while (dfx > 0)
		    {
		      dfx += NE;
		      subx++;
		      if (subx >= 3) { subx = 0; j+=4; }
		    }
		  subx++;
		  if (subx >= 3) { subx = 0; j+=4; }

		  for (k=0; k<3; k++)
		    xp[k] += j;
		  dfx += E;
		}

	      /* Scale the sample */
	      rs >>= 4; gs >>= 4; bs >>= 4;

	      /* store the sample */
	      (*ip++) = rs;
	      (*ip++) = gs;
	      (*ip++) = bs;
	      (*ip++) = as;
	    }

	  /* Next 3 y positions */
	  for (i=0; i<3; i++)
	    {
	      xp[i] = data->row[yp];
	      
	      /* Next position */
	      while (dfy > 0)
		{
		  dfy += NE;
		  subyp++;
		  if (subyp >= 3)
		    { subyp = 0; yp++; }
		}
	      subyp++; if (subyp >= 3) { subyp=0; yp++; }
	      
	      dfy += E;
	    }

	  dfx = 2*n-d;
	}
    }

  /* Reset the data structures */
  free(data->image);

  data->image = newimage;
  data->width = newwidth;
  data->height = newheight;

  data->row = realloc(data->row, sizeof(png_bytep)*newheight);

  for (ny=0; ny<newheight; ny++)
    {
      data->row[ny] = newimage + 4*ny*newwidth;
    }
}

void image_set_data(image_data* img, void* data,
		    void (*destruct)(image_data*, void*))
{
  img->data = data;
  img->data_destruct = destruct;
}

void* image_get_data(image_data* img)
{
  return img->data;
}

#endif
