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
#include "xfont.h"
#include "carbondisplay.h"

static int process_events(long int timeout,
			  int* buf,
			  int  buflen);

WindowRef zoomWindow;
static int quitflag = 0;

static xfont** font = NULL;
static int     n_fonts = 9;

static char*   fontlist[] =
{
  "'Arial' 10",
  "'Arial' 10 b",
  "'Arial' 10 i",
  "'Courier New' 10 f",
  "font3",
  "'Arial' 10 ib",
  "'Courier New' 10 fb",
  "'Courier New' 10 fi",
  "'Courier New' 10 fib"
};

static int style_font[16] = { 0, 1, 2, 5, 3, 6, 7, 8,
			      4, 4, 4, 4, 4, 4, 4, 4 };

struct text
{
  int fg, bg;
  int font;

  int spacer;
  int space;
  
  int len;
  int* text;
  
  struct text* next;
};

struct line
{
  struct text* start;
  int          n_chars;
  int          offset;
  int          baseline;
  int          ascent;
  int          descent;
  int          height;

  struct line* next;
};

struct cellline
{
  int*           cell;
  unsigned char* fg;
  unsigned char* bg;
  unsigned char* font;
};

struct window
{
  int xpos, ypos;

  int winsx, winsy;
  int winlx, winly;

  int overlay;
  int force_fixed;
  int no_more;
  int no_scroll;

  int fore, back;
  int style;

  int winback;

  struct text* text;
  struct text* lasttext;
  
  struct line* line;
  struct line* topline;
  struct line* lastline;

  struct cellline* cline;
};

int cur_win;
struct window text_win[3];
static int    nShow;

#define CURWIN text_win[cur_win]
#define CURSTYLE (text_win[cur_win].style|(text_win[cur_win].force_fixed<<8))

#define DEFAULTX 80
#define DEFAULTY 30
static int size_x, size_y;
static int max_x, max_y;

int xfont_x = 0;
int xfont_y = 0;
static int win_x   = 0;
static int win_y   = 0;
static int total_x = 0;
static int total_y = 0;
static int start_y;

#define DEFAULT_FORE 0
#define DEFAULT_BACK 7
#define FIRST_ZCOLOUR 3

static int more_on = 0;
static int displayed_text = 0;

/***                           ----// 888 \\----                           ***/

/* Support functions */

static void resize_window()
{
  int ofont_x, ofont_y;

  if (xfont_x == 0 || xfont_y == 0)
    return;

  /* FIXME */
}

static void size_window(void)
{
  Rect bounds;

  xfont_x = xfont_get_width(font[style_font[4]]);
  xfont_y = xfont_get_height(font[style_font[4]]);
  
  win_x = xfont_x*size_x;
  win_y = xfont_y*size_y;
  total_x = win_x + 4;
  total_y = win_y + 4;

  GetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);
  bounds.right = bounds.left + total_x;
  bounds.bottom = bounds.top + total_y;
  SetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);
}

/***                           ----// 888 \\----                           ***/

static inline int istrlen(const int* string)
{
  int x = 0;

  while (string[x] != 0) x++;
  return x;
}

static inline void istrcpy(int* dest, const int* src)
{
  memcpy(dest, src, (istrlen(src)+1)*sizeof(int));
}

/***                           ----// 888 \\----                           ***/

/* Event handlers */

/* We could do this, except it doesn't work. Got to love apple's docs. */
/* const MenuCommand kCommandQuit = FOUR_CHAR_CODE('quit'); */

static pascal OSStatus zoom_evt_handler(EventHandlerCallRef myHandlerChain,
					EventRef event, 
					void* data)
{
  UInt32    cla;
  UInt32    wha;
  HICommand cmd;

  cla = GetEventClass(event);
  wha = GetEventKind(event);
  
  switch (cla)
    {
    case kEventClassCommand:
      switch (wha)
	{
	case kEventCommandProcess:
	  GetEventParameter(event, kEventParamDirectObject,
			    typeHICommand, NULL, sizeof(HICommand),
			    NULL, &cmd);
	  switch (cmd.commandID)
	    {
	    case FOUR_CHAR_CODE('quit'):
	      quitflag = 1;
	    }
	  break;
	}
      break;

    case kEventClassMouse:
      switch (wha)
	{
	case kEventMouseDown:
	  {
	    short part;
	    WindowPtr ourwindow;
	    HIPoint   argh;
	    Point     point;

	    /* 
	     * Yay, more great docs. Apple's docs specify that the type here
	     * should be 'QDPoint', which doesn't exist, of course.
	     * And HIPoint is almost totally useless for any real work,
	     * so the first thing we have to do is convert it to a Point.
	     * None of this is in the docs, either.
	     */
	    GetEventParameter(event, kEventParamMouseLocation,
			      typeHIPoint, NULL, sizeof(HIPoint),
			      NULL, &argh);
	    point.h = argh.x;
	    point.v = argh.y;
	    part = FindWindow(point, &ourwindow);

	    switch (part)
	      {
	      case inMenuBar:
		MenuSelect(point);
		break;
	      }
	  }
	  break;
	}
    }

  return noErr;
}

static inline int isect_rect(Rect* r1, Rect* r2)
{
  return 1;
}

static void draw_window(int   win,
			Rect* rct)
{
  struct line* winline;
  int x;
  int width;
  int offset;
  struct text* wintext;

  if (text_win[win].overlay)
    {
    }
  else
    {
      winline = text_win[win].line;

      /* Iterate through the lines and plot what's necessary */
      while (winline != NULL)
	{
	  wintext   = winline->start;
	  width     = 0;
	  offset    = winline->offset;

	  for (x=0; x<winline->n_chars;)
	    {
	      int w;
	      int toprint;

	      toprint = winline->n_chars-x;
	      if (toprint > (wintext->len - offset))
		toprint = wintext->len - offset;
	      
	      if (toprint > 0)
		{
		  if (wintext->text[toprint+offset-1] == 10)
		    {
		      toprint--;
		      x++;
		    }

		  w = xfont_get_text_width(font[wintext->font],
					   wintext->text + offset,
					   toprint);

		  xfont_plot_string(font[wintext->font],
				    width+2,
				    -winline->baseline + 2,
				    wintext->text + offset,
				    toprint);

		  x      += toprint;
		  offset += toprint;
		  width  += w;
		}
	      else
		{
		  offset = 0;
		  wintext = wintext->next;
		}
	    }

	  winline = winline->next;
	}
    }
}

static pascal OSStatus zoom_wnd_handler(EventHandlerCallRef myHandlerChain,
					EventRef event, 
					void* data)
{
  UInt32    cla;
  UInt32    wha;

  cla = GetEventClass(event);
  wha = GetEventKind(event);

  switch (cla)
    {
    case kEventClassWindow:
      switch (wha)
	{
	case kEventWindowDrawContent:
	  draw_window(0, NULL);
	  draw_window(1, NULL);
	  draw_window(2, NULL);
	  break;
	}
      break;

    case kEventClassMouse:
      zmachine_fatal("Click!");
      break;
    }

  return noErr;
}

/* Support functions */

static void rejig_fonts(void)
{
  int x;
  rc_font* fonts;

  fonts = rc_get_fonts(&n_fonts);
 
  /* Allocate fonts */
  if (fonts == NULL)
    {
      font = realloc(font, sizeof(xfont*)*9);
      for (x=0; x<9; x++)
	{
	  font[x] = xfont_load_font(fontlist[x]);
	}
      n_fonts = 9;
    }
  else
    {
      int y;
      
      for (x=0; x<16; x++)
	style_font[x] = -1;
      
      font = realloc(font, sizeof(xfont*)*n_fonts);
      for (x=0; x<n_fonts; x++)
	{
	  font[x] = xfont_load_font(fonts[x].name);

	  for (y=0; y<fonts[x].n_attr; y++)
	    style_font[fonts[x].attributes[y]] = x;
	}
    }
}

/* Display implementation */

/***                           ----// 888 \\----                           ***/

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

/***                           ----// 888 \\----                           ***/

void display_exit(int code)
{
  exit(code);
}

void display_initialise(void)
{
  EventTargetRef  target;
  EventTypeSpec   appevts[] = 
    { 
      { kEventClassCommand, kEventCommandProcess },
      { kEventClassMouse, kEventMouseDown }
    };
  EventTypeSpec   wndevts[] = 
    { 
      { kEventClassWindow, kEventWindowDrawContent },
      { kEventClassMouse, kEventMouseUp }
    };

  target = GetEventDispatcherTarget();

  /* Initialise font structures */
  rejig_fonts();

  /* Setup event handlers */
  InstallApplicationEventHandler(NewEventHandlerUPP(zoom_evt_handler),
				 2, appevts, 0, NULL);
  InstallWindowEventHandler(zoomWindow,
			    NewEventHandlerUPP(zoom_wnd_handler),
			    1, wndevts, 0, NULL);

  /* Resize the window */
  max_x = size_x = rc_get_xsize();
  max_y = size_y = rc_get_ysize();
  
  size_window();

  /* Setup the display */
  display_clear();

  /* Yay, we can now show the window */
  ShowWindow(zoomWindow);
}

void display_reinitialise(void)
{
  rejig_fonts();
}

void display_finalise(void)
{
  int x;

  /* Deallocate fonts */
  for (x=0; x<9; x++)
    xfont_release_font(font[x]);
}

/***                           ----// 888 \\----                           ***/

void display_erase_window(void)
{
  Rect rct;

  displayed_text = 0;
  
  if (CURWIN.overlay)
    {
      int x,y;

      /* Blank an overlay window */

      for (y=0; y<(CURWIN.winly/xfont_y); y++)
	{
	  for (x=0; x<max_x; x++)
	    {
	      CURWIN.cline[y].cell[x] = ' ';
	      CURWIN.cline[y].fg[x]   = CURWIN.back;
	      CURWIN.cline[y].bg[x]   = 255;
	      CURWIN.cline[y].font[x] = style_font[4];
	    }
	}
    }
  else
    {
      /* Blank a proportional text window */
      struct text* text;
      struct text* nexttext;
      struct line* line;
      struct line* nextline;
      int x, y, z;

      text = CURWIN.text;
      while (text != NULL)
	{
	  nexttext = text->next;
	  free(text->text);
	  free(text);
	  text = nexttext;
	}
      CURWIN.text = CURWIN.lasttext = NULL;
      CURWIN.winback = CURWIN.back;

      line = CURWIN.line;
      while (line != NULL)
	{
	  nextline = line->next;
	  free(line);
	  line = nextline;
	}
      CURWIN.line = CURWIN.topline = CURWIN.lastline = NULL;
      
      for (y=(CURWIN.winsy/xfont_y); y<size_y; y++)
	{
	  for (x=0; x<max_x; x++)
	    {
	      for (z=1; z<=2; z++)
		{
		  text_win[z].cline[y].cell[x] = ' ';
		  text_win[z].cline[y].fg[x]   = FIRST_ZCOLOUR+DEFAULT_BACK;
		  text_win[z].cline[y].bg[x]   = 255;
		  text_win[z].cline[y].font[x] = style_font[4];
		}
	    }
	}
    }

  /* Redraw the main window */
  rct.top = 0;
  rct.left = 0;
  rct.right = total_x;
  rct.bottom = -total_y;
  InvalWindowRect(zoomWindow, &rct);
}

void display_clear(void)
{
  int x, y, z;

  displayed_text = 0;
  
  /* Clear the main text window */
  text_win[0].force_fixed = 0;
  text_win[0].overlay     = 0;
  text_win[0].no_more     = 0;
  text_win[0].no_scroll   = 0;
  text_win[0].fore        = DEFAULT_FORE+FIRST_ZCOLOUR;
  text_win[0].back        = DEFAULT_BACK+FIRST_ZCOLOUR;
  text_win[0].style       = 0;
  text_win[0].xpos        = 0;
  text_win[0].ypos        = win_y;
  text_win[0].winsx       = 0;
  text_win[0].winsy       = 0;
  text_win[0].winlx       = win_x;
  text_win[0].winly       = win_y;
  text_win[0].winback     = DEFAULT_BACK+FIRST_ZCOLOUR;

  start_y = text_win[0].ypos;

  /* Clear the overlay windows */
  for (x=1; x<3; x++)
    {
      text_win[x].force_fixed = 1;
      text_win[x].overlay     = 1;
      text_win[x].no_more     = 1;
      text_win[x].no_scroll   = 1;
      text_win[x].xpos        = 0;
      text_win[x].ypos        = 0;
      text_win[x].winsx       = 0;
      text_win[x].winsy       = 0;
      text_win[x].winlx       = win_x;
      text_win[x].winly       = 0;

      text_win[0].winback     = DEFAULT_BACK+FIRST_ZCOLOUR;
      text_win[x].fore        = DEFAULT_FORE+FIRST_ZCOLOUR;
      text_win[x].back        = DEFAULT_BACK+FIRST_ZCOLOUR;
      text_win[x].style       = 4;

      text_win[x].text        = NULL;
      text_win[x].line        = NULL;

      if (text_win[x].cline != NULL)
	{
	  for (y=0; y<max_y; y++)
	    {
	      free(text_win[x].cline[y].cell);
	      free(text_win[x].cline[y].fg);
	      free(text_win[x].cline[y].bg);
	      free(text_win[x].cline[y].font);
	    }
	  free(text_win[x].cline);
	}
      
      text_win[x].cline       = malloc(sizeof(struct cellline)*size_y);
	  
      for (y=0; y<size_y; y++)
	{
	  text_win[x].cline[y].cell = malloc(sizeof(int)*size_x);
	  text_win[x].cline[y].fg   = malloc(sizeof(char)*size_x);
	  text_win[x].cline[y].bg   = malloc(sizeof(char)*size_x);
	  text_win[x].cline[y].font = malloc(sizeof(char)*size_x);
	  
	  for (z=0; z<size_x; z++)
	    {
	      text_win[x].cline[y].cell[z] = ' ';
	      text_win[x].cline[y].fg[z]   = DEFAULT_BACK+FIRST_ZCOLOUR;
	      text_win[x].cline[y].bg[z]   = 255;
	      text_win[x].cline[y].font[z] = style_font[4];
	    }
	}
      
      max_x = size_x;
      max_y = size_y;
    }

  cur_win = 0;
  display_erase_window();
}

static void new_line(int more)
{
  struct line* line;
  Rect rct;

  if (CURWIN.lastline == NULL)
    {
      CURWIN.lastline = CURWIN.line = malloc(sizeof(struct line));

      CURWIN.line->start    = NULL;
      CURWIN.line->n_chars  = 0;
      CURWIN.line->offset   = 0;
      CURWIN.line->baseline =
	CURWIN.ypos + xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
      CURWIN.line->ascent   = xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
      CURWIN.line->descent  = xfont_get_descent(font[style_font[(CURSTYLE>>1)&15]]);
      CURWIN.line->height   = xfont_get_height(font[style_font[(CURSTYLE>>1)&15]]);
      CURWIN.line->next     = NULL;

      displayed_text = CURWIN.lastline->ascent + CURWIN.lastline->descent;
      
      return;
    }

  if (more != 0)
    {
      int distext;

      distext = CURWIN.lastline->ascent + CURWIN.lastline->descent;
      if (displayed_text+distext >= (CURWIN.winly - CURWIN.winsy))
	{
	  more_on = 1;
	  display_readchar(0);
	  more_on = 0;
	}
      displayed_text += distext;
    }

  rct.top    = CURWIN.lastline->baseline - CURWIN.lastline->ascent+4;
  rct.bottom = CURWIN.lastline->baseline + CURWIN.lastline->descent+4;
  rct.left   = 4;
  rct.right  = win_x+4;
  InvalWindowRect(zoomWindow, &rct);
  
  line = malloc(sizeof(struct line));

  line->start     = NULL;
  line->n_chars   = 0;
  line->baseline  = CURWIN.lastline->baseline+CURWIN.lastline->descent;
  line->baseline += xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
  line->ascent    = xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
  line->descent   = xfont_get_descent(font[style_font[(CURSTYLE>>1)&15]]);
  line->height    = xfont_get_height(font[style_font[(CURSTYLE>>1)&15]]);
  line->next      = NULL;

  CURWIN.lastline->next = line;
  CURWIN.lastline = line;

  CURWIN.xpos = 0;
  CURWIN.ypos = line->baseline - line->ascent;

  if (line->baseline+line->descent > CURWIN.winly)
    {
      int toscroll;
      struct line* l;
      int x, y;

      toscroll = (line->baseline+line->descent)-CURWIN.winly;
      l = CURWIN.line;

      /* Scroll the lines upwards */
      while (l != NULL)
	{
	  l->baseline -= toscroll;
	  l = l->next;
	}

      /* Scroll the overlays upwards */
      for (y=CURWIN.winsy/xfont_y;
	   y<(size_y-1);
	   y++)
	{
	  for (x=0; x<max_x; x++)
	    {
	      text_win[2].cline[y].cell[x] = text_win[2].cline[y+1].cell[x];
	      text_win[2].cline[y].font[x] = text_win[2].cline[y+1].font[x];
	      text_win[2].cline[y].fg[x]   = text_win[2].cline[y+1].fg[x];
	      text_win[2].cline[y].bg[x]   = text_win[2].cline[y+1].bg[x];
	    }
	}
      
      for (x=0; x<max_x; x++)
	{
	  text_win[2].cline[size_y-1].cell[x] = ' ';
	  text_win[2].cline[size_y-1].font[x] = style_font[4];
	  text_win[2].cline[size_y-1].fg[x]   = DEFAULT_BACK+FIRST_ZCOLOUR;
	  text_win[2].cline[size_y-1].bg[x]   = 255;
	}

      display_update();
    }
}

static void format_last_text(int more)
{
  int x;
  struct text* text;
  int word_start, word_len, total_len, xpos;
  xfont* fn;
  struct line* line;
  Rect rct;
  
  text = CURWIN.lasttext;

  fn = font[text->font];

  if (CURWIN.lastline == NULL)
    {
      new_line(more);
    }

  if (text->spacer)
    {
      line = CURWIN.lastline;
      
      new_line(more);

      CURWIN.lastline->descent = 0;
      CURWIN.lastline->baseline =
	line->baseline+line->descent+text->space;
      CURWIN.lastline->ascent = text->space;

      new_line(more);
    }
  else
    {
      word_start = 0;
      word_len   = 0;
      total_len  = 0;
      xpos       = CURWIN.xpos;
      line       = CURWIN.lastline;
      
      /*
       * Move the other lines to make room if this font is bigger than
       * ones previously used on this line
       */
      if (CURWIN.lastline->ascent < xfont_get_ascent(font[text->font]))
	{
	  int toscroll;
	  struct line* l;
	  
	  toscroll = xfont_get_ascent(font[text->font]) - CURWIN.lastline->ascent;
	  
	  l = CURWIN.line;
	  while (l != CURWIN.lastline)
	    {
	      if (l == NULL)
		zmachine_fatal("Programmer is a spoon");
	      
	      l->baseline -= toscroll;
	      l = l->next;
	    }
	  if (more != 0)
	    displayed_text += toscroll;
	  CURWIN.lastline->ascent = xfont_get_ascent(font[text->font]);
	  display_update();
	}
      
      /*
       * Ditto
       */
      if (CURWIN.lastline->descent < xfont_get_descent(font[text->font]))
	{
	  int toscroll;
	  
	  toscroll = xfont_get_descent(font[text->font]) -
	    CURWIN.lastline->descent;
	  if (CURWIN.lastline->baseline+xfont_get_descent(font[text->font]) 
	      > CURWIN.winly)
	    {
	      struct line* l;
	      
	      l = CURWIN.line;
	      
	      while (l != NULL)
		{
		  l->baseline -= toscroll;
		  l = l->next;
		}
	      
	      display_update();
	    }
	  
	  if (more != 0)
	    displayed_text += toscroll;
	  CURWIN.lastline->descent = xfont_get_descent(font[text->font]);
	}
      
      for (x=0; x<text->len;)
	{
	  if (text->text[x] == ' '  ||
	      text->text[x] == '\n' ||
	      x == (text->len-1))
	    {
	      int w;
	      int nl;

	      nl = 0;
	      do
		{
		  if (text->text[x] == '\n')
		    {
		      nl = 1;
		      break;
		    }
		  x++;
		  word_len++;
		}
	      while (!nl &&
		     (x < text->len &&
		      (text->text[x] == ' ' ||
		       text->text[x] == '\n')));
	      
	      w = xfont_get_text_width(fn,
				       text->text + word_start,
				       word_len);

	      /* We've got a word */
	      xpos += w;
	      
	      if (xpos > CURWIN.winlx)
		{
		  /* Put this word on the next line */
		  new_line(more);
		  
		  xpos = CURWIN.xpos + w;
		  line = CURWIN.lastline;
		}
	      
	      if (line->start == NULL)
		{
		  line->offset = word_start;
		  line->start = text;
		}
	      line->n_chars += word_len;
	      
	      word_start += word_len;
	      total_len  += word_len;
	      word_len    = 0;
	      
	      if (nl)
		{
		  new_line(more);
		  
		  x++;
		  total_len++;
		  word_start++;
		  
		  xpos = CURWIN.xpos;
		  line = CURWIN.lastline;
		}
	    }
	  else
	    {
	      word_len++;
	      x++;
	    }
	}
      
      CURWIN.xpos = xpos;
    }
  
  rct.top    = CURWIN.lastline->baseline - CURWIN.lastline->ascent+4;
  rct.bottom = CURWIN.lastline->baseline + CURWIN.lastline->descent+4;
  rct.left   = 4;
  rct.right  = win_x+4;
  InvalWindowRect(zoomWindow, &rct);
}

void display_prints(const int* str)
{
  if (CURWIN.overlay)
    {
      int x;
      Rect rct;
      int sx;

      if (CURWIN.xpos >= max_x)
	CURWIN.xpos = max_x-1;
      if (CURWIN.xpos < 0)
	CURWIN.xpos = 0;
      if (CURWIN.ypos >= max_y)
	CURWIN.ypos = max_y-1;
      if (CURWIN.ypos < 0)
	CURWIN.ypos = 0;
      
      CURWIN.style |= 8;
      sx = CURWIN.xpos;
      
      /* Is an overlay window */
      for (x=0; str[x] != 0; x++)
	{
	  if (str[x] > 31)
	    {
	      if (CURWIN.xpos >= size_x)
		{
		  rct.top = CURWIN.ypos*xfont_y+4;
		  rct.bottom = CURWIN.ypos*xfont_y+4+xfont_y;
		  rct.left   = sx*xfont_x+4;
		  rct.right  = win_x+4;
		  InvalWindowRect(zoomWindow, &rct);
		  sx = 0;
		  
		  CURWIN.xpos = 0;
		  CURWIN.ypos++;
		}
	      if (CURWIN.ypos >= size_y)
		{
		  CURWIN.ypos = size_y-1;
		}

	      CURWIN.cline[CURWIN.ypos].cell[CURWIN.xpos] = str[x];
	      if (CURWIN.style&1)
		{
		  CURWIN.cline[CURWIN.ypos].fg[CURWIN.xpos]   = CURWIN.back;
		  CURWIN.cline[CURWIN.ypos].bg[CURWIN.xpos]   = CURWIN.fore;
		}
	      else
		{
		  CURWIN.cline[CURWIN.ypos].fg[CURWIN.xpos]   = CURWIN.fore;
		  CURWIN.cline[CURWIN.ypos].bg[CURWIN.xpos]   = CURWIN.back;
		}
	      CURWIN.cline[CURWIN.ypos].font[CURWIN.xpos] = style_font[(CURSTYLE>>1)&15];
	      
	      CURWIN.xpos++;
	    }
	  else
	    {
	      switch (str[x])
		{
		case 10:
		case 13:
		  rct.top = CURWIN.ypos*xfont_y+4;
		  rct.bottom = CURWIN.ypos*xfont_y+4+xfont_y;
		  rct.left   = sx*xfont_x+4;
		  rct.right  = CURWIN.xpos*xfont_x+4;
		  InvalWindowRect(zoomWindow, &rct);

		  sx = 0;
		  CURWIN.xpos = 0;
		  CURWIN.ypos++;
		  
		  if (CURWIN.ypos >= size_y)
		    {
		      CURWIN.ypos = size_y-1;
		    }
		  break;
		}
	    }
	}

      rct.top = CURWIN.ypos*xfont_y+4;
      rct.bottom = CURWIN.ypos*xfont_y+4+xfont_y;
      rct.left   = sx*xfont_x+4;
      rct.right  = CURWIN.xpos*xfont_x+4;
      InvalWindowRect(zoomWindow, &rct);
    }
  else
    {
      struct text* text;

      if (str[0] == 0)
	return;

      text = malloc(sizeof(struct text));

      if (CURWIN.style&1)
	{
	  text->fg   = CURWIN.back;
	  text->bg   = CURWIN.fore;
	}
      else
	{
	  text->fg   = CURWIN.fore;
	  text->bg   = CURWIN.back;
	}
      text->spacer = 0;
      text->font   = style_font[(CURSTYLE>>1)&15];
      text->len    = istrlen(str);
      text->text   = malloc(sizeof(int)*text->len);
      text->next   = NULL;
      memcpy(text->text, str, sizeof(int)*text->len);

      if (CURWIN.lasttext == NULL)
	{
	  CURWIN.text = text;
	  CURWIN.lasttext = text;
	}
      else
	{
	  CURWIN.lasttext->next = text;
	  CURWIN.lasttext = text;
	}

      format_last_text(-1);
    }
}

void display_prints_c(const char* str)
{
  int* txt;
  int x, len;

  txt = malloc((len=strlen(str))*sizeof(int)+sizeof(int));
  for (x=0; x<=len; x++)
    {
      txt[x] = str[x];
    }
  display_prints(txt);
  free(txt);
}

void display_printf(const char* format, ...)
{
  va_list  ap;
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

/***                           ----// 888 \\----                           ***/

int display_readline(int* buf, int buflen, long int timeout)
{
  int result;

  result = process_events(timeout, buf, buflen);

  return result;
}

int display_readchar(long int timeout)
{
  return process_events(timeout, NULL, 0);
}

/***                           ----// 888 \\----                           ***/

void display_set_title(const char* title)
{
}

void display_update(void)
{
  Rect rct;

  rct.top    = 0;
  rct.left   = 0;
  rct.right  = total_x;
  rct.bottom = total_y;
  InvalWindowRect(zoomWindow, &rct);
}

/***                           ----// 888 \\----                           ***/

void display_set_colour  (int fore, int back)
{
}

/***                           ----// 888 \\----                           ***/

void display_split       (int lines, int window)
{
  text_win[window].winsx = CURWIN.winsx;
  text_win[window].winlx = CURWIN.winsx;
  text_win[window].winsy = CURWIN.winsy;
  text_win[window].winly = CURWIN.winsy + xfont_y*lines;
  text_win[window].xpos  = 0;
  text_win[window].ypos  = 0;

  CURWIN.topline = NULL;
  CURWIN.winsy += xfont_y*lines;
  if (CURWIN.ypos < CURWIN.winsy)
    {
      if (CURWIN.line == NULL)
	start_y = CURWIN.winsy;
      else
	{
	  CURWIN.lasttext->next   = malloc(sizeof(struct text));
	  CURWIN.lasttext         = CURWIN.lasttext->next;
	  CURWIN.lasttext->spacer = 1;
	  CURWIN.lasttext->space  = CURWIN.winsy -
	    (CURWIN.lastline->baseline + CURWIN.lastline->descent);
	  CURWIN.lasttext->len    = 0;
	  CURWIN.lasttext->text   = NULL;
	  CURWIN.lasttext->font   = style_font[CURSTYLE];

	  if (CURWIN.style&1)
	    {
	      CURWIN.lasttext->fg   = CURWIN.back;
	      CURWIN.lasttext->bg   = CURWIN.fore;
	    }
	  else
	    {
	      CURWIN.lasttext->fg   = CURWIN.fore;
	      CURWIN.lasttext->bg   = CURWIN.back;
	    }

	  format_last_text(0);
	}
      CURWIN.ypos = CURWIN.winsy;
    }
}

void display_join        (int window1, int window2)
{
  if (text_win[window1].winsy != text_win[window2].winly)
    return; /* Windows can't be joined */
  text_win[window1].winsy = text_win[window2].winsy;
  text_win[window2].winly = text_win[window2].winsy;

  text_win[window1].topline = text_win[window2].topline = NULL;
}

void display_set_window  (int window)
{
  text_win[window].fore  = CURWIN.fore;
  text_win[window].back  = CURWIN.back;
  text_win[window].style = CURWIN.style;
  cur_win = window;
}

int  display_get_window  (void)
{
  return cur_win;
}

void display_set_more    (int window,
				 int more)
{
}

/***                           ----// 888 \\----                           ***/

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
  return CURWIN.xpos;
}

int  display_get_gcur_y  (void)
{
  return CURWIN.ypos;
}

int  display_get_cur_x   (void)
{
  return CURWIN.xpos;
}

int  display_get_cur_y   (void)
{
  return CURWIN.ypos;
}

/***                           ----// 888 \\----                           ***/

int  display_set_font    (int font)
{
  switch (font)
    {
    case -1:
      display_set_style(-16);
      break;

    default:
      break;
    }

  return 0;
}

int  display_set_style   (int style)
{
  int old_style;

  old_style = CURWIN.style;
  
  if (style == 0)
    CURWIN.style = 0;
  else
    {
      if (style > 0)
	CURWIN.style |= style;
      else
	CURWIN.style &= ~(-style);
    }

  return old_style;
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
  return 0;
}

int  display_get_mouse_y (void)
{
  return 0;
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
  IBNibRef nib;

  CreateNibReference(CFSTR("zoom"), &nib);
  SetMenuBarFromNib(nib, CFSTR("MenuBar"));
  CreateWindowFromNib(nib, CFSTR("ZoomMain"), &zoomWindow);
  DisposeNibReference(nib);
  
  zoom_main(argc, argv);

  return 0;
}

static void process_menu_command(long menres)
{
  HiliteMenu(0);
}

static int process_events(long int timeout,
			  int* buf,
			  int  buflen)
{
  EventRef event;
  EventTargetRef target;

  target = GetEventDispatcherTarget();

  display_update();

  while (!quitflag)
    {
      if (ReceiveNextEvent(0, NULL, kEventDurationForever, true, &event) == noErr)
	{
	  SendEventToEventTarget(event, target);
	  ReleaseEvent(event);
	}
    }

  display_exit(0);
  
  return 0;
}

#endif
