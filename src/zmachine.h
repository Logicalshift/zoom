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
 * Data types that describe the Z-Machine
 */

#ifndef __ZMACHINE_H
#define __ZMACHINE_H

#include <stdio.h>

#include "ztypes.h"
#include "hash.h"
#include "file.h"
#include "display.h"

/*
 * You can #define the following definitions to alter how your version 
 * of Zoom is compiled.
 *
 * DEBUG does produce rather a lot of debugging information (~15Mb
 * from advent.z5, just to open the grate...). However, if you know
 * what you're doing, you may find this useful to fix problems in your 
 * games (or locate problems in Zoom)
 *
 * Undefining SAFE will turn off bounds checking in any operations
 * that use it.
 *
 * GLOBAL_PC will make the program counter be stored in a global
 * variable - this creates a very slight slowdown, but means warnings
 * and errors can give the PC that they occured at
 *
 * CAN_UNDO means that the undo commands are supported
 *
 * SQUEEZEUNDO will cause the undo buffer to be compressed (which is slow)
 */

#undef  DEBUG        /* Lots of debugging crap */
#define SAFE         /* Perform more bounds checking */
#undef  PAGED_MEMORY /* Not implemented, anyway ;-) */
#define GLOBAL_PC    /* Set to make the program counter global */
#define CAN_UNDO     /* Support the undo commands */
#undef  SQUEEZEUNDO  /* Store undo information in a compressed format (slow) */
#undef  TRACKING     /* Enable object tracking options */

/*
 * Versions to support (note that support for version 5 includes
 * support for versions 7 and 8 as well
 */
#define SUPPORT_VERSION_3
#define SUPPORT_VERSION_4
#define SUPPORT_VERSION_5
#undef  SUPPORT_VERSION_6

/* File format */

enum ZHeader_bytes
{
  ZH_version   = 0x00,
  ZH_flags,
  ZH_release   = 0x02,
  ZH_base_high = 0x04,
  ZH_initpc    = 0x06,
  ZH_dict      = 0x08,
  ZH_objs      = 0x0a,
  ZH_globals   = 0x0c,
  ZH_static    = 0x0e,
  ZH_flags2    = 0x10,
  ZH_serial    = 0x12,
  ZH_abbrevs   = 0x18,
  ZH_filelen   = 0x1a,
  ZH_checksum  = 0x1c,
  ZH_intnumber = 0x1e,
  ZH_intvers,
  ZH_lines,
  ZH_columns,
  ZH_width         = 0x22,
  ZH_height        = 0x24,
  ZH_fontwidth     = 0x26, /* height in v6 */
  ZH_fontheight,           /* width in v6 */
  ZH_routines,
  ZH_staticstrings = 0x2a,
  ZH_defback       = 0x2c,
  ZH_deffore,
  ZH_termtable,
  ZH_widthos3      = 0x30,
  ZH_revnumber     = 0x32,
  ZH_alphatable    = 0x34,
  ZH_extntable     = 0x36
};

/* Internal data structures */

typedef struct ZMap
{
  ZDWord  actual_size;
  ZByte*  mapped_pages;
  ZByte** pages;
} ZMap;

struct ZStack;

typedef struct ZArgblock
{
  int n_args;
  ZWord arg[8];
} ZArgblock;

typedef struct ZFrame
{
  /* Return address */
  ZDWord ret;

  ZByte  nlocals;    /* Number of locals */
  ZByte  flags;      /* Arguments supplied */
  ZByte  storevar;   /* Variable to store result in on return */
  ZByte  discard;    /* Nonzero if result should be discarded */
  
  ZWord  frame_size; /* Evaluation size */

  ZWord  local[16];
  ZUWord frame_num;

  void (*v4read)(ZDWord*, struct ZStack*, ZArgblock*);
  void (*v5read)(ZDWord*, struct ZStack*, ZArgblock*, int);
  ZArgblock readblock;
  int       readstore;
  
  struct ZFrame* last_frame;
} ZFrame;

typedef struct ZStack
{
  ZDWord  stack_total;
  ZDWord  stack_size;
  ZWord*  stack;
  ZWord*  stack_top;
  ZFrame* current_frame;
} ZStack;

typedef struct ZMachine
{
  ZUWord   static_ceiling;
  ZUWord   dynamic_ceiling;
  ZDWord   high_start;
  ZDWord   story_length;

  ZByte*   header;
  ZByte*   dynamic_memory;

  ZFile*   file;

  ZByte* undo;
  ZDWord undo_len;

#ifdef PAGED_MEMORY
  ZMap     memory;
#else
  ZByte*   memory;
#endif

  ZByte*   globals;
  ZByte*   objects;

  ZStack   stack;

  char*    abbrev[96];

  ZByte*   dict;

  hash     cached_dictionaries;

  enum {
    packed_v3,
    packed_v4,
    packed_v6,
    packed_v8
  } packtype;

  ZDWord routine_offset;
  ZDWord string_offset;

  int display_active;
  ZDisplay* dinfo;

  int graphical;

  /* Output streams */
  int    screen_on;
  int    transcript_on;
  int    transcript_commands;
  FILE*  transcript_file;

  int    memory_on;
  ZUWord memory_pos[16];
  
  int    buffering;

  /* Input streams */
  int   script_on;
  FILE* script_file;

#ifdef GLOBAL_PC
  ZDWord pc;
#endif

  /* Commandline options */
  int warning_level;

#ifdef TRACKING
  int track_objects;
  int track_properties;
  int track_attributes;
#endif
} ZMachine;

typedef struct ZDictionary
{
  char sep[256];
  hash words;
} ZDictionary;

extern void zmachine_load_story  (char* filename, ZMachine* machine);
extern void zmachine_setup_header(void);
extern void zmachine_fatal       (char* format, ...);
extern void zmachine_warning     (char* format, ...);

extern ZWord   pop         (ZStack*);
extern void    push        (ZStack*, const ZWord);
extern ZFrame* call_routine(ZDWord* pc, ZStack* stack, ZDWord start);
     
/* Utility macros */

#ifdef DEBUG
extern ZWord debug_print_var(ZWord val, int var);
#define DebugVar(x, y) debug_print_var(x, y)
#else
#define DebugVar(x, y) x
#endif

#define GetVar(x)  DebugVar((x==0?pop(stack):(((unsigned char) x)<16?stack->current_frame->local[x]:(machine.globals[((x)<<1)-32]<<8)|machine.globals[((x)<<1)-31])), x)
#define GetCode(x) machine.memory[(x)]
#define Word(x)    ((machine.memory[(x)]<<8)|machine.memory[(x)+1])
#define Byte(x)    (machine.memory[(x)])
#define GetWord(m, x) ((m[x]<<8)|(m[x+1]))
#define Address(x) (machine.memory + (x))

extern ZMachine machine;

#endif
