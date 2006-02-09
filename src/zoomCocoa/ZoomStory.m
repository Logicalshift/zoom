//
//  ZoomStory.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomStory.h"
#import "ZoomStoryID.h"

#import "ZoomMetadata.h"
#import "ZoomBlorbFile.h"
#import "ZoomPreferences.h"

#include "ifmetadata.h"

NSString* ZoomStoryDataHasChangedNotification = @"ZoomStoryDataHasChangedNotification";
NSString* ZoomStoryExtraMetadata = @"ZoomStoryExtraMetadata";

NSString* ZoomStoryExtraMetadataChangedNotification = @"ZoomStoryExtraMetadataChangedNotification";

@implementation ZoomStory

+ (void) initialize {
	NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
	
	[defs registerDefaults: 
		[NSDictionary dictionaryWithObjectsAndKeys:
			[NSDictionary dictionary], ZoomStoryExtraMetadata,
			nil]];
}

+ (NSString*) nameForKey: (NSString*) key {
	// FIXME: internationalisation (this FIXME applies to most of Zoom, which is why it hasn't happened yet)
	static NSDictionary* keyNameDict = nil;
	
	if (keyNameDict == nil) {
		keyNameDict = [NSDictionary dictionaryWithObjectsAndKeys:
			@"Title", @"title",
			@"Headline", @"headline",
			@"Author", @"author",
			@"Genre", @"genre",
			@"Group", @"group",
			@"Year", @"year",
			@"Zarfian rating", @"zarfian",
			@"Teaser", @"teaser",
			@"Comments", @"comment",
			@"My Rating", @"rating",
			@"Description", @"description",
			@"Cover picture number", @"coverpicture",
			nil];
		
		[keyNameDict retain];
	}
	
	return [keyNameDict objectForKey: key];
}

+ (NSString*) keyForTag: (int) tag {
	switch (tag) {
		case 0: return @"title";
		case 1: return @"headline";
		case 2: return @"author";
		case 3: return @"genre";
		case 4: return @"group";
		case 5: return @"year";
		case 6: return @"zarfian";
		case 7: return @"teaser";
		case 8: return @"comment";
		case 9: return @"rating";
		case 10: return @"description";
		case 11: return @"coverpicture";
	}
	
	return nil;
}

+ (ZoomStory*) defaultMetadataForFile: (NSString*) filename {
	// Gets the standard metadata for the given file
	BOOL isDir;
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: filename
											  isDirectory: &isDir]) return nil;
	if (isDir) return nil;
	
	// Get the ID for this file
	NSData* fileData = [NSData dataWithContentsOfFile: filename];
	ZoomStoryID* fileID = [[ZoomStoryID alloc] initWithZCodeStory: fileData];
	ZoomMetadata* fileMetadata = nil;
	
	// If this file is a blorb file, then extract the IFmd chunk
	const unsigned char* bytes = [fileData bytes];
	
	if (bytes[0] == 'F' && bytes[1] == 'O' && bytes[2] == 'R' && bytes[3] == 'M') {
		ZoomBlorbFile* blorb = [[ZoomBlorbFile alloc] initWithData: fileData];
		NSData* ifMD = [blorb dataForChunkWithType: @"IFmd"];
		
		if (ifMD != nil) {
			fileMetadata = [[ZoomMetadata alloc] initWithData: ifMD];
		} else {
			NSLog(@"Warning: found a game with an IFmd chunk, but was not able to parse it");
		}
		
		[blorb release];
	}
	
	// If we've got an ifMD chunk, then see if we can extract the story from it
	ZoomStory* result = nil;
	
	if (fileMetadata) {
		result = [[fileMetadata findStory: fileID] copy];
		
		if (result == nil) {
			NSLog(@"Warning: found a game with an IFmd chunk, but which did not appear to contain any relevant metadata (looked for ID: %@)", fileID); 
		}
	}
	
	// If there's no result, then make up the data from the filename
	if (result == nil) {
		result = [[ZoomStory alloc] init];
		
		// Add the ID
		[result addID: fileID];
		
		// Behaviour is different for stories that are organised
		NSString* orgDir = [[[ZoomPreferences globalPreferences] organiserDirectory] stringByStandardizingPath];
		BOOL storyIsOrganised = NO;
		
		NSString* mightBeOrgDir = [[[filename stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
		mightBeOrgDir = [mightBeOrgDir stringByStandardizingPath];
		
		if ([orgDir caseInsensitiveCompare: mightBeOrgDir] == NSOrderedSame) storyIsOrganised = YES;
		if (![[[[filename lastPathComponent] stringByDeletingPathExtension] lowercaseString] isEqualToString: @"game"]) storyIsOrganised = NO;
		
		// Build the metadata
		NSString* groupName;
		NSString* gameName;
		
		if (storyIsOrganised) {
			gameName = [[filename stringByDeletingLastPathComponent] lastPathComponent];
			groupName = [[[filename stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] lastPathComponent];
		} else {
			gameName = [[filename stringByDeletingPathExtension] lastPathComponent];
			groupName = @"";
		}
		
		[result setTitle: gameName];
		[result setGroup: groupName];
	}
	
	// Clean up
	[fileID release];
	[fileMetadata release];
	
	// Return the result
	return [result autorelease];
}

// = Initialisation =

- (id) init {
	self = [super init];
	
	if (self) {
		story = IFStory_Alloc();
		needsFreeing = YES;
		
		extraMetadata = nil;
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(extraDataChanged:)
													 name: ZoomStoryExtraMetadataChangedNotification
												   object: nil];		
	}
	
	return self;
}

- (id) initWithStory: (IFMDStory*) s {
	self = [super init];
	
	if (self) {
		story = s;
		needsFreeing = NO;
		
		extraMetadata = nil;
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(extraDataChanged:)
													 name: ZoomStoryExtraMetadataChangedNotification
												   object: nil];
	}
	
	return self;
}

- (void) dealloc {
	if (needsFreeing) {
		IFStory_Free(story);
		free(story);
	}
	
	if (extraMetadata) [extraMetadata release];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}

// = Accessors =
- (struct IFMDStory*) story {
	return story;
}

- (void) addID: (ZoomStoryID*) newID {
	int ident;
	int foundID = -1;
	
	for (ident = 0; ident<story->numberOfIdents; ident++) {
		if (IFID_Compare(story->idents[ident], [newID ident]) == 0) {
			foundID = ident; break;
		}
	}
	
	if (foundID >= 0) {
		if (story->idents[foundID]->dataFormat == IFFormat_ZCode) {
			if (story->idents[foundID]->data.zcode.checksum == 0x10000) {
				story->idents[foundID]->data.zcode.checksum = [newID ident]->data.zcode.checksum;
			}
		}
	} else {
		story->numberOfIdents++;
		story->idents = realloc(story->idents, sizeof(IFMDIdent)*story->numberOfIdents);
		story->idents[story->numberOfIdents-1] = IFID_Alloc();
		IFIdent_Copy(story->idents[story->numberOfIdents-1], [newID ident]);
	}
}

- (NSString*) title {
	if (story && story->data.title) {
		return [(NSString*)IFStrCpyCF(story->data.title) autorelease];
	}
	
	return @"";
}

- (NSString*) headline {
	if (story && story->data.headline) {
		return [(NSString*)IFStrCpyCF(story->data.headline) autorelease];
	}
	
	return @"";
}

- (NSString*) author {
	if (story && story->data.author) {
		return [(NSString*)IFStrCpyCF(story->data.author) autorelease];
	}
	
	return @"";
}

- (NSString*) genre {
	if (story && story->data.genre) {
		return [(NSString*)IFStrCpyCF(story->data.genre) autorelease];
	}
	
	return @"";
}

- (int) year {
	if (story) return story->data.year;
	return 0;
}

- (NSString*) group {
	if (story && story->data.group) {
		return [(NSString*)IFStrCpyCF(story->data.group) autorelease];
	}
	
	return @"";
}

- (unsigned) zarfian {
	if (story) return story->data.zarfian;
	return IFMD_Unrated;
}

- (NSString*) teaser {
	if (story && story->data.teaser) {
		return [(NSString*)IFStrCpyCF(story->data.teaser) autorelease];
	}
	
	return @"";
}

- (NSString*) comment {
	if (story && story->data.comment) {
		return [(NSString*)IFStrCpyCF(story->data.comment) autorelease];
	}
	
	return @"";
}

- (float)     rating {
	if (story) return story->data.rating;
	return -1;
}

- (int) coverPicture {
	if (story) return story->data.coverpicture;
	return -1;
}

- (NSString*) description {
	if (story && story->data.description) {
		return [(NSString*)IFStrCpyCF(story->data.description) autorelease];
	}
	return NULL;
}

// = Setting data =

// Setting data
- (void) setTitle: (NSString*) newTitle {
	if (story->data.title) {
		free(story->data.title);
		story->data.title = NULL;
	}
	
	if (newTitle) {
		story->data.title = IFMakeStrCF((CFStringRef)newTitle);
	}
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setHeadline: (NSString*) newHeadline {
	if (story->data.headline) {
		free(story->data.headline);
		story->data.headline = NULL;
	}
	
	if (newHeadline) {
		story->data.headline = IFMakeStrCF((CFStringRef)newHeadline);
	}
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setAuthor: (NSString*) newAuthor {
	if (story->data.author) {
		free(story->data.author);
		story->data.author = NULL;
	}
	
	if (newAuthor) {
		story->data.author = IFMakeStrCF((CFStringRef)newAuthor);
	}
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setGenre: (NSString*) genre {
	if (story->data.genre) {
		free(story->data.genre);
		story->data.genre = NULL;
	}
	
	if (genre) {
		story->data.genre = IFMakeStrCF((CFStringRef)genre);
	}
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setYear: (int) year {
	story->data.year = year;
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setGroup: (NSString*) group {
	if (story->data.group) {
		free(story->data.group);
		story->data.group = NULL;
	}
	
	if (group) {
		story->data.group = IFMakeStrCF((CFStringRef)group);
	}
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setZarfian: (unsigned) zarfian {
	story->data.zarfian = zarfian;
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setTeaser: (NSString*) teaser {
	if (story->data.teaser) {
		free(story->data.teaser);
		story->data.teaser = NULL;
	}
	
	if (teaser) {
		story->data.teaser = IFMakeStrCF((CFStringRef)teaser);
	}
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setComment: (NSString*) comment {
	if (story->data.comment) {
		free(story->data.comment);
		story->data.comment = NULL;
	}
	
	if (comment) {
		story->data.comment = IFMakeStrCF((CFStringRef)comment);
	}
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setRating: (float) rating {
	story->data.rating = rating;
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setCoverPicture: (int) coverpicture {
	story->data.coverpicture = coverpicture;
	
	[self heyLookThingsHaveChangedOohShiney];
}

- (void) setDescription: (NSString*) description {
	if (story->data.description) {
		free(story->data.description);
		story->data.description = NULL;
	}
	
	if (description) {
		story->data.description = IFMakeStrCF((CFStringRef)description);
	}
	
	[self heyLookThingsHaveChangedOohShiney];
}

// = NSCopying =
- (id) copyWithZone: (NSZone*) zone {
	IFMDStory* newStory = IFStory_Alloc();
	IFStory_Copy(newStory, story);
	
	ZoomStory* res;
	
	res = [[ZoomStory alloc] initWithStory: newStory];
	res->needsFreeing = YES;
	
	return res;
}

// = Story pseudo-dictionary methods =
- (void) loadExtraMetadata {
	if (extraMetadata != nil) return;
	
	NSDictionary* dict = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomStoryExtraMetadata];
	
	// We retrieve the data for the first story ID only. Assuming nothing funny has happened, it
	// will be the same for all IDs associated with this story.
	if (dict == nil || ![dict isKindOfClass: [NSDictionary class]]) {
		extraMetadata = [[NSMutableDictionary alloc] init];
	} else {
		extraMetadata = [[dict objectForKey: [[[self storyIDs] objectAtIndex: 0] description]] mutableCopy];
	}
	
	if (extraMetadata == nil) {
		extraMetadata = [[NSMutableDictionary alloc] init];
	}
}

- (void) storeExtraMetadata {
	// Make a mutable copy of the metadata dictionary
	NSMutableDictionary* newExtraData = [[[[NSUserDefaults standardUserDefaults] objectForKey: ZoomStoryExtraMetadata] mutableCopy] autorelease];
	
	if (newExtraData == nil || ![newExtraData isKindOfClass: [NSMutableDictionary class]]) {
		newExtraData = [[[NSMutableDictionary alloc] init] autorelease];
	}
	
	// Add the data for all our story IDs
	NSEnumerator* idEnum = [[self storyIDs] objectEnumerator];
	ZoomStoryID* storyID;
	
	while (storyID = [idEnum nextObject]) {
		[newExtraData setObject: extraMetadata
						 forKey: [storyID description]];
	}
	
	// Store in the defaults
	[[NSUserDefaults standardUserDefaults] setObject: newExtraData
											  forKey: ZoomStoryExtraMetadata];
	
	// Notify the other stories about the change
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryExtraMetadataChangedNotification
														object: self];
}

- (void) extraDataChanged: (NSNotification*) not {
	// Respond to notifications about changing metadata
	if (extraMetadata) {
		[extraMetadata release];
		extraMetadata = nil;
		
		// (Reloading prevents a potential bug in the future. It's not absolutely required right now)
		[self loadExtraMetadata];
	}
}

- (id) objectForKey: (id) key {
	if (![key isKindOfClass: [NSString class]]) {
		[NSException raise: @"ZoomKeyNotString" format: @"Metadata key is not a string"];
		return nil;
	}
	
	if ([key isEqualToString: @"title"]) {
		return [self title];
	} else if ([key isEqualToString: @"headline"])  {
		return [self headline];
	} else if ([key isEqualToString: @"author"]) {
		return [self author];
	} else if ([key isEqualToString: @"genre"]) {
		return [self genre];
	} else if ([key isEqualToString: @"group"]) {
		return [self group];
	} else if ([key isEqualToString: @"year"]) {
		int year = [self year];
		
		if (year <= 0) return nil;
		
		return [NSString stringWithFormat: @"%i", year];
	} else if ([key isEqualToString: @"zarfian"]) {
		//return [self zarfian];
		return @"IMPLEMENT ME";
	} else if ([key isEqualToString: @"teaser"]) {
		return [self teaser];
	} else if ([key isEqualToString: @"comment"]) {
		return [self comment];
	} else if ([key isEqualToString: @"rating"]) {
		float rating = [self rating];
		
		if (rating < 0) return nil;
		
		return [NSString stringWithFormat: @"%05.2f", rating];
	} else if ([key isEqualToString: @"description"]) {
		return [self description];
	} else if ([key isEqualToString: @"coverpicture"]) {
		return [NSNumber numberWithInt: [self coverPicture]];
	} else {
		[self loadExtraMetadata];
		return [extraMetadata objectForKey: key];
	}
}

- (void) setObject: (id) value
			forKey: (id) key {
	if ([key isEqualToString: @"rating"] && [value isKindOfClass: [NSNumber class]]) {
		[self setRating: [value floatValue]];
		return;
	}
	
	if (![value isKindOfClass: [NSString class]] && value != nil) {
		[NSException raise: @"ZoomBadValue" format: @"Metadata value is not a string"];
		return;
	}
	if (![key isKindOfClass: [NSString class]]) {
		[NSException raise: @"ZoomKeyNotString" format: @"Metadata key is not a string"];
		return;
	}

	if ([key isEqualToString: @"title"]) {
		[self setTitle: value];
	} else if ([key isEqualToString: @"headline"])  {
		[self setHeadline: value];
	} else if ([key isEqualToString: @"author"]) {
		[self setAuthor: value];
	} else if ([key isEqualToString: @"genre"]) {
		[self setGenre: value];
	} else if ([key isEqualToString: @"group"]) {
		[self setGroup: value];
	} else if ([key isEqualToString: @"year"]) {
		if (value == nil || [(NSString*)value length] == 0) [self setYear: 0];
		else [self setYear: atoi([value cString])];
	} else if ([key isEqualToString: @"zarfian"]) {
		// IMPLEMENT ME
	} else if ([key isEqualToString: @"teaser"]) {
		[self setTeaser: value];
	} else if ([key isEqualToString: @"comment"]) {
		[self setComment: value];
	} else if ([key isEqualToString: @"rating"]) {
		if (value == nil || [(NSString*)value length] == 0) [self setRating: -1];
		else [self setRating: atof([value cString])];
	} else if ([key isEqualToString: @"description"]) {
		[self setDescription: value];
	} else if ([key isEqualToString: @"coverpicture"]) {
		[self setCoverPicture: [value intValue]];
	} else {
		[self loadExtraMetadata];
		if (value == nil) {
			[extraMetadata removeObjectForKey: key];
		} else {
			[extraMetadata setObject: value
							  forKey: key];
		}
		[self storeExtraMetadata];
	}
}

// Searching
- (BOOL) containsText: (NSString*) text {
	// List of strings to check against
	NSArray* stringsToCheck = [[NSArray alloc] initWithObjects: 
		[self title], [self headline], [self author], [self genre], [self group], nil];
	
	// List of words to match against (we take off a word for each match)
	NSMutableArray* words = [[text componentsSeparatedByString: @" "] mutableCopy];
	
	// Loop through each string to check against
	NSEnumerator* searchEnum = [stringsToCheck objectEnumerator];
	NSString* string;
	
	while ([words count] > 0 && (string = [searchEnum nextObject])) {
		int num;
		
		for (num=0; num<[words count]; num++) {
			if ([(NSString*)[words objectAtIndex: num] length] == 0 || 
				[string rangeOfString: [words objectAtIndex: num]
							  options: NSCaseInsensitiveSearch].location != NSNotFound) {
				// Found this word
				[words removeObjectAtIndex: num];
				num--;
				continue;
			}
		}
	}

	// Finish up
	BOOL success = [words count] <= 0;
	
	[words release];
	[stringsToCheck release];
	
	// Is true if there are no words left to match
	return success;
}

// = Sending notifications =
- (void) heyLookThingsHaveChangedOohShiney {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryDataHasChangedNotification
														object: self];
}

// Identifying and comparing stories
- (NSArray*) storyIDs {
	NSMutableArray* idArray = [NSMutableArray array];
	
	int ident;
	
	for (ident = 0; ident < story->numberOfIdents; ident++) {
		ZoomStoryID* theId = [[ZoomStoryID alloc] initWithIdent: story->idents[ident]];
		if (theId) {
			[idArray addObject: theId];
			[theId release];
		}
	}
	
	return idArray;
}

- (BOOL) hasID: (ZoomStoryID*) storyID {
	NSArray* ourIds = [self storyIDs];
	
	return [ourIds containsObject: storyID];
}

- (BOOL) isEquivalentToStory: (ZoomStory*) eqStory {
	if (eqStory == self) return YES; // Shortcut
	
	NSArray* theirIds = [eqStory storyIDs];
	NSArray* ourIds = [self storyIDs];
	
	NSEnumerator* idEnum = [theirIds objectEnumerator];
	ZoomStoryID* thisId;
	
	while (thisId = [idEnum nextObject]) {
		if ([ourIds containsObject: thisId]) return YES;
	}
	
	return NO;
}

@end
