//
//  ZoomStory.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ZoomStory : NSObject {
	struct IFMDStory* story;
	BOOL   needsFreeing;
}

// Initialisation
- (id) init;								// New story
- (id) initWithStory: (struct IFMDStory*) story;   // Existing story (not freed)

// Accessors
- (NSString*) title;
- (NSString*) headline;
- (NSString*) author;
- (NSString*) genre;
- (int)       year;
- (NSString*) group;
- (unsigned)  zarfian;
- (NSString*) teaser;
- (NSString*) comment;
- (float)     rating;

@end
