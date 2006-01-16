//
//  ZoomHQImageView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 14/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomHQImageView.h"


@implementation ZoomHQImageView

- (void)drawRect:(NSRect)rect {
	// Set the graphics context image rendering quality
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	
	// The rest is up to the image view (or would be, if it didn't promptly turn this off again)
	// [super drawRect: rect];
	
	[[self image] drawInRect: [self bounds]
					fromRect: NSMakeRect(0,0,[[self image] size].width,[[self image] size].height)
				   operation: NSCompositeSourceOver
					fraction: 1.0];
}

- (void) mouseDown: (NSEvent*) event {
	if ([event clickCount] == 2 && [self target] != nil) {
		[self sendAction: [self action]
					  to: [self target]];
	}
}

@end
