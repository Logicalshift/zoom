//
//  ZoomTextView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomTextView.h"
#import "ZoomView.h"

@implementation ZoomTextView

- (void) keyDown: (NSEvent*) event {
    [super keyDown: event];
    
    if (![self isEditable]) {
        NSView* superview = [self superview];

        while (![superview isKindOfClass: [ZoomView class]]) {
            superview = [superview superview];
            if (superview == NULL) break;
        }

        [superview keyDown: event];
    }
}

@end
