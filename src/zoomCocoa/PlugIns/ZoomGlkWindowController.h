//
//  ZoomGlkWindowController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkView.h>


@class ZoomTextToSpeech;

///
/// WindowController for windows running a Glk interpreter
///
@interface ZoomGlkWindowController : NSWindowController {
	IBOutlet GlkView* glkView;										// The view onto the game this controller is running

	IBOutlet NSDrawer* logDrawer;									// The drawer that's opened while dealing with log messages
	IBOutlet NSTextView* logText;									// The text contained in the drawer
	
	NSString* clientPath;											// The Glk executable we'll run to play this game
	NSString* inputPath;											// The file we'll pass to the executable as the game to run
	NSImage* logo;													// The logo that we're going to show
	BOOL ttsAdded;													// Whether or not the GlkView has the tts receiver added to it
	ZoomTextToSpeech* tts;											// Text-to-speech object
}

// Configuring the client
- (void) setClientPath: (NSString*) clientPath;						// Selects which GlkClient executable to run
- (void) setInputFilename: (NSString*) inputPath;					// The file that should be passed to the client as the file to run
- (void) setLogo: (NSImage*) logo;									// The logo to display instead of the 'CocoaGlk' logo

@end
