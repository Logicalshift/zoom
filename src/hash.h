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
 * Hash table
 */

#ifndef __HASH_TABLE
#define __HASH_TABLE

typedef struct hash
{
  int n_buckets;
  int unhappy;
  
  void **bucket;
} *hash;

extern hash  hash_create     (void);
extern void  hash_store      (hash  hash,
			      unsigned char *key,
			      int   keylen,
			      void *data);
extern void  hash_store_happy(hash  hash,
			      unsigned char *key,
			      int   keylen,
			      void *data);
extern void  hash_free       (hash hash);
extern void  hash_iterate    (hash hash,
			      int (*func)(unsigned char *key,
					  int   keylen,
					  void *data,
					  void *arg),
			      void *arg);
extern void *hash_get        (hash  hash,
			      unsigned char *key,
			      int   keylen);
extern void  hash_resize     (hash hash,
			      int  n_buckets);

#endif
