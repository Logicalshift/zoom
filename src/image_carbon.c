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
 * Generic image routines
 */

/*
 * Under Carbon, we use the routines provided by QuickTime to load
 * images - this enables us to support a much wider range of image
 * types if necessary, with little extra work.
 *
 * (Feel free to compare to the blecherousness of the X imaging
 * system)
 */

#include "../config.h"

#if WINDOW_SYSTEM==3

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "image.h"

#include <Carbon/Carbon.h>
#include <QuickTime/QuickTime.h>

struct image_data
{
  Handle                  dataRef;
  GraphicsImportComponent gi;
  Rect                    bounds;
};

image_data* image_load(ZFile* file, int offset, int len)
{
  image_data* res;
  void* data;

  OSErr erm;

  /*
   * Awkward and slightly inefficient (well, very inefficient) means of
   * getting the data into a handle...
   */
  data = read_block(file, offset, offset+len);
  if (data == NULL)
    return NULL;

  res = malloc(sizeof(image_data));

  res->dataRef = NULL;
  res->gi      = NULL;

  erm = PtrToHand(data, &res->dataRef, len);
  //free(data);
  if (erm != noErr)
    {
      free(res);
      return NULL;
    }

  res->gi = 0;
  erm = GetGraphicsImporterForDataRef(data, PointerDataHandlerSubType, &res->gi);
  if (erm != noErr)
    {
      DisposeHandle(res->dataRef);
      free(res);
      return NULL;
    }

  erm = GraphicsImportGetNaturalBounds(res->gi, &res->bounds);
  if (erm != noErr)
    {
      CloseComponent(res->gi);
      DisposeHandle(res->dataRef);
      free(res);
      return NULL;
    }

  printf("Image, bounds %i, %i\n", res->bounds.right, res->bounds.bottom);

  return res;
}

int image_height(image_data* img)
{
  return img->bounds.bottom;
}

int image_width(image_data* img)
{
  return img->bounds.right;
}

#endif
