//
//  ZoomLowerWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Oct 08 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomLowerWindow.h"


@implementation ZoomLowerWindow

- (id) initWithZoomView: (ZoomView*) zV {
    self = [super init];

    if (self) {
        zoomView = zV; // In Soviet Russia, zoomView retains us. 
    }

    return self;
}

- (void) dealloc {
    // [zoomView release];
    [super dealloc];
}

// Clears the window
- (void) clearWithStyle: (ZStyle*) style {
    // Clear the lower part of all the upper windows
    NSEnumerator* upperEnum = [[zoomView upperWindows] objectEnumerator];
    ZoomUpperWindow* win;
    while (win = [upperEnum nextObject]) {
        [win cutLines];
    }
    
    [[[[zoomView textView] textStorage] mutableString] setString: @""];
    [[zoomView textView] setBackgroundColor: [zoomView backgroundColourForStyle: style]];
    [[zoomView textView] clearPastedLines]; 
    [zoomView scrollToEnd];
    [zoomView resetMorePrompt];
}

// Sets the input focus to this window
- (void) setFocus {
}

// Sending data to a window
- (void) writeString: (NSString*) string
           withStyle: (ZStyle*) style {
    [[[zoomView textView] textStorage] appendAttributedString:
        [zoomView formatZString: string
                      withStyle: style]];
    //[[zoomView buffer] appendAttributedString:
    //    [zoomView formatZString: string
    //                  withStyle: style]];
    
    [zoomView scrollToEnd];
    [zoomView displayMoreIfNecessary];
}

@end
