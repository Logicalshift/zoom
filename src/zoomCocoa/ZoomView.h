//
//  ZoomView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
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
    int lastTileSize;
    BOOL upperWindowNeedsRedrawing;

    BOOL exclusiveMode;

    // The task, if we're running it
    NSTask* zoomTask;
    NSPipe* zoomTaskStdout;
    NSMutableString* zoomTaskData;

    // The delegate
    NSObject* delegate;
    
    // Details about the file we're currently saving
    long creatorCode; // 'YZZY' for Zoom
    long typeCode;
}

// The delegate
- (void) setDelegate: (id) delegate;
- (id)   delegate;

- (void) killTask;

// Specifying what to run
- (void) setZMachine: (NSObject<ZMachine>*) machine;
- (void) runNewServer: (NSString*) serverName;
- (NSObject<ZMachine>*) zMachine;

// Scrolling, more prompt
- (void) scrollToEnd;
- (void) resetMorePrompt;
- (void) updateMorePrompt;

- (void) setShowsMorePrompt: (BOOL) shown;
- (void) displayMoreIfNecessary;
- (void) page;

// Formatting a string
- (NSAttributedString*) formatZString: (NSString*) zString
                            withStyle: (ZStyle*) style;

- (ZoomTextView*) textView;

// Fonts, colours, etc
- (NSFont*) fontWithStyle: (int) style;
- (NSColor*) foregroundColourForStyle: (ZStyle*) style;
- (NSColor*) backgroundColourForStyle: (ZStyle*) style;

- (void) setFonts:   (NSArray*) fonts;
- (void) setColours: (NSArray*) colours;

// File saving
- (long) creatorCode;
- (void) setCreatorCode: (long) code;

// The upper window
- (int)  upperWindowSize;
- (void) setUpperBuffer: (double) bufHeight;
- (double) upperBufferHeight;
- (void) rearrangeUpperWindows;
- (NSArray*) upperWindows;
- (void) padToLowerWindow;

- (void) upperWindowNeedsRedrawing;

// Event handling
- (BOOL) handleKeyDown:(NSEvent*) theEvent;

@end

// ZoomView delegate methods
@interface NSObject(ZoomViewDelegate)

- (void) zMachineStarted: (id) sender;
- (void) zMachineFinished: (id) sender;

@end
