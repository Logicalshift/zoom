//
//  ZoomView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomView.h"
#import "ZoomLowerWindow.h"
#import "ZoomUpperWindow.h"

#import "ZoomScrollView.h"

@implementation ZoomView

static ZoomView** allocatedViews = nil;
static int        nAllocatedViews = 0;

NSString* ZoomStyleAttributeName = @"ZoomStyleAttributeName";

static void finalizeViews(void);

+ (void) initialize {
    atexit(finalizeViews);
}

+ (void) finalize {
    int view;
    
    for (view=0;view<nAllocatedViews;view++) {
        [allocatedViews[view] killTask];
    }
}

static void finalizeViews(void) {
    [ZoomView finalize];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
	
    if (self) {
        // Mark views as allocated
        allocatedViews = realloc(allocatedViews, sizeof(ZoomView*) * (nAllocatedViews+1));
        allocatedViews[nAllocatedViews] = self;
        nAllocatedViews++;

        // No upper/lower windows
        upperWindows = [[NSMutableArray allocWithZone: [self zone]] init];
        lowerWindows = [[NSMutableArray allocWithZone: [self zone]] init];

        // No Zmachine/task to start with
        zMachine = nil;
        zoomTask = nil;
        delegate = nil;

        // Yep, we autoresize our subviews
        [self setAutoresizesSubviews: YES];
        
        // Default creator code is YZZY (Zoom's creator code)
        creatorCode = 'YZZY';
        typeCode = '\?\?\?\?';

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
		[textView setAllowsUndo: NO];
		[textView setUsesFontPanel: NO];
		
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
		viewPrefs = [[ZoomPreferences globalPreferences] retain];
		fonts = [[viewPrefs fonts] retain];
		colours = [[viewPrefs colours] retain];

        // Get notifications
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(boundsChanged:)
                                                     name: NSViewBoundsDidChangeNotification
                                                   object: self];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(boundsChanged:)
                                                     name: NSViewFrameDidChangeNotification
                                                   object: self];
        [self setPostsBoundsChangedNotifications: YES];
        [self setPostsFrameChangedNotifications: YES];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(preferencesHaveChanged:)
													 name: ZoomPreferencesHaveChangedNotification
												   object: viewPrefs];		
    }
	
    return self;
}

- (void) dealloc {    
    if (zMachine) {
        [zMachine release];
    }

    if (zoomTask) {
        [zoomTask terminate];
        [zoomTask release];
    }

    if (zoomTaskStdout) {
        [zoomTaskStdout release];
    }

    if (zoomTaskData) {
        [zoomTaskData release];
    }

    int view;
    for (view=0;view<nAllocatedViews;view++) {
        if (allocatedViews[view] == self) {
            memmove(allocatedViews + view, allocatedViews + view + 1,
                    sizeof(ZoomView*)*(nAllocatedViews-view-1));
            nAllocatedViews--;
        }
    }

    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [textScroller release];
    [textView release];
    [moreView release];
    [fonts release];
    [colours release];
    [upperWindowBuffer release];
	[viewPrefs release];

    [super dealloc];
}

- (void)drawRect:(NSRect)rect {
    // Drawing code here.
}

- (void) setZMachine: (NSObject<ZMachine>*) machine {
    if (zMachine) [zMachine release];

    zMachine = [machine retain];
    [zMachine startRunningInDisplay: self];
}

- (NSObject<ZMachine>*) zMachine {
    return zMachine;
}

// = ZDisplay functions =
- (NSObject<ZLowerWindow>*) createLowerWindow {
    ZoomLowerWindow* win = [[ZoomLowerWindow allocWithZone: [self zone]]
        initWithZoomView: self];

    [lowerWindows addObject: win];

    [win clearWithStyle: [[[ZStyle alloc] init] autorelease]];
    return [win autorelease];
}

- (out byref NSObject<ZUpperWindow>*) createUpperWindow {
    ZoomUpperWindow* win = [[ZoomUpperWindow allocWithZone: [self zone]]
        initWithZoomView: self];

    [upperWindows addObject: win];

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

- (void) dimensionX: (out int*) xSize
                  Y: (out int*) ySize {
    NSSize fixedSize = [@"M" sizeWithAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [self fontWithStyle:ZFixedStyle], NSFontAttributeName, nil]];
    NSRect ourBounds = [textView bounds];

    *xSize = floor(ourBounds.size.width  / fixedSize.width);
    *ySize = floor(ourBounds.size.height / fixedSize.height);
}

- (void) boundsChanged: (NSNotification*) not {
    if (zMachine) {
        [zMachine displaySizeHasChanged];
    }
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
    
    if (receiving) {
        // Move the input position if required
        int modifiers = [theEvent modifierFlags];
        
        NSString* chars = [theEvent characters];
        
        modifiers &= NSControlKeyMask|NSCommandKeyMask|NSAlternateKeyMask|NSFunctionKeyMask;
        
        if (modifiers == 0) {
            NSRange selRange = [textView selectedRange];
                        
            if (selRange.location < inputPos) {
                [textView setSelectedRange: NSMakeRange([[textView textStorage] length], 0)];
            }
        }
    }

    return NO;
}

// = Formatting, fonts, colours, etc =

- (NSDictionary*) attributesForStyle: (ZStyle*) style {
    // Strings come from Zoom's server formatted with ZStyles rather than
    // actual styles (so that the interface can choose it's own formatting).
    // So we need this to translate those styles into 'real' ones.
	
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
		[[style copy] autorelease], ZoomStyleAttributeName,
        nil];
	
	return newAttr;
}

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
		[[style copy] autorelease], ZoomStyleAttributeName,
        nil];

    // Create + append the newly attributed string
    result = [[NSMutableAttributedString alloc] initWithString: zString
                                                    attributes: newAttr];

    return [result autorelease];
}

- (void) setFonts: (NSArray*) newFonts {
    // FIXME: check that fonts is valid
    // FIXME: update fonts displayed previously
    
    [fonts release];
    fonts = [[NSArray allocWithZone: [self zone]] initWithArray: newFonts 
                                                      copyItems: YES];
}

- (void) setColours: (NSArray*) newColours {
    [colours release];
    colours = [[NSArray allocWithZone: [self zone]] initWithArray: newColours
                                                        copyItems: YES];
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
}

- (double) upperBufferHeight {
    return [upperWindowBuffer containerSize].height;
}

- (void) rearrangeUpperWindows {
    int newSize = [self upperWindowSize];
    if (newSize != lastUpperWindowSize) {
        // Lay things out
        lastUpperWindowSize = newSize;

        // Force text display onto lower window (or where the lower window will be)
        NSDictionary* fixedAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
            [self fontWithStyle:ZFixedStyle], NSFontAttributeName, nil];
        NSSize fixedSize = [@"M" sizeWithAttributes: fixedAttributes];

        NSAttributedString* newLine = [[[NSAttributedString alloc] initWithString: @"\n"
                                                                       attributes: fixedAttributes]
            autorelease];

        double sepHeight = fixedSize.height * (double)newSize;
        sepHeight -= [upperWindowBuffer containerSize].height;

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

            NSRect endRect = [[textView layoutManager] boundingRectForGlyphRange: endGlyph
                                                                 inTextContainer: [textView textContainer]];

            if (NSMaxY(endRect) < sepHeight) {
                [[textView textStorage] appendAttributedString: newLine];
            } else {
                break;
            }
        } while (1);

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

- (void) runNewServer: (NSString*) serverName {
    if (zMachine != nil) {
        [zMachine release];
        zMachine = nil;
        
        // FIXME: reset the display
    }
    
    if (zoomTask != nil) {
        [zoomTask terminate];
        [zoomTask release];
        zoomTask = nil;
    }

    if (zoomTaskStdout != nil) {
        [zoomTaskStdout release];
        zoomTaskStdout = nil;
    }

    if (zoomTaskData != nil) {
        [zoomTaskData release];
        zoomTaskData = nil;
    }

    zoomTask = [[NSTask allocWithZone: [self zone]] init];
    zoomTaskData = [[NSMutableString allocWithZone: [self zone]] init];

    if (serverName == nil) {
        serverName = [[NSBundle mainBundle] pathForResource: @"ZoomServer"
                                                     ofType: nil];
    }

    // Prepare for launch
    [zoomTask setLaunchPath: serverName];
    
    zoomTaskStdout = [[NSPipe allocWithZone: [self zone]] init];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_zoomTaskNotification:)
                                                 name: NSFileHandleDataAvailableNotification
                                               object: [zoomTaskStdout fileHandleForReading]];
    [[zoomTaskStdout fileHandleForReading] waitForDataInBackgroundAndNotify];

    [zoomTask setStandardOutput: zoomTaskStdout];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_zoomTaskFinished:)
                                                 name: NSTaskDidTerminateNotification
                                               object: zoomTask];
    
    // Light the blue touch paper
    [zoomTask launch];

    // ***FOOOM***
}

- (void) _zoomTaskFinished: (NSNotification*) not {
    // The task has finished
    if (zMachine) {
        [zMachine release];
        zMachine = nil;
    }

    // Notify the user (display a message)
    ZStyle* notifyStyle = [[ZStyle allocWithZone: [self zone]] init];
    ZStyle* standardStyle = [[ZStyle allocWithZone: [self zone]] init];
    [notifyStyle setForegroundColour: 7];
    [notifyStyle setBackgroundColour: 1];

    NSString* finishString = @"[ The game has finished ]";
    if ([zoomTask terminationStatus] != 0) {
        finishString = @"[ The Zoom interpreter has quit unexpectedly ]";
    }

    NSAttributedString* newline = [self formatZString: @"\n"
                                            withStyle: [standardStyle autorelease]];
    NSAttributedString* string = [self formatZString: finishString
                                           withStyle: [notifyStyle autorelease]];

    [[textView textStorage] appendAttributedString: newline];
    [[textView textStorage] appendAttributedString: string];
    [[textView textStorage] appendAttributedString: newline];

    // Update the windows
    [self rearrangeUpperWindows];

    int currentSize = [self upperWindowSize];
    if (currentSize != lastTileSize) {
        [textScroller tile];
        [self padToLowerWindow];
        [self updateMorePrompt];
        lastTileSize = currentSize;
    }

    // Paste stuff
    NSEnumerator* upperEnum = [upperWindows objectEnumerator];
    ZoomUpperWindow* win;
    while (win = [upperEnum nextObject]) {
        [textView pasteUpperWindowLinesFrom: win];
    }
    
    // Notify the delegate
    if (delegate && [delegate respondsToSelector: @selector(zMachineFinished:)]) {
        [delegate zMachineFinished: self];
    }
    
    // Free things up
    [zoomTask release];
    [zoomTaskStdout release];
    [zoomTaskData release];

    zoomTask = nil;
    zoomTaskStdout = nil;
    zoomTaskData = nil;
}

- (void) _zoomTaskNotification: (NSNotification*) not {
    // Data is waiting on stdout: receive it
    NSData* inData = [[zoomTaskStdout fileHandleForReading] availableData];

    if ([inData length]) {
        [zoomTaskData appendString: [NSString stringWithCString: [inData bytes]
                                                         length: [inData length]]];
        
        if (zMachine == nil) {
            // Task data could be indicating that we should start up the ZMachine
            if ([zoomTaskData rangeOfString: @"ZoomServer: Ready"].location != NSNotFound) {
                NSObject<ZVendor>* theVendor = nil;
                NSString* connectionName = [NSString stringWithFormat: @"ZoomVendor-%i",
                    [zoomTask processIdentifier]];

                theVendor =
                    [[NSConnection rootProxyForConnectionWithRegisteredName: connectionName
                                                                      host: nil] retain];

                if (theVendor) {
                    zMachine = [[theVendor createNewZMachine] retain];
                    [theVendor release];
                }

                if (!zMachine) {
                    NSLog(@"Failed to create Z-Machine");

                    [zoomTask terminate];
                } else {
                    if (delegate && [delegate respondsToSelector: @selector(zMachineStarted:)]) {
                        [delegate zMachineStarted: self];
                    }
                    
                    [zMachine startRunningInDisplay: self];
                }
            }
        } else {
            printf("%s", [[NSString stringWithCString: [inData bytes]
                                               length: [inData length]] cString]);
        }
    } else {
    }

    [[zoomTaskStdout fileHandleForReading] waitForDataInBackgroundAndNotify];
}

// = Prompting for files =
- (void) setupPanel: (NSSavePanel*) panel
               type: (ZFileType) type {
    BOOL supportsMessage = [panel respondsToSelector: @selector(setMessage:)];
    [panel setCanSelectHiddenExtension: YES];
    
    NSString* saveOpen = @"Save as";
    
    if ([panel isKindOfClass: [NSOpenPanel class]]) {
        saveOpen = @"Open";
    } else {
        saveOpen = @"Save as";
    }
    
    [panel setExtensionHidden: 
        [[[NSUserDefaults standardUserDefaults] objectForKey: 
            @"ZoomHiddenExtension"] boolValue]];
    
    switch (type) {
        default:
        case ZFileQuetzal:
            [panel setRequiredFileType: @"qut"];
            typeCode = 'IFZS';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ savegame (quetzal) file", saveOpen]];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"qut", nil]];
            }
            break;
            
        case ZFileData:
            [panel setRequiredFileType: @"dat"];
            typeCode = '\?\?\?\?';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ data file", saveOpen]];
                
                // (Assume if setMessage is supported, we have 10.3)
                [panel setAllowsOtherFileTypes: YES];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"dat", @"qut", nil]];
            }
            break;
            
        case ZFileRecording:
            [panel setRequiredFileType: @"txt"];
            typeCode = 'TEXT';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ command recording file", saveOpen]];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"txt", nil]];
            }
            break;
            
        case ZFileTranscript:
            [panel setRequiredFileType:  [NSString stringWithFormat: @"txt"]];
            typeCode = 'TEXT';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ transcript recording file", saveOpen]];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"txt", nil]];
            }
            break;
    }
}

- (void) storePanelPrefs: (NSSavePanel*) panel {
    [[NSUserDefaults standardUserDefaults] setObject: [panel directory]
                                              forKey: @"ZoomSavePath"];
    [[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool: [panel isExtensionHidden]]
                                              forKey: @"ZoomHiddenExtension"];
}

- (long) creatorCode {
    return creatorCode;
}

- (void) setCreatorCode: (long) code {
    creatorCode = code;
}

- (void) promptForFileToWrite: (ZFileType) type
                  defaultName: (NSString*) name {
    NSSavePanel* panel = [NSSavePanel savePanel];
    
    [self setupPanel: panel
                type: type];
    
    [panel beginSheetForDirectory: [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomSavePath"]
                             file: nil
                   modalForWindow: [self window]
                    modalDelegate: self
                   didEndSelector: @selector(savePanelDidEnd:returnCode:contextInfo:) 
                      contextInfo: nil];
}

- (void)savePanelDidEnd: (NSSavePanel *) panel 
             returnCode: (int) returnCode 
            contextInfo: (void*) contextInfo {
    if (returnCode != NSOKButton) {
        [zMachine filePromptCancelled];
    } else {
        NSString* fn = [panel filename];
        NSFileHandle* file = nil;
        
        [self storePanelPrefs: panel];
        
        if ([[NSFileManager defaultManager] createFileAtPath:fn
                                                        contents:[NSData data]
                                                      attributes:
            [NSDictionary dictionaryWithObjectsAndKeys: 
                [NSNumber numberWithLong: creatorCode], NSFileHFSCreatorCode,
                [NSNumber numberWithLong: typeCode], NSFileHFSTypeCode,
                [NSNumber numberWithBool: [panel isExtensionHidden]], NSFileExtensionHidden,
                nil]]) {
            file = [NSFileHandle fileHandleForWritingAtPath: fn];
        }
        
        if (file) {
            ZHandleFile* f;
            
            f = [[ZHandleFile alloc] initWithFileHandle: file];
            
            [zMachine promptedFileIs: [f autorelease]
                                size: 0];
        } else {
            [zMachine filePromptCancelled];
        }
    }
}

- (void) promptForFileToRead: (ZFileType) type
                 defaultName: (NSString*) name {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    
    [self setupPanel: panel
                type: type];
    
    [panel beginSheetForDirectory: [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomSavePath"]
                             file: nil
                   modalForWindow: [self window]
                    modalDelegate: self
                   didEndSelector: @selector(openPanelDidEnd:returnCode:contextInfo:) 
                      contextInfo: nil];
}

- (void)openPanelDidEnd: (NSOpenPanel *) panel 
             returnCode: (int) returnCode 
            contextInfo: (void*) contextInfo {
    if (returnCode != NSOKButton) {
        [zMachine filePromptCancelled];
    } else {
        NSString* fn = [panel filename];
        NSFileHandle* file = nil;

        [self storePanelPrefs: panel];

        file = [NSFileHandle fileHandleForReadingAtPath: fn];
        
        if (file) {
            ZDataFile* f;
            NSData* fData = [file readDataToEndOfFile];
            
            f = [[ZDataFile alloc] initWithData: fData];
            
            [zMachine promptedFileIs: [f autorelease]
                                size: [fData length]];
        } else {
            [zMachine filePromptCancelled];
        }
    }
}

// = The delegate =
- (void) setDelegate: (id) dg {
    // (Not retained)
    delegate = dg;
}

- (id) delegate {
    return delegate;
}

- (void) killTask {
    if (zoomTask) [zoomTask terminate];
}

// = Warnings/errors =
- (void) displayWarning: (NSString*) warning {
	// FIXME
	NSString* warningString;
	
	warningString = [NSString stringWithFormat: @"[ Warning: %@ ]", warning];
	
	if ([viewPrefs fatalWarnings]) {
		[self displayFatalError: warningString];
		return;
	}
	
	if ([viewPrefs displayWarnings]) {
		if ([lowerWindows count] <= 0) {
			NSBeginInformationalAlertSheet(@"Warning", @"OK", nil, nil, [self window], nil, nil, nil, NULL, @"%@", warning);
			return;
		}
		
		ZStyle* warningStyle = [[ZStyle alloc] init];
		[warningStyle setBackgroundColour: 4];
		[warningStyle setForegroundColour: 7];
		[warningStyle setBold: NO];
		[warningStyle setFixed: NO];
		[warningStyle setSymbolic: NO];
		[warningStyle setUnderline: YES];
		
		[[lowerWindows objectAtIndex: 0] writeString: warningString
										   withStyle: warningStyle];
	}
	//NSBeginAlertSheet(@"Warning", @"OK", nil, nil, [self window], nil, nil, nil, NULL, @"%@", warning);
	//NSLog(@"Warning: %@", warning);
}

- (void) displayFatalError: (NSString*) error {
	NSBeginCriticalAlertSheet(@"Fatal error", @"Stop", nil, nil, [self window], nil, nil, nil, NULL, @"%@", error);
}

// = Setting/updating preferences =
- (void) setPreferences: (ZoomPreferences*) prefs {
	[[NSNotificationCenter defaultCenter] removeObserver: self
													name: ZoomPreferencesHaveChangedNotification
												  object: viewPrefs];
	[viewPrefs release];
	
	viewPrefs = [prefs retain];
	
	[self preferencesHaveChanged: [NSNotification notificationWithName: ZoomPreferencesHaveChangedNotification
																object: viewPrefs]];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(preferencesHaveChanged:)
												 name: ZoomPreferencesHaveChangedNotification
											   object: viewPrefs];
}

- (void) preferencesHaveChanged: (NSNotification*)not {
	// Usually called by the notification manager
	if ([not object] != viewPrefs) {
		NSLog(@"(BUG?) notification recieved for preferences that do not belong to us");
		return;
	}
	
	// Update fonts, colours according to specification
	[fonts release];
	[colours release];
	
	fonts = [[viewPrefs fonts] retain];
	colours = [[viewPrefs colours] retain];
	
	[self reformatWindow];
}

- (void) reformatWindow {
	// Reformats the entire window according to currently set fonts/colours
	NSMutableAttributedString* storage = [textView textStorage];
	NSRange attributedRange;
	NSDictionary* attr;
	int len = [storage length];
	
	attributedRange.location = 0;
	
	while (attributedRange.location < len) {
		attr = [storage attributesAtIndex: attributedRange.location
						   effectiveRange: &attributedRange];

		if (attributedRange.location == NSNotFound) break;
		if (attributedRange.length == 0) break;
		
		// Re-apply the style associated with this block of text
		ZStyle* sty = [attr objectForKey: ZoomStyleAttributeName];
		
		if (sty) {
			NSDictionary* newAttr = [self attributesForStyle: sty];
			
			[storage setAttributes: newAttr
							 range: attributedRange];
		}
		
		attributedRange.location += attributedRange.length;
	}
	
	// Reset the background colour of the lower window
	[textView setBackgroundColor: [self backgroundColourForStyle: [[lowerWindows objectAtIndex: 0] backgroundStyle]]];
	
	// Reformat the upper window(s) as necessary
	[textScroller tile];
	
	NSEnumerator* upperWindowEnum = [upperWindows objectEnumerator];
	ZoomUpperWindow* upperWin;
	
	while (upperWin = [upperWindowEnum nextObject]) {
		[upperWin reformatLines];
	}
	
	[textScroller updateUpperWindows];
}

@end
