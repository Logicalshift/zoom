//
//  ZoomAppDelegate.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomPreferenceWindow.h"
#import "ZoomMetadata.h"
#import "ZoomStory.h"

@interface ZoomAppDelegate : NSObject {
	ZoomPreferenceWindow* preferencePanel;
	
	NSMutableArray* gameIndices;
}

- (NSArray*) gameIndices;
- (ZoomStory*) findStory: (ZoomStoryID*) gameID;

@end
