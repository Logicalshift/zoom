//
//  ZoomStoryOrganiser.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomStoryOrganiser.h"

NSString* ZoomStoryOrganiserChangedNotification = @"ZoomStoryOrganiserChangedNotification";
static NSString* defaultName = @"ZoomStoryOrganiser";

@implementation ZoomStoryOrganiser

// = Internal functions =
- (NSDictionary*) dictionary {
	NSMutableDictionary* defaultDictionary = [NSMutableDictionary dictionary];
	
	NSEnumerator* filenameEnum = [filenamesToIdents keyEnumerator];
	NSString* filename;
	
	while (filename = [filenameEnum nextObject]) {
		NSData* encodedId = [NSArchiver archivedDataWithRootObject: [filenamesToIdents objectForKey: filename]];
		
		[defaultDictionary setObject: encodedId
							  forKey: filename];
	}
	
	return defaultDictionary;
}

- (void) storePreferences {
	[[NSUserDefaults standardUserDefaults] setObject:[self dictionary] 
											  forKey:defaultName];
}

- (void) preferenceThread: (NSDictionary*) threadDictionary {
	NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
	NSDictionary* prefs = [threadDictionary objectForKey: @"preferences"];
	
	int counter = 0;
	
	// Connect to the main thread
	[[NSRunLoop currentRunLoop] addPort: port2
                                forMode: NSDefaultRunLoopMode];
	subThread = [[NSConnection allocWithZone: [self zone]]
        initWithReceivePort: port2
                   sendPort: port1];
	[subThread setRootObject: self];
		
	// Function called from a seperate thread
	NSEnumerator* filenameEnum = [prefs keyEnumerator];
	NSString* filename;
	
	while (filename = [filenameEnum nextObject]) {
		NSData* storyData = [prefs objectForKey: filename];
		ZoomStoryID* fileID = [NSUnarchiver unarchiveObjectWithData: storyData];
		ZoomStoryID* realID = [[ZoomStoryID alloc] initWithZCodeFile: filename];
		
		if (fileID != nil && realID != nil && [fileID isEqual: realID]) {
			// Check for a pre-existing entry
			[storyLock lock];
			
			NSString* oldFilename;
			ZoomStoryID* oldIdent;
			
			oldFilename = [identsToFilenames objectForKey: fileID];
			oldIdent = [filenamesToIdents objectForKey: filename];
			
			if (oldFilename && oldIdent && [oldFilename isEqualToString: filename] && [oldIdent isEqualTo: fileID]) {
				[storyLock unlock];
				continue;
			}
			
			// Remove old entries
			if (oldFilename) {
				[identsToFilenames removeObjectForKey: fileID];
				[storyFilenames removeObject: oldFilename];
			}
			
			if (oldIdent) {
				[filenamesToIdents removeObjectForKey: filename];
				[storyIdents removeObject: oldIdent];
			}
			
			// Add this entry
			NSString* newFilename = [[filename copy] autorelease];
			NSString* newIdent    = [[fileID copy] autorelease];
			
			[storyFilenames addObject: newFilename];
			[storyIdents addObject: newIdent];
			
			[identsToFilenames setObject: newFilename forKey: newIdent];
			[filenamesToIdents setObject: newIdent forKey: newFilename];
			
			[storyLock unlock];
		}
		
		[realID release];
		
		counter++;
		if (counter > 20) {
			counter = 0;
			[[subThread rootProxy] organiserChanged];
		}
	}	
	
	[[subThread rootProxy] organiserChanged];
	
	// Tidy up
	[subThread release];
	[port1 release];
	[port2 release];

	subThread = nil;
	port1 = port2 = nil;
	
	// Done
	[threadDictionary release];
	[self release];
	
	// Clear the pool
	[p release];
}

- (void) loadPreferences {
	NSDictionary* prefs = [[NSUserDefaults standardUserDefaults] objectForKey: defaultName];
	
	// Detach a thread to decode the dictionary
	NSDictionary* threadDictionary =
		[[NSDictionary dictionaryWithObjectsAndKeys:
			prefs, @"preferences",
			nil] retain];
	
	// Create a connection so the threads can communicate
	port1 = [[NSPort port] retain];
	port2 = [[NSPort port] retain];
	
	mainThread = [[NSConnection allocWithZone: [self zone]]
		initWithReceivePort: port1
                   sendPort: port2];
	[mainThread setRootObject: self];
	
	// Run the thread
	[self retain]; // Released by the thread when it finishes
	[NSThread detachNewThreadSelector: @selector(preferenceThread:)
							 toTarget: self
						   withObject: threadDictionary];
}

- (void) organiserChanged {
	[self storePreferences];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryOrganiserChangedNotification
														object: self];
}

// = Initialisation =
+ (void) initialize {
	// User defaults
    NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
	ZoomStoryOrganiser* defaultPrefs = [[[[self class] alloc] init] autorelease];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject: [defaultPrefs dictionary]
															forKey: defaultName];
	
    [defaults registerDefaults: appDefaults];	
}

- (id) init {
	self = [super init];
	
	if (self) {
		storyFilenames = [[NSMutableArray alloc] init];
		storyIdents = [[NSMutableArray alloc] init];
		
		filenamesToIdents = [[NSMutableDictionary alloc] init];
		identsToFilenames = [[NSMutableDictionary alloc] init];
		
		storyLock = [[NSLock alloc] init];
		port1 = nil;
		port2 = nil;
		mainThread = nil;
		subThread = nil;
	}
	
	return self;
}

- (void) dealloc {
	[storyFilenames release];
	[storyIdents release];
	[filenamesToIdents release];
	[identsToFilenames release];
	
	[storyLock release];
	[port1 release];
	[port2 release];
	[mainThread release];
	[subThread release];
	
	[super dealloc];
}

// = The shared organiser =
static ZoomStoryOrganiser* sharedOrganiser = nil;

+ (ZoomStoryOrganiser*) sharedStoryOrganiser {
	if (!sharedOrganiser) {
		sharedOrganiser = [[ZoomStoryOrganiser alloc] init];
		[sharedOrganiser loadPreferences];
	}
	
	return sharedOrganiser;
}

// = Storing stories =
- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident {
	[self addStory: filename
		 withIdent: ident
		  organise: NO];
}

- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident
		 organise: (BOOL) organise {
	// FIXME: Organise not supported yet
	if (organise) {
		// Move to a standard directory, change the filename we're using
	}
	
	[storyLock lock];
	
	NSString* oldFilename;
	ZoomStoryID* oldIdent;
	
	oldFilename = [identsToFilenames objectForKey: ident];
	oldIdent = [filenamesToIdents objectForKey: filename];
	
	if (oldFilename && oldIdent && [oldFilename isEqualToString: filename] && [oldIdent isEqualTo: ident]) {
		// Nothing to do
		NSLog(@"ZZzz");
		[storyLock unlock];
		return;
	}
	
	if (oldFilename) {
		[identsToFilenames removeObjectForKey: ident];
		[storyFilenames removeObject: oldFilename];
	}
	
	if (oldIdent) {
		[filenamesToIdents removeObjectForKey: filename];
		[storyIdents removeObject: oldIdent];
	}
	
	NSString* newFilename = [[filename copy] autorelease];
	NSString* newIdent    = [[ident copy] autorelease];
	
	[storyFilenames addObject: newFilename];
	[storyIdents addObject: newIdent];
	
	[identsToFilenames setObject: newFilename forKey: newIdent];
	[filenamesToIdents setObject: newIdent forKey: newFilename];
	
	[storyLock unlock];
	[self organiserChanged];
}

// = Retrieving story information =
- (NSString*) filenameForIdent: (ZoomStoryID*) ident {
	NSString* res;
	
	[storyLock lock];
	res = [[[identsToFilenames objectForKey: ident] retain] autorelease];
	[storyLock unlock];
	
	return res;
}

- (ZoomStoryID*) identForFilename: (NSString*) filename {
	ZoomStoryID* res;
	
	[storyLock lock];
	res = [[[filenamesToIdents objectForKey: filename] retain] autorelease];
	[storyLock unlock];
	
	return res;
}

- (NSArray*) storyFilenames {
	return [[storyFilenames copy] autorelease];
}

- (NSArray*) storyIdents {
	return [[storyIdents copy] autorelease];
}

@end
