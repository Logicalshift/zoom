//
//  ZoomSkeinLayout.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomSkein.h"

@interface ZoomSkeinLayout : NSObject {
	ZoomSkeinItem* rootItem;

	// Item mapping
	NSMutableDictionary* itemForItem;
	
	// The layout
	NSMutableDictionary* tree;
	NSMutableArray* levels;
	float globalOffset, globalWidth;
	
	// Some extra status
	ZoomSkeinItem* activeItem;
	ZoomSkeinItem* selectedItem;
}

// Initialisation
- (id) initWithRootItem: (ZoomSkeinItem*) item;

// Setting skein data
- (void) setRootItem: (ZoomSkeinItem*) item;
- (void) setActiveItem: (ZoomSkeinItem*) item;
- (void) setSelectedItem: (ZoomSkeinItem*) item;

- (ZoomSkeinItem*) rootItem;
- (ZoomSkeinItem*) activeItem;
- (ZoomSkeinItem*) selectedItem;

// Performing the layout
- (void) layoutSkein;

// Getting layout data

- (int) levels;
- (NSArray*) itemsOnLevel: (int) level;
- (NSArray*) dataForLevel: (int) level;

- (NSDictionary*) dataForItem: (ZoomSkeinItem*) item;
- (ZoomSkeinItem*) itemForData: (NSDictionary*) data;

// General item data
- (float)    xposForItem:      (ZoomSkeinItem*) item;
- (int)      levelForItem:     (ZoomSkeinItem*) item;
- (float)    widthForItem:     (ZoomSkeinItem*) item;
- (float)    fullWidthForItem: (ZoomSkeinItem*) item;
- (NSArray*) childrenForItem:  (ZoomSkeinItem*) item;

- (float)    xposForData:      (NSDictionary*) item;
- (int)      levelForData:     (NSDictionary*) item;
- (float)    widthForData:     (NSDictionary*) item;
- (float)    fullWidthForData: (NSDictionary*) item;
- (NSArray*) childrenForData:  (NSDictionary*) item;

// Item positioning data
- (NSSize) size;

- (NSRect) activeAreaForItem: (ZoomSkeinItem*) itemData;
- (NSRect) textAreaForItem: (ZoomSkeinItem*) itemData;
- (NSRect) activeAreaForData: (NSDictionary*) itemData;
- (NSRect) textAreaForData: (NSDictionary*) itemData;
- (ZoomSkeinItem*) itemAtPoint: (NSPoint) point;

// Drawing
- (void) drawInRect: (NSRect) rect;
- (void) drawItem: (ZoomSkeinItem*) item
		  atPoint: (NSPoint) point;
- (NSImage*) imageForItem: (ZoomSkeinItem*) item;
- (NSImage*) image;

@end
