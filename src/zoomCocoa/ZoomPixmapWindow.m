//
//  ZoomPixmapWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "ZoomPixmapWindow.h"


@implementation ZoomPixmapWindow

// Initialisation
- (id) initWithZoomView: (ZoomView*) view {
	self = [super init];
	
	if (self) {
		pixmap = [[NSImage alloc] initWithSize: NSMakeSize(640, 400)];
		zView = view;
		[zView.window setContentSize: NSMakeSize(640, 400)];
		
		inputStyle = nil;
	}
	
	return self;
}

- (void) dealloc {
	[pixmap release];
	[inputStyle release];
	
	[super dealloc];
}

// = Getting the pixmap =

- (NSSize) size {
	return [pixmap size];
}

@synthesize pixmap;

// = Standard window commands =

- (void) clearWithStyle: (ZStyle*) style {
	[pixmap lockFocus];
	
    NSColor* backgroundColour = [style reversed]?[zView foregroundColourForStyle: style]:[zView backgroundColourForStyle: style];
	[backgroundColour set];
	NSRectFill(NSMakeRect(0, 0, [pixmap size].width, [pixmap size].height));
			   
	[pixmap unlockFocus];
}

- (void) setFocus {
}

- (NSSize) sizeOfFont: (NSFont*) font {
    // Hack: require a layout manager for OS X 10.6, but we don't have the entire text system to fall back on
    NSLayoutManager* layoutManager = [[NSLayoutManager alloc] init];
    
    // Width is one 'em'
	CGFloat width = [@"M" sizeWithAttributes: [NSDictionary dictionaryWithObjectsAndKeys: NSFontAttributeName, font, nil]].width;
    
    // Height is decided by the layout manager
	CGFloat height = [layoutManager defaultLineHeightForFont: font];
    
    return NSMakeSize(width, height);
}

- (void) writeString: (NSString*) string
		   withStyle: (ZStyle*) style {
	[pixmap lockFocus];
	
	NSLog(@"Warning: should not call standard ZWindow writeString on a pixmap window");
	
	[pixmap unlockFocus];
}

// Pixmap window commands
- (void) setSize: (NSSize) windowSize {
	if (windowSize.width < 0) {
		windowSize.width = [zView bounds].size.width;
	}
	if (windowSize.height < 0) {
		windowSize.height = [zView bounds].size.height;
	}
	
	[pixmap setSize: windowSize];
}

- (void) plotRect: (NSRect) rect
		withStyle: (ZStyle*) style {
	[pixmap lockFocusFlipped:YES];
	
    NSColor* foregroundColour = [zView foregroundColourForStyle: style];
	[foregroundColour set];
	NSRectFill(rect);
	
	[pixmap unlockFocus];
	[zView setNeedsDisplay: YES];
}

- (void) plotText: (NSString*) text
		  atPoint: (NSPoint) point
		withStyle: (ZStyle*) style {
	[pixmap lockFocusFlipped:YES];
		
	NSMutableDictionary* attr = [[zView attributesForStyle: style] mutableCopy];
	
	// Draw the background
	CGFloat height = [self sizeOfFont: [attr objectForKey: NSFontAttributeName]].height;
	CGFloat descender = [[attr objectForKey: NSFontAttributeName] descender];
	NSSize size = [text sizeWithAttributes: attr];
	
	point.y -= ceil(height)+1.0;
	
	size.height = height;
	NSRect backgroundRect;
	backgroundRect.origin = point;
	backgroundRect.size = size;
	backgroundRect.origin.y -= descender;
	
	backgroundRect.origin.x = floor(backgroundRect.origin.x);
	backgroundRect.origin.y = floor(backgroundRect.origin.y);
	backgroundRect.size.width = ceil(backgroundRect.size.width);
	backgroundRect.size.height = ceil(backgroundRect.size.height) + 1.0;
	
	[(NSColor*)[attr objectForKey: NSBackgroundColorAttributeName] set];
	NSRectFill(backgroundRect);
	
	// Draw the text
	[attr removeObjectForKey: NSBackgroundColorAttributeName];
	[text drawAtPoint: point
	   withAttributes: attr];
	
	[attr release];
	
	[pixmap unlockFocus];
	[zView setNeedsDisplay: YES];
}

- (void) scrollRegion: (NSRect) region
			  toPoint: (NSPoint) where {
	[pixmap lockFocusFlipped:YES];
	
	// Used to use NSCopyBits but Apple randomly broke it sometime in Snow Leopard. The docs lied anyway.
	// This is much slower :-(
	NSBitmapImageRep*	copiedBits	= [[NSBitmapImageRep alloc] initWithFocusedViewRect: region];
	NSImage*			copiedImage	= [[NSImage alloc] init];
	[copiedImage addRepresentation: copiedBits];
	[copiedBits release];
	[copiedImage drawInRect: NSMakeRect(where.x, where.y, region.size.width, region.size.height)
				   fromRect: NSMakeRect(0,0, region.size.width, region.size.height)
				  operation: NSCompositingOperationSourceOver
				   fraction: 1.0
			 respectFlipped: YES
					  hints: nil];
	
	[copiedImage release];
	
	// Uh, docs say we should use NSNullObject here, but it's not defined. Making a guess at its value (sigh)
	// This would be less of a problem in a view, because we can get the view's own graphics state. But you
	// can't get the graphics state for an image (in general).
	// NSCopyBits(0, region, where);
	[pixmap unlockFocus];
}

// = Measuring =

- (void) getInfoForStyle: (in ZStyle*) style
				   width: (out float*) width
				  height: (out float*) height
				  ascent: (out float*) ascent
				 descent: (out float*) descent {
    int fontnum;
	
    fontnum =
        ([style bold]?1:0)|
        ([style underline]?2:0)|
        ([style fixed]?4:0)|
        ([style symbolic]?8:0);

	NSFont* font = [zView fontWithStyle: fontnum];
    NSSize fontSize = [self sizeOfFont: font];
	
	*width = fontSize.width;
	*ascent = [font ascender];
	*descent = [font descender];
	*height = fontSize.height+1;
}

- (out bycopy NSDictionary*) attributesForStyle: (in bycopy ZStyle*) style {
	return [zView attributesForStyle: style];
}

- (NSSize) measureString: (in NSString*) string
			   withStyle: (in ZStyle*) style {
	NSDictionary* attr = [zView attributesForStyle: style];
	
	return [string sizeWithAttributes: attr];
}

- (NSColor*) colourAtPixel: (NSPoint) point {
	[pixmap lockFocusFlipped:YES];
	
	if (point.x <= 0) point.x = 1;
	if (point.y <= 0) point.y = 1;
	
	NSColor* res = NSReadPixel(point);
	
	[pixmap unlockFocus];
	
	return [[res copy] autorelease];
}

// = Input =

- (void) setInputPosition: (NSPoint) point
				withStyle: (in bycopy ZStyle*) style {
	inputPos = point;
	if (inputStyle) {
		[inputStyle release];
	}
	inputStyle = [style copy];
}

@synthesize inputPos;

- (ZStyle*) inputStyle {
	return inputStyle;
}

- (void) plotImageWithNumber: (int) number
					 atPoint: (NSPoint) point {
	NSImage* img = [[zView resources] imageWithNumber: number];

	NSRect destRect;
	destRect.origin = point;
	destRect.size = [[zView resources] sizeForImageWithNumber: number
												forPixmapSize: [pixmap size]];
	
	[pixmap lockFocusFlipped:YES];
	[img drawInRect: destRect
		   fromRect: NSZeroRect
		  operation: NSCompositingOperationSourceOver
		   fraction: 1.0
	 respectFlipped: YES
			  hints: nil];
	[pixmap unlockFocus];
	
	[zView setNeedsDisplay: YES];
}

// = NSCoding =
- (void) encodeWithCoder: (NSCoder*) encoder {
	[encoder encodeObject: pixmap];
	
	[encoder encodePoint: inputPos];
	[encoder encodeObject: inputStyle];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
    if (self) {
		pixmap = [[decoder decodeObject] retain];
		inputPos = [decoder decodePoint];
		inputStyle = [[decoder decodeObject] retain];
    }
	
    return self;
}

@synthesize zoomView=zView;

// = Input styles =

- (void) setInputStyle: (ZStyle*) newInputStyle {
	// Do nothing
}

@end
