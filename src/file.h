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

#ifndef __FILE_H
#define __FILE_H

#include "ztypes.h"

typedef struct ZFile ZFile;

extern ZFile* open_file      (char*  filename);
extern ZFile* open_file_write(char* filename);
extern void   close_file     (ZFile* file);
extern ZByte  read_byte      (ZFile* file);
extern ZUWord read_word      (ZFile* file);
extern ZUWord read_rword     (ZFile* file);
extern ZByte* read_page      (ZFile* file, int page_no);
extern ZByte* read_block     (ZFile* file, int start_pos, int end_pos);
extern void   read_block2    (ZByte*, ZFile*, int start_pos, int end_pos);
extern void   write_block    (ZFile* file, ZByte* block, int length);
extern void   write_byte     (ZFile* file, ZByte byte);
extern void   write_word     (ZFile* file, ZWord word);
extern void   write_dword    (ZFile* file, ZDWord word);
extern ZDWord get_file_size  (char* filename);

#endif
