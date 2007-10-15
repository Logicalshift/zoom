//
//  ZoomDownloadView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 13/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomDownloadView.h"


@implementation ZoomDownloadView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		// Set up the image
		downloadImage = [[NSImage imageNamed: @"IFDB-downloading"] retain];
		
		// Set up the progress indicator
		progress = [[NSProgressIndicator alloc] initWithFrame: NSMakeRect(NSMinX(frame)+14, NSMinY(frame) + 18, frame.size.width-28, 16)];
		[progress setAutoresizingMask: NSViewWidthSizable|NSViewMaxYMargin];
		
		[self addSubview: progress];
    }
    return self;
}

- (void) dealloc {
	[downloadImage release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
	NSSize imageSize = [downloadImage size];
	NSRect bounds = [self bounds];
	
	[[NSColor clearColor] set];
	NSRectFill(bounds);
	
	[downloadImage drawInRect: bounds
					 fromRect: NSMakeRect(0,0, imageSize.width,imageSize.height)
					operation: NSCompositeSourceOver
					 fraction: 1.0];
}

- (BOOL) isOpaque {
	return NO;
}

- (NSProgressIndicator*) progress {
	return progress;
}

@end
