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

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#include "file.h"
#include "zmachine.h"

#if WINDOW_SYSTEM != 2

struct ZFile
{
  FILE* handle;
};

ZFile* open_file(char* filename)
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

ZFile* open_file_write(char* filename)
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
  size_t rd;
  
  block = malloc(end_pos-start_pos);
  if (block == NULL)
    return NULL;

  if (fseek(file->handle, start_pos, SEEK_SET))
    zmachine_fatal("Failed to seek to position %i", start_pos);
  rd = fread(block, 1, end_pos-start_pos, file->handle);
  if (rd != end_pos-start_pos)
    zmachine_fatal("Tried to read %i items of 1 byte, got %i items",
		   end_pos-start_pos, rd);

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

#endif

#if WINDOW_SYSTEM == 2

#include <windows.h>

struct ZFile
{
  HANDLE file;
};

ZFile* open_file(char* filename)
{
  ZFile* f;

  f = malloc(sizeof(ZFile));

  f->file = CreateFile(filename,
		       GENERIC_READ,
		       FILE_SHARE_READ,
		       NULL,
		       OPEN_EXISTING,
		       FILE_ATTRIBUTE_NORMAL,
		       NULL);

  if (f->file == INVALID_HANDLE_VALUE)
    {
      zmachine_fatal("Unable to open %s", filename);
      free(f);
      return NULL;
    }

  return f;
}

ZFile* open_file_write(char* filename)
{
  ZFile* f;

  f = malloc(sizeof(ZFile));

  f->file = CreateFile(filename,
		       GENERIC_READ|GENERIC_WRITE,
		       FILE_SHARE_READ|FILE_SHARE_WRITE,
		       NULL,
		       CREATE_ALWAYS,
		       FILE_ATTRIBUTE_NORMAL,
		       NULL);

  if (f->file == INVALID_HANDLE_VALUE)
    {
      free(f);
      return NULL;
    }

  return f;
}

void close_file(ZFile* file)
{
  CloseHandle(file->file);
  free(file);
}

ZByte read_byte(ZFile* file)
{
  ZByte block[1];
  DWORD nread;

  if (!ReadFile(file->file, block, 1, &nread, NULL))
    zmachine_fatal("Unable to read byte from file");
  return block[0];
}

ZUWord read_word(ZFile* file)
{
  return (read_byte(file)<<8)|read_byte(file);
}

ZUWord read_rword(ZFile* file)
{
  return read_byte(file)|(read_byte(file)<<8);
}

ZByte* read_block(ZFile* file,
		  int start_pos,
		  int end_pos)
{
  ZByte* block;
  DWORD  nread;

  block = malloc(sizeof(ZByte)*(end_pos-start_pos));

  if (SetFilePointer(file->file, start_pos, NULL, FILE_BEGIN) == -1)
    {
      zmachine_fatal("Unable to seek to %i", start_pos);
      free(block);
      return NULL;
    }
  if (!ReadFile(file->file, block, end_pos-start_pos, &nread, NULL))
    {
      zmachine_fatal("Unable to read %i bytes", end_pos-start_pos);
      free(block);
      return NULL;
    }

  if (nread != end_pos-start_pos)
    {
      zmachine_fatal("Tried to read %i bytes, but only got %i",
		     end_pos-start_pos, nread);
      free(block);
      return NULL;
    }

  return block;
}

void read_block2(ZByte* block,
		 ZFile* file,
		 int start_pos,
		 int end_pos)
{
  DWORD  nread;

  if (SetFilePointer(file->file, start_pos, NULL, FILE_BEGIN) == -1)
    zmachine_fatal("Unable to seek");
  if (!ReadFile(file->file, block, end_pos-start_pos, &nread, NULL))
    zmachine_fatal("Unable to read file");

  if (nread != end_pos-start_pos)
    zmachine_fatal("Tried to read %i bytes, but only got %i",
		   end_pos-start_pos, nread);
}

void write_block(ZFile* file, ZByte* block, int length)
{
  DWORD nwrite;
  
  WriteFile(file->file, block, length, &nwrite, NULL);
}

void write_byte(ZFile* file, ZByte byte)
{
  write_block(file, &byte, 1);
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

ZDWord get_file_size(char* filename)
{
  HANDLE hnd;
  ZDWord sz;

  hnd = CreateFile(filename,
		   GENERIC_READ,
		   FILE_SHARE_READ,
		   NULL,
		   OPEN_EXISTING,
		   FILE_ATTRIBUTE_NORMAL,
		   NULL);

  if (hnd == INVALID_HANDLE_VALUE)
    return -1;

  sz = GetFileSize(hnd, NULL);
  
  CloseHandle(hnd);
  
  return sz;
}

#endif
