//
//  ZoomClient.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomProtocol.h"
#import "ZoomStory.h"

@class ZoomView;
@interface ZoomClient : NSDocument {
    NSData* gameData;
	
	ZoomStory* story;
	ZoomStoryID* storyId;
	
	NSData* autosaveData;
	
	ZoomView* defaultView;
	NSData*   saveData;
}

- (NSData*) gameData;
- (ZoomStory*) storyInfo;
- (ZoomStoryID*) storyId;

// Restoring from an autosave
- (void) loadDefaultAutosave;
- (void) setAutosaveData: (NSData*) data;
- (NSData*) autosaveData;

// Loading a zoomSave file
- (ZoomView*) defaultView;
- (NSData*)   saveData;

@end
