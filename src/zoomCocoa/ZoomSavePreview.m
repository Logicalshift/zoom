//
//  ZoomSavePreview.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Mar 27 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSavePreview.h"


@implementation ZoomSavePreview

static NSImage* saveHighlightInactive;
static NSImage* saveHighlightActive;
static NSImage* saveBackground;

+ (void) initialize {
	saveHighlightInactive = [[NSImage imageNamed: @"saveHighlightInactive"] retain];
	saveHighlightActive = [[NSImage imageNamed: @"saveHighlightActive"] retain];
	saveBackground = [[NSImage imageNamed: @"saveBackground"] retain];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		filename = nil;
		preview = nil;
		highlighted = NO;
    }
    return self;
}

- (id) initWithPreview: (ZoomUpperWindow*) prev
			  filename: (NSString*) file {
	self = [self init];
	
	if (self) {
		preview = [prev retain];
		filename = [file copy];
		highlighted = NO;
	}
	
	return self;
}

- (void) dealloc {
	if (preview) [preview release];
	if (filename) [filename release];
	
	[super dealloc];
}

- (void) setHighlighted: (BOOL) value {
	highlighted = value;
	[self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect {
	NSFont* lineFont = [NSFont userFixedPitchFontOfSize: 9];
	NSFont* infoFont = [NSFont systemFontOfSize: 11];
	
	NSRect ourBounds = [self bounds];
	
	// Background
	NSColor* textColour;
	NSColor* backgroundColour;
	
	if (highlighted) {
		if (saveHighlightActive) {
			backgroundColour = [NSColor colorWithPatternImage: saveHighlightActive];
			[[NSColor clearColor] setStroke];
		} else {
			backgroundColour = [NSColor highlightColor];
			[[NSColor colorWithDeviceRed: .02 green: .39 blue: .80 alpha: 1.0] setStroke];
		}
		
		textColour = [NSColor whiteColor];
	} else {
		if (saveBackground) {
			backgroundColour = [NSColor colorWithPatternImage: saveBackground];
		} else {
			backgroundColour = [NSColor whiteColor];
		}
		
		[[NSColor colorWithDeviceRed: .76 green: .76 blue: .76 alpha:1.0] setStroke];
		textColour = [NSColor blackColor];
	}

	[[NSGraphicsContext currentContext] setPatternPhase: [self convertPoint: NSMakePoint(0,0)
																	 toView: nil]];
	
	[backgroundColour setFill];
	NSRectFill(rect);
	[NSBezierPath setDefaultLineWidth: 1.0];
	[NSBezierPath strokeRect: NSMakeRect(ourBounds.origin.x+0.5, ourBounds.origin.y+0.5, ourBounds.size.width-1.0, ourBounds.size.height-1.0)];
	
	// Preview lines (from the top)
	NSDictionary* previewStyle = [NSDictionary dictionaryWithObjectsAndKeys: 
		lineFont, NSFontAttributeName,
		textColour, NSForegroundColorAttributeName,
		backgroundColour, NSBackgroundColorAttributeName,
		nil];
	
	float ypos = 4;
	int lines = 0;
	
	NSArray* upperLines = [preview lines];
	NSAttributedString* thisLine;
	
	NSEnumerator* lineEnum = [upperLines objectEnumerator];
	
	while (thisLine = [lineEnum nextObject]) {
		// Strip any multiple spaces out of this line
		int x;
		
		unichar* newString = NULL;
		int newLen = 0;

		for (x=0; x<[thisLine length]; x++) {
			unichar chr = [[thisLine string] characterAtIndex: x];
			
			if (chr == 32) {
				while (x<[thisLine length]-1 && [[thisLine string] characterAtIndex: x+1] == 32) {
					x++;
				}
			}
			
			newLen++;
			newString = realloc(newString, sizeof(unichar)*newLen);
			newString[newLen-1] = chr;
		}
		
		// Convert to NSString
		NSString* stripString = [[NSString alloc] initWithCharacters: newString
															  length: newLen];
		free(newString);
		
		// Draw this string
		NSSize stringSize = [stripString sizeWithAttributes: previewStyle];
		
		[stripString drawInRect: NSMakeRect(4, ypos, ourBounds.size.width-8, stringSize.height)
				withAttributes: previewStyle];
		ypos += stringSize.height;
		
		// Finish up
		[stripString release];
		
		lines++;
		if (lines > 2) break;
	}
	
	// Draw the filename
	NSDictionary* infoStyle = [NSDictionary dictionaryWithObjectsAndKeys: 
		infoFont, NSFontAttributeName,
		textColour, NSForegroundColorAttributeName,
		backgroundColour, NSBackgroundColorAttributeName,
		nil];
	
	NSString* displayName = [[filename stringByDeletingLastPathComponent] lastPathComponent];
	displayName = [displayName stringByDeletingPathExtension];
	
	NSSize infoSize = [displayName sizeWithAttributes: infoStyle];
	NSRect infoRect = ourBounds;
	
	infoRect.origin.x = 4;
	infoRect.origin.y = ourBounds.size.height - 4 - infoSize.height;
	infoRect.size.width -= 8;
	
	[displayName drawInRect: infoRect
			 withAttributes: infoStyle];
	
	// Draw the date (if there's room)
	infoRect.size.width -= infoSize.width + 4;
	infoRect.origin.x += infoSize.width + 4;
	
	NSDate* fileDate = [[[NSFileManager defaultManager] fileAttributesAtPath: filename
																traverseLink: YES] objectForKey: NSFileModificationDate];
	
	if (fileDate) {
		NSString* dateString = [[fileDate dateWithCalendarFormat: @"%d %b %Y %H:%M" timeZone: [NSTimeZone defaultTimeZone]] description];
		NSSize dateSize = [dateString sizeWithAttributes: infoStyle];
		
		if (dateSize.width <= infoRect.size.width) {
			infoRect.origin.x = (infoRect.origin.x + infoRect.size.width) - dateSize.width;
			infoRect.size.width = dateSize.width;
			
			[dateString drawInRect: infoRect
					withAttributes: infoStyle];
		}
	}
}

- (void) mouseUp: (NSEvent*) event {
	[self setHighlighted: !highlighted];
}

- (BOOL) isFlipped {
	return YES;
}

@end
