//
//  ZoomResourceDrop.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 28 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomResourceDrop.h"

static NSImage* needDropImage;
static NSImage* blorbImage;

@implementation ZoomResourceDrop

+ (void) initialize {
	needDropImage = [NSImage imageNamed: @"NeedDrop"];
	blorbImage = [NSImage imageNamed: @"Blorb"];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
		droppedFilename = nil;
		
		[self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
    }
	
    return self;
}

- (void) dealloc {
	[droppedFilename release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
	NSRect bounds = [self bounds];
	
	// Position to draw the image in
	NSRect imgRect = NSMakeRect(0,0,48,48);
	
	imgRect.origin.y = NSMaxY(bounds) - imgRect.size.height - 4;
	imgRect.origin.x = NSMinY(bounds) + (bounds.size.width - imgRect.size.width)/2.0;
	
	// Image and text to draw
	NSImage* img = nil;
	NSString* description = @"Er";
	
	if (droppedFilename) {
		img = blorbImage;
		description = @"Drag a Blorb resource file here to change the resources for this game";
	} else {
		img = needDropImage;
		description = @"Drag a Blorb resource file here to set it as the graphics/sound resources for this game";
	}
	
	// Draw the image
	NSRect sourceRect;
	sourceRect.origin = NSMakePoint(0,0);
	sourceRect.size = [img size];
	
	[img drawInRect: imgRect
		   fromRect: sourceRect
		  operation: NSCompositeSourceOver
		   fraction: 1.0];
	
	// Draw the text
	NSRect remainingRect = bounds;
	NSMutableParagraphStyle* paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[paraStyle setAlignment: NSCenterTextAlignment];
	
	remainingRect.size.height -= imgRect.size.height + 8;
	
	[description drawInRect: remainingRect
			 withAttributes: [NSDictionary dictionaryWithObjectsAndKeys: 
				 [NSFont systemFontOfSize: 11], NSFontAttributeName,
				 paraStyle, NSParagraphStyleAttributeName,
				 nil]];
}

@end
