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

#ifndef __LAYOUT_H
#define __LAYOUT_H

typedef struct layout_lines
{
  int  line_len;
  int* line_text;

  struct layout_lines* next;
} layout_lines;

typedef struct layout_window
{
  int   is_array;
  int** array;

  int   am_text;
  int*  text;

  layout_lines* line;
} layout_window;

extern void layout_set_window   (int win,
				 int xsize,
				 int ysize,
				 int is_array);
extern void layout_select_window(int win);
extern void layout_select_font  (int font);
extern void layout_output_text  (int* text);

#endif
