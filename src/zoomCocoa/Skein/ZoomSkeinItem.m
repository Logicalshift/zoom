//
//  ZoomSkeinItem.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinItem.h"


@implementation ZoomSkeinItem

// = Initialisation =

+ (ZoomSkeinItem) skeinItemWithCommand: (NSString*) command {
	return [[[[self class] alloc] initWithCommand: command] autorelease];
}

- (id) initWithCommand: (NSString*) com {
	self = [super init];
	
	if (self) {
		command = [com copy];
		result  = nil;
		
		parent = nil;
		children = [[NSMutableSet alloc] init];
		
		temporary = YES;
		tempScore = 0;
		played    = NO;
		change    = NO;
		
		annotation = nil;
	}
	
	return self;
}

- (id) init {
	return [self initWithCommand: nil];
}

- (void) dealloc {
	// First, mark the old items as having no parent
	NSEnumerator* objEnum = [children objectEnumerator];
	ZoomSkeinItem* child;
	while (child = [objEnum nextObject]) {
		[child removeFromParent];
	}
	
	// Then just release everything
	[children release];

	if (command)	[command release];
	if (result)		[result release];
	if (annotation) [annotation release];
	
	[super dealloc];
}

// **** Data accessors ****

// = Skein tree =

- (void) setParent: (ZoomSkeinItem*) newParent {
	parent = newParent;
}

- (ZoomSkeinItem*) parent {
	return parent;
}

- (NSSet*) children {
	return children;
}

- (ZoomSkeinItem*) childWithCommand: (NSString*) command {
	return [children objectForKey: command];
}

- (void) mergeWith: (ZoomSkeinItem*) newItem {
	// Merges this item with another
	NSEnumerator* objEnum = [[newItem children] objectEnumerator];
	ZoomSkeinItem* childItem;
	
	while (childItem = [objEnum nextObject]) {
		ZoomSkeinItem* oldChild = [self childWithCommand: [childItem command]];
		
		// Same reasoning as addChild: - this saves us a message call, which might allow us to deal with deeper skeins
		if (oldChild == nil) {
			[self addChild: childItem];
		} else {
			[oldChild mergeWith: childItem];
		}
	}
}

- (void) addChild: (ZoomSkeinItem*) childItem {
	ZoomSkeinItem* oldChild = [self childWithCommand: [childItem command]];
	
	if (oldChild != nil) {
		// Merge if this child item already exists
		[oldChild mergeWith: childItem];
		
		// Set certain flags to the same as the new item
		if ([childItem result]) [oldChild setResult: [childItem result]];
		if ([childItem annotation]) [oldChild setAnnotation: [childItem annotation]];
		
		if (![childItem temporary]) [oldChild setTemporary: NO];
		[oldChild setPlayed: [childItem played]];
		[oldChild setChanged: [childItem changed]];
	} else {
		// Otherwise, just add the new item
		[childItem setParent: self];
		[children addObject: childItem];
	}
}

- (void) removeChild: (ZoomSkeinItem*) childItem {
	if ([childItem parent] != self) return;

	[childItem setParent: nil];
	[children removeObject: childItem];
}

- (void) removeFromParent {
	if (parent) {
		[parent removeChild: self];
	}
}

// = Item data =

- (NSString*) command {
	return [[command copy] autorelease];
}

- (NSString*) result {
	return [[result copy] autorelease];
}

- (void) setCommand: (NSString*) newCommand {
	if (command) [command release];
	command = nil;
	if (newCommand) command = [newCommand copy];
}

- (void) setResult: (NSString*) newResult {
	if (result) [result release];
	result = nil;
	if (newResult) result = [newResult copy];
}

// = Item state =

- (BOOL) temporary {
	return temporary;
}

- (int)  temporaryScore {
	return temporaryScore;
}

- (BOOL) played {
	return played;
}

- (BOOL) changed {
	return changed;
}

- (void) setTemporary: (BOOL) isTemporary {
	temporary = isTemporary
}

static int tempScore = 1;

- (void) zoomSetTemporaryScore {
	temporaryScore = tempScore;
}

- (void) increaseTemporaryScore {
	temporaryScore = tempScore++;
	
	// Also set the parent's scores
	ZoomSkeinItem* item = parent;
	while (item != nil) {
		[item zoomSetTemporaryScore];
		item = [item parent];
	}
}

- (void) setPlayed: (BOOL) newPlayed {
	played = newPlayed;
}

- (void) setChanged: (BOOL) newChanged {
	changed = newChanged;
}

// = Annotation =

- (NSString*) annotation {
	return annotation;
}

- (void) setAnnotation: (NSString*) newAnnotation {
	if (annotation) [annotation release];
	annotation = nil;
	if (newAnnotation) annotation = [newAnnotation copy];
}

// = Taking part in a set =

- (unsigned)hash {
	// Items are distinguished by their command
	return [command hash];
}

- (BOOL)isEqual:(id)anObject {
	if ([anObject isKindOfClass: [NSString class]]) {
		// We can be equal to a string with the same value as our command
		return [anObject isEqual: command];
	}
	
	// But we can't be equal to any other type of object, except ZoomSkeinItem
	if (![anObject isKindOfClass: [ZoomSkeinItem class]])
		return NO;
	
	// We compare on commands
	ZoomSkeinItem* otherItem = anObject;
	
	return [[otherItem command] isEqual: command];
}

@end
