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

#ifndef __IMAGE_H
#define __IMAGE_H

#include "ztypes.h"
#include "file.h"

/*
 * This file is mainly here to help the display system deal with
 * images... consequently, some features may or not be implemented
 * depending on if they're actually *needed* for the display
 * type. (The routines to do with getting the actual image data being
 * the most likely suspects for this... X doesn't provide us with
 * anything particularily high-level for dealing with images, but Mac
 * OS does, so there we don't need to arse around in the actual image
 * data.)
 */

typedef struct image_data image_data; /* Black box data type */

image_data*    image_load      (ZFile* file, int offset, int len);
void           image_unload    (image_data*);
void           image_unload_rgb(image_data*);

int            image_width     (image_data*);
int            image_height    (image_data*);
unsigned char* image_rgb       (image_data*);

void           image_resample  (image_data*, int n, int d);

void           image_set_data  (image_data*, void*,
				void (*destruct)(image_data*, void*));
void*          image_get_data  (image_data*);

#endif

