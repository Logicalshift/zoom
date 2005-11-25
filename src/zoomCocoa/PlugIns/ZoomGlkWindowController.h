//
//  ZoomGlkWindowController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkView.h>


///
/// WindowController for windows running a Glk interpreter
///
@interface ZoomGlkWindowController : NSWindowController {
	IBOutlet GlkView* glkView;										// The view onto the game this controller is running
	
	NSString* clientPath;											// The Glk executable we'll run to play this game
	NSString* inputPath;											// The file we'll pass to the executable as the game to run
}

// Configuring the client
- (void) setClientPath: (NSString*) clientPath;						// Selects which GlkClient executable to run
- (void) setInputFilename: (NSString*) inputPath;					// The file that should be passed to the client as the file to run

@end
