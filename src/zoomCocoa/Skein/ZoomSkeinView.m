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

// Drawing info
static NSDictionary* itemTextAttributes;

// Images
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

// Layout
- (void) layoutSkein;
- (void) updateTrackingRects;
- (void) removeAllTrackingRects;

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
- (void) playToPoint: (ZoomSkeinItem*) item;

- (void) cancelEditing: (id) sender;
- (void) finishEditing: (id) sender;

- (void) editSoon: (ZoomSkeinItem*) item;
- (void) iHateEditing;

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

+ (void) initialize {
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

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
	
    if (self) {
		skein = [[ZoomSkein alloc] init];
		activeButton = ZSVnoButton;
		
		layout = [[ZoomSkeinLayout alloc] init];
		[layout setRootItem: [skein rootItem]];
    }
	
    return self;
}

- (void) dealloc {
	[skein release];
	
	if (trackingRects) [trackingRects release];

	if (itemEditor) [itemEditor release];
	if (itemToEdit) [itemToEdit release];
	
	if (trackedItem)   [trackedItem release];
	if (clickedItem)   [clickedItem release];
	if (trackingItems) [trackingItems release];

	[layout release];

	[super dealloc];
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
	if (skeinNeedsLayout) [self layoutSkein];
	
	// (Sigh, will fail to keep track of these properly otherwise)
	NSRect visRect = [self visibleRect];
	if (!NSEqualRects(visRect, lastVisibleRect)) {
		// Need to only update this occasionally, or some redraws may cause an infinite loop
		[self updateTrackingRects];
	}
	lastVisibleRect = visRect;
	
	[layout setActiveItem: [skein activeItem]];
	[layout drawInRect: rect];
	
	// Draw the control icons for the tracked item
	if (trackedItem != nil) {
		float xpos = [layout xposForData: trackedItem];
		float ypos = ((float)[layout levelForData: trackedItem])*itemHeight + (itemHeight / 2.0);
		float bgWidth = [layout widthForData: trackedItem];
		
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
		
		ZoomSkeinItem* itemParent = [[layout itemForData: trackedItem] parent];
		
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
			NSImage* lock = [[layout itemForData: trackedItem] temporary]?unlocked:locked;
			
			[[self class] drawButton: lock
							 atPoint: NSMakePoint(right, ypos + 18)
						 highlighted: activeButton==ZSVlockButton];
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
	[layout setRootItem: [sk rootItem]];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(skeinDidChange:)
												 name: ZoomSkeinChangedNotification
											   object: skein];
	[self setSelectedItem: nil];
	[self skeinNeedsLayout];
	
	[self layoutSkein];
	[self updateTrackingRects];
	[self scrollToItem: [skein activeItem]];
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

- (void) layoutSkein {
	// Only actually layout if we're marked as needing it
	if (!skeinNeedsLayout) return;

	skeinNeedsLayout = NO;
	
	// Re-layout this skein
	[layout setRootItem: [skein rootItem]];
	[layout layoutSkein];
	
	// Resize this view
	NSRect newBounds = [self frame];
	
	newBounds.size = [layout size];
	/*
	newBounds.size.width = [[tree objectForKey: ZSfullwidth] floatValue];
	//newBounds.size.width = globalWidth + globalOffset + itemWidth/2.0;
	newBounds.size.height = ((float)[levels count]) * itemHeight;
	 */
	
	[self setFrameSize: newBounds.size];
	
	// View needs redisplaying
	[self setNeedsDisplay: YES];
	
	// ... and redo the tracking rectangles
	[self updateTrackingRects];
}

// = Affecting the display =

- (void) scrollToItem: (ZoomSkeinItem*) item {
	if (item == nil) return;
	
	if (skeinNeedsLayout) [self layoutSkein];
	
	NSDictionary* foundItem = [layout dataForItem: item];
	
	if (foundItem) {
		float xpos, ypos;
		
		xpos = [layout xposForItem: item];
		ypos = [layout levelForItem: item]*itemHeight + (itemHeight / 2);
		
		NSRect visRect = [self visibleRect];
		
		xpos -= visRect.size.width / 2.0;
		ypos -= visRect.size.height / 3.0;
		
		[self scrollPoint: NSMakePoint(xpos, ypos)];
	} else {
		NSLog(@"ZoomSkeinView: Attempt to scroll to nonexistant item");
	}
}

// = Skein mouse sensitivity =

- (void) removeAllTrackingRects {
	NSEnumerator* trackingEnum = [trackingRects objectEnumerator];
	NSNumber* val;
	
	while (val = [trackingEnum nextObject]) {
		[self removeTrackingRect: [val intValue]];
	}
	
	[trackingRects release];
	trackingRects = [[NSMutableArray alloc] init];
	
	[trackingItems release];
	trackingItems = [[NSMutableArray alloc] init];
}

- (void) updateTrackingRects {
	if (dragScrolling) return;
	if ([self superview] == nil || [self window] == nil) return;

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
	if (trackedItem) [trackedItem release];
	trackedItem = nil;

	int startLevel = floorf(NSMinY(visibleRect) / itemHeight)-1;
	int endLevel = ceilf(NSMaxY(visibleRect) / itemHeight);
	
	NSTrackingRectTag tag;
	BOOL inside = NO;

	int level;
	
	if (startLevel < 0) startLevel = 0;
	if (endLevel >= [layout levels]) endLevel = [layout levels]-1;
	
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
		NSEnumerator* itemEnum = [[layout dataForLevel: level] objectEnumerator];
		NSDictionary* item;
		
		while (item = [itemEnum nextObject]) {
			NSRect itemRect = [layout activeAreaForItem: item];
			
			// Same reasoning as before
			[trackingItems addObject: item];
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
	if (skeinNeedsLayout) {
		[self layoutSkein];
		[self updateTrackingRects];
		return;
	}
	
	if ([trackingItems indexOfObjectIdenticalTo: item] == NSNotFound) {
		NSLog(@"Item %p does not exist in SkeinView! (tracking error)", item);
		return;
	}
	
	if (!overWindow) {
		// Make sure the cursor stack is set up correctly
		[[NSCursor openHandCursor] push];
		overWindow = YES;
	}
	
	if (!overItem) {
		[[NSCursor pointingHandCursor] push];
	}
	
	if (trackedItem) {
		[trackedItem release];
	}
	trackedItem = [item retain];
	overItem = YES;
	
	if (trackedItem) {
		[self setNeedsDisplay: YES];
	}
}

- (void) mouseLeftItem: (NSDictionary*) item {
	if (overItem) [NSCursor pop];
	if (trackedItem) [self setNeedsDisplay: YES];
	overItem = NO;
	if (trackedItem) [trackedItem release];
	trackedItem = nil;
	
	[self iHateEditing];
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
	
	// Update the tracked item if it's not accurate
	NSPoint pointInView = [event locationInWindow];
	pointInView = [self convertPoint: pointInView fromView: nil];
	
	ZoomSkeinItem* realItem = [layout itemAtPoint: pointInView];
	NSDictionary* realItemD = [layout dataForItem: realItem];
	
	if (realItemD != trackedItem) {
		if (!overWindow) [self mouseEnteredView];
		
		if (trackedItem) [self mouseLeftItem: trackedItem];
		if (realItemD) [self mouseEnteredItem: realItemD];
	}
	
	if (clickedItem) [clickedItem release];
	clickedItem = [trackedItem retain];
	
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
	} else if (clickedItem != nil) {
		// Drag this item. Default action is a copy action, but a move op is possible if command is held
		// down.
		
		// Create an image of this item
		NSRect itemRect = [layout activeAreaForItem: clickedItem];
		NSImage* itemImage;
		
	}
}

- (void) mouseUp: (NSEvent*) event {
	[self iHateEditing];
	
	if (clickedItem) {
		[clickedItem release];
		clickedItem = nil;
	}
	
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
					if ([event modifierFlags]&NSAlternateKeyMask && [event clickCount] == 1) {
						// Clicking with the option key edits immediately
						ZoomSkeinItem* skeinItem = [layout itemForData: trackedItem];

						[self editItem: skeinItem];
					} else if ([event modifierFlags]&NSCommandKeyMask || [event clickCount] == 2) {
						// Run the game to this point (double- or command- click)
						ZoomSkeinItem* skeinItem = [layout itemForData: trackedItem];

						[self playToPoint: skeinItem];
					} else if ([event clickCount] == 1) {
						// Select this item - queue up for editing if required
						ZoomSkeinItem* skeinItem = [layout itemForData: trackedItem];
						
						if ([layout selectedItem] != skeinItem) {
							// Change the selected item
							[self setSelectedItem: skeinItem];
						} else {
							// Edit soon
							[self editSoon: skeinItem];
						}
					}
					//[self editItem: [trackedItem objectForKey: ZSitem]];
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
	float xpos = [layout xposForData: item];
	float ypos = ((float)[layout levelForData: item]) * itemHeight + (itemHeight/2.0);

	NSDictionary* fontAttrs = itemTextAttributes;
	
	NSSize size = [[[layout itemForData: item] command] sizeWithAttributes: fontAttrs];

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
	ZoomSkeinItem* skeinItem = [layout itemForData: item];
	
	// Add a new, blank item
	ZoomSkeinItem* newItem = 
		[skeinItem addChild: [ZoomSkeinItem skeinItemWithCommand: @""]];
	
	// Lock it
	[newItem setTemporary: NO];
	
	// Note the changes
	[skein zoomSkeinChanged];	
	[self skeinNeedsLayout];
	
	// Edit the item
	[self scrollToItem: newItem];
	[self editItem: newItem];
}

- (void) deleteButtonClicked: (NSEvent*) event
					withItem: (NSDictionary*) item {
	ZoomSkeinItem* skeinItem = [layout itemForData: item];
	ZoomSkeinItem* itemParent = [skeinItem parent];
	
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
	[skein zoomSkeinChanged];
	[self skeinNeedsLayout];
	
	if (itemParent) {
		[self scrollToItem: itemParent];
	}
}

- (void) lockButtonClicked: (NSEvent*) event
				  withItem: (NSDictionary*) item {
	ZoomSkeinItem* skeinItem = [layout itemForData: item];

	if ([skeinItem parent] == nil) return;

	if ([skeinItem temporary]) {
		[skeinItem setTemporary: NO];
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
	
	[skein zoomSkeinChanged];
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

		[self cancelEditing: self];
		[skein zoomSkeinChanged];
	} else {
		[self cancelEditing: self];
	}
}

- (void) cancelEditing: (id) sender {
	if (itemToEdit != nil && [[self window] firstResponder] == itemToEdit) {
		NSLog(@"Killing first responder");
		[[self window] makeFirstResponder: self];
	}
	
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
	// Finish any existing editing
	[self finishEditing: self];
	
	if ([skeinItem parent] == nil) {
		// Can't edit the root item
		NSBeep();
		return;
	}
	
	// Allows you to edit an item's command
	NSDictionary* item = [layout dataForItem: skeinItem];
	
	if (item == nil) {
		NSLog(@"ZoomSkeinView: Item not found for editing");
		return;
	}
		
	// Area of the text for this item
	NSRect itemFrame = [layout textAreaForItem: item];
	
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

- (void) editSoon: (ZoomSkeinItem*) item {
	[self performSelector: @selector(editItem:)
			   withObject: item
			   afterDelay: 0.7];
}

- (void) iHateEditing {
	[NSObject cancelPreviousPerformRequestsWithTarget: self];
}

// = Selecting items =

- (void) setSelectedItem: (ZoomSkeinItem*) item {
	if (item == [layout selectedItem]) return;
	
	[layout setSelectedItem: item];
	
	[self setNeedsDisplay: YES];
}

- (ZoomSkeinItem*) selectedItem {
	return [layout selectedItem];
}

// = Playing the game =

- (void) playToPoint: (ZoomSkeinItem*) item {
	if (![delegate respondsToSelector: @selector(restartGame)] ||
		![delegate respondsToSelector: @selector(playToPoint:fromPoint:)]) {
		// Can't play to this point: delegate does not support it
		return;
	}
	
	// Make sure it won't disappear...
	[item increaseTemporaryScore];
	
	// Deselect the curently selected item
	[self setSelectedItem: nil];
	
	// Work out if we can play from the active item or not
	ZoomSkeinItem* activeItem = [skein activeItem];
	ZoomSkeinItem* parent = [item parent];
	
	while (parent != nil) {
		if (parent == activeItem) break;
		parent = [parent parent];
	}
	
	if (parent == nil) {
		// We need to play from the start
		[delegate restartGame];
		[delegate playToPoint: item
					fromPoint: [skein rootItem]];
	} else {
		// Play from the active item
		[delegate playToPoint: item
					fromPoint: activeItem];
	}
}

// = Delegate =

- (void) setDelegate: (id) dg {
	delegate = dg;
}

- (id) delegate {
	return delegate;
}

// = Moving around =

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
	[self finishEditing: self];
	[self removeAllTrackingRects];
}

- (void) viewWillMoveToSuperview:(NSView *)newSuperview {
	[self finishEditing: self];
	[self removeAllTrackingRects];
}

- (void)viewDidMoveToWindow {
	[self skeinNeedsLayout];
}

- (void) viewDidMoveToSuperview {
	[self skeinNeedsLayout];
}

- (void) setFrame: (NSRect) frame {
	[self skeinNeedsLayout];
	[super setFrame: frame];
}

- (void) setBounds: (NSRect) bounds {
	[self skeinNeedsLayout];
	[super setBounds: bounds];
}

@end
