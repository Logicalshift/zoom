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
 * Display for X-Windows
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#include "xdisplay.h"
#include "xfont.h"

#include "zmachine.h"
#include "display.h"
#include "rc.h"

/* #define DEBUG */

/* Globals */

Display*     x_display;
int          x_screen = 0;

/*
Font*         x_font  = NULL;
XFontStruct** x_fonti = NULL;
*/

xfont**      x_fonts = NULL;

Window       x_mainwin;
GC           x_wingc;
GC           x_caretgc;
GC           x_pixgc;

#define N_COLS 14
XColor   x_colour[N_COLS] =
{ { 0, 0xdd00,0xdd00,0xdd00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xaa00,0xaa00,0xaa00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0xff00,0xff00, DoRed|DoGreen|DoBlue, 0 },

  /* ZMachine colours start here */
  { 0, 0x0000,0x0000,0x0000, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0x0000,0x0000, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x0000,0xff00,0x0000, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0xff00,0x0000, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x0000,0x0000,0xff00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0x0000,0xff00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x0000,0xff00,0xff00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0xff00,0xcc00, DoRed|DoGreen|DoBlue, 0 },
  
  { 0, 0xbb00,0xbb00,0xbb00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x8800,0x8800,0x8800, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x4400,0x4400,0x4400, DoRed|DoGreen|DoBlue, 0 }};

#define DEFAULT_FORE 0
#define DEFAULT_BACK 7

#define N_FONTS 6
static int n_fonts = N_FONTS;

/*
 * Font 0 is the default font, font 1 is the bold font, font 2 the
 * italic font, and font 3 the fixed pitch font. Other fonts are user
 * defined (and can be set using the set_font directive)
 *
 * Window size is determined by the metrics of font 3, which should be 
 * fixed pitch if you don't want anything daft happening (note that
 * this is really the preserve of the game; this interpreter is quite
 * capable of dealing with different sized fonts)
 */

#define FIRST_ZCOLOUR 3

/*
 * In order to best support version 6, we use a pixmap to output all display
 * information to.
 */
Pixmap x_pix;

int xfont_x;
int xfont_y;
static int win_x;
static int win_y;
static int win_width;
static int win_height;
static int do_redraw = 0;

static int caret = 0;
static int caret_x, caret_y;
static int caret_h;
static int input_sx;
static int input_sy;
static int input_sh;
static int insert_mode = 1;
static int more_on = 0;

static int font_num;
static int cur_style;

static int style_font[16] = {  0, 0, 0, 0, 3, 3, 3, 3,
			      -1,-1,-1,-1,-1,-1,-1,-1 };
static int reverse = 0;

static int (*newline_func)(const int*, int) = NULL;

typedef struct history_item
{
  int* string;
  struct history_item* next;
  struct history_item* last;
} history_item;
static history_item* last_string = NULL;

/* Variables relating to the display itself */

struct window
{
  int xpos, ypos;
  int line_height;
  
  int fore, back;

  int winsx, winsy;
  int lmargin, rmargin;
  int winlx, winly;

  int text_amount;
  int no_more;
  int force_fixed;
  int no_scroll;
};

int cur_win;
struct window text_win[32];

#define CURWIN text_win[cur_win]

static int process_events(long int, int*, int);
static void draw_window(void);
static void display_more(void);

int moretext[] = { 91, 77, 79, 82, 69, 93, 0 };

/***                           ----// 888 \\----                           ***/

static inline int istrlen(const int* string)
{
  int x = 0;

  while (string[x] != 0) x++;
  return x;
}
static inline void istrcpy(int* dest, const int* src)
{
  int x;

  for (x=0; src[x] != 0; x++)
    {
      dest[x] = src[x];
    }
  dest[x] = 0;
}

static Atom x_prot[5];
static Atom wmprots;

/*
 * Start up X and get things moving
 */
void display_initialise(void)
{
  XSetWindowAttributes win_attr;
  XWindowAttributes    attr;
  rc_font*             fonts;
  rc_colour*           cols;
  int                  num;
  
  int x,y;

  x_display = XOpenDisplay(NULL);
  x_screen  = DefaultScreen(x_display);

  fonts = rc_get_fonts(&num);
  n_fonts = 0;

  xfont_initialise();

  for (x=0; x<num; x++)
    {
      if (fonts[x].num <= 0)
	zmachine_fatal("Font numbers must be positive integers");
      if (fonts[x].num > n_fonts)
	{
	  n_fonts = fonts[x].num;
	  x_fonts = realloc(x_fonts, sizeof(xfont*)*n_fonts);
	}

      x_fonts[fonts[x].num-1] = xfont_load_font(fonts[x].name);

      for (y=0; y<fonts[x].n_attr; y++)
	{
	  style_font[fonts[x].attributes[y]] = fonts[x].num-1;
	}
    }
  
  for (y=0; y<16; y++)
    {
      if (style_font[y] == -1)
	{
	  style_font[y] = style_font[8];
	}
    }
    
  xfont_x = xfont_get_width(x_fonts[3]);
  xfont_y = xfont_get_height(x_fonts[3]);;

  cols = rc_get_colours(&num);
  if (num > 11)
    {
      num = 11;
      zmachine_warning("Maximum of 11 colours");
    }
  if (num < 8)
    zmachine_warning("Supplied colourmap doesn't defined all 8 'standard' colours");

  for (x=0; x<num; x++)
    {
      x_colour[x+FIRST_ZCOLOUR].red   = cols[x].r<<8;
      x_colour[x+FIRST_ZCOLOUR].green = cols[x].g<<8;
      x_colour[x+FIRST_ZCOLOUR].blue  = cols[x].b<<8;
    }
  
  win_attr.event_mask = ExposureMask|KeyPressMask|KeyReleaseMask|StructureNotifyMask;
  win_attr.background_pixel = x_colour[0].pixel;

  /* Create the main window */
  x_mainwin = XCreateWindow(x_display,
			    RootWindow(x_display, x_screen),
			    100,100, 
			    win_width=((win_x=(xfont_x*rc_get_xsize())) + 16),
			    win_height=((win_y=(xfont_y*rc_get_ysize())) + 16),
			    1, DefaultDepth(x_display, x_screen), InputOutput,
			    CopyFromParent,
			    CWEventMask|CWBackPixel,
			    &win_attr);
  
  XMapWindow(x_display, x_mainwin);

  /* Window properties */
  {
    XTextProperty tprop;
    XSizeHints*   hints;
    XWMHints*     wmhints;
    char*         title = "Zoom " VERSION;
    char*         icon  = "Zoom";
    
    XStringListToTextProperty(&title, 1, &tprop);
    XSetWMName(x_display, x_mainwin, &tprop);
    XFree(tprop.value);
    
    XStringListToTextProperty(&icon, 1, &tprop);
    XSetWMIconName(x_display, x_mainwin, &tprop);
    XFree(tprop.value);

    hints = XAllocSizeHints();
    hints->min_width  = win_width;
    hints->min_height = win_height;
    hints->width      = win_width;
    hints->height     = win_height;
    hints->width_inc  = 2;
    hints->height_inc = 2;
    hints->flags      = PSize|PMinSize|PResizeInc;

    XSetWMNormalHints(x_display, x_mainwin, hints);
    XFree(hints);

    wmhints = XAllocWMHints();
    wmhints->input = True;
    wmhints->flags = InputHint;
    
    XSetWMHints(x_display, x_mainwin, wmhints);
    XFree(wmhints);

    x_prot[0] = XInternAtom(x_display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(x_display, x_mainwin, x_prot, 1);
    wmprots = XInternAtom(x_display, "WM_PROTOCOLS", False);
  }
  
  /* Allocate colours */
  XGetWindowAttributes(x_display, x_mainwin, &attr);
  for (x=0; x<N_COLS; x++)
    {
      if (!XAllocColor(x_display,
		       DefaultColormap(x_display, x_screen),
		       &x_colour[x]))
	{
	  fprintf(stderr, "Warning: couldn't allocate colour #%i\n", x);
	  x_colour[x].pixel = BlackPixel(x_display, x_screen);
	}
    }

  /* Create the display pixmap */
  x_pix = XCreatePixmap(x_display,
			x_mainwin,
			xfont_x*rc_get_xsize(),
			xfont_y*rc_get_ysize(),
			DefaultDepth(x_display, x_screen));

  x_wingc   = XCreateGC(x_display, x_mainwin, 0, NULL);
  x_pixgc   = XCreateGC(x_display, x_pix, 0, NULL);
  x_caretgc = XCreateGC(x_display, x_mainwin, 0, NULL);

  XSetForeground(x_display, x_caretgc,
		 x_colour[FIRST_ZCOLOUR+DEFAULT_FORE].pixel);
  XSetFunction(x_display, x_caretgc, GXxor);
  XSetLineAttributes(x_display, x_caretgc, 2, LineSolid, CapButt, JoinBevel);
  
  display_clear();
}

/*
 * When we display the menu, we use the default fonts and colours. The 
 * game might want different fonts & colours, so this frees the ones
 * we have loaded and reloads with the new ones (this also resizes the 
 * game window if necessary)
 */
void display_reinitialise(void)
{
  rc_font*    fonts;
  rc_colour*  cols;
  int         num,x,y;
  XSizeHints* hints;

  /* Deallocate resources */
  for (x=0; x<n_fonts; x++)
    {
      xfont_release_font(x_fonts[x]);
    }
  for (x=0; x<N_COLS; x++)
    {
      XFreeColors(x_display, DefaultColormap(x_display, x_screen),
		  &x_colour[x].pixel, 1, 0);
    }

  xfont_shutdown();

  /* Reallocate fonts */
  xfont_initialise();
  
  fonts = rc_get_fonts(&num);
  n_fonts = 0;

  for (x=0; x<num; x++)
    {
      if (fonts[x].num <= 0)
	zmachine_fatal("Font numbers must be positive integers");
      if (fonts[x].num > n_fonts)
	{
	  n_fonts = fonts[x].num;
	  x_fonts = realloc(x_fonts, sizeof(xfont*)*n_fonts);
	}

      x_fonts[fonts[x].num-1] = xfont_load_font(fonts[x].name);

      for (y=0; y<fonts[x].n_attr; y++)
	{
	  style_font[fonts[x].attributes[y]] = fonts[x].num-1;
	}
    }
  
  for (y=0; y<16; y++)
    {
      if (style_font[y] == -1)
	{
	  style_font[y] = style_font[8];
	}
    }
	  
  xfont_x = xfont_get_width(x_fonts[3]);
  xfont_y = xfont_get_height(x_fonts[3]);

  /* Reallocate colours */
  cols = rc_get_colours(&num);
  if (num > 11)
    {
      num = 11;
      zmachine_warning("Maximum of 11 colours");
    }

  for (x=0; x<num; x++)
    {
      x_colour[x+FIRST_ZCOLOUR].red   = cols[x].r<<8;
      x_colour[x+FIRST_ZCOLOUR].green = cols[x].g<<8;
      x_colour[x+FIRST_ZCOLOUR].blue  = cols[x].b<<8;
    }
  for (x=0; x<N_COLS; x++)
    {
      if (!XAllocColor(x_display,
		       DefaultColormap(x_display, x_screen),
		       &x_colour[x]))
	{
	  fprintf(stderr, "Warning: couldn't allocate colour #%i\n", x);
	  x_colour[x].pixel = BlackPixel(x_display, x_screen);
	}
    }
  
  win_x=(xfont_x*rc_get_xsize());
  win_y=(xfont_y*rc_get_ysize());
  
  /* Recreate pixmap */
  XFreePixmap(x_display, x_pix);
  x_pix = XCreatePixmap(x_display,
			x_mainwin,
			xfont_x*rc_get_xsize(),
			xfont_y*rc_get_ysize(),
			DefaultDepth(x_display, x_screen));

  x_pixgc   = XCreateGC(x_display, x_pix, 0, NULL);

  /* Resize main window */
  hints = XAllocSizeHints();
  hints->min_width  = win_x+16;
  hints->min_height = win_y+16;
  hints->width      = win_x+16;
  hints->height     = win_y+16;
  hints->flags      = PSize|PMinSize;  
  XSetWMNormalHints(x_display, x_mainwin, hints);
  XFree(hints);
  
  XResizeWindow(x_display, x_mainwin,
		win_width=(win_x+16),
		win_height=(win_y+16));

  display_clear();
}

/*
 * Shuts down
 */
void display_finalise(void)
{
  XFreePixmap(x_display, x_pix);
  XDestroyWindow(x_display, x_mainwin);
  XCloseDisplay(x_display);
}

/*
 * Sets the title of the window to the given string
 */
void display_set_title(const char* title)
{
  XTextProperty tprop;
  char *t;

  t = malloc(sizeof(char)*300);
  sprintf(t, "Zoom " VERSION " - %s", title);
    
  XStringListToTextProperty(&t, 1, &tprop);
  XSetWMName(x_display, x_mainwin, &tprop);
  XFree(tprop.value);

  free(t);
}

/*
 * Blanks the (entire) display and resets window positions
 */
void display_clear(void)
{
  cur_win = 0;
  text_win[0].xpos = 0;
  text_win[0].ypos = win_y;
  text_win[0].fore = DEFAULT_FORE;
  text_win[0].back = DEFAULT_BACK;
  text_win[0].line_height = 0;
  text_win[0].winsx = text_win[0].winsy = 0;
  text_win[0].lmargin = text_win[0].rmargin = 0;
  text_win[0].winlx = win_x;
  text_win[0].winly = win_y;
  text_win[0].text_amount = 0;
  text_win[0].no_more = 0;
  text_win[0].force_fixed = 0;
  text_win[0].no_scroll = 0;
  
  XSetForeground(x_display, x_pixgc, x_colour[FIRST_ZCOLOUR+DEFAULT_BACK].pixel);

  XFillRectangle(x_display, x_pix, x_pixgc, 0, 0, win_x, win_y);
}

/*
 * Does a quick newline (also handles [MORE] display)
 */
static void new_line(int more)
{
  CURWIN.ypos += CURWIN.line_height;
  CURWIN.text_amount += CURWIN.line_height;
  
  CURWIN.xpos = CURWIN.winsx + CURWIN.lmargin;
  if (font_num >= 0)
    CURWIN.line_height = xfont_get_height(x_fonts[font_num]);
  else
    CURWIN.line_height = xfont_y;

  if ((CURWIN.ypos+CURWIN.line_height) > CURWIN.winly)
    {
      if (CURWIN.no_scroll)
	{
#ifdef DEBUG
	  printf("Scrolling is off - wrapped\n");
#endif
	  CURWIN.ypos -= (CURWIN.ypos+CURWIN.line_height)-CURWIN.winly;
	}
      else
	{
	  int scrollby;
	  
	  scrollby = (CURWIN.ypos+CURWIN.line_height)-CURWIN.winly;
	  
	  if (CURWIN.text_amount + scrollby > CURWIN.winly-CURWIN.winsy &&
	      CURWIN.winly != CURWIN.winsy)
	    {
	      if (!CURWIN.no_more && more == -1)
		{
		  display_more();
		}
	      CURWIN.text_amount = 0;
	    }
	  if (more == 1 && !CURWIN.no_more)
	    {
	      display_more();
	    }
	  
	  /* Need to scroll window */
	  XCopyArea(x_display, x_pix, x_pix, x_pixgc, 
		    CURWIN.winsx, CURWIN.winsy+scrollby,
		    CURWIN.winlx-CURWIN.winsx, (CURWIN.winly-CURWIN.winsy)-scrollby,
		    CURWIN.winsx, CURWIN.winsy);
	  
	  XSetForeground(x_display, x_pixgc,
			 x_colour[FIRST_ZCOLOUR+CURWIN.back].pixel);
	  XFillRectangle(x_display, x_pix, x_pixgc,
			 CURWIN.winsx, CURWIN.winly-scrollby,
			 CURWIN.winlx-CURWIN.winsx, scrollby);
	  
	  CURWIN.ypos -= scrollby;
	}
    }  
}

/*
 * Displays the 'more' prompt
 */
static void display_more(void)
{
  more_on = 1;
  draw_window();
  display_readchar(0);
  more_on = 0;
  do_redraw = 1;
}

/*
 * Outputs a string - this must not contain newline characters
 * This function performs word wrapping
 */
static int outputs(const int* string, int font, int len, int split)
{
  int width, height;
  int oldheight;

  if (CURWIN.winsy >= CURWIN.winly)
    {
      return 0;
    }

  width  = xfont_get_text_width(x_fonts[font], string, len);
  height = xfont_get_height(x_fonts[font]);

  if (split && CURWIN.xpos+width > CURWIN.winlx)
    {
      int word_start, word_len, total_len, xpos, x;

      /*
       * FIXME: infinite recursion (yeearrrgh) if a single word is
       * longer than a line
       */
      
      word_start = 0;
      total_len = 0;
      word_len = 0;
      xpos = CURWIN.xpos;

      for (x=0; x<len; x++)
	{
	  if (string[x] == ' ' || x==(len-1))
	    {
	      /* We've got a word */
	      xpos += xfont_get_text_width(x_fonts[font],
					   string + word_start,
					   word_len+1);

	      if (xpos > CURWIN.winlx-CURWIN.rmargin)
		{
		  int more = -1;
		  outputs(string, font, total_len, 0);

		  if (newline_func != NULL)
		    more = (newline_func)(string + total_len, len - total_len);

		  if (more == 2)
		    {
		      return 1;
		    }

		  new_line(more);
		  
		  return outputs(string + total_len,
				 font, len - total_len, 1);
		}
	      
	      total_len += word_len + 1;
	      word_start = total_len;
	      word_len = 0;
	    }
	  else
	    {
	      word_len++;
	    }
	}
      
      return 0;
    }

  oldheight = CURWIN.line_height;
  if (height > oldheight)
    CURWIN.line_height = height;
  
  if ((CURWIN.ypos+CURWIN.line_height) > CURWIN.winly && !CURWIN.no_scroll)
    {
      int scrollby;
      
      scrollby = (CURWIN.ypos+CURWIN.line_height)-CURWIN.winly;

      if (CURWIN.text_amount + scrollby > CURWIN.winly-CURWIN.winsy &&
	  !CURWIN.no_scroll)
	{
	  if (!CURWIN.no_more)
	    {
	      display_more();
	    }
	  CURWIN.text_amount = 0;
	}

      if (CURWIN.no_scroll)
	{
	  CURWIN.ypos-=scrollby;
	}
      else
	{
	  /* Need to scroll window */
	  XCopyArea(x_display, x_pix, x_pix, x_pixgc, 
		    CURWIN.winsx, CURWIN.winsy+scrollby,
		    CURWIN.winlx-CURWIN.winsx, CURWIN.winly-scrollby,
		    CURWIN.winsx, CURWIN.winsy);
	  
	  XSetForeground(x_display, x_pixgc,
			 x_colour[FIRST_ZCOLOUR+CURWIN.back].pixel);
	  XFillRectangle(x_display, x_pix, x_pixgc,
			 CURWIN.winsx, CURWIN.winly-scrollby,
			 CURWIN.winlx-CURWIN.winsx, scrollby);
	  
	  CURWIN.ypos -= scrollby;
	}
    }

  if (height > oldheight)
    {
      int scrollby;

      scrollby = height - oldheight;
      
      /* Need to scroll window (again) */
      XCopyArea(x_display, x_pix, x_pix, x_pixgc, 
		CURWIN.winsx, CURWIN.ypos,
		CURWIN.winlx-CURWIN.winsx, oldheight,
		CURWIN.winsx, CURWIN.ypos+scrollby);

      /*
       * This isn't ideal: Jigsaw fails if we set this to the current
       * background colour, and Beyond zork fails if we do this. Errrgh
       */
      XSetForeground(x_display, x_pixgc,
		     x_colour[FIRST_ZCOLOUR+DEFAULT_BACK].pixel);
      XFillRectangle(x_display, x_pix, x_pixgc,
		     CURWIN.winsx, CURWIN.ypos,
		     CURWIN.winlx, scrollby);
    }  
  
  XSetForeground(x_display, x_pixgc,
		 x_colour[CURWIN.back+FIRST_ZCOLOUR].pixel);
  XFillRectangle(x_display, x_pix, x_pixgc,
		 CURWIN.xpos, CURWIN.ypos,
		 width, CURWIN.line_height);	 

  xfont_set_colours(CURWIN.fore+FIRST_ZCOLOUR, CURWIN.back+FIRST_ZCOLOUR);

  xfont_plot_string(x_fonts[font],
		    x_pix,
		    x_pixgc,
		    CURWIN.xpos,
		    CURWIN.ypos+CURWIN.line_height-xfont_get_descent(x_fonts[font]),
		    string, len);

  do_redraw = 1;

  CURWIN.xpos += width;

  return 0;
}

/*
 * printf (a convenience function, calls prints)
 */
void display_printf(const char* format, ...)
{
  va_list* ap;
  char     string[512];
  int x,len;
  int      istr[512];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

  len = strlen(string);
  
  for (x=0; x<=len; x++)
    {
      istr[x] = string[x];
    }
  display_prints(istr);
}

/*
 * prints - prints a string on the display
 */
void display_prints(const int* string)
{
  int x, lp, ls, oldfont;

#ifdef DEBUG
  printf("Output (at %i, %i - lineheight is %i) >%s<\n", CURWIN.xpos, CURWIN.ypos, CURWIN.line_height, string);
#endif
  
  lp = ls = 0;

  oldfont = font_num;
  if (CURWIN.force_fixed && font_num >= 0)
    {
      display_set_font(style_font[((cur_style|8)>>1)&15]);
    }

  if (reverse)
    {
      int tmp;

      tmp = CURWIN.fore;
      CURWIN.fore = CURWIN.back;
      CURWIN.back = tmp;
    }
  
  for (x=0; string[x] != 0; x++, lp++)
    {
      if (string[x] == 10)
	{
	  int more = -1;
	  
	  outputs(string + ls, font_num, lp, 1);

	  if (newline_func != NULL)
	    {
	      more = (newline_func)(string + ls + lp + 1,
				    istrlen(string)-lp-ls-1);
	    }

	  new_line(more);

	  if (more == 2)
	    return;
	  
	  ls += lp+1;
	  lp = -1;
	}
    }
  outputs(string + ls, font_num, lp, 1);

  if (reverse)
    {
      int tmp;

      tmp = CURWIN.fore;
      CURWIN.fore = CURWIN.back;
      CURWIN.back = tmp;
    }

  if (CURWIN.force_fixed)
    oldfont = display_set_font(oldfont);
}

void display_prints_c(const char* string)
{
  int* txt;
  int x, len;

  txt = malloc((len=strlen(string))*sizeof(int)+sizeof(int));
  for (x=0; x<=len; x++)
    {
      txt[x] = string[x];
    }
  display_prints(txt);
  free(txt);
}

/*
 * Read a character from the console
 */
int display_readchar(long int timeout)
{
  CURWIN.text_amount = 0;
    
  return process_events(timeout, NULL, 0);
}

/*
 * Read a line of text from the console
 */
int display_readline(int* buf, int buflen, long int timeout)
{
  int result;
  
  CURWIN.text_amount = 0;
  
  result = process_events(timeout, buf, buflen);
#ifdef DEBUG
  printf("Input >%s<\n", buf);
#endif

  if (result)
    new_line(0);

  return result;
}

/*
 * Actually plots the game window
 */
static void draw_window(void)
{
  int top, left, bottom, right;
  
  left   = (win_width-win_x)>>1;
  top    = (win_height-win_y)>>1;
  right  = left + win_x;
  bottom = top + win_y;
  /* Draw the text area */
  XCopyArea(x_display, x_pix, x_mainwin,
	    x_wingc, 0,0, win_x, win_y,
	    left, top);
  
  /* Draw the beveled border */
  XSetForeground(x_display, x_wingc, x_colour[0].pixel);
  XFillRectangle(x_display, x_mainwin, x_wingc,
		 0,0, left, bottom);
  XFillRectangle(x_display, x_mainwin, x_wingc,
		 0,0, right, top);
  
  XFillRectangle(x_display, x_mainwin, x_wingc,
		 0, bottom, win_width, top);
  XFillRectangle(x_display, x_mainwin, x_wingc,
		 right, 0, left, bottom);
  
  XSetLineAttributes(x_display, x_wingc, 2, LineSolid,
		     CapProjecting, JoinBevel);
  XSetForeground(x_display, x_wingc, x_colour[1].pixel);
  XDrawLine(x_display, x_mainwin, x_wingc,
	    left-1, top-1, right+1, top-1);
  XDrawLine(x_display, x_mainwin, x_wingc,
	    left-1, top-1, left-1, bottom+1);
  
  XSetForeground(x_display, x_wingc, x_colour[2].pixel);
  XDrawLine(x_display, x_mainwin, x_wingc,
	    right+1, bottom+1, right+1, top);
  XDrawLine(x_display, x_mainwin, x_wingc,
	    right+1, bottom+1, left, bottom+1);

  /* Draw the caret */
  if (caret)
    XDrawLine(x_display, x_mainwin, x_caretgc,
	      caret_x+left, caret_y+top, caret_x+left, caret_y+top+caret_h);

  if (more_on)
    {
      int w;

      w = xfont_get_text_width(x_fonts[3], moretext, 6);
      XSetForeground(x_display, x_wingc,
		     x_colour[FIRST_ZCOLOUR+6].pixel);
      XFillRectangle(x_display, x_mainwin, x_wingc,
		     win_width-w-2,
		     win_height-xfont_get_height(x_fonts[3])-2,
		     w, xfont_get_height(x_fonts[3]));

      xfont_set_colours(FIRST_ZCOLOUR+0, FIRST_ZCOLOUR+6);

      xfont_plot_string(x_fonts[3],
			x_mainwin,
			x_wingc,
			win_width-w-2,
			win_height-xfont_get_descent(x_fonts[3])-2,
			moretext, 6);
    }
}

/*
 * Display the text we're currently editting
 */
static void draw_input_text(int* buf, int inputpos)
{
  int width;
  int len;

  len = istrlen(buf);

  /* Hide the caret */
  if (caret)
    {
      XDrawLine(x_display, x_mainwin, x_caretgc,
		caret_x+((win_width-win_x)>>1),
		caret_y+((win_height-win_y)>>1),
		caret_x+((win_width-win_x)>>1),
		caret_y+((win_height-win_y)>>1)+caret_h);
      caret = 0;
    }

  /* Erase any old text */
  XSetForeground(x_display, x_pixgc,
		 x_colour[CURWIN.back+FIRST_ZCOLOUR].pixel);
  XFillRectangle(x_display, x_pix, x_pixgc,
		 input_sx, input_sy,
		 CURWIN.winlx, input_sh);	 

  width = xfont_get_text_width(x_fonts[font_num], buf, len);

  if (input_sx+width < CURWIN.winlx)
    {
      /* It all fits in */
      xfont_set_colours(CURWIN.fore+FIRST_ZCOLOUR,
			CURWIN.back+FIRST_ZCOLOUR);
      xfont_plot_string(x_fonts[font_num], x_pix, x_pixgc,
			input_sx,
			input_sy+xfont_get_ascent(x_fonts[font_num]),
			buf, len);
      caret_x = input_sx+xfont_get_text_width(x_fonts[font_num], buf, inputpos);
    }
  else
    {
      int width_l, width_r;
      XRectangle clip[1];
      GC tempgc;

      tempgc = XCreateGC(x_display, x_pix, 0, NULL);

      xfont_set_colours(CURWIN.fore+FIRST_ZCOLOUR, CURWIN.back+FIRST_ZCOLOUR);
      
      width_l   = xfont_get_text_width(x_fonts[font_num], buf, inputpos);
      width_r   = xfont_get_text_width(x_fonts[font_num],
				       buf+inputpos, len-inputpos);

      clip[0].x = input_sx;
      clip[0].y = input_sy;
      clip[0].width = CURWIN.winlx - input_sx;
      clip[0].height = input_sh;
      XSetClipRectangles(x_display, tempgc, 0, 0, clip, 1, Unsorted);

      if (width_l < (CURWIN.winlx-input_sx))
	{
	  xfont_plot_string(x_fonts[font_num],
			    x_pix, tempgc,
			    input_sx,
			    input_sy+xfont_get_ascent(x_fonts[font_num]),
			    buf, len);
	  
	  caret_x = input_sx+width_l;
	}
      else if (width_r < (CURWIN.winlx-input_sx))
	{
	  xfont_plot_string(x_fonts[font_num],
			    x_pix, tempgc,
			    CURWIN.winlx-width,
			    input_sy+xfont_get_ascent(x_fonts[font_num]),
			    buf, len);

	  caret_x = CURWIN.winlx - width_r;
	}
      else
	{
	  xfont_plot_string(x_fonts[font_num],
			    x_pix, tempgc,
			    (input_sx+3*((CURWIN.winlx-input_sx)/4))-width_l,
			    input_sy+xfont_get_ascent(x_fonts[font_num]),
			    buf, len);
	  caret_x = input_sx+3*((CURWIN.winlx-input_sx)/4);
	}

      XFreeGC(x_display, tempgc);
    }
      
  XCopyArea(x_display, x_pix, x_mainwin, x_wingc, 
	    input_sx, input_sy,
	    CURWIN.winlx-input_sx, input_sh,
	    input_sx+((win_width-win_x)>>1), input_sy+((win_height-win_y)>>1));

  /* Redisplay the caret */
  if (insert_mode)
    XSetLineAttributes(x_display, x_caretgc, 2, LineSolid,
		       CapButt, JoinBevel);
  else
    XSetLineAttributes(x_display, x_caretgc, 4, LineSolid,
		       CapButt, JoinBevel);
  
  XDrawLine(x_display, x_mainwin, x_caretgc,
	    caret_x+((win_width-win_x)>>1),
	    caret_y+((win_height-win_y)>>1),
	    caret_x+((win_width-win_x)>>1),
	    caret_y+((win_height-win_y)>>1)+caret_h);
  caret = 1;
}

/*
 * Called periodically when the interpreter thinks the display would
 * benefit from being updated.
 */
void display_update(void)
{
  if (do_redraw)
    draw_window();
}

/*
 * Process X events
 */
int process_events(long int to, int* buf, int buflen)
{
  static unsigned char keybuf[20];
  static int     bufsize = 0;
  static int     bufpos;
  int            connection_num;
  struct timeval timeout;
  struct timeval now;
  int            inputpos = 0;
  int            x;
  KeySym         ks;
  history_item*  history = NULL;

  caret = 0;

  caret_x = CURWIN.xpos;
  caret_y = CURWIN.ypos;
  caret_h = CURWIN.line_height;

  XSetForeground(x_display, x_caretgc,
		 x_colour[FIRST_ZCOLOUR+1].pixel^x_colour[FIRST_ZCOLOUR+CURWIN.back].pixel);

  /* display_prints(" "); */  CURWIN.xpos = caret_x;
  do_redraw = 1;
      
  if (buf != NULL)
    {
      /* Display any text that's already in the buffer */
      input_sx = CURWIN.xpos;
      input_sy = CURWIN.ypos;
      input_sh = CURWIN.line_height;
      
      inputpos = istrlen(buf);
      
      draw_input_text(buf, inputpos);
    }

  if (do_redraw)
    draw_window();
  do_redraw = 0;

  if (bufsize > 0)
    {
      bufsize--;
      return keybuf[bufpos++];
    }

  connection_num = ConnectionNumber(x_display);

  gettimeofday(&now, NULL);
  timeout.tv_sec  = now.tv_sec + (to/1000);
  timeout.tv_usec = now.tv_usec + ((to%1000)*1000);
  timeout.tv_sec += timeout.tv_usec/1000000;
  timeout.tv_usec %= 1000000;
  
  while (1) 
    {
      XEvent ev;
      fd_set readfds;
      struct timeval tv;
      int isevent;
      int flash;

      FD_ZERO(&readfds);
      FD_SET(connection_num, &readfds);

      flash = 0;

      if (to != 0)
	{
	  gettimeofday(&now, NULL);
	  tv.tv_sec  = timeout.tv_sec - now.tv_sec;
	  tv.tv_usec = timeout.tv_usec - now.tv_usec;

	  tv.tv_sec  += tv.tv_usec/1000000;
	  tv.tv_usec %= 1000000;

	  if (tv.tv_usec < 0)
	    {
	      tv.tv_usec += 1000000;
	      tv.tv_sec  -= 1;
	    }

	  if (tv.tv_sec < 0)
	    {
	      if (buf != NULL)
		{
		  /* Erase any old text */
		  XSetForeground(x_display, x_pixgc,
				 x_colour[CURWIN.back+FIRST_ZCOLOUR].pixel);
		  XFillRectangle(x_display, x_pix, x_pixgc,
				 input_sx, input_sy,
				 CURWIN.winlx-input_sx, input_sh);  
		}
	      return 0;
	    }
	}

      if ((tv.tv_sec >= 1 || to == 0) && caret_y+caret_h <= win_y)
	{
	  tv.tv_sec  = 0;
	  tv.tv_usec = 400000;
	  flash = 1;
	}

      isevent = 0;
      if (XPending(x_display))
	isevent = 1;
      else if (select(connection_num+1, &readfds, NULL, NULL,
		      (to==0&&flash==0)?NULL:&tv))
	isevent = 1;

      if (!isevent && flash)
	{
	  caret = !caret;
	  XDrawLine(x_display, x_mainwin, x_caretgc,
		    caret_x+((win_width-win_x)>>1),
		    caret_y+((win_height-win_y)>>1),
		    caret_x+((win_width-win_x)>>1),
		    caret_y+((win_height-win_y)>>1)+caret_h);
	  continue;
	}
      
      if (isevent)
	{
	  XNextEvent(x_display, &ev);
	  
	  switch (ev.type)
	    {
	    case KeyPress:	      
	      bufpos = 0;
	      bufsize = XLookupString(&ev.xkey, keybuf, 20, NULL, NULL);
	      
	      if (buf == NULL)
		{
		  x = 1;
		  for (ks=XLookupKeysym(&ev.xkey, x++); ks != NoSymbol;
		       ks=XLookupKeysym(&ev.xkey, x++))
		    {
		      switch (ks)
			{
			case XK_Left:
			  keybuf[bufsize++] = 131;
			  break;
			  
			case XK_Right:
			  keybuf[bufsize++] = 132;
			  break;
			  
			case XK_Up:
			  keybuf[bufsize++] = 129;
			  break;
			  
			case XK_Down:
			  keybuf[bufsize++] = 130;
			  break;
			  
			case XK_Delete:
			  keybuf[bufsize++] = 8;
			  break;
			}
		    }
		  
		  if (bufsize > 0)
		    {
		      bufsize--;
		      return keybuf[bufpos++];
		    }
		}
	      else
		{
		  int x, y;

		  x = 1;
		  for (ks=XLookupKeysym(&ev.xkey, x++); ks != NoSymbol;
		       ks=XLookupKeysym(&ev.xkey, x++))
		    {
		      switch (ks)
			{
			case XK_Left:
			  if (inputpos>0)
			    inputpos--;
			  break;

			case XK_Right:
			  if (buf[inputpos] != 0)
			    inputpos++;
			  break;

			case XK_Up:
			  if (history == NULL)
			    history = last_string;
			  else
			    if (history->next != NULL)
			      history = history->next;
			  if (history != NULL)
			    {
			      if (istrlen(history->string) < buflen)
				istrcpy(buf, history->string);
			      inputpos = istrlen(buf);
			    }
			  break;

			case XK_Down:
			  if (history != NULL)
			    {
			      history = history->last;
			      if (history != NULL)
				{
				  if (istrlen(history->string) < buflen)
				    istrcpy(buf, history->string);
				  inputpos = istrlen(buf);
				}
			      else
				{
				  buf[0] = 0;
				  inputpos = 0;
				}
			    }
			  break;

			case XK_Home:
			  inputpos = 0;
			  break;

			case XK_Insert:
			  insert_mode = !insert_mode;
			  break;

			case XK_End:
			  inputpos = istrlen(buf);
			  break;

			case XK_BackSpace:
			case XK_Delete:
			  if (inputpos == 0)
			    break;
			  
			  if (buf[inputpos] == 0)
			    buf[--inputpos] = 0;
			  else
			    {
			      for (y=inputpos-1; buf[y] != 0; y++)
				buf[y] = buf[y+1];
			      inputpos--;
			    }
			  break;

			case XK_Return:
			  {
			    history_item* newhist;

			    newhist = malloc(sizeof(history_item));
			    newhist->last = NULL;
			    newhist->next = last_string;
			    if (last_string)
			      last_string->last = newhist;
			    newhist->string = malloc(sizeof(int)*(istrlen(buf)+1));
			    istrcpy(newhist->string, buf);
			    last_string = newhist;
			  }
			  bufsize = 0;
			  return 1;
			}
		    }
		  
		  for (x=0; x<bufsize; x++)
		    {
		      if (istrlen(buf) >= buflen)
			break;
		      
		      if (keybuf[x]>31 && keybuf[x]<127)
			{
			  if (buf[inputpos] == 0)
			    {
			      buf[inputpos+1] = 0;
			      buf[inputpos++] = keybuf[x];
			    }
			  else
			    {
			      if (insert_mode)
				{
				  for (y=istrlen(buf)+1; y>inputpos; y--)
				    {
				      buf[y] = buf[y-1];
				    }
				}
			      buf[inputpos++] = keybuf[x];
			    }
			}
		    }
		  
		  bufsize = 0;

		  draw_input_text(buf, inputpos);
		}
	      break;

	    case ConfigureNotify:
	      win_width = ev.xconfigure.width;
	      win_height = ev.xconfigure.height;
	      break;

	    case ClientMessage:
	      if (ev.xclient.message_type == wmprots)
		{
		  if (ev.xclient.data.l[0] == x_prot[0])
		    {
		      exit(0);
		    }
		}
	      break;
	      
	    case Expose:
	      draw_window();
	      break;
	    }
	}
      else
	{
	  if (buf != NULL)
	    {
	      /* Erase any old text */
	      XSetForeground(x_display, x_pixgc,
			     x_colour[CURWIN.back+FIRST_ZCOLOUR].pixel);
	      XFillRectangle(x_display, x_pix, x_pixgc,
			     input_sx, input_sy,
			     CURWIN.winlx-input_sx, input_sh);  
	    }
	  return 0;
	}
    }
}

/*
 * Goes beep
 */
void display_beep(void)
{
  XBell(x_display, 70);
}

/***                           ----// 888 \\----                           ***/

/*
 * Sets the colours that all future text will be plotted in.
 */
void display_set_colour(int fore, int back)
{
  if (fore == -1)
    fore = DEFAULT_FORE;
  if (back == -1)
    back = DEFAULT_BACK;
  if (fore == -2)
    fore = CURWIN.fore;
  if (back == -2)
    back = CURWIN.back;

  CURWIN.fore = fore;
  CURWIN.back = back;
}

/*
 * Sets the font we will plot in in future (this uses Z-Machine font
 * numbers rather than internal ones)
 */
int display_set_font(int font)
{
  int old_font;

  if (font == -1)
    display_set_style(-16);
  
  if (font < 0)
    return 0;
  if (font >= n_fonts)
    return 0;

  old_font = font_num;
  font_num = font;

  return old_font;
}

/*
 * Sets whether or not the current window should scroll or not
 */
void display_set_scroll(int scroll)
{
  CURWIN.no_scroll = !scroll;
}

/*
 * Sets the style to use (the style is a bitfield, bit 0 is reverse,
 * bit 1 is bold, bit 2 is italic, bit 3 is fixed-pitch and bit 4 is
 * symbolic)
 */
int display_set_style(int style)
{
  int old_style;

  if (font_num < 0)
    return style;

  old_style = cur_style;
  
  if (style == 0)
    cur_style = 0;
  else
    {
      if (style > 0)
	cur_style |= style;
      else
	cur_style &= ~(-style);
    }

  display_set_font(style_font[(cur_style>>1)&15]);
  
  reverse = cur_style&1;

  return old_style;
}

/*
 * Fills in a ZDisplay block to tell the interpreter about our display
 * (this should be a static block, as this gets called more than once
 * for v6 games)
 */
ZDisplay* display_get_info(void)
{
  static ZDisplay info;

  info.status_line = 1;
  info.can_split = 1;
  info.variable_font = 1;
  info.colours = 1;
  info.boldface = 1;
  info.italic = 1;
  info.fixed_space = 1;
  info.sound_effects = 0;
  info.timed_input = 1;
  info.lines = rc_get_ysize();
  info.columns = rc_get_xsize();
  info.width = win_x;
  info.height = win_y;
  info.font_width  = xfont_x;
  info.font_height = xfont_y;
  info.fore = DEFAULT_FORE;
  info.back = DEFAULT_BACK;
  info.mouse = 1;
  
  info.pictures = 0;

  return &info;
}

/*
 * Splits a window in two at the given offset (lines is from the top
 * of the window). The window number specifies the number of the
 * future upper window.
 */
void display_split(int lines, int window)
{
  text_win[window].winsx       = CURWIN.winsx;
  text_win[window].winlx       = CURWIN.winlx;
  text_win[window].winsy       = CURWIN.winsy;
  text_win[window].winly       = CURWIN.winsy + xfont_y*lines;
  text_win[window].fore        = CURWIN.fore;
  text_win[window].back        = CURWIN.back;
  text_win[window].text_amount = 0;
  text_win[window].no_more     = 1;
  text_win[window].xpos        = CURWIN.winsx;
  text_win[window].ypos        = CURWIN.winsy;
  text_win[window].force_fixed = 0;
  text_win[window].no_scroll   = 0;
  text_win[window].line_height = xfont_y;

#ifdef DEBUG
  printf("Bottom of window is now %i\n", text_win[window].winly);
#endif
  
  CURWIN.winsy += xfont_y*lines;
  if (CURWIN.ypos < CURWIN.winsy)
    CURWIN.ypos = CURWIN.winsy;
}

/*
 * Joins two windows that were previously split
 */
void display_join(int window1, int window2)
{
  if (text_win[window1].winsy != text_win[window2].winly)
    return; /* Windows can't be joined */
  text_win[window1].winsy = text_win[window2].winsy;
  text_win[window2].winly = text_win[window2].winsy;
}

/*
 * Sets the current window
 */
void display_set_window(int window)
{
  if (window < 0)
    zmachine_fatal("Can't set window to %i", window);
  text_win[window].fore = CURWIN.fore;
  text_win[window].back = CURWIN.back;
  cur_win = window;
}

/*
 * Gets the current window number
 */
int display_get_window(void)
{
  return cur_win;
}

/*
 * Clears the current window
 */
void display_erase_window(void)
{
  int height;

  if (font_num >= 0)
    height = xfont_get_height(x_fonts[font_num]);
  else
    height = xfont_y;
  
  XSetForeground(x_display, x_pixgc, x_colour[FIRST_ZCOLOUR+CURWIN.back].pixel);

  XFillRectangle(x_display, x_pix, x_pixgc,
		 CURWIN.winsx, CURWIN.winsy,
		 CURWIN.winlx-CURWIN.winsx,
		 CURWIN.winly-CURWIN.winsy);
  CURWIN.xpos = CURWIN.winsx + CURWIN.lmargin;
  CURWIN.ypos = CURWIN.winlx - height;
  CURWIN.line_height = height;
  do_redraw =  1;
}

/*
 * Erases the current line in the current window
 */
void display_erase_line(int val)
{
  XSetForeground(x_display, x_pixgc, x_colour[FIRST_ZCOLOUR+CURWIN.back].pixel);
  if (val == 1)
    {
      XFillRectangle(x_display, x_pix, x_pixgc,
		     CURWIN.xpos, CURWIN.ypos,
		     CURWIN.winlx-CURWIN.xpos,
		     CURWIN.line_height);
    }
  else
    {
      if (CURWIN.xpos + val > CURWIN.winlx)
	val = CURWIN.winlx-CURWIN.xpos+1;
      XFillRectangle(x_display, x_pix, x_pixgc,
		     CURWIN.xpos, CURWIN.ypos,
		     val-1,
		     CURWIN.line_height);
    }
}

/*
 * Sets the cursor position in the current window. x and y are
 * character coordinates
 */
void display_set_cursor(int x, int y)
{
  CURWIN.xpos = CURWIN.winsx+x*xfont_x;
  CURWIN.ypos = y*xfont_y;
  
  if (CURWIN.xpos > CURWIN.winlx)
    CURWIN.xpos = CURWIN.winlx;
  if (CURWIN.xpos < CURWIN.winsx)
    CURWIN.xpos = CURWIN.winsx;
  
  /*
  if (CURWIN.ypos > CURWIN.winly)
    {
      CURWIN.ypos = CURWIN.winly;
#ifdef DEBUG
      printf("(Cursor ypos clipped to bottom)\n");
#endif
    }
  if (CURWIN.ypos < CURWIN.winsy)
    {
#ifdef DEBUG
      printf("(Cursor ypos clipped to top)\n");
#endif
      CURWIN.ypos = CURWIN.winsy;
    }
  */

#ifdef DEBUG
  printf("(text-set) Cursor position now %i, %i\n", CURWIN.xpos, CURWIN.ypos);
#endif
}

/*
 * Sets the graphics cursor position in the current window
 */
void display_set_gcursor(int x, int y)
{
  CURWIN.xpos = x;
  CURWIN.ypos = y;
  
  if (CURWIN.xpos > CURWIN.winlx)
    CURWIN.xpos = CURWIN.winlx;
  if (CURWIN.xpos < CURWIN.winsx)
    CURWIN.xpos = CURWIN.winsx;

  /*
  if (CURWIN.ypos > CURWIN.winly)
    CURWIN.ypos = CURWIN.winly;
  if (CURWIN.ypos < CURWIN.winsy)
    CURWIN.ypos = CURWIN.winsy;
  */
    
#ifdef DEBUG
  printf("(graph-set) Cursor position now %i, %i\n", CURWIN.xpos, CURWIN.ypos);
#endif
}

/*
 * Gets the graphics cursor X position
 */
int display_get_gcur_x(void)
{
  return CURWIN.xpos;
}

/*
 * Gets the graphics cursor Y position
 */
int display_get_gcur_y(void)
{
  return CURWIN.ypos;
}

/*
 * Gets the text cursor X position
 */
int display_get_cur_x(void)
{
  return (CURWIN.xpos-CURWIN.winsx)/xfont_x;
}

/*
 * Gets the text cursor Y position
 */
int display_get_cur_y(void)
{
  return (CURWIN.ypos-CURWIN.winsy)/xfont_y;
}

/*
 * Sets whether or not a window should display 'More' or not
 */
void display_set_more(int window, int more)
{
  text_win[window].no_more = !more;
}

/*
 * Force a window to use a fixed pitch font regardless of style or
 * font settings
 */
extern void display_force_fixed (int window, int val)
{
  text_win[window].force_fixed = val;
}

/***                           ----// 888 \\----                           ***/

/*
 * Defines a window for v6
 */
void display_window_define(int window,
			   int x, int y,
			   int lmargin, int rmargin,
			   int width, int height)
{
  text_win[window].winsx   = x;
  text_win[window].winsy   = y;
  text_win[window].lmargin = lmargin;
  text_win[window].rmargin = rmargin;
  text_win[window].winlx   = x + width;
  text_win[window].winly   = y + height;

  if (text_win[window].winly > win_y)
    text_win[window].winly = win_y;

  /* if (text_win[window].xpos < x || text_win[window].xpos > x+width ||
      text_win[window].ypos < y || text_win[window].ypos > y+height)
    {
      text_win[window].xpos = x;
      text_win[window].ypos = y;
      } */
}

/*
 * Sets the function that should be called just before a newline is
 * printed (this function can return -1 for proceed as normal, 0 for
 * do not display [MORE], 1 for display [MORE] now, or 2 for abort
 * display (the function must set things up so that the remainder of
 * the line is displayed at some point)
 */
void display_set_newline_function(int (*func)(const int* remaining,
					      int rem_len))
{
  newline_func = func;
}

/*
 * Gets the font height in pixels
 */
int display_get_font_height(void)
{
  return xfont_get_height(x_fonts[font_num]);
}

/*
 * Gets the width of a character '0' in the current font
 */
int display_get_font_width(void)
{
  static int zero[] = { 48, 0 };
  return xfont_get_text_width(x_fonts[font_num], zero, 1);
}

/*
 * Resets window positions to the defaults
 */
void display_reset_windows(void)
{
  cur_win = 0;
  text_win[0].xpos = 0;
  text_win[0].ypos = 0;
  text_win[0].line_height = xfont_y;
  text_win[0].winsx = text_win[0].winsy = 0;
  text_win[0].lmargin = text_win[0].rmargin = 0;
  text_win[0].winlx = win_x;
  text_win[0].winly = win_y;
  text_win[0].text_amount = 0;
  text_win[0].no_more = 0;
  text_win[0].force_fixed = 0;
  text_win[0].no_scroll = 0;  
}
