//
//  ZoomiFictionController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomiFictionController.h"


@implementation ZoomiFictionController

static ZoomiFictionController* sharedController = nil;

// = Setup/initialisation =

+ (ZoomiFictionController*) sharediFictionController {
	if (!sharedController) {
		sharedController = [[ZoomiFictionController alloc] initWithWindowNibName: @"iFiction"];
	}
	
	return sharedController;
}

- (void) windowDidLoad {
	[addButton setPushedImage: [NSImage imageNamed: @"add-in"]];
	[drawerButton setPushedImage: [NSImage imageNamed: @"drawer-in"]];		
	
	[[self window] setFrameUsingName: @"iFiction"];
	[[self window] setExcludedFromWindowsMenu: YES];
}

- (void) close {
	[[self window] orderOut: self];
	[[self window] saveFrameUsingName: @"iFiction"];
}

- (void)windowDidMove:(NSNotification *)aNotification {
	[[self window] saveFrameUsingName: @"iFiction"];
}

// = IB actions =

- (IBAction) addButtonPressed: (id) sender {
}

- (IBAction) drawerButtonPressed: (id) sender {
	[drawer toggle: self];
}

@end
