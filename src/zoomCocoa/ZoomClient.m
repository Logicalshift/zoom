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
	
	story = [[NSApp delegate] findStory: storyId];
	
	if ([[[NSApp delegate] userMetadata] findStory: storyId] != nil) {
		NSLog(@"Already user story!");
	}
	
	if (story == nil) {
		story = [[ZoomStory alloc] init];
		[story addID: storyId];
	} else {
		[story retain];
	}
	
	[[[NSApp delegate] userMetadata] storeStory: [[story copy] autorelease]];
	[story release];
	
	story = [[[NSApp delegate] userMetadata] findStory: storyId];
	if (story == nil) {
		NSLog(@"Story not found!");
		story = [[ZoomStory alloc] init];
	} else {
		[story retain];
	}
    
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

// How?

@end
