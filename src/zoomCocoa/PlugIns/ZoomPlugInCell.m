//
//  ZoomPlugInCell.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugInCell.h"


@implementation ZoomPlugInCell

- (void)drawInteriorWithFrame: (NSRect)cellFrame 
					   inView: (NSView *)controlView {
	[super drawInteriorWithFrame: cellFrame
						  inView: controlView];
}

- (void) setObjectValue: (id <NSCopying>)object {
	if ([object isKindOfClass: [ZoomPlugInInfo class]]) {
		[objectValue release];
		objectValue = [object copy];
	}
}

- (id) objectValue {
	return objectValue;
}

@end
