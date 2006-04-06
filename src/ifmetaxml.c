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
	
	int failed;					/* Set to 1 if the parsing suffers a fatal error */
	
	int version;				/* 090 or 100, or 0 if no <ifindex> tag has been encountered */
	
	IFXmlTag* tag;				/* The current topmost tag */
	
	IFID storyId;				/* The identification chunks to attach to the current story, once we've finished building it */
	IFStory story;				/* The story that we're building */
	
	IFMetabase tempMetabase;	/* A temporary metabase that we put half-built stories into */
	IFID tempId;				/* The ID of a temporary story */
	
	int release;				/* For 0.9 zcode IDs: the release # */
	char serial[6];				/* For 0.9 zcode IDs: the serial # */
	int checksum;				/* For 0.9 zcode IDs: the checksum */
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
		
	currentState->storyId = NULL;
	currentState->story = NULL;
	
	currentState->tempMetabase = IFMB_Create();
	currentState->tempId = IFMB_GlulxIdNotInform(0, 0);
	
	/* Begin parsing */
	theParser = XML_ParserCreate(NULL);
	currentState->parser = theParser;

	XML_SetElementHandler(theParser, StartElement, EndElement);
	XML_SetCharacterDataHandler(theParser, CharData);
	XML_SetUserData(theParser, currentState);
	
	/* Ready? Go! */
	XML_Parse(theParser, (const char*)xml, size, 1);
	
	/* Clear up any temp stuff we may have created */
	if (currentState->storyId) IFMB_FreeId(currentState->storyId);
	IFMB_FreeId(currentState->tempId);
	IFMB_Free(currentState->tempMetabase);
	
	free(currentState);
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

/* Converts 's' to simple ASCII. The return value must be freed */
static char* Xascii(const IFChar* s) {
	char* res;
	int x;
	int len = IFMB_StrLen(s);
	
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
	printf("**** ERROR: %i\n", errorType);
}

/* The XML parser itself */

static XMLCALL void StartElement(void *userData,
								 const XML_Char *name,
								 const XML_Char **atts) {
	IFXmlState* state;
	int x;
	IFXmlTag* tag;
	XML_Char* parent;
	
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
				if (state->storyId != NULL) {
					IFMB_FreeId(state->storyId);
					state->storyId = NULL;
				}
				
				IFMB_RemoveStoryWithId(state->tempMetabase, state->tempId);
				state->story = IFMB_GetStoryWithId(state->tempMetabase, state->tempId);
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
		} else if (XCstrcmp(parent, "identification") == 0 || XCstrcmp(parent, "id") == 0) {
			if (XCstrcmp(name, "zcode") == 0) {
				int x;
				
				for (x=0; x<6; x++) state->serial[x] = '-';
				state->release = -1;
				state->checksum = -1;
				
			} else if (XCstrcmp(name, "format") == 0) {
			} else {
				Error(state, IFXmlUnrecognisedTag, NULL);
				state->tag->failed = 1;
			}
		} else if (XCstrcmp(parent, "zcode") == 0) {
			if (XCstrcmp(name, "release") == 0) {
			} else if (XCstrcmp(name, "serial") == 0) {
			} else if (XCstrcmp(name, "checksum") == 0) {
			} else {
				Error(state, IFXmlUnrecognisedTag, NULL);
			}
		} else {
			Error(state, IFXmlUnrecognisedTag, NULL);
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
	XML_Char* parent;
	IFChar* value;
	
	/* Get the state */
	state = (IFXmlState*)userData;
	if (state->failed) return;
	if (state->tag == NULL) return;
	
	if (XCstrcmp(state->tag->name, name) != 0) {
		/* Mismatched tags */
		Error(state, IFXmlMismatchedTags, NULL);
		state->tag->failed = 1;
	}
	
	if (state->tag->parent) {
		parent = state->tag->parent->name;
	} else {
		parent = "";
	}
	
	/* Trim out whitespace for the current tag */
	pos = whitePos = 0;
	
	while (state->tag->value[whitePos] == ' ') whitePos++;
	while (state->tag->value[whitePos] != 0) {
		state->tag->value[pos++] = state->tag->value[whitePos];

		if (state->tag->value[whitePos] == ' ' || state->tag->value[whitePos] == '\n') {
			whitePos++;
			while (state->tag->value[whitePos] == ' ') whitePos++;
		} else {
			whitePos++;
		}
	}
	
	if (pos > 0 && state->tag->value[pos-1] == ' ') pos--;
	state->tag->value[pos] = 0;
	
	value = state->tag->value;

	/* Perform an action on this tag */
	if (!state->tag->failed) {
		if (XCstrcmp(name, "br") == 0) {
			/* br tags are supported anywhere */
		} else if (state->version == 90) {
			
			/* == Handle version 0.90 tags == */
			
			if (XCstrcmp(parent, "identification") == 0 || XCstrcmp(parent, "id") == 0) {
				/* An identification section */
				if (XCstrcmp(name, "zcode") == 0) {
					/* End of a ZCode ID */
					if (state->release < 0) {
						Error(state, IFXmlBadZcodeSection, NULL);
					} else {
						IFID newId;
						
						newId = IFMB_ZcodeId(state->release, state->serial, state->checksum);
						
						if (state->storyId == NULL) {
							state->storyId = newId;
						} else {
							IFID ids[2];
							IFID compoundId;
							
							ids[0] = newId;
							ids[1] = state->storyId;
							
							compoundId = IFMB_CompoundId(2, ids);
							
							IFMB_FreeId(newId);
							IFMB_FreeId(state->storyId);
							
							state->storyId = compoundId;
						}
					}
				}
			} else if (XCstrcmp(parent, "zcode") == 0) {
				/* zcode identification section */
				
				if (XCstrcmp(name, "serial") == 0) {
					int x;
					
					for (x=0; x<6 && value[x] != 0; x++) {
						state->serial[x] = value[x];
					}
				} else if (XCstrcmp(name, "release") == 0) {
					char* release = Xascii(value);
					
					state->release = atoi(release);
					
					free(release);
				} else if (XCstrcmp(name, "checksum") == 0) {
					char* checksum = Xascii(value);
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
					
					state->checksum = val;
					
					free(checksum);
				}
			} else if (XCstrcmp(parent, "story") == 0) {
				/* Story data (or identification, which we ignore) */
				char* key = NULL;
				
				if (XCstrcmp(name, "title") == 0) {
					key = "bibliographic.title";
				} else if (XCstrcmp(name, "headline") == 0) {
					key = "bibliographic.headline";
				} else if (XCstrcmp(name, "author") == 0) {
					key = "bibliographic.author";
				} else if (XCstrcmp(name, "genre") == 0) {
					key = "bibliographic.genre";
				} else if (XCstrcmp(name, "year") == 0) {
					key = "bibliographic.firstpublished";
				} else if (XCstrcmp(name, "group") == 0) {
					key = "bibliographic.group";
				} else if (XCstrcmp(name, "zarfian") == 0) {
					key = "bibliographic.forgiveness";
				} else if (XCstrcmp(name, "teaser") == 0) {
					key = "zoom.teaser";
				} else if (XCstrcmp(name, "comment") == 0) {
					key = "zoom.comment";
				} else if (XCstrcmp(name, "rating") == 0) {
					key = "zoom.rating";
				} else if (XCstrcmp(name, "description") == 0) {
					key = "bibliographic.description";
				} else if (XCstrcmp(name, "coverpicture") == 0) {
					key = "zcode.coverpicture";
				} else if (XCstrcmp(name, "auxiliary") == 0) {
					key = "resources.auxiliary";
				}
				
				if (key != NULL && state->story != NULL) {
					IFMB_SetValue(state->story, key, value);
				}
			} else if (XCstrcmp(parent, "ifindex") == 0) {
				
				if (XCstrcmp(name, "story") == 0) {
					/* End of story: copy it into the main metabase */
					if (state->storyId != NULL) {
						IFMB_CopyStory(state->meta, state->story, state->storyId);
						
						IFMB_FreeId(state->storyId);
						state->storyId = NULL;
					} else {
						Error(state, IFXmlStoryWithNoId, NULL);
					}
				}
			}
			
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
