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
    }
    return self;
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

@end
