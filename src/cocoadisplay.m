/*
 *  A Z-Machine
 *  Copyright (C) 2001 Andrew Hunter
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
 * Display interface for Mac OS X (cocoa)
 */

#include "../config.h"

#if WINDOW_SYSTEM == 3

#import <Cocoa/Cocoa.h>

#include "display.h"


/***                           ----// 888 \\----                           ***/

/* Printing & housekeeping functions */
void printf_debug(char* format, ...)
{ }

void printf_info (char* format, ...)
{ }

void printf_info_done(void)
{ }

void printf_error(char* format, ...)
{ }

void printf_error_done(void)
{ }

void display_exit(int code)
{ }

/***                           ----// 888 \\----                           ***/

/* Misc functions */
void display_initialise(void)
{ }

void display_reinitialise(void)
{ }

void display_finalise(void)
{ }

/***                           ----// 888 \\----                           ***/

/* Output functions */
void display_clear(void)
{ }

void display_prints(const int* string)
{ }

void display_prints_c(const char* string)
{ }

void display_printc(int chr)
{ }

void display_printf(const char* format, ...)
{ }

int display_check_char(int chr)
{ }

/* Input functions */
int display_readline(int* buf, int buflen, long int timeout)
{ }

int display_readchar(long int timeout)
{ }

/* Display attribute functions */

void display_set_title(const char* title)
{ }

void display_update   (void)
{ }

/* Version 1-5 display */
void display_set_colour  (int fore, int back)
{ }

void display_split       (int lines, int window)
{ }

void display_join        (int win1, int win2)
{ }

void display_set_cursor  (int x, int y)
{ }

void display_set_gcursor (int x, int y)
{ }

void display_set_scroll  (int scroll)
{ }

int  display_get_gcur_x  (void)
{ }

int  display_get_gcur_y  (void)
{ }

int  display_get_cur_x   (void)
{ }

int  display_get_cur_y   (void)
{ }

int  display_set_font    (int font)
{ }

int  display_set_style   (int style)
{ }

void display_set_window  (int window)
{ }

int  display_get_window  (void)
{ }

void display_set_more    (int window,
				 int more)
{ }

void display_erase_window(void)
{ }

void display_erase_line  (int val)
{ }

void display_force_fixed (int window, int val)
{ }

void display_beep        (void)
{ }

void display_terminating (unsigned char* table)
{ }

int  display_get_mouse_x (void)
{ }

int  display_get_mouse_y (void)
{ }

/* Version 6 display */
void display_window_define       (int window,
					 int x, int y,
					 int lmargin, int rmargin,
					 int width, int height)
{ }

void display_window_scroll       (int window, int pixels)
{ }

void display_set_newline_function(int (*func)(const int * remaining,
						     int rem_len))
{ }

int  display_get_font_width      (void)
{ }

int  display_get_font_height     (void)
{ }

void display_reset_windows       (void)
{ }

/***                           ----// 888 \\----                           ***/

ZDisplay* display_get_info(void)
{ }

/***                           ----// 888 \\----                           ***/

int main(int argc, const char *argv[])
{
  return NSApplicationMain(argc, argv);
}

#endif
