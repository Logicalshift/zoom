//
//  ZoomView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <signal.h>

#import "ZoomView.h"
#import "ZoomLowerWindow.h"
#import "ZoomUpperWindow.h"
#import "ZoomPixmapWindow.h"

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
		
		// Output receivers
		outputReceivers = nil;
		
		// Input source
		inputSource = nil;

        // No upper/lower windows
        upperWindows = [[NSMutableArray allocWithZone: [self zone]] init];
        lowerWindows = [[NSMutableArray allocWithZone: [self zone]] init];

        // No Zmachine/task to start with
        zMachine = nil;
        zoomTask = nil;
        delegate = nil;

        // Yep, we autoresize our subviews
        [self setAutoresizesSubviews: YES];
		
		// Autosave
		lastAutosave = nil;
		upperWindowsToRestore = 0;

		// Default scale factor
		scaleFactor = 1.0;
        
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
		
		// Command history
		commandHistory = [[NSMutableArray alloc] init];
		historyPos     = 0;
		
		// Resources
		resources = nil;
		
		// Terminating characters
		terminatingChars = nil;
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
	
	if (pixmapWindow) {
		[pixmapCursor setDelegate: nil];
		[pixmapCursor release];
		[pixmapWindow release];
	}

    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [textScroller release];
    [textView release];
    [moreView release];
    [fonts release];
    [colours release];
    [upperWindowBuffer release];
	[viewPrefs release];
	[commandHistory release];
	[outputReceivers release];
	if (lastAutosave) [lastAutosave release];
	
	if (inputLine) [inputLine release];
	
	if (inputSource) [inputSource release];
	
	if (resources) [resources release];
	
	if (terminatingChars) [terminatingChars release];

    [super dealloc];
}

// Drawing
- (void) drawRect: (NSRect) rect {
	if (pixmapWindow != nil) {
		NSRect bounds = [self bounds];
		NSImage* pixmap = [pixmapWindow pixmap];
		NSSize pixSize = [pixmap size];
		
		/*
		[pixmap drawAtPoint: NSMakePoint(floor(bounds.origin.x + (bounds.size.width-pixSize.width)/2.0), floor(bounds.origin.y + (bounds.size.height-pixSize.height)/2.0))
				   fromRect: NSMakeRect(0,0,pixSize.width, pixSize.height)
				  operation: NSCompositeSourceOver
				   fraction: 1.0];
		 */
				
		bounds.origin.y += bounds.size.height;
		bounds.size.height = -bounds.size.height;

		[pixmap drawInRect: bounds
				  fromRect: NSMakeRect(0,0,pixSize.width, pixSize.height)
				 operation: NSCompositeSourceOver
				  fraction: 1.0];
		
		[pixmapCursor draw];
		
		if (inputLine) {
			[inputLine drawAtPoint: inputLinePos];
		}
	}
}

- (BOOL) isFlipped {
	return YES;
}

// Scaling
- (void) setScaleFactor: (float) scaling {
	scaleFactor = scaling;
	[textScroller setScaleFactor: scaling];
		
	NSRect tVF = [textView frame];
	NSRect tVB = tVF;
	tVB.origin.x = tVB.origin.y = 0;
	tVB.size.width *= scaling;
	tVB.size.height *= scaling;
	
	[textView setBounds: tVB];
	
	if (zMachine) {
		[zMachine displaySizeHasChanged];
	}
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
	// Can only have one lower window
	if ([lowerWindows count] > 0) return [lowerWindows objectAtIndex: 0];
	
    ZoomLowerWindow* win = [[ZoomLowerWindow allocWithZone: [self zone]]
        initWithZoomView: self];

    [lowerWindows addObject: win];

    [win clearWithStyle: [[[ZStyle alloc] init] autorelease]];
    return [win autorelease];
}

- (out byref NSObject<ZUpperWindow>*) createUpperWindow {
	if (upperWindowsToRestore > 0) {
		// Restoring upper windows from autosave
		upperWindowsToRestore--;
		return [upperWindows objectAtIndex: [upperWindows count] - (upperWindowsToRestore+1)];
	}
	
	// Otherwise, create a brand new upper window
    ZoomUpperWindow* win = [[ZoomUpperWindow allocWithZone: [self zone]]
        initWithZoomView: self];

    [upperWindows addObject: win];

    [win clearWithStyle: [[[ZStyle alloc] init] autorelease]];
    return [win autorelease];
}

- (out byref NSObject<ZPixmapWindow>*) createPixmapWindow {
	if (pixmapWindow == nil) {
		pixmapWindow = [[ZoomPixmapWindow alloc] initWithZoomView: self];

		pixmapCursor = [[ZoomCursor alloc] init];
		[pixmapCursor setDelegate: self];
		
		// FIXME: test of the cursor
		[pixmapCursor positionAt: NSMakePoint(100, 100)
						withFont: [self fontWithStyle: 0]];
		[pixmapCursor setShown: NO];
		[pixmapCursor setBlinking: YES];
		[pixmapCursor setActive: YES];
	}
	
	[textScroller removeFromSuperview];
	
	if (delegate != nil && [delegate respondsToSelector: @selector(zoomViewIsNotResizable)]) {
		[delegate zoomViewIsNotResizable];
	}
	
	return pixmapWindow;
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
	if (lastAutosave) [lastAutosave release];
	lastAutosave = [[zMachine createGameSave] retain];
	
	if (pixmapWindow == nil) {
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
		
		if ([focusedView isKindOfClass: [ZoomUpperWindow class]]) {
			[[textScroller upperWindowView] setFlashCursor: YES]; 
		}
		
		// If the more prompt is off, then set up for editing
		if (!moreOn) {
			[self resetMorePrompt];
			[self scrollToEnd];
		}
	}
    
    receivingCharacters = YES;
	[self orWaitingForInput];
	
	// Position the cursor
	if (pixmapWindow != nil) {
		ZStyle* style = [pixmapWindow inputStyle];
		int fontnum =
			([style bold]?1:0)|
			([style underline]?2:0)|
			([style fixed]?4:0)|
			([style symbolic]?8:0);
		
		[pixmapCursor positionAt: [pixmapWindow inputPos]
						withFont: [self fontWithStyle: fontnum]];
		
		[pixmapCursor setShown: !moreOn];
	}
	
	// Become the first responder
	if (pixmapWindow != nil) {
		[[self window] makeFirstResponder: self];
	} else if ([focusedView isKindOfClass: [ZoomUpperWindow class]]) {
		[[self window] makeFirstResponder: [textScroller upperWindowView]];
	} else {
		[[self window] makeFirstResponder: textView];
	}
	
	// Deal with the input source
	if (inputSource != nil && [inputSource respondsToSelector: @selector(nextCommand)]) {
		NSString* nextInput = [inputSource nextCommand];
		
		if (nextInput == nil) {
			// End of input
			[inputSource release];
			inputSource = nil;
		} else {			
			if ([nextInput length] == 0) nextInput = @"\n";
			
			// We've got some input: perform it
			[self stopReceiving];
			
			[zMachine inputText: nextInput];
			[self orInputCharacter: nextInput];
		}
	}	
}

- (void) shouldReceiveText: (int) maxLength {
	if (lastAutosave) [lastAutosave release];
	lastAutosave = [[zMachine createGameSave] retain];

	if (pixmapWindow == nil) {
		// == Version 1-5/7/8 routines ==
		[self rearrangeUpperWindows];
		
		int currentSize = [self upperWindowSize];
		if (currentSize != lastTileSize) {
			[textScroller tile];
			[self updateMorePrompt];
			lastTileSize = currentSize;
		}
	
		historyPos = [commandHistory count];

		// Paste stuff
		NSEnumerator* upperEnum = [upperWindows objectEnumerator];
		ZoomUpperWindow* win;
		while (win = [upperEnum nextObject]) {
			[textView pasteUpperWindowLinesFrom: win];
		}
    
		// If the more prompt is off, then set up for editing
		if (!moreOn) {
			[textView setEditable: YES];

			[self resetMorePrompt];
			[self scrollToEnd];
		}

		inputPos = [[textView textStorage] length];
	} else {
		// == Version 6 pixmap entry routines ==
		
		// Move the cursor to the appropriate position
		ZStyle* style = [pixmapWindow inputStyle];
		int fontnum =
			([style bold]?1:0)|
			([style underline]?2:0)|
			([style fixed]?4:0)|
			([style symbolic]?8:0);
		
		[pixmapCursor positionAt: [pixmapWindow inputPos]
						withFont: [self fontWithStyle: fontnum]];

		// Display the cursor
		[pixmapCursor setShown: YES];
		
		// Setup the command history
		historyPos = [commandHistory count];
		
		// Setup the input line
		[self setInputLinePos: [pixmapWindow inputPos]];
		[self setInputLine: [[[ZoomInputLine alloc] initWithCursor: pixmapCursor
														attributes: [self attributesForStyle: [pixmapWindow inputStyle]]]
			autorelease]];
	}
	
	// Set the first responder appropriately
	if (pixmapWindow != nil) {
		[[self window] makeFirstResponder: self];
	} else if ([focusedView isKindOfClass: [ZoomUpperWindow class]]) {
		[[self window] makeFirstResponder: [textScroller upperWindowView]];
	} else {
		[[self window] makeFirstResponder: textView];
		[textView scrollRangeToVisible: NSMakeRange([[textView string] length], 0)];
		[textView setSelectedRange: NSMakeRange([[textView string] length], 0)];
	}	
	
    receiving = YES;
	[self orWaitingForInput];
	
	// Dealing with the input source
	if (inputSource != nil && [inputSource respondsToSelector: @selector(nextCommand)]) {
		NSString* nextInput = [inputSource nextCommand];
		
		if (nextInput == nil) {
			// End of input
			[inputSource release];
			inputSource = nil;
		} else {
			nextInput = [nextInput stringByAppendingString: @"\n"];
			
			// We've got some input: write it, perform it
			[self stopReceiving];
			
			// FIXME: maybe do this in the current style? (At least this way, it's obvious what's come from where)
			ZStyle* inputStyle = [[[ZStyle alloc] init] autorelease];
			[inputStyle setUnderline: YES];
			[inputStyle setBold: YES];
			[inputStyle setBackgroundColour: 7];
			[inputStyle setForegroundColour: 4];
			
			[focusedView writeString: nextInput
						   withStyle: inputStyle];
			
			[commandHistory addObject: nextInput];
			
			[zMachine inputText: nextInput];
			[self orInputCommand: nextInput];
		}
	}
}

- (void) stopReceiving {
    receiving = NO;
    receivingCharacters = NO;
    [textView setEditable: NO];
	[[textScroller upperWindowView] setFlashCursor: NO]; 
}

- (void) dimensionX: (out int*) xSize
                  Y: (out int*) ySize {
    NSSize fixedSize = [@"M" sizeWithAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [self fontWithStyle:ZFixedStyle], NSFontAttributeName, nil]];
    NSRect ourBounds = NSMakeRect(0,0,0,0);
	
	if (pixmapWindow == nil)
		ourBounds = [textView bounds];
	else
		ourBounds.size = [[pixmapWindow pixmap] size];

    *xSize = floor(ourBounds.size.width  / fixedSize.width);
    *ySize = floor(ourBounds.size.height / fixedSize.height);
}

- (void) pixmapX: (out int*) xSize
			   Y: (out int*) ySize {
	if (pixmapWindow == nil) {
		[self dimensionX: xSize Y: ySize];
	} else {
		NSSize pixSize = [[pixmapWindow pixmap] size];
		
		*xSize = pixSize.width;
		*ySize = pixSize.height;
	}
}

- (void) fontWidth: (out int*) width
			height: (out int*) height {
	if (pixmapWindow == nil) {
		*width = 1;
		*height = 1;
	} else {
		NSFont* font = [self fontWithStyle: ZFixedStyle];
	
		*width = [font widthOfString: @"M"];
		*height = ceilf([font defaultLineHeightForFont])+1.0;
	}
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
	NSRect frame = [textView convertRect: [[textScroller contentView] frame]
								fromView: textScroller];

    [textView scrollPoint: NSMakePoint(0,
									   NSMaxY(endRect) - frame.size.height)];
}

- (void) displayMore: (BOOL) shown {
	moreOn = shown;
	[self setShowsMorePrompt: moreOn];
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
	if (pixmapWindow) return; // Nothing to do
	
    // Updates the more prompt to represent the new height of the window
	NSSize contentSize = [textScroller contentSize];
	contentSize = [textView convertSize: contentSize
							   fromView: textScroller];
	
    double maxHeight = moreReferencePoint + contentSize.height;

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
        NSRect content = [textView bounds];
		if (pixmapWindow) content = [self bounds];
        
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
		
		if (pixmapWindow) {
			[self addSubview: moreView];
		} else {
			[textView addSubview: moreView];
		}
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
			NSString* inputText = [str substringWithRange: NSMakeRange(inputPos,
																	   newlinePos-inputPos+1)];
			
			[commandHistory addObject: [str substringWithRange: NSMakeRange(inputPos,
																			newlinePos-inputPos)]];
            [zMachine inputText: inputText];
			[self orInputCommand: inputText];

            inputPos = newlinePos + 1;
        }
    } while (newlinePos >= 0);
}

// = Event methods =

- (BOOL)handleKeyDown:(NSEvent *)theEvent {
    if (moreOn && pixmapWindow==nil) {
        // FIXME: maybe only respond to certain keys
        [self page];
        return YES;
    }
	
	if (receiving && terminatingChars != nil) {
		// Deal with terminating characters
		NSString* chars = [theEvent characters];
		unichar chr = [chars characterAtIndex: 0];
		NSNumber* recv = [NSNumber numberWithInt: chr];
		
		BOOL canTerminate = YES;
		if (chr == 252 || chr == 253 || chr == 254) {
			// Mouse characters
			canTerminate = NO;
		}
		
		if (chr == NSUpArrowFunctionKey   ||
			chr == NSDownArrowFunctionKey ||
			chr == NSLeftArrowFunctionKey ||
			chr == NSRightArrowFunctionKey) {
			canTerminate = ([theEvent modifierFlags]&NSAlternateKeyMask)==1 && ([theEvent modifierFlags]&NSCommandKeyMask)==0;
		}
		
		if (canTerminate && [terminatingChars containsObject: recv]) {
			// Set the terminating character
			[zMachine inputTerminatedWithCharacter: [recv intValue]];
			
			// Send the input text
			NSString* str = [textView string];
			NSString* inputText = [str substringWithRange: NSMakeRange(inputPos,
																	   [str length]-inputPos)];
			inputPos = [str length];
			
			[zMachine inputText: inputText];
						
			return YES;
		}
	}
	
	if (inputLine) {
		[inputLine keyDown: theEvent];
		return YES;
	}
    
    if (receivingCharacters) {
        NSString* chars = [theEvent characters];
        
        [zMachine inputText: chars];
		[self orInputCharacter: chars];
        
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
		
		// Up and down arrow keys have a different meaning if the cursor is beyond the
		// end inputPos.
		// (Arrow keys won't be caught above thanks to the NSFunctionKeyMask)
		unsigned cursorPos = [textView selectedRange].location;
		
		if (modifiers == NSFunctionKeyMask) {
			int key = [chars characterAtIndex: 0];
			
			if (cursorPos >= inputPos && (key == NSUpArrowFunctionKey || key == NSDownArrowFunctionKey)) {
				// Move historyPos
				int oldPos = historyPos;
				
				if (key == NSUpArrowFunctionKey) historyPos--;
				if (key == NSDownArrowFunctionKey) historyPos++;
				
				if (historyPos < 0) historyPos = 0;
				if (historyPos > [commandHistory count]) historyPos = [commandHistory count];
				
				if (historyPos == oldPos) return YES;
				
				// Clear the input
				[[textView textStorage] deleteCharactersInRange: NSMakeRange(inputPos,
																			 [[textView textStorage] length] - inputPos)];
				
				// Put in the new string
				if (historyPos < [commandHistory count]) {
					[[[textView textStorage] mutableString] insertString: [commandHistory objectAtIndex: historyPos]
																 atIndex: inputPos];
				}
				
				// Move to the end
				[textView setSelectedRange: NSMakeRange([[textView textStorage] length], 0)];
				
				// Done
				return YES;
			}
		}
    }

    return NO;
}

- (void) keyDown: (NSEvent*) event {
	[self handleKeyDown: event];
}

- (void) mouseUp: (NSEvent*) event {
	[self clickAtPointInWindow: [event locationInWindow]
					 withCount: [event clickCount]];
	
	[super mouseUp: event];
}

- (void) clickAtPointInWindow: (NSPoint) windowPos
					withCount: (int) count {
	// Note that clicking can only be accurate in the 'upper' window
	// We'll have problems if the lower window is scrolled, too.
	NSPoint pointInView = [self convertPoint: windowPos
									fromView: nil];
	
	if (pixmapWindow != nil) {
		// Point is in X,Y coordinates
		[zMachine inputMouseAtPositionX: pointInView.x
									  Y: pointInView.y];
	} else {
		// Point is in character coordinates
		NSDictionary* fixedAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
            [self fontWithStyle:ZFixedStyle], NSFontAttributeName, nil];
        NSSize fixedSize = [@"M" sizeWithAttributes: fixedAttributes];
		
		int charX = floorf(pointInView.x / fixedSize.width);
		int charY = floorf(pointInView.y / fixedSize.height);
		
		// Report the position to the remote server
		[zMachine inputMouseAtPositionX: charX+1
									  Y: charY+1];
	}
	
	// Send the appropriate 'mouse down' character to the remote system
	// We use NSF34/NSF35 as 'pretend' mouse down characters
	unichar clickChar = NSF34FunctionKey;
	
	if (count == 2) clickChar = NSF35FunctionKey;
	
	NSEvent* fakeKeyDownEvent = [NSEvent keyEventWithType: NSKeyDown
												 location: NSMakePoint(0,0)
											modifierFlags: 0
												timestamp: 0
											 windowNumber: [[self window] windowNumber]
												  context: nil
											   characters: [NSString stringWithCharacters: &clickChar length: 1]
							  charactersIgnoringModifiers: [NSString stringWithCharacters: &clickChar length: 1]
												isARepeat: NO
												  keyCode: 0];
	[self handleKeyDown: fakeKeyDownEvent];
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
	
	// The foreground colour must have 100% alpha
	foregroundColour = [NSColor colorWithDeviceRed: [foregroundColour redComponent]
											 green: [foregroundColour greenComponent]
											  blue: [foregroundColour blueComponent]
											 alpha: 1.0];
	
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
	
	// The foreground colour must have 100% alpha
	foregroundColour = [NSColor colorWithDeviceRed: [foregroundColour redComponent]
											 green: [foregroundColour greenComponent]
											  blue: [foregroundColour blueComponent]
											 alpha: 1.0];
	
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
	// FIXME: better to do this with preferences now, but Inform still uses these calls
    
    [fonts release];
    fonts = [[NSArray allocWithZone: [self zone]] initWithArray: newFonts 
                                                      copyItems: YES];
	
	[self reformatWindow];
}

- (void) setColours: (NSArray*) newColours {
    [colours release];
    colours = [[NSArray allocWithZone: [self zone]] initWithArray: newColours
                                                        copyItems: YES];
	
	[self reformatWindow];
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
	
	// The foreground colour must have 100% alpha
	res = [NSColor colorWithDeviceRed: [res redComponent]
								green: [res greenComponent]
								 blue: [res blueComponent]
								alpha: 1.0];	
    
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
    [upperWindowBuffer setContainerSize: NSMakeSize(contentSize.width*scaleFactor, bufHeight)];
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

            if (NSMinY(endRect) < sepHeight) {
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
	// Kill off any previously running machine
    if (zMachine != nil) {
        [zMachine release];
        zMachine = nil;
	}
    
    if (zoomTask != nil) {
		NSTask* oldTask = zoomTask;
		
        zoomTask = nil; // Changes tidy up behaviour
		
        [oldTask terminate];
        [oldTask release];
    }

    if (zoomTaskStdout != nil) {
        [zoomTaskStdout release];
        zoomTaskStdout = nil;
    }

    if (zoomTaskData != nil) {
        [zoomTaskData release];
        zoomTaskData = nil;
    }
	
	// Reset the display
	if (pixmapCursor) [pixmapCursor release];
	pixmapCursor = nil;
	if (pixmapWindow) [pixmapWindow release];
	pixmapWindow = nil;
	focusedView = nil;
	
	[textView setString: @""];
	
	[upperWindows release];
	[lowerWindows release];
	upperWindows = [[NSMutableArray alloc] init];
	lowerWindows = [[NSMutableArray alloc] init];
	
	receiving = NO;
	receivingCharacters = NO;
	moreOn = NO;
	
	[self orInterpreterRestart];
	[self rearrangeUpperWindows];

	// Start a new machine
    zoomTask = [[NSTask allocWithZone: [self zone]] init];
    zoomTaskData = [[NSMutableString allocWithZone: [self zone]] init];

    if (serverName == nil) {
        serverName = [[NSBundle mainBundle] pathForResource: @"ZoomServer"
                                                     ofType: nil];
    }
	
	if (serverName == nil) {
		serverName = [[NSBundle bundleForClass: [self class]] pathForResource: @"ZoomServer"
																	   ofType: nil];
	}

    // Prepare for launch
    [zoomTask setLaunchPath: serverName];
    
    zoomTaskStdout = [[NSPipe allocWithZone: [self zone]] init];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(zoomTaskNotification:)
                                                 name: NSFileHandleDataAvailableNotification
                                               object: [zoomTaskStdout fileHandleForReading]];
    [[zoomTaskStdout fileHandleForReading] waitForDataInBackgroundAndNotify];

    [zoomTask setStandardOutput: zoomTaskStdout];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(zoomTaskFinished:)
                                                 name: NSTaskDidTerminateNotification
                                               object: zoomTask];
    
    // Light the blue touch paper
    [zoomTask launch];

	//    \||/
    // ***FOOM***
}//        ||
//		   ||
//		   ||
//		   ||
//		  \||/
//         \/
//	     (phut)
- (void) zoomTaskFinished: (NSNotification*) not {
	if ([not object] != zoomTask) return; // Not our task
	
    // The task has finished
    if (zMachine) {
        [zMachine release];
        zMachine = nil;
    }
	
	if (receiving || receivingCharacters) [self stopReceiving];
	
    // Notify the user (display a message)
    ZStyle* notifyStyle = [[ZStyle allocWithZone: [self zone]] init];
    ZStyle* standardStyle = [[ZStyle allocWithZone: [self zone]] init];
    [notifyStyle setForegroundColour: 7];
    [notifyStyle setBackgroundColour: 1];

    NSString* finishString = @"[ The game has finished ]";
    if ([zoomTask terminationStatus] != 0) {
        finishString = @"[ The Zoom interpreter has quit unexpectedly ]";
    } else {
		if (lastAutosave != nil) {
			[lastAutosave release];
			lastAutosave = nil;
		}
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
	
	[self scrollToEnd];

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
	
	// Cursor is not blinking any more
	if (pixmapCursor) {
		[pixmapCursor setBlinking: NO];
		[pixmapCursor setShown: NO];
		[pixmapCursor setActive: NO];
	}

	// Free things up
    [zoomTask release];
    [zoomTaskStdout release];
    [zoomTaskData release];

    zoomTask = nil;
    zoomTaskStdout = nil;
    zoomTaskData = nil;
}

- (BOOL) isRunning {
	return zMachine != nil;
}

- (void) zoomTaskNotification: (NSNotification*) not {
	if ([not object] != [zoomTaskStdout fileHandleForReading]) return;
	
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

- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename {
	NSSavePanel* panel = sender;
	
	if ([[filename pathExtension] isEqualToString: [panel requiredFileType]]) return YES;
	
	if ([[panel requiredFileType] isEqualToString: @"zoomSave"]) {
		if ([[filename pathExtension] isEqualToString: @"qut"]) {
			return YES;
		}
	}
	
	BOOL isDir;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath: filename isDirectory: &isDir]) {
		if (isDir) return YES;
	}
	
	return NO;
}

- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename {
	NSSavePanel* panel = sender;
	
	if ([[filename pathExtension] isEqualToString: [panel requiredFileType]]) return YES;
	
	if ([[panel requiredFileType] isEqualToString: @"zoomSave"]) {
		if ([[filename pathExtension] isEqualToString: @"qut"]) {
			return YES;
		}
	}
	
	return NO;
}

// = Prompting for files =
- (void) setupPanel: (NSSavePanel*) panel
               type: (ZFileType) type {
    BOOL supportsMessage = [panel respondsToSelector: @selector(setMessage:)];
    [panel setCanSelectHiddenExtension: YES];
	[panel setDelegate: self];
    
    NSString* saveOpen = @"Save as";
    
    if ([panel isKindOfClass: [NSOpenPanel class]]) {
        saveOpen = @"Open";
    } else {
        saveOpen = @"Save as";
    }
    
    [panel setExtensionHidden: 
        [[[NSUserDefaults standardUserDefaults] objectForKey: 
            @"ZoomHiddenExtension"] boolValue]];
	
	BOOL usePackage = NO;
	
	if (type == ZFileQuetzal && delegate && [delegate respondsToSelector: @selector(useSavePackage)]) {
		usePackage = [delegate useSavePackage];
	}
		
    switch (type) {
        default:
        case ZFileQuetzal:
			if (usePackage) {
				[panel setRequiredFileType: @"zoomSave"];
			} else {
				[panel setRequiredFileType: @"qut"];
			}
            typeCode = 'IFZS';
            if (supportsMessage) {
                [panel setMessage: [NSString stringWithFormat: @"%@ savegame (quetzal) file", saveOpen]];
                [panel setAllowedFileTypes: [NSArray arrayWithObjects: usePackage?@"zoomSave":@"qut", nil]];
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
	
	NSString* directory = nil;
	
	if (delegate && [delegate respondsToSelector: @selector(defaultSaveDirectory)]) {
		directory = [delegate defaultSaveDirectory];
	}
	
	if (directory == nil) {
		directory = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomSavePath"];
	}
    
    [panel beginSheetForDirectory: directory
                             file: nil
                   modalForWindow: [self window]
                    modalDelegate: self
                   didEndSelector: @selector(savePanelDidEnd:returnCode:contextInfo:) 
                      contextInfo: [[NSNumber numberWithInt: type] retain]];
}

- (void)savePanelDidEnd: (NSSavePanel *) panel 
             returnCode: (int) returnCode 
            contextInfo: (void*) contextInfo {
	NSNumber* typeNum = [(NSNumber*)contextInfo autorelease];
	ZFileType type = [typeNum intValue];
	
    if (returnCode != NSOKButton) {
        [zMachine filePromptCancelled];
    } else {
        NSString* fn = [panel filename];
        NSFileHandle* file = nil;
		
		BOOL usePackage = NO;
        
        [self storePanelPrefs: panel];
		
		if (type == ZFileQuetzal && delegate && [delegate respondsToSelector: @selector(useSavePackage)]) {
			usePackage = [delegate useSavePackage];
		}
        
		if (usePackage) {
			// We store information about the current screen state in the package
			ZPackageFile* f = [[ZPackageFile alloc] initWithPath: fn
													 defaultFile: @"save.qut"
													  forWriting: YES];
			
			if (f) {
				int windowNumber = 0;
				
				[f setAttributes: [NSDictionary dictionaryWithObjectsAndKeys: 
					[NSNumber numberWithLong: creatorCode], NSFileHFSCreatorCode,
					[NSNumber numberWithLong: typeCode], NSFileHFSTypeCode,
					[NSNumber numberWithBool: [panel isExtensionHidden]], NSFileExtensionHidden,
					nil]];
				
				if ([(ZoomUpperWindow*)[upperWindows objectAtIndex: 0] length] > 0) {
					windowNumber = 0;
				} else {
					windowNumber = 1;
				}
				
				[f addData: [NSArchiver archivedDataWithRootObject: [upperWindows objectAtIndex: windowNumber]]
			   forFilename: @"ZoomPreview.dat"];
				[f addData: [NSArchiver archivedDataWithRootObject: self]
			   forFilename: @"ZoomStatus.dat"];
				
				if (delegate && [delegate respondsToSelector: @selector(prepareSavePackage:)]) {
					[delegate prepareSavePackage: f];
				}
				
				[zMachine promptedFileIs: [f autorelease]
									size: 0];
			} else {
				[zMachine filePromptCancelled];				
			}
		} else {
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
		
		if ([[fn pathExtension] isEqualToString: @"zoomSave"]) {
			ZPackageFile* f;
			
			f = [[ZPackageFile alloc] initWithPath: fn
									   defaultFile: @"save.qut"
										forWriting: NO];
			
			if (f) {
				[zMachine promptedFileIs: [f autorelease]
									size: [f fileSize]];
			} else {
				[zMachine filePromptCancelled];
			}
		} else {
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

- (void) debugTask {
	if (zoomTask) kill([zoomTask processIdentifier], SIGUSR1);
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
	if ([lowerWindows count] > 0) {
		[textView setBackgroundColor: [self backgroundColourForStyle: [[lowerWindows objectAtIndex: 0] backgroundStyle]]];
	}
	
	// Reformat the upper window(s) as necessary
	[textScroller tile];
	
	NSEnumerator* upperWindowEnum = [upperWindows objectEnumerator];
	ZoomUpperWindow* upperWin;
	
	while (upperWin = [upperWindowEnum nextObject]) {
		[upperWin reformatLines];
	}
	
	[textScroller updateUpperWindows];
}

- (void) retileUpperWindowIfRequired {
    int currentSize = [self upperWindowSize];
    if (currentSize != lastTileSize) {
        [textScroller tile];
        [self updateMorePrompt];
        lastTileSize = currentSize;
    }
}

// = Autosave =

- (BOOL) createAutosaveDataWithCoder: (NSCoder*) encoder {
	if (lastAutosave == nil) return NO;
	
	int autosaveVersion = 100;
	
	[encoder encodeValueOfObjCType: @encode(int) 
								at: &autosaveVersion];
	
	[encoder encodeObject: lastAutosave];
	
	[encoder encodeObject: upperWindows];
	[encoder encodeObject: lowerWindows];
	
	// The rest of the view state
	[encoder encodeObject: [textView textStorage]];
	[encoder encodeObject: commandHistory];
	
	// All we need, I think
	
	// Done
	return YES;
}

- (void) restoreAutosaveFromCoder: (NSCoder*) decoder {
	int autosaveVersion;
	
	[decoder decodeValueOfObjCType: @encode(int)
								at: &autosaveVersion];
	
	if (autosaveVersion == 100) {
		if (lastAutosave) [lastAutosave release];
		if (upperWindows) [upperWindows release];
		if (lowerWindows) [lowerWindows release];
		if (commandHistory) [commandHistory release];

		lastAutosave = [[decoder decodeObject] retain];
		upperWindows = [[decoder decodeObject] retain];
		lowerWindows = [[decoder decodeObject] retain];
		
		NSTextStorage* storage = [decoder decodeObject];
		
		[[textView textStorage] setAttributedString: storage];
		
		commandHistory = [[decoder decodeObject] retain];
		
		// Final setup
		upperWindowsToRestore = [upperWindows count];
		
		[upperWindows makeObjectsPerformSelector: @selector(setZoomView:)
									  withObject: self];
		[lowerWindows makeObjectsPerformSelector: @selector(setZoomView:)
									  withObject: self];
		
		// Load the state into the z-machine
		if (zMachine) {
			[zMachine restoreSaveState: lastAutosave];
		}
		
		[self reformatWindow];
		[self resetMorePrompt];
		[self scrollToEnd];
		inputPos = [[textView textStorage] length];
	} else {
		NSLog(@"Unknown autosave version (ignoring)");
	}
}

// = NSCoding =
- (void) encodeWithCoder: (NSCoder*) encoder {
	int encodingVersion = 100;
	
	[encoder encodeValueOfObjCType: @encode(int) 
								at: &encodingVersion];
	
	[encoder encodeObject: upperWindows];
	[encoder encodeObject: lowerWindows];
	
	// The rest of the view state
	[encoder encodeObject: [textView textStorage]];
	[encoder encodeObject: commandHistory];
	
	// All we need, I think
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [self initWithFrame: NSMakeRect(0,0, 200, 200)];
	
    if (self) {
		int encodingVersion;
		
		[decoder decodeValueOfObjCType: @encode(int)
									at: &encodingVersion];
		
		if (encodingVersion == 100) {
			if (lastAutosave) [lastAutosave release];
			if (upperWindows) [upperWindows release];
			if (lowerWindows) [lowerWindows release];
			if (commandHistory) [commandHistory release];
			
			lastAutosave = nil;
			upperWindows = [[decoder decodeObject] retain];
			lowerWindows = [[decoder decodeObject] retain];
			
			NSTextStorage* storage = [decoder decodeObject];
			
			[[textView textStorage] setAttributedString: storage];
			
			commandHistory = [[decoder decodeObject] retain];
			
			// Final setup
			upperWindowsToRestore = [upperWindows count];
			
			[upperWindows makeObjectsPerformSelector: @selector(setZoomView:)
										  withObject: self];
			[lowerWindows makeObjectsPerformSelector: @selector(setZoomView:)
										  withObject: self];
			
			// Load the state into the z-machine
			if (zMachine) {
				[zMachine restoreSaveState: lastAutosave];
			}
			
			[self reformatWindow];
			[self resetMorePrompt];
			[self scrollToEnd];
			inputPos = [[textView textStorage] length];
		} else {
			NSLog(@"Unknown autosave version (ignoring)");
			[self release];
			return nil;
		}
    }
	
    return self;
}

- (void) restoreSaveState: (NSData*) state {
	[zMachine restoreSaveState: state];
	
	[self reformatWindow];
	[self resetMorePrompt];
	[self scrollToEnd];
	inputPos = [[textView textStorage] length];
}

// = Debugging =
- (void) hitBreakpointAt: (int) pc {
	if (delegate && [delegate respondsToSelector: @selector(hitBreakpoint:)]) {
		[delegate hitBreakpoint: pc];
	} else {
		NSLog(@"Breakpoint without handler");
		[zMachine continueFromBreakpoint];
	}
}

// = Focused view =
- (void) setFocusedView: (NSObject<ZWindow>*) view {
	focusedView = view;
}

- (NSObject<ZWindow>*) focusedView {
	return focusedView;
}

// = Cursor delegate =
- (void) viewWillMoveToWindow: (NSWindow*) newWindow {
	// Will observe events in a new window
	if ([self window] != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: NSWindowDidBecomeKeyNotification
													  object: [self window]];
		[[NSNotificationCenter defaultCenter] removeObserver: self
														name: NSWindowDidResignKeyNotification
													  object: [self window]];
	}
	
	if (newWindow != nil) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(windowDidBecomeKey:)
													 name: NSWindowDidBecomeKeyNotification
												   object: [self window]];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(windowDidResignKey:)
													 name: NSWindowDidResignKeyNotification
												   object: [self window]];		
	}
}

- (void) windowDidBecomeKey: (NSNotification*) not {
	if (pixmapCursor) {
		[pixmapCursor setActive: YES];
	}
}

- (void) windowDidResignKey: (NSNotification*) not {
	if (pixmapCursor) {
		[pixmapCursor setActive: NO];
	}
}

- (void) blinkCursor: (ZoomCursor*) sender {
	[self setNeedsDisplayInRect: [sender cursorRect]];
}

- (BOOL) acceptsFirstResponder {
	if (pixmapWindow != nil) {
		return YES;
	}
	
	return NO;
}

- (BOOL) becomeFirstResponder {
	if (pixmapCursor) {
		[pixmapCursor setFirst: YES];
		return YES;
	}
	
	return NO;
}

- (BOOL) resignFirstResponder {
	if (pixmapCursor) {
		[pixmapCursor setFirst: NO];
	}
	
	return YES;
}

// = Manual input =

- (void) setInputLinePos: (NSPoint) pos {
	inputLinePos = pos;
}

- (void) setInputLine: (ZoomInputLine*) input {
	if (inputLine) [inputLine release];
	inputLine = [input retain];
	
	if ([inputLine delegate] == nil)
		[inputLine setDelegate: self];
}

- (void) inputLineHasChanged: (ZoomInputLine*) sender {
	[self setNeedsDisplayInRect: [inputLine rectForPoint: inputLinePos]];
}

- (void) endOfLineReached: (ZoomInputLine*) sender {
	[self setNeedsDisplayInRect: [inputLine rectForPoint: inputLinePos]];
	
	if (receiving) {
		NSString* inputText = [inputLine inputLine];
		
		[commandHistory addObject: inputText];
		
		inputText = [inputText stringByAppendingString: @"\n"];
		
		[zMachine inputText: inputText];
		[self orInputCommand: inputText];		
	}
	
	[inputLine release];
	inputLine = nil;
}

// = Output receivers =

- (void) addOutputReceiver: (id) receiver {
	if (!outputReceivers) {
		outputReceivers = [[NSMutableArray alloc] init];
	}
	
	if ([outputReceivers indexOfObjectIdenticalTo: receiver] == NSNotFound) {
		[outputReceivers addObject: receiver];
	}
}

- (void) removeOutputReceiver: (id) receiver {
	if (!outputReceivers) return;
	[outputReceivers removeObjectIdenticalTo: receiver];
	
	if ([outputReceivers count] <= 0) {
		[outputReceivers release];
		outputReceivers = nil;
	}
}

// These functions are really for internal use only: they actually call the output receivers as appropriate
- (void) orInputCommand: (NSString*) command {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(inputCommand:)]) {
			[or inputCommand: command];
		}
	}
}

- (void) orInputCharacter: (NSString*) character {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(inputCharacter:)]) {
			[or inputCharacter: character];
		}
	}
}

- (void) orOutputText:   (NSString*) outputText {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(outputText:)]) {
			[or outputText: outputText];
		}
	}
}

- (void) orWaitingForInput {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(zoomWaitingForInput)]) {
			[or zoomWaitingForInput];
		}
	}
}

- (void) orInterpreterRestart {
	if (!outputReceivers) return;
	NSEnumerator* orEnum = [outputReceivers objectEnumerator];
	NSObject* or;
	
	while (or = [orEnum nextObject]) {
		if ([or respondsToSelector: @selector(zoomInterpreterRestart)]) {
			[or zoomInterpreterRestart];
		}
	}
}

- (void) zMachineHasRestarted {
	[self orInterpreterRestart];
}

// = Input sources =

- (void) setInputSource: (id) source {
	if (inputSource) [inputSource release];
	inputSource = [source retain];
	
	if (receivingCharacters && [inputSource respondsToSelector: @selector(nextCommand)]) {
		// Get the next command
		NSString* nextInput = [inputSource nextCommand];
		
		if (nextInput == nil) {
			// End of input
			[inputSource release];
			inputSource = nil;
		} else {			
			if ([nextInput length] == 0) nextInput = @"\n";
			
			// We've got some input: perform it
			[self stopReceiving];
			
			[zMachine inputText: nextInput];
			[self orInputCharacter: nextInput];
		}
	} else if (receiving && [inputSource respondsToSelector: @selector(nextCommand)]) {
		NSString* nextInput = [inputSource nextCommand];
		
		if (nextInput == nil) {
			// End of input
			[inputSource release];
			inputSource = nil;
		} else {
			nextInput = [nextInput stringByAppendingString: @"\n"];
			
			// We've got some input: write it, perform it
			[self stopReceiving];
			
			// FIXME: maybe do this in the current style? (At least this way, it's obvious what's come from where)
			ZStyle* inputStyle = [[[ZStyle alloc] init] autorelease];
			[inputStyle setUnderline: YES];
			[inputStyle setBold: YES];
			[inputStyle setBackgroundColour: 7];
			[inputStyle setForegroundColour: 4];
			
			[focusedView writeString: nextInput
						   withStyle: inputStyle];
			
			[commandHistory addObject: nextInput];
			
			[zMachine inputText: nextInput];
			[self orInputCommand: nextInput];
		}
	}
}

- (void) removeInputSource: (id) source {
	if (source == inputSource) {
		[inputSource release];
		inputSource = nil;
	}
}

// = Resources =

- (void) setResources: (ZoomBlorbFile*) res {
	if (resources) [resources release];
	resources = [res retain];
}

- (ZoomBlorbFile*) resources {
	return resources;
}

- (BOOL) containsImageWithNumber: (int) number {
	if (resources == nil) return NO;
		
	return [resources containsImageWithNumber: number];
}

- (NSSize) sizeOfImageWithNumber: (int) number {
	return [resources sizeForImageWithNumber: number
							   forPixmapSize: [pixmapWindow size]];
	NSImage* img = [resources imageWithNumber: number];
	
	if (img != nil) {
		return [img size];
	} else {
		return NSMakeSize(0,0);
	}
}

// = Terminating characters =

- (void) setTerminatingCharacters: (NSSet*) termChars {
	if (terminatingChars) [terminatingChars release];
	
	terminatingChars = [termChars copy];
}

- (NSSet*) terminatingCharacters {
	return terminatingChars;
}


// = Dealing with the history =

- (NSString*) lastHistoryItem {
	int oldPos = historyPos;
	
	historyPos--;
				
	if (historyPos < 0) historyPos = 0;
	if (historyPos > [commandHistory count]) historyPos = [commandHistory count];

	if (historyPos == oldPos) return nil;

	if (historyPos < [commandHistory count]) {
		return [commandHistory objectAtIndex: historyPos];
	} else {
		return nil;
	}
}

- (NSString*) nextHistoryItem {
	int oldPos = historyPos;
				
	historyPos++;
				
	if (historyPos < 0) historyPos = 0;
	if (historyPos > [commandHistory count]) historyPos = [commandHistory count];
	
	if (historyPos == oldPos) return nil;
	
	if (historyPos < [commandHistory count]) {
		return [commandHistory objectAtIndex: historyPos];
	} else {
		return nil;
	}
}

@end
