//
//  ZoomCollapsableView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Feb 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomCollapsableView.h"


@implementation ZoomCollapsableView

#define BORDER 4.0
#define FONTSIZE 20

// = Init/housekeeping =

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		views = [[NSMutableArray alloc] init];
		titles = [[NSMutableArray alloc] init];
		states = [[NSMutableArray alloc] init];
		
		rearranging = NO;
		
		[self setPostsFrameChangedNotifications: YES];
    	[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(subviewFrameChanged:)
													 name: NSViewFrameDidChangeNotification
												   object: self];
	}
    return self;
}

- (void) dealloc {
	[views release];
	[titles release];
	[states release];
	
	[super dealloc];
}

// = Drawing =
- (BOOL) isOpaque {
	return YES;
}

- (void)drawRect:(NSRect)rect {
	NSFont* titleFont = [NSFont boldSystemFontOfSize: FONTSIZE];
	NSColor* backgroundColour = [NSColor whiteColor];
	NSDictionary* titleAttributes = 
		[NSDictionary dictionaryWithObjectsAndKeys: 
			titleFont, NSFontAttributeName,
			[NSColor blackColor], NSForegroundColorAttributeName,
			backgroundColour, NSBackgroundColorAttributeName,
			nil];
	
	[backgroundColour setFill];
	NSRectFill(rect);
	
	NSRect bounds = [self bounds];
	
	// Draw the titles and frames
	NSColor* frameColour = [NSColor colorWithDeviceRed: 0.5
												 green: 0.5
												  blue: 0.5
												 alpha: 1.0];

	int x;
	
	for (x=0; x<[views count]; x++) {
		NSView* thisView = [views objectAtIndex: x];
		NSString* thisTitle = [titles objectAtIndex: x];
		//BOOL visible = [[states objectAtIndex: x] boolValue];
		
		NSSize titleSize = [thisTitle sizeWithAttributes: titleAttributes];
		NSRect thisFrame = [thisView frame];
		
		float ypos = thisFrame.origin.y - (titleSize.height*1.2);
		
		// Draw the border rect
		NSRect borderRect = NSMakeRect(floor(BORDER)+0.5, floor(ypos)+0.5, 
									   bounds.size.width-(BORDER*2), thisFrame.size.height + (titleSize.height * 1.2) + (BORDER));
		[frameColour setStroke];
		[NSBezierPath strokeRect: borderRect];
		
		// IMPLEMENT ME: draw the show/hide triangle (or maybe add this as a view?)
		
		// Draw the title
		[thisTitle drawAtPoint: NSMakePoint(BORDER*2, ypos + 2 + titleSize.height * 0.1)
				withAttributes: titleAttributes];
	}
	
	
	// Draw the rest
	[super drawRect: rect];
}

// = Management =

- (void) addSubview: (NSView*) subview
		  withTitle: (NSString*) title {
	[views addObject: subview];
	[titles addObject: title];
	[states addObject: [NSNumber numberWithBool: YES]];

	NSRect bounds = [self bounds];
	
	// Set the width appropriately
	NSRect viewFrame = [subview frame];
	
	viewFrame.size.width = bounds.size.width - (BORDER*4);
	[subview setAutoresizingMask: NSViewWidthSizable];
	[subview setFrame: viewFrame];
	[subview setNeedsDisplay: YES];
	
	// Rearrange the views
	[self rearrangeSubviews];
	
	// Receive notifications about this view
	[subview setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(subviewFrameChanged:)
												 name: NSViewFrameDidChangeNotification
											   object: subview];
}

- (void) rearrangeSubviews {
	reiterate = YES;
	if (rearranging) return;
	rearranging = YES;
	reiterate = NO;
	
	BOOL needsRedrawing = NO;
	
	NSRect oldBounds;
	NSRect newBounds = [self bounds];;
	
	NSEnumerator* viewEnum;
	NSView* subview;
	
	float bestWidth;
	float newHeight;
	
	NSFont* titleFont = [NSFont boldSystemFontOfSize: FONTSIZE];
	float titleHeight = [titleFont ascender] - [titleFont descender];
	
	oldBounds = newBounds;
	
	// First stage: resize all subviews to be the correct width
	bestWidth = oldBounds.size.width - (BORDER*4);
	
	viewEnum = [views objectEnumerator];
	
	while (subview = [viewEnum nextObject]) {
		NSRect viewFrame = [subview frame];
		
		if (viewFrame.size.width != bestWidth) {
			needsRedrawing = YES;
			viewFrame.size.width = bestWidth;
			[subview setFrameSize: viewFrame.size];
			[subview setNeedsDisplay: YES];
		}
	}
	
	// Second stage: calculate our new height (and resize appropriately)
	newHeight = BORDER;
	
	viewEnum = [views objectEnumerator];
	
	while (subview = [viewEnum nextObject]) {
		NSRect viewFrame = [subview frame];
		
		newHeight += titleHeight * 1.2;
		newHeight += viewFrame.size.height;
		newHeight += BORDER*2;
	}
	
	oldBounds.size.height = floor(newHeight);
	[self setFrameSize: oldBounds.size];
	
	// Loop until our width settles down
	newBounds = [self bounds];
	
	// Stage three: Position the views appropriately
	float ypos = BORDER;
	
	viewEnum = [views objectEnumerator];
	
	while (subview = [viewEnum nextObject]) {
		NSRect viewFrame = [subview frame];
		
		ypos += titleHeight * 1.2;
		
		if ([subview superview] != self) {
			if ([subview superview] != nil) [subview removeFromSuperview];
			[self addSubview: subview];
		}		
		
		if (viewFrame.origin.x != BORDER*2 ||
			viewFrame.origin.y != floor(ypos)) {
			viewFrame.origin.x = BORDER*2;
			viewFrame.origin.y = floor(ypos);
		
			[subview setFrameOrigin: viewFrame.origin];
			[subview setNeedsDisplay: YES];
			needsRedrawing = YES;
		}
		
		ypos += viewFrame.size.height;
		ypos += BORDER*2;
	}
	
	if (reiterate) {
		// Something has resized and messed up our beautiful arrangement!
		rearranging = NO;
		[self rearrangeSubviews];
		return;
	}
	
	// Final stage: tidy up, redraw if necessary
	//if (needsRedrawing) {
		[self setNeedsDisplay: YES];
	//}
	
	rearranging = NO;
}

#if 0
- (void) rearrangeSubviews {
	if (rearranging) return;
	rearranging = YES;
	
	NSRect ourBounds = [self bounds];
	
	BOOL needsDisplay = NO;

	NSFont* titleFont = [NSFont boldSystemFontOfSize: FONTSIZE];
	NSDictionary* titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys: titleFont, NSFontAttributeName, nil];
	
	float ypos = BORDER;
	int x;
	
	for (x=0; x<[views count]; x++) {
		NSView* thisView = [views objectAtIndex: x];
		NSString* thisTitle = [titles objectAtIndex: x];
		BOOL visible = [[states objectAtIndex: x] boolValue];
		
		NSSize titleSize = [thisTitle sizeWithAttributes: titleAttributes];
		
		// Space for the title and border
		ypos += titleSize.height*1.2;
		
		// Position the view
		NSRect viewFrame = [thisView frame];
		
		viewFrame.origin.x = BORDER*2;
		viewFrame.origin.y = floor(ypos);
		viewFrame.size.width = ourBounds.size.width - (BORDER*4);
		
		if (!NSEqualRects([thisView frame], viewFrame)) {
			[thisView setFrame: viewFrame];
			[thisView setNeedsDisplay: YES];
			needsDisplay = YES;
		}
		
		if (visible) {
			// View should be displayed
			if ([thisView superview] != self) {
				NSView* lastView = nil;
				
				if (x > 0) lastView = [views objectAtIndex: x-1];
				
				[self addSubview: thisView
					  positioned: NSWindowAbove
					  relativeTo: lastView];
			}
			
			ypos += viewFrame.size.height;
		} else {
			// View should *not* be displayed
			if ([thisView superview] != nil) {
				[thisView removeFromSuperview];
			}
		}
		
		ypos += BORDER*2;
	}
	
	// Set our own frame size
	rearranging = NO;	

	NSRect oldFrame = [self frame];
	if (ypos != oldFrame.size.height) {
		oldFrame.size.height = floor(ypos)+1;
		[self setFrame: oldFrame];
		needsDisplay = YES;
	}
	
	if (needsDisplay) { 
		[self setNeedsDisplay: YES];
		[self displayIfNeeded];
	}
}
#endif

- (BOOL) isFlipped {
	return YES;
}

- (void) subviewFrameChanged: (NSNotification*) not {
	reiterate = YES;
	if (rearranging) return;
	
	rearranging = YES;
	int x;
	NSRect bounds = [self bounds];
	
	for (x=0; x<[views count]; x++) {
		NSView* view = [views objectAtIndex: x];
		NSRect viewFrame = [view frame];
		
		if (viewFrame.size.width != bounds.size.width - (BORDER*4)) {
			viewFrame.size.width = bounds.size.width - (BORDER*4);
			[view setFrame: viewFrame];
			[view setNeedsDisplay: YES];
			[self setNeedsDisplay: YES];
		}
	}
	
	rearranging = NO;
	
	[self rearrangeSubviews];
}

- (void) startRearranging {
	rearranging = YES;
}

- (void) finishRearranging {
	rearranging = NO;
	
	[self rearrangeSubviews];
}

@end
