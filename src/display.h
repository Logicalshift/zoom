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

/***                           ----// 888 \\----                           ***/

/* Misc functions */
extern void display_initialise  (void); /* Called on startup */
extern void display_reinitialise(void); /* Called on startup */
extern void display_finalise    (void); /* Called on shutdown */
extern void display_poll        (void); /* Called frequently to keep the display 'alive' */

/***                           ----// 888 \\----                           ***/

/* Output functions */
extern void display_clear (void);
extern void display_prints(const char*);
extern void display_printc(char);
extern void display_printf(const char*, ...);

/* Input functions */
extern int  display_readline(char*, int, long int);
extern int  display_readchar(long int timeout); /* Timeout is milliseconds */

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

  int lines, columns;
  int width, height;
  int font_width, font_height;

  int pictures;
  int fore, back;
} ZDisplay;
extern ZDisplay* display_get_info(void);

/* Display attribute functions */

extern void display_set_title(const char* title);

/* Version 1-5 display */
extern void display_set_colour  (int fore, int back);
extern void display_split       (int lines, int window);
extern void display_join        (int win1, int win2);
extern void display_set_cursor  (int x, int y);
extern void display_set_gcursor (int x, int y);
extern void display_set_scroll  (int scroll);
extern int  display_get_gcur_x  (void);
extern int  display_get_gcur_y  (void);
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

/* Version 6 display */
extern void display_set_window (int window);

extern void display_window_define       (int window,
					 int x, int y,
					 int lmargin, int rmargin,
					 int width, int height);
extern void display_window_scroll       (int window, int pixels);
extern void display_set_newline_function(int (*func)(const char* remaining,
						     int rem_len));
extern int  display_get_font_width      (void);
extern int  display_get_font_height     (void);

#endif

