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
 * Display for MacOS X (Carbon)
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

/* Colour information */
RGBColor maccolour[14] = {
  { 0xdd00, 0xdd00, 0xdd00 },
  { 0xaa00, 0xaa00, 0xaa00 },
  { 0xff00, 0xff00, 0xff00 },

  { 0x0000, 0x0000, 0x0000 },
  { 0xff00, 0x0000, 0x0000 },
  { 0x0000, 0xff00, 0x0000 },
  { 0xff00, 0xff00, 0x0000 },
  { 0x0000, 0x0000, 0xff00 },
  { 0xff00, 0x0000, 0xff00 },
  { 0x0000, 0xff00, 0xff00 },
  { 0xff00, 0xff00, 0xcc00 },
  
  { 0xbb00, 0xbb00, 0xbb00 },
  { 0x8800, 0x8800, 0x8800 },
  { 0x4400, 0x4400, 0x4400 }
};

/* Windows, flags */
WindowRef  zoomWindow;
ControlRef zoomScroll;

DialogRef  fataldlog = nil;
DialogRef  quitdlog  = nil;
int        window_available = 0;
int        quitflag = 0;
static int updating = 0;

static int scrollpos = 0;

/* Font information */
static xfont** font = NULL;
static int     n_fonts = 9;
int            mac_openflag = 0;

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

/* Z-Machine window layout */
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

/* Windows data structures 'emselves */
int cur_win;
struct window text_win[3];

#define CURWIN text_win[cur_win]
#define CURSTYLE (text_win[cur_win].style|(text_win[cur_win].force_fixed<<8))

/* Window parameters */
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

static int scroll_overlays = 1;

#define DEFAULT_FORE 0
#define DEFAULT_BACK 7
#define FIRST_ZCOLOUR 3

static int more_on = 0;
static int displayed_text = 0;

/* The caret */
#define FLASH_DELAY (kEventDurationSecond*3)/5

EventLoopTimerRef caret_timer;

static int  caret_x, caret_y, caret_height;
static int  input_x, input_y;
static int  caret_on = 0;
static int  caret_shown = 0;
static int  caret_flashing = 0;
static int  insert = 1;

/* Input and history buffers */

static char* force_text = NULL;
static int*  text_buf   = NULL;
static int   buf_offset = 0;
static int   max_buflen = 0;
static int   read_key   = -1;

typedef struct history_item
{
  int* string;
  struct history_item* next;
  struct history_item* last;
} history_item;
static history_item* last_string = NULL;
static history_item* history_pos = NULL;

static unsigned char terminating[256] =
{
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
};
static int click_x, click_y;

static void draw_input_text(void);
static void update_status_text(void);

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

/* Manipulation functions */
Boolean display_force_input(char* text)
{
  static char* buf = NULL;

  if (text_buf == NULL)
    return false;

  buf = realloc(buf, strlen(text)+1);
  
  strcpy(buf, text);
  force_text = buf;

  return true;
}

/***                           ----// 888 \\----                           ***/

/* Support functions */

static void format_last_text(int more);
static void redraw_input_text(void);
static void draw_window(int win, Rect* rct);
static void draw_borders(void);

/* Reformat the text in a window that has been resized */
static void resize_window()
{
  int x,y,z;
  int ofont_x, ofont_y;
  int owin;
  Rect rct;

  if (xfont_x == 0 || xfont_y == 0)
    return;

  ofont_x = xfont_x; ofont_y = xfont_y;
  xfont_x = xfont_get_width(font[style_font[4]]);
  xfont_y = xfont_get_height(font[style_font[4]]);

  if (xfont_x == 0 || xfont_y == 0)
    zmachine_fatal("Bad font selection");

  if (ofont_y != xfont_y)
    {
      int make_equal;
      
      for (x=1; x<3; x++)
	{
	  if (text_win[x].winly == text_win[0].winsy)
	    make_equal = 1;
	  else
	    make_equal = 0;

	  text_win[x].winsy = (text_win[x].winsy/ofont_y)*xfont_y;
	  text_win[x].winly = (text_win[x].winly/ofont_y)*xfont_y;
	  if (make_equal)
	    text_win[0].winsy = text_win[x].winsy;
	}
    }

  owin = cur_win;
  cur_win = 0;

  GetWindowBounds(zoomWindow, kWindowContentRgn, &rct);
  
  if ((rct.bottom-rct.top) <= CURWIN.winsy)
    rct.bottom = rct.top + CURWIN.winsy + xfont_y;

  total_x = rct.right - rct.left;
  total_y = rct.bottom - rct.top;

  MoveControl(zoomScroll, total_x - 15, 0);
  SizeControl(zoomScroll, 16, total_y-14);
  
  size_x = (total_x-19)/xfont_x;
  size_y = (total_y-4)/xfont_y;

  win_x = total_x-19;
  win_y = total_y-4;

  /* Resize and reformat the overlay windows */
  for (x=1; x<=2; x++)
    {
      cur_win = x;
      
      if (size_y > max_y)
	{
	  CURWIN.cline = realloc(CURWIN.cline, sizeof(struct cellline)*size_y);

	  /* Allocate new rows */
	  for (y=max_y; y<size_y; y++)
	    {
	      CURWIN.cline[y].cell = malloc(sizeof(int)*max_x);
	      CURWIN.cline[y].fg   = malloc(sizeof(char)*max_x);
	      CURWIN.cline[y].bg   = malloc(sizeof(char)*max_x);
	      CURWIN.cline[y].font = malloc(sizeof(char)*max_x);

	      for (z=0; z<max_x; z++)
		{
		  CURWIN.cline[y].cell[z] = ' ';
		  CURWIN.cline[y].fg[z]   = CURWIN.cline[max_y-1].fg[z];
		  CURWIN.cline[y].bg[z]   = CURWIN.cline[max_y-1].bg[z];
		  CURWIN.cline[y].font[z] = style_font[4];
		}
	    }
	}
      
      if (size_x > max_x)
	{
	  /* Allocate new columns */
	  for (y=0; y<(max_y>size_y?max_y:size_y); y++)
	    {
	      CURWIN.cline[y].cell = realloc(CURWIN.cline[y].cell,
					     sizeof(int)*size_x);
	      CURWIN.cline[y].fg   = realloc(CURWIN.cline[y].fg,
					     sizeof(char)*size_x);
	      CURWIN.cline[y].bg   = realloc(CURWIN.cline[y].bg,
					     sizeof(char)*size_x);
	      CURWIN.cline[y].font = realloc(CURWIN.cline[y].font,
					     sizeof(char)*size_x);
	      for (z=max_x; z<size_x; z++)
		{
		  CURWIN.cline[y].cell[z] = ' ';
		  CURWIN.cline[y].fg[z]   = CURWIN.cline[y].fg[max_x-1];
		  CURWIN.cline[y].bg[z]   = CURWIN.cline[y].bg[max_x-1];
		  CURWIN.cline[y].font[z] = style_font[4];
		}
	    }
	}
    }

  if (size_x > max_x)
    max_x = size_x;
  if (size_y > max_y)
    max_y = size_y;
  
  /* Resize and reformat the text window */
  cur_win = 0;
  
  CURWIN.winlx = win_x;
  CURWIN.winly = win_y;

  if (CURWIN.line != NULL)
    {
      struct line* line;
      struct line* next;

      CURWIN.topline = NULL;
      
      CURWIN.ypos = CURWIN.line->baseline - CURWIN.line->ascent;
      CURWIN.xpos = 0;

      line = CURWIN.line;
      while (line != NULL)
	{
	  next = line->next;
	  free(line);
	  line = next;
	}

      CURWIN.line = CURWIN.lastline = NULL;

      if (CURWIN.text != NULL)
	{
	  CURWIN.lasttext = CURWIN.text;
	  while (CURWIN.lasttext->next != NULL)
	    {
	      format_last_text(0);
	      CURWIN.lasttext = CURWIN.lasttext->next;
	    }
	  format_last_text(0);
	}
    }
  
  /* Scroll more text onto the screen if we can */
  cur_win = 0;
  if (CURWIN.lastline != NULL)
    {
      if (CURWIN.lastline->baseline+CURWIN.lastline->descent < win_y)
	{
	  /* Scroll everything down */
	  int down;
	  struct line* l;

	  down = win_y -
	    (CURWIN.lastline->baseline+CURWIN.lastline->descent);

	  l = CURWIN.line;
	  while (l != NULL)
	    {
	      l->baseline += down;

	      l = l->next;
	    }
	}

      if (CURWIN.line->baseline-CURWIN.line->ascent > start_y)
	{
	  /* Scroll everything up */
	  int up;
	  struct line* l;

	  up = (CURWIN.line->baseline-CURWIN.line->ascent) - start_y;

	  l = CURWIN.line;
	  while (l != NULL)
	    {
	      l->baseline -= up;

	      l = l->next;
	    }
	}
    }

  redraw_input_text();
  
  zmachine_resize_display(display_get_info());
  
  cur_win = owin;
}

/* Configure the size of a window */
static void size_window(void)
{
  Rect bounds;

  xfont_x = xfont_get_width(font[style_font[4]]);
  xfont_y = xfont_get_height(font[style_font[4]]);
  
  win_x = xfont_x*size_x;
  win_y = xfont_y*size_y;
  total_x = win_x + 19;
  total_y = win_y + 4;

  MoveControl(zoomScroll, total_x - 15, 0);
  SizeControl(zoomScroll, 15, total_y);

  GetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);
  bounds.right = bounds.left + total_x;
  bounds.bottom = bounds.top + total_y;
  SetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);
}

/* Draw the caret */
static void draw_caret()
{
  CGrafPtr thePort;
  Rect portRect;

  thePort = GetQDGlobalsThePort();
  GetPortBounds(thePort, &portRect); 

  if ((caret_on^caret_shown)) /* If the caret needs redrawing... */
    {
      /* 
       * I'd quite like to implement a coloured caret as in the 
       * Windows & X versions, but RGBForeColor doesn't seem to
       * work well with PenMode(srcXor). Well, s/well/at all/.
       */
      PenNormal();
      PenMode(srcXor);
      PenSize(2,1);
      MoveTo(portRect.left+caret_x+2, portRect.top+caret_y+2);
      Line(0, caret_height);

      PenNormal();

      caret_shown = !caret_shown;
    }
}

/* Redraw the caret */
static void redraw_caret(void)
{
  GrafPtr oldport;
  
  if (!updating)
    {
      Rect clip;

      GetPort(&oldport);

      SetPort(GetWindowPort(zoomWindow));
      
      clip.left = 2;
      clip.right = clip.left+win_x;
      clip.top = 2;
      clip.bottom = clip.top+win_y;
      ClipRect(&clip);
    }

  draw_caret();

  if (!updating)
    {
      Rect clip;

      clip.left = 0;
      clip.right = total_x;
      clip.top = 0;
      clip.bottom = total_y;
      ClipRect(&clip);

      SetPort(oldport);
    }
}

/* Force the caret to be hidden */
static void hide_caret(void)
{
  caret_on = 0;
  redraw_caret();
}

/* Force the caret to be shown */
static void show_caret(void)
{
  caret_on = 1;
  redraw_caret();
}

/* Flash the caret */
static void flash_caret(void)
{
  caret_on = !caret_on;
  redraw_caret();
}

static pascal void caret_flasher(EventLoopTimerRef iTimer,
				 void*             data)
{
  if (caret_flashing)
    {
      flash_caret();
    }
}

/* Draw the current input buffer */
static void draw_input_text(void)
{
  int w;
  int on;
  int fg, bg;

  fg = CURWIN.fore;
  bg = CURWIN.back;

  if (CURWIN.style&1)
    {
      fg = CURWIN.back;
      bg = CURWIN.fore;
    }

  on = caret_on;
  hide_caret();

  if (CURWIN.overlay)
    {
      input_x = caret_x = xfont_x*CURWIN.xpos;
      input_y = caret_y = xfont_y*CURWIN.ypos;
      caret_height = xfont_y;
    }
  else
    {
      if (CURWIN.lastline != NULL)
	{
	  input_x = caret_x = CURWIN.xpos;
	  input_y = caret_y = CURWIN.lastline->baseline-scrollpos;
	  caret_y -= CURWIN.lastline->ascent;
	  caret_height = CURWIN.lastline->ascent+CURWIN.lastline->descent-1;
	}
      else
	{
	  input_x = input_y = caret_x = caret_y = 0;
	  caret_height = xfont_y-1;
	}
    }

  if (text_buf != NULL)
    {
      Rect rct;

      CGrafPtr thePort;
      Rect portRect;
      
      thePort = GetQDGlobalsThePort();
      GetPortBounds(thePort, &portRect); 

      w = xfont_get_text_width(font[style_font[CURSTYLE]],
			       text_buf,
			       istrlen(text_buf));

      PenNormal();
      rct.left   = portRect.left + input_x + w + 2;
      rct.right  = portRect.left + win_x+2;
      rct.top    = portRect.top + caret_y+2;
      rct.bottom = rct.top + xfont_get_height(font[style_font[CURSTYLE]]);
      RGBForeColor(&maccolour[bg]);
      PaintRect(&rct);

      caret_x += xfont_get_text_width(font[style_font[CURSTYLE]],
				      text_buf,
				      buf_offset);

      xfont_set_colours(fg, bg);
      xfont_plot_string(font[style_font[CURSTYLE]],
			input_x+2, -input_y-2,
			text_buf,
			istrlen(text_buf));
    }

  if (on)
    show_caret();
}

/* Redraw the input text */
static void redraw_input_text(void)
{
  GrafPtr oldport;
  Rect clip;
  
  GetPort(&oldport);
  
  SetPort(GetWindowPort(zoomWindow));
  
  clip.left = 2;
  clip.right = clip.left+win_x;
  clip.top = 2;
  clip.bottom = clip.right+win_y;
  ClipRect(&clip);

  draw_input_text();

  clip.left = 0;
  clip.right = total_x;
  clip.top = 0;
  clip.bottom = total_y;
  ClipRect(&clip);

  SetPort(oldport);
}

/* Redraw (part of?) the window */
void redraw_window(Rect* rct)
{
  GrafPtr oldport;
  RgnHandle oldclip = nil;

  if (!updating)
    {
      GetPort(&oldport);

      SetPort(GetWindowPort(zoomWindow));

      oldclip = NewRgn();
      GetClip(oldclip);

      ClipRect(rct);
    }
  
  draw_window(0, rct);
  draw_window(1, rct);
  draw_window(2, rct);
  caret_shown = 0;
  draw_input_text();
  draw_borders();

  if (!updating)
    {
      SetClip(oldclip);
      DisposeRgn(oldclip);

      SetPort(oldport);
    }
}

/***                           ----// 888 \\----                           ***/

/* Event handlers */

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
	    case 'REST':
	      if (!display_force_input("restore"))
		{
		  carbon_display_message("Zoom " VERSION " - note",
					 "Unable to force a restore at this point");
		}
	      break;

	    case 'SAVE':
	      if (!display_force_input("save"))
		{
		  carbon_display_message("Zoom " VERSION " - note",
					 "Unable to force a save at this point");
		}
	      break;
	     
	    case kHICommandQuit:
	      if (window_available)
		{
		  AlertStdCFStringAlertParamRec par;
		  OSStatus res;
		  
		  par.version       = kStdCFStringAlertVersionOne;
		  par.movable       = false;
		  par.helpButton    = false;
		  par.defaultText   = CFSTR("Quit Zoom");
		  par.cancelText    = CFSTR("Continue playing");
		  par.otherText     = nil;
		  par.defaultButton = kAlertStdAlertCancelButton;
		  par.cancelButton  = kAlertStdAlertOKButton;
		  par.position      = kWindowDefaultPosition;
		  par.flags         = 0;
		  
		  res = CreateStandardSheet(kAlertCautionAlert,
					    CFSTR("Are you sure you want to quit Zoom?"),
					    CFSTR("Any changes since your last save will be lost"),
					    &par,
					    GetWindowEventTarget(zoomWindow),
					    &quitdlog);
		  ShowSheetWindow(GetDialogWindow(quitdlog), zoomWindow);
		}
	      else
		{
		  quitflag = 1;
		}
	    }
	  return noErr;

	default:
	  return eventNotHandledErr;
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
		return noErr;
		break;

	      default:
		return eventNotHandledErr;
	      }
	  }
	  break;
	}

    case kEventClassAppleEvent:
      {
	EventRecord er;
	OSStatus erm;

	ConvertEventRefToEventRecord(event, &er);
	erm = AEProcessAppleEvent( &er );

	return erm;
      }
    }

  return eventNotHandledErr;
}

static inline int isect_rect(Rect* r1, Rect* r2)
{
  return 1;
}

/* Draws a Z-Machine window */
/*
 * *ahem* The zoom screen model (versions 1-5) is as follows:
 *
 * There are 3 windows - one main text window and two overlay windows.
 * One of the overlay windows is used as the 'split' window in version
 * 4+, and the other is used as the status bar in version 3 (all three
 * windows may be used if a v3 game splits the screen).
 *
 * Overlay windows are an array of cells that cover the window. As each
 * cell has a fixed size (or *should* do, there's not a lot stopping the
 * user from selecting a non-proportional font), there may be some space
 * left at the edges - this is filled in in the colours of the neighbouring
 * cells. The text window is a full formatted text window. We do things in
 * a slightly complicated manner here: while this does make bits of the
 * code pretty much unreadable, it has the advantage of allowing us to
 * resize and reformat the window dynamically (yay).
 *
 * Each overlay window has a 'solid' section and a 'transparent' section.
 * The 'solid' section is that defined by the split, the rest is transparent.
 * The difference between the sections comes when the background colour of
 * a cell is set to 255. In the 'solid' section, this cell will be plotted
 * in the background colour of the window. In the 'transparent' section,
 * this cell will not be plotted. All other cells are plotted in both
 * sections.
 *
 * The text window should be drawn first, followed by the overlay windows.
 */
static void draw_window(int   win,
			Rect* rct)
{
  struct line* line;
  int x;
  int width;
  int offset;
  int lasty;
  struct text* text;

  CGrafPtr thePort;
  Rect portRect;
  Rect frct;

  thePort = GetQDGlobalsThePort();
  GetPortBounds(thePort, &portRect); 

  if (text_win[win].overlay)
    {
      /* Window is an overlay window (status bars, etc) */
      int x,y;

      x = y = 0;

      for (y=(text_win[win].winsy/xfont_y); y<size_y; y++)
	{
	  int bg = 0;

	  for (x=0; x<size_x; x++)
	    {
	      if (text_win[win].cline[y].cell[x] != ' ' ||
		  text_win[win].cline[y].bg[x] != 255   ||
		  y*xfont_y<text_win[win].winly)
		{
		  int len;
		  int fn, fg;
		  
		  len = 1;
		  fg = text_win[win].cline[y].fg[x];
		  bg = text_win[win].cline[y].bg[x];
		  fn = text_win[win].cline[y].font[x];
		  
		  /* We want to plot as much as possible in one go */
		  while (text_win[win].cline[y].font[x+len] == fn &&
			 text_win[win].cline[y].fg[x+len]   == fg &&
			 text_win[win].cline[y].bg[x+len]   == bg &&
			 (bg != 255 ||
			  text_win[win].cline[y].cell[x+len] != ' ' ||
			  y*xfont_y<text_win[win].winly))
		    len++;
		  
		  if (bg == 255)
		    bg = fg;
		  
		  xfont_set_colours(fg, bg);
		  xfont_plot_string(font[text_win[win].cline[y].font[x]],
				    2 + x*xfont_x,
				    -(y*xfont_y +
				      xfont_get_ascent(font[text_win[win].cline[y].font[x]]))
				    - 2,
				    &text_win[win].cline[y].cell[x],
				    len);

		  x += len-1;
		}
	    }
	  
	  /* May need to fill in to the end of the line */
	  if (xfont_x*size_x < win_x &&
	      y*xfont_y<text_win[win].winly)
	    {
	      Rect frct;

	      frct.top    = portRect.top + y*xfont_y+2;
	      frct.left   = portRect.left + xfont_x*size_x+2;
	      frct.bottom = frct.top + xfont_y;
	      frct.right  = portRect.left + win_x+2;
	      RGBForeColor(&maccolour[bg]);
	      PaintRect(&frct);
	    }
	}
    }
  else
    {
      RgnHandle oldregion;
      RgnHandle newregion;

      /* Set up the clip region */
      oldregion = NewRgn();
      newregion = NewRgn();
      GetClip(oldregion);

      frct.left   = portRect.left+2;
      frct.right  = portRect.left + win_x + 2;
      frct.top    = portRect.top + text_win[win].winsy+2;
      frct.bottom = portRect.top + text_win[win].winly+2;
      RectRgn(newregion, &frct);

      SectRgn(oldregion, newregion, newregion);
      
      SetClip(newregion);

      line = text_win[win].line;

      /* Free any lines that scrolled off ages ago */
      if (line != NULL)
	while (line->baseline < -262144)
	  {
	    struct line* n;

	    n = line->next;
	    if (n == NULL)
	      break;

	    if (text_win[win].topline == line)
	      text_win[win].topline = NULL;

	    if (n->start != line->start)
	      {
		struct text* nt;
		
		if (line->start != text_win[win].text)
		  zmachine_fatal("Programmer is a spoon");
		text_win[win].text = n->start;

		text = line->start;
		while (text != n->start)
		  {
		    if (text == NULL)
		      zmachine_fatal("Programmer is a spoon");
		    nt = text->next;
		    free(text);
		    text = nt;
		  }
	      }
	    
	    free(line);
	    text_win[win].line = n;

	    line = n;
	  }

      /* Fill in to the start of the lines */
      if (line != NULL)
	{
	  frct.top    = portRect.top+text_win[win].winsy+2;
	  frct.bottom = portRect.top+line->baseline-line->ascent+2 - scrollpos;
	  frct.left   = portRect.left+2;
	  frct.right  = frct.left + win_x;
	  if (frct.top < frct.bottom)
	    {
	      RGBForeColor(&maccolour[text_win[win].winback]);
	      PaintRect(&frct);
	    }

	  lasty = frct.bottom;
	}
      else
	lasty = portRect.top + text_win[win].winsy + 2;

      /* Iterate through the lines and plot what's necessary */
      while (line != NULL)
	{
	  text   = line->start;
	  width     = 0;
	  offset    = line->offset;

	  /*
	   * Each line may span several text objects. We have to plot
	   * each one in turn.
	   */
	  for (x=0; x<line->n_chars;)
	    {
	      int w;
	      int toprint;

	      /* 
	       * Work out the amount of text to plot from the current 
	       * text object 
	       */
	      toprint = line->n_chars-x;
	      if (toprint > (text->len - offset))
		toprint = text->len - offset;
	      
	      if (toprint > 0)
		{
		  /* Plot the text */
		  if (text->text[toprint+offset-1] == 10)
		    {
		      toprint--;
		      x++;
		    }

		  w = xfont_get_text_width(font[text->font],
					   text->text + offset,
					   toprint);

		  xfont_set_colours(text->fg, text->bg);
		  if (line->baseline + line->descent - scrollpos >
		      rct->top &&
		      line->baseline - line->ascent - scrollpos <
		      rct->bottom)
		    {
		      xfont_plot_string(font[text->font],
					width+2,
					-line->baseline - 2 + scrollpos,
					text->text + offset,
					toprint);
		    }

		  x      += toprint;
		  offset += toprint;
		  width  += w;
		}
	      else
		{
		  /* At the end of this object - move onto the next */
		  offset = 0;
		  text = text->next;
		}
	    }

	  /* Fill in to the end of the line */
	  frct.top    = portRect.top+line->baseline - line->ascent + 2 -
	    scrollpos;
	  frct.bottom = frct.top + line->ascent + line->descent;
	  frct.left   = portRect.left + width+2;
	  frct.right  = portRect.left + win_x+2;
	  RGBForeColor(&maccolour[text_win[win].winback]);
	  PaintRect(&frct);

	  lasty = frct.bottom;

	  /* Move on */
	  line = line->next;
	}

      /* Fill in to the bottom of the window */
      frct.top    = lasty;
      frct.bottom = win_y+2;
      frct.left = 2;
      frct.right = 2+win_x;
      if (frct.top < frct.bottom)
	{
	  RGBForeColor(&maccolour[text_win[win].winback]);
	  PaintRect(&frct);
	}

      /* Reset the clip region */
      SetClip(oldregion);

      DisposeRgn(newregion);
      DisposeRgn(oldregion);
    }
}

static void draw_borders()
{
  Rect rct;

  CGrafPtr thePort;
  Rect portRect;

  thePort = GetQDGlobalsThePort();
  GetPortBounds(thePort, &portRect); 

  PenNormal();
  RGBForeColor(&maccolour[2]);

  /* Top */
  rct.left   = portRect.left;
  rct.right  = portRect.left+win_x+4;
  rct.top    = portRect.top;
  rct.bottom = rct.top+2;
  PaintRect(&rct);

  /* Bottom */
  rct.bottom = portRect.bottom;
  rct.top    = rct.bottom-2;
  PaintRect(&rct);

  /* Left */
  rct.left   = portRect.left;
  rct.right  = rct.left+2;
  rct.top    = portRect.top;
  rct.bottom = portRect.bottom;
  PaintRect(&rct);
  
  /* Right */
  rct.left  = portRect.left+win_x+2;
  rct.right = rct.left+2;
  PaintRect(&rct);
}

static void update_scroll(void)
{
  Rect rct;
  int newpos;
  
  newpos = GetControl32BitValue(zoomScroll);
  
  if (newpos != scrollpos)
    {
      scrollpos = newpos;

      rct.top    = text_win[0].winsy+2;
      rct.bottom = text_win[0].winly+2;
      rct.left   = 2;
      rct.right  = 2+win_x;

      redraw_window(&rct);
    }
}

static pascal void zoom_scroll_handler(ControlRef control,
				       ControlPartCode partcode)
{
  if (partcode)
    {
      int newpos;

      newpos = scrollpos;

      switch (partcode)
	{
	case kControlUpButtonPart:
	  newpos -= xfont_y;
	  break;
	case kControlDownButtonPart:
	  newpos += xfont_y;
	  break;

	case kControlPageUpPart:
	  newpos -= text_win[0].winly - text_win[0].winsy - xfont_y;
	  break;
	case kControlPageDownPart:
	  newpos += text_win[0].winly - text_win[0].winsy - xfont_y;
	  break;
	}

      if (newpos != scrollpos)
	{
	  if (text_win[0].line != NULL &&
	      newpos < text_win[0].line->baseline - text_win[0].line->ascent)
	    newpos = text_win[0].line->baseline - text_win[0].line->ascent;
	  if (newpos > 0)
	    newpos = 0;
	  
	  SetControl32BitValue(zoomScroll, newpos);
	}
    }
  update_scroll(); /* There's only one event, so we do this...  */
}

static pascal OSStatus zoom_wnd_handler(EventHandlerCallRef myHandlerChain,
					EventRef event, 
					void* data)
{
  UInt32    cla;
  UInt32    wha;

  int x;

  cla = GetEventClass(event);
  wha = GetEventKind(event);

  switch (cla)
    {
    case kEventClassWindow:
      switch (wha)
	{
	case kEventWindowDrawContent:
	  /* Draw the window */
	  {
	    Rect rct;

	    rct.top = rct.left = 0;
	    rct.bottom = total_y;
	    rct.right  = total_x;

	    updating = 1;
	    redraw_window(&rct);
	    updating = 0;
	  }
	  break;

	case kEventWindowResizeCompleted:
	  /* Force a complete window update */
	  scroll_overlays = 0;
	  resize_window();
	  scroll_overlays = 1;
	  display_update();
	  break;

	case kEventWindowBoundsChanged:
	  {
	    Rect rct;

	    /* Resize the text in the window */
	    scroll_overlays = 0;
	    resize_window();
	    scroll_overlays = 1;

	    rct.top = rct.left = 0;
	    rct.bottom = total_y;
	    rct.right  = total_x;
	    
	    /* Redraw the window */
	    updating = 1;
	    SetPort(GetWindowPort(zoomWindow));	    
	    ClipRect(&rct);
	    redraw_window(&rct);
	    updating = 0;
	  }
	  break;
	}
      break;

    case kEventClassCommand:
      switch (wha)
	{
	case kEventProcessCommand:
	  {
	    HICommand cmd;

	    GetEventParameter(event, kEventParamDirectObject,
			      typeHICommand, NULL, sizeof(HICommand),
			      NULL, &cmd);

	    switch (cmd.commandID)
	      {
	      case kHICommandOK:
		if (fataldlog != nil)
		  {
		    fataldlog = nil;
		    display_exit(1);
		    return noErr;
		  }
		else if (quitdlog != nil)
		  {
		    quitdlog = nil;
		    display_exit(0);
		    return noErr;
		  }

		return eventNotHandledErr;
		break;
		
	      default:
		return eventNotHandledErr;
	      }
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

	    GetEventParameter(event, kEventParamMouseLocation,
			      typeHIPoint, NULL, sizeof(HIPoint),
			      NULL, &argh);
	    point.h = argh.x;
	    point.v = argh.y;
	    part = FindWindow(point, &ourwindow);

	    switch (part)
	      {
	      case inContent:
		return eventNotHandledErr;

	      case inGoAway:
		if (TrackGoAway(ourwindow, point))
		  {
		    AlertStdCFStringAlertParamRec par;
		    OSStatus res;

		    par.version       = kStdCFStringAlertVersionOne;
		    par.movable       = false;
		    par.helpButton    = false;
		    par.defaultText   = CFSTR("Quit Zoom");
		    par.cancelText    = CFSTR("Continue playing");
		    par.otherText     = nil;
		    par.defaultButton = kAlertStdAlertCancelButton;
		    par.cancelButton  = kAlertStdAlertOKButton;
		    par.position      = kWindowDefaultPosition;
		    par.flags         = 0;

		    res = CreateStandardSheet(kAlertCautionAlert,
					      CFSTR("Are you sure you want to quit Zoom?"),
					      CFSTR("Any changes since your last save will be lost"),
					      &par,
					      GetWindowEventTarget(zoomWindow),
					      &quitdlog);
		    ShowSheetWindow(GetDialogWindow(quitdlog), zoomWindow);
		  }
		break;

	      default:
		return eventNotHandledErr;
	      }
	  }
	}
      break;

    case kEventClassTextInput:
      switch (wha)
	{
	case kEventTextInputUnicodeForKeyEvent:
	  {
	    UniChar* text;
	    UInt32   size;

	    if (scrollpos != 0)
	      {
		SetControl32BitValue(zoomScroll, 0);
		update_scroll();
	      }

	    /* Read the text */
	    GetEventParameter(event, kEventParamTextInputSendText,
			      typeUnicodeText, NULL, 0, &size, NULL);
	    if (size == 0)
	      return eventNotHandledErr;
	    text = malloc(size);
	    GetEventParameter(event, kEventParamTextInputSendText,
			      typeUnicodeText, NULL, size, NULL, text);
	    size >>= 1;

	    /* 
	     * We handle the even differently depending on whether or not
	     * we are reading into a text buffer
	     */
	    if (text_buf == NULL)
	      {
		/* Waiting for a single keypress */
		if (size != 1)
		  {
		    zmachine_warning("Multiple Unicode characters received - only returning one to the game");
		  }
		
		switch (text[0])
		  {
		  case kUpArrowCharCode:
		    read_key = 129;
		    break;
		  case kDownArrowCharCode:
		    read_key = 130;
		    break;
		  case kLeftArrowCharCode:
		    read_key = 131;
		    break;
		  case kRightArrowCharCode:
		    read_key = 132;
		    break;

		  case kReturnCharCode:
		    read_key = 13;
		    break;

		  case kDeleteCharCode:
		  case kBackspaceCharCode:
		    read_key = 8;
		    break;

		  case kFunctionKeyCharCode:
		    /* FIXME: how do we deal with this? */
		    break;

		  default:
		    if (text[0] >= 32)
		      read_key = text[0];
		    break;
		  }
	      }
	    else
	      {
		/* We're dealing with an input buffer */
		switch (text[0])
		  {
		  case kUpArrowCharCode:
		    if (history_pos == NULL)
		      history_pos = last_string;
		    else
		      if (history_pos->next != NULL)
			history_pos = history_pos->next;
		    if (history_pos != NULL)
		      {
			if (istrlen(history_pos->string) < max_buflen)
			  istrcpy(text_buf, history_pos->string);
			
			buf_offset = istrlen(text_buf);
		      }
		    redraw_input_text();
		    break;
		  case kDownArrowCharCode:
		    if (history_pos != NULL)
		      {
			history_pos = history_pos->last;
			if (history_pos != NULL)
			  {
			    if (istrlen(history_pos->string) < max_buflen)
			      istrcpy(text_buf, history_pos->string);
			    buf_offset = istrlen(text_buf);
			  }
			else
			  {
			    text_buf[0] = 0;
			    buf_offset = 0;
			  }
		      }
		    
		    redraw_input_text();
		    break;
		    
		  case kLeftArrowCharCode:
		    if (buf_offset > 0)
		      buf_offset--;
		    redraw_input_text();
		    break;
		  case kRightArrowCharCode:
		    if (buf_offset < istrlen(text_buf))
		      buf_offset++;
		    redraw_input_text();
		    break;
		    
		  case kDeleteCharCode:
		  case kBackspaceCharCode:
		    if (buf_offset > 0)
		      {
			int  x;
			
			for (x=buf_offset-1; text_buf[x] != 0; x++)
			  {
			    text_buf[x] = text_buf[x+1];
			  }
			buf_offset--;
			
			redraw_input_text();
		      }
		    break;
		    
		  case kReturnCharCode:
		    {
		      history_item* newhist;
		      
		      newhist = malloc(sizeof(history_item));
		      newhist->last = NULL;
		      newhist->next = last_string;
		      if (last_string)
			last_string->last = newhist;
		      newhist->string = malloc(sizeof(int)*(istrlen(text_buf)+1));
		      istrcpy(newhist->string, text_buf);
		      last_string = newhist;
		    }
		    
		    display_prints(text_buf);
		    display_prints_c("\n");
		    text_buf = NULL;
		    read_key = 10;
		    break;
		    
		  case kFunctionKeyCharCode:
		    /* FIXME: how do we deal with this? */
		    break;

		  default:
		    for (x=0; x<size; x++)
		      {
			if (text_buf[buf_offset] == 0 &&
			    buf_offset < max_buflen)
			  { 
			    text_buf[buf_offset++] = text[x];
			    text_buf[buf_offset] = 0;
			  }
			else
			  {
			    if ((insert && buf_offset < max_buflen-1) ||
				!insert)
			      {
				if (insert)
				  {
				    int x;
				    
				    for (x=istrlen(text_buf); x>=buf_offset; x--)
				      {
					text_buf[x+1] = text_buf[x];
				      }
				  }
				
				text_buf[buf_offset] = text[x];
				buf_offset++;
			      }
			  }
		      }
			
		    redraw_input_text();
		    break;
		  }
	      }

	    free(text);
	  }
	  break;
	}
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
  EventLoopRef    mainLoop;
  EventTargetRef  target;

  rc_colour* colours;
  int n_cols;
  int x;

  target = GetEventDispatcherTarget();

  /* Initialise font structures */
  rejig_fonts();

  /* Set up the colour structures */
  colours = rc_get_colours(&n_cols);
  
  if (colours != NULL)
    {
      for (x=3; x<14; x++)
	{
	  if ((x-3)<n_cols)
	    {
	      maccolour[x].red   = colours[x-3].r<<8;
	      maccolour[x].green = colours[x-3].g<<8;
	      maccolour[x].blue  = colours[x-3].b<<8;
	    }
	}
    }

  /* Resize the window */
  max_x = size_x = rc_get_xsize();
  max_y = size_y = rc_get_ysize();
  
  size_window();

  /* Setup the display */
  display_clear();

  /* Install a timer to flash the caret */
  mainLoop = GetMainEventLoop();
  InstallEventLoopTimer(mainLoop,
			FLASH_DELAY,
			FLASH_DELAY,
			NewEventLoopTimerUPP(caret_flasher),
			NULL,
			&caret_timer);

  /* Yay, we can now show the window */
  ShowWindow(zoomWindow);
  window_available = 1;
}

void display_reinitialise(void)
{
  rejig_fonts();

  display_clear();
  resize_window();
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

  SetControlViewSize    (zoomScroll, CURWIN.winly-CURWIN.winsy);
  SetControl32BitMinimum(zoomScroll, 0);
  SetControl32BitMaximum(zoomScroll, 0);
  SetControl32BitValue  (zoomScroll, 0);

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
  rct.bottom = total_y;
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

  rct.top    = CURWIN.lastline->baseline - CURWIN.lastline->ascent+2;
  rct.bottom = CURWIN.lastline->baseline + CURWIN.lastline->descent+2;
  rct.left   = 2;
  rct.right  = rct.left+win_x;
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
      if (scroll_overlays)
	{
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
	      /* Hmm, the standard isn't detailed on whether or not to break 
	       * on a hyphen. The MacOS version of Zoom is currently the only
	       * version to do so */
	      text->text[x] == '-'  ||
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

  if (CURWIN.line != NULL)
    {
      SetControlViewSize    (zoomScroll, (CURWIN.winly-CURWIN.winsy));
      SetControl32BitMinimum(zoomScroll, 
			     CURWIN.line->baseline - CURWIN.line->ascent - 
			     CURWIN.winsy);
      SetControl32BitMaximum(zoomScroll, 0);
    }
  else
    {
      SetControlViewSize    (zoomScroll, CURWIN.winly-CURWIN.winsy);
      SetControl32BitMinimum(zoomScroll, 0);
      SetControl32BitMaximum(zoomScroll, 0);
      SetControl32BitValue  (zoomScroll, 0);
    }
  
  rct.top    = CURWIN.lastline->baseline - CURWIN.lastline->ascent+2;
  rct.bottom = CURWIN.lastline->baseline + CURWIN.lastline->descent+2;
  rct.left   = 2;
  rct.right  = win_x+2;
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
		  rct.top = CURWIN.ypos*xfont_y+2;
		  rct.bottom = CURWIN.ypos*xfont_y+2+xfont_y;
		  rct.left   = sx*xfont_x+2;
		  rct.right  = win_x+2;
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
		  rct.top = CURWIN.ypos*xfont_y+2;
		  rct.bottom = CURWIN.ypos*xfont_y+2+xfont_y;
		  rct.left   = sx*xfont_x+2;
		  rct.right  = CURWIN.xpos*xfont_x+2;
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

      rct.top    = CURWIN.ypos*xfont_y+2;
      rct.bottom = CURWIN.ypos*xfont_y+2+xfont_y;
      rct.left   = sx*xfont_x+2;
      rct.right  = CURWIN.xpos*xfont_x+2;
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

  displayed_text = 0;
  result = process_events(timeout, buf, buflen);

  return result;
}

int display_readchar(long int timeout)
{
  displayed_text = 0;
  return process_events(timeout, NULL, 0);
}

/***                           ----// 888 \\----                           ***/

void display_set_title(const char* title)
{
  static char tit[256];

  strcpy(tit+1, "Zoom " VERSION " - ");
  strcat(tit+1, title);
  tit[0] = strlen(tit+1);
  SetWTitle(zoomWindow, tit);
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
  if (fore == -1)
    fore = DEFAULT_FORE;
  if (back == -1)
    back = DEFAULT_BACK;
  if (fore == -2)
    fore = CURWIN.fore - FIRST_ZCOLOUR;
  if (back == -2)
    back = CURWIN.back - FIRST_ZCOLOUR;

  CURWIN.fore = fore + FIRST_ZCOLOUR;
  CURWIN.back = back + FIRST_ZCOLOUR;
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

  if (CURWIN.line != NULL)
    {
      SetControlViewSize    (zoomScroll, (CURWIN.winly-CURWIN.winsy));
      SetControl32BitMinimum(zoomScroll, 
			     CURWIN.line->baseline - CURWIN.line->ascent - 
			     CURWIN.winsy);
      SetControl32BitMaximum(zoomScroll, 0);
    }
  else
    {
      SetControlViewSize    (zoomScroll, CURWIN.winly-CURWIN.winsy);
      SetControl32BitMinimum(zoomScroll, 0);
      SetControl32BitMaximum(zoomScroll, 0);
      SetControl32BitValue  (zoomScroll, 0);
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
  if (CURWIN.overlay)
    {
      CURWIN.xpos = x;
      CURWIN.ypos = y;
    }
  else
    {
      if (CURWIN.line != NULL)
	zmachine_fatal("Can't move the cursor in a non-overlay window when text has been printed");

      CURWIN.xpos = x*xfont_x;
      CURWIN.ypos = y*xfont_y;
      start_y = CURWIN.ypos;
    }
}

void display_set_gcursor (int x, int y)
{
  display_set_cursor(x, y);
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
  if (CURWIN.overlay)
    {
      int x;
      
      if (val == 1)
	val = size_x;
      else
	val += CURWIN.xpos;

      for (x=CURWIN.xpos; x<val; x++)
	{
	  CURWIN.cline[CURWIN.ypos].cell[x] = ' ';
	  CURWIN.cline[CURWIN.ypos].fg[x]   = CURWIN.back;
	  CURWIN.cline[CURWIN.ypos].bg[x]   = 255;
	  CURWIN.cline[CURWIN.ypos].font[x] = style_font[4];
	}
    }
}

void display_force_fixed (int window, int val)
{
  CURWIN.force_fixed = val;
}

void display_beep        (void)
{
}

void display_terminating (unsigned char* table)
{
  int x;

  for (x=0; x<256; x++)
    terminating[x] = 0;

  if (table != NULL)
    {
      for (x=0; table[x] != 0; x++)
	{
	  terminating[table[x]] = 1;

	  if (table[x] == 255)
	    {
	      int y;

	      for (y=129; y<=154; y++)
		terminating[y] = 1;
	      for (y=252; y<255; y++)
		terminating[y] = 1;
	    }
	}
    }
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
  
  dis.lines         = size_y;
  dis.columns       = size_x;
  dis.width         = size_x;
  dis.height        = size_y;
  dis.font_width    = 1;
  dis.font_height   = 1;
  dis.pictures      = 0;
  dis.fore          = DEFAULT_FORE;
  dis.back          = DEFAULT_BACK;

  return &dis;
}

extern int zoom_main(int, char**);

int main(int argc, char** argv)
{
  IBNibRef nib;
  Rect rct;
  EventTypeSpec   appevts[] = 
    { 
      { kEventClassCommand, kEventCommandProcess },
      { kEventClassMouse,   kEventMouseDown },
      { kEventClassAppleEvent, kEventAppleEvent }
    };
  EventTypeSpec   wndevts[] = 
    { 
      { kEventClassWindow,     kEventWindowDrawContent },
      { kEventClassWindow,     kEventWindowResizeCompleted },
      { kEventClassWindow,     kEventWindowBoundsChanged },
      { kEventClassMouse,      kEventMouseDown },
      { kEventClassCommand,    kEventProcessCommand },
      { kEventClassTextInput,  kEventTextInputUnicodeForKeyEvent }
    };

  EventTargetRef target;
  EventRef       event;

  CreateNibReference(CFSTR("zoom"), &nib);
  SetMenuBarFromNib(nib, CFSTR("MenuBar"));
  DisposeNibReference(nib);

  /* Create the window */
  rct.top = 100;
  rct.left = 100;
  rct.bottom = rct.top + 480;
  rct.right = rct.left + 640;
  CreateNewWindow(kDocumentWindowClass,
		  kWindowStandardDocumentAttributes|
		  kWindowCollapseBoxAttribute|
		  kWindowLiveResizeAttribute|
		  kWindowStandardHandlerAttribute,
		  &rct,
		  &zoomWindow);

  /* Create the scrollback scrollbar */
  rct.top    = 0;
  rct.left   = 640-15;
  rct.bottom = 480;
  rct.right  = 640;
  CreateScrollBarControl(zoomWindow, &rct, 0,0,0,0, true, 
			 NewControlActionUPP(zoom_scroll_handler), 
			 &zoomScroll);
  
  /* Apple Event handlers */
  EnableMenuCommand(NULL,kAEShowPreferences);
  
  AEInstallEventHandler(kCoreEventClass, kAEOpenApplication, 
			NewAEEventHandlerUPP(ae_open_handler), 0,
			false);
  AEInstallEventHandler(kCoreEventClass, kAEReopenApplication, 
			NewAEEventHandlerUPP(ae_reopen_handler), 0,
			false);
  AEInstallEventHandler(kCoreEventClass, kAEQuitApplication, 
			NewAEEventHandlerUPP(ae_quit_handler), 0,
			false);
  AEInstallEventHandler(kCoreEventClass, kAEPrintDocuments, 
			NewAEEventHandlerUPP(ae_print_handler), 0,
			false);
  AEInstallEventHandler(kCoreEventClass, kAEOpenDocuments, 
			NewAEEventHandlerUPP(ae_opendocs_handler), 0,
			false);

  /* Setup event handlers */
  InstallApplicationEventHandler(NewEventHandlerUPP(zoom_evt_handler),
				 3, appevts, 0, NULL);
  InstallWindowEventHandler(zoomWindow,
			    NewEventHandlerUPP(zoom_wnd_handler),
			    6, wndevts, 0, NULL);

  /* Wait for the open event to arrive */

  /* 
   * (I originally didn't bother to do this. However, it turns out that if
   * you try to, for example, open a dialog box before this event and then
   * carry on, things break in subtle and irritating ways)
   */
  target = GetEventDispatcherTarget();

  while (!quitflag && !mac_openflag)
    {
      if (ReceiveNextEvent(0, NULL, kEventDurationForever, true, &event) == noErr)
	{
	  SendEventToEventTarget(event, target);
	  ReleaseEvent(event);
	}
    }

  zoom_main(argc, argv);

  return 0;
}

static void process_menu_command(long menres)
{
  HiliteMenu(0);
}

static pascal void timeout_time(EventLoopTimerRef iTimer,
				void*             data)
{
  read_key = 0;
  QuitEventLoop(GetMainEventLoop()); /* Give it a poke */
}

static int process_events(long int timeout,
			  int* buf,
			  int  buflen)
{
  EventRef event;
  EventTargetRef target;
  EventLoopTimerRef ourtime = nil;

  target = GetEventDispatcherTarget();

  if (forceopenfs != NULL)
    {
      free(forceopenfs);
      forceopenfs = NULL;
    }

  if (timeout > 0)
    {
      static EventLoopTimerUPP timer = NULL;

      if (timer == NULL)
	timer = NewEventLoopTimerUPP(timeout_time);

      InstallEventLoopTimer(GetMainEventLoop(),
			    kEventDurationMillisecond*timeout,
			    0,
			    timer,
			    NULL,
			    &ourtime);
    }
			  

  show_caret();
  caret_flashing = 1;
  display_update();

  if (buf != NULL)
    {
      text_buf    = buf;
      max_buflen  = buflen;
      buf_offset  = istrlen(buf);
      history_pos = NULL;
      read_key    = -1;
    }
  else
    {
      text_buf   = NULL;
      buf_offset = 0;
      read_key   = -1;
    }

  while (!quitflag && read_key == -1)
    {
      if (ReceiveNextEvent(0, NULL, kEventDurationForever, true, &event) == noErr)
	{
	  SendEventToEventTarget(event, target);
	  ReleaseEvent(event);
	}

      if (force_text != NULL && buf != NULL)
	{
	  int x,len;

	  len = strlen(force_text);

	  for (x=0; x<len; x++)
	    {
	      buf[x] = force_text[x];
	    }
	  buf[len] = '\0';
	  read_key = 10;
	  force_text = NULL;

	  display_prints(buf);
	  display_prints_c("\n");
	  text_buf = NULL;
	}
    }

  if (ourtime != nil)
    {
      RemoveEventLoopTimer(ourtime);
    }

  text_buf = NULL;
  force_text = NULL;

  caret_flashing = 0;
  hide_caret();

  if (read_key != -1)
    return read_key;

  display_exit(0);
  
  return 0;
}

#endif
