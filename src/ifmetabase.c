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
#include <ctype.h>

#include "ifmetabase.h"
#include "ifmetabase-internal.h"

/* Functions - general metabase manipulation */

static void FreeValue(IFValue value) {
	int x;
	
	for (x=0; x<value->childCount; x++) {
		FreeValue(value->children[x]);
	}
	
	if (value->children != NULL) free(value->children);
	if (value->value != NULL) free(value->value);
	if (value->key != NULL) free(value->key);
}

static void FreeStory(IFStory story) {
	FreeValue(story->root);
	IFMB_FreeId(story->id);
	free(story);
}

/* Constructs a new, empty metabase */
IFMetabase IFMB_Create() {
	IFMetabase result = malloc(sizeof(struct IFMetabase));
	
	result->numStories = 0;
	result->numIndexEntries = 0;
	result->stories = NULL;
	result->index = NULL;
	
	return result;
}

/* Frees up all the memory associated with a metabase */
void IFMB_Free(IFMetabase meta) {
	int x;
	
	for (x=0; x<meta->numStories; x++) {
		FreeStory(meta->stories[x]);
	}
	
	if (meta->index != NULL) free(meta->index);
	if (meta->stories != NULL) free(meta->stories);
	free(meta);
}

/* Functions - IFIDs */

/* Retrieves the hexidecimal value of c */
static int hex(char c) {
	/* Various possible values for a hex number */
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	
	/* Not a hex value */
	return -1;
}

/* Retrieves the numeric value of a character */
static int num(char c) {
	if (c >= '0' && c <= '9') return c - '0';
	
	/* Not a numeric value */
	return -1;
}

/* Reads a positive number from val, putting the length in len */
static int number(const char* val, int* len) {
	int number = 0;
	int x;
	int valLen;
	
	for (x=0; val[x] != 0; x++) {
		int digitVal;
		
		digitVal = num(val[x]);
		if (digitVal < 0) break;
		
		number *= 10;
		number += digitVal;
	}
	
	*len = x;
	if (x == 0) return -1;
	
	return number;
}

/* Reads a positive hexadecimal from val, putting the length in len */
static unsigned int hexnumber(const char* val, int* len) {
	unsigned int number = 0;
	int x;
	int valLen;
	
	for (x=0; val[x] != 0; x++) {
		int digitVal;
		
		digitVal = hex(val[x]);
		if (digitVal < 0) break;
		
		number *= 16;
		number += digitVal;
	}
	
	*len = x;
	if (x == 0) return 0xffffffff;
	
	return number;
}

/* Returns if c is whitespace or not */
static int whitespace(char c) {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

/* Takes an ID string and produces a corresponding IFID structure, or NULL if the string is invalid */
IFID IFMB_IdFromString(const char* idString) {
	/* 
	 * IFIDs have the following possible forms: 
	 *
	 * UUID://1974A053-7DB0-4103-93A1-767C1382C0B7// (a uuid - GLULX/ZCODE, possibly others later?)
	 * ZCODE-11-271781 (zcode, release + serial)
	 * ZCODE-11------- (zcode, release no serial)
	 * ZCODE-11-278162-8267 (zcode, release + serial + checksum)
	 * GLULX-12359abc-263a6bf1 (glulx, memsize + checksum)
	 * GLULX-11-287367-27382917 (glulx, release + serial + checksum)
	 * TADS-78372173827931 (TADS, MD5 sum - treated identically to a MD5 sum)
	 * 67687abe6717cef (MD5 sum)
	 */
	
	int x;
	int idLen;
	char lowerPrefix[10];
	int isTads;
	int pos;
	unsigned char md5[16];
	
	/* Skip any initial whitespace */
	while (whitespace(*idString)) idString++;
	
	/* Convert the start of the string to lowercase */
	for (x=0; x<10 && idString[x] != 0; x++) {
		lowerPrefix[x] = tolower(idString[x]);
	}
	
	/* Record the length of the string */
	idLen = strlen(idString);
	
	/* Try to parse a UUID */
	if (idLen >= 39 && lowerPrefix[0] == 'u' && lowerPrefix[1] == 'u' && lowerPrefix[2] == 'i' && lowerPrefix[3] == 'd' && idString[4] == ':' && idString[5] == '/' && idString[6] == '/') {
		/* String begins with UUID://, characters 7 onwards make up the UUID itself, we're fairly casual about the parsing */
		unsigned char uuid[16];			/* The that we've retrieved */
		int uuidPos = 0;				/* The nibble that we're currently reading */
		int chrNum;
		
		/* Clear the UUID */
		for (chrNum=0; chrNum<16; chrNum++) uuid[chrNum] = 0;
		
		/* Iterate through the IFID string */
		for (chrNum=7; uuidPos < 32 && chrNum < idLen; chrNum++) {
			char uuidChar;
			int hexValue;
			
			uuidChar = idString[chrNum];
			
			/* '-' is permitted as a divided: for the purposes of parsing, we allow many or none of these, which allows us to parse some invalid UUIDs */
			if (uuidChar == '-') continue;
			
			/* Get and check the hexidecimal value of this character (not a valid IFID if this is not a hex value) */
			hexValue = hex(uuidChar);
			if (hexValue < -1) return NULL;
			
			/* Or it into the uuid value */
			uuid[uuidPos>>1] |= hexValue<<(4*(1-(uuidPos&1)));
			uuidPos++;
		}
		
		/* If we haven't got 32 nibbles, then this is not a UUID */
		if (uuidPos != 32) return NULL;
		
		/* Remaining characters must be '/' or whitespace only */
		for (; chrNum < idLen; chrNum++) {
			if (!whitespace(idString[chrNum]) && idString[chrNum] != '/') return NULL;
		}
		
		/* This is a UUID: return a suitable ID structure */
		return IFMB_UUID(uuid);
	}
	
	/* Try to parse a ZCODE IFID */
	if (idLen >= 14 && lowerPrefix[0] == 'z' && lowerPrefix[1] == 'c' && lowerPrefix[2] == 'o' && lowerPrefix[3] == 'd' && lowerPrefix[4] == 'e' && idString[5] == '-') {
		/* String begins with ZCODE- should be followed by a */
		int release = -1;
		char serial[6];
		unsigned int checksum = -1;
		int x, len, pos;
		
		/* Clear the serial number */
		for (x=0; x<6; x++) serial[x] = 0;
		
		/* Get the release number */
		release = number(idString + 6, &len);
		if (release < 0) return NULL;
		
		pos = 6+len;
		if (idString[pos] != '-') return NULL;
		pos++;
		
		/* Next 6 characters are the serial # */
		for (x=0; x<6; x++) {
			serial[x] = idString[pos++];
		}
		
		/* The checksum is optional (though highly recommended) */
		if (idString[pos] == '-') {
			pos++;
			
			checksum = hexnumber(idString + pos, &len);
			if (len == 0) return NULL;
			if (checksum > 0xffff) return NULL;
			
			pos += len;
		}
		
		/* The rest of the string should be just whitespace (if anything) */
		for (; pos < idLen; pos++) {
			if (!whitespace(idString[pos])) return NULL;
		}
		
		/* Return a Z-Code story ID */
		return IFMB_ZcodeId(release, serial, checksum);
	}
	
	/* GLULX IFIDs are much like zcode IDs, except the checksum is 32-bit */
	if (idLen >= 14 && lowerPrefix[0] == 'g' && lowerPrefix[1] == 'l' && lowerPrefix[2] == 'u' && lowerPrefix[3] == 'l' && lowerPrefix[4] == 'x' && idString[5] == '-') {
		/* String begins with ZCODE- should be followed by a */
		int release = -1;
		char serial[6];
		unsigned int checksum = -1;
		int x, len, pos;
		int numeric;
		int hexadecimal;
		
		/* Clear the serial number */
		for (x=0; x<6; x++) serial[x] = 0;
		
		/* Next few characters are either the release number, or a hexadecimal indication of initial memory map size */
		/* It is supposed that release numbers won't ever approach 8 characters in length */
		numeric = 1;
		hexadecimal = 1;
		for (x=6; idString[x] != '-' && idString[x] != 0; x++) {
			if (idString[x] < '0' || idString[x] > '9') numeric = 0;
			else if ((idString[x] < 'a' || idString[x] > 'f')  && (idString[x] < 'A' || idString[x] > 'F')) hexadecimal = 0;
		}
		
		if (x >= 14) {
			/* Format is GLULX-memsize-checksum */
			unsigned int memsize = -1;
			
			/* Starts with memory size */
			memsize = hexnumber(idString + 6, &len);
			if (len == 0) return NULL;
			
			/* This is followed by a checksum */
			pos = 6 + len;
			if (idString[pos] != '-') return NULL;
			
			pos++;
			checksum = hexnumber(idString + pos, &len);
			if (len == 0) return NULL;
			
			pos += len;
			
			/* The rest of the string should be just whitespace (if anything) */
			for (; pos < idLen; pos++) {
				if (!whitespace(idString[pos])) return NULL;
			}
			
			return IFMB_GlulxIdNotInform(memsize, checksum);
		} else {
			/* Format is GLULX-release-serial-checksum */

			/* Get the release number */
			release = number(idString + 6, &len);
			if (release < 0) return NULL;
			
			pos = 6+len;
			if (idString[pos] != '-') return NULL;
			pos++;
			
			/* Next 6 characters are the serial # */
			for (x=0; x<6; x++) {
				serial[x] = idString[pos++];
			}
			
			/* The checksum is mandatory for GLULX games */
			if (idString[pos] != '-') return NULL;
			
			pos++;
			
			checksum = hexnumber(idString + pos, &len);
			if (len == 0) return NULL;
			
			pos += len;
			
			/* The rest of the string should be just whitespace (if anything) */
			for (; pos < idLen; pos++) {
				if (!whitespace(idString[pos])) return NULL;
			}
			
			/* Return a GLULX story ID */
			return IFMB_GlulxId(release, serial, checksum);
		}
	}
	
	/* MD5sum identifiers are treated identically */
	pos = 0;
	
	/* Might be a TADS specifier */
	if (lowerPrefix[0] == 't' && lowerPrefix[1] == 'a' && lowerPrefix[2] == 'd' && lowerPrefix[3] == 's' && lowerPrefix[4] == '-') {
		pos += 5;
		isTads = 1;
	}
	
	/* Rest of the string should be an MD5 specifier (32 hexadecimal characters) */
	for (x=0; x<16; x++) md5[x] = 0;
	
	x = 0;
	for (; idString[pos] != 0 && !whitespace(idString[pos]); pos++) {
		int hexValue;
		
		hexValue = hex(idString[pos]);
		if (hexValue < 0) return NULL;
		
		if (x >= 32) break;
		md5[x>>1] |= hexValue<<(4*(1-(x&1)));

		x++;
	}
	
	if (x < 32) return NULL;
	
	for (; idString[pos] != 0; pos++) {
		if (!whitespace(idString[pos])) return NULL;
	}
	
	/* Is a TADS/generic MD5 string */
	return IFMB_Md5Id(md5);
}

/* Returns an IFID based on the 16-byte UUID passed as an argument */
IFID IFMB_UUID(const unsigned char* uuid) {
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

/* Returns an IFID based on a glulx identifier from an Inform-created game */
IFID IFMB_GlulxId(int release, const char* serial, unsigned int checksum) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_GLULX;
	
	result->data.glulx.release = release;
	memcpy(result->data.glulx.serial, serial, 6);
	result->data.glulx.checksum = checksum;
	
	return result;
}

/* Returns an IFID based on a generic glulx identifier */
IFID IFMB_GlulxIdNotInform(unsigned int memsize, unsigned int checksum) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_GLULXNOTINFORM;
	
	result->data.glulxNotInform.memsize = memsize;
	result->data.glulxNotInform.checksum = checksum;
	
	return result;
}

/* Returns an IFID based on a MD5 identifier */
IFID IFMB_Md5Id(const unsigned char* md5) {
	IFID result;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_MD5;
	
	memcpy(result->data.md5, md5, 16);
	
	return result;
}

/* Merges a set of IFIDs into a single ID */
static int countIds(IFID compoundId) {
	/* Count the number of IDs in the flattened version of compoundId */
	if (compoundId->type == ID_NULL) {
		return 0;
	} else if (compoundId->type == ID_COMPOUND) {
		int x, count;
		
		count = 0;
		for (x=0; x<compoundId->data.compound.count; x++) {
			count += countIds(compoundId->data.compound.ids[x]);
		}
		
		return count;
	} else {
		return 1;
	}
}

static IFID* flattenIds(IFID compoundId, IFID* start) {
	/* Flatten out the IDs in the compound ID into start (copies the IDs) */
	if (compoundId->type == ID_NULL) {
		return start;
	} else if (compoundId->type == ID_COMPOUND) {
		int x;
		IFID* pos = start;
		
		for (x=0; x<compoundId->data.compound.count; x++) {
			pos = flattenIds(compoundId->data.compound.ids[x], pos);
		}
		
		return pos;
	} else {
		*start = IFMB_CopyId(compoundId);
		return start+1;
	}
}

IFID IFMB_CompoundId(int count, IFID* identifiers) {
	IFID result;
	int x, numIds;
	IFID* lastId;
	
	result = malloc(sizeof(struct IFID));
	result->type = ID_COMPOUND;
	
	numIds = 0;
	for (x=0; x < count; x++) {
		numIds += countIds(identifiers[x]);
	}

	result->data.compound.count = numIds;
	result->data.compound.ids = malloc(sizeof(IFID)*numIds);
	result->data.compound.idsNotNull = NULL;
	
	lastId = result->data.compound.ids;
	for (x=0; x < count; x++) {
		lastId = flattenIds(identifiers[x], lastId);
	}
	
	return result;
}


/* Retrieves the IDs that make up a compound ID: number is returned in count. Returns NULL if the ID is not compound */
IFID* IFMB_SplitId(IFID id, int* count) {
	*count = 1;
	if (id->type != ID_COMPOUND) return NULL;
	
	if (id->data.compound.idsNotNull == NULL) {
		int start, end, x;
		
		/* idsNotNull contains the IDs in this compound ID with the ID_NULL ones moved to the end */
		id->data.compound.idsNotNull = malloc(sizeof(IFID)*id->data.compound.count);
		
		start = 0;
		end = id->data.compound.count-1;
		
		for (x=0; x<id->data.compound.count; x++) {
			IFID thisID = id->data.compound.ids[x];
			
			if (thisID->type == ID_NULL) {
				id->data.compound.idsNotNull[end--] = thisID;
			} else {
				id->data.compound.idsNotNull[start++] = thisID;
			}
		}
	}
	
	for (*count=0; *count < id->data.compound.count && id->data.compound.idsNotNull[*count]->type != ID_NULL; *count++);
	
	return id->data.compound.idsNotNull;
}

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
			
		case ID_GLULX:
			if (a->data.glulx.checksum > b->data.glulx.checksum) return 1;
			if (a->data.glulx.checksum < b->data.glulx.checksum) return -1;
				
			if (a->data.glulx.release > b->data.glulx.release) return 1;
			if (b->data.glulx.release < b->data.glulx.release) return -1;
						
			for (x=0; x<6; x++) {
				if (a->data.glulx.serial[x] > b->data.glulx.serial[x]) return 1;
				if (a->data.glulx.serial[x] < b->data.glulx.serial[x]) return -1;
			}
			break;
			
		case ID_GLULXNOTINFORM:
			if (a->data.glulxNotInform.memsize > b->data.glulxNotInform.memsize) return 1;
			if (a->data.glulxNotInform.memsize < b->data.glulxNotInform.memsize) return -1;
			
			if (a->data.glulxNotInform.checksum > b->data.glulxNotInform.checksum) return 1;
			if (a->data.glulxNotInform.checksum < b->data.glulxNotInform.checksum) return -1;
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
	if (ident->type == ID_COMPOUND) {
		int x;
		
		for (x=0; x<ident->data.compound.count; x++) {
			IFMB_FreeId(ident->data.compound.ids[x]);
		}
		
		free(ident->data.compound.ids);
		
		if (ident->data.compound.idsNotNull) free(ident->data.compound.idsNotNull);
	}
	
	free(ident);
}

/* Copies an ID */
IFID IFMB_CopyId(IFID ident) {
	IFID result = malloc(sizeof(struct IFID));
	
	*result = *ident;
	
	if (ident->type == ID_COMPOUND) {
		int x;
		
		result->data.compound.ids = malloc(sizeof(IFID)*ident->data.compound.count);
		result->data.compound.idsNotNull = NULL;
		
		for (x=0; x<ident->data.compound.count; x++) {
			result->data.compound.ids[x] = IFMB_CopyId(ident->data.compound.ids[x]);
		}
	}
	
	return result;
}

/* Functions - stories */

/* Perform a binary search in the given metabase for a story with an ID 'close to' the specified identifier - returns the number of the index entry */
static int NearestIndexNumber(IFMetabase meta, IFID ident) {
	int top, bottom, compare;
	
	bottom = 0;
	top = meta->numIndexEntries-1;
	
	while (top > bottom) {
		int middle;
		
		middle = (top+bottom)>>1;
		
		compare = IFMB_CompareIds(ident, meta->index[middle].id);
		
		if (compare == 0) return middle;
		if (compare == -1) bottom = middle + 1;
		if (compare == 1) top = middle - 1;
	}
	
	/* Return the first value that is less than the specified ID */
	if (top >= meta->numIndexEntries) top--;
	if (top >= 0) {
		compare = IFMB_CompareIds(ident, meta->index[top].id);
		
		while (compare > 0 && top >= 0) {
			top--;
			if (top >= 0) compare = IFMB_CompareIds(ident, meta->index[top].id);
		}
	}
	
	return top;
}

/* Searches for an existing story with the specified identifier, returns NULL if none is found */
static IFStory ExistingStoryWithId(IFMetabase meta, IFID ident) {
	if (ident->type == ID_COMPOUND) {
		/* For a compound ID, find the first story that matches any of the contained IDs */
		int x;
		
		for (x=0; x<ident->data.compound.count; x++) {
			IFStory story;
			
			story = ExistingStoryWithId(meta, ident->data.compound.ids[x]);
			if (story != NULL) return story;
		}
		
		/* Otherwise, return NULL */
		return NULL;
	} else {
		/* For all others, just search for the ID */
		int index;
		
		index = NearestIndexNumber(meta, ident);
		if (index < 0 || index >= meta->numIndexEntries) return NULL;
		
		if (IFMB_CompareIds(ident, meta->index[index].id) == 0) 
			return meta->stories[meta->index[index].storyNumber];
		else
			return NULL;
	}
}

/* Indexes the specified story number using the specified identifier */
/* If a compound ID, any IDs that could not be indexed (due to them already existing in the metabase) are set to ID_NULL as a side-effect */
static int IndexStory(IFMetabase meta, int storyNum, IFID ident) {
	if (ident->type == ID_NULL) {
		return 0;
	} else if (ident->type == ID_COMPOUND) {
		/* Compound IDs are indexed according to their contents */
		int x;
		int indexed;
		
		indexed = 0;
		for (x=0; x<ident->data.compound.count; x++) {
			int indexedEntry;
			
			indexedEntry = IndexStory(meta, storyNum, ident->data.compound.ids[x]);
			
			if (indexedEntry) {
				indexed = 1;
			} else {
				/* Got a story ID that does not identify a new story - set it to NULL */
				ident->data.compound.ids[x]->type = ID_NULL;
				
				if (ident->data.compound.idsNotNull) {
					free(ident->data.compound.idsNotNull);
					ident->data.compound.idsNotNull = NULL;
				}
			}
		}
	} else {
		int index;

		/* Find the index entry after which to place this story */
		index = NearestIndexNumber(meta, ident);
		
		/* Nothing to do if there's already an entry with this ID */
		if (index >= 0 && IFMB_CompareIds(ident, meta->index[index].id) == 0) return 0;
		
		index++;
		
		/* Expand the index array */
		meta->numIndexEntries++;
		meta->index = realloc(meta->index, sizeof(IFIndexEntry)*meta->numIndexEntries);
		
		if (index < meta->numIndexEntries-1)
			memmove(meta->index + index + 1, meta->index + index, sizeof(IFIndexEntry)*(meta->numIndexEntries-1-index));
		
		/* Add the new entry */
		meta->index[index].id = ident;
		meta->index[index].storyNumber = storyNum;
		
		return 1;
	}
}

/* Retrieves the story in the metabase with the given ID (the story is created if it does not already exist) */
IFStory IFMB_GetStoryWithId(IFMetabase meta, IFID ident) {
	IFStory story;

	/* Return the existing story if there's already an entry for this ID in the metabase */
	story = ExistingStoryWithId(meta, ident);
	if (story != NULL) return story;
	
	/* Otherwise, create a new story entry */
	story = malloc(sizeof(struct IFStory));
	story->id = IFMB_CopyId(ident);
	story->number = meta->numStories;
	
	story->root = malloc(sizeof(struct IFValue));
	story->root->key = NULL;
	story->root->value = NULL;
	story->root->childCount = 0;
	story->root->children = NULL;
	story->root->parent = NULL;
	
	/* Add this story to the index */
	meta->numStories++;
	meta->stories = realloc(meta->stories, sizeof(IFStory)*meta->numStories);
	meta->stories[meta->numStories-1] = story;
	
	IndexStory(meta, meta->numStories-1, story->id);
	
	return story;
}

/* Retrieves the ID associated with a given story object */
IFID IFMB_IdForStory(IFStory story) {
	return story->id;
}

/* Removes the story with the specified number from the index */
static void UnindexStory(IFMetabase meta, int storyNum, IFID ident) {
	if (ident->type == ID_NULL) {
		/* NULL stories are never indexed */
		return;
	} else if (ident->type == ID_COMPOUND) {
		int x;
		
		/* Compound stories are indexed by component - unindex those */
		for (x=0; x<ident->data.compound.count; x++) {
			UnindexStory(meta, storyNum, ident->data.compound.ids[x]);
		}
	} else {
		int index;
		
		/* Find this entry in the index */
		index = NearestIndexNumber(meta, ident);
		if (index >= 0 && IFMB_CompareIds(ident, meta->index[index].id) != 0) return;
		
		/* Remove this entry from the index */
		memmove(meta->index + index, meta->index + index + 1, sizeof(IFIndexEntry)*(meta->numIndexEntries - index - 1));
		meta->numIndexEntries--;
	}
}

/* Removes a story with the given ID from the metabase */
void IFMB_RemoveStoryWithId(IFMetabase meta, IFID ident) {
	/* Get the story with this ID */
	IFStory story = ExistingStoryWithId(meta, ident);
	if (story == NULL) return;
	
	/* Remove this story from the indexes */
	UnindexStory(meta, story->number, ident);
	
	/* Remove the story from the metabase list of stories (a stub always remains, a bit memory inefficient, but required for our index) */
	meta->stories[story->number] = NULL;

	/* Destroy the story itself */
	FreeStory(story);
}

/* Returns non-zero if the metabase contains a story with a given ID */
int IFMB_ContainsStoryWithId(IFMetabase meta, IFID ident) {
	return ExistingStoryWithId(meta, ident)!=NULL;
}

/* Finds the index of a value with the specified key */
static int IndexForKey(IFValue parent, const char* key) {
	int top, bottom, compare;
	
	/* Binary search for the key */
	top = parent->childCount;
	bottom = 0;
	
	while (top > bottom) {
		int middle;
		int compare;
		
		middle = (top+bottom)>>1;
		
		compare = strcmp(key, parent->children[middle]->key);
		
		if (compare == 0) return middle;
		if (compare < 0) bottom = middle + 1;
		if (compare > 0) top = middle - 1;
	}
	
	/* Find the first value that's less than the key */
	if (top >= 0 && top < parent->childCount) {
		compare = strcmp(key, parent->children[top]->key);
		
		while (top >= 0 && compare > 0) {
			top--;
			
			if (top >= 0) compare = strcmp(key, parent->children[top]->key);
		}
	}
	
	return top;
}

/* Finds a value using the specified path, from the specified value, optionally creating a new entry */
static IFValue FindValue(IFValue root, const char* path, int createEntry) {
	char* key;
	int x, dividerPos;
	IFValue childValue;
	int index;
	int found;
	
	/* Base case: no path */
	if (path == NULL || path[0] == 0) return root;
	
	/* Get the key for this stage of the path */
	for (x=0; path[x] != '.' && path[x] != '@' && path[x] != 0; x++);
	dividerPos = x;
	
	key = malloc(sizeof(char)*dividerPos+1);
	for (x=0; x<dividerPos; x++) key[x] = tolower(path[x]);
	key[x] = 0;
	
	/* Set childValue to the value for this part of the key */
	index = IndexForKey(root, key);
	
	found = 1;
	if (index < 0 || strcmp(key, root->children[index]->key) != 0) found = 0;
	
	/* Return NULL if the key is not found and we're not creating a new entry */
	if (!found && !createEntry) {
		free(key);
		return NULL;
	}
	
	if (!found) {
		/* If createEntry is true, and the entry is not found, create a new entry */
		childValue = malloc(sizeof(struct IFValue));
		
		childValue->key = malloc(sizeof(char)*(strlen(key)+1));
		strcpy(childValue->key, key);
		childValue->value = NULL;
		childValue->childCount = 0;
		childValue->children = NULL;
		childValue->parent = root;
		
		/* Add it to the list of entries for this node */
		root->childCount++;
		root->children = realloc(root->children, sizeof(IFValue)*root->childCount);
		
		index++;
		memmove(root->children + index + 1, root->children + index,  sizeof(IFValue)*(root->childCount - 1 - index));
		
		root->children[index] = childValue;
	} else {
		childValue = root->children[index];
	}
	
	/* Continue to the next branch */
	if (path[dividerPos] == '.') dividerPos++;
	
	free(key);
	return FindValue(childValue, path + dividerPos, createEntry);
}

/* Returns a UTF-16 string for a given parameter in a story, or NULL if none was found */
/* Copy this value away if you intend to retain it: it may be destroyed on the next IFMB_ call */
IFChar* IFMB_GetValue(IFStory story, const char* valueKey) {
	IFValue value = FindValue(story->root, valueKey, 0);
	
	if (value != NULL) {
		return value->value;
	} else {
		return NULL;
	}
}

/* Sets the UTF-16 string for a given parameter in the story (NULL to unset the parameter) */
void IFMB_SetValue(IFStory story, const char* valueKey, IFChar* utf16value) {
	IFValue value = FindValue(story->root, valueKey, 1);
	
	if (value->value != NULL) free(value->value);
	
	if (utf16value == NULL) {
		value->value = NULL;
	} else {
		value->value = malloc(sizeof(IFChar)*(IFMB_StrLen(utf16value)+1));
		IFMB_StrCpy(value->value, utf16value);
	}
}

/* Functions - iterating */

/* Gets an iterator covering all the stories in the given metabase */
IFStoryIterator IFMB_GetStoryIterator(IFMetabase meta) {
	IFStoryIterator result = malloc(sizeof(struct IFStoryIterator));
	
	result->metabase = meta;
	result->count = -1;
}

/* Gets an iterator covering all the values set in a story */
IFValueIterator IFMB_GetValueIterator(IFStory story) {
	IFValueIterator result;
	
	result = malloc(sizeof(struct IFValueIterator));
	
	result->root = story->root;
	result->count = -1;
	
	result->path = malloc(sizeof(char));
	result->path[0] = 0;
	
	result->pathBuf = NULL;
	
	return result;
}

/* Gets the next story defined in the metabase (or NULL if there are no more) */
IFStory IFMB_NextStory(IFStoryIterator iter) {
	iter->count++;
	
	while (iter->count < iter->metabase->numStories && iter->metabase->stories[iter->count] == NULL) {
		iter->count++;
	}
	
	if (iter->count >= iter->metabase->numStories) return NULL;
	
	return iter->metabase->stories[iter->count];
}

/* Moves to the next (or first) value: returns 0 if finished */
int IFMB_NextValue(IFValueIterator iter) {
	iter->count++;
	
	if (iter->count < iter->root->childCount)
		return 1;
	else
		return 0;
}

/* Retrieves the key from a value iterator */
char* IFMB_KeyFromIterator(IFValueIterator iter) {
	char* key;
	
	key = iter->root->children[iter->count]->key;
	
	/* Just return the key if this is the root iterator */
	if (iter->path[0] == 0) return key;
	
	/* Otherwise build the full path to this key */
	iter->pathBuf = realloc(iter->pathBuf, sizeof(char)*(strlen(key)+strlen(iter->path)+2));

	strcpy(iter->pathBuf, iter->path);
	if (key[0] != '@') strcat(iter->pathBuf, ".");
	strcat(iter->pathBuf, key);
	
	return iter->pathBuf;
}

/* Retrieves the last part of the key from a value iterator */
char* IFMB_SubkeyFromIterator(IFValueIterator iter) {
	return iter->root->children[iter->count]->key;
}

/* Retrieves the string value from a value iterator */
IFChar* IFMB_ValueFromIterator(IFValueIterator iter) {
	return iter->root->children[iter->count]->value;
}

/* Retrieves an iterator for the nodes underneath a given value (or NULL if there are none) */
IFValueIterator IFMB_ChildrenFromIterator(IFValueIterator iter) {
	IFValueIterator result;
	IFValue newRoot;
	
	/* Get the new root of this iterator */
	newRoot = iter->root->children[iter->count];
	if (newRoot->childCount <= 0) return NULL;
	
	/* Construct a new value iterator for the children of this iterator */
	result = malloc(sizeof(struct IFValueIterator));
	
	result->root = newRoot;
	result->count = -1;
	
	result->path = malloc(sizeof(char));
	result->path[0] = 0;
	
	result->pathBuf = NULL;
	
	return result;	
}

/* Frees the two types of iterator */
void IFMB_FreeStoryIterator(IFStoryIterator iter) {
	free(iter);
}

void IFMB_FreeValueIterator(IFValueIterator iter) {
	if (iter->path) free(iter->path);
	if (iter->pathBuf) free(iter->pathBuf);
	
	free(iter);
}
	
/* Functions - basic UTF-16 string manipulation */

int IFMB_StrLen(const IFChar* a) {
	int x;
	
	for (x=0; a[x] != 0; x++);
	
	return x;
}

int IFMB_StrCmp(const IFChar* a, const IFChar* b) {
	int x;
	
	for (x=0; ; x++) {
		if (a[x] > b[x]) return 1;
		if (a[x] < b[x]) return -1;
		
		if (a[x] == 0) break;
	}
	
	return 0;
}

void IFMB_StrCpy(IFChar* a, const IFChar* b) {
	int x;
	
	for (x=0; b[x] != 0; x++) a[x] = b[x];
	a[x] = 0;
}
