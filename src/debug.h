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

#ifndef __DEBUG_H
#define __DEBUG_H

#include "zmachine.h"
#include "file.h"
#include "hash.h"

/* === Debug data structures === */

typedef struct debug_breakpoint debug_breakpoint;
typedef struct debug_symbols    debug_symbols;
typedef struct debug_symbol     debug_symbol;
typedef struct debug_file       debug_file;
typedef struct debug_line       debug_line;

/* Symbols */
typedef struct debug_class      debug_class;
typedef struct debug_object     debug_object;
typedef struct debug_global     debug_global;
typedef struct debug_array      debug_array;
typedef struct debug_attr       debug_attr;
typedef struct debug_prop       debug_prop;
typedef struct debug_fakeact    debug_fakeact;
typedef struct debug_action     debug_action;
typedef struct debug_routine    debug_routine;

/* Information structures */
typedef struct debug_address    debug_address;

struct debug_file
{
  int number;
  char* name;
  char* realname;
};

struct debug_class
{
  char* name;
  
  int st_fl, st_ln, st_ch;
  int end_fl, end_ln, end_ch;
};

struct debug_object
{
  int number;
  char* name;
  
  int st_fl, st_ln, st_ch;
  int end_fl, end_ln, end_ch;
};

struct debug_global
{
  int   number;
  char* name;
};

struct debug_array
{
  int offset;
  char* name;
};

struct debug_attr
{
  int   number;
  char* name;
};

struct debug_prop
{
  int   number;
  char* name;
};

struct debug_fakeact
{
  int number;
  char* name;
};

struct debug_action
{
  int number;
  char* name;
};

struct debug_line
{
  int fl, ln, ch;
  ZDWord address;
};

struct debug_routine
{
  int number;
  
  int defn_fl, defn_ln, defn_ch;
  ZDWord start;

  ZDWord end;
  int end_fl, end_ln, end_ch;

  char* name;

  int    nvars;
  char** var;

  int         nlines;
  debug_line* line;
};

struct debug_symbol
{
  enum
    {
      dbg_class,
      dbg_object,
      dbg_global,
      dbg_attr,
      dbg_prop,
      dbg_action,
      dbg_fakeact,
      dbg_array,
      dbg_routine
    }
  type;

  union
  {
    debug_class    class;
    debug_object   object;
    debug_global   global;
    debug_attr     attr;
    debug_prop     prop;
    debug_action   action;
    debug_fakeact  fakeact;
    debug_array    array;
    int            routine;
  } data;
};

struct debug_breakpoint
{
  ZDWord address;
  ZByte original;
};

struct debug_symbols
{
  int nsymbols;
  hash symbol;
  hash file;

  debug_routine* routine;
  int            nroutines;
  debug_file*    files;
  int            nfiles;

  ZDWord         codearea;
};

struct debug_address
{
  debug_routine* routine;
  debug_line*    line;
};

extern debug_breakpoint* debug_bplist;
extern int               debug_nbps;
extern debug_symbols     debug_syms;

#define DEBUG_EOF_DBR 0
#define DEBUG_FILE_DBR 1
#define DEBUG_CLASS_DBR 2
#define DEBUG_OBJECT_DBR 3
#define DEBUG_GLOBAL_DBR 4
#define DEBUG_ATTR_DBR 5
#define DEBUG_PROP_DBR 6
#define DEBUG_FAKEACT_DBR 7
#define DEBUG_ACTION_DBR 8
#define DEBUG_HEADER_DBR 9
#define DEBUG_LINEREF_DBR 10
#define DEBUG_ROUTINE_DBR 11
#define DEBUG_ARRAY_DBR 12
#define DEBUG_MAP_DBR 13
#define DEBUG_ROUTINE_END_DBR 14

/* === Debug functions === */

/* Breakpoints */
int               debug_set_breakpoint  (int address);
int               debug_clear_breakpoint(int address);
debug_breakpoint* debug_get_breakpoint  (int address);

void              debug_run_breakpoint(ZDWord pc);

/* === Inform debug file functions === */

/* Initialisation/loading */
void              debug_load_symbols    (char* filename);

/* Information retrieval */
debug_address     debug_find_address    (int   address);

#endif

