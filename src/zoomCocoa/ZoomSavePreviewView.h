//
//  ZoomSavePreviewView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Mon Mar 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface ZoomSavePreviewView : NSView {
	NSMutableArray* upperWindowViews;
}

- (void) setDirectoryToUse: (NSString*) directory;

@end
