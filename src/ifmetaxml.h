/*
 *  ifmetaxml.h
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 04/04/2006.
 *  Copyright 2006 Andrew Hunter. All rights reserved.
 *
 */

#ifndef __IFMETAXML_H
#define __IFMETAXML_H

/*
 * Importer for iFiction XML files.
 */

#include <stdlib.h>
#include "ifmetabase.h"

/* Possible error codes */
typedef enum IFXmlError {
	IFXmlNotIfiction,
	IFXmlNoVersionSupplied,
	IFXmlVersionIsTooRecent,
	
	IFXmlMismatchedTags,
	IFXmlUnrecognisedTag
} IFXmlError;

/* Load the records contained in the specified */
extern void IF_ReadIfiction(IFMetabase meta, const unsigned char* xml, size_t size);

#endif
