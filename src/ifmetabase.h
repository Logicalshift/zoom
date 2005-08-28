/*
 *  ifmetabase.h
 *  ZoomCocoa
 *
 *  Created by Andrew Hunter on 20/08/2005.
 *  Copyright 2005 Andrew Hunter. All rights reserved.
 *
 */

#ifndef __IFMETABASE_H
#define __IFMETABASE_H

/*
 * The IF metabase: an abstract place we can store and retrieve metadata.
 *
 * The metabase has a fairly complex structure to reflect the nature of metadata. It is hierarchical: it can represent many
 * sources of metadata. It is modular: different sources of metadata can provide different types of metadata, which can add up
 * to the complete set (for example, an archive site can provide details like game titles, and a review site can provide things
 * like game reviews).
 *
 * This is to support the IF XML metadata format specification 1.0.
 */

/* Startup */

extern void metabase_init(void);

/* Metabase callbacks - implement elsewhere */

enum IFMDError {
	IFMDE_FailedToAllocateMemory,
	IFMDE_NamespaceAlreadyInUse,
	IFMDE_ModuleNameAlreadyInUse,
	IFMDE_NULLReference
};

extern void metabase_error(enum IFMDError errorCode, const char* simple_description, ...);
extern void metabase_caution(enum IFMDError errorCode, const char* simple_description, ...);

/* Memory functions (re-implement these if you have a non-ANSI system) */

extern void* metabase_alloc(size_t bytes);
extern void* metabase_realloc(void* ptr, size_t bytes);
extern void  metabase_free(void* ptr);
extern void  metabase_memmove(void* dst, const void* src, size_t size);

/* String convienience functions */

extern int   metabase_strlen(const int* src);
extern void  metabase_strcpy(int* dst, const int* src);
extern int*  metabase_strdup(const int* src);
extern int   metabase_strcmp(const int* a, const int* b);
extern char* metabase_utf8(const int* string);
extern int*  metabase_ucs4(const char* utf8);

/* Describing metadata structure */

/* Associates a namespace with a module name */
extern void metabase_associate_module(const int* namespace, const char* module);

/* Retrieves the module name to use for a specific namespace */
extern const char* metabase_module_for_namespace(const int* namespace);

/* Retrieves a namespace for a specific module */
extern const int* metabase_namespace_for_module(const char* module);

/* Creating metabases */

/* The metabase structure */
typedef struct IFMetabase* IFMetabase;

/* How data from a metabase is filtered */
enum IFMDFilter {
	IFFilter_Inclusive,
	IFFilter_Exclusive
};

/* Creates a new, empty metabase */
extern IFMetabase metabase_create(IFMetabase parent);

/* Destroys an old, unworthy metabase */
extern void metabase_destroy(IFMetabase metabase);

/* Sets how a metabase is filtered (exclusive: modules are filtered out, inclusive: modules are filtered in) */
extern void metabase_filter(IFMetabase metabase, enum IFMDFilter filter_style);

/* Adds a module to the list of filters for a metabase */
/*
 * If the filter style is IF_inclusive, then data for this module is now presented (you'll get results for data from
 * this module in this metabase).
 * If the filter style is IF_exclusive, then data for this module is removed (you'll no longer get results for data from
 * this module)
 */
extern void metabase_add_filter(IFMetabase metabase, const char* module_name);

/* Describing stories */

/* A key to an entry in the metabase */
typedef struct IFMDKey* IFMDKey;

/* Types of story */
enum IFMDFormat {
	IFFormat_Unknown = 0x0,
	
	IFFormat_ZCode,
	IFFormat_Glulx,
	
	IFFormat_TADS,
	IFFormat_HUGO,
	IFFormat_Alan,
	IFFormat_Adrift,
	IFFormat_Level9,
	IFFormat_AGT,
	IFFormat_MagScrolls,
	IFFormat_AdvSys
};

/* For z-code games with an unknown checksum */
#define IFMDChecksum_Unknown 0x10000

/* Creates a reference to a story with a specific type and MD5 */
extern IFMDKey metabase_story_with_md5(enum IFMDFormat format, const char* md5);

/* Creates a reference to a story with a z-code identification. md5 can be NULL if unknown */
extern IFMDKey metabase_story_with_zcode(const char* serial, unsigned int release, unsigned int checksum, const char* md5);

/* Compares two IFMDKeys */
extern int metabase_compare_keys(IFMDKey key1, IFMDKey key2);

/* Storing metadata */

/*
 * Metadata strings are in null-terminated UCS-4. Fields can use '.' to indicate structure (eg foo.bar to indicate
 * <foo><bar>Data</bar></foo>), and '@' to indicate attributes (eg foo@bar for <foo bar="Data"></foo>).
 *
 * Data fields should be otherwise unstructured. Not all XML structure can be represented: this is deliberate. The
 * metabase is XML-like, not actual XML.
 */

typedef struct IFMDEntry* IFMDEntry;

/* Gets an entry for a specific key (entries may be created if they don't exist yet) */
extern IFMDEntry metabase_entry_for_key(IFMetabase metabase, IFMDKey key);

/* Associates an additional key with an entry */
extern void metabase_add_key(IFMDEntry entry, IFMDKey newKey);

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

#endif
