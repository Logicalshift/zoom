//
//  ZoomUpperWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomUpperWindow.h"


@implementation ZoomUpperWindow

- (id) initWithZoomView: (ZoomView*) view {
    self = [super init];
    if (self) {
        theView = view;
        lines = [[NSMutableArray allocWithZone: [self zone]] init];

        backgroundColour = [[NSColor blueColor] retain];

        endLine = startLine = 0;
    }
    return self;
}

- (void) dealloc {
    //[theView release];
    [lines release];
    [backgroundColour release];
    [super dealloc];
}

// Clears the window
- (void) clearWithStyle: (ZStyle*) style {
    [lines release];
    lines = [[NSMutableArray allocWithZone: [self zone]] init];
    xpos = ypos = 0;

    [backgroundColour release];
    backgroundColour = [[theView backgroundColourForStyle: style] retain];
}

// Sets the input focus to this window
- (void) setFocus {
}

// Sending data to a window
- (void) writeString: (NSString*) string
           withStyle: (ZStyle*) style {
    [style setFixed: YES];

    int x;
    int len = [string length];
    for (x=0; x<len; x++) {
        if ([string characterAtIndex: x] == '\n') {
            [self writeString: [string substringToIndex: x]
                    withStyle: style];
            ypos++; xpos = 0;
            [self writeString: [string substringFromIndex: x+1]
                    withStyle: style];
            return;
        }
    }

    if (ypos >= [lines count]) {
        int x;
        for (x=[lines count]; x<=ypos; x++) {
            [lines addObject: [[[NSMutableAttributedString alloc] init] autorelease]];
        }
    }

    NSMutableAttributedString* thisLine;
    thisLine = [lines objectAtIndex: ypos];

    int strlen = [string length];

    // Make sure there is enough space on this line for the text
    if ([thisLine length] <= xpos+strlen) {
        NSFont* fixedFont = [theView fontWithStyle: ZFixedStyle];
        NSDictionary* clearStyle = [NSDictionary dictionaryWithObjectsAndKeys:
            fixedFont, NSFontAttributeName,
            nil];
        char* spaces = malloc((xpos+strlen)-[thisLine length]);

        int x;
        for (x=0; x<(xpos+strlen)-[thisLine length]; x++) {
            spaces[x] = ' ';
        }

        NSAttributedString* spaceString = [[NSAttributedString alloc]
            initWithString: [NSString stringWithCString: spaces
                                                 length: (xpos+strlen)-[thisLine length]]
                attributes: clearStyle];
        
        [thisLine appendAttributedString: spaceString];

        [spaceString release];
        free(spaces);
    }

    // Replace the appropriate section of the line
    NSAttributedString* thisString = [theView formatZString: string
                                                  withStyle: style];
    [thisLine replaceCharactersInRange: NSMakeRange(xpos, strlen)
                  withAttributedString: thisString];
    xpos += strlen;

    [theView upperWindowNeedsRedrawing];
}

// Size (-1 to indicate an unsplit window)
- (void) startAtLine: (int) line {
    startLine = line;
}

- (void) endAtLine:   (int) line {
    endLine = line;

    [theView rearrangeUpperWindows];
}

// Cursor positioning
- (void) setCursorPositionX: (int) xp
                          Y: (int) yp {
    xpos = xp; ypos = yp-startLine;
}

- (NSPoint) cursorPosition {
    return NSMakePoint(xpos, ypos+startLine);
}


// Line erasure
static NSString* blankLine(int length) {
	char* cString = malloc(length);
	int x;
	
	for (x=0; x<length; x++) cString[x] = ' ';
	
	NSString* res = [NSString stringWithCString: cString 
										 length: length];
	
	return res;
}

- (void) eraseLineWithStyle: (ZStyle*) style {
    if (ypos >= [lines count]) {
        int x;
        for (x=[lines count]; x<=ypos; x++) {
            [lines addObject: [[[NSMutableAttributedString alloc] init] autorelease]];
        }
    }

		int xs, ys;
		NSAttributedString* newString;
		
		[theView dimensionX: &xs Y: &ys];
		
		newString = [theView formatZString: blankLine(xs+1)
								 withStyle: style];
		
        [[lines objectAtIndex: ypos] setAttributedString: newString];
}

// Maintainance
- (int) length {
    return (endLine - startLine);
}

- (NSArray*) lines {
    return lines;
}

- (NSColor*) backgroundColour {
    return backgroundColour;
}

- (void) cutLines {
	int length = [self length];
	if ([lines count] < length) return;
	
    [lines removeObjectsInRange: NSMakeRange(length,
                                             [lines count] - length)];
}

- (void) reformatLines {
	NSEnumerator* lineEnum = [lines objectEnumerator];
	NSMutableAttributedString* string;
	
	while (string = [lineEnum nextObject]) {
		NSRange attributedRange;
		NSDictionary* attr;
		int len = [string length];
				
		attributedRange.location = 0;
		
		 while (attributedRange.location < len) {
			attr = [string attributesAtIndex: attributedRange.location
							  effectiveRange: &attributedRange];
			
			if (attributedRange.location == NSNotFound) break;
			if (attributedRange.length == 0) break;
			
			// Re-apply the style associated with this block of text
			ZStyle* sty = [attr objectForKey: ZoomStyleAttributeName];
			
			if (sty) {
				NSDictionary* newAttr = [theView attributesForStyle: sty];
				
				[string setAttributes: newAttr
								range: attributedRange];
			}
			
			attributedRange.location += attributedRange.length;
		}
	}
}

@end
