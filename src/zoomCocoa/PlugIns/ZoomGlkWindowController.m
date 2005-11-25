//
//  ZoomGlkWindowController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkWindowController.h"

#import <GlkView/GlkHub.h>

@implementation ZoomGlkWindowController

+ (void) initialize {
	// Set up the Glk hub
	[[GlkHub sharedGlkHub] useProcessHubName];
	[[GlkHub sharedGlkHub] setRandomHubCookie];
}

// = Initialisation =

- (id) init {
	self = [super initWithWindowNibPath: [[NSBundle bundleForClass: [ZoomGlkWindowController class]] pathForResource: @"GlkWindow"
																											  ofType: @"nib"]
								  owner: self];
	
	if (self) {
	}
	
	return self;
}

- (void) dealloc {
	[clientPath release];
	[inputPath release];
	
	[super dealloc];
}

- (void) maybeStartView {
	// If we're sufficiently configured to start the application, then do so
	if (glkView && clientPath && inputPath) {
		[glkView setInputFilename: inputPath];
		[glkView launchClientApplication: clientPath
						   withArguments: [NSArray array]];
	}
}

- (void) windowDidLoad {
	// Configure the view
	[glkView setRandomViewCookie];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

// = Configuring the client =

- (void) setClientPath: (NSString*) newPath {
	// Set the client path
	[clientPath release];
	clientPath = nil;
	clientPath = [newPath copy];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

- (void) setInputFilename: (NSString*) newPath {
	// Set the input path
	[inputPath release];
	inputPath = nil;
	inputPath = [newPath copy];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

@end
