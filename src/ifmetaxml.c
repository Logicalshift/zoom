/*
 *  ifmetaxml.c
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 04/04/2006.
 *  Copyright 2006 Andrew Hunter. All rights reserved.
 *
 */

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>

#include <expat.h>

#include "ifmetaxml.h"

#ifndef XMLCALL
/* Not always defined? */
# define XMLCALL
#endif

/* The XML parser function declarations */
static XMLCALL void StartElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts);
static XMLCALL void EndElement  (void *userData,
								 const XML_Char *name);
static XMLCALL void CharData    (void *userData,
								 const XML_Char *s,
								 int len);

/* The parser state structure */
typedef struct IFXmlTag {
	IFChar* value;
	XML_Char* name;
	int failed;
	
	struct IFXmlTag* parent;
} IFXmlTag;

typedef struct IFXmlState {
	XML_Parser parser;
	IFMetabase meta;
	
	int failed;				/* Set to 1 if the parsing suffers a fatal error */
	
	int version;			/* 090 or 100, or 0 if no <ifindex> tag has been encountered */
	IFStory story;			/* The current story that we're reading entries for */
	
	IFXmlTag* tag;			/* The current topmost tag */
} IFXmlState;

/* Load the records contained in the specified */
void IF_ReadIfiction(IFMetabase meta, const unsigned char* xml, size_t size) {
	XML_Parser theParser;
	IFXmlState* currentState;
	
	/* Construct the parser state structure */
	currentState = malloc(sizeof(IFXmlState));
	
	currentState->meta = meta;
	currentState->failed = 0;
	currentState->version = 0;
	currentState->story = NULL;
	
	/* Begin parsing */
	theParser = XML_ParserCreate(NULL);
	currentState->parser = theParser;

	XML_SetElementHandler(theParser, StartElement, EndElement);
	XML_SetCharacterDataHandler(theParser, CharData);
	XML_SetUserData(theParser, currentState);
	
	/* Ready? Go! */
	XML_Parse(theParser, (const char*)xml, size, 1);
}

/* Some string utility functions */

static unsigned char bytesFromUTF8[256] = {
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5};

/* Compare an XML string against a C string */
static int XCstrcmp(const XML_Char* a, const char* b) {
	int x;
	
	for (x=0; a[x] != 0 && b[x] != 0; x++) {
		if (a[x] < (unsigned char)b[x]) return -1;
		if (a[x] > (unsigned char)b[x]) return 1;
	}
	
	if (a[x] < (unsigned char)b[x]) return -1;
	if (a[x] > (unsigned char)b[x]) return 1;
	
	return 0;
}

/* Converts s to IFChars. Result needs to be freed */
static int Xstrlen(const XML_Char* a) {
	int x;
	
	if (a == NULL) return 0;
	
	for (x=0; a[x] != 0; x++);
	
	return x;
}

static IFChar* Xmdchar(const XML_Char* s, int len) {
	int x, pos;
	IFChar* res;
	
	if (len < 0) len = Xstrlen(s);
	
	res = malloc(sizeof(IFChar)*(len+1));
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
	
	res[pos++] = 0;
	
	return res;
}

/* Error handling/reporting */

static void Error(IFXmlState* state, IFXmlError errorType, void* errorData) {
	printf("ERROR: %i\n", errorType);
}

/* The XML parser itself */

static XMLCALL void StartElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts) {
	IFXmlState* state;
	int x;
	IFXmlTag* tag;
	XML_Char* parent;
	
	printf("%s\n", name);
	
	/* Get the state */
	state = (IFXmlState*)userData;
	
	if (state->tag) {
		parent = state->tag->name;
	} else {
		parent = "";
	}
	
	/* Put this tag onto the tag stack */
	tag = malloc(sizeof(IFXmlTag));

	tag->value = malloc(sizeof(IFChar));
	tag->value[0] = 0;
	tag->name = malloc(sizeof(char)*(strlen(name)+1));
	strcpy(tag->name, name);
	
	tag->parent = state->tag;
	if (tag->parent) {
		tag->failed = tag->parent->failed;
	} else {
		tag->failed = 0;
	}
	
	state->tag = tag;

	/* Do nothing else if the parse has failed fatally for some reason */
	if (state->failed) return;
	
	/* The action we take depends on the current state and the next token */
	if (state->version == 0) {
		if (XCstrcmp(name, "ifindex") != 0) {
			Error(state, IFXmlNotIfiction, NULL);
			state->failed = 1;
			return;
		}
		
		/* How the file is parsed depends on the version number that's supplied */
		for (x=0; atts[x] != NULL; x+=2) {
			if (XCstrcmp(atts[x], "version") == 0) {
				double version;
				
				version = strtod(atts[x+1], NULL);
				state->version = version * 100;
			}
		}

		if (state->version == 0) {
			Error(state, IFXmlNoVersionSupplied, NULL);
			state->failed = 1;
		} else if (state->version > 100) {
			Error(state, IFXmlVersionIsTooRecent, NULL);
			state->failed = 1;
		}
	} else if (XCstrcmp(name, "br") == 0) {
		/* 'br' tags are allowed anywhere and just add a newline to the tag value */
		if (state->tag->parent) {
			int valueLen = IFMB_StrLen(state->tag->parent->value);
			
			state->tag->parent->value = realloc(state->tag->parent->value, sizeof(IFChar)*(valueLen+2));
			
			state->tag->parent->value[valueLen] = '\n';
			state->tag->parent->value[valueLen+1] = 0;
		}
	} else if (state->version == 90) {
		
		/* == Version 0.9 identification and data format == */

		if (state->tag->failed) {
			/* Just ignore 'failed' tags */
		} else if (XCstrcmp(parent, "ifindex") == 0) {
			/* Tags under the 'ifindex' root tag */
			if (XCstrcmp(name, "story") == 0) {
				/* Start of a story */
			} else {
				/* Unknown tag */
				Error(state, IFXmlUnrecognisedTag, NULL);
				state->tag->failed = 1;
			}
		} else if (XCstrcmp(parent, "story") == 0) {
			/* Tags under the 'story' tag */
			if (XCstrcmp(name, "identification") == 0 || XCstrcmp(name, "id") == 0) {
				/* Start of an identification chunk */
			} else if (XCstrcmp(name, "title") == 0) {
			} else if (XCstrcmp(name, "headline") == 0) {
			} else if (XCstrcmp(name, "author") == 0) {
			} else if (XCstrcmp(name, "genre") == 0) {
			} else if (XCstrcmp(name, "year") == 0) {
			} else if (XCstrcmp(name, "group") == 0) {
			} else if (XCstrcmp(name, "zarfian") == 0) {
			} else if (XCstrcmp(name, "teaser") == 0) {
			} else if (XCstrcmp(name, "comment") == 0) {
			} else if (XCstrcmp(name, "rating") == 0) {
			} else if (XCstrcmp(name, "description") == 0) {
			} else if (XCstrcmp(name, "coverpicture") == 0) {
			} else if (XCstrcmp(name, "auxiliary") == 0) {
			} else {
				/* Unknown tag */
				Error(state, IFXmlUnrecognisedTag, NULL);
				state->tag->failed = 1;
			}
		}
	} else {
		
		/* == Version 1.0 identification and data format == */
		
	}
}

static XMLCALL void EndElement(void *userData,
							   const XML_Char *name) {
	IFXmlState* state;
	IFXmlTag* tag;
	int pos, whitePos;
	
	/* Get the state */
	state = (IFXmlState*)userData;
	if (state->failed) return;
	if (state->tag == NULL) return;
	
	if (XCstrcmp(state->tag->name, name) != 0) {
		/* Mismatched tags */
		Error(state, IFXmlMismatchedTags, NULL);
		state->tag->failed = 1;
	}
	
	/* Trim out whitespace for the current tag */
	pos = whitePos = 0;
	
	printf("  \"");
	while (state->tag->value[whitePos] == ' ') whitePos++;
	while (state->tag->value[whitePos] != 0) {
		state->tag->value[pos++] = state->tag->value[whitePos];
		printf("%c", state->tag->value[pos-1]);

		if (state->tag->value[whitePos] == ' ' || state->tag->value[whitePos] == '\n') {
			whitePos++;
			while (state->tag->value[whitePos] == ' ') whitePos++;
		} else {
			whitePos++;
		}
	}
	printf("\"\n/%s\n", name);
	
	if (pos > 0 && state->tag->value[pos-1] == ' ') pos--;
	state->tag->value[pos] = 0;

	/* Perform an action on this tag */
	if (!state->tag->failed) {
		if (XCstrcmp(name, "br") == 0) {
			/* br tags are supported anywhere */
		} else if (state->version == 90) {
			
			/* == Handle version 0.90 tags == */
			
		} else {
			
			/* == Handle version 1.00 tags == */
			
		}
	}
	
	/* Pop this tag from the stack */
	tag = state->tag;
	state->tag = tag->parent;
	
	free(tag->value);
	free(tag->name);
	free(tag);
}

static XMLCALL void CharData(void *userData,
							 const XML_Char *s,
							 int len) {
	IFXmlState* state;
	int valueLen, charDataLen, x;
	IFChar* charData;
	
	/* Get the state */
	state = (IFXmlState*)userData;
	if (state->failed) return;
	if (state->tag == NULL) return;
	if (state->tag->failed) return;
	
	/* Append the character data for the current tag */
	charData = Xmdchar(s, len);
	charDataLen = IFMB_StrLen(charData);
	valueLen = IFMB_StrLen(state->tag->value);
	
	state->tag->value = realloc(state->tag->value, sizeof(IFChar)*(valueLen+charDataLen+1));
	
	for (x=0; x<charDataLen; x++) {
		IFChar c = charData[x];
		
		/* All whitespace characters become spaces */
		if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
			state->tag->value[valueLen+x] = ' ';
		} else {
			state->tag->value[valueLen+x] = charData[x];
		}
	}
	
	state->tag->value[valueLen+charDataLen] = 0;
	
	/* Tidy up after ourselves */
	free(charData);
}
