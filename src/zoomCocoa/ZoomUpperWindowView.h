//
//  ZoomUpperWindowView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomView.h"

@class ZoomView;
@interface ZoomUpperWindowView : NSView {
    ZoomView* zoomView;
	
	BOOL cursorFlashing;
	BOOL cursorShown;
	
	NSTimer* flasher;
}

- (void) updateCursor;
- (void) setFlashCursor: (BOOL) flash;
- (void) flashCursor;

@end
