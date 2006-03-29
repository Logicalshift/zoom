/*
 *  ifmetabase-internal.h
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 16/03/2006.
 *  Copyright 2006 Andrew Hunter. All rights reserved.
 *
 */

/*
 * Internal structure definitions for the metabase
 */

#ifndef __IFMETABASE_INTERNAL_H
#define __IFMETABASE_INTERNAL_H

#include "ifmetabase.h"

/* The IFMetabase structure */

struct IFMetabase {
};

/* The IFStory structure */

struct IFStory {
};

/* IFID structure */

struct IFID {
	enum {
		ID_UUID,
		ID_ZCODE,
		ID_MD5,
		ID_COMPOUND
	} type;
	
	union {
		char uuid[16];
		char md5[16];
		
		struct {
			int release;
			char serial[6];
			int checksum;
		} zcode;
		
		struct {
			int count;
			IFID* ids;
		} compound;
	} data;
};

/*  */

#endif
