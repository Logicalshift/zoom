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
static const float itemHeight = 64.0;

// Entries in the item dictionary
static NSString* ZSitem = @"ZSitem";
static NSString* ZSwidth = @"ZSwidth";
static NSString* ZSfullwidth = @"ZSfullwidth";
static NSString* ZSposition = @"ZSposition";
static NSString* ZSchildren = @"ZSchildren";
static NSString* ZSlevel    = @"ZSlevel";

// Images
static NSImage* unplayed, *selected, *active, *unchanged, *changed;

@implementation ZoomSkeinView

+ (NSImage*) imageNamed: (NSString*) name {
	NSImage* img = [NSImage imageNamed: name];
	
	[img setFlipped: YES];
	return img;
}

+ (void) initialize {
	unplayed  = [[[self class] imageNamed: @"Skein-unplayed"] retain];
	selected  = [[[self class] imageNamed: @"Skein-selected"] retain];
	active    = [[[self class] imageNamed: @"Skein-active"] retain];
	unchanged = [[[self class] imageNamed: @"Skein-unchanged"] retain];
	changed   = [[[self class] imageNamed: @"Skein-changed"] retain];
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
    }
	
    return self;
}

- (void) dealloc {
	[skein release];
	
	if (tree) [tree release];
	if (levels) [levels release];
	
	[super dealloc];
}

// = Drawing =

- (void)drawRect:(NSRect)rect {
	if (tree == nil) return;
	
	// Fill in the background
	[[NSColor whiteColor] set];
	NSRectFill(rect);
	
	// Actually draw the skein
	int startLevel = floorf(NSMinY(rect) / itemHeight)-1;
	int endLevel = ceilf(NSMaxY(rect) / itemHeight);
	int level;
	
	NSDictionary* fontAttrs = [NSDictionary dictionaryWithObjectsAndKeys: 
		[NSColor blackColor], NSForegroundColorAttributeName,
		[NSFont systemFontOfSize: 10], NSFontAttributeName,
		nil];
	
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
			NSSize size = [[skeinItem command] sizeWithAttributes: fontAttrs];
			
			// Draw the background (IMPLEMENT ME)
			NSImage* background = unchanged;
			
			if (![skeinItem played]) background = unplayed;
			if ([skeinItem changed]) background = changed;
			if (skeinItem == [skein activeItem]) background = active;
			if ([skeinItem parent] == [skein activeItem]) background = changed;
			
			[background drawAtPoint: NSMakePoint(xpos - 45, ypos - 8)
						   fromRect: NSMakeRect(0,0,90,30)
						  operation: NSCompositeSourceOver
						   fraction: 1.0];

			// Draw the item
			[[skeinItem command] drawAtPoint: NSMakePoint(xpos - (size.width/2), ypos)
							  withAttributes: fontAttrs];
			
			// Draw links to the children
			[[NSColor blackColor] set];
			NSEnumerator* childEnumerator = [[item objectForKey: ZSchildren] objectEnumerator];
			
			float startYPos = ypos + 10.0 + size.height;
			float endYPos = ypos - 10.0 + itemHeight;
			
			NSDictionary* child;
			while (child = [childEnumerator nextObject]) {
				float childXPos = [[child objectForKey: ZSposition] floatValue] + globalOffset;
				
				[NSBezierPath strokeLineFromPoint: NSMakePoint(xpos, startYPos)
										  toPoint: NSMakePoint(childXPos, endYPos)];
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
	[self skeinNeedsLayout];
	
	[self scrollToItem: [skein activeItem]];
}

- (void) skeinNeedsLayout {
	if (!skeinNeedsLayout) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(layoutSkein)
											 target: self
										   argument: nil
											  order: 32
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
	
	// Return the result
	NSMutableDictionary* result = [ZoomSkeinView item: item
											withWidth: itemWidth
											fullWidth: position
												level: level];
	
	[result setObject: children
			   forKey: ZSchildren];
		
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
	
	if ((-newPos) > globalOffset)
		globalOffset = -newPos;
	if (newPos > globalWidth)
		globalWidth = newPos;
}

- (void) layoutSkein {
	if (!skeinNeedsLayout) return;
	skeinNeedsLayout = NO;
	
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
	
	if (tree == nil) return;
	
	// Transform the 'relative' positions of all items into 'absolute' positions
	globalOffset = 0; globalWidth = 0;
	[self fixPositions: tree
			withOffset: 0];
	globalOffset += itemWidth/2.0;
	
	// Resize this view
	NSRect newBounds = [self bounds];
	
	newBounds.size.width = [[tree objectForKey: ZSfullwidth] floatValue];
	//newBounds.size.width = globalWidth + globalOffset + itemWidth/2.0;
	newBounds.size.height = ((float)[levels count]) * itemHeight;
	
	[self setFrame: newBounds];
	
	// View needs redisplaying
	[self setNeedsDisplay: YES];
}

// = Affecting the display =

- (void) scrollToItem: (ZoomSkeinItem*) item {
	if (item == nil) return;
	
	if (skeinNeedsLayout) [self layoutSkein];
	
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
	
	if (foundItem) {
		float xpos, ypos;
		
		xpos = [[foundItem objectForKey: ZSposition] floatValue] + globalOffset;
		ypos = [[foundItem objectForKey: ZSlevel] intValue]*itemHeight + (itemHeight / 2);
		
		NSRect visRect = [self visibleRect];
		
		xpos -= visRect.size.width / 2.0;
		ypos -= visRect.size.height / 2.0;
		
		[self scrollPoint: NSMakePoint(xpos, ypos)];
	} else {
		NSLog(@"ZoomSkeinView: Attempt to scroll to nonexistant item");
	}
}

@end
