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
 * Implementations of the operation functions
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <ctype.h>

#include "../config.h"

#include "zmachine.h"
#include "op.h"
#include "zscii.h"
#include "tokenise.h"
#include "stream.h"
#include "state.h"
#include "pix.h"

#include "display.h"

#if !defined(INLINE_OPS) || (defined(INLINE_OPS) && defined(INLINING))

/*
 * A note on our use of windows:
 * 0 is the 'main' bottom window in all versions
 * 1 is the status window, but only for version 3
 * 2 is the upper window for versions 4 & 5
 * 3,4,5, etc are the windows for version 6 (2 is also window 1)
 */

/***                           ----// 888 \\----                           ***/

/* Utilty functions */

#define dobranch \
      switch (branch) \
	{ \
	case 0: \
	  zcode_op_rfalse(pc, stack); \
	  return; \
	case 1: \
	  zcode_op_rtrue(pc, stack); \
	  return; \
	  \
	default: \
	  *pc += branch-2; \
	}

inline void push(ZStack* stack, const ZWord word)
{
  *(stack->stack_top++) = word;
  stack->stack_size--;

  if (stack->current_frame != NULL)
    stack->current_frame->frame_size++;
  
  if (stack->stack_size <= 0)
    {
      stack->stack_total += 2048;
      if (!(stack->stack = realloc(stack->stack,
				   stack->stack_total*sizeof(ZWord))))
	{
	  zmachine_fatal("Stack overflow");
	}
      stack->stack_size = 2048;
    }

#ifdef DEBUG
  if (stack->current_frame)
    printf("Stack: push - size now %i, frame usage %i (pushed #%x)\n",
	   stack->stack_size, stack->current_frame->frame_size,
	   stack->stack_top[-1]);
#endif
}

inline ZWord pop(ZStack* stack)
{
  stack->stack_size++;

  if (stack->current_frame)
    {
      stack->current_frame->frame_size--;
#ifdef SAFE
      if (stack->current_frame->frame_size < 0)
	zmachine_fatal("Stack underflow");
#endif
    }

#ifdef SAFE
  if (stack->stack_top == stack->stack)
    zmachine_fatal("Stack underflow");
#endif
  
#ifdef DEBUG
  if (stack->current_frame)
    printf("Stack: pop - size now %i, frame usage %i (value #%x)\n",
	   stack->stack_size, stack->current_frame->frame_size,
	   stack->stack_top[-1]);
#endif
  
  return *(--stack->stack_top);
}

inline ZFrame* call_routine(ZDWord* pc, ZStack* stack, ZDWord start)
{
  ZFrame* newframe;
  int n_locals;
  int x;

  newframe = malloc(sizeof(ZFrame));
  
  newframe->ret          = *pc;
  newframe->flags        = 0;
  newframe->storevar     = 0;
  newframe->discard      = 0;
  newframe->frame_size   = 0;
  if (stack->current_frame != NULL)
    newframe->frame_num  = stack->current_frame->frame_num+1;
  else
    newframe->frame_num  = 1;
  newframe->last_frame   = stack->current_frame;
  newframe->v4read       = NULL;
  newframe->v5read       = NULL;
  stack->current_frame   = newframe;
  
  n_locals = GetCode(start);
  newframe->nlocals = n_locals;

  if (machine.memory[0] <= 4)
    {
      for (x=0; x<n_locals; x++)
	{
	  newframe->local[x+1] = (GetCode(start+(x*2)+1)<<8)|
	    GetCode(start+(x*2)+2);
	}
  
      *pc = start+n_locals*2+1;
    }
  else
    {
      if (n_locals > 15)
	{
	  zmachine_warning("Routine with %i locals", n_locals);
	  n_locals = 15;
	}
      for (x=0; x<n_locals; x++)
	{
	  newframe->local[x+1] = 0;
	}

      *pc = start+1;
    }

  return newframe;
}

inline void store(ZStack* stack, int var, ZWord value)
{
#ifdef DEBUG
  printf("Storing %i in Variable #%x\n", value, var);
#endif
  if (var == 0)
    {
      push(stack, value);
    }
  else if (var < 16)
    {
      stack->current_frame->local[var] = value;
    }
  else
    {
      var-=16;
      machine.globals[var<<1]     = value>>8;
      machine.globals[(var<<1)+1] = value;
    }
}

inline void restart_machine(void)
{
  machine.screen_on = 1;
  machine.transcript_on = 0;
  if (machine.transcript_file)
    {
      fclose(machine.transcript_file);
      machine.transcript_file = NULL;
    }
  machine.memory_on = 0;

  display_set_window(0);
  display_join(0,2);

  zmachine_setup_header();
}

#define Obj3(x) (machine.objects + 62+(((x)-1)*9))
#define parent_3  4
#define sibling_3 5
#define child_3   6

struct prop
{
  ZByte* prop;
  int    size;
  int    pad;
  int    isdefault;
};

static inline struct prop* get_object_prop_3(ZUWord object, ZWord property)
{
  ZByte* obj;
  ZByte* prop;
  ZByte  size;
  
  static struct prop info;

  obj = Obj3(object);
  prop = machine.memory + ((obj[7]<<8)|obj[8]);

  prop = prop + (prop[0]*2) + 1;

  while ((size = prop[0]) != 0)
    {
      if ((size&0x1f) == property)
	{
	  info.size = (size>>5) + 1;
	  info.prop = prop + 1;
	  info.isdefault = 0;
	  return &info;
	}
      
      prop = prop + (size>>5) + 2;
    }

  info.size = 2;
  info.prop = machine.objects + 2*property-2;
  info.isdefault = 1;

  return &info;
}

#define UnpackR(x) (machine.packtype==packed_v4?4*((ZUWord)x):(machine.packtype==packed_v8?8*((ZUWord)x):4*((ZUWord)x)+machine.routine_offset))
#define UnpackS(x) (machine.packtype==packed_v4?4*((ZUWord)x):(machine.packtype==packed_v8?8*((ZUWord)x):4*((ZUWord)x)+machine.string_offset))
#define Obj4(x) (machine.objects + 126 + (((x)-1)*14))
#define parent_4  6
#define sibling_4 8
#define child_4   10
#define GetParent4(x) (((x)[parent_4]<<8)|(x)[parent_4+1])
#define GetSibling4(x) (((x)[sibling_4]<<8)|(x)[sibling_4+1])
#define GetChild4(x) (((x)[child_4]<<8)|(x)[child_4+1])
#define GetPropAddr4(x) (((x)[12]<<8)|(x)[13])

struct propinfo
{
  int datasize;
  int number;
  int header;
};

static inline struct propinfo* get_object_propinfo_4(ZByte* prop)
{
  static struct propinfo pinfo;
  
  if (prop[0]&0x80)
    {
      pinfo.number   = prop[0]&0x3f;
      pinfo.datasize = prop[1]&0x3f;
      pinfo.header = 2;

      if (pinfo.datasize == 0)
	pinfo.datasize = 64;
    }
  else
    {
      pinfo.number   = prop[0]&0x3f;
      pinfo.datasize = (prop[0]&0x40)?2:1;
      pinfo.header = 1;
    }

  return &pinfo;
}

static inline struct prop* get_object_prop_4(ZUWord object, ZWord property)
{
  ZByte* obj;
  ZByte* prop;
  int    pnum;
  
  static struct prop info;

  if (object != 0)
    {
      obj = Obj4(object);
      prop = Address((ZUWord)GetPropAddr4(obj));
      
      prop += (prop[0]*2) + 1;
      pnum = 128;
      
      while (pnum != 0)
	{
	  int len, pad;
	  
	  if (prop[0]&0x80)
	    {
	      pnum = prop[0]&0x3f;
	      len  = prop[1]&0x3f;
	      pad  = 2;
	      
	      if (len == 0)
		len = 64;
	    }
	  else
	    {
	      pnum = prop[0]&0x3f;
	      len  = (prop[0]&0x40)?2:1;
	      pad  = 1;
	    }
	  
#ifdef DEBUG
	  printf("(Property %i, (looking for %i) length %i: ", pnum,
		 property, len);
	  {
	    int x;
	    
	    for (x=0; x<=len+pad; x++)
	      printf("$%x ", prop[x]);
	    printf(")\n");
	  }
#endif
	  
	  if (pnum == property)
	    {
	      info.size = len;
	      info.prop = prop + pad;
	      info.isdefault = 0;
	      info.pad = pad;
	      return &info;
	    }
	  
	  prop = prop + len + pad;
	}
    }

  info.size = 2;
  info.prop = machine.objects + 2*property-2;
  info.isdefault = 1;
  info.pad = 0;

  return &info;
}

#ifdef TRACKING
static inline char* tracking_object(ZUWord arg)
{
  ZByte* obj;
  ZByte* prop;
  int len;

  if (Byte(0) <= 3)
    {
      obj = Obj3(arg);
      prop = machine.memory + ((obj[7]<<8)|obj[8]) + 1;
      return zscii_to_ascii(prop, &len);
    }
  else
    {
      obj = Obj4(arg);
      prop = Address((ZUWord)GetPropAddr4(obj)+1);
      return zscii_to_ascii(prop, &len);
    }
}

#include <stdarg.h>
static void tracking_print(char* format, ...)
{
  va_list* ap;
  char str[512];

  va_start(ap, format);
  vsprintf(str, format, ap);
  va_end(ap);

  fprintf(stderr, "TRACKING: %s\n", str);
}
#endif

static inline void draw_statusbar_123(ZStack* stack);

/***                           ----// 888 \\----                           ***/

/* 2OPs */

inline void zcode_op_jen(ZDWord* pc,
			 ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 ZDWord branch)
{
  if (arg1 != arg2)
    {
      dobranch;
    }
}

inline void zcode_op_je(ZDWord* pc,
			ZStack* stack,
			int omit,
			ZWord arg1,
			ZWord arg2,
			ZDWord branch)
{
  if (arg1 == arg2)
    {
      dobranch;
    }
}
inline void zcode_op_jenm(ZDWord*    pc,
			  ZStack*    stack,
			  ZArgblock* args,
			  ZDWord     branch)
{
  int x;
  int eq;

  eq = 1;
  
  for (x=1; x<args->n_args; x++)
    {
      if (args->arg[0] == args->arg[x])
	{
	  eq = 0;
	}
    }

  if (eq)
    {
      dobranch;
    }
}

inline void zcode_op_jem(ZDWord*    pc,
			 ZStack*    stack,
			 ZArgblock* args,
			 ZDWord     branch)
{
  int x;
  
  for (x=1; x<args->n_args; x++)
    {
      if (args->arg[0] == args->arg[x])
	{
	  dobranch;
	  return;
	}
    }
}

inline void zcode_op_jln(ZDWord* pc,
			 ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 ZDWord branch)
{
  if (arg1 >= arg2)
    {
      dobranch;
    }
}

inline void zcode_op_jl(ZDWord* pc,
			ZStack* stack,
			int omit,
			ZWord arg1,
			ZWord arg2,
			ZDWord branch)
{
  if (arg1 < arg2)
    {
      dobranch;
    }
}

inline void zcode_op_jgn(ZDWord* pc,
			 ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 ZDWord branch)
{
  if (arg1 <= arg2)
    {
      dobranch;
    }
}

inline void zcode_op_jg(ZDWord* pc,
			ZStack* stack,
			int omit,
			ZWord arg1,
			ZWord arg2,
			ZDWord branch)
{
  if (arg1 > arg2)
    {
      dobranch;
    }
}

inline void zcode_op_dec_chkn(ZDWord* pc,
			      ZStack* stack,
			      int omit,
			      ZWord arg1,
			      ZWord arg2,
			      ZDWord branch)
{
  ZWord var;

  var = GetVar(arg1);
  var--;
  store(stack, arg1, var);

  if (var >= arg2)
    {
      dobranch;
    }
}

inline void zcode_op_dec_chk(ZDWord* pc,
			     ZStack* stack,
			     int omit,
			     ZWord arg1,
			     ZWord arg2,
			     ZDWord branch)
{
  ZWord var;

  var = GetVar(arg1);
  var--;
  store(stack, arg1, var);

  if (var < arg2)
    {
      dobranch;
    }
}

inline void zcode_op_inc_chkn(ZDWord* pc,
			      ZStack* stack,
			      int omit,
			      ZWord arg1,
			      ZWord arg2,
			      ZDWord branch)
{
  ZWord var;

  var = GetVar(arg1);
  var++;
  store(stack, arg1, var);

  if (var <= arg2)
    {
      dobranch;
    }
}

inline void zcode_op_inc_chk(ZDWord* pc,
			     ZStack* stack,
			     int omit,
			     ZWord arg1,
			     ZWord arg2,
			     ZDWord branch)
{
  ZWord var;

  var = GetVar(arg1);
  var++;
  store(stack, arg1, var);

  if (var > arg2)
    {
      dobranch;
    }
}

inline void zcode_op_jin_123(ZDWord* pc,
			     ZStack* stack,
			     int omit,
			     ZUWord arg1,
			     ZUWord arg2,
			     ZDWord branch)
{
  ZByte* obj;

  if (arg1>255 || arg1 == 0)
    zmachine_fatal("Object out of range");
  
  obj = Obj3(arg1);
  if (obj[parent_3] == arg2)
    {
      dobranch;
    }
}

inline void zcode_op_jinn_123(ZDWord* pc,
			      ZStack* stack,
			      int omit,
			      ZUWord arg1,
			      ZUWord arg2,
			      ZDWord branch)
{
  ZByte* obj;

  if (arg1>255 || arg1 == 0)
    zmachine_fatal("Object out of range");

  obj = Obj3(arg1);
  if (obj[parent_3] != arg2)
    {
      dobranch;
    }
}

inline void zcode_op_jin_45678 (ZDWord* pc,
				ZStack* stack,
				int store,
				ZUWord arg1,
				ZUWord arg2,
				ZDWord branch)
{
  ZByte* obj;

  obj = Obj4(arg1);
  if (GetParent4(obj) == arg2)
    {
      dobranch;
    }
}

inline void zcode_op_jinn_45678(ZDWord* pc,
				ZStack* stack,
				int store,
				ZUWord arg1,
				ZUWord arg2,
				ZDWord branch)
{
  ZByte* obj;

  obj = Obj4(arg1);
  if (GetParent4(obj) != arg2)
    {
      dobranch;
    }  
}

inline void zcode_op_testn(ZDWord* pc,
			   ZStack* stack,
			   int omit,
			   ZUWord bitmap,
			   ZUWord flags,
			   ZDWord branch)
{
  if ((bitmap&flags) != flags)
    {
      dobranch;
    }
}

inline void zcode_op_test(ZDWord* pc,
			  ZStack* stack,
			  int omit,
			  ZUWord bitmap,
			  ZUWord flags,
			  ZDWord branch)
{
  if ((bitmap&flags) == flags)
    {
      dobranch;
    }
}

inline void zcode_op_test_attr_123(ZDWord* pc,
				   ZStack* stack,
				   int omit,
				   ZUWord object,
				   ZUWord attr,
				   ZDWord branch)
{
  ZByte* obj;
  int byte, bit;
  
  if (object>255 || object == 0)
    zmachine_fatal("Object out of range");
  if (attr>31)
    zmachine_fatal("Attribute out of range");

  byte = attr>>3;
  bit  = attr&7;

  obj = Obj3(object);

#ifdef TRACKING
  if (machine.track_attributes)
    tracking_print("Testing attribute %i of object \"%s\" (%s)",
		   attr, tracking_object(object),
		   (obj[byte]&(0x80>>bit))?"Set":"Unset");
#endif

  if (obj[byte]&(0x80>>bit))
    {
      dobranch;
    }
}

inline void zcode_op_test_attrn_123(ZDWord* pc,
				    ZStack* stack,
				    int omit,
				    ZUWord object,
				    ZUWord attr,
				    ZDWord branch)
{
  ZByte* obj;
  int byte, bit;

  if (object>255 || object == 0)
    zmachine_fatal("Object out of range");
  if (attr>31)
    zmachine_fatal("Attribute out of range");

  byte = attr>>3;
  bit  = attr&7;

  obj = Obj3(object);

#ifdef TRACKING
  if (machine.track_attributes)
    tracking_print("Testing attribute %i of object \"%s\" (%s)",
		   attr, tracking_object(object),
		   (obj[byte]&(0x80>>bit))?"Set":"Unset");
#endif

  if (!(obj[byte]&(0x80>>bit)))
    {
      dobranch;
    }
}

inline void zcode_op_test_attr_45678(ZDWord* pc, ZStack* stack,
				     int omit,
				     ZUWord arg1,
				     ZUWord arg2,
				     ZDWord branch)
{
  ZByte* obj;
  int byte, bit;

  if (arg1 == 0)
    zmachine_fatal("Object 0 has no attributes");
  if (arg2 == 48)
    {
      zmachine_warning("Attempt to test attribute 48");
      return;
    }
  if (arg2>47)
    zmachine_fatal("Attribute out of range");
  
  byte = arg2>>3;
  bit  = arg2&7;

  obj = Obj4(arg1);

#ifdef TRACKING
  if (machine.track_attributes)
    tracking_print("Testing attribute %i of object \"%s\" (%s)",
		   arg2, tracking_object(arg1),
		   (obj[byte]&(0x80>>bit))?"Set":"Unset");
#endif

  if ((obj[byte]&(0x80>>bit)))
    {
      dobranch;
    }
}

inline void zcode_op_test_attrn_45678(ZDWord* pc,
				      ZStack* stack,
				      int omit,
				      ZUWord arg1,
				      ZUWord arg2,
				      ZDWord branch)
{
  ZByte* obj;
  int byte, bit;

  if (arg1 == 0)
    zmachine_fatal("Object 0 has no attributes");
  if (arg2 == 48)
    {
      zmachine_warning("Attempt to test attribute 48");
      return;
    }
  if (arg2>47)
    zmachine_fatal("Attribute out of range");
  
  byte = arg2>>3;
  bit  = arg2&7;

  obj = Obj4(arg1);

#ifdef TRACKING
  if (machine.track_attributes)
    tracking_print("Testing attribute %i of object \"%s\" (%s)",
		   arg2, tracking_object(arg1),
		   (obj[byte]&(0x80>>bit))?"Set":"Unset");
#endif

  if (!(obj[byte]&(0x80>>bit)))
    {
      dobranch;
    }
}

inline void zcode_op_set_attr_123(ZStack* stack,
				  int omit,
				  ZUWord arg1,
				  ZUWord arg2)
{
  ZByte* obj;
  int byte, bit;

  if (arg1>255 || arg1 == 0)
    zmachine_fatal("Object out of range");
  if (arg2>31)
    zmachine_fatal("Attribute out of range");

#ifdef TRACKING
  if (machine.track_attributes)
    tracking_print("Setting attribute %i of object \"%s\"",
		   arg2, tracking_object(arg1));
#endif
  
  byte = arg2>>3;
  bit  = arg2&7;

  obj = Obj3(arg1);
  obj[byte] |= 0x80>>bit;
}

inline void zcode_op_clear_attr_123(ZStack* stack,
				    int omit,
				    ZUWord arg1,
				    ZUWord arg2)
{
  ZByte* obj;
  int byte, bit;

  if (arg1>255 || arg1 == 0)
    zmachine_fatal("Object out of range");
  if (arg2>31)
    zmachine_fatal("Attribute out of range");
  
  byte = arg2>>3;
  bit  = arg2&7;

#ifdef TRACKING
  if (machine.track_attributes)
    tracking_print("Clearing attribute %i of object \"%s\"",
		   arg2, tracking_object(arg1));
#endif

  obj = Obj3(arg1);
  obj[byte] &= ~(0x80>>bit);
}

inline void zcode_op_set_attr_45678(ZStack* stack,
				    int omit,
				    ZUWord arg1,
				    ZUWord arg2)
{
  ZByte* obj;
  int byte, bit;

  if (arg1 == 0)
    zmachine_fatal("Object 0 cannot be altered");
  if (arg2>47)
    zmachine_fatal("Attribute out of range");

#ifdef DEBUG
  printf("Setting attribute %x of object #%x\n", arg2, arg1);
#endif

#ifdef TRACKING
  if (machine.track_attributes)
    tracking_print("Setting attribute %i of object \"%s\"",
		   arg2, tracking_object(arg1));
#endif
  
  byte = arg2>>3;
  bit  = arg2&7;

  obj = Obj4(arg1);
  obj[byte] |= (0x80>>bit);
}

inline void zcode_op_clear_attr_45678(ZStack* stack,
				      int omit,
				      ZUWord arg1,
				      ZUWord arg2)
{
  ZByte* obj;
  int byte, bit;

  if (arg1 == 0)
    zmachine_fatal("Object 0 cannot be altered");
  if (arg2>47)
    zmachine_fatal("Attribute out of range");

#ifdef DEBUG
  printf("Clearing attribute %x of object #%x\n", arg2, arg1);
#endif
 
#ifdef TRACKING
  if (machine.track_attributes)
    tracking_print("Clearing attribute %i of object \"%s\"",
		   arg2, tracking_object(arg1));
#endif
 
  byte = arg2>>3;
  bit  = arg2&7;

  obj = Obj4(arg1);
  obj[byte] &= ~(0x80>>bit);
}

inline void zcode_op_insert_obj_123(ZStack* stack,
				    int omit,
				    ZUWord obj,
				    ZUWord dest)
{
  ZByte* src_obj;
  ZByte* dest_obj;
  ZByte* tmp;
  
  if (obj>255 || obj == 0)
    zmachine_fatal("Object out of range");  
  if (dest>255)
    zmachine_fatal("Object out of range");

  /* Get the address of the object */
  src_obj = Obj3(obj);

  if (src_obj[parent_3] != 0)
    {
      /* Get the address of its parent */
      tmp = Obj3(src_obj[parent_3]);
      
      /*
       * If the object is a direct child of its parent, set the new child
       * to the object's sibling
       */
      if (tmp[child_3] == obj)
	{
	  tmp[child_3] = src_obj[sibling_3];
	}
      else
	{
	  /* Find the object which is a sibling with this object */
	  tmp = Obj3(tmp[child_3]);
	  
	  while (tmp[sibling_3] != obj && tmp[sibling_3] != 0)
	    {
	      tmp = Obj3(tmp[sibling_3]);
	    }
	  
	  if (tmp[sibling_3] == 0)
	    zmachine_fatal("Corrupt object tree (object is not a child of its parent)");
	  
	  /* Set its sibling to the sibling of the object */
	  tmp[sibling_3] = src_obj[sibling_3];
	}
    }
      
  if (dest != 0)
    {
      /* Set the new parent's child to be this object */
      dest_obj = Obj3(dest);
      src_obj[sibling_3] = dest_obj[child_3];
      dest_obj[child_3]  = obj;
    }
  else
    src_obj[sibling_3] = 0;
  
  src_obj[parent_3] = dest;
}

inline void zcode_op_insert_obj_45678(ZStack* stack,
				      int omit,
				      ZUWord obj,
				      ZUWord dest)
{
  ZByte* src_obj;
  ZByte* dest_obj;
  ZByte* tmp;

#ifdef DEBUG
  printf("Inserting object %i into %i\n", obj, dest);
#endif
  
  if (obj == 0)
    zmachine_fatal("Object 0 cannot be inserted");

  src_obj = Obj4(obj);
  
  if (GetParent4(src_obj) != 0)
    {
      ZUWord sibling;
      
      /* Get the address of the old parent */
      tmp = Obj4(GetParent4(src_obj));

      if (GetChild4(tmp) == obj)
	{
	  sibling = GetSibling4(src_obj);
	  /*
	   * Object is a direct child, so we make the new child this
	   * object's sibling
	   */
	  tmp[child_4] = sibling>>8;
	  tmp[child_4+1] = sibling;
	}
      else
	{
	  ZUWord our_sibling;
	  
	  /* Find the object which is a sibling with this object */
	  tmp = Obj4(GetChild4(tmp));

	  sibling = GetSibling4(tmp);
	  while (sibling != obj && sibling != 0)
	    {
	      tmp = Obj4(sibling);
	      sibling = GetSibling4(tmp);
	    }

	  if (sibling == 0)
	    zmachine_fatal("Corrupt object tree (object is not a child of its parent)");

	  /* Set its sibling to our sibling */
	  our_sibling = GetSibling4(src_obj);
	  tmp[sibling_4] = our_sibling>>8;
	  tmp[sibling_4+1] = our_sibling;
	}
    }

  if (dest != 0)
    {
      ZUWord kid;
      
      /* Set the new parent's child to be this object */
      dest_obj = Obj4(dest);
      kid = GetChild4(dest_obj);
      src_obj[sibling_4] = kid>>8;
      src_obj[sibling_4+1] = kid;
      dest_obj[child_4] = obj>>8;
      dest_obj[child_4+1] = obj;
    }
  else
    {
      src_obj[sibling_4] = 0;
      src_obj[sibling_4+1] = 0;
    }

  src_obj[parent_4] = dest>>8;
  src_obj[parent_4+1] = dest;
}

inline void zcode_op_get_prop_123(ZStack* stack,
				  int omit,
				  ZUWord obj,
				  ZUWord prop,
				  int st)
{
  struct prop* p;
  
  if (obj>255 || obj == 0)
    zmachine_fatal("Object out of range");
  if (prop>31)
    zmachine_fatal("Property out of range");
  
  p = get_object_prop_3(obj, prop);

  switch (p->size)
    {
    case 1:
      store(stack, st, p->prop[0]);
      break;
      
    case 2:
      store(stack, st, (p->prop[0]<<8)|p->prop[1]);
      break;
      
    default:
      zmachine_fatal("Size %i is invalid for get_prop\n", p->size);
    }
}

inline void zcode_op_get_prop_45678(ZStack* stack,
				    int omit,
				    ZUWord obj,
				    ZUWord prop,
				    int st)
{
  struct prop* p;

  if (obj == 0)
    zmachine_warning("Object 0 has no properties");
  if (prop>63)
    zmachine_fatal("Property %i out of range", prop);

#ifdef DEBUG
  printf("Get_prop: object %i prop %i\n", obj, prop);
#endif

  p = get_object_prop_4(obj, prop);

  switch (p->size)
    {
    case 1:
      store(stack, st, p->prop[0]);
       break;

      /*
       * Hmm, this is against spec, but some Inform games
       * (Christminster?) seem to use get_prop on properties with
       * lengths > 2. So we'll let 'em off with a warning
       */
    default:
      zmachine_warning("get_prop used on a property with length %i",
		       p->size);
      store(stack, st, (p->prop[-1]<<8)|p->prop[0]);
      break;
      
    case 2:
      store(stack, st, (p->prop[0]<<8)|p->prop[1]);
      break;
      
      /* default:
	 zmachine_fatal("Size %i is invalid for get_prop\n", p->size); */
    }
}

inline void zcode_op_get_prop_addr_123(ZStack* stack,
				       int omit,
				       ZUWord obj,
				       ZUWord prop,
				       int st)
{
  ZByte* obj_adr;
  ZUWord prop_adr;
  ZByte  size;

  if (obj == 0 || obj>255)
    zmachine_fatal("Object out of range");
  if (prop > 31)
    zmachine_fatal("Property out of range");
  
  obj_adr = Obj3(obj);

  prop_adr  = (obj_adr[7]<<8)|obj_adr[8];
  prop_adr += Byte(prop_adr)*2 + 1;

  while ((size = Byte(prop_adr)) != 0)
    {
      if ((size&0x1f) == prop)
	{
	  store(stack, st, prop_adr + 1);
	  return;
	}

      prop_adr += (size>>5) + 2;
    }

  store(stack, st, 0);
}

inline void zcode_op_get_prop_addr_45678(ZStack* stack,
					 int omit,
					 ZUWord obj,
					 ZUWord prop,
					 int st)
{
  ZByte* obj_adr;
  ZUWord prop_adr;
  struct propinfo* pinfo;

  if (obj == 0)
    {
      zmachine_warning("Object 0 has no properties");
      store(stack, st, 0);
    }
  if (prop > 63)
    zmachine_fatal("Property %i out of range", prop);
  
  obj_adr = Obj4(obj);
  
  prop_adr = GetPropAddr4(obj_adr);
  prop_adr += (Byte(prop_adr)*2)+1;
  
  do
    {
      pinfo = get_object_propinfo_4(Address(prop_adr));

      if (pinfo->number == prop)
	{
	  store(stack, st, (ZUWord)(prop_adr+pinfo->header));
	  return;
	}
      
      prop_adr += pinfo->datasize + pinfo->header;
    }
  while (pinfo->number != 0);

  store(stack, st, 0);
}

inline void zcode_op_get_next_prop_123(ZStack* stack,
				       int omit,
				       ZUWord obj,
				       ZUWord prop,
				       int st)
{
  ZByte* obj_adr;
  ZWord  prop_adr;
  ZByte  size;
  int state;

  obj_adr = Obj3(obj);

  prop_adr  = (obj_adr[7]<<8)|obj_adr[8];
  prop_adr += Byte(prop_adr)*2 + 1;

  if (prop == 0)
    {
      store(stack, st, Byte(prop_adr)&0x1f);
      return;
    }
  
  state = 0;
  while ((size = Byte(prop_adr)) != 0)
    {
      if (state)
	{
	  store(stack, st, size&0x1f);
	  return;
	}
      if ((size&0x1f) == prop)
	{
	  state = 1;
	}

      prop_adr += (size>>5) + 2;
    }

  store(stack, st, 0);  
}

inline void zcode_op_get_next_prop_45678(ZStack* stack,
					 int omit,
					 ZUWord obj,
					 ZUWord prop,
					 int st)
{
  struct prop*     property;
  struct propinfo* inf;
  
  if (obj == 0)
    zmachine_fatal("Object 0 has no properties");
  if (prop > 63)
    zmachine_fatal("Property out of range");
  
  if (prop == 0)
    {
      ZByte* obj_adr;
      ZUWord prop_adr;
 
      obj_adr = Obj4(obj);

      prop_adr = GetPropAddr4(obj_adr);
      prop_adr += (Byte(prop_adr)*2)+1;

      inf = get_object_propinfo_4(Address(prop_adr));
      store(stack, st, inf->number);
      return;
    }
  
  property = get_object_prop_4(obj, prop);
  
  if (property->isdefault)
    zmachine_fatal("Can't get next property of a default");

  inf = get_object_propinfo_4(property->prop - property->pad);
  if (inf->number != 0)
    {
      ZByte *next_prop;

      next_prop = property->prop + inf->datasize;
      inf = get_object_propinfo_4(next_prop);

      store(stack, st, inf->number);
    }
  else /* Huh? We retrieved property 0? */
    zmachine_fatal("Programmer is a spoon");
}

inline void zcode_op_store(ZStack* stack,
			   int omit,
			   ZWord arg1,
			   ZWord arg2)
{
  store(stack, arg1, arg2);
}

inline void zcode_op_loadw(ZStack* stack,
			   int omit,
			   ZUWord arg1,
			   ZUWord arg2,
			   int st)
{
#ifdef DEBUG
  printf("Loading word at #%x\n", arg1+(arg2*2));
#endif
  store(stack, st, Word(arg1+(arg2*2)));
}

inline void zcode_op_loadb(ZStack* stack,
			   int omit,
			   ZUWord arg1,
			   ZUWord arg2,
			   int st)
{
#ifdef DEBUG
  printf("Loading byte at #%x\n", arg1+arg2);
#endif
  store(stack, st, Byte(arg1+arg2));
}

/***                           ----// 888 \\----                           ***/

inline void zcode_op_or (ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 int st)
{
  store(stack, st, arg1|arg2);
}

inline void zcode_op_and(ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 int st)
{
  store(stack, st, arg1&arg2);
}

inline void zcode_op_add(ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 int st)
{
  store(stack, st, arg1+arg2);
}

inline void zcode_op_sub(ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 int st)
{
  store(stack, st, arg1-arg2);
}

inline void zcode_op_mul(ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 int st)
{
  store(stack, st, arg1*arg2);
}

inline void zcode_op_div(ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 int st)
{
  if (arg2 == 0)
    zmachine_fatal("Division by 0");
  store(stack, st, arg1/arg2);
}
     
inline void zcode_op_mod(ZStack* stack,
			 int omit,
			 ZWord arg1,
			 ZWord arg2,
			 int st)
{
  if (arg2 == 0)
    zmachine_fatal("Modulo by 0");
  store(stack, st, arg1%arg2);
}

/***                           ----// 888 \\----                           ***/

inline void zcode_op_call_2s_45678(ZDWord* pc,
				   ZStack* stack,
				   int omit,
				   ZWord arg1,
				   ZWord arg2,
				   int st)
{
  ZDWord  new_routine;
  ZFrame* newframe;

  if (arg1 == 0)
    {
      store(stack, st, 0);
      return;
    }
  
  new_routine = UnpackR(arg1);
  newframe = call_routine(pc, stack, new_routine);

  if (omit >= 2)
    {
      newframe->local[1] = arg2;
      newframe->flags |= 1;
    }
  newframe->storevar = st;
}

inline void zcode_op_call_2n_5678(ZDWord* pc,
				  ZStack* stack,
				  int omit,
				  ZWord arg1,
				  ZWord arg2)
{
  ZDWord  new_routine;
  ZFrame* newframe;

  if (arg1 == 0)
    {
      return;
    }
  
  new_routine = UnpackR(arg1);
  newframe = call_routine(pc, stack, new_routine);

  if (omit >= 2)
    {
      newframe->local[1] = arg2;
      newframe->flags |= 1;
    }
  newframe->discard  = 1;
}

/* Convert colour to internal format */
inline static int convert_colour(int col)
{
  switch (col)
    {
    case 2:
      return 0;
    case 3:
      return 1;
    case 4:
      return 2;
    case 5:
      return 3;
    case 6:
      return 4;
    case 7:
      return 5;
    case 8:
      return 6;
    case 9:
      return 7;
    case 10:
      return 8;
    case 11:
      return 9;
    case 12:
      return 10;
    case 1:
      return -1;
    case 0:
      return -2;

    default:
      zmachine_warning("Colour %i out of range", col);
      return -1;
    }
}

inline void zcode_op_set_colour_578(ZStack* stack,
				    int omit,
				    ZWord arg1,
				    ZWord arg2)
{
#ifdef DEBUG
  printf("Setting colours to %i, %i\n", arg1, arg2);
#endif
  stream_flush_buffer();
  display_set_colour(convert_colour(arg1), convert_colour(arg2));
}

inline void zcode_op_ret(ZDWord* pc,ZStack* stack,ZWord arg);

inline void zcode_op_throw_5678(ZDWord* pc,
				ZStack* stack,
				int omit,
				ZUWord arg1,
				ZUWord arg2)
{
  if (stack->current_frame == NULL)
    zmachine_fatal("Throw attempted after function with catch has returned");
  if (stack->current_frame->frame_num < arg1)
    zmachine_fatal("Throw attempted after function with catch has returned");

  /* Unroll the stack to the appropriate frame */
  while (stack->current_frame->frame_num != arg2)
    {
      ZFrame* oldframe;

      oldframe = stack->current_frame;
      stack->current_frame = oldframe->last_frame;
      stack->stack_size += oldframe->frame_size;
      stack->stack_top  -= oldframe->frame_size;

      free(oldframe);
    }

  /* Do a return */
  zcode_op_ret(pc, stack, arg1);
}

inline void zcode_op_catch_5678(ZStack* stack,
				int st)
{
  if (stack->current_frame == NULL)
    zmachine_fatal("Catch attempted while no frame is current");
  store(stack, st, stack->current_frame->frame_num);
}

/* 1OPs */
inline void zcode_op_jzn(ZDWord* pc,
			 ZStack* stack,
			 ZWord arg,
			 ZDWord branch)
{
  if (arg != 0)
    {
      dobranch;
    }
}

inline void zcode_op_jz(ZDWord* pc,
			ZStack* stack,
			ZWord arg,
			ZDWord branch)
{
  if (arg == 0)
    {
      dobranch;
    }
}

inline void zcode_op_get_siblingn_123(ZDWord* pc,
				      ZStack* stack,
				      ZUWord arg,
				      int st,
				      ZDWord branch)
{
  ZByte* obj;

  obj = Obj3(arg);
  store(stack, st, obj[sibling_3]);
  if (obj[sibling_3] == 0)
    {
      dobranch;
    }
}

inline void zcode_op_get_sibling_123(ZDWord* pc,
				     ZStack* stack,
				     ZUWord arg,
				     int st,
				     ZDWord branch)
{
  ZByte* obj;

  obj = Obj3(arg);
  store(stack, st, obj[sibling_3]);
  if (obj[sibling_3] != 0)
    {
      dobranch;
    }
}

inline void zcode_op_get_childn_123(ZDWord* pc,
				    ZStack* stack,
				    ZUWord arg,
				    int st,
				    ZDWord branch)
{
  ZByte* obj;

  obj = Obj3(arg);
  store(stack, st, obj[child_3]);
  if (obj[child_3] == 0)
    {
      dobranch;
    }
}


inline void zcode_op_get_child_123(ZDWord* pc,
				   ZStack* stack,
				   ZUWord arg,
				   int st,
				   ZDWord branch)
{
  ZByte* obj;

  obj = Obj3(arg);
  store(stack, st, obj[child_3]);
  if (obj[child_3] != 0)
    {
      dobranch;
    }
}

inline void zcode_op_get_parent_123(ZStack* stack,
				    ZUWord arg,
				    int st)
{
  ZByte* obj;

  obj = Obj3(arg);
  store(stack, st, obj[parent_3]);
}

inline void zcode_op_get_prop_len_123(ZStack* stack,
				      ZUWord prop,
				      int st)
{
  store(stack, st, (machine.memory[prop-1]>>5)+1);
}

inline void zcode_op_get_sibling_45678(ZDWord* pc,
				       ZStack* stack,
				       ZUWord obj,
				       int st,
				       ZDWord branch)
{
  ZByte* obj_adr;
  ZUWord sibling;

  if (obj == 0)
    {
      zmachine_warning("Object 0 has no siblings");
      store(stack, st, 0);
      return;
    }
  
  obj_adr = Obj4(obj);
  sibling = GetSibling4(obj_adr);

  store(stack, st, sibling);

  if (sibling != 0)
    {
      dobranch;
    }
}


inline void zcode_op_get_siblingn_45678(ZDWord* pc,
					ZStack* stack,
					ZUWord obj,
					int st,
					ZDWord branch)
{
  ZByte* obj_adr;
  ZUWord sibling;

  if (obj == 0)
    {
      store(stack, st, 0);
      zmachine_warning("Object 0 has no sibling");
      return;
    }
  
  obj_adr = Obj4(obj);
  sibling = GetSibling4(obj_adr);
  store(stack, st, sibling);

  if (sibling == 0)
    {
      dobranch;
    }
}

inline void zcode_op_get_child_45678(ZDWord* pc,
				     ZStack* stack,
				     ZUWord obj,
				     int st,
				     ZDWord branch)
{
  ZByte* obj_adr;
  ZUWord child;

  if (obj == 0)
    {
      store(stack, st, 0);
      zmachine_warning("Object 0 has no child");
      return;
    }
  
  obj_adr = Obj4(obj);
  child = GetChild4(obj_adr);
  store(stack, st, child);

  if (child != 0)
    {
      dobranch;
    }
}

inline void zcode_op_get_childn_45678(ZDWord* pc,
				      ZStack* stack,
				      ZUWord obj,
				      int st,
				      ZDWord branch)
{
  ZByte* obj_adr;
  ZUWord child;

  if (obj == 0)
    {
      store(stack, st, 0);
      zmachine_warning("Object 0 has no child");
      return;
    }
  
  obj_adr = Obj4(obj);
  child = GetChild4(obj_adr);
  store(stack, st, child);

  if (child == 0)
    {
      dobranch;
    }
}

inline void zcode_op_get_parent_45678(ZStack* stack,
				      ZUWord obj,
				      int st)
{
  ZByte* obj_adr;

  if (obj == 0)
    {
      store(stack, st, 0);
      zmachine_warning("Object 0 has no parent");
      return;
    }
  
  obj_adr = Obj4(obj);
  store(stack, st, GetParent4(obj_adr));
}

inline void zcode_op_get_prop_len_45678(ZStack* stack,
					ZUWord prop,
					int st)
{
  ZByte* p;
  struct propinfo* inf;

  p = machine.memory + prop;
  if (p[-1]&0x80)
    p -= 2;
  else
    p -= 1;

  inf = get_object_propinfo_4(p);

  store(stack, st, inf->datasize);
}

inline void zcode_op_inc(ZStack* stack, ZWord arg)
{
  ZWord var;

#ifdef DEBUG
  printf("Inc: increasing variable %i by 1\n", arg);
#endif
  
  var = GetVar(arg);
  var++;
  store(stack, arg, var);
}

inline void zcode_op_dec(ZStack* stack, ZWord arg)
{
  ZWord var;

#ifdef DEBUG
  printf("Dec: decreasing variable %i by 1\n", arg);
#endif
  
  var = GetVar(arg);
  var--;
  store(stack, arg, var);
}

inline void zcode_op_print_addr(ZStack* stack, ZUWord arg)
{
  int len;

#ifdef DEBUG
  printf(">%s<\n", zscii_to_ascii(machine.memory + arg, &len));
#endif
  
  stream_prints(zscii_to_ascii(machine.memory + arg, &len));
}

inline void zcode_op_call_1s_45678(ZDWord* pc,
				   ZStack* stack,
				   ZWord arg,
				   int st)
{
  ZDWord  new_routine;
  ZFrame* newframe;

  if (arg == 0)
    {
      store(stack, st, 0);
      return;
    }
  
  new_routine = UnpackR(arg);
  newframe = call_routine(pc, stack, new_routine);

  newframe->storevar = st;
}
 

inline void zcode_op_remove_obj_123(ZStack* stack,
				    ZWord arg)
{
  zcode_op_insert_obj_123(stack, 2, arg, 0);
}

inline void zcode_op_remove_obj_45678(ZStack* stack,
				      ZWord arg)
{
  zcode_op_insert_obj_45678(stack, 2, arg, 0);
}

inline void zcode_op_print_obj_123(ZStack* stack, ZWord arg)
{
  ZByte* obj;
  ZByte* prop;
  int len;

  obj = Obj3(arg);
  prop = machine.memory + ((obj[7]<<8)|obj[8]) + 1;

#ifdef DEBUG
  printf(">%s<\n", zscii_to_ascii(prop, &len));
#endif

  stream_prints(zscii_to_ascii(prop, &len));
}

inline void zcode_op_print_obj_45678(ZStack* stack,
				     ZWord arg)
{
  ZByte* obj;
  ZByte* prop;
  int len;

  obj = Obj4(arg);
  prop = Address((ZUWord)GetPropAddr4(obj)+1);

#ifdef DEBUG
  printf(">%s<\n", zscii_to_ascii(prop, &len));
#endif

  stream_prints(zscii_to_ascii(prop, &len));
}

inline void zcode_op_ret(ZDWord* pc,
			 ZStack* stack,
			 ZWord arg)
{
  ZFrame* oldframe;
  
  oldframe = stack->current_frame;
  stack->current_frame = oldframe->last_frame;
  stack->stack_top  -= oldframe->frame_size;
  stack->stack_size += oldframe->frame_size;

  *pc = oldframe->ret;

  if (oldframe->discard == 0)
    store(stack, oldframe->storevar, arg);

  if (oldframe->v4read != NULL)
    (oldframe->v4read)(pc, stack, &oldframe->readblock);
  if (oldframe->v5read != NULL)
    (oldframe->v5read)(pc, stack, &oldframe->readblock, oldframe->readstore);

#ifdef DEBUG
  if (oldframe->discard == 0)
    printf("Returned %i into V%x\n", arg, oldframe->storevar);
  if (stack->current_frame != NULL)
    printf("Stack: returned, discarded %i outstanding items (stack top now #%x, size %i, frame usage %i)\n",
	   oldframe->frame_size, stack->stack_top, stack->stack_size,
	   stack->current_frame!=NULL?stack->current_frame->frame_size:-1);
#endif
  
  free(oldframe);
}

inline void zcode_op_jump(ZDWord* pc, ZStack* stack, ZWord arg)
{
  *pc+=arg-2;
}

inline void zcode_op_print_paddr_123(ZStack* stack,
				     ZUWord arg)
{
  int len;

#ifdef DEBUG
  printf(">%s<\n", zscii_to_ascii(machine.memory + (((ZDWord)arg)<<1), &len));
#endif

  stream_prints(zscii_to_ascii(machine.memory + (((ZDWord)arg)<<1), &len));
}

inline void zcode_op_print_paddr_45678(ZStack* stack,
				       ZUWord arg)
{
  int len;

#ifdef DEBUG
  printf(">%s<\n", zscii_to_ascii(machine.memory + UnpackS(arg), &len));
#endif

  stream_prints(zscii_to_ascii(machine.memory + UnpackS(arg), &len));
}

inline void zcode_op_call_1n_5678 (ZDWord* pc,
				   ZStack* stack,
				   ZWord arg)
{
  ZDWord  new_routine;
  ZFrame* newframe;

  if (arg == 0)
    {
      return;
    }

  new_routine = UnpackR(arg);
  
  newframe = call_routine(pc, stack, new_routine);

  newframe->discard = 1;
}

inline void zcode_op_load(ZStack* stack,
			  ZWord arg,
			  int st)
{
  store(stack, st, GetVar(arg));
}

inline void zcode_op_not_1234(ZStack* stack,
			      ZWord arg,
			      int st)
{
  store(stack, st, ~GetVar(arg));
}

/* 0OPs */
inline void zcode_op_rtrue(ZDWord* pc, ZStack* stack)
{
  zcode_op_ret(pc, stack, 1);
}

inline void zcode_op_rfalse(ZDWord* pc, ZStack* stack)
{
  zcode_op_ret(pc, stack, 0);
}

inline void zcode_op_print(char* string)
{
#ifdef DEBUG
  printf(">%s<\n", string);
#endif
  stream_prints(string);
}

inline void zcode_op_print_ret(ZDWord* pc,
			       ZStack* stack,
			       char* string)
{
#ifdef DEBUG
  printf("R>%s<\n", string);
#endif
  stream_prints(string);
  stream_prints("\n");
  zcode_op_rtrue(pc, stack);
}

inline void zcode_op_nop(ZStack* stack)
{
  /* Zzz */
}

static inline int save_1234(ZDWord  pc,
			    ZStack* stack,
			    int     st)
{
  static char fname[256] = "savefile.qut";
  ZWord tmp;
  int ok;

  do
    {
      ok = 1;
      display_prints("\nPlease supply a filename for save\nFile: ");
      display_readline(fname, 255, 0);

      if (get_file_size(fname) != -1)
	{
	  char yn[5];

	  yn[0] = 0;
	  ok = 0;
	  display_prints("That file already exists!\nAre you sure? (y/N) ");
	  display_readline(yn, 4, 0);

	  if (tolower(yn[0]) == 'y')
	    ok = 1;
	  else
	    {
	      return 0;
	    }
	}
    }
  while (!ok);
  
  if (st >= 0)
    store(stack, st, 2);

  if (state_save(fname, stack, pc))
    {
      if (st == 0)
	tmp = GetVar(st);
      return 1;
    }

  if (state_fail())
    display_printf("(Save failed, reason: %s)\n", state_fail());
  else
    display_printf("(Save failed, reason unknown)\n");

  if (st == 0)
    tmp = GetVar(st);
  return 0;
}

inline void zcode_op_saven_123(ZDWord* pc,
			       ZStack* stack,
			       ZDWord branch)
{
  if (!save_1234(*pc, stack, -1))
    {
      dobranch;
    }
}

inline void zcode_op_save_123(ZDWord* pc,
			      ZStack* stack,
			      ZDWord  branch)
{
  ZDWord newpc;
  
  if (branch == 0 || branch == 1)
    {
      zmachine_warning("This interpreter does not support returning from v3 save statements correctly");
      newpc = *pc;
    }
  else
    newpc = *pc + branch-2;

  if (save_1234(newpc, stack, -1))
    {
      dobranch;
    }
}

inline void zcode_op_save_4(ZDWord* pc, ZStack* stack, int st)
{
  if (save_1234(*pc, stack, st))
    store(stack, st, 1);
  else
    store(stack, st, 0);
}

static inline int restore_1234(ZDWord* pc, ZStack* stack)
{
  static char fname[256] = "savefile.qut";
  
  display_prints("\nPlease supply a filename for restore\nFile: ");
  display_readline(fname, 255, 0);
  
  if (state_load(fname, stack, pc))
    {
      restart_machine();
      return 1;
    }

  if (state_fail())
    display_printf("(Restore failed, reason: %s)\n", state_fail());
  else
    display_printf("(Restore failed, reason unknown)\n");
  
  return 0;
}

inline void zcode_op_restoren_123(ZDWord* pc,
				  ZStack* stack,
				  ZDWord branch)
{
  if (!restore_1234(pc, stack))
    {
      dobranch;
    }
}

inline void zcode_op_restore_123(ZDWord* pc,
				 ZStack* stack,
				 ZDWord branch)
{
  restore_1234(pc, stack);
}

inline void zcode_op_restore_4(ZDWord* pc,
			       ZStack* stack,
			       int st)
{
  if (!restore_1234(pc, stack))
    {
      store(stack, st, 0);
    }
}

inline void zcode_op_restart(ZDWord* pc, ZStack* stack)
{
  /* Unwind stack */
  while (stack->current_frame->last_frame != NULL)
    {
      ZFrame* oldframe;

      oldframe = stack->current_frame;
      stack->current_frame = oldframe->last_frame;

      stack->stack_size += oldframe->frame_size;
      stack->stack_top  -= oldframe->frame_size;

      free(oldframe);
    }
  
  read_block2(machine.memory, machine.file, 0, machine.dynamic_ceiling);
  *pc = Word(ZH_initpc);

  restart_machine();
}

inline void zcode_op_ret_popped(ZDWord* pc,
				ZStack* stack)
{
  zcode_op_ret(pc, stack, pop(stack));
}

inline void zcode_op_pop_1234(ZStack* stack)
{
  pop(stack);
}

inline void zcode_op_quit(ZDWord* pc, ZStack* stack)
{
  *pc = -1;
}

inline void zcode_op_new_line(ZStack* stack)
{
  stream_prints("\n");
  stream_flush_buffer();
}

inline void zcode_op_show_status_3(ZStack* stack)
{
  draw_statusbar_123(stack);
}

inline void zcode_op_status_nop_45678(ZStack* stack)
{ /* Snore */ }

inline void zcode_op_verifyn_345678  (ZDWord* pc, ZStack* stack,
				      ZDWord branch)
{
  /* We just assume the verification has passed */
}

inline void zcode_op_verify_345678(ZDWord* pc,
				   ZStack* stack,
				   ZDWord branch)
{
  dobranch;
}

inline void zcode_op_piracy_5678(ZDWord* pc,
				 ZStack* stack,
				 ZDWord branch)
{
  dobranch;
}

inline void zcode_op_piracyn_5678(ZDWord* pc,
				  ZStack* stack,
				  ZDWord branch)
{
  /* Snore */
}

/* VAR ops */

inline void zcode_op_call_123(ZDWord* pc,
			      ZStack* stack,
			      ZArgblock* args,
			      int st)
{
  ZDWord  new_routine;
  ZFrame* newframe;
  int     x;
  
  if (args->n_args < 1)
    zmachine_fatal("call must have 1 argument");

  if (args->arg[0] == 0)
    {
      store(stack, st, 0);
      return;
    }
  
  new_routine = 2*(ZUWord)args->arg[0];
  
#ifdef DEBUG
  printf("CALL $%x -> V%03i\n", new_routine, st);
#endif

  newframe = call_routine(pc, stack, new_routine);

  for (x=1; x<args->n_args; x++)
    {
      newframe->flags |= 1<<(x-1);
      newframe->local[x] = args->arg[x];
    }

  newframe->storevar = st;
}

inline void zcode_op_call_vs_45678(ZDWord* pc,
				   ZStack* stack,
				   ZArgblock* args,
				   int st)
{
  ZDWord  new_routine;
  ZFrame* newframe;
  int     x;
  
  if (args->n_args < 1)
    zmachine_fatal("call must have 1 argument");

  if (args->arg[0] == 0)
    {
      store(stack, st, 0);
      return;
    }
  
  new_routine = UnpackR((ZUWord)args->arg[0]);
  
#ifdef DEBUG
  printf("CALL $%x -> V%03i\n", new_routine, st);
#endif

  newframe = call_routine(pc, stack, new_routine);

  for (x=1; x<args->n_args; x++)
    {
      newframe->flags |= 1<<(x-1);
      newframe->local[x] = args->arg[x];
    }

  newframe->storevar = st;  
}

inline void zcode_op_output_stream_3(ZStack*, ZArgblock*);

inline void zcode_op_storew(ZStack* stack,
			    ZArgblock* args)
{
  ZByte* mem;

#ifdef DEBUG
  printf("Storing word value %i at #%x\n",
	 args->arg[2],
	 ((ZUWord) args->arg[0] + (ZUWord) (args->arg[1]*2))&0xffff);
#endif
#ifdef SAFE
  if (((ZUWord) args->arg[0] + ((ZUWord) args->arg[1]*2)) >
      machine.dynamic_ceiling)
    zmachine_fatal("Out of range storew (tried to store at $%x, but ceiling is at $%x)",
		   ((ZUWord) args->arg[0] + ((ZUWord) args->arg[1]*2)),
		   machine.dynamic_ceiling);
#endif
  
  if ((ZUWord) args->arg[0] + ((ZUWord) args->arg[1]*2) == ZH_flags2)
    {
      ZArgblock a;

      stream_flush_buffer();
      
      a.n_args = 1;
      a.arg[0] = (args->arg[2]&1)?2:-2;

      zcode_op_output_stream_3(stack, &a);

      args->arg[2] &= ~1;
      args->arg[2] |= Word(ZH_flags2)&1;
    }

  mem = Address(((ZUWord) args->arg[0] + ((ZUWord) args->arg[1]*2))&0xffff);
  mem[0] = args->arg[2]>>8;
  mem[1] = args->arg[2];
}

inline void zcode_op_storeb(ZStack* stack,
			    ZArgblock* args)
{
  ZByte* mem;

#ifdef DEBUG
  printf("Storing byte value %i at #%x\n",
	 args->arg[2],
	 ((ZUWord) args->arg[0] + (ZUWord) args->arg[1])&0xffff);
#endif
#ifdef SAFE
  if (((ZUWord) args->arg[0] + (ZUWord) args->arg[1]) >
      machine.dynamic_ceiling)
    zmachine_fatal("Out of range storeb (store to $%x, ceiling at $%x)", ((ZUWord) args->arg[0] + (ZUWord) args->arg[1]), machine.dynamic_ceiling);
#endif

  mem = Address(((ZUWord) args->arg[0] + (ZUWord) args->arg[1])&0xffff);
  mem[0] = args->arg[2];
}

inline void zcode_op_put_prop_123(ZStack* stack,
				  ZArgblock* args)
{
  struct prop* p;
  
  if (args->arg[0]>255 || args->arg[0] == 0)
    zmachine_fatal("Object out of range");
  if (args->arg[1]>31)
    zmachine_fatal("Property out of range");
  
  p = get_object_prop_3(args->arg[0], args->arg[1]);
  if (p->isdefault)
    zmachine_fatal("No such property %i for object %i", args->arg[1], args->arg[0]);

  switch (p->size)
    {
    case 1:
      p->prop[0] = args->arg[2];
      break;
      
    case 2:
      p->prop[0] = args->arg[2]>>8;
      p->prop[1] = args->arg[2];
      break;

    default:
      zmachine_fatal("%i is an invalid size for put_prop", p->size);
    }
}

inline void zcode_op_put_prop_45678(ZStack* stack,
				    ZArgblock* args)
{
  struct prop* p;
  
  if (args->arg[0] == 0)
    zmachine_fatal("Object 0 has no properties");
  if (args->arg[1]>63)
    zmachine_fatal("Property out of range");
  
  p = get_object_prop_4(args->arg[0], args->arg[1]);
  if (p->isdefault)
    zmachine_fatal("No such property %i for object %i", args->arg[1], args->arg[0]);

  switch (p->size)
    {
    case 1:
      p->prop[0] = args->arg[2];
      break;
      
    case 2:
      p->prop[0] = args->arg[2]>>8;
      p->prop[1] = args->arg[2];
      break;

    default:
      zmachine_fatal("%i is an invalid size for put_prop", p->size);
    }
}

static inline void draw_statusbar_123(ZStack* stack)
{
  ZWord score;
  ZWord moves;

  stream_flush_buffer();
  stream_buffering(0);
  
  display_set_window(1); display_set_font(3);
  display_set_colour(7, 0);

  display_prints("\n ");
  display_set_cursor(2, 0);
  zcode_op_print_obj_123(stack, GetVar(16));

  score = GetVar(17);
  moves = GetVar(18);

  display_set_cursor(50, 0);
  if (machine.memory[1]&0x2)
    {
      display_printf("Time: %2i:%02i", (score+11)%12+1, moves);
    }
  else
    {
      display_printf("Score: %i  Moves: %i", score, moves);
    }

  display_set_colour(0, 7); display_set_font(0);
  display_set_window(0);
  stream_buffering(1);
}

inline void zcode_op_sread_123(ZStack* stack, ZArgblock* args)
{
  ZByte* mem;
  char* buf;
  int x;

  stream_flush_buffer();

  mem = machine.memory + (ZUWord) args->arg[0];
  buf = malloc(sizeof(char)*(mem[0]+1));
  
  buf[0] = 0;
  draw_statusbar_123(stack);
  display_readline(buf, mem[0], 0);
  stream_input(buf);
  
  for (x=0; buf[x] != 0; x++)
    {
      buf[x] = tolower(buf[x]);
      mem[x+1] = buf[x];
    }
  mem[x+1] = 0;

  if (args->n_args > 1)
    {
      tokenise_string(buf,
		      Word(ZH_dict),
		      machine.memory + (ZUWord) args->arg[1],
		      0,
		      1);

#ifdef DEBUG
      {
	ZByte* tokbuf;
	tokbuf = machine.memory + (ZUWord) args->arg[1];
	for (x=0; x<tokbuf[1]; x++)
	  {
	    printf("Token $%x%x word at %i, length %i\n",
			   tokbuf[2+x*4],
			   tokbuf[3+x*4],
			   tokbuf[5+x*4],
			   tokbuf[4+x*4]);
	  }
      }
#endif
    }

  free(buf);
}

inline void zcode_op_sread_4(ZDWord* pc,
			     ZStack* stack,
			     ZArgblock* args)
{
  ZByte* mem;
  static char* buf;
  int x;

  stream_flush_buffer();

  mem = machine.memory + (ZUWord) args->arg[0];

  if (args->arg[7] != 0)
    {
      ZWord ret;
      
      /* Returning from a timeout routine */

      ret = pop(stack);

      if (ret != 0)
	{
	  mem[1] = 0;
	  return;
	}
    }
  else
    {
      buf = malloc(sizeof(char)*(mem[0]+1));
      buf[0] = 0;
    }
  
  if (args->arg[2] == 0)
    {
      display_readline(buf, mem[0], 0);
    }
  else
    {
      int res;
      
      res = display_readline(buf, mem[0], args->arg[2]*100);
      
      if (!res)
	{
	  ZFrame* newframe;
	  int x;

	  stream_input(buf);

	  for (x=0; buf[x] != 0; x++)
	    {
	      buf[x] = tolower(buf[x]);
	      mem[x+1] = tolower(x);
	    }
	  mem[x+1] = 0;

	  newframe = call_routine(pc, stack, UnpackR(args->arg[3]));
	  args->arg[7] = 1;
	  newframe->storevar  = 0;
	  newframe->flags     = 0;
	  newframe->readblock = *args;
	  newframe->v4read    = zcode_op_sread_4;
	  return;
	}
    }

  stream_input(buf);
  for (x=0; buf[x] != 0; x++)
    {
      buf[x] = tolower(buf[x]);
      mem[x+1] = buf[x];
    }
  mem[x+1] = 0;

  if (args->n_args > 1)
    {
      tokenise_string(buf,
		      Word(ZH_dict),
		      machine.memory + (ZUWord) args->arg[1],
		      0,
		      1);

#ifdef DEBUG
      {
	ZByte* tokbuf;
	tokbuf = machine.memory + (ZUWord) args->arg[1];
	for (x=0; x<tokbuf[1]; x++)
	  {
	    printf("Token $%x%x word at %i, length %i\n",
			   tokbuf[2+x*4],
			   tokbuf[3+x*4],
			   tokbuf[5+x*4],
			   tokbuf[4+x*4]);
	  }
      }
#endif
    }

  free(buf);
}

inline void zcode_op_aread_5678(ZDWord* pc,
				ZStack* stack,
				ZArgblock* args,
				int st)
{
  ZByte* mem;
  char* buf;
  int x;
  
  mem = machine.memory + (ZUWord) args->arg[0];
  buf = malloc(sizeof(char)*(mem[0]+1));

  if (args->arg[7] != 0)
    {
      ZWord ret;
      
      /* Returning from a timeout routine */

      ret = pop(stack);

      if (ret != 0)
	{
	  mem[1] = 0;
	  free(buf);
	  return;
	}
    }
  
  if (mem[1] != 0)
    {
      /* zmachine_warning("aread: using existing buffer (display may
       * get messed up)"); */
      
      for (x=0; x<mem[1]; x++)
	{
	  buf[x] = mem[x+2];
	}
      buf[x] = 0;

      stream_remove_buffer(buf);
    }
  else
    buf[0] = 0;

  stream_flush_buffer();

  if (args->arg[2] == 0)
    {
      display_readline(buf, mem[0], 0);
      stream_input(buf);
    }
  else
    {
      int res;

      res = display_readline(buf, mem[0], args->arg[2]*100);
      
      if (!res)
	{
	  ZFrame* newframe;
	  int x;

	  mem[1] = 0;
	  for (x=0; buf[x] != 0; x++)
	    {
	      mem[1]++;
	      buf[x] = tolower(buf[x]);
	      mem[x+2] = buf[x];
	    }

	  newframe = call_routine(pc, stack, UnpackR(args->arg[3]));
	  args->arg[7] = 1;
	  newframe->storevar  = 0;
	  newframe->flags     = 0;
	  newframe->readblock = *args;
	  newframe->readstore = st;
	  newframe->v5read    = zcode_op_aread_5678;
	  free(buf);
	  return;
	}

      stream_input(buf);
    }

  mem[1] = 0;
  for (x=0; buf[x] != 0; x++)
    {
      mem[1]++;
      buf[x] = tolower(buf[x]);
      mem[x+2] = buf[x];
    }

  if (args->n_args > 1 && args->arg[1] != 0)
    {
      tokenise_string(buf,
		      Word(ZH_dict),
		      Address((ZUWord) args->arg[1]),
		      0,
		      2);

#ifdef DEBUG
      {
	ZByte* tokbuf;
	tokbuf = Address((ZUWord)args->arg[1]);
	printf("Dump of parse buffer $%x\n", args->arg[1]);
	for (x=0; x<tokbuf[1]; x++)
	  {
	    printf("  Token $%x%x word at %i, length %i\n",
		   tokbuf[2+x*4],
		   tokbuf[3+x*4],
		   tokbuf[5+x*4],
		   tokbuf[4+x*4]);
	  }
      }
#endif
    }

  free(buf);

  store(stack, st, 10);
}

inline void zcode_op_print_char(ZStack* stack,
				ZArgblock* args)
{
#ifdef DEBUG
  printf(">%c<\n", args->arg[0]);
#endif
  if (args->arg[0] == 0)
    args->arg[0] = 32;
  stream_printf("%c", args->arg[0]);
}

inline void zcode_op_print_num(ZStack* stack,
			       ZArgblock* args)
{
#ifdef DEBUG
  printf(">%i<\n", args->arg[0]);
#endif
  stream_printf("%i", args->arg[0]);
}

inline void zcode_op_random(ZStack* stack,
			    ZArgblock* args,
			    int st)
{
  if (args->arg[0] > 0)
    {
      store(stack, st, (rand()%args->arg[0])+1);
    }
  else if (args->arg[0] < 0)
    {
      srand(args->arg[0]);
      store(stack, st, 0);
    }
  else
    {
      struct timeval tv;
      
      /* Reseed RNG */
      gettimeofday(&tv, NULL);
      srand(tv.tv_sec|tv.tv_usec);

      store(stack, st, 0);
    }
}

inline void zcode_op_push(ZStack* stack,
			  ZArgblock* args)
{
  push(stack, args->arg[0]);
}

inline void zcode_op_pull_1234578(ZStack* stack,
				  ZArgblock* args)
{
  ZUWord val;

  val = pop(stack);
  store(stack, args->arg[0], val);
}

inline void zcode_op_split_window_345678(ZStack* stack, ZArgblock* args)
{
  stream_flush_buffer();

  if (args->arg[0] != 0)
    {
      int win;
      int ver;

      ver = Byte(0);

#ifdef DEBUG
      printf("Top window bottom is now %i\n", args->arg[0]);
#endif
      
      win = display_get_window();
      
      display_set_window(0);
      display_join(0, 2);
      display_split(args->arg[0], 2);
      display_no_more(2);
      display_set_window(2);
      if (ver == 3)
	{
	  display_set_cursor(0,1);
	  display_erase_window();
	}
      display_set_scroll(0);
      display_force_fixed(2, 1);

      display_set_window(win);
    }
  else
    {
      display_join(0, 2);
      display_set_window(0);
    }

  if (machine.transcript_on == 2 && display_get_window() == 0)
    machine.transcript_on = 1;
}

inline void zcode_op_set_window_34578(ZStack* stack, ZArgblock* args)
{
  stream_flush_buffer();

  switch (args->arg[0])
    {
    case 0:
      stream_buffering(machine.buffering);
      display_set_window(0);

      if (machine.transcript_on == 2)
	machine.transcript_on = 1;
      break;
    case 1:
      stream_buffering(0);
      display_set_window(2);
      if (Byte(0) == 3)
	display_set_cursor(0,1);

      if (machine.transcript_on == 1)
	machine.transcript_on = 2;
      break;
    default:
      zmachine_warning("Window %i not available", args->arg[0]);
    }
}

inline void zcode_op_call_vs2_45678(ZDWord* pc,
				    ZStack* stack,
				    ZArgblock* args,
				    int store)
{
  zcode_op_call_vs_45678(pc, stack, args, store);
}


inline void zcode_op_erase_window_45678(ZStack* stack,
					ZArgblock* args)
{
  int old_win;

  stream_flush_buffer();
  old_win = display_get_window();
  
  switch (args->arg[0])
    {
    case 0:
      display_set_window(0);
      display_erase_window();
      if (Byte(0) != 4)
	display_set_cursor(0,0);
      display_set_window(old_win);
      break;
      
    case 1:
      display_set_window(2);
      display_erase_window();
      display_set_cursor(0,0);
      display_set_window(old_win);
      break;

    case -1:
      display_join(0, 2);
      display_set_window(0);
      display_erase_window();
      if (Byte(0) != 4)
	display_set_cursor(0,0);
      break;
    }
}

inline void zcode_op_erase_line_4578(ZStack*    stack,
				     ZArgblock* args)
{
  display_erase_line(1);
}

inline void zcode_op_set_cursor_4578(ZStack* stack,
				     ZArgblock* args)
{
  stream_flush_buffer();
#ifdef DEBUG
  printf("Cursor moved to %i, %i\n", args->arg[1]-1, args->arg[0]-1);
#endif
  display_set_cursor(args->arg[1]-1, args->arg[0]-1);
}

inline void zcode_op_get_cursor_45678(ZStack* stack,
				      ZArgblock* args)
{
  ZByte* dest;
  int x, y;

  dest = Address((ZUWord)args->arg[0]);
  x = display_get_cur_x()+1;
  y = display_get_cur_y()+1;

  dest[0] = y>>8;
  dest[1] = y;
  dest[2] = x>>8;
  dest[3] = x;
}

inline void zcode_op_set_text_style_45678(ZStack* stack,
					  ZArgblock* args)
{
  stream_flush_buffer();
  display_set_style(args->arg[0]);
}

inline void zcode_op_buffer_mode_45678(ZStack* stack,
				       ZArgblock* args)
{
  machine.buffering = args->arg[0];
  stream_buffering(args->arg[0]);
}

inline void zcode_op_output_stream_3(ZStack* stack,
				     ZArgblock* args)
{
  ZWord w;
  
  stream_flush_buffer();

  switch (args->arg[0])
    {
    case 0:
      return;
      
    case 1:
      machine.screen_on = 1;
      break;
    case -1:
      machine.screen_on = 0;
      break;

    case 2:
      if (machine.transcript_file == NULL)
	{
	  static char fname[256] = "script.txt";
	  
	  display_prints("\nPlease supply a filename for transcript\nFile: ");
	  display_readline(fname, 255, 0);
	  if (get_file_size(fname) != -1)
	    {
	      char yn[5];

	      yn[0] = 0;
	      display_prints("That file already exists!\nAre you sure? (y/N) ");
	      display_readline(yn, 1, 0);
	      
	      if (tolower(yn[0]) == 'y')
		machine.transcript_file = fopen(fname, "a");
	    }
	  if (machine.transcript_file == NULL)
	    {
	      display_prints("Failed.\n");
	      return;
	    }
	  else
	    {
	      fprintf(machine.transcript_file, "*** Transcript generated by Zoom " VERSION "\n\n");
	    }
	}

      if (machine.transcript_file != NULL)
	machine.transcript_on = 1;
      w = Word(ZH_flags2);
      w |= 1;
      machine.memory[ZH_flags2] = w>>8;
      machine.memory[ZH_flags2+1] = w;
      break;
    case -2:
      if (machine.transcript_file != NULL)
	fflush(machine.transcript_file);
      machine.transcript_on = 0;

      w = Word(ZH_flags2);
      w &= ~1;
      machine.memory[ZH_flags2] = w>>8;
      machine.memory[ZH_flags2+1] = w;
      break;
      
    default:
      zmachine_warning("Stream number %i not supported by this interpreter (for versions 1, 2 & 3)", args->arg[0]);
    }
}

inline void zcode_op_output_stream_4578(ZStack* stack,
					ZArgblock* args)
{
  ZByte* mem;
  ZWord w;

  stream_flush_buffer();
  
  switch (args->arg[0])
    {
    case 0:
      return;
      
    case 1:
      machine.screen_on = 1;
      break;
    case -1:
      machine.screen_on = 0;
      break;

    case 2:
      if (machine.transcript_file == NULL)
	{
	  static char fname[256] = "script.txt";
	  
	  display_prints("\nPlease supply a filename for transcript\nFile: ");
	  display_readline(fname, 256, 0);

	  if (get_file_size(fname) != -1)
	    {
	      char yn[5];

	      yn[0] = 0;
	      display_prints("That file already exists!\nAre you sure? (y/N) ");
	      display_readline(yn, 1, 0);
	      
	      if (tolower(yn[0]) == 'y')
		machine.transcript_file = fopen(fname, "a");
	    }
	  if (machine.transcript_file == NULL)
	    {
	      display_prints("Failed.\n");
	      return;
	    }
	  else
	    {
	      machine.transcript_on = 1;
	      fprintf(machine.transcript_file, "*** Transcript generated by Zoom\n\n");
	    }
	}

      if (machine.transcript_file != NULL)
	machine.transcript_on = 1;

      w = Word(ZH_flags2);
      w |= 1;
      machine.memory[ZH_flags2] = w>>8;
      machine.memory[ZH_flags2+1] = w;
      break;
    case -2:
      if (machine.transcript_file != NULL)
	fflush(machine.transcript_file);
      machine.transcript_on = 0;

      w = Word(ZH_flags2);
      w &= ~1;
      machine.memory[ZH_flags2] = w>>8;
      machine.memory[ZH_flags2+1] = w;
      break;

    case 3:
      if (args->arg[1] == 0)
	zmachine_fatal("output_stream 3 must be supplied with a memory address");
      machine.memory_on++;
      if (machine.memory_on > 16)
	zmachine_fatal("Maximum recurse level for memory redirect is 16");
      machine.memory_pos[machine.memory_on-1] = args->arg[1];

      mem = Address((ZUWord)machine.memory_pos[machine.memory_on-1]);
      mem[0] = 0;
      mem[1] = 0;
      break;
    case -3:
      machine.memory_on--;
      if (machine.memory_on < 0)
	{
	  machine.memory_on = 0;
	  zmachine_warning("Tried to stop writing to memory when no memory redirect was in effect");
	}
      break;
      
    default:
      zmachine_warning("Stream number %i not supported by this interpreter (for versions 4, 5, 7 & 8)", args->arg[0]);
    }
}

inline void zcode_op_input_stream_345678 (ZStack* stack, ZArgblock*
					  args) {
  zmachine_warning("input_stream not implemented"); }

inline void zcode_op_sound_effect_345678(ZStack*    stack,
					 ZArgblock* args)
{
  display_beep();
}

inline void zcode_op_read_char_45678(ZStack* stack,
				     ZArgblock* args,
				     int st)
{
  stream_flush_buffer();
  store(stack, st, display_readchar(0));
}

static inline ZDWord scan_table(ZUWord word,
				ZUWord addr,
				ZUWord len,
				ZUWord form)
{
  int p;

  if (form&0x80)
    {
      for (p=0; p<len; p++)
	{
	  if (Word(addr) == word)
	    return addr;
	  addr += form&0x7f;
	}
    }
  else
    {
      for (p=0; p<len; p++)
	{
	  if (Byte(addr) == word)
	    return addr;
	  addr += form&0x7f;
	}
    }

  return -1;
}

inline void zcode_op_scan_table_45678(ZDWord* pc,
				      ZStack* stack,
				      ZArgblock* args,
				      int st,
				      ZDWord branch)
{
  ZDWord adr;
  
  if (args->n_args < 4)
    args->arg[3] = 0x82;

  adr = scan_table(args->arg[0],
		   args->arg[1],
		   args->arg[2],
		   args->arg[3]);

  if (adr > 0)
    {
      store(stack, st, adr);
      dobranch;
    }
  else
    {
      store(stack, st, 0);
    }
}

inline void zcode_op_scan_tablen_45678(ZDWord* pc,
				       ZStack* stack,
				       ZArgblock* args,
				       int st,
				       ZDWord branch)
{
  ZDWord adr;
  
  if (args->n_args < 4)
    args->arg[3] = 0x82;

  adr = scan_table(args->arg[0],
		   args->arg[1],
		   args->arg[2],
		   args->arg[3]);

  if (adr > 0)
    {
      store(stack, st, adr);
    }
  else
    {
      store(stack, st, 0);
      dobranch;
    }
}

inline void zcode_op_not_5678(ZStack* stack, ZArgblock* args, int st)
{
  store(stack, st, ~args->arg[0]);
}

inline void zcode_op_call_vn_5678(ZDWord* pc,
				  ZStack* stack,
				  ZArgblock* args)
{
  ZDWord  new_routine;
  ZFrame* newframe;
  int     x;

  if (args->n_args < 1)
    zmachine_fatal("call must have 1 argument");

  if (args->arg[0] == 0)
    {
      return;
    }
  
  new_routine = UnpackR((ZUWord)args->arg[0]);

  newframe = call_routine(pc, stack, new_routine);

  for (x=1; x<args->n_args; x++)
    {
      newframe->flags |= 1<<(x-1);
      newframe->local[x] = args->arg[x];
    }

  newframe->discard = 1;
}
     
inline void zcode_op_call_vn2_5678(ZDWord* pc,
				   ZStack* stack,
				   ZArgblock* args)
{
  zcode_op_call_vn_5678(pc, stack, args);
}

inline void zcode_op_tokenise_5678(ZStack* stack,
				   ZArgblock* args)
{
  ZByte* text;
  char*  buf;

  text = Address((ZUWord)args->arg[0]);
  buf = malloc(text[0]+1);
  strncpy(buf, text + 2, text[1]);
  buf[text[1]] = 0;
  
  tokenise_string(buf,
		  args->arg[2]==0?Word(ZH_dict):args->arg[2],
		  Address((ZUWord)args->arg[1]),
		  args->arg[3] != 0,
		  2);

#ifdef DEBUG
      {
	ZByte* tokbuf;
	int x;
	
	tokbuf = machine.memory + (ZUWord) args->arg[1];
	for (x=0; x<tokbuf[1]; x++)
	  {
	    printf("Token $%x%x word at %i, length %i\n",
			   tokbuf[2+x*4],
			   tokbuf[3+x*4],
			   tokbuf[5+x*4],
			   tokbuf[4+x*4]);
	  }
      }
#endif

  free(buf);
}

inline void zcode_op_encode_text_5678(ZStack* stack,
				      ZArgblock* args)
{
  /* Note: I haven't tested this yet */
  pack_zscii(Address((ZUWord)args->arg[0]) + args->arg[2],
	     args->arg[1],
	     Address((ZUWord)args->arg[3]),
	     9);
}

inline void zcode_op_copy_table_5678(ZStack* stack,
				     ZArgblock* args)
{
  if (args->arg[1] != 0)
    {
#ifdef DEBUG
      printf("Copying #%x bytes from #%x to #%x\n", args->arg[2],
	     (ZUWord)args->arg[0], (ZUWord)args->arg[1]);
#endif
      
      if (args->arg[2] >= 0) /* Move memory */
	memmove(Address((ZUWord)args->arg[1]),
		Address((ZUWord)args->arg[0]),
		(ZUWord)args->arg[2]);
      else /* Copy forwards */
	{
	  ZUWord x;
	  ZByte* src;
	  ZByte* dest;

	  src = Address((ZUWord)args->arg[0]);
	  dest = Address((ZUWord)args->arg[1]);

	  for (x = 0; x<-args->arg[2]; x++)
	    {
	      dest[x] = src[x];
	    }
	}
    }
  else
    {
      ZUWord x;
      ZByte* mem;

#ifdef DEBUG
      printf("Blanking %i bytes from #%x\n", args->arg[2], (ZUWord)args->arg[0]);
#endif
      
      mem = Address((ZUWord)args->arg[0]);
      
      for (x=0; x<args->arg[2]; x++)
	{
	  mem[x] = 0;
	}
    }
}

inline void zcode_op_print_table_5678(ZStack* stack,
				      ZArgblock* args)
{
  ZByte* table;
  int x,y;
  int xpos;

  stream_flush_buffer();
  xpos = display_get_gcur_x();

  if (args->arg[2] == 0)
    args->arg[2] = 1;

#ifdef DEBUG
  printf("Printing table #%x (%ix%i), offset %i\n", args->arg[0], args->arg[1], args->arg[2], args->arg[3]);
#endif
  
  table = Address((ZUWord) args->arg[0]);

  for (y=0; y<args->arg[2]; y++)
    {
      if (y != 0)
	{
	  stream_prints("\n");
	  stream_flush_buffer();
	  if (machine.screen_on)
	    display_set_gcursor(xpos, display_get_gcur_y());
	}
      
      for (x=0; x<args->arg[1]; x++)
	{
	  unsigned char c;

	  c = (table++)[0];
	  if (c == 0)
	    c = 32;
	  if (c>31)
	    stream_printf("%c", c);
	}

      table += args->arg[3];
    }
  stream_flush_buffer();
}

inline void zcode_op_check_argcount_5678(ZDWord* pc,
					 ZStack* stack,
					 ZArgblock* args,
					 ZDWord branch)
{
  if (stack->current_frame->flags&(1<<(args->arg[0]-1)))
    {
      dobranch;
    }
}

inline void zcode_op_check_argcountn_5678(ZDWord* pc,
					  ZStack* stack,
					  ZArgblock* args,
					  ZDWord branch)
{
  if (!(stack->current_frame->flags&(1<<(args->arg[0]-1))))
    {
      dobranch;
    }
}

/* EXT ops */
inline void zcode_op_save_5678(ZDWord* pc,
			       ZStack* stack,
			       ZArgblock* args,
			       int st)
{
  static char fname[256] = "savefile.qut";
  int ok;

  stream_flush_buffer();
  
  if (args->n_args == 0)
    {
      ZWord tmp;
      
      do
	{
	  ok = 1;
	  display_prints("\nPlease supply a filename for save\nFile: ");
	  display_readline(fname, 255, 0);

	  if (get_file_size(fname) != -1)
	    {
	      char yn[5];

	      yn[0] = 0;
	      ok = 0;
	      display_prints("That file already exists!\nAre you sure? (y/N) ");
	      display_readline(yn, 1, 0);
	      
	      if (tolower(yn[0]) == 'y')
		ok = 1;
	      else
		{
		  store(stack, st, 0);
		  return;
		}
	    }
	}
      while (!ok);

      store(stack, st, 2);
      if (state_save(fname, stack, *pc))
	{
	  tmp = GetVar(st); /* Pop the variable if it was on the stack */
	  store(stack, st, 1);
	}
      else
	{
	  tmp = GetVar(st);
	  store(stack, st, 0);

	  if (state_fail())
	    display_printf("(Save failed, reason: %s)\n", state_fail());
	  else
	    display_printf("(Save failed, reason unknown)\n");
	}
    }
  else
    {
      char fname[256];
      ZFile* file;

      /* Untested */

      if (args->arg[3] != 0)
	strcpy(fname, Address(args->arg[2]));
      else
	strcpy(fname, "table.dat");

      display_prints("\nPlease supply a filename for save\nFile: ");
      display_readline(fname, 255, 0);

      if (!(file = open_file_write(fname)))
	{
	  store(stack, st, 0);
	  return;
	}

      write_block(file, Address(args->arg[0]), args->arg[1]);
	
      store(stack, st, 1);
    }
}

inline void zcode_op_restore_5678(ZDWord* pc,
				  ZStack* stack,
				  ZArgblock* args,
				  int st)
{
  static char fname[256] = "savefile.qut";
  
  if (args->n_args == 0)
    {
      display_prints("\nPlease supply a filename for restore\nFile: ");
      display_readline(fname, 255, 0);

      if (state_load(fname, stack, pc))
	{
	  restart_machine();
	  return;
	}

      if (state_fail())
	display_printf("(Restore failed, reason: %s)\n", state_fail());
      else
	display_printf("(Restore failed, reason unknown)\n");
      
      store(stack, st, 0);
    }
  else
    {
      char fname[256];
      ZFile* file;

      /* Untested */

      if (args->arg[3] != 0)
	strcpy(fname, Address(args->arg[2]));
      else
	strcpy(fname, "table.dat");

      display_prints("\nPlease supply a filename for restore\nFile: ");
      display_readline(fname, 255, 0);

      if (!(file = open_file(fname)))
	{
	  store(stack, st, 0);
	  return;
	}

      read_block2(Address(args->arg[0]),
		  file, 0, args->arg[1]);
	
      store(stack, st, 1);
    }
}

inline void zcode_op_log_shift_5678(ZStack* stack,
				    ZArgblock* args,
				    int st)
{
  if (args->arg[1] >= 0)
    {
      store(stack, st, args->arg[0]<<args->arg[1]);
    }
  else
    {
      ZUWord result;

      result = args->arg[0];
      result >>= -args->arg[1];
      store(stack, st, result);
    }
}

inline void zcode_op_art_shift_5678(ZStack* stack,
				    ZArgblock* args,
				    int st)
{
  if (args->arg[1] >= 0)
    {
      store(stack, st, args->arg[0]<<args->arg[1]);
    }
  else
    {
      store(stack, st, args->arg[0]>>-args->arg[1]);
    }
}

inline void zcode_op_set_font_5678(ZStack* stack,
				   ZArgblock* args,
				   int store)
{
  stream_flush_buffer();
  
  switch (args->arg[0])
    {
    case 1:
      display_set_font(0);
      break;

    case 3:
      display_set_font(-1);
      break;

    case 4:
      display_set_font(3);
      break;

    default:
      zmachine_warning("Font %i not supported", args->arg[0]);
    }
}

inline void zcode_op_save_undo_5678(ZDWord* pc,
				    ZStack* stack,
				    ZArgblock* args,
				    int st)
{
#ifdef CAN_UNDO
  ZWord tmp;

  if (machine.undo)
    free(machine.undo);
  
  store(stack, st, 2);
  machine.undo = state_compile(stack, *pc, &machine.undo_len,
#ifdef SQUEEZE_UNDO
			       1
#else
			       0
#endif
			       );
  tmp = GetVar(st); /* (Pop the value again if it's on the stack) */
  
  if (machine.undo)
    store(stack, st, 1);
  else
    store(stack, st, 0);
#else
  store(stack, st, -1);
#endif
}

inline void zcode_op_restore_undo_5678(ZDWord* pc,
				       ZStack* stack,
				       ZArgblock* args,
				       int st)
{
#ifdef CAN_UNDO
  if (machine.undo)
    {
      if (state_decompile(machine.undo, stack, pc, machine.undo_len))
	{
	  free(machine.undo);
	  machine.undo = NULL;
	  return;
	}
      free(machine.undo);
      machine.undo = NULL;
      store(stack, st, 0);
    }
#else
  store(stack, st, 0);
#endif
}

inline void zcode_op_print_unicode_578   (ZStack* stack, ZArgblock*
					  args) {
  zmachine_warning("print_unicode not implemented"); }
inline void zcode_op_check_unicode_578   (ZStack* stack, ZArgblock*
					  args, int store) {
  zmachine_warning("check_unicode not implemented"); }

/***                           ----// 888 \\----                           ***/

/* Version 6 opcodes */

#ifdef SUPPORT_VERSION_6

#ifndef GLOBAL_PC
#error Version 6 support requires a global program counter
#endif

static struct v6_wind
{
  int wrapping, scrolling, transcript, buffering;

  int x, y;
  int xsize, ysize;
  int xcur, ycur;
  int leftmar, rightmar;
  ZUWord newline_routine;
  ZWord countdown;
  int style;
  ZUWord colour;
  int font_num;
  ZUWord font_size;

  ZWord line_count;
} windows[8];

static int newline_function(const char* remaining, int rem_len);

void zcode_v6_initialise(void)
{
  int x;

  for (x=0; x<8; x++)
    {
      windows[x].wrapping   = 0;
      windows[x].scrolling  = 1;
      windows[x].buffering  = 1;
      windows[x].transcript = 0;
      windows[x].x = windows[x].y = 0;
      windows[x].xsize = windows[x].ysize = 100;
    }

  windows[0].wrapping = 1;

  display_set_newline_function(newline_function);

  pix_open_file("/home/ahunter/infocom/zorkzero/ZORK0/ZORK0.EG1");
}

static char* pending_text = NULL;
static int   pending_len;

static void newline_return(ZDWord* pc,
			   ZStack* stack,
			   ZArgblock args,
			   int st)
{
  printf("-- Newline return\n");
  if (pending_text != NULL)
    {
      char* oldtext;

      oldtext = pending_text; pending_text = NULL;
      display_prints(oldtext);
      free(oldtext);
    }
}

static int newline_function(const char* remaining,
			    int   rem_len)
{
  int win;

  win = display_get_window();

  if (windows[win].countdown > 0)
    {
      windows[win].countdown--;

      if (windows[win].countdown == 0)
	{
	  ZFrame* newframe;

	  pending_text = malloc(rem_len+1);
	  pending_len  = rem_len;
	  memcpy(pending_text, remaining, rem_len);
	  pending_text[rem_len] = 0;

	  newframe = call_routine(&machine.pc, &machine.stack,
				  UnpackR(windows[win].newline_routine));
	  newframe->storevar = 255;
	  newframe->discard  = 1;
	  newframe->v5read   = newline_return;
	  
	  return 2;
	}

      if (windows[win].line_count > -999)
	{
	  windows[win].line_count--;
	  if (windows[win].line_count == 0)
	    return 1;
	  return 0;
	}
      else if (windows[win].line_count == -999)
	{
	  return 0;
	}
      else
	return -1;
    }
  return -1;
}

inline void zcode_op_erase_line_6(ZStack* stack,
				  ZArgblock* args)
{
  display_erase_line(args->arg[0]);
}

inline void zcode_op_pull_6(ZStack*    stack,
			    ZArgblock* args,
			    int        st)
{
  if (args->arg[0] != 0)
    {
      ZByte* us;
      ZByte* val;
      ZUWord len;
      
      /* User stack */
      us = Address(args->arg[0]);
      len = (us[0]<<8)|us[1];
      len++;
      us[0] = len>>8; us[1] = len;
      val = us + len*2;
      
      store(stack, st, (val[0]<<8)|val[1]);
    }
  else
    {
      /* Game stack */
      store(stack, st, pop(stack));
    }
}

inline void zcode_op_set_cursor_6(ZStack* stack,
				  ZArgblock* args)
{
  if (args->n_args == 3)
    {
      int owin;

      owin = display_get_window();
      display_set_window(args->arg[2]);
      display_set_gcursor(args->arg[0] - windows[args->arg[2]].leftmar,
			  args->arg[1]);
      display_set_window(owin);
    }
  else
    {
      display_set_gcursor(args->arg[0], args->arg[1]);
    }
}

static inline void zcode_setup_window(int window)
{
  display_set_window(window);
  display_window_define(window,
			windows[window].x+windows[window].leftmar,
			windows[window].y,
			windows[window].xsize-windows[window].leftmar-windows[window].rightmar,
			windows[window].ysize);
  display_set_scroll(windows[window].scrolling);
  stream_buffering(windows[window].buffering);
}

inline void zcode_op_set_window_6(ZStack* stack, ZArgblock* args)
{
  stream_flush_buffer();

  zcode_setup_window(args->arg[0]);
}

inline void zcode_op_output_stream_6(ZStack* stack, ZArgblock* args)
{
  zcode_op_output_stream_4578(stack, args);
}

inline void zcode_op_draw_picture_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 draw_picture not implemented"); }

inline void zcode_op_picture_data_6(ZDWord* pc,
				    ZStack* stack,
				    ZArgblock* args,
				    int branch)
{
  ZByte* d;
  ZUWord width, height;

  d = Address((ZUWord)args->arg[1]);

  width = pix_width((ZUWord)args->arg[0]);
  height = pix_height((ZUWord)args->arg[0]);

  d[0] = height>>8;
  d[1] = height;
  d[2] = width>>8;
  d[3] = width;
}

inline void zcode_op_picture_datan_6(ZDWord* pc, ZStack* stack,
				    ZArgblock* args, int branch)
{
  zmachine_warning("v6 picture_datan not implemented");
  dobranch;
}

inline void zcode_op_set_colourm_6(ZStack* stack,
				   ZArgblock* args)
{
  int win, working;

  working = display_get_window();
  if (args->n_args > 2)
    {
      win = display_get_window();
      display_set_window(args->arg[2]);
      working = args->arg[2];
    }
  
  display_set_colour(convert_colour(args->arg[0]),
		     convert_colour(args->arg[1]));
  windows[working].colour = args->arg[0]|(args->arg[1]<<8);
  
  if (args->n_args > 2)
    {
      display_set_window(win);
    }
}

inline void zcode_op_set_colour_6(ZStack* stack,
				  int omit,
				  ZWord arg1,
				  ZWord arg2)
{
  ZArgblock args;

  args.n_args = 2;
  args.arg[0] = arg1;
  args.arg[1] = arg2;
  zcode_op_set_colourm_6(stack, &args);
}

inline void zcode_op_erase_picture_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 erase_picture not implemented"); }

inline void zcode_op_set_margins_6(ZStack* stack, ZArgblock* args)
{
  if (args->n_args < 3)
    args->arg[2] = display_get_window();
  windows[args->arg[2]].leftmar  = args->arg[0];
  windows[args->arg[2]].rightmar = args->arg[1];

  printf("Margins of window %i set to %i, %i\n", args->arg[2], args->arg[0], args->arg[1]);
  
  {
    int win, yp;
    win = display_get_window();
    display_set_window(args->arg[2]);
    yp = display_get_gcur_y();
    
    zcode_setup_window(args->arg[2]);
    display_set_gcursor(1, yp);
    display_set_window(win);
  }
}

inline void zcode_op_move_window_6(ZStack* stack, ZArgblock* args)
{
  windows[args->arg[0]].x = args->arg[2];
  windows[args->arg[0]].y = args->arg[1];
  windows[args->arg[0]].leftmar = 0;
  windows[args->arg[0]].rightmar = 0;
  
  {
    int win;
    win = display_get_window();
    zcode_setup_window(args->arg[0]);
    display_set_window(win);
  }
}

inline void zcode_op_window_size_6(ZStack* stack, ZArgblock* args)
{
  windows[args->arg[0]].xsize = args->arg[2];
  windows[args->arg[0]].ysize = args->arg[1];
  windows[args->arg[0]].leftmar = 0;
  windows[args->arg[0]].rightmar = 0;

  {
    int win;
    win = display_get_window();
    zcode_setup_window(args->arg[0]);
    display_set_window(win);
  }
}

#define StyleSet(x, y) switch (args->arg[2]) { case 0: x = (y)!=0; \
   break; case 1: if ((y)!=0) x=1; break; case 2: if ((y)==0) x=0; break; \
   case 3: x ^= (y)!=0; }
inline void zcode_op_window_style_6(ZStack* stack, ZArgblock* args)
{
  StyleSet(windows[args->arg[0]].wrapping,   args->arg[1]&1);
  StyleSet(windows[args->arg[0]].scrolling,  args->arg[1]&2);
  StyleSet(windows[args->arg[0]].transcript, args->arg[1]&4);
  StyleSet(windows[args->arg[0]].buffering,  args->arg[1]&8);
}

inline void zcode_op_get_wind_prop_6(ZStack* stack,
				     ZArgblock* args,
				     int st)
{
  int win;

  win = display_get_window();
  display_set_window(args->arg[0]);
  switch(args->arg[1])
    {
    case 0:
      store(stack, st, windows[args->arg[0]].y);
      break;
    case 1:
      store(stack, st, windows[args->arg[0]].x);
      break;
    case 2:
      store(stack, st, windows[args->arg[0]].ysize);
      break;
    case 3:
      store(stack, st, windows[args->arg[0]].xsize);
      break;
    case 4:
      store(stack, st, display_get_gcur_x());
      break;
    case 5:
      store(stack, st, display_get_gcur_y());
      break;
    case 6:
      store(stack, st, windows[args->arg[0]].leftmar);
      break;
    case 7:
      store(stack, st, windows[args->arg[0]].rightmar);
      break;
    case 8:
      store(stack, st, windows[args->arg[0]].newline_routine);
      break;
    case 9:
      store(stack, st, windows[args->arg[0]].countdown);
      break;
    case 10:
      store(stack, st, windows[args->arg[0]].style);
      break;
    case 11:
      store(stack, st, windows[args->arg[0]].colour);
      break;
    case 12:
      store(stack, st, windows[args->arg[0]].font_num);
      break;
    case 13:
      store(stack, st, windows[args->arg[0]].font_size);
      break;
    case 14:
      store(stack, st,
	    windows[args->arg[0]].wrapping|
	    (windows[args->arg[0]].scrolling<<1)|
	    (windows[args->arg[0]].transcript<<2)|
	    (windows[args->arg[0]].buffering<<3));
      break;
    case 15:
      store(stack, st,
	    windows[args->arg[0]].line_count);
      break;

    default:
      zmachine_fatal("Attempt to access out of range window property %i", args->arg[1]);
   }
  display_set_window(win);
}

inline void zcode_op_scroll_window_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 scroll_window not implemented"); }

inline void zcode_op_pop_stack_6(ZStack* stack,
				 ZArgblock* args)
{
  if (args->arg[1] == 0)
    {
      int x;

      for (x=0; x<(ZUWord) args->arg[0]; x++)
	pop(stack);
    }
  else
    {
      ZByte* s;
      ZUWord len;

      s = Address(args->arg[1]);
      len = (s[0]<<8)|s[1];
      len += args->arg[0];
      s[0] = len>>8;
      s[1] = len;
    }
}

inline void zcode_op_read_mouse_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 read_mouse not implemented"); }
inline void zcode_op_mouse_window_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 mouse_window not implemented"); }

static inline int zcode_v6_push_stack(ZStack* stack,
				      ZUWord  stk,
				      ZUWord  value)
{
  ZByte* s;
  ZByte* val;
  ZUWord len;
  
  if (stk == 0)
    {
      push(stack, value);
      return 1;
    }

  s = Address(stk);
  len = (s[0]<<8)|s[1];

  if (len <= 1)
    return 0;

  val = s + (len*2);
  val[0] = value>>8;
  val[1] = value;
  
  len--;
  s[0] = len>>8;
  s[1] = len;

  return 1;
}

inline void zcode_op_push_stack_6(ZDWord* pc,
				  ZStack* stack,
				  ZArgblock* args,
				  int branch)
{
  if (zcode_v6_push_stack(stack, args->arg[1], args->arg[0]))
    {
      dobranch;
    }
}

inline void zcode_op_push_stackn_6(ZDWord* pc,
				   ZStack* stack,
				   ZArgblock* args,
				   int branch)
{
  if (!zcode_v6_push_stack(stack, args->arg[1], args->arg[0]))
    {
      dobranch;
    }
}

inline void zcode_op_put_wind_prop_6(ZStack* stack,
				     ZArgblock* args)
{
  int win;

  win = display_get_window();
  display_set_window(args->arg[0]);
  switch(args->arg[1])
    {
    case 0:
      zmachine_warning("Bad put_wind_prop: should use move_window instead");
      windows[args->arg[0]].y = args->arg[2];
      break;
    case 1:
      zmachine_warning("Bad put_wind_prop: should use move_window instead");
      windows[args->arg[0]].x = args->arg[2];
      break;
    case 2:
      zmachine_warning("Bad put_wind_prop: should use window_size instead");
      windows[args->arg[0]].ysize = args->arg[2];
      break;
    case 3:
      zmachine_warning("Bad put_wind_prop: should use window_size instead");
      windows[args->arg[0]].xsize = args->arg[2];
      break;
    case 4:
      zmachine_warning("Bad put_wind_prop: should use set_cursor instead");
      display_set_gcursor(display_get_gcur_x(), args->arg[2]);
      break;
    case 5:
      zmachine_warning("Bad put_wind_prop: should use set_cursor instead");
      display_set_gcursor(args->arg[2], display_get_gcur_y());
      break;
    case 6:
      windows[args->arg[0]].leftmar = args->arg[2];
      break;
    case 7:
      windows[args->arg[0]].rightmar = args->arg[2];
      break;
    case 8:
      windows[args->arg[0]].newline_routine = args->arg[2];
      break;
    case 9:
      windows[args->arg[0]].countdown = args->arg[2];
      break;
    case 10:
      zmachine_warning("Bad put_wind_prop: should use set_text_style instead");
      break;
    case 11:
      zmachine_warning("Bad put_wind_prop: should use set_colour instead");
      break;
    case 12:
      zmachine_warning("Bad put_wind_prop: should use set_font instead");
      break;
    case 13:
      zmachine_warning("Bad put_wind_prop: should use set_font instead");
      break;
    case 14:
      zmachine_warning("Bad put_wind_prop: should use window_style instead");
      break;
    case 15:
      windows[args->arg[0]].line_count = args->arg[2];
      break;

    default:
      zmachine_fatal("Attempt to access out of range window property %i", args->arg[1]);
   }
  display_set_window(win);
}

inline void zcode_op_print_form_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 print_form not implemented"); }
inline void zcode_op_make_menu_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 make_menu not implemented"); }
inline void zcode_op_make_menun_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 make_menun not implemented"); }
inline void zcode_op_picture_table_6(ZStack* stack, ZArgblock* args)
{ zmachine_warning("v6 picture_table not implemented"); }

#endif

/* Our own extensions */
static clock_t start_clock, end_clock;

inline void zcode_op_start_timer_45678(ZStack* stack, ZArgblock* args)
{
  start_clock = clock();
}

inline void zcode_op_stop_timer_45678(ZStack* stack, ZArgblock* args)
{
  end_clock = clock();
}

inline void zcode_op_read_timer_45678(ZStack* stack, ZArgblock* args, int st)
{
  clock_t now;

  now = end_clock - start_clock;

  store(stack, st, (ZUWord) (now*100)/CLOCKS_PER_SEC);
}

inline void zcode_op_print_timer_45678(ZStack* stack, ZArgblock* args)
{
  clock_t now;
  
  now = end_clock - start_clock;

  stream_printf("%i.%i secs", (signed int) (now/CLOCKS_PER_SEC),
		(signed int) ((now*100)/CLOCKS_PER_SEC)%100);
}

#endif
