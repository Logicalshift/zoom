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
 * Implementation of a metadata parser for the IF Metadata format (version 0.9)
 * Supports the UNICODE version of expat, if you can compile it.
 * (#define XML_UNICODE when compiling to enable, doesn't require wchat_t)
 *
 * Implementation with expat increases complexity a lot over an implementation
 * using (say) a DOM library, but these are usually less portable and implemented
 * for languages like (blech) C++. This will work on anything that expat can be
 * compiled for, which is pretty much anything.
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>

#include <expat.h>

#include "ifmetadata.h"

#ifndef XMLCALL
/* Not always defined? */
# define XMLCALL
#endif

/* == Parser function declarations == */
static XMLCALL void startElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts);
static XMLCALL void endElement  (void *userData,
								 const XML_Char *name);
static XMLCALL void charData    (void *userData,
								 const XML_Char *s,
								 int len);

/* == Parser state == */
typedef struct IFMDState IFMDState;

struct IFMDState {
	XML_Parser parser;
	
	IFMetadata* data;
	IFMDStory*  story;
	IFMDIdent*  ident;
	
	int level;
	XML_Char** tagStack;
	XML_Char** tagText;
};

/* == Useful utility functions == */

/*
 * We provide a bunch of 'X' functions to provide minimal wide character support
 * for the case where wchar.h is not available. Note that current versions of
 * expat do not support widechar support without wchar.h, so you may consider this
 * superflous. This does simplify the code somewhat - ie, it should compile
 * regardless of the type of XML_Char.
 *
 * Upper/lowercase support is therefore ASCII only, and comparasons need to be
 * exact (ie not following the Unicode rules). This is presently OK, regardless
 * of the use of Unicode, as no current game format requires the use of Unicode
 * comparason rules.
 */

static int Xstrncpy(XML_Char* a, const XML_Char* b, int len) {
	int x;
	
	for (x=0; b[x] != 0 && x<len; x++) {
		a[x] = b[x];
	}
	
	a[x] = 0;
	
	return x;
}

#if 0
static int XCstrncpy(XML_Char* a, const unsigned char* b, int len) {
	int x;
	
	for (x=0; b[x] != 0 && x < (len-1); x++) {
		a[x] = b[x];
	}
	
	a[x] = 0;
	
	return x;
}

static int Xstrcmp(const XML_Char* a, const XML_Char* b) {
	int x;
	
	for (x=0; a[x] != 0 && b[x] != 0; x++) {
		if (a[x] < b[x]) return -1;
		if (a[x] > b[x]) return 1;
	}
	
	if (a[x] < b[x]) return -1;
	if (a[x] > b[x]) return 1;
	
	return 0;
}
#endif

static int XCstrcmp(const XML_Char* a, const unsigned char* b) {
	int x;
	
	for (x=0; a[x] != 0 && b[x] != 0; x++) {
		if (a[x] < b[x]) return -1;
		if (a[x] > b[x]) return 1;
	}
	
	if (a[x] < b[x]) return -1;
	if (a[x] > b[x]) return 1;
	
	return 0;
}

static int Xstrlen(const XML_Char* a) {
	int x;
	
	if (a == NULL) return 0;

	for (x=0; a[x] != 0; x++);
	
	return x;
}

static XML_Char XchompConvert(XML_Char c) {
	if (c == '\n' || c == '\t' || c == '\r') return ' ';
	if (c == 1) return '\n'; /* Hack */
	return c;
}

static XML_Char* Xchomp(const XML_Char* a) {
	/*
	 * 'Strips' the string provided
	 * '\n' and '\t' are replaced with ' '
	 * Sequences of spaces are replaced with a single space
	 * Spaces are removed from the beginning and end of the string
	 *
	 * The returned string should be released with free(), and is always as long as or shoter than a.
	 */
	
	XML_Char* result = malloc(sizeof(XML_Char)*(Xstrlen(a)+1));
	int ignoreSpaces = 1;
	int x;
	int pos = 0;
	
	if (a == NULL) {
		result[0] = 0;
		return result;
	}
	
	/* Perform the chomping */
	for (x=0; a[x] != 0; x++) {
		XML_Char c = XchompConvert(a[x]);
		
		if (c == ' ' && ignoreSpaces) continue;
		if (c == ' ' || c == '\n') ignoreSpaces = 1; else ignoreSpaces = 0;
		
		result[pos++] = c;
	}
	
	/* Strip spaces at the end of the string */
	while (pos > 0 && result[pos-1] == ' ') pos--;
	
	result[pos] = 0;
	
	return result;
}

static XML_Char* Xlower(XML_Char* s) {
	/* Converts the 's' string to lower case (for ASCII values thereof). s is converted in place */
	int x;
	
	for (x=0; s[x] !=0; x++) {
		if (s[x] >= 'A' && s[x] <= 'Z') s[x] = tolower(s[x]);
	}
	
	return s;
}

static char* Xascii(XML_Char* s) {
	/* Converts 's' to simple ASCII. The return value must be freed */
	char* res;
	int x;
	int len = Xstrlen(s);
	
	res = malloc(sizeof(char)*(len+1));
	
	for (x=0; x<len; x++) {
		if (s[x] >= 32 && s[x] < 127)
			res[x] = s[x];
		else
			res[x] = '?';
	}
	
	res[x] = 0;
	
	return res;
}

/* Table pinched from the Unicode book */
static unsigned char bytesFromUTF8[256] = {
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5};

static IFMDChar* Xmdchar(XML_Char* s) {
	/* Converts s to IFMDChars. Result needs to be freed */
	int x, pos;
	int len = Xstrlen(s);
	IFMDChar* res;
	
	res = malloc(sizeof(IFMDChar)*(len+1));
	pos = 0;
	
	for (x=0; x<len; x++) {
		int chr = (unsigned char)s[x];
		
		if (chr < 127) {
			res[pos++] = chr;
		} else {
			/* UTF-8 decode */
			int bytes = bytesFromUTF8[chr];
			int chrs[6];
			int y;
			int errorFlag;
			
			if (x+bytes >= len) break;
			
			/* Read+check the characters that make up this char */
			errorFlag = 0;
			for (y=0; y<=bytes; y++) {
				chrs[y] = (unsigned char)s[x+y];
				
				if (chrs[y] < 127) errorFlag = 1;
			}
			if (errorFlag) continue; /* Ignore this character (error) */
			
			/* Get the UCS-4 character */
			switch (bytes) {
				case 1: chr = ((chrs[0]&~0xc0)<<6)|(chrs[1]&~0x80); break;
				case 2: chr = ((chrs[0]&~0xe0)<<12)|((chrs[1]&~0x80)<<6)|(chrs[2]&~0x80); break;
				case 3: chr = ((chrs[0]&~0xf0)<<18)|((chrs[1]&~0x80)<<12)|((chrs[2]&~0x80)<<6)|(chrs[3]&~0x80); break;
				case 4: chr = ((chrs[0]&~0xf8)<<24)|((chrs[1]&~0x80)<<18)|((chrs[2]&~0x80)<<12)|((chrs[3]&~0x80)<<6)|(chrs[4]&~0x80); break;
				case 5: chr = ((chrs[0]&~0xfc)<<28)|((chrs[1]&~0x80)<<24)|((chrs[2]&~0x80)<<18)|((chrs[3]&~0x80)<<12)|((chrs[4]&~0x80)<<6)|(chrs[5]&~0x80); break;
			}
			
			x += bytes;
			
			res[pos++] = chr;
		}
	}
	
	res[x] = 0;
	
	return res;
}

static IFMDChar* Xcopy(IFMDChar* stringIn) {
	int x;
	IFMDChar* stringOut;
	int len;
	
	if (stringIn == NULL) return NULL;
	for (len=0; stringIn[len]!=0; len++);
	if (len == 0) return NULL;
	
	stringOut = malloc(sizeof(IFMDChar)*(len+1)); 
	for (x=0; x<len; x++) {
		stringOut[x] = stringIn[x];
	}
	stringOut[x] = 0;
	
	return stringOut;
}

/* State functions */
static void pushTag(IFMDState* s, const XML_Char* tag) {
	int len = Xstrlen(tag);
	int x;
	
	s->level++;
	
	s->tagStack = realloc(s->tagStack, sizeof(XML_Char*)*(s->level));
	s->tagStack[s->level-1] = malloc(sizeof(XML_Char)*(len+1));
	s->tagText = realloc(s->tagText, sizeof(XML_Char*)*(s->level));
	s->tagText[s->level-1] = NULL;

	Xstrncpy(s->tagStack[s->level-1], tag, len);
	
	for (x=0; x<len; x++) {
		if (s->tagStack[s->level-1][x] < 127) {
			s->tagStack[s->level-1][x] = tolower(s->tagStack[s->level-1][x]);
		}
	}
}

static void popTag(IFMDState* s) {
	if (s->level <= 0) {
		return;
	}
	
	s->level--;
	free(s->tagStack[s->level]);
	if (s->tagText[s->level]) free(s->tagText[s->level]);
}

static XML_Char* parentTag(IFMDState* s) {
	if (s->level < 2) return NULL;
	return s->tagStack[s->level-2];
}

static XML_Char* currentTag(IFMDState* s) {
	if (s->level < 1) return NULL;
	return s->tagStack[s->level-1];
}

static void addError(IFMDState* s, enum IFMDErrorType errorType, const char* data) {
	s->data->numberOfErrors++;
	s->data->error = realloc(s->data->error, s->data->numberOfErrors*sizeof(IFMDError));
	
	s->data->error[s->data->numberOfErrors-1].severity = IFMDErrorFatal;
	s->data->error[s->data->numberOfErrors-1].type     = errorType;
	s->data->error[s->data->numberOfErrors-1].moreText = NULL; /* FIXME */
	
	if (s->story)
		s->story->error = 1;
	
	printf("Error: %i (%s) (@%i)\n", errorType, data, XML_GetCurrentLineNumber(s->parser));
}

/* Sorting functions */
static int indexCompare(const void* a, const void* b) {
	const IFMDIndexEntry* ai = a;
	const IFMDIndexEntry* bi = b;
	
	return IFID_Compare(ai->ident, bi->ident);
}

/* == The main functions == */
IFMetadata* IFMD_Parse(const IFMDByte* data, size_t length) {
	XML_Parser theParser;
	IFMetadata* res = malloc(sizeof(IFMetadata));
	IFMDState*  currentState = malloc(sizeof(IFMDState));
	
	enum XML_Status status;
	
	int story, ident, entry;
	
	/* Create the result structure */
	res->error = NULL;
	res->stories = NULL;
	res->index = NULL;
	res->numberOfStories  = 0;
	res->numberOfErrors = 0;
	res->numberOfIndexEntries = 0;
		
	/* Create the state */
	currentState->data  = res;
	currentState->story = NULL;
	currentState->ident = NULL;
	currentState->level = 0;
	currentState->tagStack = NULL;
	currentState->tagText  = NULL;
	
	/* Begin parsing */
	theParser = XML_ParserCreate(NULL);
	currentState->parser = theParser;
	XML_SetElementHandler(theParser, startElement, endElement);
	XML_SetCharacterDataHandler(theParser, charData);
	XML_SetUserData(theParser, currentState);
	
	/* Go! */
	status = XML_Parse(theParser, data, length, 1);
	
	if (status != XML_STATUS_OK) {
		enum XML_Error error = XML_GetErrorCode(theParser);
		const XML_LChar* erm = XML_ErrorString(error);
		
		addError(currentState, IFMDErrorXMLError, erm);
	}
	
	/* Index */
	for (story = 0; story < res->numberOfStories; story++) {
		if (!res->stories[story].error) {
			for (ident = 0; ident < res->stories[story].numberOfIdents; ident++) {
				IFMDIndexEntry newEntry;
				
				newEntry.ident = res->stories[story].idents + ident;
				/* newEntry.story = res->stories + story; */
				newEntry.storyNum = story;
				
				res->numberOfIndexEntries++;
				res->index = realloc(res->index, sizeof(IFMDIndexEntry)*res->numberOfIndexEntries);
				res->index[res->numberOfIndexEntries-1] = newEntry;
			}
		}
	}
	
	/* Sort the entries for easy searching */
	qsort(res->index, res->numberOfIndexEntries, sizeof(IFMDIndexEntry), indexCompare);
	
	for (entry=0; entry<res->numberOfIndexEntries-1; entry++) {
		int cmp = IFID_Compare(res->index[entry].ident, res->index[entry+1].ident);
		
		if (cmp > 0) addError(currentState, IFMDErrorProgrammerIsASpoon, "Index not sorted");
		if (cmp == 0) {
			/* Duplicate entry */
			if (res->index[entry].storyNum != res->index[entry+1].storyNum) {
				char msg[512];
				
				snprintf(msg, 512, "FIX THIS MESSAGE");
				msg[511] = 0;
				
				addError(currentState, IFMDErrorStoriesShareIDs, msg);
			} else {
				char msg[512];
				
				snprintf(msg, 512, "FIX THIS MESSAGE");
				msg[511] = 0;
				
				addError(currentState, IFMDErrorDuplicateID, msg);
			}
			
			/* Remove following entry */
			res->numberOfIndexEntries--;
			memmove(res->index+entry+1,
					res->index+entry+2,
					sizeof(IFMDIndexEntry)*(res->numberOfIndexEntries-entry));
			
			/* Keep trying at this entry */
			entry--;
		}
	}
		
	/* Finish up */
	XML_ParserFree(theParser);
	
	while (currentState->level > 0) popTag(currentState);
	if (currentState->tagStack) free(currentState->tagStack);
	free(currentState);
	
	/* All done */
	return res;
}

void IFMD_Free(IFMetadata* oldData) {
	int x;
	
	/* Index */
	free(oldData->index);
	
	/* Stories */
	for (x=0; x<oldData->numberOfStories; x++) {
		IFStory_Free(oldData->stories + x);
	}
	
	free(oldData->stories);
	
	/* Errors */
	for (x=0; x<oldData->numberOfErrors; x++) {
		if (oldData->error[x].moreText) free(oldData->error[x].moreText);
	}
	free(oldData->error);
	
	/* Finally, the data itself */
	free(oldData);
}

IFMDStory* IFMD_Find(IFMetadata* data, const IFMDIdent* id) {
	int top, bottom;
	
	bottom = 0;
	top = data->numberOfIndexEntries-1;
	
	while (bottom < top) {
		int middle = (bottom + top)>>1;
		int cmp = IFID_Compare(data->index[middle].ident, id);
		
		if (cmp == 0) return data->stories + data->index[middle].storyNum;
		else if (cmp < 0) bottom = middle+1;
		else if (cmp > 0) top    = middle-1;
	}
	
	if (bottom == top && IFID_Compare(id, data->index[bottom].ident) == 0) {
		return data->stories + data->index[bottom].storyNum;
	}
	
	return NULL;
}

/* == Parser functions == */
static XMLCALL void startElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts) {
	IFMDState* state = userData;
	XML_Char* parent, *current;
	
	pushTag(state, name);
	
	parent = parentTag(state);
	current = currentTag(state);
	
	if (current == NULL) {
		/* Programmer is a spoon */
		addError(state, IFMDErrorProgrammerIsASpoon, "No current tag");
		return;
	}
	
	if (parent == NULL) {
		/* ifindex only */
		if (XCstrcmp(current, "ifindex") != 0) {
			/* Not IF metadata */
			addError(state, IFMDErrorNotIFIndex, NULL);
		}
	} else if (XCstrcmp(parent, "ifindex") == 0) {
		/* <story> only */
		if (XCstrcmp(current, "story") == 0) {
			/* IF story */
			IFMDStory newStory;
			
			newStory.numberOfIdents = 0;
			newStory.idents = NULL;
			newStory.error = 0;
			
			newStory.data.title = NULL;
			newStory.data.headline = NULL;
			newStory.data.author = NULL;
			newStory.data.genre = NULL;
			newStory.data.year = 0;
			newStory.data.group = NULL;
			newStory.data.zarfian = IFMD_Unrated;
			newStory.data.teaser = NULL;
			newStory.data.comment = NULL;
			newStory.data.rating = -1.0;
			
			state->data->numberOfStories++;
			state->data->stories = realloc(state->data->stories, sizeof(IFMDStory)*state->data->numberOfStories);
			state->data->stories[state->data->numberOfStories-1] = newStory;
			
			state->story = state->data->stories + (state->data->numberOfStories-1);
		} else {
			/* Unrecognised tag */
			addError(state, IFMDErrorUnknownTag, NULL);
		}
	} else if (XCstrcmp(parent, "story") == 0) {
		/* Metadata or <identification> tags */
		if (XCstrcmp(current, "identification") == 0) {
			/* Story ID data */
			IFMDIdent newID;
			int x;
			
			if (state->story == NULL) return;
			
			newID.format = IFFormat_Unknown;
			newID.dataFormat = IFFormat_Unknown;
			newID.usesMd5 = 0;
			for (x=0; x<16; x++) newID.md5Sum[x] = 0;
			
			state->story->numberOfIdents++;
			state->story->idents = realloc(state->story->idents, sizeof(IFMDIdent)*state->story->numberOfIdents);
			state->story->idents[state->story->numberOfIdents-1] = newID;
			
			state->ident = state->story->idents + (state->story->numberOfIdents-1);
		} else if (XCstrcmp(current, "title") == 0) {
		} else if (XCstrcmp(current, "headline") == 0) {
		} else if (XCstrcmp(current, "author") == 0) {
		} else if (XCstrcmp(current, "genre") == 0) {
		} else if (XCstrcmp(current, "year") == 0) {
		} else if (XCstrcmp(current, "group") == 0) {
		} else if (XCstrcmp(current, "zarfian") == 0) {
		} else if (XCstrcmp(current, "teaser") == 0) {
		} else if (XCstrcmp(current, "comment") == 0) {
		} else if (XCstrcmp(current, "rating") == 0) {
		} else {
			/* Unrecognised tag */
			addError(state, IFMDErrorUnknownTag, NULL);
		}
	} else if (XCstrcmp(parent, "identification") == 0) {
		/* ID tags */
		if (XCstrcmp(current, "format") == 0) {
			/* Format of the story */
		} else if (XCstrcmp(current, "md5") == 0) {
			/* MD5 data */
		} else if (XCstrcmp(current, "zcode") == 0) {
			/* ZCode data */
			if (state->ident) {
				int x;
				
				state->ident->data.zcode.checksum = 0x10000; /* == No checksum */
				state->ident->data.zcode.release  = 0;				
				for (x=0; x<6; x++) state->ident->data.zcode.serial[x] = 0;
			}
		} else if (XCstrcmp(current, "glulx") == 0) {
			/* Glulx data */
		} else {
			/* Unrecognised ID tag */
			addError(state, IFMDErrorUnknownTag, NULL);
		}
	} else if (XCstrcmp(parent, "zcode") == 0) {
		/* ZCode data */
		if (XCstrcmp(current, "serial") == 0) {
		} else if (XCstrcmp(current, "release") == 0) {
		} else if (XCstrcmp(current, "checksum") == 0) {
		} else {
			/* Unrecognised tag */
			addError(state, IFMDErrorUnknownTag, NULL);
		}
	} else if (XCstrcmp(parent, "glulx") == 0) {
		/* Glulx data */
		if (XCstrcmp(current, "serial") == 0) {
		} else if (XCstrcmp(current, "release") == 0) {
		} else {
			/* Unrecognised tag */
			addError(state, IFMDErrorUnknownTag, NULL);
		}
	} else {
		/* Unknown data */
	}
}

static XMLCALL void endElement(void *userData,
							   const XML_Char *name) {
	IFMDState* state = userData;
	XML_Char* current;
	XML_Char* parent;
	XML_Char* currentText;
	
	current = currentTag(state);
	parent  = parentTag(state);

	if (current == NULL) {
		/* Programmer is a spoon */
		addError(state, IFMDErrorProgrammerIsASpoon, "No current tag");
		return;
	}
	
	currentText = state->tagText[state->level-1];
	
	if (parent) {
		/* Process these tags */
		if (state->ident != NULL) {
			/* Dealing with a game identification section */
			
			if (XCstrcmp(parent, "identification") == 0) {
				/* General identification */
				if (XCstrcmp(current, "md5") == 0) {
					/* MD5 key <identification><md5> */
					char key[32];
					int pos = 0;
					int x;
					int len = Xstrlen(currentText);
					
					IFMDByte checksum[16];
					
					/* Read the text of the key */
					for (x=0; x<len; x++) {
						int cT = currentText[x];
						
						if ((cT >= 'a' && cT <= 'f') ||
							(cT >= 'A' && cT <= 'F') ||
							(cT >= '0' && cT <= '9')) {
							key[pos++] = cT;
							
							if (pos >= 32) break;
						}
					}
					
					/* Key is a 128-bit number - we convert into bytes */
					for (x=0; x<16; x++) checksum[x] = 0;
					
					for (x=(pos-1); x >= 0; x--) {
						/* x = the nibble we're dealing with */
						/* key[x] = the hexadecimal char we're dealing with */
						int hex = key[x];
						int val = 0;
						int byte = x>>1;
						
						if (hex >= 'a' && hex <= 'f') val = 10 + (hex-'a');
						else if (hex >= 'A' && hex <= 'F') val = 10 + (hex-'A');
						else if (hex >= '0' && hex <= '9') val = hex-'0';
						
						if ((x&1) != 0) {
							/* First nibble */
							checksum[byte] |= val;
						} else {
							/* Second nibble */
							checksum[byte] |= val<<4;
						}
					}
					
					/* Store the result */
					state->ident->usesMd5 = 1;
					memcpy(state->ident->md5Sum, checksum, sizeof(IFMDByte)*16);
				} else if (XCstrcmp(current, "format") == 0) {
					/* File format specifier <identification><format> */
					XML_Char* format = Xlower(Xchomp(currentText));
					
					if (XCstrcmp(format, "zcode") == 0) {
						state->ident->format = IFFormat_ZCode;
					} else if (XCstrcmp(format, "glulx") == 0) {
						state->ident->format = IFFormat_Glulx;
					} else if (XCstrcmp(format, "tads") == 0) {
						state->ident->format = IFFormat_TADS;
					} else if (XCstrcmp(format, "hugo") == 0) {
						state->ident->format = IFFormat_HUGO;
					} else if (XCstrcmp(format, "alan") == 0) {
						state->ident->format = IFFormat_Alan;
					} else if (XCstrcmp(format, "adrift") == 0) {
						state->ident->format = IFFormat_Adrift;
					} else if (XCstrcmp(format, "level9") == 0) {
						state->ident->format = IFFormat_Level9;
					} else if (XCstrcmp(format, "agt") == 0) {
						state->ident->format = IFFormat_AGT;
					} else if (XCstrcmp(format, "magscrolls") == 0) {
						state->ident->format = IFFormat_MagScrolls;
					} else if (XCstrcmp(format, "advsys") == 0) {
						state->ident->format = IFFormat_AdvSys;
					} else {
						/* Unrecognised format */
						addError(state, IFMDErrorUnknownFormat, NULL);
					}
					
					free(format);
				}
			} else if (XCstrcmp(parent, "zcode") == 0) {
				/* zcode identification section */
				XML_Char* text = Xlower(Xchomp(currentText));
				
				state->ident->dataFormat = IFFormat_ZCode;
				
				if (XCstrcmp(current, "serial") == 0) {
					int x;
					
					for (x=0; x<6 && text[x] != 0; x++) {
						state->ident->data.zcode.serial[x] = text[x];
					}
				} else if (XCstrcmp(current, "release") == 0) {
					char* release = Xascii(text);
					
					state->ident->data.zcode.release = atoi(release);
					
					free(release);
				} else if (XCstrcmp(current, "checksum") == 0) {
					char* checksum = Xascii(text);
					int x, val;
					
					val = 0;
					for (x=0; x<4 && checksum[x] != 0; x++) {
						int hex = 0;
						
						val <<= 4;
						
						if (checksum[x] >= '0' && checksum[x] <= '9') hex = checksum[x]-'0';
						else if (checksum[x] >= 'A' && checksum[x] <= 'F') hex = checksum[x]-'A'+10;
						else if (checksum[x] >= 'a' && checksum[x] <= 'f') hex = checksum[x]-'a'+10;
						else break;
						
						val |= hex;
					}
					
					free(checksum);
				}
				
				free(text);
			} else if (XCstrcmp(parent, "glulx") == 0) {
				/* glulx identification section */
				XML_Char* text = Xlower(Xchomp(currentText));
				
				state->ident->dataFormat = IFFormat_Glulx;
				
				if (XCstrcmp(current, "serial") == 0) {
					int x;
					
					for (x=0; x<6 && text[x] != 0; x++) {
						state->ident->data.glulx.serial[x] = text[x];
					}
				} else if (XCstrcmp(current, "release") == 0) {
					char* release = Xascii(text);
					
					state->ident->data.glulx.release = atoi(release);
					
					free(release);
				}
				
				free(text);
			}
		} else if (state->story != NULL) {
			/* Dealing with a story section */
			if (XCstrcmp(parent, "story") == 0) {
				/* Probably metadata */
				XML_Char* text = Xchomp(currentText);
				
				if (XCstrcmp(current, "title") == 0) {
					state->story->data.title = Xmdchar(text);
				} else if (XCstrcmp(current, "headline") == 0) {
					state->story->data.headline = Xmdchar(text);
				} else if (XCstrcmp(current, "author") == 0) {
					state->story->data.author = Xmdchar(text);
				} else if (XCstrcmp(current, "genre") == 0) {
					state->story->data.genre = Xmdchar(text);
				} else if (XCstrcmp(current, "year") == 0) {
					char* year = Xascii(text);
					
					state->story->data.year = atoi(year);
					
					free(year);
				} else if (XCstrcmp(current, "group") == 0) {
					state->story->data.group = Xmdchar(text);
				} else if (XCstrcmp(current, "zarfian") == 0) {
					Xlower(text);
					
					if (XCstrcmp(text, "merciful") == 0) {
						state->story->data.zarfian = IFMD_Merciful;
					} else if (XCstrcmp(text, "polite") == 0) {
						state->story->data.zarfian = IFMD_Polite;
					} else if (XCstrcmp(text, "tough") == 0) {
						state->story->data.zarfian = IFMD_Tough;
					} else if (XCstrcmp(text, "nasty") == 0) {
						state->story->data.zarfian = IFMD_Nasty;
					} else if (XCstrcmp(text, "cruel") == 0) {
						state->story->data.zarfian = IFMD_Cruel;
					}
				} else if (XCstrcmp(current, "teaser") == 0) {
					state->story->data.teaser = Xmdchar(text);
				} else if (XCstrcmp(current, "comment") == 0) {
					state->story->data.comment = Xmdchar(text);
				} else if (XCstrcmp(current, "rating") == 0) {
					char* rating = Xascii(text);
					
					state->story->data.rating = atof(rating);
					
					free(rating);
				}
				
				free(text);
			}
		}
	}
	
	if (parent && (XCstrcmp(parent, "teaser") == 0 || XCstrcmp(parent, "comment") == 0) &&
		XCstrcmp(current, "br") == 0) {
		/* <br> is allowed: this is a bit of a hack */
		XML_Char newLine[2] = { 1, 0 };
				
		popTag(state);
		charData(state, newLine, 1);
		return;
	}
	
	if (XCstrcmp(current, "identification") == 0) {
		/* Verify the identification for errors */
		if (state->ident->dataFormat != IFFormat_Unknown &&
			state->ident->dataFormat != state->ident->format) {
			/* Specified one format with <format>, but gave data for another */
			addError(state, IFMDErrorMismatchedFormats, NULL);
		}
				
		/* Clear it */
		state->ident = NULL;
	} else if (XCstrcmp(current, "story") == 0) {
		state->story = NULL;
	}
	
	popTag(state);
}

static XMLCALL void charData(void *userData,
							 const XML_Char *s,
							 int len) {
	IFMDState* state = userData;
	int oldLen = Xstrlen(state->tagText[state->level-1]);
			
	/* Store this text */
	state->tagText[state->level-1] = realloc(state->tagText[state->level-1], 
											 sizeof(XML_Char)*(oldLen+len+1));
	Xstrncpy(state->tagText[state->level-1] + oldLen,
			 s, len);
}

/* == Story/ID functions == */
int IFID_Compare(const IFMDIdent* a, const IFMDIdent* b) {
	int x;
	
	/* Format comparison */
	if (a->format > b->format) return 1;
	if (a->format < b->format) return -1;
	
	if (a->dataFormat > b->dataFormat) return 1;  /* (ERROR) */
	if (a->dataFormat < b->dataFormat) return -1; /* (ERROR) */
	
	/* Format-specific comparison */
	switch (a->dataFormat) { /* (Must be the same as b->dataFormat) */
		case IFFormat_ZCode:
			/* ZCode comparison is considered desisive: skip any future tests */
			
			/* Checksum */
			if (a->data.zcode.checksum < 0x10000 && b->data.zcode.checksum < 0x10000) {
				if (a->data.zcode.checksum > b->data.zcode.checksum) return 1;
				if (a->data.zcode.checksum < b->data.zcode.checksum) return -1;
			}
			
			/* Serial number */
			for (x=0; x<6; x++) {
				if (a->data.zcode.serial[x] > b->data.zcode.serial[x]) return 1;
				if (a->data.zcode.serial[x] < b->data.zcode.serial[x]) return -1;
			}
			
			/* Release */
			if (a->data.zcode.release > b->data.zcode.release) return 1;
			if (a->data.zcode.release < b->data.zcode.release) return -1;
			
			/* They're the same */
			return 0;
			
		case IFFormat_Glulx:
			/* Do nothing (Glulx comparison is not considered decisive) */
			break;
			
		default:
			/* Unknown format */
			break;
	}
	
	/* MD5 comparison (if possible) */
	if (a->usesMd5 && !b->usesMd5) return 1;
	if (!a->usesMd5 && b->usesMd5) return -1;
	
	if (a->usesMd5 && b->usesMd5) {
		for (x=0; x<16; x++) {
			unsigned char md5a, md5b;
			
			md5a = a->md5Sum[x];
			md5b = b->md5Sum[x];
			
			if (md5a > md5b) return 1;
			if (md5a < md5b) return -1;
		}
	}
	
	/* Surely these are the same game! */
	return 0;
}

void IFID_Free(IFMDIdent* oldId) {
	/* Note: only frees the data associated with the ident (ie, not the oldId pointer itself) */
	
	/* Nothing to do yet */
}

void IFStory_Free(IFMDStory* oldStory) {
	/* Note: only frees the data associated with the story (ie, not the oldStory pointer itself) */
	int x;
	
	for (x=0; x<oldStory->numberOfIdents; x++) {
		IFID_Free(oldStory->idents + x);
	}
	
	if (oldStory->data.title)    free(oldStory->data.title);
	if (oldStory->data.headline) free(oldStory->data.headline);
	if (oldStory->data.author)   free(oldStory->data.author);
	if (oldStory->data.genre)    free(oldStory->data.genre);
	if (oldStory->data.group)    free(oldStory->data.group);
	if (oldStory->data.teaser)   free(oldStory->data.teaser);
	if (oldStory->data.comment)  free(oldStory->data.comment);
	
	free(oldStory->idents);
}

/* Formatting strings */
int IFStrLen(const IFMDChar* string) {
	int len;
	
	for (len=0;string[len]!=0;len++);
	
	return len;
}

char* IFStrnCpyC(char* dst, const IFMDChar* src, size_t sz) {
	int pos;
	
	for (pos=0; src[pos]!=0 && pos<(sz-1); pos++) {
		if (src[pos] < 127) dst[pos] = src[pos]; else dst[pos] = '?';
	}
	
	dst[pos] = 0;
	
	return dst;
}

static unsigned short int* GetUTF16(const IFMDChar* src, int* len) {
	int pos, dpos;
	int alloc;
	short int* res;
	
	res = NULL;
	alloc = 0;
	dpos = 0;
	
#define UTStore(x) if (dpos >= alloc) { alloc += 256; res = realloc(res, sizeof(short int)*alloc); } res[dpos++] = x;
	
	for (pos=0; src[pos]!=0; pos++) {
		if (src[pos] <= 0xffff) {
			UTStore(src[pos]);
		} else if (src[pos] <= 0x10ffff) {
			UTStore(0xd800 + (src[pos]>>10));
			UTStore(0xdc00 + (src[pos]&0x3ff));
		} else {
			/* Skip this character */
		}
	}
    UTStore(0);
	
	if (len) *len = dpos-1;

    return res;
}

#ifdef HAVE_WCHAR_H
wchar_t* IFStrnCpyW(wchar_t* dst, const IFMDChar* src, size_t sz) {
	unsigned short int* utf16 = GetUTF16(src, NULL);
	int x;
	
	for (x=0; utf16[x]!=0 && x<(sz-1); x++) {
		dst[x] = utf16[x];
	}
	
	dst[x] = 0;
	
	free(utf16);
	
	return dst;
}
#endif

#ifdef HAVE_COREFOUNDATION
CFStringRef IFStrCpyCF(const IFMDChar* src) {
	int len;
	unsigned short int* utf16 = GetUTF16(src, &len);
	CFStringRef string;
	
	string = CFStringCreateWithCharacters(kCFAllocatorDefault, utf16, len);

	free(utf16);
	
	return string;
}

IFMDChar* IFMakeStrCF(const CFStringRef src) {
	/* UTF-16 to UCS-4 */
	IFMDChar* res;
	UniChar* buffer;
	int len = CFStringGetLength(src);
	int pos, x;
	
	CFRange r;
	
	/* Allocate buffers */
	buffer = malloc(sizeof(UniChar)*len); /* Always same length or shorter */
	res = malloc(sizeof(IFMDChar)*(len+1));
	
	r.location = 0; r.length = len;
	CFStringGetCharacters(src, r, buffer);
	
	/* Perform conversion */
	pos = 0;
	for (x=0; x<len; x++) {
		UniChar chr = buffer[x];
		
		if (chr >= 0xd800 && chr <= 0xdbff && (x+1)<len) {
			/* High surrogate */
			UniChar chr2 = buffer[++x];
			
			if (chr2 >= 0xdc00 && chr2 <= 0xdfff) {
				/* Low surrogate */
				res[pos++] = ((chr-0xd800)<<10) + (chr2-0xdfff) + 0x10000;
			}
		} else {
			res[pos++] = chr;
		}
	}
	
	/* Tidy up */
	res[pos] = 0;
	free(buffer);
	
	/* Return results */
	return res;
}
#endif

/* = Allocation functions = */

IFMetadata* IFMD_Alloc(void) {
	IFMetadata* md;
	
	md = malloc(sizeof(IFMetadata));
	
	md->numberOfStories = md->numberOfErrors = md->numberOfIndexEntries = 0;
	md->stories = NULL;
	md->error   = NULL;
	md->index   = NULL;
	
	return md;
}

IFMDStory* IFStory_Alloc(void) {
	IFMDStory* st;
	
	st = malloc(sizeof(IFMDStory));
	
	st->numberOfIdents = 0;
	st->idents = NULL;
	st->error = 0;
	
	st->data.title = NULL;
	st->data.headline = NULL;
	st->data.author = NULL;
	st->data.genre = NULL;
	st->data.year = 0;
	st->data.group = NULL;
	st->data.zarfian = IFMD_Unrated;
	st->data.teaser = NULL;
	st->data.comment = NULL;
	st->data.rating = -1.0;
	
	return st;
}

IFMDIdent* IFID_Alloc(void) {
	IFMDIdent* id;
	
	id = malloc(sizeof(IFMDIdent));
	
	id->format = IFFormat_Unknown;
	id->dataFormat = IFFormat_Unknown;
	id->usesMd5 = 0;
	
	return id;
}

/* = Copying = */
void IFIdent_Copy(IFMDIdent* dst, const IFMDIdent* src) {
	*dst = *src;
}

void IFStory_Copy(IFMDStory* dst, const IFMDStory* src) {
	IFStory_Free(dst);

	/* Idents, etc */
	dst->error = src->error;
	dst->numberOfIdents = src->numberOfIdents;
	
	if (src->numberOfIdents > 0) {
		int x;
		
		dst->idents = malloc(sizeof(IFMDIdent)*src->numberOfIdents);
		
		for (x=0; x<src->numberOfIdents; x++) {
			IFIdent_Copy(dst->idents + x, src->idents + x);
		}
	} else {
		dst->idents = NULL;
	}
	
	/* Data */
	dst->data.title = Xcopy(src->data.title);
	dst->data.headline = Xcopy(src->data.headline);
	dst->data.author = Xcopy(src->data.author);
	dst->data.genre = Xcopy(src->data.genre);
	dst->data.group = Xcopy(src->data.group);
	dst->data.teaser = Xcopy(src->data.teaser);
	dst->data.comment = Xcopy(src->data.comment);
	
	dst->data.year = src->data.year;
	dst->data.zarfian = src->data.zarfian;
	dst->data.rating = src->data.rating;
}

/* = Modification functions = */
void IFMD_AddStory(IFMetadata* data, IFMDStory* newStory) {
	int x;
	IFMDStory* newEntry;
	
	/* Add story to the list */
	if (!(newStory >= data->stories && newStory < (data->stories + data->numberOfStories))) {
		/* Story doesn't exist yet */
		IFMDStory template;
		
		template.numberOfIdents = 0;
		template.idents = NULL;
		template.error = 0;
		
		template.data.title = NULL;
		template.data.headline = NULL;
		template.data.author = NULL;
		template.data.genre = NULL;
		template.data.year = 0;
		template.data.group = NULL;
		template.data.zarfian = IFMD_Unrated;
		template.data.teaser = NULL;
		template.data.comment = NULL;
		template.data.rating = -1.0;		
		
		data->numberOfStories++;
		data->stories = realloc(data->stories, sizeof(IFMDStory)*data->numberOfStories);
		
		data->stories[data->numberOfStories-1] = template;
		IFStory_Copy(data->stories + (data->numberOfStories-1), newStory);
		
		newEntry = data->stories + (data->numberOfStories-1);
	} else {
		newEntry = newStory;
	}
	
	/* Add story to the index, remove any idents that appear twice */
	for (x=0; x<newStory->numberOfIdents; x++) {
		int top, bottom, res, cmp;
		IFMDIdent* id = newStory->idents + x;
		
		bottom = 0;
		top = data->numberOfIndexEntries-1;
		res = -1;
		
		while (bottom < top) {
			int middle = (bottom + top)>>1;
			cmp = IFID_Compare(data->index[middle].ident, id);
			
			if (cmp == 0) { res = middle; break; }
			else if (cmp < 0) bottom = middle+1;
			else if (cmp > 0) top    = middle-1;
		}
		
		if (bottom == top && IFID_Compare(id, data->index[bottom].ident) == 0) res = bottom;
		
		if (res != -1) {
			if ((data->stories + data->index[res].storyNum) != newEntry) {
				int storyId, y;
				IFMDStory* thisStory = data->stories + data->index[res].storyNum;
				
				/* Delete this ident from the index */
				data->numberOfIndexEntries--;
				memmove(data->index+res,
						data->index+res+1,
						sizeof(IFMDIndexEntry)*(data->numberOfIndexEntries-res));
				
				/* Delete this ident from its story */
				storyId = -1;
				
				for (y=0; y<thisStory->numberOfIdents; y++) {
					if (thisStory->idents + y == id) storyId = y;
				}
				
				if (storyId >= 0) {
					thisStory->numberOfIdents--;
					memmove(thisStory->idents+storyId,
							thisStory->idents+storyId+1,
							sizeof(IFMDIdent)*(thisStory->numberOfIdents-storyId));
					
					if (thisStory->numberOfIdents == 0) {
						/* Used to do this: */
						/* thisStory->error = 1; */ /* Won't be saved/indexed any more */
						/* Was simple, and slightly problematic for what I want to do */
						/* Ergo, must delete this story from the list */
						int storyNum;
						
						/* thisStory must be in data->stories */
						storyNum = thisStory - data->stories;
						
						if (storyNum < 0 || storyNum >= data->numberOfStories) {
							/* Subtly handle this error condition */
							abort(); /* BLEAAARRRGH */
						}
						
						/* Move newEntry if required */
						if (newEntry > thisStory) newEntry--;
						
						if (newEntry == thisStory) {
							/* Programmer is a spoon */
							abort();
						}
						
						/* Rearrange the stories */
						data->numberOfStories--;
						memmove(data->index+storyNum,
								data->index+storyNum+1,
								sizeof(IFMDIndexEntry)*(data->numberOfStories-storyNum));						
					}
				}
			}
		}
		
		/* Add this ident to the index */
		if (top >= data->numberOfIndexEntries) top = data->numberOfIndexEntries-1;
		
		res = top;
		if (res < 0) res = 0;
		
		if (data->numberOfIndexEntries > 0)
			cmp = IFID_Compare(id, data->index[res].ident); 
		else
			cmp = 0;
		
		if (cmp > 0) {
			res++;
		}
		
		/* Res should now be equal to the first place where cmp = 1 */
		data->numberOfIndexEntries++;
		data->index = realloc(data->index, sizeof(IFMDIndexEntry)*data->numberOfIndexEntries);
		memmove(data->index+res + 1, data->index+res, sizeof(IFMDIndexEntry)*(data->numberOfIndexEntries-res-1));
		
		data->index[res].storyNum = newEntry - data->stories;
		data->index[res].ident = newEntry->idents + x;
	}
	
	return;
}
