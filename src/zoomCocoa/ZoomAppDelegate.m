//
//  ZoomAppDelegate.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomAppDelegate.h"
#import "ZoomGameInfoController.h"

#import "ZoomMetadata.h"

@implementation ZoomAppDelegate

// = Initialisation =
- (id) init {
	self = [super init];
	
	if (self) {
		gameIndices = [[NSMutableArray alloc] init];
		
		NSData* userData = nil;
		NSData* infocomData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"infocom" ofType: @"xml"]];
		NSData* archiveData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"archive" ofType: @"xml"]];
		
		if (userData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: userData] autorelease]];
		else
			[gameIndices addObject: [[[ZoomMetadata alloc] init] autorelease]];
		
		if (infocomData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: infocomData] autorelease]];
		if (archiveData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: archiveData] autorelease]];
	}
	
	return self;
}

- (void) dealloc {
	if (preferencePanel) [preferencePanel release];
	[gameIndices release];
	
	[super dealloc];
}

// = Opening files =
- (BOOL) applicationShouldOpenUntitledFile: (NSApplication*) sender {
    return NO;
}

// = General actions =
- (IBAction) showPreferences: (id) sender {
	if (!preferencePanel) {
		preferencePanel = [[ZoomPreferenceWindow alloc] init];
	}
	
	[[preferencePanel window] center];
	[preferencePanel setPreferences: [ZoomPreferences globalPreferences]];
	[[preferencePanel window] makeKeyAndOrderFront: self];
}

- (IBAction) displayGameInfoWindow: (id) sender {
	[[ZoomGameInfoController sharedGameInfoController] showWindow: self];

	// Blank out the game info window
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
	
	// Try to update the game info window using the first responder
	[NSApp sendAction: @selector(updateGameInfo:)
				   to: nil
				 from: self];
}

- (IBAction) displayNoteWindow: (id) sender {
}

// = Application-wide data =
- (NSArray*) gameIndices {
	return gameIndices;
}

- (ZoomStory*) findStory: (ZoomStoryID*) gameID {
	NSEnumerator* indexEnum = [gameIndices objectEnumerator];
	ZoomMetadata* repository;
	
	while (repository = [indexEnum nextObject]) {
		ZoomStory* res = [repository findStory: gameID];
		
		if (res) return res;
	}
	
	return nil;
}

- (ZoomMetadata*) userMetadata {
	return [gameIndices objectAtIndex: 0];
}

@end
