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
 * Fonts for Mac OS
 */

#include "../config.h"

#if WINDOW_SYSTEM == 3

#include <stdlib.h>
#include <string.h>

#include <Carbon/Carbon.h>

#include "zmachine.h"
#include "font3.h"
#include "xfont.h"
#include "carbondisplay.h"

struct xfont
{
  enum
    {
      FONT_INTERNAL,
      FONT_FONT3
    } type;
  union
  {
    struct
    {
      FMFontFamily family;
      int size;
      int isbold;
      int isitalic;
      int isunderlined;

      TextEncoding      encoding;
      UnicodeToTextInfo convert;
    } mac;
  } data;
};

/***                           ----// 888 \\----                           ***/

void xfont_initialise(void)
{
}

void xfont_shutdown(void)
{
}

#define DEFAULT_FONT applFont


/*
 * Internal format for Mac OS font names
 *
 * "face name" width properties
 *
 * Where properties can be one or more of:
 *   b - bold
 *   i - italic
 *   u - underline
 */
static xfont* xfont_default_font(void)
{
  xfont* xf;

  xf = malloc(sizeof(struct xfont));
  xf->type = FONT_INTERNAL;
  xf->data.mac.family       = DEFAULT_FONT;
  xf->data.mac.size         = 12;
  xf->data.mac.isbold       = 0;
  xf->data.mac.isitalic     = 0;
  xf->data.mac.isunderlined = 0;
  return xf;
}

xfont* xfont_load_font(char* font)
{
  char   fontcopy[256];
  char*  face_name;
  Str255 family;
  char*  face_width;
  char*  face_props;
  xfont* xf;

  int x;

  if (strcmp(font, "font3") == 0)
    {
      zmachine_warning("Font 3 not currently supported under Mac OS X");

      xf = malloc(sizeof(struct xfont));
      xf->type = FONT_INTERNAL;
      xf->data.mac.family       = DEFAULT_FONT;
      xf->data.mac.size         = 12;
      xf->data.mac.isbold       = 0;
      xf->data.mac.isitalic     = 0;
      xf->data.mac.isunderlined = 0;
      return xf;
    }
  
  if (strlen(font) > 256)
    {
      zmachine_warning("Invalid font name (too long)");
 
      xf = malloc(sizeof(struct xfont));
      xf->type = FONT_INTERNAL;
      xf->data.mac.family       = DEFAULT_FONT;
      xf->data.mac.size         = 12;
      xf->data.mac.isbold       = 0;
      xf->data.mac.isitalic     = 0;
      xf->data.mac.isunderlined = 0;
      return xf;
    }

  /* Get the face name */
  strcpy(fontcopy, font);
  x = 0;
  while (fontcopy[x++] != '\'')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (font name must be in single quotes)", font);

	  xf = xfont_default_font();
	  return xf;
	}
    }

  face_name = &fontcopy[x];

  x--;
  while (fontcopy[++x] != '\'')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (missing \')", font);

	  xf = xfont_default_font();
	  return xf;
	}
    }
  fontcopy[x] = 0;

  /* Get the font width */
  while (fontcopy[++x] == ' ')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (no font size specified)", font);

	  xf = xfont_default_font();
	  return xf;
	}
    }

  face_width = &fontcopy[x];

  while (fontcopy[x] >= '0' &&
	 fontcopy[x] <= '9')
    x++;

  if (fontcopy[x] != ' ' &&
      fontcopy[x] != 0)
    {
      zmachine_warning("Invalid font name: %s (invalid size)", font);

      xf = xfont_default_font();
      return xf;
    }

  if (fontcopy[x] != 0)
    {
      fontcopy[x] = 0;
      face_props  = &fontcopy[x+1];
    }
  else
    face_props = NULL;

  xf = malloc(sizeof(xfont));
  xf->type = FONT_INTERNAL;
  family[0] = strlen(face_name);
  strcpy(family+1, face_name);
  xf->data.mac.family = FMGetFontFamilyFromName(family);
  if (xf->data.mac.family == kInvalidFontFamily)
    {
      zmachine_warning("Font '%s' not found, reverting to default", face_name);
      xf->data.mac.family = DEFAULT_FONT;
    }
  xf->data.mac.size = atoi(face_width);
  xf->data.mac.isbold = 0;  
  xf->data.mac.isitalic = 0;
  xf->data.mac.isunderlined = 0;

  if (face_props != NULL)
    {
      for (x=0; face_props[x] != 0; x++)
	{
	  switch (face_props[x])
	    {
	    case 'b':
	    case 'B':
	      xf->data.mac.isbold = 1;
	      break;

	    case 'i':
	    case 'I':
	      xf->data.mac.isitalic = 1;
	      break;

	    case 'u':
	    case 'U':
	      xf->data.mac.isunderlined = 1;
	      break;
	    }
	}
    }

  if (FMGetFontFamilyTextEncoding(xf->data.mac.family, &xf->data.mac.encoding)
      != noErr)
    zmachine_fatal("Unable to get encoding for font '%s'", face_name);
  if (CreateUnicodeToTextInfoByEncoding(xf->data.mac.encoding, &xf->data.mac.convert)
      != noErr)
    zmachine_fatal("Unable to create TextInfo structure for font '%s'", face_name);

  return xf;
}

void xfont_release_font(xfont* xf)
{
  DisposeUnicodeToTextInfo(&xf->data.mac.convert);
  free(xf);
}

static void select_font(xfont* font)
{
  TextFont(font->data.mac.family);
  TextSize(font->data.mac.size);
  TextFace((font->data.mac.isbold?bold:0)           |
	   (font->data.mac.isitalic?italic:0)       |
	   (font->data.mac.isunderlined?underline:0));
}

void xfont_set_colours(int fg, int bg)
{
  /* Implement me */
}

int xfont_get_height(xfont* xf)
{
  GrafPtr oldport;
  FontInfo fm;

  GetPort(&oldport);
  SetPort(GetWindowPort(zoomWindow));

  select_font(xf);
  GetFontInfo(&fm);

  SetPort(oldport);

  return fm.ascent + fm.descent;
}

int xfont_get_ascent(xfont* xf)
{
  GrafPtr oldport;
  FontInfo fm;

  GetPort(&oldport);
  SetPort(GetWindowPort(zoomWindow));

  select_font(xf);
  GetFontInfo(&fm);

  SetPort(oldport);

  return fm.ascent;
}

int xfont_get_descent(xfont* xf)
{
  GrafPtr oldport;
  FontInfo fm;

  GetPort(&oldport);
  SetPort(GetWindowPort(zoomWindow));

  select_font(xf);
  GetFontInfo(&fm);

  SetPort(oldport);

  return fm.descent;
}

int xfont_get_width(xfont* xf)
{
  GrafPtr oldport;
  FontInfo fm;

  GetPort(&oldport);
  SetPort(GetWindowPort(zoomWindow));

  select_font(xf);
  GetFontInfo(&fm);

  SetPort(oldport);

  return fm.widMax;
}

static char* convert_text(xfont* font,
			  const int* string,
			  int length,
			  ByteCount* olen)
{
  static UniChar* iunicode = NULL;
  static char*    outbuf   = NULL;
  static int      warned   = 0;

  int  z;

  ByteCount inread;
  ByteCount outlen;

  OSStatus res;

  iunicode = realloc(iunicode, sizeof(UniChar)*length);
  for (z=0; z < length; z++)
    {
      iunicode[z] = string[z];
    }

  outbuf = realloc(outbuf, length*2);

  res = ConvertFromUnicodeToText(font->data.mac.convert, 
				 sizeof(UniChar)*length, iunicode,
				 kUnicodeLooseMappingsMask, 0,
				 NULL, NULL, NULL,
				 length*2, &inread, &outlen,
				 outbuf);

  if (res != noErr)
    {
      if (warned == 0)
	{
	  warned = 1;
	  zmachine_warning("Unable to convert game text to font text");
	}

      return "<?>";
    }

  if (olen != NULL)
    (*olen) = outlen;

  return outbuf;
}

int xfont_get_text_width(xfont* xf,
			 const int* string,
			 int length)
{
  GrafPtr oldport;

  char*     outbuf;
  ByteCount outlen;
  SInt16    res;

  GetPort(&oldport);
  SetPort(GetWindowPort(zoomWindow));

  select_font(xf);
  outbuf = convert_text(xf, string, length, &outlen);
  
  res = TextWidth(outbuf, 0, outlen);

  SetPort(oldport);

  return res;
}

void xfont_plot_string(xfont* font,
		       int x, int y,
		       const int* string,
		       int length)
{
  char*     outbuf;
  ByteCount outlen;

  Rect portRect;

  CGrafPtr thePort = GetQDGlobalsThePort();
  
  GetPortBounds(thePort, &portRect);

  outbuf = convert_text(font, string, length, &outlen);
  
  select_font(font);
  MoveTo(portRect.left+x, portRect.top - y);
  DrawText(outbuf, 0, outlen);
}

#endif
