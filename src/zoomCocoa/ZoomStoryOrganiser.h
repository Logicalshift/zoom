//
//  ZoomStoryOrganiser.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZoomStory.h"
#import "ZoomStoryID.h"


// The story organiser is used to store story locations and identifications
// (Mainly to build up the iFiction window)

// Notifications
extern NSString* ZoomStoryOrganiserChangedNotification;

@interface ZoomStoryOrganiser : NSObject {
	// Arrays of the stories and their idents
	NSMutableArray* storyFilenames;
	NSMutableArray* storyIdents;
	
	// Dictionaries associating them
	NSMutableDictionary* filenamesToIdents;
	NSMutableDictionary* identsToFilenames;
	
	// Preference loading/checking thread
	NSPort* port1;
	NSPort* port2;
	NSConnection* mainThread;
	NSConnection* subThread;
	
	NSLock* storyLock;
}

// The shared organiser
+ (ZoomStoryOrganiser*) sharedStoryOrganiser;

// Storing stories
- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident;
- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident
		 organise: (BOOL) organise;

// Sending notifications
- (void) organiserChanged;

// Retrieving story information
- (NSString*) filenameForIdent: (ZoomStoryID*) ident;
- (ZoomStoryID*) identForFilename: (NSString*) filename;

- (NSArray*) storyFilenames;
- (NSArray*) storyIdents;

// Story-specific data
- (NSString*) directoryForIdent: (ZoomStoryID*) ident
						 create: (BOOL) create;

// Organising stories
- (NSString*) directoryForStory: (ZoomStory*) story;
- (void)      organiseStory: (NSString*) story;
- (void)      organiseAllStories;
- (void)      reorganiseStoriesTo: (NSString*) newStoryDirectory;

@end
