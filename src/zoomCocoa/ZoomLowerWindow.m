//
//  ZoomLowerWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Oct 08 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomLowerWindow.h"


@implementation ZoomLowerWindow

- (id) initWithZoomView: (ZoomView*) zV {
    self = [super init];

    if (self) {
        zoomView = [zV retain];
    }

    return self;
}

- (void) dealloc {
    [zoomView release];
    [super dealloc];
}

// Clears the window
- (void) clear {
    [[[[zoomView textView] textStorage] mutableString] setString: @""];
    [zoomView scrollToEnd];
    [zoomView resetMorePrompt];
}

// Sets the input focus to this window
- (void) setFocus {
    NSLog(@"Lower window focus");
}

// Sending data to a window
- (void) writeString: (NSAttributedString*) string {
    [[[zoomView textView] textStorage] appendAttributedString: string];
    [zoomView scrollToEnd];
    [zoomView displayMoreIfNecessary];
}

@end
