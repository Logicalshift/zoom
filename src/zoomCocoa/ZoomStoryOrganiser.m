//
//  ZoomStoryOrganiser.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomStoryOrganiser.h"
#import "ZoomAppDelegate.h"

NSString* ZoomStoryOrganiserChangedNotification = @"ZoomStoryOrganiserChangedNotification";
static NSString* defaultName = @"ZoomStoryOrganiser";
static NSString* extraDefaultsName = @"ZoomStoryOrganiserExtra";
static NSString* ZoomGameDirectories = @"ZoomGameDirectories";
static NSString* ZoomGameStorageDirectory = @"ZoomGameStorageDirectory";
static NSString* ZoomIdentityFilename = @".zoomIdentity";

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

- (NSDictionary*) extraDictionary {
	NSData* resourceData = [NSArchiver archivedDataWithRootObject: identsToResources];
	
	return [NSDictionary dictionaryWithObjectsAndKeys: 
		resourceData, @"identsToResources", nil];
}

- (void) storePreferences {
	[[NSUserDefaults standardUserDefaults] setObject:[self dictionary] 
											  forKey:defaultName];
	[[NSUserDefaults standardUserDefaults] setObject:[self extraDictionary] 
											  forKey:extraDefaultsName];
}

- (void) preferenceThread: (NSDictionary*) threadDictionary {
	NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
	NSDictionary* prefs = [threadDictionary objectForKey: @"preferences"];
	NSDictionary* prefs2 = [threadDictionary objectForKey: @"extraPreferences"];
	
	int counter = 0;
	
	// Connect to the main thread
	[[NSRunLoop currentRunLoop] addPort: port2
                                forMode: NSDefaultRunLoopMode];
	subThread = [[NSConnection allocWithZone: [self zone]]
        initWithReceivePort: port2
                   sendPort: port1];
	[subThread setRootObject: self];
	
	// Resources
	NSData* idToRes = [prefs2 objectForKey: @"identsToResources"];
	
	if (idToRes != nil && [idToRes isKindOfClass: [NSData class]]) {
		[storyLock lock];
		if (identsToResources != nil) {
			[identsToResources release];
		}
		
		identsToResources = [[NSUnarchiver unarchiveObjectWithData: idToRes] mutableCopy];
		
		if (identsToResources == nil || ![identsToResources isKindOfClass: [NSMutableDictionary class]]) {
			[identsToResources release];
			identsToResources = [[NSMutableDictionary alloc] init];
		}
		[storyLock unlock];
	}
		
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
			[(ZoomStoryOrganiser*)[subThread rootProxy] organiserChanged];
		}
	}	
	
	[(ZoomStoryOrganiser*)[subThread rootProxy] organiserChanged];
	
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
	NSDictionary* extraPrefs = [[NSUserDefaults standardUserDefaults] objectForKey: defaultName];
	
	// Detach a thread to decode the dictionary
	NSDictionary* threadDictionary =
		[[NSDictionary dictionaryWithObjectsAndKeys:
			prefs, @"preferences",
			extraPrefs, @"extraPreferences",
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
	
		NSArray* libraries = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString* libraryDir = [[libraries objectAtIndex: 0] stringByAppendingPathComponent: @"Interactive Fiction"];
	
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys: [defaultPrefs dictionary], defaultName,
		libraryDir, ZoomGameStorageDirectory, nil];
	
    [defaults registerDefaults: appDefaults];	
}

- (id) init {
	self = [super init];
	
	if (self) {
		storyFilenames = [[NSMutableArray alloc] init];
		storyIdents = [[NSMutableArray alloc] init];
		
		filenamesToIdents = [[NSMutableDictionary alloc] init];
		identsToFilenames = [[NSMutableDictionary alloc] init];
		identsToResources = [[NSMutableDictionary alloc] init];
		
		storyLock = [[NSLock alloc] init];
		port1 = nil;
		port2 = nil;
		mainThread = nil;
		subThread = nil;
		
		// Any time a story changes, we move it
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(someStoryHasChanged:)
													 name: ZoomStoryDataHasChangedNotification
												   object: nil];
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
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
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

- (void) removeStoryWithIdent: (ZoomStoryID*) ident {
	[storyLock lock];
	
	NSString* filename = [identsToFilenames objectForKey: ident];
	
	if (filename != nil) {
		[filenamesToIdents removeObjectForKey: filename];
		[identsToFilenames removeObjectForKey: ident];
		[identsToResources removeObjectForKey: ident];
		[storyIdents removeObjectIdenticalTo: ident];
		[storyFilenames removeObject: filename];
	}
	
	[storyLock unlock];
	[self organiserChanged];
}

- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident
		 organise: (BOOL) organise {	
	[storyLock lock];
	
	NSString* oldFilename;
	ZoomStoryID* oldIdent;
	
	oldFilename = [identsToFilenames objectForKey: ident];
	oldIdent = [filenamesToIdents objectForKey: oldFilename];
	
	if (organise) {		
		ZoomStory* theStory = [[NSApp delegate] findStory: ident];
		
		// If there's no story registered, then we need to create one
		if (theStory == nil) {
			theStory = [[ZoomStory alloc] init];
			
			[theStory addID: ident];
			[theStory setTitle: [[filename lastPathComponent] stringByDeletingPathExtension]];
			
			[[[NSApp delegate] userMetadata] storeStory: [theStory autorelease]];
			[[[NSApp delegate] userMetadata] writeToDefaultFile];
		}

		// Copy to a standard directory, change the filename we're using
		filename = [filename stringByStandardizingPath];
		
		NSString* fileDir = [self directoryForIdent: ident create: YES];
		NSString* destFile = [fileDir stringByAppendingPathComponent: @"game.z5"];
		destFile = [destFile stringByStandardizingPath];
		
		if (![filename isEqualToString: destFile]) {
			[[NSFileManager defaultManager] removeFileAtPath: destFile handler: nil];
			if ([[NSFileManager defaultManager] copyPath: filename
												  toPath: destFile
												 handler: nil]) {
				filename = destFile;
			} else {
				NSLog(@"Warning: couldn't copy '%@' to '%@'", filename, destFile);
			}
		}
	}
	
	if (oldFilename && oldIdent && [oldFilename isEqualToString: filename] && [oldIdent isEqualTo: ident]) {
		// Nothing to do
		[storyLock unlock];
		return;
	}
	
	if (oldFilename) {
		[identsToFilenames removeObjectForKey: ident];
		[filenamesToIdents removeObjectForKey: oldFilename];
		[storyFilenames removeObject: oldFilename];
	}

	if (oldIdent) {
		[filenamesToIdents removeObjectForKey: filename];
		[identsToFilenames removeObjectForKey: oldIdent];
		[storyIdents removeObject: oldIdent];
	}
	
	[filenamesToIdents removeObjectForKey: filename];
	[identsToFilenames removeObjectForKey: ident];
	
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

// Story-specific data

- (NSString*) preferredDirectoryForIdent: (ZoomStoryID*) ident {
	// The preferred directory is defined by the story group and title
	// (Ungrouped/untitled if there is no story group/title)

	// TESTME: what does stringByAppendingPathComponent do in the case where the group/title
	// contains a '/' or other evil character?
	NSString* confDir = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomGameStorageDirectory];
	ZoomStory* theStory = [[NSApp delegate] findStory: ident];
	
	confDir = [confDir stringByAppendingPathComponent: [theStory group]];
	confDir = [confDir stringByAppendingPathComponent: [theStory title]];
	
	return confDir;
}

- (BOOL) directory: (NSString*) dir
		 isForGame: (ZoomStoryID*) ident {
	// If the preferences get corrupted or something similarily silly happens,
	// we want to avoid having games point to the wrong directories. This
	// routine checks that a directory belongs to a particular game.
	BOOL isDir;
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: dir
											  isDirectory: &isDir]) {
		// Corner case
		return YES;
	}
	
	if (!isDir) // Files belong to no game
		return NO;
	
	NSString* idFile = [dir stringByAppendingPathComponent: ZoomIdentityFilename];
	if (![[NSFileManager defaultManager] fileExistsAtPath: idFile
											  isDirectory: &isDir]) {
		// Directory has no identification
		return NO;
	}
	
	if (isDir) // Identification must be a file
		return NO;
	
	ZoomStoryID* owner = [NSUnarchiver unarchiveObjectWithFile: idFile];
	
	if (owner && [owner isKindOfClass: [ZoomStoryID class]] && [owner isEqual: ident])
		return YES;
	
	// Directory belongs to some other game
	return NO;
}

- (NSString*) findDirectoryForIdent: (ZoomStoryID*) ident
					  createGameDir: (BOOL) createGame
					 createGroupDir: (BOOL) createGroup {
	// Assuming a story doesn't already have a directory, find (and possibly create)
	// a directory for it
	NSString* confDir = nil;
	BOOL isDir;
	
	ZoomStory* theStory = [[NSApp delegate] findStory: ident];
	NSString* group = [theStory group];
	NSString* title = [theStory title];
	
	if (group == nil || [group isEqualToString: @""])
		group = @"Ungrouped";
	if (title == nil || [title isEqualToString: @""])
		title = @"Untitled";
	
	// Find the root directory
	NSString* rootDir = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomGameStorageDirectory];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: rootDir
											  isDirectory: &isDir]) {
		if (createGroup) {
			[[NSFileManager defaultManager] createDirectoryAtPath: rootDir
													   attributes: nil];
			isDir = YES;
		} else {
			return nil;
		}
	}
	
	if (!isDir) {
		static BOOL warned = NO;
		
		if (!warned)
			NSRunAlertPanel([NSString stringWithFormat: @"Game library not found"],
							[NSString stringWithFormat: @"Warning: %@ is a file", rootDir], 
							@"OK", nil, nil);
		warned = YES;
		return nil;
	}
	
	// Find the group directory
	NSString* groupDir = [rootDir stringByAppendingPathComponent: group];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: groupDir
											  isDirectory: &isDir]) {
		if (createGroup) {
			[[NSFileManager defaultManager] createDirectoryAtPath: groupDir
													   attributes: nil];
			isDir = YES;
		} else {
			return nil;
		}
	}
	
	if (!isDir) {
		static BOOL warned = NO;
		
		if (!warned)
			NSRunAlertPanel([NSString stringWithFormat: @"Group directory not found"],
							[NSString stringWithFormat: @"Warning: %@ is a file", groupDir], 
							@"OK", nil, nil);
		warned = YES;
		return nil;
	}
	
	// Now the game directory
	NSString* gameDir = [groupDir stringByAppendingPathComponent: title];
	int number = 0;
	const int maxNumber = 20;
	
	while (![self directory: gameDir 
				  isForGame: ident] &&
		   number < maxNumber) {
		number++;
		gameDir = [groupDir stringByAppendingPathComponent: [NSString stringWithFormat: @"%@ %i", title, number]];
	}
	
	if (number >= maxNumber) {
		static BOOL warned = NO;
		
		if (!warned)
			NSRunAlertPanel([NSString stringWithFormat: @"Game directory not found"],
							[NSString stringWithFormat: @"Zoom was unable to locate a directory for the game '%@'", title], 
							@"OK", nil, nil);
		warned = YES;
		return nil;
	}
	
	// Create the directory if necessary
	if (![[NSFileManager defaultManager] fileExistsAtPath: gameDir
											  isDirectory: &isDir]) {
		if (createGame) {
			[[NSFileManager defaultManager] createDirectoryAtPath: gameDir
													   attributes: nil];
		} else {
			if (createGroup) {
				// Special case, really. Sometimes we need to know where we're going to move the game to
				return gameDir;
			} else {
				return nil;
			}
		}
	}
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: gameDir
											  isDirectory: &isDir] || !isDir) {
		// Chances of reaching here should have been eliminated previously
		return nil;
	}
	
	// Create the identifier file
	NSString* identityFile = [gameDir stringByAppendingPathComponent: ZoomIdentityFilename];
	[NSArchiver archiveRootObject: ident
						   toFile: identityFile];
	
	/* -- Not used here
	// Store this directory as the dir for this game
	NSMutableDictionary* newGameDirs = [gameDirs mutableCopy];
	
	if (newGameDirs == nil) {
		newGameDirs = [[NSMutableDictionary alloc] init];
	}
	
	[newGameDirs setObject: gameDir
					forKey: [ident description]];
	[defaults setObject: [newGameDirs autorelease]
				 forKey: ZoomGameDirectories];
	 */
	
	return gameDir;
}

- (NSString*) directoryForIdent: (ZoomStoryID*) ident
						 create: (BOOL) create {
	NSString* confDir = nil;
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		
	// If there is a directory in the preferences, then that's the directory to use
	NSDictionary* gameDirs = [defaults objectForKey: ZoomGameDirectories];
	
	if (gameDirs)
		confDir = [gameDirs objectForKey: [ident description]];

	BOOL isDir;
	if (![[NSFileManager defaultManager] fileExistsAtPath: confDir
											  isDirectory: &isDir]) {
		confDir = nil;
	}
	
	if (!isDir)
		confDir = nil;
	
	if (confDir && [self directory: confDir isForGame: ident])
		return confDir;
	
	confDir = nil;
	
	NSString* gameDir = [self findDirectoryForIdent: ident
									  createGameDir: create
									 createGroupDir: create];
	
	if (gameDir == nil) return nil;
		
	// Store this directory as the dir for this game
	NSMutableDictionary* newGameDirs = [gameDirs mutableCopy];

	if (newGameDirs == nil) {
		newGameDirs = [[NSMutableDictionary alloc] init];
	}

	[newGameDirs setObject: gameDir
					forKey: [ident description]];
	[defaults setObject: [newGameDirs autorelease]
				 forKey: ZoomGameDirectories];
	
	return gameDir;
}

- (BOOL) moveStoryToPreferredDirectoryWithIdent: (ZoomStoryID*) ident {
	// Get the current directory
	NSString* currentDir = [self directoryForIdent: ident 
											create: NO];
	currentDir = [currentDir stringByStandardizingPath];
	
	if (currentDir == nil) return NO;
	
	// Get the 'ideal' directory
	NSString* idealDir = [self findDirectoryForIdent: ident
									   createGameDir: NO
									  createGroupDir: YES];
	idealDir = [idealDir stringByStandardizingPath];
	
	// See if they already match
	if ([idealDir isEqualToString: currentDir]) 
		return YES;
	
	// If they don't match, then idealDir should be new (or something weird has just occured)
	if ([[NSFileManager defaultManager] fileExistsAtPath: idealDir]) {
		// Doh!
		NSLog(@"Wanted to move game from '%@' to '%@', but '%@' already exists", currentDir, idealDir, idealDir);
		return NO;
	}
	
	// Move the old directory to the new directory
	
	// Vague possibilities of this failing: in particular, currentDir may be not write-accessible or
	// something might appear there between our check and actually moving the directory	
	if (![[NSFileManager defaultManager] movePath: currentDir
										  toPath: idealDir
										 handler: nil]) {
		NSLog(@"Failed to move '%@' to '%@'", currentDir, idealDir);
		return NO;
	}
	
	// Success: store the new directory in the defaults
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	NSDictionary* gameDirs = [defaults objectForKey: ZoomGameDirectories];
	if (gameDirs == nil) gameDirs = [NSDictionary dictionary];
	NSMutableDictionary* newGameDirs = [gameDirs mutableCopy];
	
	if (newGameDirs == nil) {
		newGameDirs = [[NSMutableDictionary alloc] init];
	}
	
	[newGameDirs setObject: idealDir
					forKey: [ident description]];
	[defaults setObject: [newGameDirs autorelease]
				 forKey: ZoomGameDirectories];	
	
	return YES;
}

- (void) someStoryHasChanged: (NSNotification*) not {
	ZoomStory* story = [not object];
	
	if (![story isKindOfClass: [ZoomStory class]]) {
		NSLog(@"someStoryHasChanged: called with a non-story object (too many spoons?)");
		return; // Unlikely but possible. If I'm a spoon, that is.
	}
	
	// De and requeue this to be done next time through the run loop
	// (stops this from being performed multiple times when many story parameters are updated together)
	[[NSRunLoop currentRunLoop] cancelPerformSelector: @selector(finishChangingStory:)
											   target: self
											 argument: story];
	[[NSRunLoop currentRunLoop] performSelector: @selector(finishChangingStory:)
										 target: self
									   argument: story
										  order: 128
										  modes: [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
}

- (void) finishChangingStory: (ZoomStory*) story {
	// For our pre-arranged stories, several IDs are possible, but more usually one
	NSEnumerator* identEnum = [[story storyIDs] objectEnumerator];
	ZoomStoryID* ident;
	BOOL changed = NO;
	
	while (ident = [identEnum nextObject]) {
		int identID = [storyIdents indexOfObject: ident];
		
		if (identID != NSNotFound) {
			// Get the old location of the game
			ZoomStoryID* realID = [storyIdents objectAtIndex: identID];
			
			NSString* oldGameFile = [self directoryForIdent: ident create: NO];
			oldGameFile = [oldGameFile stringByAppendingPathComponent: @"game.z5"];
			NSString* oldGameLoc = [storyFilenames objectAtIndex: identID];
			
			oldGameFile = [oldGameFile stringByStandardizingPath];
			oldGameLoc = [oldGameLoc stringByStandardizingPath];

			// Actually perform the move
			if ([self moveStoryToPreferredDirectoryWithIdent: [storyIdents objectAtIndex: identID]]) {
				changed = YES;
			
				// Store the new location of the game, if necessary
				if ([oldGameLoc isEqualToString: oldGameFile]) {
					NSString* newGameFile = [[self directoryForIdent: ident create: NO] stringByAppendingPathComponent: @"game.z5"];
					newGameFile = [newGameFile stringByStandardizingPath];

					if (![oldGameFile isEqualToString: newGameFile]) {
						[filenamesToIdents removeObjectForKey: oldGameFile];
						
						[filenamesToIdents setObject: realID
											  forKey: newGameFile];
						[identsToFilenames setObject: newGameFile
											  forKey: realID];
						
						[storyFilenames replaceObjectAtIndex: identID
												  withObject: newGameFile];
					}
				}
			}
		}
	}
	
	if (changed)
		[self organiserChanged];
}

// Blorb resources

- (BOOL) addResource: (NSString*) blorbFile
		   withIdent: (ZoomStoryID*) ident
			organise: (BOOL) organise {
	NSFileManager* fm = [NSFileManager defaultManager];
	
	if (blorbFile == nil || [blorbFile length] == 0) {
		// Delete the file if required
		if (organise) {
			NSString* dir = [self directoryForIdent: ident
											 create: NO];
			NSString* newFile = [dir stringByAppendingPathComponent: @"resource.blb"];
			
			if (dir != nil && [fm fileExistsAtPath: newFile]) {
				[fm removeFileAtPath: newFile
							 handler: nil];
			}
		}
		
		[identsToResources removeObjectForKey: ident];
		
		return YES;
	}
	
	// Check that the file exists and is not a directory
	BOOL isDir;
	BOOL exists = [fm fileExistsAtPath: blorbFile
						   isDirectory: &isDir];
	
	if (!exists) {
		NSLog(@"Resource file \"%@\" does not exist", blorbFile);
		return NO;
	}
	if (isDir) {
		NSLog(@"Resource file \"%@\" is a directory", blorbFile);
		return NO;
	}
	
	// Organise if required
	if (organise) {
		NSString* dir = [self directoryForIdent: ident
										 create: NO];
		
		if (dir == nil) {
			NSLog(@"No organised directory for game: cannot store resources");
			return NO;
		}
		
		exists = [fm fileExistsAtPath: dir
						  isDirectory: &isDir];
		if (!exists || !isDir) {
			NSLog(@"Organised directory for game does not exist");
			return NO;
		}
		
		NSString* newFile = [dir stringByAppendingPathComponent: @"resource.blb"];
		
		if (![fm copyPath: blorbFile
				   toPath: newFile
				  handler: nil]) {
			NSLog(@"Unable to copy resource file to new location");
			return NO;
		}
		
		blorbFile = newFile;
	}
	
	// Add to our database
	[storyLock lock];
	[identsToResources setObject: [[blorbFile copy] autorelease]
						  forKey: ident];
	[storyLock unlock];
	[self organiserChanged];
	
	// Done
	return YES;
}

- (NSString*) resourcesForIdent: (ZoomStoryID*) ident {
	[storyLock lock];
	NSString* res = [[[identsToResources objectForKey: ident] copy] autorelease];
	[storyLock unlock];
	
	return res;
}

@end
