//
//  ZoomMetadata.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZoomStory.h"
#import "ZoomStoryID.h"

// Cocoa interface to the C ifmetadata class
// Yes, Panther now has a SAX parser. No, I'm not using it.

@interface ZoomMetadata : NSObject {
	struct IFMetadata* metadata;
}

// Initialisation
- (id) init;											// Blank metadata
- (id) initWithContentsOfFile: (NSString*) filename;	// Calls initWithData
- (id) initWithData: (NSData*) xmlData;					// Designated initialiser

// Retrieving information
- (ZoomStory*) findStory: (ZoomStoryID*) ident;

@end
