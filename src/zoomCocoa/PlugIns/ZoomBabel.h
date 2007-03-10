//
//  ZoomBabel.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 10/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomPlugIns/ZoomStoryID.h>

//
// Objective-C interface to the babel command line tool
//
@interface ZoomBabel : NSObject {
	NSTask* babelTask;										// The babel task
}

// = Initialisation =

- (id) initWithFilename: (NSString*) story;					// Initialise this object with the specified story (metadata and image extraction will start immediately)

// = Raw reading =

- (void) setTaskTimeout: (float) seconds;					// Sets the maximum time to wait for the babel command to respond when blocking (default is 0.2 seconds)

- (NSString*) rawMetadata;									// Retrieves a raw XML metadata record (or nil)
- (NSData*) rawCoverImage;									// Retrieves the raw cover image data (or nil)

// = Interpreted reading =

- (ZoomStory*) metadata;									// Retrieves the metadata for this file
- (NSImage*) coverImage;									// Retrieves the cover image for this file

@end
