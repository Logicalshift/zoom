//
//  ZoomUpperWindowView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomUpperWindowView.h"
#import "ZoomUpperWindow.h"

@implementation ZoomUpperWindowView

- (id)initWithFrame:(NSRect)frame
           zoomView:(ZoomView*) view {
    self = [super initWithFrame:frame];
    if (self) {
        zoomView = view;
		flasher = nil;
		cursorFlashing = cursorShown = NO;
    }
    return self;
}

- (void) dealloc {
	if (flasher) {
		[flasher invalidate];
		[flasher release];
	}
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
    [[NSColor whiteColor] set];
    NSRectFill(rect);
    
    NSSize fixedSize = [@"M" sizeWithAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [zoomView fontWithStyle:ZFixedStyle], NSFontAttributeName, nil]];
    
    NSEnumerator* upperEnum;
    int ypos = 0;

    upperEnum = [[zoomView upperWindows] objectEnumerator];

    // Draw each window in turn
    ZoomUpperWindow* win;
    while (win = [upperEnum nextObject]) {
        int y;

        // Get the lines from the window
        NSArray* lines = [win lines];

        // Work out how many to draw
        int maxY = [win length];
        if (maxY > [lines count]) maxY = [lines count];

        // Fill in the background
        NSRect winRect = NSMakeRect(0,
                                    ypos*fixedSize.height,
                                    rect.size.width,
                                    (ypos+[win length])*fixedSize.height);
        [[win backgroundColour] set];
        NSRectFill(winRect);
        
        // Draw 'em
        for (y=0; y<maxY; y++) {
            NSMutableAttributedString* line = [lines objectAtIndex: y];

            [line drawAtPoint: NSMakePoint(0, fixedSize.height*(ypos+y))];
        }
        
        ypos += [win length];
    }
}

- (BOOL) isFlipped {
    return YES;
}

// = Flashing the cursor =
- (void) makeTimer {
	if (flasher) {
		[flasher invalidate];
		[flasher release];
		flasher = nil;
	}

	if (cursorFlashing) {
		flasher = [NSTimer timerWithTimeInterval: 0.7
										  target: self
										selector: @selector(flashCursor)
										userInfo: nil
										 repeats: YES];
		[[NSRunLoop currentRunLoop] addTimer: flasher
									 forMode: NSDefaultRunLoopMode];
		[flasher retain];
	}
}

- (void) updateCursor {
	ZoomUpperWindow* activeWindow = (ZoomUpperWindow*)[zoomView focusedView];
	
	if (![activeWindow isKindOfClass: [ZoomUpperWindow class]]) {
		// Can't update
		return;
	}
	
	// Font size
    NSSize fixedSize = [@"M" sizeWithAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [zoomView fontWithStyle:ZFixedStyle], NSFontAttributeName, nil]];
	
	// Get the cursor position
	NSPoint cursorPos = [activeWindow cursorPosition];
	int xp = cursorPos.x;
	int yp = cursorPos.y;
	
	[self lockFocus];
	
    NSEnumerator* upperEnum = [[zoomView upperWindows] objectEnumerator];
	
    ZoomUpperWindow* win;
	int startY = 0;
    while (win = [upperEnum nextObject]) {
		if (win == activeWindow) {			
			// Draw the line
			NSArray* lines = [win lines];
			
			NSRect winRect = NSMakeRect(0,
										fixedSize.height * (yp + startY),
										[self bounds].size.width,
										fixedSize.height);
			[[win backgroundColour] set];
			NSRectFill(winRect);			
			
			if (yp < [lines count] && yp < [win length]) {
				[[lines objectAtIndex: yp] drawAtPoint: NSMakePoint(0, fixedSize.height*(yp+startY))];
			}
			
			// Draw the cursor
			if (cursorShown) {
				[[NSColor selectedTextBackgroundColor] set];
			
				NSRect cursorRect = NSMakeRect(fixedSize.width * xp, fixedSize.height * (yp + startY), fixedSize.width, fixedSize.height);
				NSRectFill(cursorRect);
			}
		}
		
		startY += [win length];
	}
			
	[self unlockFocus];
	[[self window] flushWindow];
}

- (void) setFlashCursor: (BOOL) flash {
	cursorFlashing = flash;
	cursorShown = NO;
	
	[self updateCursor];
	[self makeTimer];
}

- (void) flashCursor {
	cursorShown = !cursorShown;
	[self updateCursor];
}

@end
