//
//  ZoomGlkPlugIn.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkPlugIn.h"


@implementation ZoomGlkPlugIn

// = Initialisation =

- (id) initWithFilename: (NSString*) gameFile {
	self = [super initWithFilename: gameFile];
	
	if (self) {
	}
	
	return self;
}

- (void) dealloc {
	[clientPath release]; clientPath = nil;
	
	if (document) [document release];
	document = nil;
	
	[super dealloc];
}

// = Overrides from ZoomPlugIn =

+ (BOOL) canLoadSavegames {
	return NO;
}

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story {
	if (!document) {
		// Set up the document for this game
		document = [[ZoomGlkDocument alloc] init];

		// Tell it what it needs to know
		[document setStoryData: story];
		[document setClientPath: clientPath];
		[document setInputFilename: [self gameFilename]];
		[document setLogo: [self logo]];
	}
	
	// Return it
	return document;
}

// = Configuring the client =

- (void) setClientPath: (NSString*) newPath {
	[clientPath release];
	clientPath = nil;
	clientPath = [newPath copy];
}

- (NSImage*) logo {
	return nil;
}

@end
