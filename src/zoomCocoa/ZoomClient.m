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

/*
- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"ZoomClient";
}
*/

- (void) makeWindowControllers {
    ZoomClientController* controller = [[ZoomClientController allocWithZone: [self zone]] init];

    [self addWindowController: [controller autorelease]];
}

- (NSData *)dataRepresentationOfType:(NSString *)type {
    // Can't save, really

    return gameData;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)type {
    if (gameData) [gameData release];
    gameData = [data retain];
	
	story = [[NSApp delegate] findStory: [[[ZoomStoryID alloc] initWithZCodeStory: gameData] autorelease]];
	
	if (story == nil) {
		story = [[ZoomStory alloc] init];
	} else {
		[story retain];
	}
    
    return YES;
}

- (NSData*) gameData {
    return gameData;
}

- (ZoomStory*) storyInfo {
	return story;
}

@end
