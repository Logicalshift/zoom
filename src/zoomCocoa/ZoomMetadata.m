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

#define ReportErrors

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

- (id) initWithData: (NSData*) xmlData
		   filename: (NSString*) fname {
	self = [super init];
	
	if (self) {
		filename = [fname copy];
		
		metadata = IFMD_Parse([xmlData bytes], [xmlData length]);
		dataLock = [[NSLock alloc] init];
		
#ifdef ReportErrors
		if (metadata->numberOfErrors > 0) {
			NSLog(@"ZoomMetadata: encountered errors in file %@", filename!=nil?[filename lastPathComponent]:@"(memory)");
			
			int x;
			for (x=0; x<metadata->numberOfErrors; x++) {
				NSLog(@"ZoomMetadata: %@ at line %i: %s",
					  metadata->error[x].severity==IFMDErrorWarning?@"Warning":@"Error",
					  metadata->error[x].lineNumber,
					  metadata->error[x].moreText);
			}
		}
#endif
		
#ifdef IFMD_ALLOW_TESTING
		// Test, if available
		IFMD_testrepository(metadata);
#endif
	}
	
	return self;
}

- (id) initWithContentsOfFile: (NSString*) fname {
	return [self initWithData: [NSData dataWithContentsOfFile: fname]
					 filename: fname];
}

- (id) initWithData: (NSData*) xmlData {
	return [self initWithData: xmlData
					 filename: nil];
}

- (void) dealloc {
	IFMD_Free(metadata);
	[dataLock release];
	
	if (filename) [filename release];
	
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

- (NSArray*) stories {
	NSMutableArray* res = [NSMutableArray array];
	
	int x;
	for (x=0; x<metadata->numberOfStories; x++) {
		ZoomStory* story = [[ZoomStory alloc] initWithStory: metadata->stories[x]];
		
		[res addObject: story];
		[story release];
	}
	
	return res;
}

// = Storing information =
- (void) storeStory: (ZoomStory*) story {
	[dataLock lock];
	IFMD_AddStory(metadata, [story story]);
	
#ifdef IFMD_ALLOW_TESTING
	// Test, if available
	IFMD_testrepository(metadata);
#endif

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

// = Errors =
- (NSArray*) errors {
	int x;
	NSMutableArray* array = [NSMutableArray array];
	
	for (x=0; x<metadata->numberOfErrors; x++) {
		if (metadata->error[x].severity == IFMDErrorFatal) {
			NSString* errorName = @"";
			
			switch (metadata->error[x].type) {
				case IFMDErrorProgrammerIsASpoon:
					errorName = @"Programmer is a spoon";
					break;
					
				case IFMDErrorXMLError:
					errorName = @"XML parsing error";
					break;
					
				case IFMDErrorNotXML:
					errorName = @"File is not in XML format";
					break;
					
				case IFMDErrorUnknownVersion:
					errorName = @"Unknown iFiction version number";
					break;
					
				case IFMDErrorUnknownTag:
					errorName = @"Invalid iFiction tag encountered in file";
					break;
					
				case IFMDErrorNotIFIndex:
					errorName = @"No index found";
					break;
					
				case IFMDErrorUnknownFormat:
					errorName = @"Unknown story format";
					break;
					
				case IFMDErrorMismatchedFormats:
					errorName = @"Story and identification data specify different formats";
					break;
					
				case IFMDErrorStoriesShareIDs:
					errorName = @"Two stories have the same ID";
					break;
					
				case IFMDErrorDuplicateID:
					errorName = @"One story contains the same ID twice";
					break;
			}
			
			[array addObject: [NSString stringWithFormat: errorName, metadata->error[x].moreText]];
		}
	}
	
	return array;
}

@end
