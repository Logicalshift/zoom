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
 * Display for MacOS (Carbon)
 */

#include "../config.h"

#if WINDOW_SYSTEM == 3

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include <Carbon/Carbon.h>

#include "zmachine.h"
#include "display.h"
#include "zoomres.h"
#include "rc.h"
#include "hash.h"

void printf_debug(char* format, ...)
{
}

void printf_info (char* format, ...)
{
}

void printf_info_done(void)
{
}

void printf_error(char* format, ...)
{
}

void printf_error_done(void)
{
}

void display_exit(int code)
{
}

void display_initialise(void)
{
}

void display_reinitialise(void)
{
}

void display_finalise(void)
{
}

void display_clear(void)
{
}

void display_prints(const int* str)
{
}

void display_prints_c(const char* str)
{
}

void display_printc(int chr)
{
}

void display_printf(const char* format, ...)
{
}

int display_check_char(int chr)
{
}

int display_readline(int* buf, int buflen, long int timeout)
{
}

int display_readchar(long int timeout)
{
}

void display_set_title(const char* title)
{
}

void display_update(void)
{
}

void display_set_colour  (int fore, int back)
{
}

void display_split       (int lines, int window)
{
}

void display_join        (int win1, int win2)
{
}

void display_set_cursor  (int x, int y)
{
}

void display_set_gcursor (int x, int y)
{
}

void display_set_scroll  (int scroll)
{
}

int  display_get_gcur_x  (void)
{
}

int  display_get_gcur_y  (void)
{
}

int  display_get_cur_x   (void)
{
}

int  display_get_cur_y   (void)
{
}

int  display_set_font    (int font)
{
}

int  display_set_style   (int style)
{
}

void display_set_window  (int window)
{
}

int  display_get_window  (void)
{
}

void display_set_more    (int window,
				 int more)
{
}

void display_erase_window(void)
{
}

void display_erase_line  (int val)
{
}

void display_force_fixed (int window, int val)
{
}

void display_beep        (void)
{
}

void display_terminating (unsigned char* table)
{
}

int  display_get_mouse_x (void)
{
}

int  display_get_mouse_y (void)
{
}

void display_window_define       (int window,
					 int x, int y,
					 int lmargin, int rmargin,
					 int width, int height)
{
}

void display_window_scroll       (int window, int pixels)
{
}

void display_set_newline_function(int (*func)(const int * remaining,
						     int rem_len))
{
}

int  display_get_font_width      (void)
{
}

int  display_get_font_height     (void)
{
}

void display_reset_windows       (void)
{
}

ZDisplay* display_get_info(void)
{
  static ZDisplay dis;

  dis.status_line   = 1;
  dis.can_split     = 1;
  dis.variable_font = 1;
  dis.colours       = 1;
  dis.boldface      = 1;
  dis.italic        = 1;
  dis.fixed_space   = 1;
  dis.sound_effects = 0;
  dis.timed_input   = 1;
  dis.mouse         = 0;
  
  dis.lines         = 25;
  dis.columns       = 80;
  dis.width         = 80;
  dis.height        = 25;
  dis.font_width    = 1;
  dis.font_height   = 1;
  dis.pictures      = 0;
  dis.fore          = 0;
  dis.back          = 7;

  return &dis;
}

extern int zoom_main(int, char**);

int main(int argc, char** argv)
{
  RunApplicationEventLoop();
}

#endif
