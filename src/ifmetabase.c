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

/* Constructs a new, empty metabase */
extern IFMetabase IFMB_Create();

/* Frees up all the memory associated with a metabase */
extern void IFMB_Free(IFMetabase meta);

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
		lowerPrefix[x] = lowerPrefix[x];
	}
	
	/* Record the length of the string */
	idLen = strlen(idString);
	
	/* Try to parse a UUID */
	if (idLen >= 39 && lowerPrefix[0] == 'u' && lowerPrefix[1] == 'u' && lowerPrefix[2] == 'i' && lowerPrefix[3] == 'd' && idString[4] == ':' && idString[5]) {
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
			uuid[uuidPos>>1] |= hexValue<<(4*(uuidPos&1));
		}
		
		/* If we haven't got 32 nibbles, then this is not a UUID */
		if (uuidPos != 32) return NULL;
		
		/* Remaining characters must be '/' or whitespace only */
		for (; chrNum < idLen; chrNum++) {
			if (!whitespace(idString[chrNum]) || idString[chrNum] != '/') return NULL;
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
		
		md5[x>>1] |= hexValue<<(4*(x&1));

		x++;
		if (x >= 32) break;
	}
	
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
	if (compoundId->type == ID_COMPOUND) {
		int x, count;
		
		count = 0;
		for (x=0; x<compoundId->data.compound.count; x++) {
			count += countIds(compoundId->data.compound.ids);
		}
		
		return count;
	} else {
		return 1;
	}
}

static IFID* flattenIds(IFID compoundId, IFID* start) {
	/* Flatten out the IDs in the compound ID into start (copies the IDs) */
	if (compoundId->type == ID_COMPOUND) {
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
	
	lastId = result->data.compound.ids;
	for (x=0; x < count; x++) {
		lastId = flattenIds(identifiers[x], lastId);
	}
	
	return result;
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
		
		for (x=0; x<ident->data.compound.count; x++) {
			result->data.compound.ids[x] = IFMB_CopyId(ident->data.compound.ids[x]);
		}
	}
	
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
