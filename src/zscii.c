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
 * Convert ZSCII strings to ASCII
 */

#include <stdlib.h>

#include "zmachine.h"
#include "zscii.h"

static unsigned char *buf  = NULL;
static unsigned char *buf2 = NULL;
static int maxlen = 0;

static unsigned int alpha_a[32] =
{
  0,0,0,0,0,0,
   97, 98, 99,100,101,102,103,104,105,106,107,108,109,
  110,111,112,113,114,115,116,117,118,119,120,121,122
};
static unsigned int alpha_b[32] =
{
  0,0,0,0,0,0,
  65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77,
  78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90
};
static unsigned int alpha_c[32] =
{
  0,0,0,0,0,0,
   0, 10, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 46,
  44, 33, 63, 95, 35, 39, 34, 47, 92, 45, 58, 40, 41
};
static unsigned int* convert_table[3] = { alpha_a, alpha_b, alpha_c };

static unsigned int** convert = convert_table;

/*
 * Convert a ZSCII string (packed) to ASCII (unpacked)
 */
char* zscii_to_ascii(ZByte* string, int* len)
{
  int abet = 0;
  int x = 0;
  int y = 0;
  int pos = 0;
  int zlen;
  ZWord zchar = 0;

  zlen = zstrlen(string);
  if (zlen > maxlen)
    {
      maxlen = zlen;
      buf = realloc(buf, zlen+1);
      buf2 = realloc(buf2, zlen+1);
    }
  
  /* Get out the Z-Characters */
  while ((string[x]&0x80) == 0)
    {
      buf2[pos++] = (string[x]&0x7c)>>2;
      buf2[pos++] = ((string[x]&0x03)<<3)|((string[x+1]&0xe0)>>5);
      buf2[pos++] = string[++x]&0x1f;

      x++;
    }
  buf2[pos++] = (string[x]&0x7c)>>2;
  buf2[pos++] = ((string[x]&0x03)<<3)|((string[x+1]&0xe0)>>5);
  buf2[pos++] = string[x+1]&0x1f;
  *len = x+2;

  y = 0;
  for (x=0; x<pos; x++)
    {
      switch (abet)
	{
	  /* Standard alphabets */
	case 2:
	  if (buf2[x] == 6)
	    {
	      /* Next 2 chars make up a Z-Character */
	      abet=4;
	      break;
	    }
	case 1:
	case 0:
	  if (buf2[x] >= 6)
	    {
	      buf[y++] = convert[abet][buf2[x]];
	      abet=0;
	    }
	  else
	    {
	      switch (buf2[x])
		{
		case 0: /* Space */
		  buf[y++] = ' ';
		  break;
		  
		case 1: /* Next char is an abbreviation */
		case 2:
		case 3:
		  zchar=(buf2[x]-1)<<5;
		  abet=3;
		  break;
		  
		case 4: /* Shift to alphabet 1 */
		  abet=1;
		  break;
		case 5: /* Shift to alphabet 2 */
		  abet=2;
		  break;
		default:
		  /* Ignore */
		  break;
		}
	    }
	  break;

	case 3: /* Abbreviation */
	  {
	    int z;
	    char* abbrev;
	    int addr;
	    ZByte* table;

	    zchar |= buf2[x];
	    
	    /* 
	     * Annoyingly, some games seem to rewrite the abbreviation
	     * table at runtime. This may cause weird things to happen
	     * if a game is sick enough to use abbreviations in
	     * abbreviations, too.
	     */
	    table = machine.memory + GetWord(machine.header, ZH_abbrevs);
	    addr = ((table[zchar*2]<<9)|(table[zchar*2+1]<<1));

	    if (machine.abbrev_addr[zchar] != addr)
	      {
		/* 
		 * Hack, this function was never designed to be called
		 * recursively
		 */
		char* oldbuf, *oldbuf2;
		int oldmaxlen;
		int ablen;

		oldbuf = buf; oldbuf2 = buf2;
		oldmaxlen = maxlen;
		maxlen = 0;
		buf = buf2 = NULL;
		
		abbrev = zscii_to_ascii(machine.memory +
					addr,
					&ablen);
		
		free(buf2);
		buf = oldbuf;
		buf2 = oldbuf2;
		maxlen = oldmaxlen;
		
		for (z=0; abbrev[z] != 0; z++)
		  {
		    buf[y++] = abbrev[z];
		  }
		
		free(abbrev);
	      }
	    else
	      {
		abbrev = machine.abbrev[zchar];
		for (z=0; abbrev[z] != 0; z++)
		  {
		    buf[y++] = abbrev[z];
		  }
	      }
	  }
	    
	  abet = 0;
	  break;

	case 4: /* First byte of a Z-Char */
	  zchar = buf2[x]<<5;
	  abet = 5;
	  break;

	case 5: /* Second byte of a Z-Char */
	  zchar |= buf2[x];

	  switch(zchar)
	    {
	    default:
	      buf[y++] = zchar;
	    }
	  abet = 0;
	  break;
	}
    }
  
  buf[y] = 0;
  
  return buf;
}

/*
 * Pack a ZSCII string, suitable for comparing to a dictionary item
 *
 * A packlen of 6 gives us v3 format, and 9 gives us v5
 */
static unsigned char zscii_table[256] =
{
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 8 */
  0x00,0xc7,0x00,0x00, 0x00,0x00,0x00,0x00, /* 16 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 24 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 32 */
  0x00,0xd4,0xd9,0xd7, 0x00,0x00,0x00,0xd8, /* 40 */
  0xde,0xdf,0x00,0x00, 0xd3,0xdc,0xd2,0xda, /* 48 */
  0xc8,0xc9,0xca,0xcb, 0xcc,0xcd,0xce,0xcf, /* 56 */
  0xd0,0xd1,0x00,0xdd, 0x00,0x00,0x00,0xd5, /* 64 */
  0x00,0x86,0x87,0x88, 0x89,0x8a,0x8b,0x8c, /* 72 */
  0x8d,0x8e,0x8f,0x90, 0x91,0x92,0x93,0x94, /* 80 */
  0x95,0x96,0x97,0x98, 0x99,0x9a,0x9b,0x9c, /* 88 */
  0x9d,0x9e,0x9f,0x00, 0xdb,0x00,0x00,0xd6, /* 96 */
  0x00,0x46,0x47,0x48, 0x49,0x4a,0x4b,0x4c, /* 104 */
  0x4d,0x4e,0x4f,0x50, 0x51,0x52,0x53,0x54, /* 112 */
  0x55,0x56,0x57,0x58, 0x59,0x5a,0x5b,0x5c, /* 120 */
  0x5d,0x5e,0x5f,0x00, 0x00,0x00,0x00,0x00, /* 128 */

  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 8 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 16 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 24 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 32 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 40 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 48 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 56 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 64 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 72 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 80 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 88 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 96 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 104 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 112 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, /* 120 */
  0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00  /* 128 */
};

static unsigned char* zscii = zscii_table;

void pack_zscii(ZByte* string, int strlen, ZByte* packed, int packlen)
{
  int  x;
  int  strpos;
  int  wordlen;
  char zchr[40];

  strpos = 0;

  for (x=0; x<packlen; x++)
    {
      if (strpos >= strlen)
	zchr[x] = 5;
      else if (zscii[string[strpos]] != 0)
	{
	  int alphabet, chr;

	  alphabet = zscii[string[strpos]]>>6;
	  chr      = zscii[string[strpos]]&0x1f;

	  switch (alphabet)
	    {
	    case 2:
	      zchr[x] = 4;
	      x++;
	      break;
	      
	    case 3:
	      zchr[x] = 5;
	      x++;
	      break;
	    }

	  zchr[x] = chr;
	}
      else
	{
	  zchr[x++] = 5;
	  zchr[x++] = 6;
	  zchr[x++] = string[strpos]>>5;
	  zchr[x]   = string[strpos]&0x1f;
	}

      strpos++;
    }

  wordlen = packlen/3;
  for (x=0; x<wordlen; x++)
    {
      packed[x<<1] = (zchr[x*3]<<2)|(zchr[x*3+1]>>3);
      packed[(x<<1)+1] = (zchr[x*3+1]<<5)|zchr[x*3+2];
    }
  packed[wordlen*2-2] |= 0x80;
}

/*
 * Works out the length (in bytes) of a packed Z-string
 */
int zstrlen(ZByte* string)
{
  int x = 0;

  while ((string[x]&0x80) == 0)
    x+=2;

  return x*3+3;
}

/*
 * Installs the alphabet table associated with the currently loaded story
 */
void zscii_install_alphabet(void)
{
  if (ReadByte(0)>=5)
    {
      ZUWord table;

      table = Word(ZH_alphatable);
      if (table)
	{
	  static unsigned int** conv = NULL;
	  static unsigned char* zsc = NULL;
	  ZByte* alpha;
	  int x, y;

	  alpha = Address(table);

	  if (conv == NULL)
	    {
	      conv = malloc(sizeof(int*)*3);
	      for (x=0; x<3; x++)
		conv[x] = malloc(sizeof(int)*32);
	    }
	  
	  zsc = realloc(zsc, sizeof(char)*256);
	  for (x=0; x<256; x++)
	    zsc[x] = 0;
	  
	  for (y=0; y<3; y++)
	    {
	      for (x=0; x<6; x++)
		conv[y][x] = 0;
	      
	      for (x=0; x<26; x++)
		{
		  conv[y][x+6]      = *(alpha++);
		  if (y != 2 || x>2)
		    zsc[conv[y][x+6]] = (x+6)|(y<<6);
		}
	    }

	  conv[2][7] = 10;
	  conv[2][6] = 32;
	  
	  convert = conv;
	  zscii = zsc;
	}
      else
	{
	  convert = convert_table;
	  zscii = zscii_table;
	}
    }
  else
    {
      convert = convert_table;
      zscii = zscii_table;
    }
}
