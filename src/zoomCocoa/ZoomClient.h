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

@interface ZoomClient : NSDocument {
    NSData* gameData;
	
	ZoomStory* story;
}

- (NSData*) gameData;
- (ZoomStory*) storyInfo;

@end
