//
//  ZoomStory.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

// Notifications
extern NSString* ZoomStoryDataHasChangedNotification;

@class ZoomStoryID;
@interface ZoomStory : NSObject<NSCopying> {
	struct IFMDStory* story;
	BOOL   needsFreeing;
	
	NSMutableDictionary* extraMetadata;
}

// Information
+ (NSString*) nameForKey: (NSString*) key;
+ (NSString*) keyForTag: (int) tag;

// Initialisation
- (id) init;								// New story
- (id) initWithStory: (struct IFMDStory*) story;   // Existing story (not freed)

- (struct IFMDStory*) story;
- (void) addID: (ZoomStoryID*) newID;

// Searching
- (BOOL) containsText: (NSString*) text;

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

- (id) objectForKey: (NSString*) key; // Always returns an NSString (other objects are possible for other metadata)

// Setting data
- (void) setTitle:    (NSString*) newTitle;
- (void) setHeadline: (NSString*) newHeadline;
- (void) setAuthor:   (NSString*) newAuthor;
- (void) setGenre:    (NSString*) genre;
- (void) setYear:     (int) year;
- (void) setGroup:    (NSString*) group;
- (void) setZarfian:  (unsigned) zarfian;
- (void) setTeaser:   (NSString*) teaser;
- (void) setComment:  (NSString*) comment;
- (void) setRating:   (float) rating;

- (void) setObject: (id) value
			forKey: (NSString*) key;

// Identifying and comparing stories
- (NSArray*) storyIDs;									// Array of ZoomStoryIDs
- (BOOL)     hasID: (ZoomStoryID*) storyID;				// Story answers to this ID
- (BOOL)     isEquivalentToStory: (ZoomStory*) story;   // Stories share an ID

// Sending notifications
- (void) heyLookThingsHaveChangedOohShiney; // Sends ZoomStoryDataHasChangedNotification

@end
