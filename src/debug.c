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
 * The debugger
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "debug.h"
#include "zscii.h"

debug_breakpoint* debug_bplist = NULL;
int               debug_nbps    = 0;

/***                           ----// 888 \\----                           ***/

/* Breakpoints */

int debug_set_breakpoint(int address)
{
  if (machine.memory[address] == 0xbc)
    return 0; /* Breakpoint already set */
  
  if (debug_get_breakpoint(address) != NULL)
    return 0; /* Breakpoint already set (shouldn't happen, but...) */

#ifdef DEBUG
  printf_debug("Setting BP @ %04x\n", address);
#endif

  debug_bplist = realloc(debug_bplist,
			 sizeof(debug_breakpoint)*(debug_nbps+1));
  debug_bplist[debug_nbps].address = address;
  debug_bplist[debug_nbps].original = machine.memory[address];

  machine.memory[address] = 0xbc; /* status_nop, our breakpoint */

  debug_nbps++;
  
  return 1;
}

debug_breakpoint* debug_get_breakpoint(int address)
{
  int x;

  for (x=0; x<debug_nbps; x++)
    {
      if (debug_bplist[x].address == address)
	return debug_bplist + x;
    }

  return NULL;
}

/***                           ----// 888 \\----                           ***/

/* Debug file */

debug_symbols debug_syms = { NULL, NULL, NULL, 0, NULL, 0 };

void debug_load_symbols(char* filename)
{
  ZFile* file;
  ZByte* db_file;
  int size;
  int pos;

  int done;

  debug_routine* this_routine;

  size = get_file_size(filename);
  file = open_file(filename);

  if (file == NULL)
    return;

  db_file = read_block(file, 0, size);

  close_file(file);

  if (db_file == NULL)
    return;

  display_printf("Debug: loading symbols from %s...\n", filename);

  if (db_file[0] != 0xde || db_file[1] != 0xbf)
    {
      display_printf("Debug: Bad debug file\n");
      free(db_file);
      return;
    }

  pos = 6;

  done = 0;

  while (pos < size && !done)
    {
      switch (db_file[pos])
	{
	case DEBUG_EOF_DBR:
	  done = 1;
	  break;

	case DEBUG_FILE_DBR:
	  {
	    debug_file fl;

	    fl.number = db_file[pos+1];
	    fl.name = malloc(sizeof(char)*(strlen(db_file + pos + 2) + 1));
	    strcpy(fl.name, db_file + pos + 2);
	    pos += 3 + strlen(fl.name);
	    fl.realname = malloc(sizeof(char)*(strlen(db_file + pos)));
	    strcpy(fl.realname, db_file + pos);
	    pos += strlen(fl.realname) + 1;

	    debug_syms.nfiles++;
	    
	    if (debug_syms.nfiles != fl.number)
	      {
		display_printf("Debug: file '%s' doesn't appear in order\n",
			       fl.name);
		goto failed;
	      }

	    debug_syms.files = realloc(debug_syms.files, 
				       sizeof(debug_file)*(debug_syms.nfiles+1));
	    debug_syms.files[fl.number] = fl;
	  }
	  break;
	  
	case DEBUG_CLASS_DBR:
	  {
	    debug_class c;

	    pos++;

	    c.name = malloc(sizeof(char)*(strlen(db_file + pos)+1));
	    strcpy(c.name, db_file + pos);
	    pos += strlen(db_file+pos) + 1;
	    
	    c.st_fl  = db_file[pos++];
	    c.st_ln  = db_file[pos++]<<8;
	    c.st_ln |= db_file[pos++];
	    c.st_ch  = db_file[pos++];
	    
	    c.end_fl  = db_file[pos++];
	    c.end_ln  = db_file[pos++]<<8;
	    c.end_ln |= db_file[pos++];
	    c.end_ch  = db_file[pos++];	    
	  }
	  break;

	case DEBUG_OBJECT_DBR:
	  {
	    debug_object o;

	    pos++;

	    o.number  = db_file[pos++]<<8;
	    o.number |= db_file[pos++];

	    o.name = malloc(sizeof(char)*(strlen(db_file + pos)+1));
	    strcpy(o.name, db_file + pos);
	    pos += strlen(db_file+pos) + 1;
	    
	    o.st_fl  = db_file[pos++];
	    o.st_ln  = db_file[pos++]<<8;
	    o.st_ln |= db_file[pos++];
	    o.st_ch  = db_file[pos++];
	    
	    o.end_fl  = db_file[pos++];
	    o.end_ln  = db_file[pos++]<<8;
	    o.end_ln |= db_file[pos++];
	    o.end_ch  = db_file[pos++];	    
	  }
	  break;
	  
	case DEBUG_GLOBAL_DBR:
	  {
	    debug_global g;

	    pos++;

	    g.number  = db_file[pos++]<<8;
	    g.number |= db_file[pos++];

	    g.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(g.name, db_file + pos);
	    pos += strlen(db_file + pos) + 1;
	  }
	  break;

	case DEBUG_ATTR_DBR:
	  {
	    debug_attr a;
 
	    pos++;

	    a.number  = db_file[pos++]<<8;
	    a.number |= db_file[pos++];

	    a.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(a.name, db_file + pos);
	    pos += strlen(a.name)+1;
	  }
	  break;

	case DEBUG_PROP_DBR:
	  {
	    debug_prop p;

	    pos++;

	    p.number  = db_file[pos++]<<8;
	    p.number |= db_file[pos++];

	    p.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(p.name, db_file + pos);
	    pos += strlen(p.name)+1;
	  }
	  break;

	case DEBUG_ACTION_DBR:
	  {
	    debug_action a;

	    pos++;

	    a.number  = db_file[pos++]<<8;
	    a.number |= db_file[pos++];

	    a.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(a.name, db_file + pos);
	    pos += strlen(db_file + pos) + 1;
	  }
	  break;

	case DEBUG_FAKEACT_DBR:
	  {
	    debug_fakeact a;

	    pos++;

	    a.number  = db_file[pos++]<<8;
	    a.number |= db_file[pos++];

	    a.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(a.name, db_file + pos);
	    pos += strlen(db_file + pos) + 1;
	  }
	  break;

	case DEBUG_ARRAY_DBR:
	  {
	    debug_array a;

	    pos++;

	    a.offset  = db_file[pos++]<<8;
	    a.offset |= db_file[pos++];

	    a.name = malloc(sizeof(char)*(strlen(db_file + pos) + 1));
	    strcpy(a.name, db_file + pos);
	    pos += strlen(db_file + pos) + 1;
	  }
	  break;

	case DEBUG_HEADER_DBR:
	  pos++;

	  pos += 64;
	  break;

	case DEBUG_LINEREF_DBR:
	  {
	    debug_line l;
	    int rno;
	    int nseq;
	    int x;

	    pos++;

	    rno   = db_file[pos++]<<8;
	    rno  |= db_file[pos++];
	    nseq  = db_file[pos++]<<8;
	    nseq |= db_file[pos++];

	    if (rno != this_routine->number)
	      {
		display_printf("Debug: routine number of line does not match current routine\n");
		goto failed;
	      }
	    
	    for (x=0; x<nseq; x++)
	      {
		l.fl  = db_file[pos++];
		l.ln  = db_file[pos++]<<8;
		l.ln |= db_file[pos++];
		l.ch  = db_file[pos++];

		l.address  = db_file[pos++]<<8;
		l.address |= db_file[pos++];
		l.address += this_routine->start;

		this_routine->line = realloc(this_routine->line,
					     sizeof(debug_line)*(this_routine->nlines+1));
		this_routine->line[this_routine->nlines] = l;
		this_routine->nlines++;
	      }
	  }
	  break;

	case DEBUG_ROUTINE_DBR:
	  {
	    debug_routine r;

	    pos++;

	    r.number   = db_file[pos++]<<8;
	    r.number  |= db_file[pos++];
	    r.defn_fl  = db_file[pos++];
	    r.defn_ln  = db_file[pos++]<<8;
	    r.defn_ln |= db_file[pos++];
	    r.defn_ch  = db_file[pos++];
	    
	    r.start  = db_file[pos++]<<16;
	    r.start |= db_file[pos++]<<8;
	    r.start |= db_file[pos++];

	    r.name = malloc(sizeof(char)*(strlen(db_file+pos) + 1));
	    strcpy(r.name, db_file + pos);
	    pos += strlen(r.name)+1;

	    r.nvars = 0;
	    r.var   = NULL;

	    while (db_file[pos] != 0)
	      {
		r.var = realloc(r.var, sizeof(char*)*(r.nvars+1));
		r.var[r.nvars] = malloc(sizeof(char)*(strlen(db_file+pos) + 1));
		strcpy(r.var[r.nvars], db_file+pos);
		pos += strlen(r.var[r.nvars]) + 1;
		r.nvars++;
	      }
	    pos++;

	    r.nlines = 0;
	    r.line   = NULL;
	    
	    debug_syms.routine = realloc(debug_syms.routine,
					 sizeof(debug_routine)*
					 (debug_syms.nroutines+1));

	    debug_syms.routine[debug_syms.nroutines] = r;
	    this_routine = debug_syms.routine + debug_syms.nroutines;

	    debug_syms.nroutines++;
	  }
	  break;
	  
	case DEBUG_ROUTINE_END_DBR:
	  {
	    int rno;

	    pos++;

	    rno   = db_file[pos++]<<8;
	    rno  |= db_file[pos++];

	    if (rno != this_routine->number)
	      {
		display_printf("Debug: routine number of EOR does not match current routine\n");
		goto failed;
	      }

	    this_routine->end_fl  = db_file[pos++];
	    this_routine->end_ln  = db_file[pos++]<<8;
	    this_routine->end_ln |= db_file[pos++];
	    this_routine->end_ch  = db_file[pos++];

	    this_routine->end     = db_file[pos++]<<16;
	    this_routine->end    |= db_file[pos++]<<8;
	    this_routine->end    |= db_file[pos++];
	  }
	  break;

	case DEBUG_MAP_DBR:
	  {
	    pos++;

	    while (db_file[pos] != 0)
	      {
		pos += strlen(db_file + pos) + 1 + 3;
	      }
	    pos++;
	  }
	  break;

	default:
	  display_printf("Debug: unknown record type %i\n", db_file[pos]);
	  goto failed;
	  return;
	}
    }

  free(db_file);
  return;

 failed:
  free(db_file);
}

