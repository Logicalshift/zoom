//
//  ZoomUpperWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomUpperWindow.h"


@implementation ZoomUpperWindow

- (id) initWithZoomView: (ZoomView*) view {
    self = [super init];
    if (self) {
        theView = [view retain];
    }
    return self;
}

- (void) dealloc {
    [theView release];
    [super dealloc];
}

// Clears the window
- (void) clear {
    NSLog(@"Upper window clear");
}

// Sets the input focus to this window
- (void) setFocus {
    NSLog(@"Upper window focus");
}

// Sending data to a window
- (void) writeString: (in bycopy NSAttributedString*) string {
}

// Size (-1 to indicate an unsplit window)
- (void) startAtLine: (int) line {
    startLine = line;
}

- (void) endAtLine:   (int) line {
    endLine = line;
}

// Cursor positioning
- (void) setCursorPositionX: (int) xpos
                          Y: (int) ypos {
}

- (void) cursorPositionX: (int*) xpos
                       Y: (int*) ypos {
}

// Line erasure
- (void) eraseLine {
}

@end
