//
//  ZoomAppDelegate.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <unistd.h>

#import "ZoomAppDelegate.h"
#import "ZoomGameInfoController.h"
#import "ZoomSkeinController.h"

#import "ZoomMetadata.h"
#import "ZoomiFictionController.h"

@implementation ZoomAppDelegate

// = Initialisation =
+ (void) initialization {
	
}

- (id) init {
	self = [super init];
	
	if (self) {
		gameIndices = [[NSMutableArray alloc] init];

		NSString* configDir = [self zoomConfigDirectory];

		NSData* userData = [NSData dataWithContentsOfFile: [configDir stringByAppendingPathComponent: @"metadata.iFiction"]];
		NSData* infocomData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"infocom" ofType: @"iFiction"]];
		NSData* archiveData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"archive" ofType: @"iFiction"]];
		
		if (userData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: userData] autorelease]];
		else
			[gameIndices addObject: [[[ZoomMetadata alloc] init] autorelease]];
		
		if (infocomData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: infocomData] autorelease]];
		if (archiveData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: archiveData] autorelease]];
		
		// Create the connection that we'll use to allow ZoomServer processes to connect to us
		// (Originally, this was created by the ZoomServer processes themselves, but there is a limit to the
		// number of Mach ports that can be created in OS X. Exceeding the limit creates a kernel panic - an
		// OS X bug, but one we really don't want to provoke if possible)
		//
		// Unlikely that anyone ever encountered this: you need ~200-odd running games before things go
		// kaboom.
		NSString* connectionName = [NSString stringWithFormat: @"Zoom-%i", getpid()];
		NSPort* port = [NSMachPort port];
		
		connection = [[NSConnection connectionWithReceivePort: port
													 sendPort: port] retain];
		[connection setRootObject: self];
		[connection addRunLoop: [NSRunLoop currentRunLoop]];
		if (![connection registerName: connectionName]) {
			NSLog(@"Uh-oh: failed to register a connection. Games will probably fail to start");
		}
				
		waitingViews = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	if (preferencePanel) [preferencePanel release];
	[gameIndices release];
	
	[waitingViews release];
	[connection registerName: nil];
	[connection release];
	
	[super dealloc];
}

// = Opening files =
- (BOOL) applicationShouldOpenUntitledFile: (NSApplication*) sender {
    return YES;
}

- (BOOL) applicationOpenUntitledFile:(NSApplication *)theApplication {
	[[[ZoomiFictionController sharediFictionController] window] makeKeyAndOrderFront: self];
	
	return YES;
}

- (BOOL)application: (NSApplication *)theApplication 
		   openFile: (NSString *)filename {
	if ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: filename
																				display: YES]) {
		return YES;
	}
	
	if ([[[filename pathExtension] lowercaseString] isEqualToString: @"ifiction"]) {
		// Load extra iFiction data
		[[ZoomiFictionController sharediFictionController] mergeiFictionFromFile: filename];
	}
	
	return NO;
}

// = General actions =
- (IBAction) showPreferences: (id) sender {
	if (!preferencePanel) {
		preferencePanel = [[ZoomPreferenceWindow alloc] init];
	}
	
	[[preferencePanel window] center];
	[preferencePanel setPreferences: [ZoomPreferences globalPreferences]];
	[[preferencePanel window] makeKeyAndOrderFront: self];
}

- (IBAction) displayGameInfoWindow: (id) sender {
	[[ZoomGameInfoController sharedGameInfoController] showWindow: self];

	// Blank out the game info window
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == nil) {
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
	}
}

- (IBAction) displaySkein: (id) sender {
	[[ZoomSkeinController sharedSkeinController] showWindow: self];

	[NSApp sendAction: @selector(updateSkein:)
				   to: nil
				 from: self];
}

- (IBAction) displayNoteWindow: (id) sender {
}

- (IBAction) showiFiction: (id) sender {
	[[[ZoomiFictionController sharediFictionController] window] makeKeyAndOrderFront: self];
}

// = Application-wide data =
- (NSArray*) gameIndices {
	return gameIndices;
}

- (ZoomStory*) findStory: (ZoomStoryID*) gameID {
	NSEnumerator* indexEnum = [gameIndices objectEnumerator];
	ZoomMetadata* repository;
	
	while (repository = [indexEnum nextObject]) {
		ZoomStory* res = [repository findStory: gameID];
		
		if (res) return res;
	}
	
	return nil;
}

- (ZoomMetadata*) userMetadata {
	return [gameIndices objectAtIndex: 0];
}

- (NSString*) zoomConfigDirectory {
	// The app delegate may not be the best place for this routine... Maybe a function somewhere
	// would be better?
	NSArray* libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
	NSEnumerator* libEnum;
	NSString* libDir;

	libEnum = [libraryDirs objectEnumerator];
	
	while (libDir = [libEnum nextObject]) {
		BOOL isDir;
		
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] fileExistsAtPath: zoomLib isDirectory: &isDir]) {
			if (isDir) {
				return zoomLib;
			}
		}
	}
	
	libEnum = [libraryDirs objectEnumerator];
	
	while (libDir = [libEnum nextObject]) {
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] createDirectoryAtPath: zoomLib
													   attributes:nil]) {
			return zoomLib;
		}
	}
	
	return nil;
}

// = Connecting views to Z-Machines =

- (void) addViewWaitingForServer: (ZoomView*) view {
	[self removeView: view];
	[waitingViews addObject: view];
}

- (void) removeView: (ZoomView*) view {
	[waitingViews removeObjectIdenticalTo: view];
}

- (id<ZDisplay>) connectToDisplay: (id<ZMachine>) zMachine {
	// Get the view that's waiting
	ZoomView* whichView = [[[waitingViews lastObject] retain] autorelease];	
	if (whichView == nil) {
		NSLog(@"WARNING: attempt to connect to a display when no objects are available to connect to");
		return nil;
	}
	
	// Remove from the list of waiting views
	[waitingViews removeLastObject];
	
	// Notify the view that it's gained a Z-Machine
	[[NSRunLoop currentRunLoop] performSelector: @selector(setZMachine:)
										 target: whichView
									   argument: zMachine
										  order: 16
										  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	//[whichView setZMachine: (NSObject<ZMachine>*)zMachine];
	
	// We're done
	return whichView;
}

@end
