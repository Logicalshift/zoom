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
 * Deal with input/output streams
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>

#include "zmachine.h"
#include "stream.h"
#include "display.h"
#include "zscii.h"

static int  buffering = 1;
static int  buflen    = 0;
static int  bufpos    = 0;
static int* buffer = NULL;

static int  zscii_unicode_table[256] =
{
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 000-007 */
  0x3f,0x3f,0x0a,0x3f, 0x3f,0x0a,0x3f,0x3f, /* 008-015 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 016-023 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 024-031 */
  0x20,0x21,0x22,0x23, 0x24,0x25,0x26,0x27, /* 032-039 */
  0x28,0x29,0x2a,0x2b, 0x2c,0x2d,0x2e,0x2f, /* 040-047 */
  0x30,0x31,0x32,0x33, 0x34,0x35,0x36,0x37, /* 048-055 */
  0x38,0x39,0x3a,0x3b, 0x3c,0x3d,0x3e,0x3f, /* 056-063 */
  0x40,0x41,0x42,0x43, 0x44,0x45,0x46,0x47, /* 064-071 */
  0x48,0x49,0x4a,0x4b, 0x4c,0x4d,0x4e,0x4f, /* 072-079 */
  0x50,0x51,0x52,0x53, 0x54,0x55,0x56,0x57, /* 080-087 */
  0x58,0x59,0x5a,0x5b, 0x5c,0x5d,0x5e,0x5f, /* 088-095 */
  0x60,0x61,0x62,0x63, 0x64,0x65,0x66,0x67, /* 096-103 */
  0x68,0x69,0x6a,0x6b, 0x6c,0x6d,0x6e,0x6f, /* 104-111 */
  0x70,0x71,0x72,0x73, 0x74,0x75,0x76,0x77, /* 112-119 */
  0x78,0x79,0x7a,0x7b, 0x7c,0x7d,0x7e,0x7f, /* 120-127 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 128-135 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 136-143 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 144-151 */
  0x3f,0x3f,0x3f,0xe4, 0xf6,0xfc,0xc4,0xd6, /* 152-159 */
  0xdc,0xdf,0xbb,0xab, 0xeb,0xef,0xff,0xcb, /* 160-167 */
  0xcf,0xe1,0xe9,0xed, 0xf3,0xfa,0xfd,0xc1, /* 168-175 */
  0xc9,0xcd,0xd3,0xda, 0xdd,0xe0,0xe8,0xec, /* 176-183 */
  0xf2,0xf9,0xc0,0xc8, 0xcc,0xd2,0xd9,0xe2, /* 184-191 */
  0xea,0xee,0xf4,0xfb, 0xc2,0xca,0xce,0xd4, /* 192-199 */
  0xdb,0xe5,0xc5,0xf8, 0xd8,0xe3,0xf1,0xf5, /* 200-207 */
  0xc3,0xd1,0xd5,0xe6, 0xc6,0xe7,0xc7,0xfe, /* 208-215 */
  0xf0,0xde,0xd0,0xa3, 0x153,0x152,0xa1,0xbf, /* 216-223 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 224-231 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 232-239 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f, /* 240-247 */
  0x3f,0x3f,0x3f,0x3f, 0x3f,0x3f,0x3f,0x3f  /* 248-255 */
};

static int* zscii_unicode = zscii_unicode_table;

/*
 * Translate a ZSCII string to a ISO 10646 one (well, Unicode, really)
 */
int* zscii_to_unicode(ZByte* string, int* len)
{
  static int* unistring = NULL;
  unsigned char* ascii;
  int x, l;

  ascii = zscii_to_ascii(string, len);

  l = strlen(ascii);
  unistring = realloc(unistring, sizeof(int)*(l+1));
  for (x=0; x<l; x++)
    {
      unistring[x] = zscii_unicode[ascii[x]];
    }
  unistring[l] = 0;

  return unistring;
}
  
static void prints(const int* const s)
{
  if (machine.memory_on)
    {
      ZByte* mem;
      ZUWord len;
      int x;

      len = Word(machine.memory_pos[machine.memory_on-1]);
      mem = Address(machine.memory_pos[machine.memory_on-1]);
      
      for (x=0; s[x] != 0; x++)
	{
	  if (s[x] == 10)
	    mem[(len++)+2] = 13;
	  else
	    mem[(len++)+2] = s[x];
	}

      mem[0] = len>>8;
      mem[1] = len;
      
      return;
    }

  if (machine.screen_on)
    {
      int old_style = 0;
      ZWord flags;

      flags = Word(ZH_flags2);
     
      if (flags&2)
	old_style = display_set_style(8);
      display_prints(s);
      if (flags&2)
	{
	  display_set_style(0);
	  display_set_style(old_style);
	}
    }
  if (machine.transcript_on == 1)
    {
      int x;

      for (x=0; s[x] != 0; x++)
	{
	  if (s[x] > 255)
	    fputc('?', machine.transcript_file);
	  else
	    fputc(s[x], machine.transcript_file);
	}
    }
}

void stream_prints(const unsigned char* s)
{
  int len, x;
  static int line = 0;
  
  if (!buffering)
    {
      int* txt;
      int x;

      txt = malloc(sizeof(int)*(strlen(s)+1));
      for (x=0; s[x] != 0; x++)
	txt[x] = zscii_unicode[s[x]];
      txt[x] = 0;
      prints(txt);
      free(txt);
      return;
    }

  len = strlen(s);
  while (bufpos + len + 1 > buflen)
    {
      buflen += 1024;
      buffer = realloc(buffer, sizeof(int)*buflen);
    }

  for (x=0; x<len; x++)
    {
      /*
      if (s[x] == 10)
	{
	  line++;
	  stream_flush_buffer();
	  if (line > 20)
	    {
	      line = 0;
	      if (machine.script_on)
		display_update();
	    }
	}
      */
      buffer[bufpos++] = zscii_unicode[s[x]];
    }
}

void stream_printc(int c)
{
  if (!buffering)
    {
      int x[2];

      x[0] = c;
      x[1] = 0;

      display_prints(x);
    }
  else
    {
      if (bufpos + 2 > buflen)
	{
	  buflen+=1024;
	  buffer = realloc(buffer, sizeof(int)*buflen);
	}
      if (c == 10)
	{
	  stream_flush_buffer();
	}
      buffer[bufpos++] = c;
    }
}

void stream_input(const char* s)
{
  if (machine.transcript_on == 1 ||
      machine.transcript_commands == 1)
    {
      fputs(s, machine.transcript_file);
      fputc('\n', machine.transcript_file);
    }
}

int stream_readline(char* buf, int len, long int timeout)
{
  int r,x;
  int* realbuf;

  stream_flush_buffer();

  if (machine.script_on)
    {
      int pos = 0;
      char rc;

      display_update();
      
      r = 1;

      while ((rc = fgetc(machine.script_file)) != 10)
	{
	  if (rc == EOF && pos == 0)
	    {
	      machine.script_on = 0;
	      fclose(machine.script_file);
	      machine.script_file = NULL;
	      
	      display_set_more(0, 1);
	      
	      return stream_readline(buf, len, timeout);
	    }
	  
	  if (rc >= 32 && rc < 127)
	    buf[pos++] = rc;
	  
	  if (pos >= len)
	    {
	      zmachine_warning("Input stream line exceeds length of input buffer");
	      break;
	    }
	  if (feof(machine.script_file))
	    break;
	}

      buf[pos++] = 0;
      stream_prints(buf);
      stream_prints("\n");
    }
  else
    {
      realbuf = malloc(sizeof(int)*(len+1));
      for (x=0; x<len; x++)
	realbuf[x] = buf[x];
      
      r = display_readline(realbuf, len, timeout);
      for (x=0; x<len; x++)
	{
	  if (realbuf[x] > 127)
	    buf[x] = '?';
	  else
	    buf[x] = realbuf[x];
	}
      
      if (r)
	stream_input(buf);
    }
      
  return r;
}

void stream_flush_buffer(void)
{
  static int flushing =  0;

  if (flushing)
    {
      return;
    }

  if (bufpos <= 0)
    return;
#ifdef DEBUG
  printf_debug("Buffer flushed\n");
#endif

  flushing = 1;

  buffer[bufpos] = 0;
  prints(buffer);
  bufpos = 0;

  flushing = 0;
}

void stream_buffering(int buf)
{
  if (!buf && buffering)
    stream_flush_buffer();

  buffering = buf;
}

void stream_printf(const char* const f, ...)
{
  va_list  ap;
  char     string[512];

  va_start(ap, f);
  vsprintf(string, f, ap);
  va_end(ap);

  stream_prints(string);  
}

void stream_remove_buffer(const char* s)
{
  int len, x;

  len = strlen(s);

  if (len > bufpos)
    return;

  for (x=len-1; x>=0; x--)
    {
      if (tolower(buffer[bufpos-1]) != tolower(s[x]))
	return;
      printf("Removing %i\n", s[x]);
      bufpos--;
    }
}

void stream_update_unicode_table(void)
{
  static int*  unitable = NULL;
  int          x;
  ZByte*       ztable;

  if (machine.heblen < 3)
    {
      zscii_unicode = zscii_unicode_table;
      return;
    }

  if (GetWord(machine.heb, ZHEB_unitable) == 0)
    {
      zscii_unicode = zscii_unicode_table;
      return;
    }
  
  unitable = realloc(unitable, sizeof(int)*256);    
  
  for (x=0; x<256; x++)
    {
      if ((x>=32 && x<127) ||
	  x==10 || x==13)
	{
	  unitable[x] = x;
	}
      else
	{
	  unitable[x] = 0x3f;
	}
    }

  ztable = Address((ZUWord)GetWord(machine.heb, ZHEB_unitable));

  if (ztable[0] > 96)
    zmachine_fatal("Bad unicode table - greater than 96 characters defined");

  for (x=0; x<ztable[0]; x++)
    {
      unitable[155+x] = (ztable[2*x]<<8)|ztable[2*x+1];
    }
  
  zscii_unicode = unitable;
}
