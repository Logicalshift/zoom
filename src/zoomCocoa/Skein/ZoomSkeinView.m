//
//  ZoomSkeinView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinView.h"

// Constants
static const float itemWidth = 120.0; // Pixels
static const float itemHeight = 96.0;
static const float itemPadding = 56.0;

// Drawing info
static NSDictionary* itemTextAttributes;

// Entries in the item dictionary
static NSString* ZSitem = @"ZSitem";
static NSString* ZSwidth = @"ZSwidth";
static NSString* ZSfullwidth = @"ZSfullwidth";
static NSString* ZSposition = @"ZSposition";
static NSString* ZSchildren = @"ZSchildren";
static NSString* ZSlevel    = @"ZSlevel";

// Images
static NSImage* unplayed, *selected, *active, *unchanged, *changed;
static NSImage* add, *delete, *locked, *unlocked, *annotate, *transcript;

// Buttons
enum ZSVbutton
{
	ZSVnoButton = 0,
	ZSVaddButton,
	ZSVdeleteButton,
	ZSVlockButton,
	ZSVannotateButton,
	ZSVtranscriptButton,

	ZSVmainItem = 256
};

// Our sooper sekrit interface
@interface ZoomSkeinView(ZoomSkeinViewPrivate)

// Item information
- (NSDictionary*) itemForItem: (ZoomSkeinItem*) item;
- (NSRect) activeAreaForItem: (NSDictionary*) item;
- (NSRect) textAreaForItem: (NSDictionary*) item;

// Layout
- (void) layoutSkein;
- (void) updateTrackingRects;

// UI
- (void) mouseEnteredView;
- (void) mouseLeftView;
- (void) mouseEnteredItem: (NSDictionary*) item;
- (void) mouseLeftItem: (NSDictionary*) item;

- (enum ZSVbutton) buttonUnderPoint: (NSPoint) point
							 inItem: (NSDictionary*) item;

- (void) addButtonClicked: (NSEvent*) event
				 withItem: (NSDictionary*) item;
- (void) deleteButtonClicked: (NSEvent*) event
					withItem: (NSDictionary*) item;
- (void) annotateButtonClicked: (NSEvent*) event
					  withItem: (NSDictionary*) item;
- (void) transcriptButtonClicked: (NSEvent*) event
						withItem: (NSDictionary*) item;
- (void) lockButtonClicked: (NSEvent*) event
				  withItem: (NSDictionary*) item;

- (void) cancelEditing: (id) sender;
- (void) finishEditing: (id) sender;

@end

@implementation ZoomSkeinView

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

+ (void) drawImage: (NSImage*) img
		   atPoint: (NSPoint) pos
		 withWidth: (float) width {
	pos.x = floorf(pos.x);
	pos.y = floorf(pos.y);
	width = floorf(width);
	
	// Images must be 90x30
	if (width == 90.0) {
		[img drawAtPoint: pos
				fromRect: NSMakeRect(0,0,90,30)
			   operation: NSCompositeSourceOver
				fraction: 1.0];
		
		return;
	}
	
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

+ (void) initialize {
	unplayed   = [[[self class] imageNamed: @"Skein-unplayed"] retain];
	selected   = [[[self class] imageNamed: @"Skein-selected"] retain];
	active     = [[[self class] imageNamed: @"Skein-active"] retain];
	unchanged  = [[[self class] imageNamed: @"Skein-unchanged"] retain];
	changed    = [[[self class] imageNamed: @"Skein-changed"] retain];
	
	add        = [[[self class] imageNamed: @"SkeinAdd"] retain];
	delete     = [[[self class] imageNamed: @"SkeinDelete"] retain];
	locked     = [[[self class] imageNamed: @"SkeinLocked"] retain];
	unlocked   = [[[self class] imageNamed: @"SkeinUnlocked"] retain];
	annotate   = [[[self class] imageNamed: @"SkeinAnnotate"] retain];
	transcript = [[[self class] imageNamed: @"SkeinTranscript"] retain];
	
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

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
	
    if (self) {
		skein = [[ZoomSkein alloc] init];
		activeButton = ZSVnoButton;
    }
	
    return self;
}

- (void) dealloc {
	[skein release];
	
	if (tree) [tree release];
	if (levels) [levels release];
	if (trackingRects) [trackingRects release];
	if (itemForItem) [itemForItem release];

	if (itemEditor != nil) [itemEditor release];
	if (itemToEdit != nil) [itemToEdit release];
	
	[super dealloc];
}

// = Information about items =

- (NSDictionary*) itemForItem: (ZoomSkeinItem*) item {
	if (skeinNeedsLayout) [self layoutSkein];
	
	return [itemForItem objectForKey: [NSValue valueWithPointer: item]]; // Yeah, yeah. Items are distinguished by command, not location in the tree
}

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
	
	return itemRect;
}

// = Drawing =

+ (void) drawButton: (NSImage*) button
			atPoint: (NSPoint) pt
		highlighted: (BOOL) highlight {
	NSRect imgRect;
	
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [button size];
	
	if (!highlight) {
		[button drawAtPoint: pt
				   fromRect: imgRect
				  operation: NSCompositeSourceOver
				   fraction: 1.0];
	} else {
		NSImage* highlighted = [[NSImage alloc] initWithSize: imgRect.size];
		
		[highlighted lockFocus];
		
		// Background
		[[NSColor colorWithDeviceRed: 0.0
							   green: 0.0
								blue: 0.0
							   alpha: 0.4] set];
		NSRectFill(imgRect);
		
		// The item
		[button drawAtPoint: NSMakePoint(0,0)
				   fromRect: imgRect
				  operation: NSCompositeDestinationAtop
				   fraction: 1.0];
		
		[highlighted unlockFocus];
		
		// Draw
		[highlighted drawAtPoint: pt
						fromRect: imgRect
					   operation: NSCompositeSourceOver
						fraction: 1.0];
		
		// Release
		[highlighted release];
	}
}

- (void)drawRect:(NSRect)rect {
	if (tree == nil) return;
	
	if (skeinNeedsLayout) [self layoutSkein];
	
	// (Sigh, will fail to keep track of these properly otherwise)
	NSRect visRect = [self visibleRect];
	if (!NSEqualRects(visRect, lastVisibleRect)) {
		// Need to only update this occasionally, or some redraws may cause an infinite loop
		[self updateTrackingRects];
	}
	lastVisibleRect = visRect;
	
	// Fill in the background
	[[NSColor whiteColor] set];
	NSRectFill(rect);
	
	// Actually draw the skein
	int startLevel = floorf(NSMinY(rect) / itemHeight)-1;
	int endLevel = ceilf(NSMaxY(rect) / itemHeight);
	int level;
		
	for (level = startLevel; level < endLevel; level++) {
		if (level < 0) continue;
		if (level >= [levels count]) break;
		
		// Iterate through the items on this level...
		NSEnumerator* levelEnum = [[levels objectAtIndex: level] objectEnumerator];
		NSDictionary* item;
		
		float ypos = ((float)level)*itemHeight + (itemHeight / 2.0);
		
		while (item = [levelEnum nextObject]) {
			ZoomSkeinItem* skeinItem = [item objectForKey: ZSitem];
			float xpos = [[item objectForKey: ZSposition] floatValue] + globalOffset;
			NSSize size = [[skeinItem command] sizeWithAttributes: itemTextAttributes];
			
			// Draw the background
			NSImage* background = unchanged;
			float bgWidth = size.width;
			//if (bgWidth < 90.0) bgWidth = 90.0;
			
			if (![skeinItem played]) background = unplayed;
			if ([skeinItem changed]) background = changed;
			if (skeinItem == [skein activeItem]) background = active;
			if ([skeinItem parent] == [skein activeItem]) background = changed;
			
			[ZoomSkeinView drawImage: background
							 atPoint: NSMakePoint(xpos - bgWidth/2.0, ypos-8)
						   withWidth: bgWidth];
/*			[background drawAtPoint: NSMakePoint(xpos - 45, ypos - 8)
						   fromRect: NSMakeRect(0,0,90,30)
						  operation: NSCompositeSourceOver
						   fraction: 1.0]; */

			// Draw the item
			[[skeinItem command] drawAtPoint: NSMakePoint(xpos - (size.width/2), ypos)
							  withAttributes: itemTextAttributes];
			
			// Draw links to the children
			[[NSColor blackColor] set];
			NSEnumerator* childEnumerator = [[item objectForKey: ZSchildren] objectEnumerator];
			
			float startYPos = ypos + 10.0 + size.height;
			float endYPos = ypos - 10.0 + itemHeight;
			
			NSColor* tempChildLink = [NSColor blueColor];
			NSColor* permChildLink = [NSColor blackColor];
			
			NSDictionary* child;
			while (child = [childEnumerator nextObject]) {
				float childXPos = [[child objectForKey: ZSposition] floatValue] + globalOffset;
				
				if ([[child objectForKey: ZSitem] temporary]) {
					[tempChildLink set];
				} else {
					[permChildLink set];
				}
				
				[NSBezierPath strokeLineFromPoint: NSMakePoint(xpos, startYPos)
										  toPoint: NSMakePoint(childXPos, endYPos)];
			}
			
			// Draw the control icons (if this is the item that the mouse is over)
			if (item == trackedItem) {
				// Layout is:
				//    A T        x +
				//    ( ** ITEM ** )
				//                 L
				// 
				// Where A = Annotate, T = transcript, x = delete, + = add, L = lock
				float w = bgWidth;
				if (w < 32.0) w = 32.0;
				w += 40.0;
				float left = xpos - w/2.0;
				float right = xpos + w/2.0;
				
				ZoomSkeinItem* itemParent = [[item objectForKey: ZSitem] parent];

				// Correct for shadow
				right -= 20.0;
				left  += 2.0;
				
				// Draw the buttons
				NSRect imgRect;
				imgRect.origin = NSMakePoint(0,0);
				imgRect.size   = [add size];
				
				[[self class] drawButton: annotate
								 atPoint: NSMakePoint(left, ypos - 18)
							 highlighted: activeButton == ZSVannotateButton];
				[[self class] drawButton: transcript
								 atPoint: NSMakePoint(left + 14, ypos - 18)
							 highlighted: activeButton==ZSVtranscriptButton];
				
				[[self class] drawButton: add
								 atPoint: NSMakePoint(right, ypos - 18)
							 highlighted: activeButton==ZSVaddButton];
				if (itemParent != nil) {
					// Can only delete items other than the parent 'start' item
					[[self class] drawButton: delete
									 atPoint: NSMakePoint(right - 14, ypos - 18)
								 highlighted: activeButton==ZSVdeleteButton];
				}
				
				if (itemParent != nil) {
					// Can't unlock the 'start' item
					NSImage* lock = [[item objectForKey: ZSitem] temporary]?unlocked:locked;
					
					[[self class] drawButton: lock
									 atPoint: NSMakePoint(right, ypos + 18)
								 highlighted: activeButton==ZSVlockButton];
				}
			}
		}
	}
}

- (BOOL) isFlipped {
	return YES;
}

// = Setting/getting the source =

- (ZoomSkein*) skein {
	return skein;
}

- (void) setSkein: (ZoomSkein*) sk {
	if (skein) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: ZoomSkeinChangedNotification
													  object: skein];
		[skein release];
	}
	
	skein = [sk retain];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(skeinDidChange:)
												 name: ZoomSkeinChangedNotification
											   object: skein];
	[self skeinNeedsLayout];
}

// = Laying things out =

- (void) skeinDidChange: (NSNotification*) not {
	[self finishEditing: self];
	[self skeinNeedsLayout];
	
	[self scrollToItem: [skein activeItem]];
}

- (void) skeinNeedsLayout {
	if (!skeinNeedsLayout) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(layoutSkein)
											 target: self
										   argument: nil
											  order: 8
											  modes: [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
		skeinNeedsLayout = YES;
	}
}

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
	NSMutableDictionary* result = [ZoomSkeinView item: item
											withWidth: ourWidth
											fullWidth: position
												level: level];
	
	[result setObject: children
			   forKey: ZSchildren];
	
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
	// Only actually layout if we're marked as needing it
	if (!skeinNeedsLayout) return;

	skeinNeedsLayout = NO;
	
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
	
	tree = [[self layoutSkeinItem: [skein rootItem]
						withLevel: 0] retain];
	
	if (tree != nil) {
		// Transform the 'relative' positions of all items into 'absolute' positions
		globalOffset = 0; globalWidth = 0;
		[self fixPositions: tree
				withOffset: 0];
	
		// Resize this view
		NSRect newBounds = [self bounds];
	
		newBounds.size.width = [[tree objectForKey: ZSfullwidth] floatValue];
		//newBounds.size.width = globalWidth + globalOffset + itemWidth/2.0;
		newBounds.size.height = ((float)[levels count]) * itemHeight;
	
		[self setFrame: newBounds];
	}
	
	// View needs redisplaying
	[self setNeedsDisplay: YES];
	
	// ... and redo the tracking rectangles
	[self updateTrackingRects];
}

// = Affecting the display =

- (void) scrollToItem: (ZoomSkeinItem*) item {
	if (item == nil) return;
	
	if (skeinNeedsLayout) [self layoutSkein];
	
#if 0
	// Find the item (slow method, but it'll work)
	int x;
	
	NSDictionary* foundItem = nil;

	for (x=0; x<[levels count]; x++) {
		NSEnumerator* itemEnum = [[levels objectAtIndex: x] objectEnumerator];
		NSDictionary* testItem;
		
		while (testItem = [itemEnum nextObject]) {
			if ([testItem objectForKey: ZSitem] == item)
				foundItem = testItem;
		}
	}
#else
	NSDictionary* foundItem = [self itemForItem: item];
#endif
	
	if (foundItem) {
		float xpos, ypos;
		
		xpos = [[foundItem objectForKey: ZSposition] floatValue] + globalOffset;
		ypos = [[foundItem objectForKey: ZSlevel] intValue]*itemHeight + (itemHeight / 2);
		
		NSRect visRect = [self visibleRect];
		
		xpos -= visRect.size.width / 2.0;
		ypos -= visRect.size.height / 3.0;
		
		[self scrollPoint: NSMakePoint(xpos, ypos)];
	} else {
		NSLog(@"ZoomSkeinView: Attempt to scroll to nonexistant item");
	}
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
	if (levelOffset < -8) return nil;
	if (levelOffset >= 22) return nil;
	
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

// = Skein mouse sensitivity =

- (void) removeAllTrackingRects {
	NSEnumerator* trackingEnum = [trackingRects objectEnumerator];
	NSNumber* val;
	
	while (val = [trackingEnum nextObject]) {
		[self removeTrackingRect: [val intValue]];
	}
	
	trackingRects = [[NSMutableArray alloc] init];
}

- (void) updateTrackingRects {
	if (dragScrolling) return;

	[self removeAllTrackingRects];
	
	NSPoint currentMousePos = [[self window] mouseLocationOutsideOfEventStream];
	currentMousePos = [self convertPoint: currentMousePos
								fromView: nil];
	
	// Only put in the visible items
	NSRect visibleRect = [self visibleRect];
	
	if (overItem)   [self mouseLeftItem: trackedItem];
	if (overWindow) [self mouseLeftView];
	overWindow = NO;
	overItem = NO;
	trackedItem = nil;

	int startLevel = floorf(NSMinY(visibleRect) / itemHeight)-1;
	int endLevel = ceilf(NSMaxY(visibleRect) / itemHeight);
	
	NSTrackingRectTag tag;
	BOOL inside = NO;

	int level;
	
	if (startLevel < 0) startLevel = 0;
	if (endLevel >= [levels count]) endLevel = [levels count]-1;
	
	// assumeInside: NO doesn't work if the pointer is already inside (acts exactly the same as assumeInside: YES 
	// in this case). Therefore we need to check manually, which is very annoying.
	inside = NO;
	if (NSPointInRect(currentMousePos, visibleRect)) {
		[self mouseEnteredView];
		inside = YES;
	}
	tag = [self addTrackingRect: visibleRect
						  owner: self
					   userData: nil
				   assumeInside: inside];
		
	[trackingRects addObject: [NSNumber numberWithInt: tag]];
	
	for (level = startLevel; level<=endLevel; level++) {
		NSEnumerator* itemEnum = [[levels objectAtIndex: level] objectEnumerator];
		NSDictionary* item;
		
		while (item = [itemEnum nextObject]) {
			NSRect itemRect = [self activeAreaForItem: item];
			
			// Same reasoning as before
			inside = NO;
			if (NSPointInRect(currentMousePos, itemRect)) {
				[self mouseEnteredItem: item];
				inside = YES;
			}
			tag = [self addTrackingRect: itemRect
								  owner: self
							   userData: item
						   assumeInside: inside];
			[trackingRects addObject: [NSNumber numberWithInt: tag]];
		}
	}
}

- (void) mouseEnteredView {
	if (!overItem && !overWindow) {
		[[NSCursor openHandCursor] push];
	}
	
	overWindow = YES;
}

- (void) mouseLeftView {
	if (overItem) { [NSCursor pop]; overItem = NO; }
	if (overWindow) [NSCursor pop];
	overWindow = NO;
	trackedItem = nil;
}

- (void) mouseEnteredItem: (NSDictionary*) item {
	if (!overWindow) {
		// Make sure the cursor stack is set up correctly
		[[NSCursor openHandCursor] push];
		overWindow = YES;
	}
	
	if (!overItem) {
		[[NSCursor pointingHandCursor] push];
	}
	
	trackedItem = item;
	overItem = YES;
	
	if (trackedItem) {
		[self setNeedsDisplay: YES];
	}
}

- (void) mouseLeftItem: (NSDictionary*) item {
	if (overItem) [NSCursor pop];
	if (trackedItem) [self setNeedsDisplay: YES];
	overItem = NO;
	trackedItem = nil;
}

- (void) mouseEntered: (NSEvent*) event {
	// Entered a tracking rectangle: switch to the arrow tracking cursor
	if ([event userData] == nil) {
		// Entered the main view tracking rectangle
		[self mouseEnteredView];
	} else {
		// Entered a tracking rectangle for a specific item
		[self mouseEnteredItem: [event userData]];
	}
}

- (void) mouseExited: (NSEvent*) event {
	// Exited a tracking rectangle: switch to the open hand cursor
	if ([event userData] == nil) {
		// Leaving the view entirely
		[self mouseLeftView];
	} else {
		// Left a item tracking rectangle
		[self mouseLeftItem: [event userData]];
	}
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
	return YES;
}

// = Mouse handling =

- (void) mouseDown: (NSEvent*) event {
	[self finishEditing: self];
	
	if (trackedItem == nil) {
		// We're dragging to move the view around
		[[NSCursor closedHandCursor] push];
		
		dragScrolling = YES;
		dragOrigin = [event locationInWindow];
		dragInitialVisible = [self visibleRect];
	} else {
		// We're inside an item - check to see which (if any) button was clicked
		activeButton = lastButton = [self buttonUnderPoint: [self convertPoint: [event locationInWindow] 
																	  fromView: nil]
													inItem: trackedItem];
		[self setNeedsDisplay: YES];
	}
}

- (void) mouseDragged: (NSEvent*) event {
	if (dragScrolling) {
		// Scroll to the new position
		NSPoint currentPos = [event locationInWindow];
		NSRect newVisRect = dragInitialVisible;
		
		newVisRect.origin.x += dragOrigin.x - currentPos.x;
		newVisRect.origin.y -= dragOrigin.y - currentPos.y;
		
		[self scrollRectToVisible: newVisRect];
	} else if (trackedItem != nil && lastButton != ZSVnoButton) {
		// If the cursor moves away from a button, then unhighlight it
		int lastActiveButton = activeButton;
		
		activeButton = [self buttonUnderPoint: [self convertPoint: [event locationInWindow] 
														 fromView: nil]
									   inItem: trackedItem];
		if (activeButton != lastButton) activeButton = ZSVnoButton;
		
		if (activeButton != lastActiveButton) [self setNeedsDisplay: YES];
	}
}

- (void) mouseUp: (NSEvent*) event {
	if (dragScrolling) {
		dragScrolling = NO;
		[NSCursor pop];
		
		[[NSRunLoop currentRunLoop] performSelector: @selector(updateTrackingRects)
											 target: self
										   argument: nil
											  order: 64
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	} else if (trackedItem != nil) {
		// Finish a click on any item button
		if (activeButton != ZSVnoButton) {
			switch (activeButton) {
				case ZSVaddButton:
					[self addButtonClicked: event
								  withItem: trackedItem];
					break;
					
				case ZSVdeleteButton:
					[self deleteButtonClicked: event
									 withItem: trackedItem];
					break;

				case ZSVannotateButton:
					[self annotateButtonClicked: event
									   withItem: trackedItem];
					break;
					
				case ZSVtranscriptButton:
					[self transcriptButtonClicked: event
										 withItem: trackedItem];
					break;

				case ZSVlockButton:
					[self lockButtonClicked: event
								   withItem: trackedItem];
					break;
					
				case ZSVmainItem:
					[self editItem: [trackedItem objectForKey: ZSitem]];
					break;
			}
			
			activeButton = ZSVnoButton;
			[self setNeedsDisplay: YES];
		}
	}

	// Reset this anyway
	activeButton = ZSVnoButton;	
	lastButton = ZSVnoButton;
}

- (enum ZSVbutton) buttonUnderPoint: (NSPoint) point
							 inItem: (NSDictionary*) item {
	// Calculate info about the location of this item
	float xpos = [[item objectForKey: ZSposition] floatValue] + globalOffset;
	float ypos = ((float)[[item objectForKey: ZSlevel] intValue]) * itemHeight + (itemHeight/2.0);

	NSDictionary* fontAttrs = itemTextAttributes;
	
	NSSize size = [[[item objectForKey: ZSitem] command] sizeWithAttributes: fontAttrs];

	float w = size.width; //[[item objectForKey: ZSwidth] floatValue];
	if (w < 32.0) w = 32.0;
	w += 40.0;
	float left = -w/2.0;
	float right = w/2.0;
	
	// Correct for shadow
	right -= 20.0;
	left  += 2.0;				

	// Actual position
	NSPoint offset = NSMakePoint(point.x - xpos, point.y - ypos);
	
	// See where was clicked
	if (offset.y > -18.0 && offset.y < -6.0) {
		// Upper row of buttons
		if (offset.x > left+2.0 && offset.x < left+14.0) return ZSVannotateButton;
		if (offset.x > left+16.0 && offset.x < left+28.0) return ZSVtranscriptButton;
		if (offset.x > right+2.0 && offset.x < right+14.0) return ZSVaddButton;
		if (offset.x > right-12.0 && offset.x < right-0.0) return ZSVdeleteButton;
	} else if (offset.y > 18.0 && offset.y < 30.0) {
		// Lower row of buttons
		if (offset.x > right+2.0 && offset.x < right+14.0) return ZSVlockButton;
	} else if (offset.y > -2.0 && offset.y < 14.0) {
		// Main item
		return ZSVmainItem;
	} else {
		// Nothing
	}
	
	return ZSVnoButton;
}

// = Item control buttons =

- (void) addButtonClicked: (NSEvent*) event
				 withItem: (NSDictionary*) item {
	ZoomSkeinItem* skeinItem = [item objectForKey: ZSitem];
	
	// Add a new, blank item
	ZoomSkeinItem* newItem = 
		[skeinItem addChild: [ZoomSkeinItem skeinItemWithCommand: @""]];
	
	[self skeinNeedsLayout];
	
	// Edit the item
	[self scrollToItem: newItem];
	[self editItem: newItem];
}

- (void) deleteButtonClicked: (NSEvent*) event
					withItem: (NSDictionary*) item {
	ZoomSkeinItem* skeinItem = [item objectForKey: ZSitem];
	
	if ([skeinItem parent] == nil) return;
	
	ZoomSkeinItem* parent = [skein activeItem];
	while (parent != nil) {
		if (parent == skeinItem) {
			// Can't delete an item that's the parent of the active item
			NSBeep(); // Maybe need some better feedback
			return;
		}
		
		parent = [parent parent];
	}
	
	// Delete the item
	[skeinItem removeFromParent];
	[self skeinNeedsLayout];
}

- (void) lockButtonClicked: (NSEvent*) event
				  withItem: (NSDictionary*) item {
	ZoomSkeinItem* skeinItem = [item objectForKey: ZSitem];

	if ([skeinItem parent] == nil) return;

	if ([skeinItem temporary]) {
		// Lock this item and its parents
		ZoomSkeinItem* parent = skeinItem;
		while (parent != nil) {
			[parent setTemporary: NO];
			parent = [parent parent];
		}
	} else {
		// Unlock this item and its children
		
		// itemsToProcess is a stack of items
		NSMutableArray* itemsToProcess = [NSMutableArray array];
		[itemsToProcess addObject: skeinItem];
		
		while ([itemsToProcess count] > 0) {
			ZoomSkeinItem* thisItem = [itemsToProcess lastObject];
			[itemsToProcess removeLastObject];
	
			[thisItem setTemporary: YES];
	
			NSEnumerator* childEnum = [[thisItem children] objectEnumerator];
			ZoomSkeinItem* child;
			while (child = [childEnum nextObject]) {
				[itemsToProcess addObject: child];
			}
		}
	}
	
	[self skeinNeedsLayout];
}

- (void) annotateButtonClicked: (NSEvent*) event
					  withItem: (NSDictionary*) item {
	//ZoomSkeinItem* skeinItem = [item objectForKey: ZSitem];
}

- (void) transcriptButtonClicked: (NSEvent*) event
						withItem: (NSDictionary*) item {
	//ZoomSkeinItem* skeinItem = [item objectForKey: ZSitem];
}

// = Editing items =

- (void) finishEditing: (id) sender {
	if (itemToEdit != nil && itemEditor != nil) {
		ZoomSkeinItem* parent = [itemToEdit parent];
		
		// This will merge trees if the item gets the same name as a neighbouring item
		[itemToEdit removeFromParent];
		[itemToEdit setCommand: [itemEditor stringValue]];
		ZoomSkeinItem* newItem = [parent addChild: itemToEdit];
		
		// Change the active item if required
		if (itemToEdit == [skein activeItem]) {
			[skein setActiveItem: newItem];
		}
		
		// NOTE: if 'addChild' can ever release the active item, we may have a problem here.
		// Currently, this can't happen

		[self skeinNeedsLayout];

		if (sender == itemEditor) [self scrollToItem: itemToEdit];
	}
	
	[self cancelEditing: self];
}

- (void) cancelEditing: (id) sender {
	if (itemToEdit != nil) {
		[itemToEdit release];
		itemToEdit = nil;
	}

	if (itemEditor != nil) {
		[itemEditor removeFromSuperview];
		[itemEditor release];
		itemEditor = nil;
	}
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
	[self finishEditing: self];
}

- (void) editItem: (ZoomSkeinItem*) skeinItem {
	// Cancel any existing editing
	// FIXME: store it? Probably a good idea
	[self finishEditing: self];
	
	// Allows you to edit an item's command
	NSDictionary* item = [self itemForItem: skeinItem];
	
	if (item == nil) {
		NSLog(@"ZoomSkeinView: Item not found for editing");
		return;
	}
	
	// Area of the text for this item
	NSRect itemFrame = [self textAreaForItem: item];
	
	// Make sure the item is the right size
	float minItemWidth = itemWidth - 32.0;
	if (itemFrame.size.width < minItemWidth) {
		itemFrame.origin.x  -= (minItemWidth - itemFrame.size.width)/2.0;
		itemFrame.size.width = minItemWidth;
	}
	
	// 'overflow' border
	itemFrame = NSInsetRect(itemFrame, -4.0, -4.0);	
	
	itemToEdit = [skeinItem retain];
	
	itemEditor = [[NSTextField alloc] initWithFrame: itemFrame];
	
	[itemEditor setAllowsEditingTextAttributes: NO];
	[itemEditor setFont: [NSFont systemFontOfSize: 10]];
	
	[itemEditor setAttributedStringValue: 
		[[[NSAttributedString alloc] initWithString: [skeinItem command]
										 attributes: itemTextAttributes] autorelease]];
		
	[itemEditor setAlignment: NSCenterTextAlignment];
	[itemEditor setAction: @selector(finishEditing:)];
	[itemEditor setTarget: self];
	[itemEditor setDelegate: self];

	[self addSubview: itemEditor];
	
	[[self window] makeFirstResponder: itemEditor];
	[[self window] makeKeyWindow];
}

@end
