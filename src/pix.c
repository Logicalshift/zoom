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
 * Functions for manipulating Infocom picture files
 *
 * Presently we only support .EG1 picture files
 * Format derived from Mark Howell's pix2gif
 */

#include <stdio.h>
#include <stdlib.h>

#include "ztypes.h"
#include "zmachine.h"
#include "file.h"
#include "pix.h"

static ZFile* pix_file = NULL;

static struct
{
  ZByte  part;
  ZByte  flags;
  ZUWord images;
  ZByte  dir_size;
  ZUWord checksum;
  ZUWord version;
} pix_info;

struct picture
{
  ZUWord num;
  ZUWord width, height;
  ZUWord flags;
  ZDWord addr;
  ZDWord cm_addr;

  ZByte* data;
};

static struct picture* pix_dir = NULL;

void pix_open_file(char* filename)
{
  int x;

  if (filename == NULL)
    {
      zmachine_warning("PIX: no graphics file supplied for v6 game");
      return;
    }
  
  pix_file = open_file(filename);
  if (pix_file == NULL)
    {
      fprintf(stderr, "*** PIX: unable to open file '%s'\n", filename);
      return;
    }

  /* Read the header */
  pix_info.part = read_byte(pix_file);
  pix_info.flags = read_byte(pix_file);
  read_word(pix_file); /* Unk */
  pix_info.images = read_rword(pix_file);
  read_word(pix_file); /* Unk */
  pix_info.dir_size = read_byte(pix_file);
  read_byte(pix_file); /* Unk */
  pix_info.checksum = read_rword(pix_file);
  read_word(pix_file); /* Unk */
  pix_info.version = read_rword(pix_file);

  if (pix_info.dir_size != 12)
    zmachine_fatal("Image format not understood");
  
  pix_dir = malloc(sizeof(struct picture)*pix_info.images);
  
  /* Read the image details */
  for (x=0; x<pix_info.images; x++)
    {
      pix_dir[x].num    = read_rword(pix_file);
      pix_dir[x].width  = read_rword(pix_file);
      pix_dir[x].height = read_rword(pix_file);
      pix_dir[x].flags  = read_rword(pix_file);
      pix_dir[x].addr   =
	(read_byte(pix_file)<<16)|(read_byte(pix_file)<<8)|
	(read_byte(pix_file));
      read_byte(pix_file);
      printf("Image #%i %ix%i ($%x)\n", pix_dir[x].num, pix_dir[x].width,
	     pix_dir[x].height, pix_dir[x].addr);

      pix_dir[x].data = NULL;
    }
}

ZUWord pix_width(ZUWord picture)
{
  if (!pix_dir)
    return 1;
  
  return pix_dir[picture-1].width;
}

ZUWord pix_height(ZUWord picture)
{
  if (!pix_dir)
    return 1;
  
  return pix_dir[picture-1].height*2;
}
