//
//  ZoomView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomProtocol.h"
#import "ZoomMoreView.h"
#import "ZoomTextView.h"


@interface ZoomView : NSView<ZDisplay> {
    NSObject<ZMachine>* zMachine;

    // Subviews
    ZoomTextView* textView;
    NSScrollView* textScroller;

    int inputPos;
    BOOL receiving;

    double morePoint;
    BOOL moreOn;

    ZoomMoreView* moreView;
}

- (void) setZMachine: (NSObject<ZMachine>*) machine;

- (void) scrollToEnd;
- (void) resetMorePrompt;

- (void) setShowsMorePrompt: (BOOL) shown;
- (void) displayMoreIfNecessary;
- (void) page;

- (NSTextView*) textView;

@end
