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

#import "ZoomScrollView.h"

@implementation ZoomView

static NSMutableArray* defaultFonts = nil;
static NSArray* defaultColours = nil;

+ (void) initialize {
    NSString* defaultFont = @"Gill Sans";
    NSString* fixedFont = @"Courier";
    NSFontManager* mgr = [NSFontManager sharedFontManager];
    NSLog(@"ZoomView initialise");

    defaultFonts = [[NSMutableArray alloc] init];

    int x;
    for (x=0; x<16; x++) {
        NSFont* thisFont = [NSFont fontWithName: defaultFont
                                           size: 12];
        NSFontTraitMask mask = 0;
        if ((x&4)) thisFont = [NSFont fontWithName: fixedFont
                                              size: 12];

        if ((x&1)) mask|=NSBoldFontMask;
        if ((x&2)) mask|=NSItalicFontMask;
        if ((x&4)) mask|=NSFixedPitchFontMask;

        if (mask != 0)
            thisFont = [mgr convertFont: thisFont
                            toHaveTrait: mask];

        [defaultFonts addObject: thisFont];
    }

    defaultColours = [[NSArray arrayWithObjects:
        [NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1],
        [NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1],
        [NSColor colorWithDeviceRed: 0 green: 1 blue: 0 alpha: 1],
        [NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha: 1],
        [NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1],
        [NSColor colorWithDeviceRed: 1 green: 0 blue: 1 alpha: 1],
        [NSColor colorWithDeviceRed: 0 green: 1 blue: 1 alpha: 1],
        [NSColor colorWithDeviceRed: 1 green: 1 blue: .8 alpha: 1],
        
        [NSColor colorWithDeviceRed: .73 green: .73 blue: .73 alpha: 1],
        [NSColor colorWithDeviceRed: .53 green: .53 blue: .53 alpha: 1],
        [NSColor colorWithDeviceRed: .26 green: .26 blue: .26 alpha: 1],
        nil] retain];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        upperWindows = [[NSMutableArray allocWithZone: [self zone]] init];
        lowerWindows = [[NSMutableArray allocWithZone: [self zone]] init];
        
        zMachine = nil;

        [self setAutoresizesSubviews: YES];

        // Set up the scroll view...
        textScroller = [[ZoomScrollView allocWithZone: [self zone]] initWithFrame:
            [self bounds]
                                                                         zoomView:
            self];
        [textScroller setAutoresizingMask: NSViewHeightSizable|NSViewWidthSizable];

        [textScroller setHasHorizontalScroller: NO];
        [textScroller setHasVerticalScroller: YES];
        
        NSSize contentSize = [textScroller contentSize];

        // Now the content view
        textView = [[ZoomTextView allocWithZone: [self zone]] initWithFrame:
            NSMakeRect(0,0,contentSize.width,contentSize.height)];

        [textView setMinSize:NSMakeSize(0.0, contentSize.height)];
        [textView setMaxSize:NSMakeSize(1e8, contentSize.height)];
        [textView setVerticallyResizable:YES];
        [textView setHorizontallyResizable:NO];
        [textView setAutoresizingMask:NSViewWidthSizable];
        [textView setEditable: NO];
        receiving = NO;
        receivingCharacters = NO;
        moreOn    = NO;
        moreReferencePoint = 0.0;

        [textView setDelegate: self];
        [[textView textStorage] setDelegate: self];

        // Next, a text container used as a 'buffer' - contains the text 'hidden'
        // by the upper window
        upperWindowBuffer = [[NSTextContainer allocWithZone: [self zone]] init];
        [upperWindowBuffer setContainerSize: NSMakeSize(100, 100)];
        [[textView layoutManager] insertTextContainer: upperWindowBuffer
                                              atIndex: 0];

        // Set up the text view container
        NSTextContainer* container = [textView textContainer];
        
        [container setContainerSize: NSMakeSize(contentSize.width, 1e8)];
        [container setWidthTracksTextView:YES];
        [container setHeightTracksTextView:NO];

        [textScroller setDocumentView: textView];
        [self addSubview: textScroller];

        moreView = [[ZoomMoreView alloc] init];
        [moreView setAutoresizingMask: NSViewMinXMargin|NSViewMinYMargin];

        // Styles, fonts, etc
        fonts = [defaultFonts retain];
        colours = [defaultColours retain];
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
    [fonts release];
    [colours release];
    [upperWindowBuffer release];

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

    [lowerWindows addObject: win];

    NSLog(@"Creating lower window");

    [win clearWithStyle: [[[ZStyle alloc] init] autorelease]];
    return [win autorelease];
}

- (out byref NSObject<ZUpperWindow>*) createUpperWindow {
    ZoomUpperWindow* win = [[ZoomUpperWindow allocWithZone: [self zone]]
        initWithZoomView: self];

    [upperWindows addObject: win];

    NSLog(@"Creating upper window");

    [win clearWithStyle: [[[ZStyle alloc] init] autorelease]];
    return [win autorelease];
}

- (void) startExclusive {
    exclusiveMode = YES;

    while (exclusiveMode) {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

        [[NSRunLoop currentRunLoop] acceptInputForMode: NSConnectionReplyMode
                                            beforeDate: [NSDate distantFuture]];

        [pool release];
    }

    [self rearrangeUpperWindows];
}

- (void) stopExclusive {
    exclusiveMode = NO;
}

- (void) flushBuffer: (ZBuffer*) toFlush {
    [toFlush blat];
}

// Set whether or not we recieve certain types of data
- (void) shouldReceiveCharacters {
    [self rearrangeUpperWindows];

    int currentSize = [self upperWindowSize];
    if (currentSize != lastTileSize) {
        [textScroller tile];
        [self updateMorePrompt];
        lastTileSize = currentSize;
    }
    
    // Paste stuff
    NSEnumerator* upperEnum = [upperWindows objectEnumerator];
    ZoomUpperWindow* win;
    while (win = [upperEnum nextObject]) {
        [textView pasteUpperWindowLinesFrom: win];
    }

    // If the more prompt is off, then set up for editting
    if (!moreOn) {
        [self resetMorePrompt];
        [self scrollToEnd];
    }
    
    receivingCharacters = YES;
}

- (void) shouldReceiveText: (int) maxLength {
    [self rearrangeUpperWindows];

    int currentSize = [self upperWindowSize];
    if (currentSize != lastTileSize) {
        [textScroller tile];
        [self updateMorePrompt];
        lastTileSize = currentSize;
    }

    // Paste stuff
    NSEnumerator* upperEnum = [upperWindows objectEnumerator];
    ZoomUpperWindow* win;
    while (win = [upperEnum nextObject]) {
        [textView pasteUpperWindowLinesFrom: win];
    }
    
    // If the more prompt is off, then set up for editting
    if (!moreOn) {
        [textView setEditable: YES];

        [self resetMorePrompt];
        [self scrollToEnd];
    }

    inputPos = [[textView textStorage] length];
    receiving = YES;
}

- (void) stopReceiving {
    receiving = NO;
    receivingCharacters = NO;
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
                    NSMaxY(endRect))];
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
    double endPoint = endRect.origin.y;
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
        maxHeight = endRect.origin.y;
    } else {
        maxHeight = 0;
    }

    moreReferencePoint = maxHeight;
    maxHeight += [textScroller contentSize].height;

    [textView setMaxSize: NSMakeSize(1e8, maxHeight)];
    [self scrollToEnd];
}

- (void) updateMorePrompt {
    // Updates the more prompt to represent the new height of the window
    double maxHeight = moreReferencePoint + [textScroller contentSize].height;

    [textView setMaxSize: NSMakeSize(1e8, maxHeight)];
    [textView sizeToFit];
    [self scrollToEnd];
    [self displayMoreIfNecessary];
}

- (void) page {
    if (!moreOn) {
        return; // Nothing to do
    }

    moreOn = NO;
    [self setShowsMorePrompt: NO];
    
    double maxHeight = [textView maxSize].height;
    moreReferencePoint = maxHeight;
    maxHeight += [textScroller contentSize].height;

    [self updateMorePrompt];

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

- (BOOL)handleKeyDown:(NSEvent *)theEvent {
    if (moreOn) {
        // FIXME: maybe only respond to certain keys
        [self page];
        return YES;
    }

    if (receivingCharacters) {
        NSString* chars = [theEvent characters];
        int key = -1;

        // Deal with special keys
        switch ([chars characterAtIndex: 0]) {
            case NSUpArrowFunctionKey: key = 129; break;
            case NSDownArrowFunctionKey: key = 130; break;
            case NSLeftArrowFunctionKey: key = 131; break;
            case NSRightArrowFunctionKey: key = 132; break;
            case 10: key = 13; break;
            case NSDeleteFunctionKey: key = 8; break;

            case NSF1FunctionKey: key = 133; break;
            case NSF2FunctionKey: key = 134; break;
            case NSF3FunctionKey: key = 135; break;
            case NSF4FunctionKey: key = 136; break;
            case NSF5FunctionKey: key = 137; break;
            case NSF6FunctionKey: key = 138; break;
            case NSF7FunctionKey: key = 139; break;
            case NSF8FunctionKey: key = 140; break;
            case NSF9FunctionKey: key = 141; break;
            case NSF10FunctionKey: key = 142; break;
            case NSF11FunctionKey: key = 143; break;
            case NSF12FunctionKey: key = 144; break;
        }

        // If there's a special key...
        if (key >= 0) {
            unichar chrs[2];
            chrs[0] = key;

            chars = [NSString stringWithCharacters: chrs
                                            length: 1];
        }
        
        [zMachine inputText: chars];
        
        return YES;
    }

    return NO;
}

// = Formatting, fonts, colours, etc =

- (NSAttributedString*) formatZString: (NSString*) zString
                            withStyle: (ZStyle*) style {
    // Strings come from Zoom's server formatted with ZStyles rather than
    // actual styles (so that the interface can choose it's own formatting).
    // So we need this to translate those styles into 'real' ones.

    NSMutableAttributedString* result;

    // Font
    NSFont* fontToUse = nil;
    int fontnum;

    fontnum =
        ([style bold]?1:0)|
        ([style underline]?2:0)|
        ([style fixed]?4:0)|
        ([style symbolic]?8:0);

    fontToUse = [fonts objectAtIndex: fontnum];

    // Colour
    NSColor* foregroundColour = [style foregroundTrue];
    NSColor* backgroundColour = [style backgroundTrue];

    if (foregroundColour == nil) {
        foregroundColour = [colours objectAtIndex: [style foregroundColour]];
    }
    if (backgroundColour == nil) {
        backgroundColour = [colours objectAtIndex: [style backgroundColour]];
    }

    if ([style reversed]) {
        NSColor* tmp = foregroundColour;

        foregroundColour = backgroundColour;
        backgroundColour = tmp;
    }

    // Generate the new attributes
    NSDictionary* newAttr = [NSDictionary dictionaryWithObjectsAndKeys:
        fontToUse, NSFontAttributeName,
        foregroundColour, NSForegroundColorAttributeName,
        backgroundColour, NSBackgroundColorAttributeName,
        nil];

    // Create + append the newly attributed string
    result = [[NSMutableAttributedString alloc] initWithString: zString
                                                    attributes: newAttr];

    return [result autorelease];
}

- (NSColor*) foregroundColourForStyle: (ZStyle*) style {
    NSColor* res;

    if ([style reversed]) {
        res = [style backgroundTrue];
    } else {
        res = [style foregroundTrue];
    }

    if (res == nil) {
        if ([style reversed]) {
            res = [colours objectAtIndex: [style backgroundColour]];
        } else {
            res = [colours objectAtIndex: [style foregroundColour]];
        }
    }
    
    return res;
}

- (NSColor*) backgroundColourForStyle: (ZStyle*) style {
    NSColor* res;

    if (![style reversed]) {
        res = [style backgroundTrue];
    } else {
        res = [style foregroundTrue];
    }

    if (res == nil) {
        if (![style reversed]) {
            res = [colours objectAtIndex: [style backgroundColour]];
        } else {
            res = [colours objectAtIndex: [style foregroundColour]];
        }
    }

    return res;
}

- (NSFont*) fontWithStyle: (int) style {
    if (style < 0 || style >= 16) {
        return nil;
    }

    return [fonts objectAtIndex: style];
}

- (int) upperWindowSize {
    int height;
    NSEnumerator* upperEnum;

    upperEnum = [upperWindows objectEnumerator];

    ZoomUpperWindow* win;

    height = 0;
    while (win = [upperEnum nextObject]) {
        int winHeight = [win length];
        if (winHeight > 0) height += winHeight;
    }

    return height;
}

- (void) setUpperBuffer: (double) bufHeight {
    // Update the upper window buffer
    NSSize contentSize = [textScroller contentSize];
    [upperWindowBuffer setContainerSize: NSMakeSize(contentSize.width, bufHeight)];

    [self padToLowerWindow];
}

- (double) upperBufferHeight {
    return [upperWindowBuffer containerSize].height;
}

- (void) rearrangeUpperWindows {
    int newSize = [self upperWindowSize];
    if (newSize != lastUpperWindowSize) {
        // Lay things out
        lastUpperWindowSize = newSize;

        // The place where we need to put the more prompt may have changed
        [self updateMorePrompt];
    }

    // Redraw the upper windows if necessary
    if (upperWindowNeedsRedrawing) {
        [textScroller updateUpperWindows];
        upperWindowNeedsRedrawing = NO;
    }
}

- (NSArray*) upperWindows {
    return upperWindows;
}

- (void) upperWindowNeedsRedrawing {
    upperWindowNeedsRedrawing = YES;
}

- (void) padToLowerWindow {
    // This is a kind of poorly documented feature of the Z-Machine display model
    // (But often used in modern games, unfortunately)
    // It is usually impossible to move the cursor while in the lower window.
    // However, there is one way to move it vertically: split the window so that
    // the upper window overlaps the cursor. Officially this is not reliable
    // behaviour, but a sufficient number of games make use of it (not helped
    // by the Glk interpreter window model) that we have to emulate it or
    // things start to look a bit crappy.
    //
    // Behaviour is: if the upper window overlaps the cursor, then we move the cursor
    // until this is no longer the case. Text previously printed is unaffected.
    // Only applies when the lower window is sufficiently empty to contain no
    //
    // Here we do this by adding newlines. This may occasionally cause some
    // 'bouncing', as Cocoa is not designed to allow for a line of text that
    // appears in two containers (you can probably hack it to do it, though,
    // so there's a project for some brave future volunteer)
    //
    // Er, right, the code:
    NSTextContainer* theContainer;

    if (upperWindowBuffer == nil) return;

    if ([[textView textStorage] length] == 0) {
        [[[textView textStorage] mutableString] appendString: @"\n"];
    }
    
    do {
        NSRange endGlyph = [textView selectionRangeForProposedRange:
            NSMakeRange([[textView textStorage] length]-1, 1)
                                                    granularity: NSSelectByCharacter];
        if (endGlyph.location > 0xf0000000) {
            return; // Doesn't exist
        }

        NSRange eRange;
        theContainer = [[textView layoutManager] textContainerForGlyphAtIndex: endGlyph.location effectiveRange: &eRange];

        if (theContainer == upperWindowBuffer) {
            [[[textView textStorage] mutableString] appendString: @"\n"];
        }

        // I suppose there's an outside chance of an infinite loop here
    } while (theContainer == upperWindowBuffer);
}

@end
