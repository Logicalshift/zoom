//
//  ZoomAppDelegate.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomAppDelegate.h"


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
	[[preferencePanel window] makeKeyAndOrderFront: self];
}

@end
