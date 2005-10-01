/*
 *  ifmetabase.c
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 20/08/2005.
 *  Copyright 2005 Andrew Hunter. All rights reserved.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ifmetabase.h"

/* Concrete data structure definitions */

typedef struct IFMDRecord IFMDRecord;

typedef struct IFMetabaseIndexEntry {
	IFMDKey key;
	int recordNumber;
} *IFMetabaseIndexEntry;

struct IFMetabase {
	IFMetabase parent;									/* The parent of this metabase */
	
	const int** modules;								/* Module names associated with this metabase */
	int numModules;
	int exclusive;										/* If 0, modules indicates the modules that are INCLUDED in this metabase, if 1, those that are excluded. Excluded modules are not represented in entries from this metabase */
	
	IFMDRecord** records;								/* Unordered array of records */
	int numRecords;										/* Number of records */
	
	int readOnly;										/* If 1, it's an error to do anything that alters this metabase or an entry in it */
	
	IFMetabaseIndexEntry* keyIndex;						/* Ordered array mapping keys to records */
	int numKeys;										/* Number of keys */
};

struct IFMDKey {
	/* Format of the game */
	enum IFMDFormat format;
	
	enum {
		IFMDKeyZCode,

		IFMDKeyMD5,
		IFMDKeyURI,
		IFMDKeyUUID
	} type;
	
	/* ID for specific key types */
	union
	{
		struct
		{
			unsigned char serial[6];
			int release;
			int checksum;
		} zcode;
		
		struct {
			unsigned char md5[16];
		} md5;
		
		struct {
			char* uri;
		} uri;
		
		struct {
			char uuid[16];
		} uuid;
	} specific;
};

typedef struct IFMDField IFMDField;
struct IFMDField {
	const int* module;						/* The module URI for this field */
	int*  name;								/* Name of this field. Root field has no name. */
	int   isDataField;						/* 1 if this field actually contains binary data, 0 if a UCS-4 string */
	void* data;								/* Data for this field, usually a string */
	
	IFMDField** subfields;					/* Subfields, if any, ordered by name */
	int numSubfields;						/* Number of subfields for this field */
	
	int* flattened;							/* Cached version of what this field looks like with subfields flattened */
	
	IFMDField* parent;						/* The field that contains this field */
	IFMDRecord* record;						/* The record that contains this field */
};

struct IFMDEntry {
	IFMetabase metabase;					/* Metabase this entry is from */
	int record;								/* Record this entry refers to */
	
	IFMDEntry previous;						/* Entry in a previous metabase */
};

struct IFMDRecord {
	IFMetabase belongsTo;					/* The metabase this record belongs to */
	
	IFMDKey* keys;							/* The keys that refer to this entry */
	int numKeys;							/* The number of keys that this entry contains */
	
	IFMDField field;						/* One single initial field, containing modules as sub-fields */
};

/* Initialisation */

void metabase_init(void) {
	/* Standard module namespaces */
	int* base, *feelies, *comments, *resources, *review;
	
	base = metabase_ucs4("http://www.logicalshift.org.uk/IF/metadata/");
	feelies = metabase_ucs4("http://www.logicalshift.org.uk/IF/metadata/feelies/");
	comments = metabase_ucs4("http://www.logicalshift.org.uk/IF/metadata/comments/");
	resources = metabase_ucs4("http://www.logicalshift.org.uk/IF/metadata/resources/");
	review = metabase_ucs4("http://www.logicalshift.org.uk/IF/metadata/review/");
	
	metabase_associate_module(base, "base");
	metabase_associate_module(feelies, "feelies");
	metabase_associate_module(comments, "comments");
	metabase_associate_module(resources, "resources");
	metabase_associate_module(review, "review");
	
	/* Clean up */
	metabase_free(base);
	metabase_free(feelies);
	metabase_free(comments);
	metabase_free(resources);
	metabase_free(review);
}

/* Metabase callbacks - implement elsewhere */

void metabase_error(enum IFMDError errorCode, const char* simple_description, ...) {
	printf("(FIXME: THIS ERROR SHOULD BE ELSEWHERE). Metabase error: %s\n", simple_description);
	abort();
}

void metabase_caution(enum IFMDError errorCode, const char* simple_description, ...) {
	printf("(FIXME: THIS ERROR SHOULD BE ELSEWHERE). Metabase warning: %s\n", simple_description);
}

/* Memory functions (re-implement these if you have a non-ANSI system) */

void* metabase_alloc(size_t bytes) {
	void* res;
	
	res = malloc(bytes);
	if (res == NULL) metabase_error(IFMDE_FailedToAllocateMemory, "Failed to allocate memory");

	return res;
}

void* metabase_realloc(void* ptr, size_t bytes) {
	void* res;
	
	res = realloc(ptr, bytes);
	if (res == NULL) metabase_error(IFMDE_FailedToAllocateMemory, "Failed to allocate memory");
	
	return res;
}

void metabase_free(void* ptr) {
	free(ptr);
}

void metabase_memmove(void* dst, const void* src, size_t size) {
	memmove(dst, src, size);
}

/* String convienience functions */

int metabase_strlen(const int* string) {
	int x = 0;
	
	while (string[x++] != 0);
	
	return x-1;
}

void metabase_strcpy(int* dst, const int* src) {
	int x = 0;
	
	while (src[x] != 0) {
		dst[x] = src[x];
		x++;
	}
}

int* metabase_strdup(const int* src) {
	int* dst = metabase_alloc(sizeof(int)*metabase_strlen(src));
	int x = 0;
	
	while (src[x] != 0) {
		dst[x] = src[x];
		x++;
	}
	
	return dst;
}

int metabase_strcmp(const int* a, const int* b) {
	int x = 0;
	
	while (a[x] != 0 && b[x] != 0 && a[x] == b[x]) x++;
	
	if (a[x] < b[x])
		return -1;
	else if (a[x] > b[x])
		return 1;
	else
		return 0;
}

char* metabase_utf8(const int* string) {
	char* res = NULL;
	int pos = 0;
	int len = 0;
	int x;
	
#define add(c) if (pos <= len) { len += 32; res = metabase_realloc(res, sizeof(char)*(len)); } res[pos++] = c
	
	for (x=0; string[x] != 0; x++) {
		int chr = string[x];
		
		if (chr < 0x20) {
			/* These are for the most part invalid */
			/* 
			Actually, according to the XML spec, they are fine, but expat complains and pain often 
			 results. This *will* prevent certain broken game files from indexing properly, and will
			 generally result in duplicate entries in these cases.
			 */
		} else if (chr < 0x80) {
			add(chr);
		} else if (chr < 0x800) {
			add(0xc0 | (chr>>6));
			add(0x80 | (chr&0x3f));
		} else if (chr < 0x10000) {
			add(0xe0 | (chr>>12));
			add(0x80 | ((chr>>6)&0x3f));
			add(0x80 | (chr&0x3f));
		} else if (chr < 0x200000) {
			add(0xf0 | (chr>>18));
			add(0x80 | ((chr>>12)&0x3f));
			add(0x80 | ((chr>>6)&0x3f));
			add(0x80 | (chr&0x3f));
		} else {
			/* These characters can't be represented by unicode anyway */
		}
	}
				
	add(0);
	return res;
}

/* Number of bytes each individual UTF-8 character encodes across */
static unsigned char bytesFromUTF8[256] = {
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5};

int* metabase_ucs4(const char* utf8) {
	int len = 0;
	int* res = NULL;
	int x = 0;
	int pos = 0;
	
	for (len=0; utf8[len]!=0; len++);
	res = metabase_alloc(sizeof(int)*len);
	
	for (x=0; x<len; x++) {
		int chr = (unsigned char)utf8[x];
		
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
				chrs[y] = (unsigned char)utf8[x+y];
				
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

/* Static utility functions */

static int binary_search(void** array, const void* obj, int count, int(*compare)(const void* a, const void* b)) {
	int top, middle, bottom;
	
	if (count <= 0) return -1;
	
	bottom = 0;
	top = count-1;
	
	while (bottom >= top) {
		int compareResult;
		
		/* Work out which object to compare */
		middle = (top+bottom)>>1;
		
		/* Perform the comparison */
		compareResult = compare(array[middle], obj);
		
		/* Return the result if equal, or move the top/bottom of the search range if not */
		if (compareResult == 0) {
			return middle;
		} else if (compareResult < 0) {
			bottom = middle+1;
		} else {
			top = middle-1;
		}
	}
	
	/* Return the first result that is larger than obj */
	if (top < 0) top = 0;
	
	while (top < count && compare(array[top], obj) < 0) top++;
	
	return top;
}

/* Describing metadata structure */

typedef struct IFMDModule {
	const int* namespace;
	const char* shortname;
} IFMDModule;

/* Indices, ordered */
static IFMDModule** modules_by_namespace = NULL;
static IFMDModule** modules_by_shortname = NULL;
static int modules_count = 0;

static int compare_module_namespace(const void* modA, const void* modB) {
	return metabase_strcmp(((IFMDModule*)modA)->namespace, (const int*)modB);
}

static int compare_module_shortname(const void* modA, const void* modB) {
	return strcmp(((IFMDModule*)modA)->shortname, (const char*)modB);
}

/* Associates a namespace with a module name */
void metabase_associate_module(const int* namespace, const char* shortname) {
	int namespace_storage_point = 0;
	int shortname_storage_point = 0;
	IFMDModule* new_module;
	
	if (namespace == NULL || shortname == NULL) {
		metabase_error(IFMDE_NULLReference, "Either a NULL namespace or shortname passed to metabase_associate_module");
		return;
	}
		
	/* Store by namespace, and then by shortname */
	namespace_storage_point = binary_search((void**)modules_by_namespace, namespace, modules_count, compare_module_namespace);
	shortname_storage_point = binary_search((void**)modules_by_shortname, shortname, modules_count, compare_module_shortname);
	
	/*
	 * Both the namespace and the shortname must not have been used before: anything else produces a caution, and results in
	 * this module not being used
	 */
	if (namespace_storage_point < modules_count && compare_module_namespace(modules_by_namespace[namespace_storage_point], namespace) == 0) {
		metabase_caution(IFMDE_NamespaceAlreadyInUse, "Namespace already in use: Each namespace may only be associated with one short name", namespace);
		return;
	}

	if (shortname_storage_point < modules_count && compare_module_shortname(modules_by_shortname[shortname_storage_point], shortname) == 0) {
		metabase_caution(IFMDE_ModuleNameAlreadyInUse, "Module name already in use: Each namespace may only be associated with one short name", shortname);
		return;
	}
	
	/* Make space for the new entry */
	modules_by_namespace = metabase_realloc(modules_by_namespace, sizeof(IFMDModule*)*(modules_count+1));
	modules_by_shortname = metabase_realloc(modules_by_shortname, sizeof(IFMDModule*)*(modules_count+1));
	
	if (namespace_storage_point < modules_count) {
		metabase_memmove(modules_by_namespace + namespace_storage_point + 1, 
						 modules_by_namespace + namespace_storage_point,
						 sizeof(IFMDModule*)*(modules_count-namespace_storage_point));
	}
	if (shortname_storage_point < modules_count) {
		metabase_memmove(modules_by_shortname + shortname_storage_point + 1, 
						 modules_by_shortname + shortname_storage_point,
						 sizeof(IFMDModule*)*(modules_count-shortname_storage_point));
	}
	
	/* Store the new entry */
	new_module = metabase_alloc(sizeof(IFMDModule));
	new_module->namespace = metabase_strdup(namespace);
	new_module->shortname = strdup(shortname);
	
	modules_by_namespace[namespace_storage_point] = modules_by_shortname[shortname_storage_point] = new_module;
}

/* Retrieves the module name to use for a specific namespace */
const char* metabase_module_for_namespace(const int* namespace) {
	int storage_point = 0;
	
	storage_point = binary_search((void**)modules_by_namespace, namespace, modules_count, compare_module_namespace);
	if (storage_point < modules_count && compare_module_namespace(modules_by_namespace[storage_point], namespace) == 0) {
		return NULL;
	}
	
	return modules_by_namespace[storage_point]->shortname;
}

/* Retrieves a namespace for a specific module */
const int* metabase_namespace_for_module(const char* module) {
	int storage_point = 0;
	
	storage_point = binary_search((void**)modules_by_shortname, module, modules_count, compare_module_shortname);
	if (storage_point < modules_count && compare_module_shortname(modules_by_shortname[storage_point], module) == 0) {
		return NULL;
	}
	
	return modules_by_shortname[storage_point]->namespace;
}

/* Creating metabases */

/* Creates a new, empty metabase */
IFMetabase metabase_create(IFMetabase parent) {
	IFMetabase result = metabase_alloc(sizeof(struct IFMetabase));
	
	result->parent = parent;

	result->modules = NULL;
	result->numModules = 0;
	result->exclusive = 1;
	
	result->records = NULL;
	result->numRecords = 0;
	
	result->readOnly = 0;
	
	result->keyIndex = NULL;
	result->numKeys = 0;
	
	return result;
}

/* Destroys an old, unworthy metabase */
void metabase_destroy(IFMetabase metabase) {
	/* Destroy the entries and the keys (IMPLEMENT ME) */
	
	/* Finally, kill it off */
	metabase_free(metabase);
}

/* Sets how a metabase is filtered (exclusive: modules are filtered out, inclusive: modules are filtered in) */
void metabase_filter(IFMetabase metabase, enum IFMDFilter filter_style) {
	if (filter_style == IFFilter_Exclusive) {
		metabase->exclusive = 1;
	} else {
		metabase->exclusive = 0;
	}
}

/* Adds a module to the list of filters for a metabase */

static int compare_strings(const void*a, const void*b) {
	return metabase_strcmp((const int*)a, (const int*)b);
}

/*
 * If the filter style is IF_inclusive, then data for this module is now presented (you'll get results for data from
 * this module in this metabase).
 * If the filter style is IF_exclusive, then data for this module is removed (you'll no longer get results for data from
 * this module)
 */
void metabase_add_filter(IFMetabase metabase, const char* module_name) {
	const int* module_namespace;
	int storage_pos = 0;
	
	module_namespace = metabase_namespace_for_module(module_name);
	
	/* Nothing to do if we've never heard about this namespace */
	if (module_namespace == NULL) return;
	
	/* Find where to add in the list of filters */
	storage_pos = binary_search((void**)metabase->modules, module_namespace, metabase->numModules, compare_strings);
	
	/* Duplicate modules are added multiple times (this is so that if we ever add a remove instruction, it'll match up with the number of adds) */
	metabase->modules = metabase_realloc(metabase->modules, sizeof(int*)*(metabase->numModules+1));
	
	if (storage_pos < metabase->numModules) {
		metabase_memmove(metabase->modules + storage_pos + 1, metabase->modules + storage_pos, sizeof(int*)*(metabase->numModules-storage_pos));
	}
	
	metabase->modules[storage_pos] = module_namespace;
}


/* Marks a metabase as read-only */
void metabase_set_readonly(IFMetabase metabase, int isReadOnly) {
	metabase->readOnly = isReadOnly!=0;
}

/* Returns 1 if a module is filtered from a particular metabase */
int metabase_is_filtered(IFMetabase metabase, const char* module_name) {
	const int* module_namespace;
	int storage_pos = 0;
	int found = 0;
	
	module_namespace = metabase_namespace_for_module(module_name);
	
	/* Nothing to do if we've never heard about this namespace */
	if (module_namespace == NULL) return !metabase->exclusive;

	/* Search for this module */
	storage_pos = binary_search((void**)metabase->modules, module_namespace, metabase->numModules, compare_strings);
	
	if (storage_pos < 0 || storage_pos >= metabase->numModules) {
		found = 0;
	} else {
		found = compare_strings(metabase->modules[storage_pos], module_namespace)==0;
	}
	
	if (metabase->exclusive)
		return found;
	else
		return !found;
}

/* Describing stories/story resources */

/* Creates a reference to a story with a specific type and MD5 */
IFMDKey metabase_story_with_md5(enum IFMDFormat format, const char* md5) {
	IFMDKey res;
	int x;
	
	res = metabase_alloc(sizeof(struct IFMDKey));
	
	res->type = IFMDKeyMD5;
	res->format = format;

	for (x=0; x<16; x++) {
		res->specific.md5.md5[x] = md5[x];
	}
	
	return res;
}

/* Creates a reference to a story existing at a specific URI */
IFMDKey metabase_story_with_uri(enum IFMDFormat format, const char* uri) {
	IFMDKey res;
	
	res = metabase_alloc(sizeof(struct IFMDKey));
	
	res->type = IFMDKeyURI;
	res->format = format;
	
	res->specific.uri.uri = metabase_alloc(sizeof(char)*(strlen(uri)+1));
	strcpy(res->specific.uri.uri, uri);
	
	return res;
}


/* Creates a reference to a story with a specific UUID (128 bits - 16 bytes) */
IFMDKey metabase_story_with_uuid(enum IFMDFormat format, const char* uuid) {
	IFMDKey res;
	int x;
	
	res = metabase_alloc(sizeof(struct IFMDKey));
	
	res->type = IFMDKeyUUID;
	res->format = format;
	
	for (x=0; x<16; x++) {
		res->specific.uuid.uuid[x] = uuid[x];
	}
}

/* Creates a reference to a story with a z-code identification. */
IFMDKey metabase_story_with_zcode(const char* serial, unsigned int release, unsigned int checksum) {
	IFMDKey res;
	int x;

	res = metabase_alloc(sizeof(struct IFMDKey));
	
	res->type = IFMDKeyZCode;
	res->format = IFFormat_ZCode;
	
	for (x=0; x<6; x++) {
		res->specific.zcode.serial[x] = serial[x];
	}
	res->specific.zcode.release = release;
	res->specific.zcode.checksum = checksum;
	
	return res;
}

/* Creates a copy of an IFMDKey */
IFMDKey metabase_copy_key(IFMDKey oldKey) {
	IFMDKey res;
	int x;
	
	res = metabase_alloc(sizeof(struct IFMDKey));
	
	res->type = oldKey->type;
	res->format = oldKey->format;
	
	switch (res->type) {
		case IFMDKeyMD5:
		case IFMDKeyZCode:
		case IFMDKeyUUID:
			res->specific = oldKey->specific;
			break;
			
		case IFMDKeyURI:
			res->specific.uri.uri = metabase_alloc(sizeof(char)*(strlen(oldKey->specific.uri.uri)+1));
			strcpy(res->specific.uri.uri, oldKey->specific.uri.uri);
			break;
		
		default:
			metabase_error(IFMDE_InvalidMDKey, "A key of an unknown type was passed to metabase_copy_keys");
			break;
	}
	
	return res;
}

/* Compares two IFMDKeys */
int metabase_compare_keys(IFMDKey key1, IFMDKey key2) {
	int x;
	unsigned char k1, k2;
	
	/* See if key types differ */
	if (key1->type < key2->type) {
		return -1;
	} else if (key1->type > key2->type) {
		return 1;
	}
	
	/* Compare based on the data the key represents */
	switch (key1->type) {
		case IFMDKeyMD5:
			for (x=0; x<16; x++) {
				k1 = key1->specific.md5.md5[x];
				k2 = key2->specific.md5.md5[x];
				
				if (k1 < k2) {
					return -1;
				} else if (k1 > k2) {
					return 1;
				}
			}
			break;
			
		case IFMDKeyZCode:
			if (key1->specific.zcode.release < key2->specific.zcode.release) {
				return -1;
			} else if (key1->specific.zcode.release > key2->specific.zcode.release) {
				return 1;
			} else if (key1->specific.zcode.checksum < key2->specific.zcode.checksum) {
				return -1;
			} else if (key1->specific.zcode.checksum > key2->specific.zcode.checksum) {
				return 1;
			}
			
			for (x=0; x<6; x++) {
				k1 = key1->specific.zcode.serial[x];
				k2 = key2->specific.zcode.serial[x];
				
				if (k1 < k2) {
					return -1;
				} else if (k1 > k2) {
					return 1;
				}				
			}
			break;
			
		case IFMDKeyURI:
			for (x=0; key1->specific.uri.uri[x] != 0 && key2->specific.uri.uri[x] != 0; x++) {
				k1 = key1->specific.uri.uri[x];
				k2 = key2->specific.uri.uri[x];
				
				if (k1 < k2) {
					return -1;
				} else if (k1 > k2) {
					return 1;
				}				
			}

			k1 = key1->specific.uri.uri[x];
			k2 = key2->specific.uri.uri[x];
			
			if (k1 < k2) {
				return -1;
			} else if (k1 > k2) {
				return 1;
			}				
			break;
			
		case IFMDKeyUUID:
			for (x=0; x<16; x++) {
				k1 = key1->specific.uuid.uuid[x];
				k2 = key2->specific.uuid.uuid[x];
				
				if (k1 < k2) {
					return -1;
				} else if (k1 > k2) {
					return 1;
				}				
			}
			break;
			
		default:
			metabase_error(IFMDE_InvalidMDKey, "A key of an unknown type was passed to metabase_compare_keys");
	}
	
	return 0;
}

/* Gets the format associated with a key */
enum IFMDFormat metabase_format_for_key(IFMDKey key) {
	return key->format;
}

/* Frees up the memory associated with a metabase key */
void metabase_destroy_key(IFMDKey oldKey) {
	switch (oldKey->type) {
		case IFMDKeyURI:
			/* Have to destroy the URI string */
			free(oldKey->specific.uri.uri);
			break;
		
		default:
			/* Nothing to do */
			break;
	}
	
	free(oldKey);
}

/* Storing metadata */

/* Compares a IFMetabaseIndexEntry to a IFMDKey */
static int key_index_to_key_compare(const void* a_indexEntry, const void* b_mdKey) {
	const struct IFMetabaseIndexEntry* entry;
	const struct IFMDKey* key;
	
	entry = a_indexEntry;
	key = b_mdKey;
	
	return metabase_compare_keys(entry->key, (IFMDKey)key);
}

/* Makes a copy of an entry (used to copy entries out of the metabase) */
void metabase_copy_entry(IFMDEntry dest, IFMDEntry src) {
}

/* Gets an entry for a specific key (entries may be created if they don't exist yet) */
IFMDEntry metabase_entry_for_key(IFMetabase metabase, IFMDKey key) {
	IFMDEntry result = NULL;
	int entryNumber = 0;
	
	if (metabase == NULL) return NULL;
	
	/* Search for the entry in the entry index */
	if (metabase->keyIndex != NULL) {
		entryNumber = binary_search((void**)metabase->keyIndex, 
									key,
									metabase->numKeys,
									key_index_to_key_compare);
	}
	
	/* See if we've found a pre-existing entry */
	if (entryNumber >= 0 && entryNumber < metabase->numKeys && key_index_to_key_compare(metabase->keyIndex[entryNumber], key) == 0) {
		/* Allocate the result */
		result = metabase_alloc(sizeof(struct IFMDEntry));
		
		result->metabase = metabase;
		result->record = metabase->keyIndex[entryNumber]->recordNumber;
		result->previous = metabase_entry_for_key(metabase->parent, key);
	} else if (!metabase->readOnly) {
		/* Construct a record for this key */
		IFMDRecord* newRecord = metabase_alloc(sizeof(IFMDRecord));
		
		newRecord->belongsTo = metabase;
		newRecord->numKeys = 1;
		newRecord->keys = metabase_alloc(sizeof(IFMDKey*));
		newRecord->keys[0] = metabase_copy_key(key);
		
		newRecord->field.name = NULL;
		newRecord->field.isDataField = 0;
		newRecord->field.data = NULL;
		newRecord->field.subfields = NULL;
		newRecord->field.numSubfields = 0;
		newRecord->field.flattened = NULL;
		newRecord->field.parent = NULL;
		newRecord->field.record = newRecord;
		
		metabase->numRecords++;
		metabase->records = metabase_realloc(metabase->records, sizeof(IFMDRecord*)*metabase->numRecords);
		metabase->records[metabase->numRecords-1] = newRecord;
		
		/* Insert an entry at the index we found with the binary search */
		metabase->keyIndex = metabase_realloc(metabase->keyIndex, sizeof(IFMetabaseIndexEntry)*(metabase->numKeys+1));
		metabase_memmove(metabase->keyIndex + entryNumber + 1, metabase->keyIndex + entryNumber, sizeof(IFMetabaseIndexEntry)*(metabase->numKeys - entryNumber));
		
		metabase->keyIndex[entryNumber] = metabase_alloc(sizeof(struct IFMetabaseIndexEntry));
		metabase->keyIndex[entryNumber]->key = metabase_copy_key(key);
		metabase->keyIndex[entryNumber]->recordNumber = metabase->numRecords-1;
		
		/* Allocate the result */
		result = metabase_alloc(sizeof(struct IFMDEntry));
		
		result->metabase = metabase;
		result->record = metabase->keyIndex[entryNumber]->recordNumber;
		result->previous = metabase_entry_for_key(metabase->parent, key);		
	} else {
		/* The key wasn't found, and this metabase was read-only: skip it */
		return metabase_entry_for_key(metabase->parent, key);
	}
		
	return result;
}

/* Given a key with an unknown (or uncertain) format and an entry indexed by that key, retrieves the format (which MAY still be unknown, but really shouldn't be) */
enum IFMDFormat metabase_format_for_entry_key(IFMDEntry entry, IFMDKey unknownKey) {
	int x;
	
	/* Scan for the key in the entry */
	while (entry != NULL) {
		/* Get the record */
		IFMDRecord* rec = entry->metabase->records[entry->record];
		
		/* Go through the keys until we find one that matches */
		for (x=0; x<rec->numKeys; x++) {
			/* If this key matches, return its format */
			if (metabase_compare_keys(unknownKey, rec->keys[x]) == 0) {
				return rec->keys[x]->format;
			}
		}
		
		/* Next entry */
		entry = entry->previous;
	}
	
	/* Default is an unknown key */
	return IFFormat_NoSuchKey;
}

/* Removes a key from the metabase (does not recurse) */
void metabase_remove_key(IFMetabase metabase, IFMDKey oldKey) {
	int entryNumber = 0;
	int x;
	IFMDRecord* rec;

	if (metabase == NULL) return;
	
	if (metabase->readOnly) {
		return;
	}

	/* Search for the entry in the entry index */
	if (metabase->keyIndex != NULL) {
		entryNumber = binary_search((void**)metabase->keyIndex, 
									oldKey,
									metabase->numKeys,
									key_index_to_key_compare);
	} else {
		return;
	}
	
	/* See if we've found a pre-existing entry */
	if (entryNumber >= 0 && entryNumber < metabase->numKeys && key_index_to_key_compare(metabase->keyIndex[entryNumber], oldKey) == 0) {
		/* Remove the key entry from the record */
		rec = metabase->records[metabase->keyIndex[entryNumber]->recordNumber];
		
		for (x=0; x<rec->numKeys; x++) {
			if (metabase_compare_keys(rec->keys[x], oldKey) == 0) {
				/* This is equivalent to oldKey: destroy it */
				metabase_destroy_key(rec->keys[x]);
				
				/* Remove the entry from the list of keys */
				metabase_memmove(rec->keys + x, rec->keys + x+1, sizeof(IFMDKey)*(rec->numKeys-x-1));
				rec->numKeys--;
				
				/* Continue loop starting from the following key */
				x--;
			}
		}
		
		/* FIXME: a record with no keys can never be accessed, so remove the record in this case */
		if (rec->numKeys <= 0) {
		}
		
		/* Remove this entry from the database */
		metabase_destroy_key(metabase->keyIndex[entryNumber]->key);
		metabase_free(metabase->keyIndex[entryNumber]);
		metabase->numKeys--;
		metabase_memmove(metabase->keyIndex + entryNumber, metabase->keyIndex + entryNumber, sizeof(IFMetabaseIndexEntry)*(metabase->numKeys-entryNumber));
	}
}

/* Associates an additional key with an entry */
void metabase_add_key(IFMDEntry entry, IFMDKey newKey) {
	int x;
	IFMDRecord* rec;
	int entryNumber = 0;
	IFMetabase metabase;
	
	if (entry == NULL) return;
	metabase = entry->metabase;
	
	/* Make no changes to a readonly metabase. We also do nothing for the invalid case of an entry without a metabase. */
	/* FIXME: maybe we should report the case of a metabase-less entry as an error */
	if (metabase == NULL || metabase->readOnly) {
		metabase_add_key(entry->previous, newKey);
		return;
	}
	
	/* If this key already exists in the index, then remove it from that record */
	/* Note that this might result in 'orphan' records */	
	metabase_remove_key(entry->metabase, newKey);
	
	/* Get the record associated with this entry */
	rec = entry->metabase->records[entry->record];
	
	/* Go through the keys until we find one that matches */
	for (x=0; x<rec->numKeys; x++) {
		/* If this key matches, then replace it with the new one */
		if (metabase_compare_keys(newKey, rec->keys[x]) == 0) {
			metabase_destroy_key(rec->keys[x]);
			rec->keys[x] = metabase_copy_key(newKey);
			break;
		}
	}
	
	/* If no match is found, then add a new key and index entry */
	if (x >= rec->numKeys) {
		/* Add a new key to the record */
		rec->numKeys++;
		rec->keys = metabase_realloc(rec->keys, sizeof(IFMDKey*)*rec->numKeys);
		rec->keys[rec->numKeys-1] = metabase_copy_key(newKey);
		
		/* Add a new index entry for this key */
		entryNumber = 0;
		if (metabase->keyIndex != NULL) {
			entryNumber = binary_search((void**)metabase->keyIndex, 
										newKey,
										metabase->numKeys,
										key_index_to_key_compare);
		}
		
		/* See if we've found a pre-existing entry */
		if (entryNumber >= 0 && entryNumber < metabase->numKeys && key_index_to_key_compare(metabase->keyIndex[entryNumber], newKey) == 0) {
			/* Finding a pre-existing entry here is an error: it can happen for two reasons - metabase_remove_key failed to do what it says on the tin, or there were two entries in the index (which should never happen) */
			metabase_error(IFMDE_AssertionFailed_FoundKeyThatShouldNotExist, "Assertion failed. Likely cause: metabase_remove_key failed to fully remove a key from the index, or a key appears multiple times in the index");
		} else {
			/* Add the entry at the position specified by entryNumber */
			metabase->keyIndex = metabase_realloc(metabase->keyIndex, sizeof(IFMetabaseIndexEntry)*(metabase->numKeys+1));
			metabase_memmove(metabase->keyIndex + entryNumber + 1, metabase->keyIndex + entryNumber, sizeof(IFMetabaseIndexEntry)*(metabase->numKeys - entryNumber));
			
			metabase->keyIndex[entryNumber] = metabase_alloc(sizeof(struct IFMetabaseIndexEntry));
			metabase->keyIndex[entryNumber]->key = metabase_copy_key(newKey);
			metabase->keyIndex[entryNumber]->recordNumber = entry->record;			
		}
	}
	
	/* Recurse to the entry in the parent metabase */
	metabase_add_key(entry->previous, newKey);
}

/* Compares a field with a module/name combination */
struct field_description {
	const int* module;
	int* name;
};

static int field_to_description_compare(const void* a_mdField, const void* b_fieldDescription) {
	const IFMDField* field = a_mdField;
	const struct field_description* desc = b_fieldDescription;
	
	/* Compare modules first */
	int moduleCompare = metabase_strcmp(field->module, desc->module);
		
	if (moduleCompare == 0) {
		/* Modules are the same: the field name defines the ordering */
		return metabase_strcmp(field->name, desc->name);
	} else {
		/* Modules are different: their names define the ordering */
		return moduleCompare;
	}
}

/* Finds the data for a specific field in a record */
struct found_field {
	IFMDField* parent;								/* Field that 'contains' the requested field */
	int offset;										/* The offset of the actual found field*/
};

static struct found_field find_field(IFMDEntry entry, const char* module, const char* field) {
	struct found_field result;
	IFMDRecord* record;
	const int* moduleURI;
	int* ucs4name;
	struct field_description fieldToFind;
	
	/* Standard result is no match */
	result.parent = NULL;
	result.offset = -1;
	
	/* Get the record associated with the entry */
	record = entry->metabase->records[entry->record];
	
	/* Get the module URI associated with this module, and convert the field name into UCS-4 */
	moduleURI = metabase_namespace_for_module(module);
	ucs4name = metabase_ucs4(field);
	
	/* Fields have the format name.name.name@attribute or name.name.name */
	
	/* Tidy up */
	metabase_free(ucs4name);
	
	/* Return result */
	return result;
}

/* Clones an entry, excepting metabase excluded modules, in a different metabase */
extern IFMDEntry metabase_clone_entry(IFMetabase metabase, IFMDEntry lastEntry);

/* Clears a specific field */
extern void metabase_clear_field(IFMDEntry entry, const char* module, const char* field);

/* Associate a string with a specific field (replacing all contents of that field) */
extern void metabase_store_string(IFMDEntry entry, const char* module, const char* field, const int* string);

/* Adds a string to the set associated with a specific field */
extern void metabase_add_string(IFMDEntry entry, const char* module, const char* field, const int* string);

/* Associate binary data with a specific field */
extern void metabase_store_data(IFMDEntry entry, const char* module, const char* field, const unsigned char* bytes, int length);

/* Adds some data to the set associated with the specified field */
extern void metabase_add_data(IFMDEntry entry, const char* module, const char* field, const unsigned char* bytes, int length);

/* Retrieve a string from a specific field (returns NULL if the field is data or if the field does not exist) */
extern int* metabase_get_string(IFMDEntry entry, const char* module, const char* field);

/* Retrieves all the strings associated with a specific field */
extern int** metabase_get_strings(IFMDEntry entry, const char* module, const char* field, int* count_out);

/* Retrieve data from a specific field */
extern unsigned char* metabase_get_data(IFMDEntry entry, const char* module, const char* field);

/* Retrieve all the data from a specific field */
extern unsigned char** metabase_get_all_data(IFMDEntry entry, const char* module, const char* field, int* count_out);
