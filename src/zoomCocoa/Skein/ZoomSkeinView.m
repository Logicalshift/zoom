//
//  ZoomSkeinView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinView.h"

// Constants
static const float itemWidth = 196.0; // Pixels
static const float itemHeight = 64.0;

// Entries in the item dictionary
static NSString* ZSitem = @"ZSitem";
static NSString* ZSwidth = @"ZSwidth";
static NSString* ZSfullwidth = @"ZSfullwidth";
static NSString* ZSposition = @"ZSposition";
static NSString* ZSchildren = @"ZSchildren";
static NSString* ZSlevel    = @"ZSlevel";

@implementation ZoomSkeinView

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
	[self layoutSkein]; // Fixme - need to update as appropriate
	
	int startLevel = floorf(NSMinY(rect) / itemHeight);
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
			float xpos = [[item objectForKey: ZSposition] floatValue];
			float width = [[skeinItem command] sizeWithAttributes: fontAttrs].width;
			
			// Draw the background (IMPLEMENT ME)
			
			// Draw the item
			[[skeinItem command] drawAtPoint: NSMakePoint(xpos - (width/2), ypos)
							  withAttributes: fontAttrs];
			
			// Draw links to the children (IMPLEMENT ME)
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
	[skein release];
	skein = [sk retain];
	
	[self skeinNeedsLayout];
}

// = Laying things out =

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
	NSEnumerator* childEnum = [[item children] objectEnumerator];
	ZoomSkeinItem* child;
	float position = 0.0;
	NSMutableDictionary* childItem;
	
	NSMutableArray* children = [NSMutableArray array];
	
	while (child == [childEnum nextObject]) {
		// Layout the child item
		childItem = [self layoutSkeinItem: child
								withLevel: level+1];
		
		// Position it (first iteration: we center later)
		[childItem setObject: [NSNumber numberWithFloat: position]
					  forKey: ZSposition];
		
		position += [[childItem objectForKey: ZSfullwidth] floatValue];
		
		// Add to the list of children for this item
		[children addObject: childItem];
	}
	
	// Should only happen if there are no children
	if (position < itemWidth) position = itemWidth;
	
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
	
	return result;
}

- (void) fixPositions: (NSMutableDictionary*) item
		   withOffset: (float) offset {
	// After running through layoutSkeinItem, all positions are relative to the 'parent' item
	// This routine fixes this
	
	// Move this item by the offset (fixing it with an absolute position)
	float newPos = [[item objectForKey: ZSposition] floatValue] + offset;
	[item setObject: [NSNumber numberWithFloat: newPos]
			 forKey: ZSposition];
	
	// Fix the children to have absolute positions
	NSEnumerator* childEnum = [[item objectForKey: ZSchildren] objectEnumerator];
	NSMutableDictionary* child;
	
	while (child = [childEnum nextObject]) {
		[self fixPositions: child
				withOffset: newPos];
	}
	
	// Add to the 'levels' array, which contains which items to draw at which levels
	int level = [[item objectForKey: ZSlevel] intValue];
	
	while (level >= [levels count]) {
		[levels addObject: [NSMutableArray array]];
	}
	
	[[levels objectAtIndex: level] addObject: item];
}

- (void) layoutSkein {
	skeinNeedsLayout = NO;
	
	// Perform initial layout of the items
	if (tree) {
		[tree release];
		tree = nil;
	}
	tree = [[self layoutSkeinItem: [skein rootItem]
						withLevel: 0] retain];
	
	if (levels) {
		[levels release];
		levels = nil;
	}
	levels = [[NSMutableArray alloc] init];
	
	// Transform the 'relative' positions of all items into 'absolute' positions
	float offset = [[tree objectForKey: ZSfullwidth] floatValue] / 2.0;
	[self fixPositions: tree
			withOffset: offset];
	
	// Resize this view
	NSRect newBounds = [self bounds];
	
	newBounds.size.width = [[tree objectForKey: ZSfullwidth] floatValue];
	newBounds.size.height = ((float)[levels count]) * itemHeight;
	
	[self setBounds: newBounds];
	
	// View needs redisplaying
	[self setNeedsDisplay: YES];
}

@end
