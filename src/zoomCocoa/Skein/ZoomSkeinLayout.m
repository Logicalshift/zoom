//
//  ZoomSkeinLayout.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <objc/objc-runtime.h>

#import "ZoomSkeinLayout.h"

// Define this to use the 'new' skein colouring style
#define SkeinDrawingStyleNew

// Constants
static const float itemPadding = 56.0;

static NSDictionary* itemTextAttributes = nil;
static NSDictionary* labelTextAttributes = nil;

// Bug in weak linking? Can't use NSShadowAttributeName... Hmph
static NSString* ZoomNSShadowAttributeName = @"NSShadow";

// Images
static NSImage* unplayed, *selected, *active, *unchanged, *changed, *annotation, *commentaryBadge;

#ifdef SkeinDrawingStyleNew
static NSImage* unchangedDark, *activeDark;
#endif

@implementation ZoomSkeinLayout

// = Factory methods =

+ (NSImage*) imageNamed: (NSString*) name {
	NSImage* img = [NSImage imageNamed: name];
	
	if (img == nil) {
		// Try to load from the framework instead
		NSBundle* ourBundle = [NSBundle bundleForClass: [self class]];
		NSString* filename = [ourBundle pathForResource: name
												 ofType: @"png"];
		
		if (filename) {
			img = [[[NSImage alloc] initWithContentsOfFile: filename] autorelease];
		}
	}
	
	[img setFlipped: YES];
	return img;
}

+ (NSImage*) darkenImage: (NSImage*) image {
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [image size];

	NSImage* highlighted = [[NSImage alloc] initWithSize: imgRect.size];
	
	[highlighted lockFocus];
	
	// Background
	[[NSColor colorWithDeviceRed: 0.0
						   green: 0.0
							blue: 0.0
						   alpha: 0.25] set];
	NSRectFill(imgRect);
	
	// The item
	[image drawAtPoint: NSMakePoint(0,0)
			  fromRect: imgRect
			 operation: NSCompositeDestinationAtop
			  fraction: 1.0];
	
	[highlighted unlockFocus];
	
	// Release
	return [highlighted autorelease];
}

+ (void) initialize {
	NSObject* labelShadow = nil;
	
	if (objc_lookUpClass("NSShadow") != nil) {
		labelShadow = [[objc_lookUpClass("NSShadow") alloc] init];
		[labelShadow setShadowOffset: NSMakeSize(0.4, -1)];
		[labelShadow setShadowBlurRadius: 1.5];
		[labelShadow setShadowColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.7]];
	}
	
	unplayed   = [[[self class] imageNamed: @"Skein-unplayed"] retain];
	selected   = [[[self class] imageNamed: @"Skein-selected"] retain];
	active     = [[[self class] imageNamed: @"Skein-active"] retain];
	unchanged  = [[[self class] imageNamed: @"Skein-unchanged"] retain];
	changed    = [[[self class] imageNamed: @"Skein-changed"] retain];
	annotation = [[[self class] imageNamed: @"Skein-annotation"] retain];
	commentaryBadge = [[[self class] imageNamed: @"SkeinDiffersBadge"] retain];
	
#ifdef SkeinDrawingStyleNew
	unchangedDark = [[[self class] darkenImage: unchanged] retain];
	activeDark = [[[self class] darkenImage: active] retain];
#endif	
	
	itemTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize: 10], NSFontAttributeName,
		[NSColor blackColor], NSForegroundColorAttributeName,
		nil] retain];
	labelTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize: 13], NSFontAttributeName,
		[NSColor blackColor], NSForegroundColorAttributeName,
		labelShadow, ZoomNSShadowAttributeName,
		nil] retain];
	
	if (labelShadow) [labelShadow release];
}

+ (void) drawImage: (NSImage*) img
		   atPoint: (NSPoint) pos
		 withWidth: (float) width {
	pos.x = floorf(pos.x);
	pos.y = floorf(pos.y);
	width = floorf(width);
	
	// Images must be 90x30
	if (width <= 0.0) width = 1.0;
	
	// Draw the middle bit
	NSRect bitToDraw = NSMakeRect(pos.x, pos.y, 50, 30);
	NSRect bitToDrawFrom = NSMakeRect(20, 0, 50, 30);
	float p;
	
	for (p=width; p>=0.0; p-=50.0) {
		if (p < 50.0) {
			bitToDrawFrom.size.width = bitToDraw.size.width = p;
		}
		
		bitToDraw.origin.x = pos.x + p - bitToDraw.size.width;
		
		[img drawInRect: bitToDraw
			   fromRect: bitToDrawFrom
			  operation: NSCompositeSourceOver
			   fraction: 1.0];	
	}
	
	// Draw the edge bits
	[img drawInRect: NSMakeRect(pos.x-20, pos.y, 20, 30)
		   fromRect: NSMakeRect(0,0,20,30)
		  operation: NSCompositeSourceOver
		   fraction: 1.0];	
	[img drawInRect: NSMakeRect(pos.x+width, pos.y, 20, 30)
		   fromRect: NSMakeRect(70,0,20,30)
		  operation: NSCompositeSourceOver
		   fraction: 1.0];	
}

// = Initialisation =

- (id) init {
	return [self initWithRootItem: nil];
}

- (id) initWithRootItem: (ZoomSkeinItem*) item {
	self = [super init];
	
	if (self) {
		rootItem = [item retain];

		itemWidth = 120.0; // Pixels
		itemHeight = 96.0;
		packingStyle = IFSkeinPackTight;
	}
	
	return self;
}

- (void) dealloc {
	if (rootItem) [rootItem release];
	
	if (itemForItem) [itemForItem release];
	
	if (tree) [tree release];
	if (levels) [levels release];
	
	if (highlightedSet) [highlightedSet release];
	if (highlightedLineItem) [highlightedLineItem release];
	
	[super dealloc];
}

// = Setting skein data =

- (void) setItemWidth: (float) newItemWidth {
	if (newItemWidth < 82.0) newItemWidth = 82.0;
	itemWidth = newItemWidth;
}

- (void) setItemHeight: (float) newItemHeight {
	itemHeight = newItemHeight;
}

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

- (void) updateHighlightDetails {
	// Update the set of items that use the 'transcript line' style
	
	// Clear the items that are currently marked as highlighted
	if (highlightedSet != nil) {
		NSEnumerator* oldHighlightEnum = [itemForItem objectEnumerator];
		ZoomSkeinLayoutItem* layoutItem;
		
		while (layoutItem = [oldHighlightEnum nextObject])  {
			[layoutItem setOnSkeinLine: NO];
			[layoutItem setRecentlyPlayed: NO];
		}
	}
	
	// This set is a set of NSValue pointers to zoomSkeinItems. It's used while drawing.
	[highlightedSet release];
	highlightedSet = [[NSMutableSet alloc] init];
	
	// Iterate up from the highlighted item
	ZoomSkeinItem* currentItem = highlightedLineItem;
	
	while (currentItem != nil) {
		// Store this item
		ZoomSkeinLayoutItem* itemUpwards = [itemForItem objectForKey: [NSValue valueWithPointer: currentItem]];
		[itemUpwards setOnSkeinLine: YES];
		[itemUpwards setRecentlyPlayed: YES];
		
		// Up the tree
		currentItem = [currentItem parent];
	}
	
	// Iterate down from the highlighted item, so long as there is only one child item
	currentItem = highlightedLineItem;
	
	while ([[currentItem children] count] == 1) {
		// Move down the tree
		currentItem = [[[currentItem children] allObjects] objectAtIndex: 0];
		
		// Store this item
		ZoomSkeinLayoutItem* itemUpwards = [itemForItem objectForKey: [NSValue valueWithPointer: currentItem]];
		[itemUpwards setOnSkeinLine: YES];
		[itemUpwards setRecentlyPlayed: NO];
		// [[itemForItem objectForKey: [NSValue valueWithPointer: currentItem]] setOnSkeinLine: YES];
	}
}

- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine {
	// Do nothing if there's nothing to do
	if (itemOnLine == highlightedLineItem) return;
	
	[highlightedLineItem release];
	highlightedLineItem = [itemOnLine retain];
	
	[self updateHighlightDetails];
}

// = Performing layout =

- (ZoomSkeinLayoutItem*) layoutSkeinItemLoose: (ZoomSkeinItem*) item
									withLevel: (int) level {
	if (item == nil) return nil;
	
	NSEnumerator* childEnum = [[item children] objectEnumerator];
	ZoomSkeinItem* child;
	float position = 0.0;
	float lastPosition = 0.0;
	float lastWidth = 0.0;
	ZoomSkeinLayoutItem* childItem;
	
	NSMutableArray* children = [NSMutableArray array];
	
	while (child = [childEnum nextObject]) {
		// Layout the child item
		childItem = [self layoutSkeinItemLoose: child
									 withLevel: level+1];
		
		// Position it (first iteration: we center later)
		position += lastWidth/2.0; // Add in halves: we're dealing with object centers
		lastPosition = position;
		
		lastWidth = [childItem fullWidth];
		position += lastWidth/2.0;
		
		[childItem setPosition: position];
		
		// Add to the list of children for this item
		[children addObject: childItem];
	}
	
	// Update position to be the total width
	position += lastWidth/2.0;
	
	// Should only happen if there are no children
	if (position == 0.0) position = itemWidth;
	
	// Center the children	
	float center = position / 2.0;
	
	childEnum = [children objectEnumerator];
	while (childItem = [childEnum nextObject]) {
		[childItem setPosition: [childItem position] - center];
	}
	
	// Adjust the width to fit the text, if required
	float ourWidth = [item commandSize].width;
	float labelWidth = [item annotationSize].width;
	
	if (labelWidth > ourWidth) ourWidth = labelWidth;
	
	if (position < (ourWidth + itemPadding)) position = ourWidth + itemPadding;
	
	// Return the result
	ZoomSkeinLayoutItem* result = [[ZoomSkeinLayoutItem alloc] initWithItem: item
																	  width: ourWidth
																  fullWidth: position
																	  level: level];
	
	[result setChildren: children];
	
	// Index this item
	[itemForItem setObject: result
					forKey: [NSValue valueWithPointer: item]];
	
	// Add to the 'levels' array, which contains which items to draw at which levels
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[[levels objectAtIndex: level] addObject: result];
	[result release]; // Is retained in the levels array, so we don't autorelease (saves some time. Might cause bugs in the future though, so NOTE THIS)
	
	return result;
}

#define MaxTightDepth 8

- (ZoomSkeinLayoutItem*) layoutSkeinItemTight: (ZoomSkeinItem*) item
									withLevel: (int) level {
	// Counterpart to layoutSkeinItemLoose that is slightly more intelligent about re-using vertical space
	if (item == nil) return nil;
	
	NSEnumerator* childEnum = [[item children] objectEnumerator];
	ZoomSkeinItem* child;
	ZoomSkeinLayoutItem* lastItem = nil;
	float position = 0.0;
	float lastWidth = 0.0;
	ZoomSkeinLayoutItem* childItem;
	
	NSMutableArray* children = [NSMutableArray array];
	
	while (child = [childEnum nextObject]) {
		// Layout the child item
		childItem = [self layoutSkeinItemTight: child
									 withLevel: level+1];
		
		// Pick an effective item width
		float effectiveWidthLeft = lastWidth;
		float effectiveWidthRight = [childItem fullWidth];
		
		if (lastItem) {
			int leftDepth = [lastItem depth];
			int rightDepth = [childItem depth];
			
			if (leftDepth < rightDepth && leftDepth < MaxTightDepth) {
				
			} else if (rightDepth < leftDepth && rightDepth < MaxTightDepth) {
				
			}
		}
		
		// Position it (first iteration: we center later)
		position += effectiveWidthLeft/2.0; // Add in halves: we're dealing with object centers
		
		lastWidth = effectiveWidthRight;
		position += lastWidth/2.0;
		
		[childItem setPosition: position];
		
		// Add to the list of children for this item
		[children addObject: childItem];
		lastItem = childItem;
	}
	
	// Update position to be the total width
	position += lastWidth/2.0;
	
	// Should only happen if there are no children
	if (position == 0.0) position = itemWidth;
	
	// Center the children	
	float center = position / 2.0;
	
	childEnum = [children objectEnumerator];
	while (childItem = [childEnum nextObject]) {
		[childItem setPosition: [childItem position] - center];
	}
	
	// Adjust the width to fit the text, if required
	float ourWidth = [item commandSize].width;
	float labelWidth = [item annotationSize].width;
	
	if (labelWidth > ourWidth) ourWidth = labelWidth;
	
	if (position < (ourWidth + itemPadding)) position = ourWidth + itemPadding;
	
	// Return the result
	ZoomSkeinLayoutItem* result = [[ZoomSkeinLayoutItem alloc] initWithItem: item
																	  width: ourWidth
																  fullWidth: position
																	  level: level];
	
	[result setChildren: children];
	
	// Index this item
	[itemForItem setObject: result
					forKey: [NSValue valueWithPointer: item]];
	
	// Add to the 'levels' array, which contains which items to draw at which levels
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[[levels objectAtIndex: level] addObject: result];
	[result release]; // Is retained in the levels array, so we don't autorelease (saves some time. Might cause bugs in the future though, so NOTE THIS)
	
	return result;
}

- (void) fixPositions: (ZoomSkeinLayoutItem*) item
		   withOffset: (float) offset {
	// After running through layoutSkeinItem, all positions are relative to the 'parent' item
	// This routine fixes this
	
	// Move this item by the offset (fixing it with an absolute position)
	float oldPos = [item position];
	float newPos = oldPos + offset;
	[item setPosition: newPos];
	
	// Fix the children to have absolute positions
	NSEnumerator* childEnum = [[item children] objectEnumerator];
	ZoomSkeinLayoutItem* child;
	
	while (child = [childEnum nextObject]) {
		[self fixPositions: child
				withOffset: newPos];
	}
	
	float leftPos = newPos - ([item fullWidth]/2.0);
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
	
	tree = [[self layoutSkeinItemLoose: rootItem
							 withLevel: 0] retain];
	
	if (tree != nil) {
		// Transform the 'relative' positions of all items into 'absolute' positions
		globalOffset = 0; globalWidth = 0;
		[self fixPositions: tree
				withOffset: 0];
	}
	
	if (highlightedLineItem) [self updateHighlightDetails];
}

// = Getting layout data =

- (int) levels {
	return [levels count];
}

- (NSArray*) itemsOnLevel: (int) level {
	if (level < 0 || level >= [levels count]) return nil;
	
	NSMutableArray* res = [NSMutableArray array];
	NSEnumerator* levelEnum = [[levels objectAtIndex: level] objectEnumerator];
	ZoomSkeinLayoutItem* item;
	
	while (item = [levelEnum nextObject])  {
		[res addObject: [item item]];
	}
	
	return res;
}

- (NSArray*) dataForLevel: (int) level {
	if (level < 0 || level >= [levels count]) return nil;
	return [levels objectAtIndex: level];
}

// = Raw item data =

- (ZoomSkeinLayoutItem*) dataForItem: (ZoomSkeinItem*) item {
	return [itemForItem objectForKey: [NSValue valueWithPointer: item]]; // Yeah, yeah. Items are distinguished by command, not location in the tree
}

- (float) xposForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] position] + globalOffset;
}

- (int) levelForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] level];
}

- (float) widthForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] width];
}

- (float) fullWidthForItem: (ZoomSkeinItem*) item {
	return [[self dataForItem: item] fullWidth];
}

// = Item positioning data =

- (NSRect) activeAreaForData: (ZoomSkeinLayoutItem*) item {
	NSRect itemRect;
	float ypos = ((float)[item level]) * itemHeight + (itemHeight/2.0);
	float position = [item position];
	float width = [item width];
	
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

- (NSRect) textAreaForData: (ZoomSkeinLayoutItem*) item {
	NSRect itemRect;
	float ypos = ((float)[item level]) * itemHeight + (itemHeight/2.0);
	float position = [item position];
	float width = [item width];
	
	// Basic rect
	itemRect.origin.x = position + globalOffset - (width/2.0);
	itemRect.origin.y = ypos + 1;
	itemRect.size.width = width;
	itemRect.size.height = [[NSFont systemFontOfSize: 10] defaultLineHeightForFont];
	
	// Move it down by a few pixels if this is a selected item
	if ([item item] == selectedItem) {
		itemRect.origin.y += 2;
	}
	
	return itemRect;
}

- (NSRect) activeAreaForItem: (ZoomSkeinItem*) itemData {
	return [self activeAreaForData: [self dataForItem: itemData]];
}

- (NSRect) textAreaForItem: (ZoomSkeinItem*) itemData {
	return [self textAreaForData: [self dataForItem: itemData]];
}

- (ZoomSkeinItem*) itemAtPoint: (NSPoint) point {
	// Searches for the item that is under the given point
	
	// Recall that items are drawn at:
	//		float ypos = ((float)level)*itemHeight + (itemHeight / 2.0);
	//      The 'lozenge' extends -8 upwards, and has a height of 30 pixels
	//		There needs to be some space for icon controls
	//		Levels start at 0
	//		Labels appear above the item (in the control space: so you can't directly click on a label)
	
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
	ZoomSkeinLayoutItem* item;
	
	while (item = [levelEnum nextObject]) {
		float thisItemWidth = [item width];
		float itemPos = [item position] + globalOffset;
		
		// There's a +40 border either side of the item
		thisItemWidth += 40.0;
		
		// Buttons require a minimum width
		if (thisItemWidth < 72.0) {
			thisItemWidth = 72.0;
		}
		
		// Item is centered
		thisItemWidth /= 2.0;
		
		if (point.x > (itemPos - thisItemWidth) && point.x < (itemPos + thisItemWidth)) {
			// This is the item
			return [item item];
		}
	}
	
	// Nothing found
	return nil;
}

- (NSSize) size {	
	if (tree) {
		NSSize res;
		
		res.width = [tree fullWidth];
		res.height = ((float)[levels count]) * itemHeight;
		
		return res;
	} else {
		return NSMakeSize(0,0);
	}
}

// = Drawing the layout =

- (void) drawInRect: (NSRect) rect {
	// Fill in the background
	[[NSColor whiteColor] set];
	NSRectFill(rect);
	
	// Actually draw the skein
	int startLevel = floorf(NSMinY(rect) / itemHeight)-1;
	int endLevel = ceilf(NSMaxY(rect) / itemHeight);
	int level;
	
	for (level = startLevel; level < endLevel; level++) {
		if (level < 0) continue;
		if (level >= [self levels]) break;
		
		// Iterate through the items on this level...
		NSEnumerator* levelEnum = [[self dataForLevel: level] objectEnumerator];
		ZoomSkeinLayoutItem* item;
		
		float ypos = ((float)level)*itemHeight + (itemHeight / 2.0);
		
		while (item = [levelEnum nextObject]) {
			ZoomSkeinItem* skeinItem = [item item];
			float xpos = [item position] + globalOffset;
			NSSize size = [skeinItem commandSize];
			
			// Draw the background
			NSImage* background = unchanged;
			float bgWidth = size.width;
			//if (bgWidth < 90.0) bgWidth = 90.0;
			
#ifdef SkeinDrawingStyleNew
			BOOL darken = [[skeinItem commentary] length] > 0;
			
			background = unchanged;
			if (darken) background = unchangedDark;
			if ([item recentlyPlayed] && !darken) background = active;
			if ([item recentlyPlayed] && darken) background = activeDark;
#else
			if (![skeinItem played]) background = unplayed;
			if ([skeinItem changed]) background = changed;
			// if (skeinItem == activeItem) background = active;
			if ([skeinItem parent] == activeItem) background = active;
			// if (skeinItem == [self selectedItem]) background = selected;
#endif
			
			[[self class] drawImage: background
							atPoint: NSMakePoint(xpos - bgWidth/2.0, ypos-8 + (background==selected?2.0:0.0))
						  withWidth: bgWidth];
			
			// Draw the item
			[skeinItem drawCommandAtPosition: NSMakePoint(xpos - (size.width/2), ypos + (background==selected?2.0:0.0))];
			
			// Draw the 'commentary changed' badge if necessary
			if ([skeinItem commentaryComparison] == ZoomSkeinDifferent) {
				NSRect fromRect;
				
				fromRect.origin = NSMakePoint(0,0);
				fromRect.size = [commentaryBadge size];
				
				[commentaryBadge drawAtPoint: NSMakePoint(xpos + bgWidth/2.0 + 4, ypos + 6)
									fromRect: fromRect
								   operation: NSCompositeSourceOver
									fraction: 1.0];
			}
			
			// Draw links to the children
			[[NSColor blackColor] set];
			NSEnumerator* childEnumerator = [[item children] objectEnumerator];
			
			float startYPos = ypos + 10.0 + size.height;
			float endYPos = ypos - 10.0 + itemHeight;
			
#ifdef SkeinDrawingStyleNew
			NSColor* tempChildLink = [NSColor grayColor];
#else
			NSColor* tempChildLink = [NSColor blueColor];
#endif
			NSColor* permChildLink = [NSColor blackColor];
			
			ZoomSkeinLayoutItem* child;
			while (child = [childEnumerator nextObject]) {
				float childXPos = [child position] + globalOffset;
				BOOL annotated = [[child item] annotation]!=nil;
				
				BOOL highlightLine = [child onSkeinLine];
				
				// Thicken the line if this is on the highlighted line
				if (highlightLine) {
					[NSBezierPath setDefaultLineWidth: 3.0];
				}
				
				// Construct the line we're going to draw
				NSBezierPath* line = [[NSBezierPath alloc] init];
				[line moveToPoint: NSMakePoint(xpos, startYPos)];
				[line lineToPoint: NSMakePoint(childXPos, annotated?endYPos-18:endYPos)];
				
				// Set the appropriate colour and dash pattern
				if ([[child item] temporary]) {
					float dashPattern[2];
					
					[tempChildLink set];
					
					dashPattern[0] = 4.0;
					dashPattern[1] = 3.0;
					[line setLineDash: dashPattern
								count: 2
								phase: 0.0];
				} else {
					[permChildLink set];
				}
				
				// Draw the line
				[line stroke];
				[line release];
								 
				// Thin it out again afterwards
				if (highlightLine) {
					[NSBezierPath setDefaultLineWidth: 1.0];
				}
			}
			
			// Draw the annotation, if present
			if ([[skeinItem annotation] length] > 0) {
				float thisItemWidth = [self widthForItem: skeinItem];
				float labelWidth = [skeinItem annotationSize].width;
				
				[[self class] drawImage: annotation
								atPoint: NSMakePoint(xpos - thisItemWidth/2.0, ypos-30)
							  withWidth: thisItemWidth];
				
				[skeinItem drawAnnotationAtPosition: NSMakePoint(xpos - (labelWidth/2), ypos - 23)];
			}
		}
	}
}

- (void) drawItem: (ZoomSkeinItem*) skeinItem
		  atPoint: (NSPoint) point {
	// Draw the background
	NSImage* background = unchanged;
	float bgWidth = [self widthForItem: skeinItem];
	
	if (![skeinItem played]) background = unplayed;
	if ([skeinItem changed]) background = changed;
	// if (skeinItem == activeItem) background = active;
	if ([skeinItem parent] == activeItem) background = active;
	// if (skeinItem == [self selectedItem]) background = selected;
	
	// Temporarily unflip the background image before drawing
	// (Doing this means this call will not work in flipped views. Well, it will, but it will look dreadful)
	[background setFlipped: NO];
	[[self class] drawImage: background
					atPoint: NSMakePoint(point.x + 20, point.y + (background==selected?2.0:0.0))
				  withWidth: bgWidth];
	[background setFlipped: YES];
	
	// Draw the item
	[skeinItem drawCommandAtPosition: NSMakePoint(point.x+20, point.y+8 + (background==selected?2.0:0.0))];
}

- (NSImage*) imageForItem: (ZoomSkeinItem*) item {
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = NSMakeSize([self widthForItem: item] + 40.0, 30.0);
	
	NSImage* img = [[[NSImage alloc] initWithSize: imgRect.size] autorelease];
	
	[img lockFocus];
	[[NSColor clearColor] set];
	NSRectFill(imgRect);
	[self drawItem: item
		   atPoint: NSMakePoint(0,0)];	
	[img unlockFocus];
	
	return img;
}

- (NSImage*) image {
	NSImage* res = [[[NSImage alloc] initWithSize: [self size]] autorelease];
	
	[res lockFocus];
	
	NSAffineTransform* flip = [NSAffineTransform transform];
	
	// Almost works, except the text is upside down.
	[flip scaleXBy: 1.0
			   yBy: -1.0];
	[flip translateXBy: 0.0
				   yBy: -[self size].height];
	[flip set];
	
	NSRect imgRect;
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [self size];
	
	[self drawInRect: imgRect];
		
	[res unlockFocus];
	
	return res;
}

@end
