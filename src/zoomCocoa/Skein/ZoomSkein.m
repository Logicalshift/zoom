//
//  ZoomSkein.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#define maxTempItems 30

#import "ZoomSkein.h"

@interface ZoomSkeinInputSource : NSObject {
	NSMutableArray* commandStack;
}

- (void) setCommandStack: (NSMutableArray*) stack;
- (NSString*) nextCommand;

@end

@implementation ZoomSkein

- (id) init {
	self = [super init];
	
	if (self) {
		rootItem = [[ZoomSkeinItem alloc] initWithCommand: @"- start -"];		
		activeItem = [rootItem retain];
		currentOutput = [[NSMutableString alloc] init];
		
		[rootItem setTemporary: NO];
		[rootItem setPlayed: YES];
		
		webData = nil;
	}
	
	return self;
}

- (void) dealloc {
	[activeItem release];
	[rootItem release];
	[currentOutput release];
	
	if (webData) [webData release];
	
	[super dealloc];
}

- (ZoomSkeinItem*) rootItem {
	return rootItem;
}

- (ZoomSkeinItem*) activeItem {
	return activeItem;
}

- (void) setActiveItem: (ZoomSkeinItem*) active {
	[activeItem release];
	activeItem = [active retain];
}

// = Notifications =

NSString* ZoomSkeinChangedNotification = @"ZoomSkeinChangedNotification";

- (void) zoomSkeinChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomSkeinChangedNotification
														object: self];
}

// = Zoom output receiver =

- (void) inputCommand: (NSString*) command {
	// Create/set the item to the appropraite item in the skein
	ZoomSkeinItem* newItem = [activeItem addChild: [ZoomSkeinItem skeinItemWithCommand: command]];
	
	// Move the 'active' item
	[activeItem release];
	activeItem = [newItem retain];
	
	// Some values for this item
	[activeItem setPlayed: YES];
	[activeItem increaseTemporaryScore];
	
	// Create a buffer for any new output
	if (currentOutput) [currentOutput release];
	currentOutput = [[NSMutableString alloc] init];
	
	// Notify anyone who's watching that we've updated
	[self zoomSkeinChanged];
}

- (void) inputCharacter: (NSString*) character {
	// We treat these the same
	[self inputCommand: character];
}

- (void) outputText: (NSString*) outputText {
	// Append this text to the current outout
	[currentOutput appendString: outputText];
}

- (void) zoomWaitingForInput {
	// Send the current output to the active item
	if ([currentOutput length] > 0) {
		[activeItem setResult: currentOutput];

		[currentOutput release];
		currentOutput = [[NSMutableString alloc] init];
	}
}

- (void) zoomInterpreterRestart {
	[self zoomWaitingForInput];
	
	// Back to the top
	[activeItem release];
	activeItem = [rootItem retain];
	
	[self zoomSkeinChanged];
	
	[self removeTemporaryItems: maxTempItems];
}

// = Creating a Zoom input receiver =

+ (id) inputSourceFromSkeinItem: (ZoomSkeinItem*) item1
						 toItem: (ZoomSkeinItem*) item2 {
	// item1 must be a parent of item2, and neither can be nil
	
	// item1 is not executed
	if (item1 == nil || item2 == nil) return nil;
	
	NSMutableArray* commandsToExecute = [NSMutableArray array];
	ZoomSkeinItem* parent = item2;
	
	while (parent != item1) {
		NSString* cmd = [parent command];
		if (cmd == nil) cmd = @"";
		[commandsToExecute addObject: cmd];
		
		parent = [parent parent];
		if (parent == nil) return nil;
	}
	
	// commandsToExecute contains the list of commands we need to execute
	ZoomSkeinInputSource* source = [[ZoomSkeinInputSource alloc] init];
	
	[source setCommandStack: commandsToExecute];
	return [source autorelease];
}

- (id) inputSourceFromSkeinItem: (ZoomSkeinItem*) item1
						 toItem: (ZoomSkeinItem*) item2 {
	return [[self class] inputSourceFromSkeinItem: item1
										   toItem: item2];
}

// = Removing temporary items =

- (void) removeTemporaryItems: (int) maxTemps {
	//
	// Maybe a bit confusing: the temporary counter is updated in various ways, but
	// more recent items are always given a higher number. 'maxTemps' is really
	// an indication in the maximum breadth of the tree.
	//
	
	NSMutableSet* itemsInUse = [NSMutableSet set];
	
	// (I have no faith in Apple's ulimits)
	NSMutableArray* itemStack = [NSMutableArray array];
	
	[itemStack addObject: rootItem];
	
	while ([itemStack count] > 0) {
		// Pop the latest item from the stack
		ZoomSkeinItem* item = [itemStack lastObject];
		[itemStack removeLastObject];
		
		// Add this item to the list of items in use
		if ([item temporary]) {
			[itemsInUse addObject: [NSNumber numberWithInt: [item temporaryScore]]];
		}
		
		// Push this item's children onto the stack
		NSEnumerator* childEnum = [[item children] objectEnumerator];
		ZoomSkeinItem* child;
		while (child = [childEnum nextObject]) {
			[itemStack addObject: child];
		}
	}
	
	// Keep only the highest maxTemps scores (and those that are not marked as temporary, of course)
	NSArray* itemList = [[itemsInUse allObjects] sortedArrayUsingSelector: @selector(compare:)];
	if ([itemList count] <= maxTemps) return;
	
	itemList = [itemList subarrayWithRange: NSMakeRange(0, [itemList count] - maxTemps)];
	
	NSSet* itemsToRemove = [NSSet setWithArray: itemList];
	
	[itemStack addObject: rootItem];
	
	while ([itemStack count] > 0) {
		// Pop the latest item from the stack
		ZoomSkeinItem* item = [[itemStack lastObject] retain];
		[itemStack removeLastObject];

		// Remove this item if necessary
		if ([item temporary] && [itemsToRemove containsObject: [NSNumber numberWithInt: [item temporaryScore]]]) {
			[item removeFromParent];
		} else {
			// Push this item's children onto the stack
			NSEnumerator* childEnum = [[item children] objectEnumerator];
			ZoomSkeinItem* child;
			while (child = [childEnum nextObject]) {
				[itemStack addObject: child];
			}
		}
	}
}

@end

// = Our input source object =

@implementation ZoomSkeinInputSource

- (id) init {
	self = [super init];
	
	if (self) {
		commandStack = nil;
	}
	
	return self;
}

- (void) dealloc {
	[commandStack release];
	[super dealloc];
}

- (void) setCommandStack: (NSMutableArray*) stack {
	[commandStack release];
	commandStack = [stack retain];
}

- (NSString*) nextCommand {
	if ([commandStack count] <= 0) return nil;
	
	NSString* nextCommand = [[commandStack lastObject] retain];
	[commandStack removeLastObject];
	return [nextCommand autorelease];
}

@end

