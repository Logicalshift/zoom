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

#ifndef __STREAM_H
#define __STREAM_H

extern void stream_prints       (const unsigned char* s);
extern void stream_printf       (const char* f, ...);
extern void stream_printc       (int c);
extern void stream_input        (const char* s);
extern int  stream_readline     (char* buf, int len, long int timeout);
extern void stream_buffering    (int buffer);
extern void stream_flush_buffer (void);
extern void stream_remove_buffer(const char* s);

#endif
