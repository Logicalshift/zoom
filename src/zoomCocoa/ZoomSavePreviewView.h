//
//  ZoomSavePreviewView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Mon Mar 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


@class ZoomSavePreview;
@interface ZoomSavePreviewView : NSView {
	NSMutableArray* upperWindowViews;
	int selected;
}

- (void) setDirectoryToUse: (NSString*) directory;
- (void) previewMouseUp: (NSEvent*) evt
				 inView: (ZoomSavePreview*) view;
- (NSString*) selectedSaveGame;

@end
