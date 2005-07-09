//
//  ZoomSkeinLayoutItem.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 08/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinLayoutItem.h"


@implementation ZoomSkeinLayoutItem

// = Initialisation =

- (id) init {
	return [self initWithItem: nil
						width: 0
					fullWidth: 0
						level: 0];
}

- (id) initWithItem: (ZoomSkeinItem*) newItem
			  width: (float) newWidth
		  fullWidth: (float) newFullWidth
			  level: (int) newLevel {
	self = [super init];
	
	if (self) {
		item = [newItem retain];
		width = newWidth;
		fullWidth = newFullWidth;
		level = newLevel;
	}
	
	return self;
}

- (void) dealloc {
	if (item) [item release];
	if (children) [children release];
	
	[super dealloc];
}

// = Getting properties =

- (ZoomSkeinItem*) item {
	return item;
}

- (float) width {
	return width;
}

- (float) fullWidth {
	return fullWidth;
}

- (float) position {
	return position;
}

- (NSArray*) children {
	return children;
}

- (int)	level {
	return level;
}

- (BOOL) onSkeinLine {
	return onSkeinLine;
}

// = Setting properties =

- (void) setItem: (ZoomSkeinItem*) newItem {
	if (item) [item release];
	item = [newItem retain];
}

- (void) setWidth: (float) newWidth {
	width = newWidth;
}

- (void) setFullWidth: (float) newFullWidth {
	fullWidth = newFullWidth;
}

- (void) setPosition: (float) newPosition {
	position = newPosition;
}

- (void) setChildren: (NSArray*) newChildren {
	if (children) [children release];
	children = [newChildren retain];
}

- (void) setLevel: (int) newLevel {
	level = newLevel;
}

- (void) setOnSkeinLine: (BOOL) online {
	onSkeinLine = online;
}

@end
