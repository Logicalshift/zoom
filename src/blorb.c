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
 * Blorb file reading
 */

#include <stdio.h>
#include <stdlib.h>

#include "zmachine.h"
#include "file.h"
#include "blorb.h"

#include "image.h"

static inline int cmp_token(const char* data, const char* token)
{
  if (*((ZDWord*)data) == *((ZDWord*)token))
    return 1;
  else
    return 0;
}

int blorb_is_blorbfile(ZFile* file)
{
  IffForm* frm;

  frm = iff_decode_form(file);

  if (frm == NULL)
    return 0;

  if (!cmp_token(frm->id, "IFRS"))
    {
      free(frm);
      return 0;
    }

  free(frm);
  return 1;
}

BlorbFile* blorb_loadfile(ZFile* file)
{
  IffFile* iff;
  BlorbFile* res;

  int            x;
  ZDWord         index_len;
  unsigned char* data;

  if (!blorb_is_blorbfile(file))
    {
      zmachine_fatal("Programmer is a spoon: blorbfile is not a blorbfile");
      return NULL;
    }

  iff = iff_decode_file(file);
  if (iff == NULL)
    {
      zmachine_warning("Bad blorb file (no tokens)");
      return NULL;
    }

  res = malloc(sizeof(BlorbFile));
  res->file = iff;

  res->zcode_offset    = -1;
  res->release_number  = -1;
  res->game_id         = NULL;
  res->source          = file;

  res->index.offset    = -1;
  res->index.npictures = 0;
  res->index.picture   = NULL;
  res->index.nsounds   = 0;
  res->index.sound     = NULL;

  res->copyright       = NULL;
  res->author          = NULL;

  /* Decode and allocate space for each of the chunks in the file */
  for (x=0; x<iff->nchunks; x++)
    {
      if (cmp_token(iff->chunk[x].id, "RIdx"))
	{
	  /* Index chunk */
	  res->index.offset = iff->chunk[x].offset;
	  res->index.length = iff->chunk[x].length;

	  if (x != 0)
	    zmachine_warning("Blorb: Technically, the index chunk should be the very first chunk in a file. Zoom doesn't care, though");
	}
      else if (cmp_token(iff->chunk[x].id, "PNG "))
	{
	  /* PNG image chunk */
	  res->index.npictures++;
	  res->index.picture = realloc(res->index.picture,
				       sizeof(BlorbImage)*res->index.npictures);
	  res->index.picture[res->index.npictures-1].file_offset =
	    iff->chunk[x].offset;
	  res->index.picture[res->index.npictures-1].file_len =
	    iff->chunk[x].length;
	  res->index.picture[res->index.npictures-1].number = -1;
	  res->index.picture[res->index.npictures-1].width = -1;
	  res->index.picture[res->index.npictures-1].height = -1;
	  res->index.picture[res->index.npictures-1].std_n = 1;
	  res->index.picture[res->index.npictures-1].std_d = 1;
	  res->index.picture[res->index.npictures-1].min_n = 0;
	  res->index.picture[res->index.npictures-1].min_d = 1;
	  res->index.picture[res->index.npictures-1].max_n = 1;
	  res->index.picture[res->index.npictures-1].max_d = 0;

	  res->index.picture[res->index.npictures-1].loaded      = NULL;
	  res->index.picture[res->index.npictures-1].in_use      = 0;
	  res->index.picture[res->index.npictures-1].usage_count = 0;
	}
      else if (cmp_token(iff->chunk[x].id, "FORM"))
	{
	  /* FORM chunk */
	  printf("FORM chunk: most likely an AIFF iff\n");
	}
      else if (cmp_token(iff->chunk[x].id, "MOD "))
	{
	  /* MOD chunk */
	  printf("MOD chunk\n");
	}
      else if (cmp_token(iff->chunk[x].id, "SONG"))
	{
	  /* SONG chunk */
	  printf("SONG chunk\n");
	}
      else if (cmp_token(iff->chunk[x].id, "Plte"))
	{
	  /* Palette chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "Reso"))
	{
	  /* Resolution chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "Loop"))
	{
	  /* Loop chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "RelN"))
	{
	  /* Release number chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "IFhd"))
	{
	  /* Game ID chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "(c) "))
	{
	  /* Copyright chunk */
	  res->copyright = read_block(file, 
				      iff->chunk[x].offset,
				      iff->chunk[x].offset+iff->chunk[x].length);
	}
      else if (cmp_token(iff->chunk[x].id, "AUTH"))
	{
	  /* Author chunk */
	  res->author = read_block(file, 
				   iff->chunk[x].offset,
				   iff->chunk[x].offset+iff->chunk[x].length);
	}
      else if (cmp_token(iff->chunk[x].id, "ANNO"))
	{
	  /* Annotation */
	}
      else if (cmp_token(iff->chunk[x].id, "ZCOD"))
	{
	  /* Executable chunk */
	  res->zcode_offset = iff->chunk[x].offset;
	  res->zcode_len    = iff->chunk[x].length;
	}
      else
	{
	  zmachine_warning("Unknown Blorb chunk type @%x: '%.4s'",
			   iff->chunk[x].offset-8,
			   iff->chunk[x].id);
	}
    }
  
  if (res->index.offset < 0)
    {
      zmachine_fatal("Blorb: Bad file (no index chunk)");
      free(res);
      return NULL;
    }

  /* Read the index */
  data = read_block(file, res->index.offset, res->index.offset+4);
  index_len = (data[0]<<24)|(data[1]<<16)|(data[2]<<8)|data[3];
  free(data);

  if (index_len*12 + 4 != res->index.length)
    {
      zmachine_fatal("Blorb: index length indicator (%i) doesn't match length of index chunk (%i)", index_len, (res->index.length-4)/12);
      free(res);
      return NULL;
    }

  for (x=0; x<index_len; x++)
    {
      int number;
      int offset;
      
      data = read_block(file, res->index.offset + 4 + x*12,
			res->index.offset + 4 + x*12 + 12);
	  
      number = (data[4]<<24)|(data[5]<<16)|(data[6]<<8)|data[7];
      offset = (data[8]<<24)|(data[9]<<16)|(data[10]<<8)|data[11];

      if (cmp_token(data, "Pict"))
	{
	  int y;
	  int picnum;

	  /* Find the picture being referred to */
	  picnum = -1;
	  for (y=0; y<res->index.npictures; y++)
	    {
	      if (res->index.picture[y].file_offset == offset+8)
		{
		  picnum = y;
		  break;
		}
	    }
	  
	  if (picnum >= 0)
	    {
	      res->index.picture[y].number = number;
	    }
	  else
	    {
	      /* 
	       * Not found? Check to see if someone's defined a new resource 
	       * type without telling me 
	       */
	      for (y=0; y<iff->nchunks; y++)
		{
		  if (iff->chunk[y].offset == offset+8)
		    {
		      zmachine_warning("Blorb: picture #%i refers to non-picture resource type '%.4s'", number, iff->chunk[y].id);
		      picnum = y;
		      break;
		    }
		}
	      if (picnum < 0)
		zmachine_warning("Blorb: picture #%i refers to no resource", number);
	    }
	}
      else if (cmp_token(data, "Snd "))
	{
	  printf("Sound...\n");
	}
      else if (cmp_token(data, "Exec"))
	{
	  if (number != 0)
	    zmachine_warning("Blorb: There should not be more than one code resource in a file");
	  else if (offset+8 != res->zcode_offset)
	    zmachine_warning("Blorb: Code index does not match code chunk");
	}
      else
	{
	  zmachine_warning("Blorb: Unknown index type: %.4s", data);
	}

      free(data);
    }

  return res;
}

BlorbImage* blorb_findimage(BlorbFile* blb, int number)
{
  int x;
  BlorbImage* res;

  if (blb == NULL)
    return NULL;
  
  for (x=0; x<blb->index.npictures; x++)
    {
      if (blb->index.picture[x].number == number)
	{
	  res = blb->index.picture + x;
	}
    }

  if (res->loaded == NULL)
    res->loaded = image_load(blb->source, res->file_offset, res->file_len);

  return res;
}
