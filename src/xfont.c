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
 * Font handling for X-Windows
 */

#include "../config.h"

#if WINDOW_SYSTEM == 1

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zmachine.h"
#include "xdisplay.h"
#include "xfont.h"
#include "font3.h"
#include "format.h"

#ifdef HAVE_XFT
# include <X11/Xft/Xft.h>
#endif

#ifdef HAVE_T1LIB
# include <t1lib.h>
# include <t1libx.h>
#endif

/* Definition of an xfont */

struct xfont
{
  enum
  {
    XFONT_X,
    XFONT_T1LIB,
    XFONT_XFT,
    XFONT_FONT3
  } type;
  union
  {
    XFontStruct* X;
    struct {
      int id;
      double size;
    } t1;
    XftFont* Xft;
  } data;
};

static int fore, back;

/***                           ----// 888 \\----                           ***/

/*
 * Function to plot a font 3 definition
 */

static void plot_font_3(Drawable draw, GC gc, int chr, int xpos, int ypos)
{
  static XPoint poly[32];
  int x;
    
  if (chr > 127 || chr < 32)
    return;
  chr-=32;

  if (font_3.chr[chr].num_coords < 0)
    {
      zmachine_warning("Attempt to plot unspecified character %i",
		       chr+32);
      return;
    }
  
  for (x=0; x<font_3.chr[chr].num_coords; x++)
    {
      poly[x].x = font_3.chr[chr].coords[x<<1];
      poly[x].y = font_3.chr[chr].coords[(x<<1)+1];

      poly[x].x *= xfont_x; poly[x].x /= 8; poly[x].x += xpos;
      poly[x].y *= xfont_y; poly[x].y /= 8; poly[x].y += ypos;
    }

  XFillPolygon(x_display,
	       draw, gc,
	       poly, font_3.chr[chr].num_coords,
	       Complex, CoordModeOrigin);
}

/***                           ----// 888 \\----                           ***/

void xfont_initialise(void)
{
#ifdef HAVE_T1LIB
  T1_InitLib(LOGFILE|T1_AA_CACHING);
  T1_SetX11Params(x_display, DefaultVisual(x_display, x_screen),
		  DefaultDepth(x_display, x_screen),
		  DefaultColormap(x_display, x_screen));
#endif
}

void xfont_shutdown(void)
{ }

xfont* xfont_load_font(char* font)
{
  xfont* f;

  f = malloc(sizeof(xfont));

  if (strcmp(font, "font3") == 0)
    {
      f->type = XFONT_FONT3;
      return f;
    }
  
#ifdef HAVE_T1LIB
  if (strcmp(font, "t1test") == 0)
    {
      f->type    = XFONT_T1LIB;
      f->data.t1.id   = 0;
      f->data.t1.size = 12;
      return f;
    }
#endif

  if (font[0] == '/')
    {
      zmachine_fatal("Font files are not supported in this version");
    }
  else
    {
#ifdef HAVE_XFT
      f->type = XFONT_XFT;
      f->data.Xft = XftFontOpenXlfd(x_display, x_screen, font);
      /*
				    XFT_XLFD, XftTypeString, font,
				    XFT_ANTIALIAS, XftTypeBool, True); */
      if (f->data.Xft != NULL)
	return f;

      zmachine_warning("XFT: Unable to load font '%s', trying standard X font", font);
#endif
      f->type = XFONT_X;
      f->data.X = XLoadQueryFont(x_display, font);
      if (f->data.X == NULL)
	{
	  zmachine_warning("Unable to load font %s - reverting to 8x13", font);
	  f->data.X = XLoadQueryFont(x_display, "8x13");
	  if (f->data.X == NULL)
	    zmachine_fatal("Unable to load font %s or fall back to 8x13", font);
	}
    }

  return f;
}

void xfont_release_font(xfont* f)
{
  switch (f->type)
    {
    case XFONT_X:
      XFreeFont(x_display, f->data.X);
      break;
    case XFONT_FONT3:
      break;
    }

  free(f);
}

void xfont_set_colours(int foreground,
		       int background)
{
  fore = foreground;
  back = background;
}

XFONT_MEASURE xfont_get_width(xfont* f)
{
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      return f->data.Xft->max_advance_width;
      break;
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      {
	BBox bounds;

	bounds = T1_GetFontBBox(f->data.t1.id);

	return (XFONT_MEASURE)(bounds.urx - bounds.llx)*f->data.t1.size / 
	  (XFONT_MEASURE)(bounds.ury - bounds.lly);
      }
      break;
#endif
    case XFONT_X:
      return f->data.X->max_bounds.width;
    case XFONT_FONT3:
      return xfont_x;
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

XFONT_MEASURE xfont_get_height(xfont* f)
{
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      return f->data.Xft->height;
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      return f->data.t1.size;
#endif
    case XFONT_X:
      return f->data.X->ascent + f->data.X->descent;
    case XFONT_FONT3:
      return xfont_y;
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

XFONT_MEASURE xfont_get_ascent(xfont* f)
{
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      return f->data.Xft->ascent;
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      {
	BBox bounds;

	bounds = T1_GetFontBBox(f->data.t1.id);

	return (XFONT_MEASURE)(bounds.ury-bounds.lly)/
	  (XFONT_MEASURE)(bounds.ury*f->data.t1.size);
      }
#endif
    case XFONT_X:
      return f->data.X->ascent;
    case XFONT_FONT3:
      return xfont_y;
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

XFONT_MEASURE xfont_get_descent(xfont* f)
{
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      return f->data.Xft->descent;
#endif
    case XFONT_X:
      return f->data.X->descent;
    case XFONT_FONT3:
      return 0;
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

XFONT_MEASURE xfont_get_text_width(xfont* f, const int* text, int len)
{
  static XChar2b* xtxt = NULL;
  int x;

  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      {
	XGlyphInfo ext;
	static XftChar16* xfttxt;

	xfttxt = realloc(xfttxt, (len+1)*sizeof(XftChar16));
	for (x=0; x<len; x++)
	  {
	    xfttxt[x] = text[x];
	  }

	XftTextExtents16(x_display, f->data.Xft, xfttxt, len, &ext);

	return ext.xOff;
      }
#endif
    case XFONT_X:
      xtxt = realloc(xtxt, (len+1)*sizeof(int));
      for (x=0; x<len; x++)
	{
	  xtxt[x].byte2 = text[x]&255;
	  xtxt[x].byte1 = (text[x]>>8)&255;
	}

      return XTextWidth16(f->data.X, xtxt, len);
    case XFONT_FONT3:
      return len*xfont_x;
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

void xfont_plot_string(xfont* f,
		       Drawable draw,
		       GC gc,
		       int x, int y,
		       const int* text, int len)
{
  static XChar2b* xtxt = NULL;
  int i;
  
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      {
	static XftChar16* xfttxt;

	xfttxt = realloc(xfttxt, (len+1)*sizeof(XftChar16));
	for (i=0; i<len; i++)
	  {
	    xfttxt[i] = text[i];
	  }

	XftDrawString16(xft_drawable, &xft_colour[fore], f->data.Xft,
			x, y, xfttxt, len);
      }
      break;
#endif

    case XFONT_X:
      xtxt = realloc(xtxt, (len+1)*sizeof(int));
      for (i=0; i<len; i++)
	{
	  xtxt[i].byte2 = text[i]&255;
	  xtxt[i].byte1 = (text[i]>>8)&255;
	}

      XSetForeground(x_display, gc, x_colour[fore].pixel);
      XSetFont(x_display, gc, f->data.X->fid);
      XDrawString16(x_display, draw, gc, x, y, xtxt, len);
      break;
      
    case XFONT_FONT3:
      XSetForeground(x_display, gc, x_colour[fore].pixel);
      {
	int pos;

	for (pos=0; pos<len; pos++)
	  {
	    plot_font_3(draw, gc, text[pos], x, y-xfont_y);
	    x+=xfont_x;
	  }
      }
      break;
    }
}

#endif
