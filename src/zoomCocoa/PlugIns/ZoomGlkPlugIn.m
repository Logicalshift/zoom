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
	
	if (windowController) [windowController release];
	windowController = nil;
	
	[super dealloc];
}

// = Overrides from ZoomPlugIn =

+ (BOOL) canLoadSavegames {
	return NO;
}

- (NSWindowController*) gameWindowController {
	if (!windowController) {
		// Start up the window controller
		windowController = [[ZoomGlkWindowController alloc] init];
		
		// Give it some suitably juicy details about what we want the controller to do
		[windowController setClientPath: clientPath];
		[windowController setInputFilename: [self gameFilename]];
	}
	
	return windowController;
}

// = Configuring the client =

- (void) setClientPath: (NSString*) newPath {
	[clientPath release];
	clientPath = nil;
	clientPath = [newPath copy];
}

@end
