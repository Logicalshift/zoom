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
 * Deal with files
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#include "file.h"

ZFile* open_file(char*  filename)
{
  ZFile* res;

  res = malloc(sizeof(ZFile));
  res->handle = fopen(filename, "r");

  if (res->handle == NULL)
    {
      free(res);
      return NULL;
    }

  return res;
}

ZFile* open_file_write(char*  filename)
{
  ZFile* res;

  res = malloc(sizeof(ZFile));
  res->handle = fopen(filename, "w");

  if (res->handle == NULL)
    {
      free(res);
      return NULL;
    }

  return res;
}

void   close_file(ZFile* file)
{
  fclose(file->handle);
  free(file);
}

ZByte* read_page(ZFile* file, int page_no)
{
  ZByte* page;

  page = malloc(4096);
  if (page == NULL)
    return NULL;
  
  fseek(file->handle, 4096*page_no, SEEK_SET);
  fread(page, 4096, 1, file->handle);

  return page;
}

ZByte* read_block(ZFile* file, int start_pos, int end_pos)
{
  ZByte* block;

  block = malloc(end_pos-start_pos);
  if (block == NULL)
    return NULL;

  fseek(file->handle, start_pos, SEEK_SET);
  fread(block, end_pos-start_pos, 1, file->handle);

  return block;
}

ZByte inline read_byte(ZFile* file)
{
  return fgetc(file->handle);
}

ZUWord read_word(ZFile* file)
{
  return (read_byte(file)<<8)|read_byte(file);
}

ZUWord read_rword(ZFile* file)
{
  return read_byte(file)|(read_byte(file)<<8);
}
void read_block2(ZByte* block, ZFile* file, int start_pos, int end_pos)
{
  fseek(file->handle, start_pos, SEEK_SET);
  fread(block, end_pos-start_pos, 1, file->handle);
}

ZDWord get_file_size(char* filename)
{
  struct stat buf;
  
  if (stat(filename, &buf) != 0)
    {
      return -1;
    }

  return buf.st_size;
}

void write_block(ZFile* file, ZByte* block, int length)
{
  fwrite(block, 1, length, file->handle);
}

inline void write_byte(ZFile* file, ZByte byte)
{
  fputc(byte, file->handle);
}

void write_word(ZFile* file, ZWord word)
{
  write_byte(file, word>>8);
  write_byte(file, word);
}

void write_dword(ZFile* file, ZDWord word)
{
  write_byte(file, word>>24);
  write_byte(file, word>>16);
  write_byte(file, word>>8);
  write_byte(file, word);
}
