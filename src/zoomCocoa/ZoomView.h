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
#import "ZoomScrollView.h"

#define ZBoldStyle 1
#define ZUnderlineStyle 2
#define ZFixedStyle 4
#define ZSymbolicStyle 8

@class ZoomScrollView;
@class ZoomTextView;
@interface ZoomView : NSView<ZDisplay> {
    NSObject<ZMachine>* zMachine;

    // Subviews
    ZoomTextView* textView;
    NSTextContainer* upperWindowBuffer; // Things hidden under the upper window
    ZoomScrollView* textScroller;

    int inputPos;
    BOOL receiving;
    BOOL receivingCharacters;

    double morePoint;
    double moreReferencePoint;
    BOOL moreOn;

    ZoomMoreView* moreView;

    NSArray* fonts; // 16 entries
    NSArray* colours; // 11 entries

    NSMutableArray* upperWindows;
    NSMutableArray* lowerWindows; // Not that more than one makes any sort of sense
    int lastUpperWindowSize;
    BOOL upperWindowNeedsRedrawing;

    BOOL exclusiveMode;
}

- (void) setZMachine: (NSObject<ZMachine>*) machine;

- (void) scrollToEnd;
- (void) resetMorePrompt;
- (void) updateMorePrompt;

- (void) setShowsMorePrompt: (BOOL) shown;
- (void) displayMoreIfNecessary;
- (void) page;

- (NSAttributedString*) formatZString: (NSString*) zString
                            withStyle: (ZStyle*) style;

- (ZoomTextView*) textView;

- (NSFont*) fontWithStyle: (int) style;
- (NSColor*) foregroundColourForStyle: (ZStyle*) style;
- (NSColor*) backgroundColourForStyle: (ZStyle*) style;

- (int)  upperWindowSize;
- (void) setUpperBuffer: (double) bufHeight;
- (double) upperBufferHeight;
- (void) rearrangeUpperWindows;
- (NSArray*) upperWindows;

- (void) upperWindowNeedsRedrawing;
- (BOOL) handleKeyDown:(NSEvent*) theEvent;

@end
