//
//  ZoomSkeinView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "ZoomSkein.h"
#import "ZoomSkeinItem.h"


@interface ZoomSkeinView : NSView {
	ZoomSkein* skein;
	
	BOOL skeinNeedsLayout;
	
	// The layout
	NSMutableDictionary* tree;
	NSMutableArray* levels;
	float globalOffset, globalWidth;
}

// Setting/getting the source
- (ZoomSkein*) skein;
- (void)       setSkein: (ZoomSkein*) skein;

// Laying things out
- (void) skeinNeedsLayout;

// Affecting the display
- (void) scrollToItem: (ZoomSkeinItem*) item;

@end
