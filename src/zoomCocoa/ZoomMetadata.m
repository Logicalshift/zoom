//
//  ZoomMetadata.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomMetadata.h"
#import "ZoomAppDelegate.h"

#include "ifmetadata.h"

@implementation ZoomMetadata

// = Initialisation, etc =

- (id) init {
	self = [super init];
	
	if (self) {
		metadata = malloc(sizeof(IFMetadata));
		
		metadata->numberOfStories = 0;
		metadata->numberOfErrors = 0;
		metadata->numberOfIndexEntries = 0;
		
		metadata->stories = NULL;
		metadata->error   = NULL;
		metadata->index   = NULL;
		
		dataLock = [[NSLock alloc] init];
	}
	
	return self;
}

- (id) initWithContentsOfFile: (NSString*) filename {
	return [self initWithData: [NSData dataWithContentsOfFile: filename]];
}

- (id) initWithData: (NSData*) xmlData {
	self = [super init];
	
	if (self) {
		metadata = IFMD_Parse([xmlData bytes], [xmlData length]);
		dataLock = [[NSLock alloc] init];
		
#ifdef IFMD_ALLOW_TESTING
		// Test, if available
		IFMD_testrepository(metadata);
#endif
	}
	
	return self;
}

- (void) dealloc {
	IFMD_Free(metadata);
	
	[super dealloc];
}

// = Finding information =

- (ZoomStory*) findStory: (ZoomStoryID*) ident {
	IFMDStory* story;
	
	[dataLock lock];
	
	story = IFMD_Find(metadata, [ident ident]);
	
	if (story) {
		ZoomStory* res = [[ZoomStory alloc] initWithStory: story];
		
		[dataLock unlock];
		return [res autorelease];
	} else {
		[dataLock unlock];
		return nil;
	}
}

// = Storing information =
- (void) storeStory: (ZoomStory*) story {
	[dataLock lock];
	IFMD_AddStory(metadata, [story story]);
	[dataLock unlock];
}

// = Saving the file =
static int dataWrite(const char* bytes, int length, void* userData) {
	NSMutableData* data = userData;
	[data appendBytes: bytes
			   length: length];
	return 0;
}

- (NSData*) xmlData {
	[dataLock lock];
	NSMutableData* res = [[NSMutableData alloc] init];
	
	IFMD_Save(metadata, dataWrite, res);
	
	[dataLock unlock];
	return [res autorelease];
}

- (BOOL) writeToFile: (NSString*)path
		  atomically: (BOOL)flag {
	return [[self xmlData] writeToFile: path atomically: flag];
}

- (BOOL) writeToDefaultFile {
	// The app delegate may not be the best place for this routine... Maybe a function somewhere
	// would be better?
	NSString* configDir = [[NSApp delegate] zoomConfigDirectory];
	
	return [self writeToFile: [configDir stringByAppendingPathComponent: @"metadata.iFiction"]
				  atomically: YES];
}

@end
