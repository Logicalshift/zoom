//
//  ZoomGlkPlugIn.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomPlugIn.h>
#import <ZoomPlugIns/ZoomGlkWindowController.h>

///
/// Base class for plugins that provide a Glk-based interpreter.
///
@interface ZoomGlkPlugIn : ZoomPlugIn {
	ZoomGlkWindowController* windowController;						// Constructed on demand
	
	NSString* clientPath;											// Path to the client application
}

// Configuring the client
- (void) setClientPath: (NSString*) clientPath;						// Selects which GlkClient executable to run

@end
