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
	
	// Details about items
	NSMutableDictionary* itemForItem;
	
	// The layout
	NSMutableDictionary* tree;
	NSMutableArray* levels;
	float globalOffset, globalWidth;
	
	// Cursor flags
	BOOL overWindow;
	BOOL overItem;
	
	NSMutableArray* trackingRects;
	NSDictionary* trackedItem;
	
	BOOL    dragScrolling;
	NSPoint dragOrigin;
	NSRect  dragInitialVisible;
	
	// Selected item
	ZoomSkeinItem* selectedItem;
	
	// Clicking buttons
	int activeButton;
	int lastButton;
	
	// Annoyingly poor support for tracking rects band-aid
	NSRect lastVisibleRect;
	
	// Editing things
	ZoomSkeinItem* itemToEdit;
	NSTextField* itemEditor;
	
	// The delegate
	NSObject* delegate;
}

// Setting/getting the source
- (ZoomSkein*) skein;
- (void)       setSkein: (ZoomSkein*) skein;

// Laying things out
- (void) skeinNeedsLayout;

// The delegate
- (void) setDelegate: (id) delegate;
- (id)   delegate;

// Affecting the display
- (void) scrollToItem: (ZoomSkeinItem*) item;
- (ZoomSkeinItem*) itemAtPoint: (NSPoint) point;

- (void) editItem: (ZoomSkeinItem*) skeinItem;
- (void) setSelectedItem: (ZoomSkeinItem*) skeinItem;
- (ZoomSkeinItem*) selectedItem;

@end

// = Using with the web kit =
#import <WebKit/WebKit.h>

@interface ZoomSkeinView(ZoomSkeinViewWeb)<WebDocumentView>

@end

// = Delegate =
@interface NSObject(ZoomSkeinViewDelegate)

// Playing the game
- (void) restartGame;
- (void) playToPoint: (ZoomSkeinItem*) point
		   fromPoint: (ZoomSkeinItem*) currentPoint;

@end
