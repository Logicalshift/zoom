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

/***                           ----// 888 \\----                           ***/

/* Structures */

typedef struct layout_line
{
  struct layout_text* start;
  int len;
  int offset;
  int baseline;
  int ascent;
  int descent;
  int height;
  
  struct layout_line* next;
} layout_line;

typedef struct layout_text
{
  int fg, bg;
  int font;

  int  len;
  int* text;
} layout_text;

typedef struct layout_cell_line
{
  int* cell;
  unsigned char* fg;
  unsigned char* bg;
  unsigned char* font;
} layout_cell_line;

typedef struct layout_window
{
  int   is_array;
  
  int               ar_x, ar_y;
  layout_cell_line* cellline;

  int win_x, win_y;
  
  int           am_text;
  layout_text*  text;

  layout_line* line;
} layout_window;

typedef struct layout_functions
{
  int (*font_measure)(int font, int* string);
  int (*font_height) (int font);
  int (*scroll)      (int x, int y, int w, int h, int xoff, int yoff);
  int (*redraw)      (int x, int y, int w, int h);
  int (*newline)     (void);
} layout_functions;

typedef struct layout
{
  int n_windows;
  layout_window* win;

  int cur_window;

  int font;
  int fg, bg;
  
  layout_functions fun;
} layout;

/***                           ----// 888 \\----                           ***/

/* General layout functions */

extern layout* layout_create       (layout_functions* funs);

extern void    layout_set_window   (layout* lay,
				    int win,
				    int xsize,
				    int ysize,
				    int is_array);
extern void    layout_select_window(layout* lay,
				    int win);
extern void    layout_select_colour(layout* lay,
				    int fg,
				    int bg);
extern void    layout_select_font  (layout* lay,
				    int font);
extern void    layout_output_text  (layout* lay,
				    int* text);
extern void    layout_clear_window (layout* lay,
				    int win);

#endif
