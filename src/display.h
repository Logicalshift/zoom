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
 * Display prototypes
 */

/*
 * Just to pre-empt you, yes I am aware of the existence of the glk
 * standard for displays. As this is quite a nice display library, I
 * may port it at some point...
 */

#ifndef __DISPLAY_H
#define __DISPLAY_H

#include "image.h"

/***                           ----// 888 \\----                           ***/

/* Printing & housekeeping functions */
extern void printf_debug(char* format, ...);
extern void printf_info (char* format, ...);
extern void printf_info_done(void);
extern void printf_error(char* format, ...);
extern void printf_error_done(void);

extern void display_exit(int code);

/***                           ----// 888 \\----                           ***/

/* Misc functions */
extern void display_initialise  (void); /* Called on startup */
extern void display_reinitialise(void); /* Called on startup */
extern void display_finalise    (void); /* Called on shutdown */

/***                           ----// 888 \\----                           ***/

/* Output functions */
extern void display_clear     (void);
extern void display_prints    (const int*);
extern void display_prints_c  (const char*);
extern void display_printc    (int);
extern void display_printf    (const char*, ...);
extern int  display_check_char(int);

extern void display_sanitise  (void);
extern void display_desanitise(void);

/* Input functions */
extern int  display_readline(int*, int, long int);
extern int  display_readchar(long int); /* Timeout is milliseconds */

/* Information about this display module */
typedef struct
{
  /* Flags */
  int status_line;
  int can_split;
  int variable_font;
  int colours;
  int boldface;
  int italic;
  int fixed_space;
  int sound_effects;
  int timed_input;
  int mouse;

  int lines, columns;
  int width, height;
  int font_width, font_height;

  int pictures;
  int fore, back;
} ZDisplay;
extern ZDisplay* display_get_info(void);

/* Display attribute functions */

extern void display_set_title(const char* title);
extern void display_update   (void);

/* Version 1-5 display */
extern void display_set_colour  (int fore, int back);
extern void display_split       (int lines, int window);
extern void display_join        (int win1, int win2);
extern void display_set_cursor  (int x, int y);
extern void display_set_scroll  (int scroll);
extern int  display_get_cur_x   (void);
extern int  display_get_cur_y   (void);
extern int  display_set_font    (int font);
extern int  display_set_style   (int style);
extern void display_set_window  (int window);
extern int  display_get_window  (void);
extern void display_set_more    (int window,
				 int more);
extern void display_erase_window(void);
extern void display_erase_line  (int val);
extern void display_force_fixed (int window, int val);
extern void display_beep        (void);

extern void display_terminating (unsigned char* table);
extern int  display_get_mouse_x (void);
extern int  display_get_mouse_y (void);

/* Pixmap display */
extern int   display_init_pixmap    (int width, int height);
extern void  display_plot_rect      (int x, int y, 
				     int width, int height);
extern void  display_scroll_region  (int x, int y, 
				     int width, int height,
				     int xoff, int yoff);
extern void  display_pixmap_cols    (int fg, int bg);
extern void  display_plot_gtext     (int*, int style, int x, int y);
extern void  display_plot_image     (image_data*, int x, int y);
extern float display_measure_text   (int*, int style);
extern void  display_wait_for_more  (void);
extern int   display_get_font_width (void);
extern int   display_get_font_height(void);

/* Version 6 display */
extern void display_set_window (int window);

extern void display_window_define       (int window,
					 int x, int y,
					 int lmargin, int rmargin,
					 int width, int height);
extern void display_window_scroll       (int window, int pixels);
extern void display_set_newline_function(int (*func)(const int * remaining,
						     int rem_len));
extern void display_reset_windows       (void);

#endif
