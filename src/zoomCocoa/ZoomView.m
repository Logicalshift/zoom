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

        textScroller = [[ZoomScrollView allocWithZone: [self zone]] initWithFrame:
            [self bounds]
                                                                         zoomView:
            self];
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

// Set whether or not we recieve certain types of data
- (void) shouldReceiveCharacters {
}

- (void) shouldReceiveText: (int) maxLength {
    [self rearrangeUpperWindows];
    
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

- (void) rearrangeUpperWindows {
    int newSize = [self upperWindowSize];
    if (newSize != lastUpperWindowSize) {
        [textScroller tile];
        lastUpperWindowSize = newSize;
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

@end
