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
 * General-purpose text layout library
 */

#include <stdlib.h>

#include "zmachine.h"
#include "layout.h"

layout* layout_create(layout_functions* funs)
{
  layout* result;
  
  result = malloc(sizeof(layout));

  result->n_windows  = 0;
  result->win        = NULL;
  result->cur_window = -1;
  result->fun        = *funs;

  return result;
}

void layout_create_window(layout* lay,
			  int     win)
{
  if (lay->n_windows < win)
    {
      lay->win = malloc(sizeof(layout_window)*(win+1));

      while (lay->n_windows < win)
	{
	  lay->win[lay->n_windows].is_array = 0;
	  lay->win[lay->n_windows].cellline = NULL;
	  lay->win[lay->n_windows].ar_x     = 0;
	  lay->win[lay->n_windows].ar_y     = 0;
	  lay->win[lay->n_windows].am_text  = 0;
	  lay->win[lay->n_windows].win_x    = 0;
	  lay->win[lay->n_windows].win_y    = 0;
	  lay->win[lay->n_windows].text     = NULL;
	  lay->win[lay->n_windows].line     = NULL;
	  
	  lay->n_windows++;
	}
    }
}

void layout_set_window(layout* lay,
		       int win,
		       int xsize,
		       int ysize,
		       int is_array)
{
  int y, x;
  
  if (lay->n_windows < win)
    layout_create_window(lay, win);

  lay->win[win].is_array = is_array;

  if (is_array)
    {
      if (xsize > lay->win[win].ar_x)
	{
	}
      
      if (ysize > lay->win[win].ar_y)
	{
	  lay->win[win].cellline = realloc(lay->win[win].cellline,
					   ysize*sizeof(layout_cell_line));

	  for (y=lay->win[win].ar_y; y<ysize; y++)
	    {
	      lay->win[win].cellline[y].cell =
		malloc(sizeof(int*)*lay->win[win].ar_x);
	      lay->win[win].cellline[y].fg =
		malloc(sizeof(char*)*lay->win[win].ar_x);
	      lay->win[win].cellline[y].bg =
		malloc(sizeof(char*)*lay->win[win].ar_x);
	      lay->win[win].cellline[y].font =
		malloc(sizeof(char*)*lay->win[win].ar_x);

	      for (x=0; x<lay->win[win].ar_x; x++)
		{
		  lay->win[win].cellline[y].cell[x] = -1;
		  lay->win[win].cellline[y].fg[x]   = 0;
		  lay->win[win].cellline[y].bg[x]   = 0;
		  lay->win[win].cellline[y].font[x] = 0;
		}
	    }
	}
      lay->win[win].ar_y = ysize;
    }
  else
    {
    }
}

