//
//  ZoomGlkDocument.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomStory.h>

///
/// Document representing a Glk game
///
@interface ZoomGlkDocument : NSDocument {
	NSString* clientPath;											// The Glk executable we'll run to play this game
	NSString* inputPath;											// The file we'll pass to the executable as the game to run
	
	ZoomStory* storyData;											// Metadata for this story
	NSImage* logo;													// The logo for this story
}

// Configuring the client
- (void) setStoryData: (ZoomStory*) story;							// Sets the metadata associated with this story
- (void) setClientPath: (NSString*) clientPath;						// Selects which GlkClient executable to run
- (void) setInputFilename: (NSString*) inputPath;					// The file that should be passed to the client as the file to run
- (void) setLogo: (NSImage*) logo;									// The logo to display for this story

- (ZoomStory*) storyData;											// The story data that we stored for this story

@end
