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

static NSString* convertCommand(NSString* command) {
	if (command == nil) return nil;
	
	unichar* uniBuf = malloc(sizeof(unichar)*[command length]);
	[command getCharacters: uniBuf];
	
	BOOL needsChange = NO;
	int x;
	int spaces = 0;
	
	for (x=0; x<[command length]; x++) {
		if (uniBuf[x] < 32) {
			needsChange = YES;
			uniBuf[x] = ' ';
		}
		
		if (uniBuf[x] == 32) {
			spaces++;
		} else {
			spaces = 0;
		}
	}
	
	if (needsChange) {
		command = [NSString stringWithCharacters: uniBuf
										  length: [command length] - spaces];
	}
	
	free(uniBuf);
	
	return command;
}

+ (ZoomSkeinItem*) skeinItemWithCommand: (NSString*) com {
	return [[[[self class] alloc] initWithCommand: com] autorelease];
}

- (id) initWithCommand: (NSString*) com {
	self = [super init];
	
	if (self) {
		command = [convertCommand(com) copy];
		result  = nil;
		
		parent = nil;
		children = [[NSMutableSet alloc] init];
		
		temporary = YES;
		tempScore = 0;
		played    = NO;
		changed   = NO;
		
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

- (ZoomSkeinItem*) childWithCommand: (NSString*) com {
	NSEnumerator* objEnum = [children objectEnumerator];
	ZoomSkeinItem* skeinItem;
	
	while (skeinItem = [objEnum nextObject]) {
		if ([[skeinItem command] isEqualToString: com]) return skeinItem;
	}
	
	return nil;
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

- (ZoomSkeinItem*) addChild: (ZoomSkeinItem*) childItem {
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
		
		// 'New' item is the old one
		return oldChild;
	} else {
		// Otherwise, just add the new item
		[childItem setParent: self];
		[children addObject: childItem];
		
		// 'new' item is the child item
		return childItem;
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

- (BOOL) hasChild: (ZoomSkeinItem*) item {
	if (item == self) return YES;
	//if ([children containsObject: child]) return YES;
	
	NSEnumerator* childEnum = [children objectEnumerator];
	ZoomSkeinItem* child;
	
	while (child = [childEnum nextObject]) {
		if ([child hasChild: item]) return YES;
	}
	
	return NO;
}

- (BOOL) hasChildWithCommand: (NSString*) theCommand {
	NSEnumerator* childEnum = [children objectEnumerator];
	ZoomSkeinItem* child;
	
	if (theCommand == nil) theCommand = @"";
	
	while (child = [childEnum nextObject]) {
		NSString* childCommand = [child command];
		if (childCommand == nil) childCommand = @"";
		
		if ([childCommand isEqualToString: theCommand]) return YES;
	}
	
	return NO;
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
	if (newCommand) command = [convertCommand(newCommand) copy];
}

- (void) setResult: (NSString*) newResult {
	if (![result isEqualTo: newResult]) {
		[self setChanged: YES];
	} else {
		[self setChanged: NO];
	}
	
	if (result) [result release];
	result = nil;
	if (newResult) result = [newResult copy];
}

// = Item state =

- (BOOL) temporary {
	return temporary;
}

- (int)  temporaryScore {
	return tempScore;
}

- (BOOL) played {
	return played;
}

- (BOOL) changed {
	return changed;
}

- (void) setTemporary: (BOOL) isTemporary {
	temporary = isTemporary;
	
	ZoomSkeinItem* p = [self parent];
	
	// Also applies to parent items if set to 'NO'
	if (!isTemporary) {
		while (p != nil) {
			if (![p temporary]) break;
			[p setTemporary: NO];
		}
	}
	
	// FIXME: unsetting should apply to children, too
}

static int currentScore = 1;

- (void) zoomSetTemporaryScore {
	tempScore = currentScore;
}

- (void) setTemporaryScore: (int) score {
	tempScore = score;
}

- (void) increaseTemporaryScore {
	tempScore = currentScore++;
	
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

// = NSCoding =

- (void) encodeWithCoder: (NSCoder*) encoder {
	[encoder encodeObject: children
				   forKey: @"children"];
	
	[encoder encodeObject: command
				   forKey: @"command"];
	[encoder encodeObject: result
				   forKey: @"result"];
	[encoder encodeObject: annotation
				   forKey: @"annotation"];
	
	[encoder encodeBool: played
				 forKey: @"played"];
	[encoder encodeBool: changed
				 forKey: @"changed"];
	[encoder encodeBool: temporary
				 forKey: @"temporary"];
	[encoder encodeInt: tempScore
				forKey: @"tempScore"];
}

- (id)initWithCoder: (NSCoder *)decoder {
	self = [super init];
	
	if (self) {
		children = [[decoder decodeObjectForKey: @"children"] retain];
		
		command = [[decoder decodeObjectForKey: @"command"] retain];
		result = [[decoder decodeObjectForKey: @"result"] retain];
		annotation = [[decoder decodeObjectForKey: @"annotation"] retain];
		
		played = [decoder decodeBoolForKey: @"played"];
		changed = [decoder decodeBoolForKey: @"changed"];
		temporary = [decoder decodeBoolForKey: @"temporary"];
		tempScore = [decoder decodeIntForKey: @"tempScore"];
		
		NSEnumerator* childEnum = [children objectEnumerator];
		ZoomSkeinItem* child;
		while (child = [childEnum nextObject]) {
			child->parent = self;
		}
	}
	
	return self;
}

@end
