//
//  ZoomAppDelegate.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomAppDelegate.h"
#import "ZoomGameInfoController.h"


@implementation ZoomAppDelegate

- (void) dealloc {
	if (preferencePanel) [preferencePanel release];
	
	[super dealloc];
}

- (BOOL) applicationShouldOpenUntitledFile: (NSApplication*) sender {
    return NO;
}

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

@end
