//
//  ZoomInputLine.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jun 26 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomInputLine.h"


@implementation ZoomInputLine

// Initialisation
- (id) initWithCursor: (ZoomCursor*) csr
		   attributes: (NSDictionary*) attr {
	self = [super init];
	
	if (self) {
		lineString = [@"" mutableCopy];
		cursor = [csr retain];
		attributes = [attr mutableCopy];
		
		[attributes removeObjectForKey: NSBackgroundColorAttributeName];
	}
	
	return self;
}

- (void) dealloc {
	[cursor release];
	[lineString release];
	[attributes release];
	
	[super dealloc];
}

// Drawing
- (void) drawAtPoint: (NSPoint) point {
	[lineString drawAtPoint: point
			 withAttributes: attributes];
}

- (NSSize) size {
	return [lineString sizeWithAttributes: attributes];
}

- (NSRect) rectForPoint: (NSPoint) point {
	NSRect r;
	
	r.origin = point;
	r.size = [self size];
	
	return r;
}

// Keys, editing
- (void) updateCursor {
	[cursor positionInString: lineString
			  withAttributes: attributes
			atCharacterIndex: insertionPos];
}

- (void) stringHasUpdated {
	if (delegate && [delegate respondsToSelector: @selector(inputLineHasChanged:)]) {
		[delegate inputLineHasChanged: self];
	}
}

- (void) keyDown: (NSEvent*) evt {
	NSString* input = [evt characters];
	
	int flags = [evt modifierFlags];
	
	// Ignore events with modifier keys
	if (flags&(NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask|NSHelpKeyMask) != 0) {
		return;
	}
	
	[self stringHasUpdated];
	
	// Deal with/strip characters 0xf700-0xf8ff from the input string
	int x;
	NSMutableString* inString = [[NSMutableString alloc] init];
		
	for (x=0; x<[input length]; x++) {
		unichar chr = [input characterAtIndex: x];
		
		// IMPLEMENT ME: up/down, function keys, etc
		
		if (chr < 0xf700 || chr > 0xf8ff) {
			[inString appendString: [NSString stringWithCharacters:&chr
															length:1]];
		}
	}
	
	// Add to the string
	if ([inString length] > 0) {
		[lineString insertString: inString
						 atIndex: insertionPos];
		insertionPos += [inString length];
		
		[self stringHasUpdated];
		[self updateCursor];
	}
	
	[inString release];
}

// Delegate
- (void) setDelegate: (id) dg {
	delegate = dg;
}

- (id) delegate {
	return delegate;
}

@end
