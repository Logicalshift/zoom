//
//  ZoomClient.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomClient.h"
#import "ZoomProtocol.h"
#import "ZoomClientController.h"
#import "ZoomStoryOrganiser.h"

#import "ZoomAppDelegate.h"

@implementation ZoomClient

- (id) init {
    self = [super init];

    if (self) {
        gameData = nil;
		story = nil;
    }

    return self;
}

- (void) dealloc {
    [gameData release];
	if (story) [story release];
    
    [super dealloc];
}

// = Creating the document =
- (void) makeWindowControllers {
    ZoomClientController* controller = [[ZoomClientController allocWithZone: [self zone]] init];

    [self addWindowController: [controller autorelease]];
}

- (NSData *)dataRepresentationOfType:(NSString *)type {
    // Can't save, really

    return gameData;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)type {
	ZoomStoryID* storyId;
	
    if (gameData) [gameData release];
    gameData = [data retain];
	
	storyId = [[[ZoomStoryID alloc] initWithZCodeStory: gameData] autorelease];

	if (storyId == nil) {
		// Can't ID this story
		[gameData release];
		gameData = nil;
		return NO;
	}
	
	story = [[[NSApp delegate] userMetadata] findStory: storyId];
	
	if (!story) {
		story = [[NSApp delegate] findStory: storyId];
		
		if (story == nil) {
			story = [[ZoomStory alloc] init];
			[story setTitle: [[[self fileName] lastPathComponent] stringByDeletingPathExtension]];
		} else {
			[story retain];
		}
		
		[story addID: storyId];
		
		[[[NSApp delegate] userMetadata] storeStory: [[story copy] autorelease]];
		[story release];
		
		story = [[[NSApp delegate] userMetadata] findStory: storyId];
		if (story == nil) {
			story = [[ZoomStory alloc] init];
		} else {
			[story retain];
		}
	} else {
		[story retain];
	}
	
	[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: [self fileName]
											  withIdent: storyId];
    
    return YES;
}

// = Document info =

- (NSData*) gameData {
    return gameData;
}

- (ZoomStory*) storyInfo {
	return story;
}

// = Document closedown =

// How? Closing fails to cause an update of any of the fields from the gameinfo window, as
// the controller has already had its document set to nil. Need to detect when a document
// is about to finish with its controllers (or when a controller is about to finish with
// its document) in order to close it down.

@end
