//
//  ZoomSkeinLayout.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinLayout.h"

// The item dictionary
static NSString* ZSitem           = @"ZSitem";
static NSString* ZSwidth          = @"ZSwidth";
static NSString* ZSfullwidth      = @"ZSfullwidth";
static NSString* ZSposition       = @"ZSposition";
static NSString* ZSchildren       = @"ZSchildren";
static NSString* ZSsimpleChildren = @"ZSsimpleChildren";
static NSString* ZSlevel          = @"ZSlevel";

// Constants
static const float itemWidth = 120.0; // Pixels
static const float itemHeight = 96.0;
static const float itemPadding = 56.0;

static NSDictionary* itemTextAttributes;

@implementation ZoomSkeinLayout

// = Factory methods =

+ (void) initialize {
	itemTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize: 10], NSFontAttributeName,
		[NSColor blackColor], NSForegroundColorAttributeName,
		nil] retain];
}

+ (NSMutableDictionary*) item: (ZoomSkeinItem*) item
					withWidth: (float) width
					fullWidth: (float) fullWidth
						level: (int) level {
	// Position is '0' by default
	return [NSMutableDictionary dictionaryWithObjectsAndKeys: 
		item, ZSitem, 
		[NSNumber numberWithFloat: width], ZSwidth, 
		[NSNumber numberWithFloat: fullWidth], ZSfullwidth,
		[NSNumber numberWithFloat: 0.0], ZSposition,
		[NSNumber numberWithInt: level], ZSlevel,
		nil];
}

// = Initialisation =

- (id) init {
	return [self initWithRootItem: nil];
}

- (id) initWithRootItem: (ZoomSkeinItem*) item {
	self = [super init];
	
	if (self) {
		rootItem = [item retain];
	}
	
	return self;
}

- (void) dealloc {
	if (rootItem) [rootItem release];
	
	if (itemForItem) [itemForItem release];
	
	if (tree) [tree release];
	if (levels) [levels release];
	
	[super dealloc];
}

// = Setting skein data =

- (void) setRootItem: (ZoomSkeinItem*) item {
	if (rootItem) [rootItem release];
	rootItem = [item retain];
}

- (ZoomSkeinItem*) rootItem {
	return rootItem;
}

- (void) setActiveItem: (ZoomSkeinItem*) item {
	if (activeItem) [activeItem release];
	activeItem = [item retain];
}

- (ZoomSkeinItem*) activeItem {
	return activeItem;
}

- (void) setSelectedItem: (ZoomSkeinItem*) item {
	if (selectedItem) [selectedItem release];
	selectedItem = [item retain];
}

- (ZoomSkeinItem*) selectedItem {
	return selectedItem;
}

// = Performing layout =

- (NSMutableDictionary*) layoutSkeinItem: (ZoomSkeinItem*) item
							   withLevel: (int) level {
	if (item == nil) return nil;
	
	NSEnumerator* childEnum = [[item children] objectEnumerator];
	ZoomSkeinItem* child;
	float position = 0.0;
	float lastPosition = 0.0;
	float lastWidth = 0.0;
	NSMutableDictionary* childItem;
	
	NSMutableArray* children = [NSMutableArray array];
	NSMutableArray* simpleChildren = [NSMutableArray array];
	
	while (child = [childEnum nextObject]) {
		// Layout the child item
		childItem = [self layoutSkeinItem: child
								withLevel: level+1];
		
		// Position it (first iteration: we center later)
		position += lastWidth/2.0; // Add in halves: we're dealing with object centers
		lastPosition = position;
		
		lastWidth = [[childItem objectForKey: ZSfullwidth] floatValue];
		position += lastWidth/2.0;
		
		[childItem setObject: [NSNumber numberWithFloat: position]
					  forKey: ZSposition];
		
		// Add to the list of children for this item
		[children addObject: childItem];
		[simpleChildren addObject: child];
	}
	
	// Update position to be the total width
	position += lastWidth/2.0;
	
	// Should only happen if there are no children
	if (position == 0.0) position = itemWidth;
	
	// Center the children	
	float center = position / 2.0;
	
	childEnum = [children objectEnumerator];
	while (childItem = [childEnum nextObject]) {
		[childItem setObject: [NSNumber numberWithFloat: [[childItem objectForKey: ZSposition] floatValue] - center]
					  forKey: ZSposition];
	}
	
	// Adjust the width to fit the text, if required
	float ourWidth = [[item command] sizeWithAttributes: itemTextAttributes].width;
	if (position < (ourWidth + itemPadding)) position = ourWidth + itemPadding;
	
	// Return the result
	NSMutableDictionary* result = [[self class] item: item
										   withWidth: ourWidth
										   fullWidth: position
											   level: level];
	
	[result setObject: children
			   forKey: ZSchildren];
	[result setObject: simpleChildren
			   forKey: ZSsimpleChildren];
	
	// Index this item
	[itemForItem setObject: result
					forKey: [NSValue valueWithPointer: item]];
	
	// Add to the 'levels' array, which contains which items to draw at which levels
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[[levels objectAtIndex: level] addObject: result];
	
	return result;
}

- (void) fixPositions: (NSMutableDictionary*) item
		   withOffset: (float) offset {
	// After running through layoutSkeinItem, all positions are relative to the 'parent' item
	// This routine fixes this
	
	// Move this item by the offset (fixing it with an absolute position)
	float oldPos = [[item objectForKey: ZSposition] floatValue];
	float newPos = oldPos + offset;
	[item setObject: [NSNumber numberWithFloat: newPos]
			 forKey: ZSposition];
	
	// Fix the children to have absolute positions
	NSEnumerator* childEnum = [[item objectForKey: ZSchildren] objectEnumerator];
	NSMutableDictionary* child;
	
	while (child = [childEnum nextObject]) {
		[self fixPositions: child
				withOffset: newPos];
	}
	
	float leftPos = newPos - ([[item objectForKey: ZSfullwidth] floatValue]/2.0);
	if ((-leftPos) > globalOffset)
		globalOffset = -leftPos;
	if (newPos > globalWidth)
		globalWidth = newPos;
}

- (void) layoutSkein {	
	if (rootItem == nil) return;
	
	if (itemForItem) [itemForItem release];
	itemForItem = [[NSMutableDictionary alloc] init];
	
	// Perform initial layout of the items
	if (tree) {
		[tree release];
		tree = nil;
	}
	if (levels) {
		[levels release];
		levels = nil;
	}
	levels = [[NSMutableArray alloc] init];
	
	tree = [[self layoutSkeinItem: rootItem
						withLevel: 0] retain];
	
	if (tree != nil) {
		// Transform the 'relative' positions of all items into 'absolute' positions
		globalOffset = 0; globalWidth = 0;
		[self fixPositions: tree
				withOffset: 0];
	}
}

// = Getting layout data =

- (int) levels {
	return [levels count];
}

- (NSArray*) itemsOnLevel: (int) level {
	if (level < 0 || level >= [levels count]) return nil;
	
	NSMutableArray* res = [NSMutableArray array];
	NSEnumerator* levelEnum = [[levels objectAtIndex: level] objectEnumerator];
	NSDictionary* item;
	
	while (item = [levelEnum nextObject])  {
		[res addObject: [item objectForKey: ZSitem]];
	}
	
	return res;
}

- (NSArray*) dataForLevel: (int) level {
	if (level < 0 || level >= [levels count]) return nil;
	return [levels objectAtIndex: level];
}

// = Raw item data =

- (NSDictionary*) dataForItem: (ZoomSkeinItem*) item {
	return [itemForItem objectForKey: [NSValue valueWithPointer: item]]; // Yeah, yeah. Items are distinguished by command, not location in the tree
}

- (ZoomSkeinItem*) itemForData: (NSDictionary*) data {
	return [data objectForKey: ZSitem];
}

- (float) xposForItem: (ZoomSkeinItem*) item {
	return [[[self dataForItem: item] objectForKey: ZSposition] floatValue] + globalOffset;
}

- (int) levelForItem: (ZoomSkeinItem*) item {
	return [[[self dataForItem: item] objectForKey: ZSlevel] intValue];
}

- (float) widthForItem: (ZoomSkeinItem*) item {
	return [[[self dataForItem: item] objectForKey: ZSwidth] floatValue];
}

- (float) fullWidthForItem: (ZoomSkeinItem*) item {
	return [[[self dataForItem: item] objectForKey: ZSfullwidth] floatValue];
}

- (NSArray*) childrenForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] objectForKey: ZSsimpleChildren];
}

- (float) xposForData: (NSDictionary*) item {
	return [[item objectForKey: ZSposition] floatValue] + globalOffset;
}

- (int) levelForData: (NSDictionary*) item {
	return [[item objectForKey: ZSlevel] intValue];
}

- (float) widthForData: (NSDictionary*) item {
	return [[item objectForKey: ZSwidth] floatValue];
}

- (float) fullWidthForData: (NSDictionary*) item {
	return [[item objectForKey: ZSfullwidth] floatValue];
}

- (NSArray*) childrenForData: (NSDictionary*) item {
	return [item objectForKey: ZSchildren];
}

// = Item positioning data =

- (NSRect) activeAreaForItem: (NSDictionary*) item {
	NSRect itemRect;
	float ypos = ((float)[[item objectForKey: ZSlevel] intValue]) * itemHeight + (itemHeight/2.0);
	float position = [[item objectForKey: ZSposition] floatValue];
	float width = [[item objectForKey: ZSwidth] floatValue];
	
	// Basic rect
	itemRect.origin.x = position + globalOffset - (width/2.0) - 20.0;
	itemRect.origin.y = ypos - 8;
	itemRect.size.width = width + 40.0;
	itemRect.size.height = 30.0;
	
	// ... adjusted for the buttons
	if (itemRect.size.width < (32.0 + 40.0)) {
		itemRect.origin.x = position + globalOffset - (32.0+40.0)/2.0;
		itemRect.size.width = 32.0 + 40.0;
	}
	itemRect.origin.y = ypos - 18;
	itemRect.size.height = 52.0;
	
	// 'overflow' border
	itemRect = NSInsetRect(itemRect, -4.0, -4.0);	
	
	return itemRect;
}

- (NSRect) textAreaForItem: (NSDictionary*) item {
	NSRect itemRect;
	float ypos = ((float)[[item objectForKey: ZSlevel] intValue]) * itemHeight + (itemHeight/2.0);
	float position = [[item objectForKey: ZSposition] floatValue];
	float width = [[item objectForKey: ZSwidth] floatValue];
	
	// Basic rect
	itemRect.origin.x = position + globalOffset - (width/2.0);
	itemRect.origin.y = ypos + 1;
	itemRect.size.width = width;
	itemRect.size.height = [[NSFont systemFontOfSize: 10] defaultLineHeightForFont];
	
	// Move it down by a few pixels if this is a selected item
	if ([item objectForKey: ZSitem] == selectedItem) {
		itemRect.origin.y += 2;
	}
	
	return itemRect;
}

- (ZoomSkeinItem*) itemAtPoint: (NSPoint) point {
	// Searches for the item that is under the given point
	
	// Recall that items are drawn at:
	//		float ypos = ((float)level)*itemHeight + (itemHeight / 2.0);
	//      The 'lozenge' extends -8 upwards, and has a height of 30 pixels
	//		There needs to be some space for icon controls, but we'll leave them out for the moment
	//		Levels start at 0
	
	// Check for level
	int level = floorf(point.y/itemHeight);
	
	if (level < 0 || level >= [levels count]) return nil;
	
	// Position in level
	float levelPos = ((float)level)*itemHeight + (itemHeight / 2.0);
	float levelOffset = point.y - levelPos;
	
	// Must correspond to the lozenge
	//if (levelOffset < -8) return nil;
	//if (levelOffset >= 22) return nil;
	if (levelOffset < -18) return nil;
	if (levelOffset >= 34) return nil;
	
	// Find which item is selected (if any)
	
	// Recall that item positions are centered. Widths are calculated
	NSEnumerator* levelEnum = [[levels objectAtIndex: level] objectEnumerator];
	NSDictionary* item;
	
	while (item = [levelEnum nextObject]) {
		float itemWidth = [[item objectForKey: ZSwidth] floatValue];
		float itemPos = [[item objectForKey: ZSposition] floatValue] + globalOffset;
		
		// There's a +40 border either side of the item
		itemWidth += 40.0;
		
		// Item is centered
		itemWidth /= 2.0;
		
		if (point.x > (itemPos - itemWidth) && point.x < (itemPos + itemWidth)) {
			// This is the item
			return [item objectForKey: ZSitem];
		}
	}
	
	// Nothing found
	return nil;
}

- (NSSize) size {	
	if (tree) {
		NSSize res;
		
		res.width = [[tree objectForKey: ZSfullwidth] floatValue];
		res.height = ((float)[levels count]) * itemHeight;
		
		return res;
	} else {
		return NSMakeSize(0,0);
	}
}

@end
