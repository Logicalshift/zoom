//
//  ZoomView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomView.h"
#import "ZoomLowerWindow.h"
#import "ZoomUpperWindow.h"

@implementation ZoomView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        zMachine = nil;

        [self setAutoresizesSubviews: YES];

        textScroller = [[NSScrollView allocWithZone: [self zone]] initWithFrame:
            [self bounds]];
        [textScroller setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];

        [textScroller setHasHorizontalScroller: NO];
        [textScroller setHasVerticalScroller: YES];
        
        NSSize contentSize = [textScroller contentSize];

        textView = [[ZoomTextView allocWithZone: [self zone]] initWithFrame:
            NSMakeRect(0,0,contentSize.width,contentSize.height)];

        [textView setMinSize:NSMakeSize(0.0, contentSize.height)];
        [textView setMaxSize:NSMakeSize(1e8, contentSize.height)];
        [textView setVerticallyResizable:YES];
        [textView setHorizontallyResizable:NO];
        [textView setAutoresizingMask:NSViewWidthSizable];
        [textView setEditable: NO];
        receiving = NO;
        moreOn    = NO;

        [textView setDelegate: self];
        [[textView textStorage] setDelegate: self];

        // Set up the text view container
        NSTextContainer* container = [textView textContainer];
        
        [container setContainerSize: NSMakeSize(contentSize.width, 1e8)];
        [container setWidthTracksTextView:YES];
        [container setHeightTracksTextView:NO];

        [textScroller setDocumentView: textView];
        [self addSubview: textScroller];

        moreView = [[ZoomMoreView alloc] init];
        [moreView setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin];
    }
    return self;
}

- (void) dealloc {
    if (zMachine) {
        [zMachine release];
    }

    [textScroller release];
    [textView release];
    [moreView release];

    [super dealloc];
}

- (void)drawRect:(NSRect)rect {
    // Drawing code here.
}

- (void) setZMachine: (NSObject<ZMachine>*) machine {
    if (zMachine) [zMachine release];

    NSLog(@"Kick start!");
    zMachine = [machine retain];
    [zMachine startRunningInDisplay: self];
}

// = ZDisplay functions =
- (NSObject<ZLowerWindow>*) createLowerWindow {
    ZoomLowerWindow* win = [[ZoomLowerWindow allocWithZone: [self zone]]
        initWithZoomView: self];

    NSLog(@"Creating lower window");

    return [win autorelease];
}

- (out byref NSObject<ZUpperWindow>*) createUpperWindow {
    ZoomUpperWindow* win = [[ZoomUpperWindow allocWithZone: [self zone]]
        initWithZoomView: self];

    NSLog(@"Creating upper window");

    return [win autorelease];
}

// Set whether or not we recieve certain types of data
- (void) shouldReceiveCharacters {
}

- (void) shouldReceiveText: (int) maxLength {
    receiving = YES;

    if (!moreOn) {
        [textView setEditable: YES];

        [self resetMorePrompt];
        [self scrollToEnd];
    }

    inputPos = [[textView textStorage] length];
}

- (void) stopReceiving {
    receiving = NO;
    [textView setEditable: NO];
}

// = Utility functions =
- (void) scrollToEnd {
    NSLayoutManager* mgr = [textView layoutManager];

    NSRange endGlyph = [textView selectionRangeForProposedRange:
        NSMakeRange([[textView textStorage] length]-1, 1)
                                                           granularity: NSSelectByCharacter];
    if (endGlyph.location > 0xf0000000) {
        return; // Doesn't exist
    }
    
    NSRect endRect = [mgr boundingRectForGlyphRange: endGlyph
                                    inTextContainer: [textView textContainer]];

    [textView scrollPoint:
        NSMakePoint(0,
                    NSMaxY(endRect) - [[textScroller contentView] frame].size.height)];
}

- (void) displayMoreIfNecessary {
    NSLayoutManager* mgr = [textView layoutManager];

    NSRange endGlyph = [textView selectionRangeForProposedRange:
        NSMakeRange([[textView textStorage] length]-1, 1)
                                                    granularity: NSSelectByCharacter];
    if (endGlyph.location > 0xf0000000) {
        return; // Doesn't exist
    }

    NSRect endRect = [mgr boundingRectForGlyphRange: endGlyph
                                    inTextContainer: [textView textContainer]];
    double endPoint = endRect.origin.y + endRect.size.height;
    NSSize maxSize = [textView maxSize];

    if (endPoint > maxSize.height) {
        morePoint = maxSize.height;
        moreOn = YES;
    }

    [self setShowsMorePrompt: moreOn];

    [self setNeedsDisplay: YES];
    [textView setEditable: NO];
}

- (void) resetMorePrompt {
    // Resets the point at which paging will next occur
    // Does NOT reset the point if paging is already going on
    
    double maxHeight;
    NSLayoutManager* mgr = [textView layoutManager];

    if (moreOn) {
        return; // More prompt is currently being displayed
    }

    NSRange endGlyph = [textView selectionRangeForProposedRange:
        NSMakeRange([[textView textStorage] length]-1, 1)
                                                    granularity: NSSelectByCharacter];
    if (endGlyph.location < 0xf0000000) {
        NSRect endRect = [mgr boundingRectForGlyphRange: endGlyph
                                        inTextContainer: [textView textContainer]];
        maxHeight = endRect.origin.y + endRect.size.height;
    } else {
        maxHeight = 0;
    }

    maxHeight += [textScroller contentSize].height;

    [textView setMaxSize: NSMakeSize(1e8, maxHeight)];
    [self scrollToEnd];
}

- (void) page {
    if (!moreOn) {
        return; // Nothing to do
    }

    moreOn = NO;
    [self setShowsMorePrompt: NO];
    
    double maxHeight = [textView maxSize].height;
    maxHeight += [textScroller contentSize].height;

    [textView setMaxSize: NSMakeSize(1e8, maxHeight)];
    [textView sizeToFit];

    [self scrollToEnd];
    [self displayMoreIfNecessary];

    if (!moreOn && receiving) {
        [textView setEditable: YES];
    }
}

- (void) setShowsMorePrompt: (BOOL) shown {
    [moreView removeFromSuperview];
    if (shown) {
        // We put the 'more' prompt in as a subview of the text view: this
        // ensures that it behaves correctly when scrolling, and also ensures
        // that it always appears at the bottom of the text.
        // This technique has one failure, though: when the more prompt moves,
        // bits may get left on the screen as a result of scrolling
        NSRect content = [textView frame];
        
        [moreView setSize];
        NSSize moreSize = [moreView frame].size;

        // Remember that NSTextViews use a flipped coordinate system!
        // (Sigh, I much preferred RISC OS's negative coordinate system
        // to this: all calculations worked regardless of whether or not
        // something was flipped)
        NSRect moreFrame = NSMakeRect(NSMaxX(content) - moreSize.width,
                                      NSMaxY(content) - moreSize.height,
                                      moreSize.width, moreSize.height);
        
        [moreView setFrame: moreFrame];
        [textView addSubview: moreView];
    }
}

- (NSTextView*) textView {
    return textView;
}

// = TextView delegate methods =
- (BOOL)    	textView:(NSTextView *)aTextView
shouldChangeTextInRange:(NSRange)affectedCharRange
    replacementString:(NSString *)replacementString {
    if (affectedCharRange.location < inputPos) {
        return NO;
    } else {
        return YES;
    }
}

- (void)textStorageDidProcessEditing:(NSNotification *)aNotification {
    if (!receiving) return;
    
    // Set the input character attributes to the input style
    //[text setAttributes: [self attributesForStyle: style_Input]
    //              range: NSMakeRange(inputPos,
    //[text length]-inputPos)];

    NSTextStorage* text = [textView textStorage];
    
    // Check to see if there's any newlines in the input...
    int newlinePos = -1;
    do {
        int x;
        NSString* str = [text string];
        int len = [str length];

        newlinePos = -1;

        for (x=inputPos; x < len; x++) {
            if ([str characterAtIndex: x] == '\n') {
                newlinePos = x;
                break;
            }
        }

        if (newlinePos >= 0) {
            [zMachine inputText: [str substringWithRange: NSMakeRange(inputPos,
                                                                      newlinePos-inputPos+1)]];
            inputPos = newlinePos + 1;
        }
    } while (newlinePos >= 0);
}

// = Event methods =

- (void)keyDown:(NSEvent *)theEvent {
    if (moreOn) {
        [self page];
    }
}

@end
