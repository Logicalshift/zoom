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

#include "zmachine.h"
#include "stream.h"
#include "display.h"

static int buffering = 1;
static int buflen    = 0;
static int bufpos    = 0;
static ZByte* buffer = NULL;

static void prints(const char* const s)
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
    fputs(s, machine.transcript_file);
}

void stream_prints(const char* s)
{
  int len, x;
  
  if (!buffering)
    {
      prints(s);
      return;
    }

  len = strlen(s);
  while (bufpos + len + 1 > buflen)
    {
      buflen += 1024;
      buffer = realloc(buffer, buflen);
    }

  for (x=0; x<len; x++)
    {
      if (s[x] == 10)
	stream_flush_buffer();
      buffer[bufpos++] = s[x];
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
  int r;

  stream_flush_buffer();

  if (machine.script_on)
    {
      int pos = 0;
      char rc;
      
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
      r = display_readline(buf, len, timeout);
      if (r)
	stream_input(buf);
    }
      
  return r;
}

void stream_flush_buffer(void)
{
  if (bufpos <= 0)
    return;

  buffer[bufpos] = 0;
  prints(buffer);
  bufpos = 0;
}

void stream_buffering(int buf)
{
  if (!buf && buffering)
    stream_flush_buffer();

  buffering = buf;
}

void stream_printf(const char* const f, ...)
{
  va_list* ap;
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
      if (buffer[bufpos-1] != s[x])
	return;
      bufpos--;
    }
}
