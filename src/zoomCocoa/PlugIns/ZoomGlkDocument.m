//
//  ZoomGlkDocument.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkDocument.h"
#import "ZoomGlkWindowController.h"

@implementation ZoomGlkDocument

// = Initialisation/finalisation =

- (void) dealloc {
	if (clientPath) [clientPath release];
	if (inputPath) [inputPath release];
	
	[super dealloc];
}

- (NSData *)dataRepresentationOfType:(NSString *)type {
	// Glk documents are never saved
    return nil;
}

- (BOOL) loadDataRepresentation: (NSData*) data
						 ofType: (NSString*) type {
	// Neither are they really loaded: we initialise via the plugin
    return YES;
}

// = Configuring the client =

- (void) setClientPath: (NSString*) newClientPath {
	[clientPath release];
	clientPath = [newClientPath copy];
}

- (void) setInputFilename: (NSString*) newInputPath {
	[inputPath release];
	inputPath = [newInputPath copy];
}

// = Constructing the window controllers =

- (void) makeWindowControllers {
	// Set up the window controller
	ZoomGlkWindowController* controller = [[ZoomGlkWindowController alloc] init];
	
	// Give it the paths
	[controller setClientPath: clientPath];
	[controller setInputFilename: inputPath];
	
	// Add it as a controller for this document
	[self addWindowController: [controller autorelease]];
}

@end
