/*
 *  ifmetabase.c
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 14/03/2005
 *  Copyright 2005 Andrew Hunter. All rights reserved.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ifmetabase.h"
#include "ifmetabase-internal.h"

/* Functions - general metabase manipulation */

/* Constructs a new, empty metabase */
extern IFMetabase IFMB_Create();

/* Frees up all the memory associated with a metabase */
extern void IFMB_Free(IFMetabase meta);

/* Functions - IFIDs */

/* Takes an ID string and produces a corresponding IFID structure, or NULL if the string is invalid */
extern IFID IFMB_IdFromString(const char* idString);

/* Returns an IFID based on the 16-byte UUID passed as an argument */
IFID IFMB_UUID(const char* uuid) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_UUID;
	
	memcpy(result->data.uuid, uuid, 16);
	
	return result;
}

/* Returns an IFID based on a Z-Code legacy identifier */
IFID IFMB_ZcodeId(int release, const char* serial, int checksum) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_ZCODE;
	
	result->data.zcode.release = release;
	memcpy(result->data.zcode.serial, serial, 6);
	result->data.zcode.checksum = checksum;
	
	return result;
}

/* Merges a set of IFIDs into a single ID */
extern IFID IFMB_CompoundId(int count, IFID identifiers);

/* Compares two IDs */
int IFMB_CompareIds(IFID a, IFID b) {
	int x;
	
	/* Compare ID types */
	if (a->type > b->type) return 1;
	if (a->type < b->type) return -1;
	
	/* Compare based on what the ID is */
	switch (a->type /* == b->type */) {
		case ID_UUID:
			for (x=0; x<16; x++) {
				if (a->data.uuid[x] > b->data.uuid[x]) return 1;
				if (a->data.uuid[x] < b->data.uuid[x]) return -1;
			}
			break;
			
		case ID_MD5:
			for (x=0; x<16; x++) {
				if (a->data.md5[x] > b->data.md5[x]) return 1;
				if (a->data.md5[x] < b->data.md5[x]) return -1;
			}
			break;
			
		case ID_ZCODE:
			if (a->data.zcode.checksum > b->data.zcode.checksum) return 1;
			if (a->data.zcode.checksum < b->data.zcode.checksum) return -1;
			
			if (a->data.zcode.release > b->data.zcode.release) return 1;
			if (b->data.zcode.release < b->data.zcode.release) return -1;
				
			for (x=0; x<6; x++) {
				if (a->data.zcode.serial[x] > b->data.zcode.serial[x]) return 1;
				if (a->data.zcode.serial[x] < b->data.zcode.serial[x]) return -1;
			}
			break;
			
		case ID_COMPOUND:
			if (a->data.compound.count > b->data.compound.count) return 1;
			if (b->data.compound.count < b->data.compound.count) return -1;
			
			for (x=0; x<a->data.compound.count; x++) {
				int comparison;
				
				comparison = IFMB_CompareIds(a->data.compound.ids[x], b->data.compound.ids[x]);
				if (comparison != 0) return comparison;
			}
			break;
			
		default:
			fprintf(stderr, "ifmetabase - warning: IFMB_CompareIds was passed an ID it does not understand");
	}
	
	/* No further distinguishing marks: return 0 */
	return 0;
}

/* Frees an ID */
void IFMB_FreeId(IFID ident) {
	free(ident);
}

/* Copies an ID */
IFID IFMB_CopyId(IFID ident) {
	IFID result = malloc(sizeof(struct IFID));
	
	*result = *ident;
	
	return result;
}

/* Functions - stories */

/* Retrieves the story in the metabase with the given ID */
extern IFStory IFMB_GetStoryWithId(IFMetabase meta, IFID ident);

/* Retrieves the ID associated with a given story object */
extern IFID IFMB_IdForStory(IFStory story);

/* Removes a story with the given ID from the metabase */
extern IFID IFMB_RemoveStoryWithId(IFID ident);

/* Returns non-zero if the metabase contains a story with a given ID */
extern int IFMB_ContainsStoryWithId(IFID ident);

/* Returns a UTF-16 string for a given parameter in a story, or NULL if none was found */
/* Copy this value away if you intend to retain it: it may be destroyed on the next IFMB_ call */
extern IFChar* IFMB_GetValue(IFStory story, const char* valueKey);

/* Sets the UTF-16 string for a given parameter in the story (NULL to unset the parameter) */
extern void IFMB_SetValue(IFStory story, const char* valueKey, IFChar* utf16value);

/* Functions - iterating */

/* Gets an iterator covering all the stories in the given metabase */
extern IFStoryIterator IFMB_GetStoryIterator(IFMetabase meta);

/* Gets an iterator covering all the values set in a story */
extern IFValueIterator IFMB_GetValueIterator(IFStory story);

/* Gets the next story defined in the metabase */
extern IFStory IFMB_NextStory(IFStoryIterator iter);

/* Gets the next value set in a story */
extern char* IFMB_NextValue(IFValueIterator iter);

/* Functions - basic UTF-16 string manipulation */

extern int IFMB_StrCmp(const IFChar* a, const IFChar* b);
extern void IFMB_StrCpy(IFChar* a, const IFChar* b);
